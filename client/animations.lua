local EVENT = 'daddy-intoxication'

Actions = {}

local blocks = {}          -- [resource:key] = true, set by other resources through the export
local activePtfx = nil
local activeAnim = nil     -- { dict, name } of an animation this resource started
local screenFaded = false

---------------------------------------------------------------------
-- State checks
---------------------------------------------------------------------
function Actions.SetBlocked(key, blocked)
    local resource = GetInvokingResource() or GetCurrentResourceName()
    blocks[('%s:%s'):format(resource, tostring(key))] = blocked and true or nil
end

-- Drop blocks owned by a resource that stopped
AddEventHandler('onClientResourceStop', function(resource)
    local prefix = resource .. ':'
    for key in pairs(blocks) do
        if key:sub(1, #prefix) == prefix then blocks[key] = nil end
    end
end)

local function isCarryingOrCarried(ped)
    if IsEntityAttached(ped) then return true end
    for _, player in ipairs(GetActivePlayers()) do
        local other = GetPlayerPed(player)
        if other ~= ped and IsEntityAttachedToEntity(other, ped) then return true end
    end
    return false
end

--- True when a forced animation, ragdoll or blackout would break another system.
function Actions.IsBlocked(ped, allowVehicle)
    if next(blocks) then return true end
    if IsPedDeadOrDying(ped, true) or IsPedFatallyInjured(ped) then return true end
    if IsPedCuffed(ped) or IsPedRagdoll(ped) or IsPedFalling(ped) then return true end
    if IsPedClimbing(ped) or IsPedVaulting(ped) or IsPedJumping(ped) then return true end
    if IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped) then return true end
    if GetPedParachuteState(ped) ~= -1 then return true end
    if IsPedUsingAnyScenario(ped) then return true end
    if not allowVehicle and IsPedInAnyVehicle(ped, true) then return true end

    local state = LocalPlayer.state
    for _, key in ipairs(Config.BlockingStates) do
        if state[key] then return true end
    end

    if Bridge.IsRestricted() then return true end
    if isCarryingOrCarried(ped) then return true end
    if Config.IsActionBlocked and Config.IsActionBlocked(ped) then return true end
    return false
end

local function applyHealthLoss(ped, amount)
    if not amount or amount <= 0 then return end
    local health = GetEntityHealth(ped)
    -- Never kill the player: 100 is the death threshold for player peds
    if health - amount > 110 then
        SetEntityHealth(ped, health - amount)
    end
end

local function stopPtfx()
    if activePtfx and DoesParticleFxLoopedExist(activePtfx) then
        StopParticleFxLooped(activePtfx, false)
    end
    activePtfx = nil
end

local function stopOwnAnim(ped)
    if activeAnim and IsEntityPlayingAnim(ped, activeAnim[1], activeAnim[2], 3) then
        StopAnimTask(ped, activeAnim[1], activeAnim[2], 2.0)
    end
    activeAnim = nil
end

--- Plays an animation this resource can later stop without touching other tasks.
local function playAnim(ped, dict, name, duration, flag)
    if not pcall(lib.requestAnimDict, dict, 3000) then return false end
    TaskPlayAnim(ped, dict, name, 8.0, -8.0, duration, flag, 0.0, false, false, false)
    activeAnim = { dict, name }
    RemoveAnimDict(dict)
    return true
end

---------------------------------------------------------------------
-- Vomiting
---------------------------------------------------------------------
function Actions.PlayVomit(healthLoss)
    local cfg = Config.Vomit
    local ped = cache.ped

    Intox.busy = true
    Audio.Vomit(ped)
    Effects.Pulse(1.0, 2500)
    applyHealthLoss(ped, healthLoss)

    -- In a vehicle or a protected state: sound and camera only
    if cache.vehicle or Actions.IsBlocked(ped) or not playAnim(ped, cfg.AnimDict, cfg.AnimName, cfg.Duration, 0) then
        Intox.busy = false
        return
    end

    if pcall(lib.requestNamedPtfxAsset, cfg.PtfxAsset, 2000) then
        UseParticleFxAssetNextCall(cfg.PtfxAsset)
        activePtfx = StartParticleFxLoopedOnPedBone(cfg.PtfxName, ped, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, GetPedBoneIndex(ped, 31086), 1.0, false, false, false)
    end

    Wait(cfg.PtfxDuration)
    stopPtfx()
    RemoveNamedPtfxAsset(cfg.PtfxAsset)
    Wait(math.max(0, cfg.Duration - cfg.PtfxDuration))
    stopOwnAnim(ped)
    Intox.busy = false
end

RegisterNetEvent(EVENT .. ':client:vomit', function(healthLoss)
    Actions.PlayVomit(tonumber(healthLoss) or 0)
end)

