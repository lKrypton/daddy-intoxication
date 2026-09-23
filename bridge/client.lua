local framework = Bridge.Framework
local QBCore, ESX

if framework == 'qbcore' then
    QBCore = exports['qb-core']:GetCoreObject()
elseif framework == 'esx' then
    ESX = exports.es_extended:getSharedObject()
end

local function frameworkNotify(msg, type)
    if framework == 'qbox' then
        exports.qbx_core:Notify(msg, type)
        return true
    elseif framework == 'qbcore' then
        QBCore.Functions.Notify(msg, type == 'inform' and 'primary' or type)
        return true
    elseif framework == 'esx' then
        ESX.ShowNotification(msg, type == 'inform' and 'info' or type)
        return true
    end
    return false
end

--- type: 'inform', 'success' or 'error'
function Bridge.Notify(msg, type)
    type = type or 'inform'

    if Config.Notify == 'framework' and frameworkNotify(msg, type) then return end

    if Config.Notify ~= 'native' then
        lib.notify({ description = msg, type = type })
        return
    end

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, false)
end

--- Framework-level states (dead, last stand, handcuffed) that block forced animations.
function Bridge.IsRestricted()
    local data
    if framework == 'qbox' then
        data = exports.qbx_core:GetPlayerData()
    elseif framework == 'qbcore' then
        data = QBCore.Functions.GetPlayerData()
    end

    local meta = data and data.metadata
    return meta and (meta.isdead or meta.inlaststand or meta.ishandcuffed) or false
end
