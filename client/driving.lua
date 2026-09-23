Driving = {}

local lastVehicle = nil

local function resetBias()
    if lastVehicle and DoesEntityExist(lastVehicle) then
        SetVehicleSteerBias(lastVehicle, 0.0)
    end
    lastVehicle = nil
end

function Driving.Cleanup()
    resetBias()
end

local function disableSteering()
    DisableControlAction(0, 59, true) -- INPUT_VEH_MOVE_LR
    DisableControlAction(0, 63, true) -- INPUT_VEH_MOVE_LEFT_ONLY
    DisableControlAction(0, 64, true) -- INPUT_VEH_MOVE_RIGHT_ONLY
end

-- Frame-level logic only while intoxicated, driving and moving; otherwise long sleeps.
CreateThread(function()
    local bias, drift = 0.0, 0.0
    local nextDrift, nextLag, lagUntil, nextHorn = 0, 0, 0, 0

    while true do
        local cfg = Config.Driving
        local sleep = 2000
        local vehicle = cache.vehicle
        local active = cfg.Mode ~= 'off' and Intox.stage >= cfg.MinStage and not Intox.blackout

        if active and vehicle and cache.seat == -1 then
            sleep = 500
            local speed = GetEntitySpeed(vehicle)

            if speed >= cfg.MinSpeed then
                sleep = 0
                lastVehicle = vehicle
                local now = GetGameTimer()
                local stage = Intox.stage

                -- Pick a new drift target now and then; easing toward it gives drift followed by correction
                if now >= nextDrift then
                    local strength = Utils.StageValue(cfg.Sway.Strength, stage) or 0.0
                    if speed > cfg.HighSpeed then strength = strength * cfg.HighSpeedScale end
                    drift = math.random() < cfg.Sway.Chance and (math.random() < 0.5 and -strength or strength) or 0.0
                    nextDrift = now + math.random(cfg.Sway.IntervalMin, cfg.Sway.IntervalMax)
                end
                bias = bias + (drift - bias) * cfg.Sway.Smoothing

                if cfg.Mode == 'inverted' and stage >= cfg.Inverted.MinStage then
                    disableSteering()
                    local input = GetDisabledControlNormal(0, 59)
                    if IsDisabledControlPressed(0, 63) then input = -1.0
                    elseif IsDisabledControlPressed(0, 64) then input = 1.0 end
                    SetVehicleSteerBias(vehicle, -input * cfg.Inverted.Strength + bias)
                else
                    if cfg.Mode == 'reduced_control' then
                        local lag = cfg.ReducedControl
                        if nextLag == 0 then nextLag = now + math.random(lag.IntervalMin, lag.IntervalMax) end
                        if now >= nextLag then
                            lagUntil = now + math.random(lag.DurationMin, lag.DurationMax)
                            nextLag = lagUntil + math.random(lag.IntervalMin, lag.IntervalMax)
                        end
                        if now < lagUntil then disableSteering() end
                    end
                    SetVehicleSteerBias(vehicle, bias)
                end

                local horn = cfg.Horn
                if stage >= horn.MinStage and now >= nextHorn then
                    if nextHorn > 0 and math.random() < horn.Chance then
                        StartVehicleHorn(vehicle, 600, `HELDDOWN`, false)
                    end
                    nextHorn = now + math.random(horn.IntervalMin, horn.IntervalMax)
                end
            end
        end

        if sleep > 0 then
            if lastVehicle then resetBias() end
            bias, drift, nextLag, lagUntil = 0.0, 0.0, 0, 0
        end

        Wait(sleep)
    end
end)
