Audio = {}

local cfg = Config.Audio
local sounds = {}          -- [key] = sound id, every looped sound is tracked here
local blackoutScene = false
local lastTinnitus = 0

local function playLoop(key, name, set)
    if sounds[key] then return end
    local id = GetSoundId()
    PlaySoundFrontend(id, name, set, true)
    sounds[key] = id
end

local function stopLoop(key)
    local id = sounds[key]
    if not id then return end
    StopSound(id)
    ReleaseSoundId(id)
    sounds[key] = nil
end

local function speech(ped, name)
    if name then PlayPedAmbientSpeechNative(ped, name, 'SPEECH_PARAMS_FORCE') end
end

function Audio.Hiccup(ped)
    speech(ped, cfg.Hiccups.Speech)
    Effects.Pulse(0.4, 600)
end

function Audio.Groan(ped)
    speech(ped, cfg.Groans.Speech)
end

function Audio.Vomit(ped)
    speech(ped, cfg.Vomit.Speech)
end

function Audio.Tinnitus()
    local tinnitus = cfg.Tinnitus
    if not tinnitus.Enabled or sounds.tinnitus then return end

    local now = GetGameTimer()
    if now - lastTinnitus < tinnitus.Cooldown then return end
    lastTinnitus = now

    playLoop('tinnitus', tinnitus.SoundName, tinnitus.SoundSet)
    SetTimeout(tinnitus.Duration, function() stopLoop('tinnitus') end)
end

function Audio.OnDrink(profile)
    local ped = cache.ped
    if profile.burp and cfg.Burp.Enabled and math.random() < cfg.Burp.Chance then
        SetTimeout(1200, function() speech(ped, cfg.Burp.Speech) end)
    end
    if profile.tinnitus or Intox.alcohol >= cfg.Tinnitus.MinAlcohol then
        Audio.Tinnitus()
    end
end

function Audio.Update(alcohol)
    local heartbeat = cfg.Heartbeat
    if heartbeat.Enabled and (alcohol >= heartbeat.MinAlcohol or Intox.blackout) then
        playLoop('heartbeat', heartbeat.SoundName, heartbeat.SoundSet)
    else
        stopLoop('heartbeat')
    end
end

--- Muffles the world and forces the heartbeat while blacked out.
function Audio.SetBlackout(active)
    if cfg.BlackoutScene then
        if active and not blackoutScene then
            StartAudioScene(cfg.BlackoutScene)
            blackoutScene = true
        elseif not active and blackoutScene then
            StopAudioScene(cfg.BlackoutScene)
            blackoutScene = false
        end
    end
    Audio.Update(Intox.alcohol)
end

function Audio.StopAll()
    for key in pairs(sounds) do stopLoop(key) end
    if blackoutScene then
        StopAudioScene(cfg.BlackoutScene)
        blackoutScene = false
    end
end

-- Ambient hiccups and groans; sleeps long and does nothing while sober
CreateThread(function()
    local nextHiccup, nextGroan = 0, 0

    while true do
        local stage = Intox.stage
        if stage > 0 and not Intox.blackout and not Intox.busy and not IsPedDeadOrDying(cache.ped, true) then
            local now = GetGameTimer()
            local hiccups, groans = cfg.Hiccups, cfg.Groans

            if hiccups.Enabled and stage >= hiccups.MinStage and stage <= hiccups.MaxStage then
                if nextHiccup == 0 then
                    nextHiccup = now + math.random(hiccups.IntervalMin, hiccups.IntervalMax)
                elseif now >= nextHiccup then
                    Audio.Hiccup(cache.ped)
                    nextHiccup = now + math.random(hiccups.IntervalMin, hiccups.IntervalMax)
                end
            end

            if groans.Enabled and stage >= groans.MinStage then
                if nextGroan == 0 then
                    nextGroan = now + math.random(groans.IntervalMin, groans.IntervalMax)
                elseif now >= nextGroan then
                    Audio.Groan(cache.ped)
                    nextGroan = now + math.random(groans.IntervalMin, groans.IntervalMax)
                end
            end

            Wait(2000)
        else
            nextHiccup, nextGroan = 0, 0
            Wait(5000)
        end
    end
end)

---------------------------------------------------------------------
-- Voice (pma-voice)
-- Every client registers the drunk submixes. The server sets the drunk player's
-- `submix` state bag and pma-voice applies it for everyone listening to that player.
---------------------------------------------------------------------
local submixIds = {}

local function createSubmix(name, params)
    local id = CreateAudioSubmix(name)
    SetAudioSubmixEffectRadioFx(id, 0)
    SetAudioSubmixEffectParamInt(id, 0, `default`, 1)
    SetAudioSubmixEffectParamFloat(id, 0, `freq_low`, params.freqLow)
    SetAudioSubmixEffectParamFloat(id, 0, `freq_hi`, params.freqHigh)
    SetAudioSubmixEffectParamFloat(id, 0, `fudge`, params.fudge)
    SetAudioSubmixEffectParamFloat(id, 0, `rm_mix`, params.rmMix)
    AddAudioSubmixOutput(id, 0)
    return id
end

local function registerVoiceSubmixes()
    local voice = Config.Voice
    if not voice.Enabled or not Bridge.IsStarted(voice.Resource) then return end

    for name, params in pairs(voice.Submixes) do
        submixIds[name] = submixIds[name] or createSubmix(name, params)
        local id = submixIds[name]
        local ok = pcall(function()
            exports[voice.Resource]:registerCustomSubmix(function() return { name, id } end)
        end)
        Utils.Debug('Voice submix', name, ok and 'registered' or 'failed')
    end
end

-- pma-voice fires this when it (re)starts
AddEventHandler('pma-voice:registerCustomSubmixes', registerVoiceSubmixes)
CreateThread(registerVoiceSubmixes)
