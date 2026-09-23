Inventory = {}

local function resolveMode()
    local mode = Config.Inventory
    if mode == 'qb-inventory' or mode == 'qb_inventory' or mode == 'esx' then mode = 'framework' end

    if mode == 'auto' then
        if Bridge.IsStarted('ox_inventory') then return 'ox_inventory' end
        if Bridge.Framework == 'qbcore' or Bridge.Framework == 'esx' then return 'framework' end
        return 'none'
    end

    -- Qbox always runs on ox_inventory
    if mode == 'framework' and Bridge.Framework == 'qbox' then return 'ox_inventory' end
    return mode
end

Inventory.Mode = resolveMode()

local chained = {} -- [item] = usable callback of another resource we wrapped

-- Give wrapped items back to their original resource when this one stops
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for name, fn in pairs(chained) do
        pcall(Bridge.RestoreUsableItem, name, fn)
    end
end)

--- Hooks item usage for every drink and recovery item.
--- onUse(src, itemName) is called after the item has been consumed.
function Inventory.Init(onUse)
    local items = {}
    for name in pairs(Config.Drinks) do items[name] = true end
    for name in pairs(Config.RecoveryItems) do items[name] = true end

    if Inventory.Mode == 'ox_inventory' then
        -- ox_inventory consumes the item itself (set `consume` in the item definition)
        AddEventHandler('ox_inventory:usedItem', function(playerId, name)
            if items[name] then onUse(playerId, name) end
        end)
    elseif Inventory.Mode == 'framework' then
        -- Let consumable scripts (qb-smallresources, esx_basicneeds ...) register first
        CreateThread(function()
            Wait(Config.UsableItemDelay or 5000)
            local skipped = {}

            for name in pairs(items) do
                local existing = Bridge.GetExistingUsable(name)

                if existing and type(existing) ~= 'boolean' then
                    -- QBCore: keep the other script's effect (thirst, animation, item removal) and add ours
                    chained[name] = existing
                    Bridge.RegisterUsableItem(name, function(src, item)
                        -- A stale callback (e.g. left over from a restart of this resource) fails here
                        if not pcall(existing, src, item) and not Bridge.RemoveItem(src, name, item) then return end
                        onUse(src, name)
                    end)
                elseif existing then
                    -- ESX: the other callback cannot be chained, so leave it alone
                    skipped[#skipped + 1] = name
                else
                    Bridge.RegisterUsableItem(name, function(src, item)
                        if Bridge.RemoveItem(src, name, item) then
                            onUse(src, name)
                        end
                    end)
                end
            end

            if #skipped > 0 then
                print(('^3[daddy-intoxication]^7 Already usable in another resource, not hooked: %s. Call exports[\'daddy-intoxication\']:ConsumeItem(source, itemName) from that resource.'):format(table.concat(skipped, ', ')))
            end
        end)
    end

    Utils.Debug('Inventory mode:', Inventory.Mode, 'Framework:', Bridge.Framework)
end
