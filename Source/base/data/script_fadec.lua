-- T-180 CSP Physics Script - Turbine FADEC Module
-- Authored by ohyeah2389

local PIDController = require('script_pid')

local FADEC = class("FADEC")

function FADEC:initialize(turbineId)
    -- Control parameters
    self.n1PID = PIDController(0.0001, 0, 1e-6, 0, 1, 1)
    self.tempPID = PIDController(0.1, 0, 0, 1e-2, 1, 1)

    self.turbineId = turbineId

    -- Operating limits
    self.maxFuelFlow = 1.0
    self.minFuelFlow = 0.001
    self.idleRPM = 16000
end

function FADEC:update(dt, sensors, controls, maxNG, maxTIT)
    -- Calculate target N1 based on throttle position
    local targetN1 = math.lerp(self.idleRPM, maxNG, controls.throttle)
    ac.debug("turboshaft." .. self.turbineId .. ".FADEC.targetN1", targetN1)

    -- Main N1 control loop
    local baseFuel = self.n1PID:update(targetN1, sensors.ngRPM, dt)
    ac.debug("turboshaft." .. self.turbineId .. ".FADEC.baseFuel", baseFuel)

    -- Temperature limiting control loop
    local tempLimit = self.tempPID:update(maxTIT, sensors.turbineInletTemp, dt)
    ac.debug("turboshaft." .. self.turbineId .. ".FADEC.tempLimit", tempLimit)

    -- Final fuel flow calculation with temperature limiting
    local commandedFuelFlow = math.min(
        self.maxFuelFlow * baseFuel,
        self.maxFuelFlow * tempLimit
    )

    ac.debug("turboshaft." .. self.turbineId .. ".FADEC.throttle", controls.throttle)
    ac.debug("turboshaft." .. self.turbineId .. ".FADEC.targetN1", targetN1)
    ac.debug("turboshaft." .. self.turbineId .. ".FADEC.baseFuel", baseFuel)
    ac.debug("turboshaft." .. self.turbineId .. ".FADEC.tempLimit", tempLimit)
    ac.debug("turboshaft." .. self.turbineId .. ".FADEC.commandedFuelFlow", commandedFuelFlow)
    ac.debug("turboshaft." .. self.turbineId .. ".FADEC.percentCommandedFuelFlow", (commandedFuelFlow / self.maxFuelFlow) * 100)

    return math.clamp(commandedFuelFlow, self.minFuelFlow, self.maxFuelFlow)
end

return FADEC