local EVENT = 'daddy-intoxication'
local players = {}      -- [src] = record, the only source of truth for intoxication
local voiceSubmixes = {} -- whitelist of submix names this resource may write

for name in pairs(Config.Voice.Submixes) do voiceSubmixes[name] = true end

local function notify(src, msg, type)
    TriggerClientEvent(EVENT .. ':client:notify', src, msg, type)
end

local function validPlayer(src)
    src = tonumber(src)
    if src and src > 0 and GetPlayerName(src) then return src end
end

local function getRecord(src, create)
    local rec = players[src]
    if not rec and create then
        rec = {
            alcohol = 0.0, stage = 0, profile = nil,
            tolerance = 0.0, lastDrink = 0, toleranceCheck = 0, lastToleranceGain = 0,
            boostMult = 1.0, boostUntil = 0,
            lastVomit = 0, lastBlackout = 0, lastDeath = 0,
            pub = {}, -- last values written to state bags
        }
        players[src] = rec
    end
    return rec
end

local function newToken()
    return math.random(100000, 999999999)
end

---------------------------------------------------------------------
-- Tolerance
---------------------------------------------------------------------
local Tolerance = {}

function Tolerance.Active()
    return Config.Tolerance.Enabled
end

function Tolerance.Reduction(rec)
    if not Tolerance.Active() then return 0 end
    return rec.tolerance / 100 * Config.Tolerance.MaxReduction
end

function Tolerance.MetabolismMult(rec)
    if not Tolerance.Active() then return 1.0 end
    return 1.0 + rec.tolerance / 100 * Config.Tolerance.MetabolismBonus
end

function Tolerance.Decay(rec, time)
    local cfg = Config.Tolerance
    if rec.tolerance <= 0 or rec.lastDrink <= 0 then return end

    local decayStart = rec.lastDrink + cfg.DecayAfter
    if time <= decayStart then return end

    local from = math.max(decayStart, rec.toleranceCheck or 0)
    rec.tolerance = math.max(0, rec.tolerance - cfg.DecayPerDay * (time - from) / 86400)
    rec.toleranceCheck = time
end

function Tolerance.Gain(rec, now, alcohol)
    local cfg = Config.Tolerance
    if not Tolerance.Active() or alcohol < cfg.GainMinAlcohol then return end
    if now - rec.lastToleranceGain < cfg.GainCooldown * 1000 then return end

    rec.lastToleranceGain = now
    -- Diminishing returns: the closer to 100, the slower it grows
    rec.tolerance = math.min(100, rec.tolerance + cfg.Gain * (1 - rec.tolerance / 100))
end

---------------------------------------------------------------------
-- State publishing (single path for every state bag write)
---------------------------------------------------------------------
local function voiceAvailable()
    return Config.Voice.Enabled and GetResourceState(Config.Voice.Resource) == 'started'
end

local function updateVoice(rec, state)
    local desired = voiceAvailable() and rec.alcohol > 0 and Config.Voice.Stages[rec.stage] or nil
    if desired and not voiceSubmixes[desired] then desired = nil end
    if desired == rec.voice then return end

    local current = state.submix
    if desired then
        -- Never replace a submix owned by another resource
        if current ~= nil and not voiceSubmixes[current] then return end
        state:set('submix', desired, true)
    elseif voiceSubmixes[current] then
        state:set('submix', nil, true)
    end
    rec.voice = desired
end

local function publish(src, rec)
    local state = Player(src).state
    local pub = rec.pub

    local function put(key, value)
        if pub[key] == value then return false end
        pub[key] = value
        state:set(key, value, true)
        return true
    end

    local alcohol = rec.alcohol > 0 and math.ceil(rec.alcohol - 0.001) or 0
    local profile = rec.alcohol > 0 and rec.profile or nil

    local changed = put('alcohol', alcohol)
    changed = put('alcoholStage', rec.stage) or changed
    changed = put('alcoholType', profile) or changed
    put('intoxicated', rec.stage >= Config.Stages.IntoxicatedFrom)
    put('bac', Utils.GetBAC(alcohol))
    if Tolerance.Active() then put('alcoholTolerance', math.floor(rec.tolerance)) end

    updateVoice(rec, state)

    if changed then
        TriggerClientEvent(EVENT .. ':client:sync', src, alcohol, rec.stage, profile)
    end
    return changed
end

