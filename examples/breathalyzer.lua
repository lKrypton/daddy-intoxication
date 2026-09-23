--[[
    Example breathalyzer integration. This file is NOT loaded by daddy-intoxication.
    Copy it into your own police resource (server side) and adapt it.

    Usage: /breathalyzer [id]  (the target must be within 3 meters)
]]

local RESOURCE = 'daddy-intoxication'
local LEGAL_LIMIT = 0.08 -- gameplay value, adjust to your server rules

RegisterCommand('breathalyzer', function(source, args)
    local target = tonumber(args[1])
    if not target or not GetPlayerName(target) then return end

    local officerCoords = GetEntityCoords(GetPlayerPed(source))
    local targetCoords = GetEntityCoords(GetPlayerPed(target))
    if #(officerCoords - targetCoords) > 3.0 then return end

    local bac = exports[RESOURCE]:GetPlayerBAC(target)
    local result = ('BAC: %.3f (%s)'):format(bac, bac >= LEGAL_LIMIT and 'OVER THE LIMIT' or 'under the limit')

    TriggerClientEvent('chat:addMessage', source, { args = { 'Breathalyzer', result } })
end, false)
