Bridge = {}

function Bridge.IsStarted(resource)
    local state = GetResourceState(resource)
    return state == 'started' or state == 'starting'
end

local function detectFramework()
    if Config.Framework ~= 'auto' then return Config.Framework end
    if Bridge.IsStarted('qbx_core') then return 'qbox' end
    if Bridge.IsStarted('qb-core') then return 'qbcore' end
    if Bridge.IsStarted('es_extended') then return 'esx' end
    return 'standalone'
end

Bridge.Framework = detectFramework()
