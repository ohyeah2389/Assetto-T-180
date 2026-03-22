-- T-180 CSP Physics Script - Active Suspension Physics Module
-- Authored by ohyeah2389

local game = require('script_acConnection')

local PID = require('script_pid')

local activeSusp = class("ActiveSusp")

function activeSusp:initialize(params)
    self.pidLF = PID(0, 40000, 200, -10000, 5000, 0.7)
    self.pidRF = PID(0, 40000, 200, -10000, 5000, 0.7)
    self.pidLR = PID(0, 40000, 200, -10000, 5000, 0.7)
    self.pidRR = PID(0, 40000, 200, -10000, 5000, 0.7)
    self.speedLUT = ac.DataLUT11.parse("(| 0=0 | 100=80 | 200=300 | 400=800 | 600=1800 | 1000=4500 |)")
end

function activeSusp:update(dt)
    game.car_cphys.controllerInputs[23] = self.speedLUT:get(game.car_cphys.speedKmh) --+ self.pidLF:update(0, -car.wheels[0].suspensionTravel, dt)
    game.car_cphys.controllerInputs[24] = self.speedLUT:get(game.car_cphys.speedKmh) --+ self.pidRF:update(0, -car.wheels[1].suspensionTravel, dt)
    game.car_cphys.controllerInputs[25] = self.speedLUT:get(game.car_cphys.speedKmh) --+ self.pidLR:update(0, -car.wheels[2].suspensionTravel, dt)
    game.car_cphys.controllerInputs[26] = self.speedLUT:get(game.car_cphys.speedKmh) --+ self.pidRR:update(0, -car.wheels[3].suspensionTravel, dt)

    if DEBUG then
        ac.debug("Wheel LF SuspTravel", -car.wheels[0].suspensionTravel, -0.2, 0.2, 2)
        ac.debug("Wheel RF SuspTravel", -car.wheels[1].suspensionTravel, -0.2, 0.2, 2)
        ac.debug("Wheel LR SuspTravel", -car.wheels[2].suspensionTravel, -0.2, 0.2, 2)
        ac.debug("Wheel RR SuspTravel", -car.wheels[3].suspensionTravel, -0.2, 0.2, 2)
        ac.debug("PID Output LF", game.car_cphys.controllerInputs[23], -10000, 5000, 2)
        ac.debug("PID Output RF", game.car_cphys.controllerInputs[24], -10000, 5000, 2)
        ac.debug("PID Output LR", game.car_cphys.controllerInputs[25], -10000, 5000, 2)
        ac.debug("PID Output RR", game.car_cphys.controllerInputs[26], -10000, 5000, 2)
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