local function clearState(src, rec)
    local state = Player(src).state
    for _, key in ipairs({ 'alcohol', 'alcoholStage', 'alcoholType', 'intoxicated', 'bac', 'alcoholTolerance' }) do
        state:set(key, nil, true)
    end
    if rec and rec.voice and voiceSubmixes[state.submix] then
        state:set('submix', nil, true)
    end
end

local function saveRecord(rec)
    if rec.id then Persistence.Save(rec.id, rec) end
end

---------------------------------------------------------------------
-- Core alcohol logic
---------------------------------------------------------------------
local function setAlcohol(src, amount, profile, reason)
    local rec = getRecord(src, true)
    local oldAlcohol, oldStage = rec.alcohol, rec.stage

    amount = Utils.Clamp(tonumber(amount) or 0, 0, Config.MaxAlcohol)
    if amount < 0.01 then amount = 0 end

    if profile and Config.Profiles[profile] then
        rec.profile = profile
    elseif not rec.profile then
        rec.profile = Config.DefaultProfile
    end

    rec.alcohol = amount
    rec.stage = Utils.GetStage(amount, oldStage)

    if amount == 0 then
        rec.profile = nil
        rec.nextNausea = nil
        rec.nausea = nil
        rec.boostUntil = 0
    end

    if publish(src, rec) then
        TriggerEvent(EVENT .. ':server:alcoholChanged', src, rec.pub.alcohol, rec.stage, rec.profile, reason)
    end

    if rec.stage ~= oldStage then
        TriggerEvent(EVENT .. ':server:stageChanged', src, rec.stage, oldStage)
        Utils.Debug(('Player %s stage %s -> %s (%s)'):format(src, oldStage, rec.stage, reason or 'update'))
    end

    if amount == 0 and oldAlcohol > 0 then saveRecord(rec) end
    return rec.pub.alcohol
end

local function resetPlayer(src, reason)
    local rec = players[src]
    if not rec then return end
    rec.blackout = nil
    rec.nausea = nil
    setAlcohol(src, 0, nil, reason or 'reset')
    TriggerClientEvent(EVENT .. ':client:reset', src)
end

local function consumeDrink(src, itemName)
    local drink = Config.Drinks[itemName]
    if not drink then return false end

    local rec = getRecord(src, true)
    local profileName = Config.Profiles[drink.profile] and drink.profile or Config.DefaultProfile
    local profile = Config.Profiles[profileName]
    local oldStage = rec.stage
    local time = os.time()

    Tolerance.Decay(rec, time)
    local amount = drink.alcohol * (profile.alcoholMultiplier or 1.0) * (1 - Tolerance.Reduction(rec))
    Tolerance.Gain(rec, GetGameTimer(), rec.alcohol + amount)
    rec.lastDrink = time

    setAlcohol(src, rec.alcohol + amount, profileName, 'drink')
    TriggerClientEvent(EVENT .. ':client:drank', src, profileName)

    if rec.stage > oldStage then
        notify(src, L('stage_' .. rec.stage), rec.stage >= 3 and 'error' or 'inform')
    end
    return true
end

local function consumeRecovery(src, itemName)
    local item = Config.RecoveryItems[itemName]
    if not item then return false end

    local rec = players[src]
    if not rec or rec.alcohol <= 0 then return true end

    local now = GetGameTimer()
    if item.metabolism then
        rec.boostMult = item.metabolism.multiplier or 1.0
        rec.boostUntil = now + (item.metabolism.duration or 0) * 1000
    end
    if item.nausea and rec.nextNausea then
        rec.nextNausea = math.max(rec.nextNausea, now) + item.nausea * 1000
    end

    local left = rec.alcohol
    if item.reduction and item.reduction > 0 then
        left = setAlcohol(src, rec.alcohol - item.reduction, nil, 'recovery')
    end

    notify(src, left == 0 and L('recovery_sober') or L('recovery_used'), 'success')
    return true
end

---------------------------------------------------------------------
-- Nausea, vomiting and blackout (server scheduled, client presents)
---------------------------------------------------------------------
local function randomSeconds(range)
    return math.random(range[1], range[2]) * 1000
end

local function vomit(src, rec, now)
    if now < rec.lastVomit + Config.Vomit.Cooldown * 1000 then return false end
    rec.lastVomit = now
    TriggerClientEvent(EVENT .. ':client:vomit', src, Config.Vomit.HealthLoss)
    setAlcohol(src, rec.alcohol - Config.Vomit.AlcoholReduction, nil, 'vomit')
    notify(src, L('vomited'), 'error')
    return true
end

