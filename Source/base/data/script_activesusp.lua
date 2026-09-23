-- T-180 CSP Physics Script - Active Suspension Physics Module
-- Authored by ohyeah2389

local PID = require('pid_v2')

local activeSusp = class("ActiveSusp")

function activeSusp:initialize(params)
    self.suspensionControlParams = {
        kP = 0,
        kI = 40000,
        kD = 200,
        minOutput = -10000,
        maxOutput = 5000,
        dampingFactor = 0.1
    }

    self.pidLF = PID(self.suspensionControlParams)
    self.pidRF = PID(self.suspensionControlParams)
    self.pidLR = PID(self.suspensionControlParams)
    self.pidRR = PID(self.suspensionControlParams)

    self.speedLUT = ac.DataLUT11.parse("(| 0=0 | 100=80 | 200=300 | 400=800 | 600=1800 | 1000=4500 |)")
end

function activeSusp:update(dt)
    Data.controllerInputs[23] = self.speedLUT:get(Data.speedKmh) --+ self.pidLF:update(0, -car.wheels[0].suspensionTravel, dt)
    Data.controllerInputs[24] = self.speedLUT:get(Data.speedKmh) --+ self.pidRF:update(0, -car.wheels[1].suspensionTravel, dt)
    Data.controllerInputs[25] = self.speedLUT:get(Data.speedKmh) --+ self.pidLR:update(0, -car.wheels[2].suspensionTravel, dt)
    Data.controllerInputs[26] = self.speedLUT:get(Data.speedKmh) --+ self.pidRR:update(0, -car.wheels[3].suspensionTravel, dt)

    if DEBUG then
        ac.debug("Wheel LF SuspTravel", -car.wheels[0].suspensionTravel, -0.2, 0.2, 2)
        ac.debug("Wheel RF SuspTravel", -car.wheels[1].suspensionTravel, -0.2, 0.2, 2)
        ac.debug("Wheel LR SuspTravel", -car.wheels[2].suspensionTravel, -0.2, 0.2, 2)
        ac.debug("Wheel RR SuspTravel", -car.wheels[3].suspensionTravel, -0.2, 0.2, 2)
        ac.debug("PID Output LF", Data.controllerInputs[23], -10000, 5000, 2)
        ac.debug("PID Output RF", Data.controllerInputs[24], -10000, 5000, 2)
        ac.debug("PID Output LR", Data.controllerInputs[25], -10000, 5000, 2)
        ac.debug("PID Output RR", Data.controllerInputs[26], -10000, 5000, 2)
        ac.debug("PID Integral LF", self.pidLF.integral, -0.2, 0.2, 2)
        ac.debug("PID Integral RF", self.pidRF.integral, -0.2, 0.2, 2)
        ac.debug("PID Integral LR", self.pidLR.integral, -0.2, 0.2, 2)
        ac.debug("PID Integral RR", self.pidRR.integral, -0.2, 0.2, 2)
    end
end

function activeSusp:reset()
    self.pidLF:reset()
    self.pidRF:reset()
    self.pidLR:reset()
    self.pidRR:reset()
end

return activeSusp