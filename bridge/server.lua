local framework = Bridge.Framework
local QBCore, ESX

if framework == 'qbcore' then
    QBCore = exports['qb-core']:GetCoreObject()
elseif framework == 'esx' then
    ESX = exports.es_extended:getSharedObject()
end

local function getPlayer(src)
    if framework == 'qbox' then return exports.qbx_core:GetPlayer(src) end
    if framework == 'qbcore' then return QBCore.Functions.GetPlayer(src) end
    if framework == 'esx' then return ESX.GetPlayerFromId(src) end
end

--- Character identifier, or nil while no character is loaded.
function Bridge.GetIdentifier(src)
    if framework == 'standalone' then
        return GetPlayerIdentifierByType(src, 'license')
    end
    local player = getPlayer(src)
    if not player then return nil end
    if framework == 'esx' then return player.identifier end
    return player.PlayerData.citizenid
end

function Bridge.OnPlayerLoaded(cb)
    if framework == 'qbox' or framework == 'qbcore' then
        AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
            cb(player.PlayerData.source)
        end)
    elseif framework == 'esx' then
        AddEventHandler('esx:playerLoaded', function(src) cb(src) end)
    else
        AddEventHandler('playerJoining', function() cb(source) end)
    end
end

function Bridge.OnPlayerUnloaded(cb)
    if framework == 'qbox' or framework == 'qbcore' then
        AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) cb(src) end)
    elseif framework == 'esx' then
        AddEventHandler('esx:playerDropped', function(src) cb(src) end)
    end
end

--- Server-side death check used to validate client death reports.
function Bridge.IsDead(src)
    local ped = GetPlayerPed(src)
    if ped ~= 0 and GetEntityHealth(ped) <= 100 then return true end

    local state = Player(src).state
    if state.isDead or state.inLastStand then return true end

    if framework == 'qbox' or framework == 'qbcore' then
        local player = getPlayer(src)
        local meta = player and player.PlayerData.metadata
        if meta and (meta.isdead or meta.inlaststand) then return true end
    end

    return false
end

--- Usable callback another resource already registered for this item (QBCore only; ESX
--- exposes names but not callbacks). Returns the callback, true (ESX, name known) or nil.
function Bridge.GetExistingUsable(name)
    if framework == 'qbcore' then
        local ok, fn = pcall(QBCore.Functions.CanUseItem, name)
        return ok and fn or nil
    elseif framework == 'esx' then
        local ok, usable = pcall(ESX.GetUsableItems)
        return ok and type(usable) == 'table' and usable[name] and true or nil
    end
end

--- Hands an item back to the callback of the resource that owned it (no wrapper of ours,
--- so it keeps working after this resource stops).
function Bridge.RestoreUsableItem(name, fn)
    if framework == 'qbcore' then
        QBCore.Functions.CreateUseableItem(name, fn)
    end
end

function Bridge.RegisterUsableItem(name, cb)
    if framework == 'qbcore' then
        QBCore.Functions.CreateUseableItem(name, function(src, item) cb(src, item) end)
    elseif framework == 'esx' then
        ESX.RegisterUsableItem(name, function(src, _, item) cb(src, item) end)
    end
end

--- Removes one item for framework usable items. Returns true when an item was removed.
function Bridge.RemoveItem(src, name, item)
    if framework == 'qbcore' then
        local player = getPlayer(src)
        return player and player.Functions.RemoveItem(name, 1, item and item.slot) or false
    elseif framework == 'esx' then
        local player = getPlayer(src)
        local invItem = player and player.getInventoryItem(name)
        if not invItem or (invItem.count or 0) < 1 then return false end
        player.removeInventoryItem(name, 1)
        return true
    end
    return false
end
