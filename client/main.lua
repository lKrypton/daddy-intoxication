local EVENT = 'daddy-intoxication'

-- Local mirror of the server state. The client never decides these values.
Intox = {
    alcohol = 0,
    stage = 0,
    profile = nil,
    busy = false,      -- nausea / vomit sequence running
    blackout = false,
}

local function applyState(alcohol, stage, profile)
    alcohol = tonumber(alcohol) or 0
    stage = tonumber(stage) or 0
    if stage == 0 and alcohol == 0 then profile = nil end

    if alcohol == Intox.alcohol and stage == Intox.stage and profile == Intox.profile then return end

    local oldStage = Intox.stage
    Intox.alcohol, Intox.stage, Intox.profile = alcohol, stage, profile

    Effects.Update(stage, profile)
    Audio.Update(alcohol, stage)

    if stage ~= oldStage then
        TriggerEvent(EVENT .. ':client:stageChanged', stage, oldStage)
    end
    TriggerEvent(EVENT .. ':client:alcoholChanged', alcohol, stage, profile, Utils.GetBAC(alcohol))
end

RegisterNetEvent(EVENT .. ':client:sync', applyState)

RegisterNetEvent(EVENT .. ':client:notify', function(msg, type)
    Bridge.Notify(msg, type)
end)

RegisterNetEvent(EVENT .. ':client:drank', function(profileName)
    Audio.OnDrink(Utils.GetProfile(profileName))
end)

RegisterNetEvent(EVENT .. ':client:reset', function()
    Actions.Abort()
end)

-- Pick up state that was published before this script started (resource restart, late join)
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    Wait(1000)
    local state = LocalPlayer.state
    applyState(state.alcohol or 0, state.alcoholStage or 0, state.alcoholType)
end)

---------------------------------------------------------------------
-- Death reporting (the server validates it before resetting)
---------------------------------------------------------------------
local lastDeathReport = 0

local function reportDeath()
    Actions.Abort()
    if not Config.ResetOnDeath or Intox.alcohol <= 0 then return end

    local now = GetGameTimer()
    if now - lastDeathReport < 10000 then return end
    lastDeathReport = now
    TriggerServerEvent(EVENT .. ':server:died')
end

AddEventHandler('gameEventTriggered', function(name, data)
    if name ~= 'CEventNetworkEntityDamage' or data[1] ~= cache.ped then return end
    if IsPedDeadOrDying(cache.ped, true) then reportDeath() end
end)

AddStateBagChangeHandler('isDead', ('player:%s'):format(cache.serverId), function(_, _, value)
    if value then reportDeath() end
end)

---------------------------------------------------------------------
-- Cleanup
---------------------------------------------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Actions.Cleanup()
    Driving.Cleanup()
    Effects.ClearAll()
    Audio.StopAll()
end)

---------------------------------------------------------------------
-- Exports (read-only; alcohol can only be changed on the server)
---------------------------------------------------------------------
local function isIntoxicated()
    return Intox.stage >= Config.Stages.IntoxicatedFrom
end

exports('GetAlcohol', function() return Intox.alcohol end)
exports('GetAlcoholStage', function() return Intox.stage end)
exports('GetAlcoholProfile', function() return Intox.profile end)
exports('GetBAC', function() return Utils.GetBAC(Intox.alcohol) end)
exports('GetTolerance', function() return LocalPlayer.state.alcoholTolerance or 0 end)
exports('IsIntoxicated', isIntoxicated)

exports('GetIntoxication', function()
    return {
        alcohol = Intox.alcohol,
        stage = Intox.stage,
        profile = Intox.profile,
        bac = Utils.GetBAC(Intox.alcohol),
        intoxicated = isIntoxicated(),
        tolerance = LocalPlayer.state.alcoholTolerance or 0,
    }
end)

--- Lets other resources block forced animations (vomit, blackout, falls) while they run their own.
exports('SetActionsBlocked', function(key, blocked)
    Actions.SetBlocked(key, blocked)
end)

--- Plays the vomit sequence only (e.g. for food poisoning scripts). Does not change alcohol.
exports('PlayVomit', function()
    CreateThread(function() Actions.PlayVomit(0) end)
end)
