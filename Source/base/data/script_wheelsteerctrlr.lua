-- T-180 CSP Physics Script - Steering Controller Module, Type B
-- Authored by ohyeah2389

local state = require('script_state')
local helpers = require('script_helpers')
local PID = require('pid_v2')
local threesixtyctrlr = require('script_threesixtyctrlr')

local WheelSteerCtrlr = class("WheelSteerCtrlr")

local threesixtyctrlr_FL = threesixtyctrlr()
local threesixtyctrlr_FR = threesixtyctrlr()
local threesixtyctrlr_RL = threesixtyctrlr()
local threesixtyctrlr_RR = threesixtyctrlr()

local driftPIDParams = {
    kP = 0.2,
    kI = 0,
    kD = 0.02,
    minOutput = -1,
    maxOutput = 1,
    dampingFactor = 0
}

function WheelSteerCtrlr:initialize()
    self.maxSteer = 180

    self.steerNormalizedInput = 0
    self.driftOffsetCommand = 0

    self.driftPID = PID(driftPIDParams)

    self:updateSetupValues()
end

function WheelSteerCtrlr:calculateFFB(dt)
    local frontSteerMag = (self.desiredSteerFL + self.desiredSteerFR)
    local rearSteerMag = (self.desiredSteerRL + self.desiredSteerRR)

    return (self.driftOffsetCommand * -1)
end

function WheelSteerCtrlr:updateSetupValues() end

function WheelSteerCtrlr:update(dt)
    self:updateSetupValues()

    local driftAngleRad = -math.atan2(Data.localVelocity.x, Data.localVelocity.z) * helpers.mapRange(car.speedKmh, 2, 20, 0, 1, true)

    self.steerNormalizedInput = math.clamp(Data.steer / (self.maxSteer / 180), -1, 1)

    local targetDriftAngle = self.steerNormalizedInput * -2.75
    self.driftOffsetCommand = self.driftPID:update(targetDriftAngle, driftAngleRad, dt)

    self.desiredSteerFL = (math.deg(driftAngleRad) / 180) + self.steerNormalizedInput * 0.3
    self.desiredSteerFR = (math.deg(driftAngleRad) / 180) + self.steerNormalizedInput * 0.3
    self.desiredSteerRL = (math.deg(driftAngleRad) / 180) + self.driftOffsetCommand
    self.desiredSteerRR = (math.deg(driftAngleRad) / 180) + self.driftOffsetCommand

    -- Reverse override
    if car.gear == -1 then
        self.desiredSteerFL = self.steerNormalizedInput * 0.5
        self.desiredSteerFR = self.steerNormalizedInput * 0.5
        self.desiredSteerRL = self.steerNormalizedInput * -0.2
        self.desiredSteerRR = self.steerNormalizedInput * -0.2
    end

    -- Wheel lock overrides
    self.steerStateFL = self.desiredSteerFL * (state.control.lockedFronts and 0 or 1)
    self.steerStateFR = self.desiredSteerFR * (state.control.lockedFronts and 0 or 1)
    self.steerStateRL = self.desiredSteerRL * (state.control.lockedRears and 0 or 1)
    self.steerStateRR = self.desiredSteerRR * (state.control.lockedRears and 0 or 1)

    -- Send results of ThreeSixtyController to pistons
    Data.controllerInputs[0], Data.controllerInputs[1] = threesixtyctrlr_FL:update(self.steerStateFL, dt)
    Data.controllerInputs[2], Data.controllerInputs[3] = threesixtyctrlr_FR:update(-self.steerStateFR, dt)
    Data.controllerInputs[4], Data.controllerInputs[5] = threesixtyctrlr_RL:update(self.steerStateRL, dt)
    Data.controllerInputs[6], Data.controllerInputs[7] = threesixtyctrlr_RR:update(-self.steerStateRR, dt)

    --if any steer state is invalid, reset the steering states
    if not (self.steerStateFL == self.steerStateFL) or not (self.steerStateFR == self.steerStateFR) or not (self.steerStateRL == self.steerStateRL) or not (self.steerStateRR == self.steerStateRR) then
        self:reset()
    end

    if DEBUG then
        ac.debug("steerctrl.Data.steer", Data.steer, -180, 180, 3)
        ac.debug("steerctrl.driftAngle", driftAngleRad, -math.pi, math.pi, 3)
        ac.debug("steerctrl.targetDriftAngle", targetDriftAngle, -1.5, 1.5, 3)
        ac.debug("steerctrl.driftOffsetCommand", self.driftOffsetCommand, -1, 1, 3)
        ac.debug("steerctrl.desiredSteerFL", self.desiredSteerFL, -1, 1, 3)
        ac.debug("steerctrl.desiredSteerFR", self.desiredSteerFR, -1, 1, 3)
        ac.debug("steerctrl.desiredSteerRL", self.desiredSteerRL, -1, 1, 3)
        ac.debug("steerctrl.desiredSteerRR", self.desiredSteerRR, -1, 1, 3)
        ac.debug("steerctrl.state.control.lockedRears", state.control.lockedRears)
        ac.debug("steerctrl.state.control.lockedFronts", state.control.lockedFronts)
        ac.debug("steerctrl.slipAngleFL", Data.wheels[0].slipAngle, -10, 10, 3)
        ac.debug("steerctrl.slipAngleFR", Data.wheels[1].slipAngle, -10, 10, 3)
        ac.debug("steerctrl.slipAngleRL", Data.wheels[2].slipAngle, -10, 10, 3)
        ac.debug("steerctrl.slipAngleRR", Data.wheels[3].slipAngle, -10, 10, 3)
        ac.debug("steerctrl.steerNormalizedInput", self.steerNormalizedInput, -1, 1, 3)
        ac.debug("steerctrl.acceleration.y", car.acceleration.y, -10, 10, 3)
    end
end

function WheelSteerCtrlr:reset()
    -- Reset PID controllers
    self.driftPID:reset()
end

return WheelSteerCtrlr
