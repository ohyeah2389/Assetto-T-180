-- T-180 CSP Physics Script - Steering Controller Module, Version 2
-- Authored by ohyeah2389

local state = require('script_state')
local helpers = require('script_helpers')
local PID = require('pid_v2')
local threesixtyctrlr = require('script_threesixtyctrlr')

local WheelSteerCtrlr = class("WheelSteerCtrlr_v2")

local threesixtyctrlr_FL = threesixtyctrlr()
local threesixtyctrlr_FR = threesixtyctrlr()
local threesixtyctrlr_RL = threesixtyctrlr()
local threesixtyctrlr_RR = threesixtyctrlr()

local setup = {
    maxSteer = ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_20"),
    ffbSmoothing = ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_1"),
    ffbMultiplier = ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_0"),
    ffbFrontSteerGain = ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_2"),
    ffbFrontSlipGain = ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_3"),
    ffbRearSteerGain = ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_4"),
    ffbRearSlipGain = ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_5"),
    ffbLatGGain = ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_6"),
    ffbSteerLimitGain = ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_21"),
    driftGain = ac.getScriptSetupValue("V2_DRIFT_GAIN"),
    frontSteerGain = ac.getScriptSetupValue("V2_FRONT_STEER_GAIN"),
}

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
    self.previousSteer = Data.steer
    self.lastFFB = 0
    self.steerChangeHistory = {0, 0, 0, 0, 0} -- Circular buffer for averaging
    self.historyIndex = 1
    self.ffbSmoothing = 0.9 -- overridden by setup
    self.ffbMultiplier = 0 -- overridden by setup

    self.desiredSteerFL = 0
    self.desiredSteerFR = 0
    self.desiredSteerRL = 0
    self.desiredSteerRR = 0

    self.steerNormalizedInput = 0
    self.driftOffsetCommand = 0

    self.driftPID = PID(driftPIDParams)

    self.driftGain = 2.75 -- overridden by setup
    self.frontSteerGain = 0.3 -- overridden by setup

    self:updateSetupValues()
end