local function startNausea(src, rec, now)
    local skill = Config.Nausea.SkillCheck.Enabled
    rec.nausea = { token = newToken(), expires = now + Config.Nausea.ResponseTimeout * 1000, skill = skill }
    TriggerClientEvent(EVENT .. ':client:nausea', src, rec.nausea.token, skill)
end

local function processNausea(src, rec, now)
    local cfg = Config.Nausea
    if not cfg.Enabled then return end

    if rec.nausea then
        if now > rec.nausea.expires then
            rec.nausea = nil
            rec.nextNausea = now + randomSeconds(cfg.RepeatDelay)
        end
        return
    end

    if rec.alcohol < cfg.MinAlcohol then
        rec.nextNausea = nil
        return
    end
    if rec.blackout then return end

    local tendency = Utils.GetProfile(rec.profile).nausea or 1.0
    if not rec.nextNausea then
        rec.nextNausea = now + randomSeconds(cfg.InitialDelay) / tendency
    elseif now >= rec.nextNausea then
        startNausea(src, rec, now)
    end
end

RegisterNetEvent(EVENT .. ':server:nauseaResponse', function(token, result)
    local src = source
    local rec = players[src]
    local pending = rec and rec.nausea
    if not pending or pending.token ~= token or type(result) ~= 'string' then return end

    local cfg = Config.Nausea
    local now = GetGameTimer()
    local tendency = Utils.GetProfile(rec.profile).nausea or 1.0
    local vomits

    if result == 'postponed' then
        rec.nausea = nil
        rec.nextNausea = now + cfg.PostponeDelay * 1000
        return
    elseif pending.skill and result == 'resisted' then
        vomits = false
    elseif pending.skill and result == 'failed' then
        vomits = true
    elseif result == 'ready' then
        vomits = math.random() < cfg.VomitChance * tendency
    else
        return
    end

    rec.nausea = nil
    if vomits and rec.alcohol >= cfg.MinAlcohol - Config.Stages.Hysteresis and vomit(src, rec, now) then
        rec.nextNausea = now + randomSeconds(cfg.RepeatDelay) / tendency
    else
        if result == 'resisted' then notify(src, L('nausea_resisted'), 'inform') end
        rec.nextNausea = now + (result == 'resisted' and cfg.SuccessDelay * 1000 or randomSeconds(cfg.RepeatDelay) / tendency)
    end
end)

local function startBlackout(src, rec, now)
    rec.blackout = { token = newToken(), expires = now + 10000 }
    TriggerClientEvent(EVENT .. ':client:blackout', src, rec.blackout.token, Config.Blackout.Duration * 1000, Config.Blackout.HealthLoss)
end

local function postponeBlackout(rec, now)
    rec.blackout = nil
    rec.lastBlackout = now - Config.Blackout.Cooldown * 1000 + Config.Blackout.RetryDelay * 1000
end

local function processBlackout(src, rec, now, rollChance)
    local cfg = Config.Blackout
    local blackout = rec.blackout

    if blackout then
        if not blackout.ends and now > blackout.expires then
            postponeBlackout(rec, now)
        elseif blackout.ends and now >= blackout.ends then
            rec.blackout = nil
            rec.lastBlackout = now
            setAlcohol(src, rec.alcohol - cfg.AlcoholReduction, nil, 'blackout')
        end
        return
    end

    if not rollChance or not cfg.Enabled or rec.stage < 4 or rec.nausea then return end
    if now < rec.lastBlackout + cfg.Cooldown * 1000 then return end

    local chance = cfg.Chance * (Utils.GetProfile(rec.profile).blackout or 1.0)
    if math.random() < chance then startBlackout(src, rec, now) end
end

RegisterNetEvent(EVENT .. ':server:blackoutResponse', function(token, accepted)
    local src = source
    local rec = players[src]
    local blackout = rec and rec.blackout
    if not blackout or blackout.ends or blackout.token ~= token then return end

    local now = GetGameTimer()
    if accepted == true then
        local cfg = Config.Blackout
        blackout.ends = now + cfg.Duration * 1000 + cfg.FadeOut + cfg.FadeIn
    else
        postponeBlackout(rec, now)
    end
end)