---------------------------------------------------------------------
-- Nausea: warning, physical reaction, optional skill check. The server decides the outcome.
---------------------------------------------------------------------
RegisterNetEvent(EVENT .. ':client:nausea', function(token, useSkillCheck)
    local ped = cache.ped
    if Intox.busy or Intox.blackout or Actions.IsBlocked(ped, true) then
        TriggerServerEvent(EVENT .. ':server:nauseaResponse', token, 'postponed')
        return
    end

    local cfg = Config.Nausea
    Intox.busy = true
    Audio.Groan(ped)
    Effects.Pulse(0.8, 2000)
    Bridge.Notify(L('nausea_warning'), 'error')

    local reaction = cfg.ReactionAnim
    if reaction and not cache.vehicle then
        playAnim(ped, reaction.dict, reaction.name, reaction.duration, 48)
    end

    Wait(800)

    local result = 'ready'
    if useSkillCheck and lib.skillCheck then
        result = lib.skillCheck(cfg.SkillCheck.Difficulty, cfg.SkillCheck.Inputs) and 'resisted' or 'failed'
    end

    stopOwnAnim(ped)
    Intox.busy = false
    TriggerServerEvent(EVENT .. ':server:nauseaResponse', token, result)
end)

---------------------------------------------------------------------
-- Blackout (presentation only; alcohol reduction happens on the server)
---------------------------------------------------------------------
local function endBlackout(fadeIn)
    TriggerScreenblurFadeOut(fadeIn)
    if screenFaded then
        DoScreenFadeIn(fadeIn)
        screenFaded = false
    end
    Intox.blackout = false
    Audio.SetBlackout(false)
end

RegisterNetEvent(EVENT .. ':client:blackout', function(token, duration, healthLoss)
    local cfg = Config.Blackout
    local ped = cache.ped
    local vehicle = cache.vehicle
    local drivingFast = vehicle and cache.seat == -1 and GetEntitySpeed(vehicle) > 2.0

    if Intox.blackout or Intox.busy or drivingFast or Actions.IsBlocked(ped, true) then
        TriggerServerEvent(EVENT .. ':server:blackoutResponse', token, false)
        return
    end

    TriggerServerEvent(EVENT .. ':server:blackoutResponse', token, true)
    Intox.blackout = true
    Bridge.Notify(L('blackout_start'), 'error')
    Audio.SetBlackout(true)
    Audio.Vomit(ped)

    TriggerScreenblurFadeIn(cfg.FadeOut)
    DoScreenFadeOut(cfg.FadeOut)
    screenFaded = true
    Wait(cfg.FadeOut)

    local endsAt = GetGameTimer() + duration
    while Intox.blackout and GetGameTimer() < endsAt do
        ped = cache.ped
        if IsPedDeadOrDying(ped, true) then break end
        if not cache.vehicle and not IsPedRagdoll(ped) then
            SetPedToRagdoll(ped, 1500, 1500, 0, false, false, false)
        end
        Wait(500)
    end

    if not Intox.blackout then return end -- aborted (death / reset / resource stop)

    endBlackout(cfg.FadeIn)
    Wait(cfg.FadeIn)
    applyHealthLoss(cache.ped, healthLoss)
    Bridge.Notify(L('blackout_wake'), 'inform')
end)

--- Stops running presentations (called on death and server reset).
function Actions.Abort()
    if Intox.blackout then endBlackout(500) end
    stopPtfx()
end

function Actions.Cleanup()
    stopPtfx()
    stopOwnAnim(cache.ped)
    if screenFaded then
        TriggerScreenblurFadeOut(0)
        DoScreenFadeIn(0)
        screenFaded = false
    end
    Intox.blackout, Intox.busy = false, false
end

---------------------------------------------------------------------
-- Stumbling / falling
---------------------------------------------------------------------
CreateThread(function()
    local nextFall = 0

    while true do
        local cfg = Config.Falling
        if cfg.Enabled and Intox.stage >= cfg.MinStage and not Intox.blackout and not Intox.busy then
            local ped = cache.ped
            local now = GetGameTimer()

            if now >= nextFall and not cache.vehicle then
                local running = IsPedRunning(ped) or IsPedSprinting(ped)
                local chance = running and cfg.RunChance or (IsPedWalking(ped) and cfg.WalkChance or 0)

                if chance > 0 and math.random() < chance and not Actions.IsBlocked(ped) then
                    local duration = running and cfg.RunDuration or cfg.WalkDuration
                    SetPedToRagdoll(ped, duration, duration, 0, false, false, false)
                    nextFall = now + cfg.Cooldown
                end
            end

            Wait(cfg.CheckInterval)
        else
            Wait(3000)
        end
    end
end)
