Utils = {}

--- Returns a translated string, falling back to English and then to the key itself.
function L(key, ...)
    local lang = Locales[Config.Locale] or Locales.en
    local str = lang[key] or Locales.en[key] or key
    if select('#', ...) > 0 then
        return str:format(...)
    end
    return str
end

function Utils.Clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function Utils.Round(value, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(value * mult + 0.5) / mult
end

--- Stage for the given points. Moving up is immediate; moving down waits until the
--- points drop Hysteresis below the current stage threshold. Used by the server only.
function Utils.GetStage(points, current)
    if points <= 0 then return 0 end

    local thresholds = Config.Stages.Thresholds
    local margin = Config.Stages.Hysteresis or 0
    local target = 0

    for i = #thresholds, 1, -1 do
        if points >= thresholds[i] then
            target = i
            break
        end
    end

    current = current or 0
    if target >= current then return target end

    for stage = current, target + 1, -1 do
        if points >= thresholds[stage] - margin then
            return stage
        end
    end

    return target
end

function Utils.GetBAC(points)
    if Config.BAC.Convert then
        return Config.BAC.Convert(points)
    end
    return Utils.Round(points / Config.MaxAlcohol * Config.BAC.Max, Config.BAC.Decimals)
end

function Utils.GetProfile(name)
    return Config.Profiles[name] or Config.Profiles[Config.DefaultProfile]
end

--- Value for a stage from a 1-4 table; missing stages use the closest lower stage.
function Utils.StageValue(tbl, stage)
    if not tbl then return nil end
    for s = stage, 1, -1 do
        if tbl[s] ~= nil then return tbl[s] end
    end
    return nil
end

function Utils.MetabolismRate(stage)
    local rates = Config.Metabolism.Rates
    return rates[stage] or rates[#rates] or 1
end

function Utils.Debug(...)
    if not Config.Debug then return end
    local parts = { ... }
    for i = 1, select('#', ...) do parts[i] = tostring(parts[i]) end
    print(('^3[daddy-intoxication]^7 %s'):format(table.concat(parts, ' ')))
end