---------------------------------------------------------------------
-- Main loop: metabolism, nausea and blackout scheduling for intoxicated players only
---------------------------------------------------------------------
CreateThread(function()
    local nextMetabolism, nextSave = 0, 0

    while true do
        Wait(1000)
        local now = GetGameTimer()
        local metabolism = now >= nextMetabolism
        if metabolism then nextMetabolism = now + Config.Metabolism.Interval * 1000 end

        for src, rec in pairs(players) do
            if rec.alcohol > 0 or rec.blackout then
                processBlackout(src, rec, now, metabolism)

                if metabolism and rec.alcohol > 0 then
                    local boost = now < rec.boostUntil and rec.boostMult or 1.0
                    local mult = (Utils.GetProfile(rec.profile).metabolismMultiplier or 1.0) * boost * Tolerance.MetabolismMult(rec)
                    setAlcohol(src, rec.alcohol - Utils.MetabolismRate(rec.stage) * mult, nil, 'metabolism')
                end

                processNausea(src, rec, now)
            end
        end

        if now >= nextSave then
            nextSave = now + Config.Persistence.SaveInterval * 1000
            for _, rec in pairs(players) do saveRecord(rec) end
        end
    end
end)

---------------------------------------------------------------------
-- Death (client report, validated on the server)
---------------------------------------------------------------------
RegisterNetEvent(EVENT .. ':server:died', function()
    local src = source
    local rec = players[src]
    if not Config.ResetOnDeath or not rec or rec.alcohol <= 0 then return end

    local now = GetGameTimer()
    if now - rec.lastDeath < 10000 then return end
    rec.lastDeath = now

    -- Medical resources may flag the death slightly later, so check a few times
    local attempts = 0
    local function check()
        attempts = attempts + 1
        if players[src] ~= rec then return end
        if Bridge.IsDead(src) then
            resetPlayer(src, 'death')
        elseif attempts < 3 then
            SetTimeout(1500, check)
        end
    end
    check()
end)

---------------------------------------------------------------------
-- Player lifecycle & persistence
---------------------------------------------------------------------
local function loadPlayer(src)
    local id = Bridge.GetIdentifier(src)
    if not id then return end

    local existing = players[src]
    if existing and existing.id == id then return end
    if existing then saveRecord(existing) end

    players[src] = nil
    local rec = getRecord(src, true)
    rec.id = id

    local data = Persistence.Load(id)
    if data then
        local time = os.time()

        if Config.Tolerance.Persist and data.tolerance then
            rec.tolerance = data.tolerance
            rec.lastDrink = data.lastDrink or 0
            rec.toleranceCheck = data.toleranceCheck or 0
            Tolerance.Decay(rec, time)
        end

        if Config.Persistence.Enabled and (data.alcohol or 0) > 0 then
            local alcohol = data.alcohol
            if Config.Persistence.OfflineMetabolism then
                alcohol = Persistence.SimulateOffline(alcohol, data.profile, time - (data.time or time))
            end
            rec.stage = Utils.GetStage(alcohol, 0)
            setAlcohol(src, alcohol, data.profile, 'restore')
        end
    end

    publish(src, rec)
    saveRecord(rec) -- drops stale alcohol data that metabolised away while offline
    Utils.Debug(('Loaded player %s (%s) alcohol=%s tolerance=%s'):format(src, id, rec.alcohol, rec.tolerance))
end

local function unloadPlayer(src, dropped)
    local rec = players[src]
    if not rec then return end

    saveRecord(rec)
    players[src] = nil

    if not dropped then
        clearState(src, rec)
        TriggerClientEvent(EVENT .. ':client:sync', src, 0, 0, nil)
        TriggerClientEvent(EVENT .. ':client:reset', src)
    end
end

Bridge.OnPlayerLoaded(function(src) loadPlayer(tonumber(src)) end)
Bridge.OnPlayerUnloaded(function(src) unloadPlayer(tonumber(src), false) end)

AddEventHandler('playerDropped', function()
    unloadPlayer(source, true)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, id in ipairs(GetPlayers()) do
        loadPlayer(tonumber(id))
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src, rec in pairs(players) do
        saveRecord(rec)
        clearState(src, rec)
    end
end)

Inventory.Init(function(src, itemName)
    if not consumeDrink(src, itemName) then
        consumeRecovery(src, itemName)
    end
end)

---------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------
local function getPublished(src, key, default)
    local rec = players[tonumber(src)]
    local value = rec and rec.pub[key]
    if value == nil then return default end
    return value
end

exports('GetPlayerAlcohol', function(src) return getPublished(src, 'alcohol', 0) end)
exports('GetPlayerAlcoholStage', function(src) return getPublished(src, 'alcoholStage', 0) end)
exports('GetPlayerAlcoholProfile', function(src) return getPublished(src, 'alcoholType', nil) end)
exports('GetPlayerBAC', function(src) return getPublished(src, 'bac', 0.0) end)
exports('IsPlayerIntoxicated', function(src) return getPublished(src, 'intoxicated', false) end)

