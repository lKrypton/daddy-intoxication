-- Per-character storage in resource KVP. Works the same on every framework and needs no database.
Persistence = {}

local function key(identifier)
    return ('intox:%s'):format(identifier)
end

function Persistence.Load(identifier)
    local raw = GetResourceKvpString(key(identifier))
    return raw and json.decode(raw) or nil
end

function Persistence.Save(identifier, rec)
    local data, hasData = {}, false

    if Config.Persistence.Enabled and rec.alcohol > 0 then
        data.alcohol = Utils.Round(rec.alcohol, 2)
        data.profile = rec.profile
        data.time = os.time()
        hasData = true
    end

    if Config.Tolerance.Persist and rec.tolerance > 0 then
        data.tolerance = Utils.Round(rec.tolerance, 2)
        data.lastDrink = rec.lastDrink
        data.toleranceCheck = rec.toleranceCheck
        hasData = true
    end

    if hasData then
        SetResourceKvp(key(identifier), json.encode(data))
    else
        DeleteResourceKvp(key(identifier))
    end
end

--- Alcohol left after `seconds` of metabolism while offline.
function Persistence.SimulateOffline(alcohol, profileName, seconds)
    local ticks = math.floor(math.max(0, seconds) / Config.Metabolism.Interval)
    local mult = Utils.GetProfile(profileName).metabolismMultiplier or 1.0
    local stage = Utils.GetStage(alcohol, 0)

    for _ = 1, math.min(ticks, 5000) do
        alcohol = alcohol - Utils.MetabolismRate(stage) * mult
        if alcohol <= 0 then return 0 end
        stage = Utils.GetStage(alcohol, stage)
    end

    return alcohol
end