function WheelSteerCtrlr:calculateFFB(dt)
    -- Prevent division by zero
    dt = math.max(dt, 0.001)

    -- Add safety check for NaN/infinite values
    if not Data.steer or not self.previousSteer then
        return 0
    end

    local steerOverLimitDelta = math.max(0, math.abs(car.steer) - self.maxSteer)

    local steerChange = (Data.steer - self.previousSteer) / dt
    self.previousSteer = Data.steer

    -- Add null checks for wheel slip angles
    local frontSlipAngle = (Data.wheels[0].slipAngle or 0) + (Data.wheels[1].slipAngle or 0)
    local rearSlipAngle = (Data.wheels[2].slipAngle or 0) + (Data.wheels[3].slipAngle or 0)

    -- Get FFB effect values
    local frontSteerGain = (setup.ffbFrontSteerGain.value or 0) / 5
    local frontSlipGain = (setup.ffbFrontSlipGain.value or 10) / 10
    local rearSteerGain = (setup.ffbRearSteerGain.value or 0) / 5
    local rearSlipGain = (setup.ffbRearSlipGain.value or 10) / 10
    local latGGain = (setup.ffbLatGGain.value or 0) / 10
    local steerLimitGain = (setup.ffbSteerLimitGain.value or 10) / 20

    local frontSteerEffect = (self.desiredSteerFL + self.desiredSteerFR) * frontSteerGain
    local frontSlipEffect = math.clamp(frontSlipAngle * -10, -6, 6) * frontSlipGain
    local rearSteerEffect = (self.desiredSteerRL + self.desiredSteerRR) * rearSteerGain
    local rearSlipEffect = 0 --math.clamp(rearSlipAngle * -15, -6, 6) * rearSlipGain
    local latGEffect = math.clamp(Data.gForces.x or 0, -5, 5) * latGGain
    local steerLimitEffect = math.clamp((steerOverLimitDelta ^ 2) * steerLimitGain, -(steerLimitGain * 2), (steerLimitGain * 2))
    local helperEffect = frontSteerEffect + frontSlipEffect + rearSteerEffect + rearSlipEffect + latGEffect
    if math.abs(steerLimitEffect) > 0 then
        -- Ensure helperEffect works in same direction as steerLimitEffect
        local steerSign = math.sign(car.steer)
        helperEffect = steerLimitEffect * steerSign + math.clamp(helperEffect * steerSign, 0, math.huge) * steerSign
    end

    -- Debug values
    if DEBUG then
        ac.debug("ffb.helperEffect", helperEffect)
        ac.debug("ffb.frontSteerEffect", frontSteerEffect)
        ac.debug("ffb.frontSlipEffect", frontSlipEffect)
        ac.debug("ffb.rearSteerEffect", rearSteerEffect)
        ac.debug("ffb.rearSlipEffect", rearSlipEffect)
        ac.debug("ffb.latGEffect", latGEffect)
        ac.debug("ffb.steerOverLimitDelta", steerOverLimitDelta)
        ac.debug("ffb.steerLimitEffect", steerLimitEffect)
    end

    -- Update circular buffer with safety check
    if math.abs(steerChange) < 1000 then  -- Reasonable maximum value
        self.steerChangeHistory[self.historyIndex] = (steerChange * 0.3) + helperEffect
        self.historyIndex = (self.historyIndex % #self.steerChangeHistory) + 1
    end

    -- Calculate moving average
    local avgSteerChange = 0
    for _, v in ipairs(self.steerChangeHistory) do
        avgSteerChange = avgSteerChange + (v or 0)  -- Use 0 if value is nil
    end
    avgSteerChange = avgSteerChange / #self.steerChangeHistory

    -- Calculate new FFB with exponential smoothing
    local targetFFB = (Data.steer * 0.2 or 0) + (avgSteerChange * 0.03)
    local smoothedFFB = (self.lastFFB * self.ffbSmoothing) + (targetFFB * (1 - self.ffbSmoothing))

    -- Final safety check before returning
    if math.abs(smoothedFFB) > 1000 or not (smoothedFFB == smoothedFFB) then  -- Check for NaN
        smoothedFFB = 0
    end

    self.lastFFB = smoothedFFB
    return math.clamp(smoothedFFB * self.ffbMultiplier, -1, 1)
end

function WheelSteerCtrlr:updateSetupValues()
    self.maxSteer = setup.maxSteer.value * 90
    self.ffbSmoothing = (setup.ffbSmoothing.value or 10) / 100
    self.ffbMultiplier = (setup.ffbMultiplier.value or 10) / 10
    self.driftGain = (((setup.driftGain.value or 7) * 0.25) + 1.0)
    self.frontSteerGain = (setup.frontSteerGain.value or 6) / 20
end

function WheelSteerCtrlr:update(dt)
    local driftAngleRad = -math.atan2(Data.localVelocity.x, Data.localVelocity.z) * helpers.mapRange(car.speedKmh, 2, 20, 0, 1, true)

    self.steerNormalizedInput = math.clamp(Data.steer / (self.maxSteer / 90), -1, 1)

    local targetDriftAngle = self.steerNormalizedInput * -self.driftGain
    self.driftOffsetCommand = self.driftPID:update(targetDriftAngle, driftAngleRad, dt)

    self.desiredSteerFL = (math.deg(driftAngleRad) / 180) + self.steerNormalizedInput * self.frontSteerGain
    self.desiredSteerFR = (math.deg(driftAngleRad) / 180) + self.steerNormalizedInput * self.frontSteerGain
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
        ac.debug("steerctrl_v2.Data.steer", Data.steer, -180, 180, 3)
        ac.debug("steerctrl_v2.driftAngle", driftAngleRad, -math.pi, math.pi, 3)
        ac.debug("steerctrl_v2.targetDriftAngle", targetDriftAngle, -1.5, 1.5, 3)
        ac.debug("steerctrl_v2.driftOffsetCommand", self.driftOffsetCommand, -1, 1, 3)
        ac.debug("steerctrl_v2.desiredSteerFL", self.desiredSteerFL, -1, 1, 3)
        ac.debug("steerctrl_v2.desiredSteerFR", self.desiredSteerFR, -1, 1, 3)
        ac.debug("steerctrl_v2.desiredSteerRL", self.desiredSteerRL, -1, 1, 3)
        ac.debug("steerctrl_v2.desiredSteerRR", self.desiredSteerRR, -1, 1, 3)
        ac.debug("steerctrl_v2.state.control.lockedRears", state.control.lockedRears)
        ac.debug("steerctrl_v2.state.control.lockedFronts", state.control.lockedFronts)
        ac.debug("steerctrl_v2.slipAngleFL", Data.wheels[0].slipAngle, -10, 10, 3)
        ac.debug("steerctrl_v2.slipAngleFR", Data.wheels[1].slipAngle, -10, 10, 3)
        ac.debug("steerctrl_v2.slipAngleRL", Data.wheels[2].slipAngle, -10, 10, 3)
        ac.debug("steerctrl_v2.slipAngleRR", Data.wheels[3].slipAngle, -10, 10, 3)
        ac.debug("steerctrl_v2.steerNormalizedInput", self.steerNormalizedInput, -1, 1, 3)
        ac.debug("steerctrl_v2.acceleration.y", car.acceleration.y, -10, 10, 3)
    end
end

function WheelSteerCtrlr:reset()
    -- Reset PID controllers
    self.driftPID:reset()

    -- Reset desired steering values
    self.desiredSteerFL = 0
    self.desiredSteerFR = 0
    self.desiredSteerRL = 0
    self.desiredSteerRR = 0

    -- Reset FFB-related values
    self.previousSteer = Data.steer
    self.lastFFB = 0
    for i = 1, #self.steerChangeHistory do
        self.steerChangeHistory[i] = 0
    end
    self.historyIndex = 1
end

return WheelSteerCtrlr