local function getTolerance(src)
    local rec = players[tonumber(src)]
    return (rec and Tolerance.Active()) and math.floor(rec.tolerance) or 0
end

exports('GetPlayerTolerance', getTolerance)

exports('GetPlayerIntoxication', function(src)
    return {
        alcohol = getPublished(src, 'alcohol', 0),
        stage = getPublished(src, 'alcoholStage', 0),
        profile = getPublished(src, 'alcoholType', nil),
        bac = getPublished(src, 'bac', 0.0),
        intoxicated = getPublished(src, 'intoxicated', false),
        tolerance = getTolerance(src),
    }
end)

exports('SetPlayerTolerance', function(src, amount)
    src = validPlayer(src)
    if not src or not Tolerance.Active() or not tonumber(amount) then return false end
    local rec = getRecord(src, true)
    rec.tolerance = Utils.Clamp(tonumber(amount), 0, 100)
    if rec.lastDrink == 0 then rec.lastDrink = os.time() end -- lets decay start from now
    publish(src, rec)
    saveRecord(rec)
    return math.floor(rec.tolerance)
end)

exports('SetPlayerAlcohol', function(src, amount, profile)
    src = validPlayer(src)
    if not src then return false end
    return setAlcohol(src, amount, profile, 'export')
end)

exports('AddPlayerAlcohol', function(src, amount, profile)
    src = validPlayer(src)
    if not src or not tonumber(amount) then return false end
    local rec = getRecord(src, true)
    return setAlcohol(src, rec.alcohol + tonumber(amount), profile, 'export')
end)

exports('ReducePlayerAlcohol', function(src, amount)
    src = validPlayer(src)
    local rec = src and players[src]
    if not rec or not tonumber(amount) then return false end
    return setAlcohol(src, rec.alcohol - tonumber(amount), nil, 'export')
end)

exports('ResetPlayerAlcohol', function(src)
    src = validPlayer(src)
    if not src then return false end
    resetPlayer(src, 'export')
    return true
end)

--- Runs the full drink logic (profile, tolerance, notifications) for a configured drink or recovery item.
exports('ConsumeItem', function(src, itemName)
    src = validPlayer(src)
    if not src then return false end
    return consumeDrink(src, itemName) or consumeRecovery(src, itemName)
end)

---------------------------------------------------------------------
-- Admin & debug commands
---------------------------------------------------------------------
local restricted = Config.DebugPermission

local function reply(source, msg, type)
    if source == 0 then print(msg) else notify(source, msg, type) end
end

local function resolveTarget(source, target)
    target = validPlayer(target or source)
    if not target then reply(source, L('invalid_player'), 'error') end
    return target
end

if Config.AdminCommand or Config.Debug then
    lib.addCommand('setalcohol', {
        help = L('cmd_setalcohol'),
        params = {
            { name = 'target', type = 'playerId', help = L('param_target') },
            { name = 'amount', type = 'number', help = L('param_amount') },
            { name = 'profile', type = 'string', help = L('param_profile'), optional = true },
        },
        restricted = restricted,
    }, function(source, args)
        local target = resolveTarget(source, args.target)
        if not target then return end
        if args.profile and not Config.Profiles[args.profile] then
            return reply(source, L('invalid_profile', args.profile), 'error')
        end
        local value = setAlcohol(target, args.amount, args.profile, 'admin')
        reply(source, L('alcohol_set', target, value, players[target].profile or '-'), 'success')
    end)
end

-- Test commands, only registered when Config.Debug is enabled
if Config.Debug then
    local function testCommand(name, fn)
        lib.addCommand(name, {
            help = L('cmd_' .. name),
            params = { { name = 'target', type = 'playerId', help = L('param_target'), optional = true } },
            restricted = restricted,
        }, function(source, args)
            local target = resolveTarget(source, args.target)
            if not target then return end
            fn(target, getRecord(target, true), GetGameTimer())
            reply(source, L('test_triggered', target), 'inform')
        end)
    end

    testCommand('testnausea', function(target, rec, now)
        if not rec.nausea then startNausea(target, rec, now) end
    end)

    testCommand('testvomit', function(target)
        TriggerClientEvent(EVENT .. ':client:vomit', target, 0)
    end)

    testCommand('testblackout', function(target, rec, now)
        if not rec.blackout then startBlackout(target, rec, now) end
    end)
end
