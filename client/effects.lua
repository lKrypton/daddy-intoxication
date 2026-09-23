Effects = {}

local cfg = Config.Effects
local current = { tc = nil, strength = 0.0, shake = 0.0 }
local target = { tc = nil, strength = 0.0, shake = 0.0 }
local shaking = false
local transitioning = false
local activePostFx = nil
local drunkFlags = false
local appliedClipset = nil

local ownIndex = -1        -- timecycle modifier index this resource set last

local function approach(value, goal, step)
    if value < goal then return math.min(goal, value + step) end
    return math.max(goal, value - step)
end

--- GTA has a single timecycle modifier slot. When another resource (a death screen, a drug
--- script) replaced ours, we forget ours instead of fading or clearing theirs.
local function ownsTimecycle()
    if not current.tc then return false end
    if GetTimecycleModifierIndex() == ownIndex then return true end
    current.tc, current.strength, ownIndex = nil, 0.0, -1
    return false
end

local function applyTimecycle(name)
    SetTimecycleModifier(name)
    SetTimecycleModifierStrength(0.0)
    ownIndex = GetTimecycleModifierIndex()
end

local function setShake(amount)
    if amount > 0.001 then
        if shaking then
            SetGameplayCamShakeAmplitude(amount)
        else
            ShakeGameplayCam(cfg.ShakeName, amount)
            shaking = true
        end
    elseif shaking then
        StopGameplayCamShaking(true)
        shaking = false
    end
end

--- Fades timecycle and camera shake toward the target. Runs only while something changes.
local function transition()
    if transitioning then return end
    transitioning = true

    CreateThread(function()
        local interval = 50
        local steps = math.max(1, cfg.TransitionTime / interval)
        local tcStep, shakeStep = 1.0 / steps, cfg.MaxShake / steps

        while true do
            local active = false

            local owned = ownsTimecycle()

            if current.tc ~= target.tc then
                active = true
                if owned and current.strength > 0 then
                    -- Fade the old modifier out before switching
                    current.strength = approach(current.strength, 0.0, tcStep)
                    SetTimecycleModifierStrength(current.strength)
                else
                    if owned then ClearTimecycleModifier() end
                    current.tc, current.strength = target.tc, 0.0
                    ownIndex = -1
                    -- Never replace a modifier another resource is showing (e.g. a death screen)
                    if current.tc and GetTimecycleModifierIndex() == -1 then
                        applyTimecycle(current.tc)
                    elseif current.tc then
                        current.tc = nil
                        target.tc = nil
                    end
                end
            elseif owned and current.strength ~= target.strength then
                active = true
                current.strength = approach(current.strength, target.strength, tcStep)
                SetTimecycleModifierStrength(current.strength)
            end

            if current.shake ~= target.shake then
                active = true
                current.shake = approach(current.shake, target.shake, shakeStep)
                setShake(current.shake)
            end

            if not active then break end
            Wait(interval)
        end

        transitioning = false
    end)
end

local function restoreMovement(ped)
    ResetPedMovementClipset(ped, Config.Movement.BlendTime)
    if appliedClipset then RemoveAnimSet(appliedClipset) end
    appliedClipset = nil
    TriggerEvent('daddy-intoxication:client:movementRestored')
    if Config.Movement.OnRestore then pcall(Config.Movement.OnRestore, ped) end
end

local function updateMovement(stage, profile)
    local clipset = Config.Movement.Enabled and stage > 0 and Utils.StageValue(profile.clipset, stage) or nil
    if clipset == appliedClipset then return end

    local ped = cache.ped
    if not clipset then
        restoreMovement(ped)
        return
    end

    if Config.Movement.CanApply and not Config.Movement.CanApply(ped) then return end
    if not pcall(lib.requestAnimSet, clipset, 3000) then return end

    SetPedMovementClipset(ped, clipset, Config.Movement.BlendTime)
    if appliedClipset then RemoveAnimSet(appliedClipset) end
    appliedClipset = clipset
end

function Effects.Update(stage, profileName)
    local profile = Utils.GetProfile(profileName)
    local enabled = cfg.Enabled and stage > 0

    if enabled then
        target.tc = profile.timecycle
        target.strength = Utils.StageValue(profile.strength, stage) or 0.5
        target.shake = Utils.StageValue(profile.shake, stage) or 0.0
    else
        target.tc, target.strength, target.shake = nil, 0.0, 0.0
    end
    transition()

    local postfx = enabled and Utils.StageValue(profile.postfx, stage) or nil
    if postfx ~= activePostFx then
        if activePostFx then AnimpostfxStop(activePostFx) end
        if postfx then AnimpostfxPlay(postfx, 0, true) end
        activePostFx = postfx
    end

    local drunk = enabled and stage >= cfg.MotionBlurStage
    if drunk ~= drunkFlags then
        SetPedMotionBlur(cache.ped, drunk)
        SetPedIsDrunk(cache.ped, drunk)
        drunkFlags = drunk
    end

    updateMovement(stage, profile)
end

--- Short camera jolt on top of the current drunk shake.
function Effects.Pulse(amount, duration)
    if not cfg.Pulses then return end
    setShake(current.shake + amount)
    SetTimeout(duration or 1500, function()
        setShake(current.shake)
    end)
end

function Effects.ClearAll()
    if ownsTimecycle() then ClearTimecycleModifier() end
    ownIndex = -1
    current.tc, current.strength, current.shake = nil, 0.0, 0.0
    target.tc, target.strength, target.shake = nil, 0.0, 0.0

    if shaking then
        StopGameplayCamShaking(true)
        shaking = false
    end
    if activePostFx then
        AnimpostfxStop(activePostFx)
        activePostFx = nil
    end
    if drunkFlags then
        SetPedMotionBlur(cache.ped, false)
        SetPedIsDrunk(cache.ped, false)
        drunkFlags = false
    end
    if appliedClipset then restoreMovement(cache.ped) end
end

-- Reapply the clipset after respawn / ped model change
lib.onCache('ped', function(ped)
    if appliedClipset then
        SetPedMovementClipset(ped, appliedClipset, Config.Movement.BlendTime)
    end
    if drunkFlags then
        SetPedMotionBlur(ped, true)
        SetPedIsDrunk(ped, true)
    end
end)
