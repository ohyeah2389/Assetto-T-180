-- T-180 CSP Physics Script - Turbine FADEC Module
-- Authored by ohyeah2389

local PIDController = require('script_pid')

local FADEC = class("FADEC")

function FADEC:initialize(turbineId)
    -- Control parameters
    self.n1PID = PIDController(0.0002, 0, 0.0001, 0, 1, 1)
    self.tempPID = PIDController(1, 0, 0, 0.001, 1, 1)

    self.turbineId = turbineId

    -- Operating limits
    self.maxN1 = 38000
    self.maxTIT = 1600  -- Kelvin
    self.maxFuelFlow = 0.2
    self.minFuelFlow = 0.0
    self.idleRPM = 16000
end

function FADEC:update(dt, sensors, controls)
    -- Calculate target N1 based on throttle position
    local targetN1 = math.lerp(self.idleRPM, self.maxN1, controls.throttle)
    ac.debug("torqueTurbine." .. self.turbineId .. ".FADEC.targetN1", targetN1)

    -- Main N1 control loop
    local baseFuel = self.n1PID:update(targetN1, sensors.n1RPM, dt)
    ac.debug("torqueTurbine." .. self.turbineId .. ".FADEC.baseFuel", baseFuel)

    -- Temperature limiting control loop
    local tempLimit = self.tempPID:update(self.maxTIT, sensors.turbineInletTemp, dt)
    ac.debug("torqueTurbine." .. self.turbineId .. ".FADEC.tempLimit", tempLimit)

    -- Final fuel flow calculation with temperature limiting
    local commandedFuelFlow = math.min(
        self.maxFuelFlow * baseFuel,
        self.maxFuelFlow * tempLimit
    )

    ac.debug("torqueTurbine." .. self.turbineId .. ".FADEC.commandedFuelFlow", commandedFuelFlow)
    ac.debug("torqueTurbine." .. self.turbineId .. ".FADEC.percentCommandedFuelFlow", (commandedFuelFlow / self.maxFuelFlow) * 100)

    return math.clamp(commandedFuelFlow, self.minFuelFlow, self.maxFuelFlow)
end

return FADEC