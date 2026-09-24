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

    self.antiWarpParams = {
        kP = 0, --20000,
        kI = 0,
        kD = 50,
        minOutput = -5000,
        maxOutput = 5000,
        dampingFactor = 0
    }

    self.pidAntiWarpLFRR = PID(self.antiWarpParams)
    self.pidAntiWarpRFLR = PID(self.antiWarpParams)

    self.camberControlParams = {
        kP = 4000,
        kI = 0,
        kD = 0,
        minOutput = -200,
        maxOutput = 200,
        dampingFactor = 0.2
    }

    self.pidCamberLF = PID(self.camberControlParams)
    self.pidCamberRF = PID(self.camberControlParams)
    self.pidCamberLR = PID(self.camberControlParams)
    self.pidCamberRR = PID(self.camberControlParams)

    self.speedLUT = ac.DataLUT11.parse("(| 0=0 | 100=80 | 200=300 | 400=800 | 600=1800 | 1000=4500 |)")
end

function activeSusp:update(dt)
    local warpLFRR = Data.wheels[3].suspensionTravel - Data.wheels[0].suspensionTravel
    local warpRFLR = Data.wheels[2].suspensionTravel - Data.wheels[1].suspensionTravel

    local antiWarpLFRR = self.pidAntiWarpLFRR:update(0, warpLFRR, dt)
    local antiWarpRFLR = self.pidAntiWarpRFLR:update(0, warpRFLR, dt)

    Data.controllerInputs[23] = self.speedLUT:get(Data.speedKmh) --+ antiWarpLFRR --+ self.pidLF:update(0, -car.wheels[0].suspensionTravel, dt)
    Data.controllerInputs[24] = self.speedLUT:get(Data.speedKmh) --+ antiWarpRFLR --+ self.pidRF:update(0, -car.wheels[1].suspensionTravel, dt)
    Data.controllerInputs[25] = self.speedLUT:get(Data.speedKmh) --- antiWarpRFLR --+ self.pidLR:update(0, -car.wheels[2].suspensionTravel, dt)
    Data.controllerInputs[26] = self.speedLUT:get(Data.speedKmh) --- antiWarpLFRR --+ self.pidRR:update(0, -car.wheels[3].suspensionTravel, dt)

    local camberLF = math.asin(math.clamp(-Data.wheels[0].contactNormal:dot(Data.wheels[0].side), -1, 1))
    local camberRF = math.asin(math.clamp(Data.wheels[1].contactNormal:dot(Data.wheels[1].side), -1, 1))
    local camberLR = math.asin(math.clamp(-Data.wheels[2].contactNormal:dot(Data.wheels[2].side), -1, 1))
    local camberRR = math.asin(math.clamp(Data.wheels[3].contactNormal:dot(Data.wheels[3].side), -1, 1))
    Data.controllerInputs[27] = 0 --self.pidCamberLF:update(math.rad(-2.5), camberLF, dt)
    Data.controllerInputs[28] = 0 --self.pidCamberRF:update(math.rad(-2.5), camberRF, dt)
    Data.controllerInputs[29] = 0 --self.pidCamberLR:update(math.rad(-2.5), camberLR, dt)
    Data.controllerInputs[30] = 0 --self.pidCamberRR:update(math.rad(-2.5), camberRR, dt)

    if DEBUG then
        ac.debug("ActiveSusp Camber LF", math.deg(camberLF), -5, 5, 2)
        ac.debug("ActiveSusp Camber RF", math.deg(camberRF), -5, 5, 2)
        ac.debug("ActiveSusp Camber LR", math.deg(camberLR), -5, 5, 2)
        ac.debug("ActiveSusp Camber RR", math.deg(camberRR), -5, 5, 2)
        ac.debug("ActiveSusp Warp LFRR", warpLFRR, -0.2, 0.2, 2)
        ac.debug("ActiveSusp Warp RFLR", warpRFLR, -0.2, 0.2, 2)
        ac.debug("ActiveSusp PID Output Warp LFRR", antiWarpLFRR, -2000, 2000, 2)
        ac.debug("ActiveSusp PID Output Warp RFLR", antiWarpRFLR, -2000, 2000, 2)
        ac.debug("ActiveSusp Wheel LF SuspTravel", -car.wheels[0].suspensionTravel, -0.2, 0.2, 2)
        ac.debug("ActiveSusp Wheel RF SuspTravel", -car.wheels[1].suspensionTravel, -0.2, 0.2, 2)
        ac.debug("ActiveSusp Wheel LR SuspTravel", -car.wheels[2].suspensionTravel, -0.2, 0.2, 2)
        ac.debug("ActiveSusp Wheel RR SuspTravel", -car.wheels[3].suspensionTravel, -0.2, 0.2, 2)
        ac.debug("ActiveSusp Final Output LF", Data.controllerInputs[23], -10000, 5000, 2)
        ac.debug("ActiveSusp Final Output RF", Data.controllerInputs[24], -10000, 5000, 2)
        ac.debug("ActiveSusp Final Output LR", Data.controllerInputs[25], -10000, 5000, 2)
        ac.debug("ActiveSusp Final Output RR", Data.controllerInputs[26], -10000, 5000, 2)
        ac.debug("ActiveSusp PID Integral LF", self.pidLF.integral, -0.2, 0.2, 2)
        ac.debug("ActiveSusp PID Integral RF", self.pidRF.integral, -0.2, 0.2, 2)
        ac.debug("ActiveSusp PID Integral LR", self.pidLR.integral, -0.2, 0.2, 2)
        ac.debug("ActiveSusp PID Integral RR", self.pidRR.integral, -0.2, 0.2, 2)
    end
end

function activeSusp:reset()
    self.pidLF:reset()
    self.pidRF:reset()
    self.pidLR:reset()
    self.pidRR:reset()
end

return activeSusp