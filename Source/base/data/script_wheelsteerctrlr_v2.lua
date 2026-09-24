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

local function setupItem(id, default)
    return ac.getScriptSetupValue(id) or refnumber(default)
end

local setup = {
    maxSteer = setupItem("STEERING_RANGE", 3),
    ffbSmoothing = setupItem("FFB_SMOOTHING", 10),
    ffbMultiplier = setupItem("FFB_GAIN", 10),
    ffbFrontSteerGain = setupItem("FFB_FRONT_ANGLE_GAIN", 0),
    ffbFrontSlipGain = setupItem("FFB_FRONT_SLIP_GAIN", 10),
    ffbRearSteerGain = setupItem("FFB_REAR_ANGLE_GAIN", 0),
    ffbRearSlipGain = setupItem("FFB_REAR_SLIP_GAIN", 10),
    ffbLatGGain = setupItem("FFB_LATERAL_G", 0),
    ffbSteerLimitGain = setupItem("FFB_STEER_LIMIT_GAIN", 10),
    driftGain = setupItem("V2_DRIFT_GAIN", 7),
    frontSteerGain = setupItem("V2_FRONT_STEER_GAIN", 6),
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
    self.previousSteer = Data.steer
    self.lastFFB = 0
    self.steerChangeHistory = {0, 0, 0, 0, 0} -- Circular buffer for averaging
    self.historyIndex = 1

    self.desiredSteerFL = 0
    self.desiredSteerFR = 0
    self.desiredSteerRL = 0
    self.desiredSteerRR = 0

    self.resetFade = 0 -- moves to 1 over one second; when 1, normal control is resumed

    self.steerNormalizedInput = 0
    self.driftOffsetCommand = 0

    self.driftPID = PID(driftPIDParams)

    self.ffb = self.calculateFFB
end

function WheelSteerCtrlr:calculateFFB(dt)
    -- stable deltatime
    dt = math.max(dt, 0.001)

    -- safety check steer values
    if not Data.steer or not self.previousSteer then return 0 end

    local steerOverLimitDelta = math.max(0, math.abs(car.steer) - setup.maxSteer.value * 90)
    local frontSlipAngle = (Data.wheels[0].slipAngle or 0) + (Data.wheels[1].slipAngle or 0)
    local rearSlipAngle = (Data.wheels[2].slipAngle or 0) + (Data.wheels[3].slipAngle or 0)

    -- grab setup values, then calc each effect
    local frontSteerGain = (setup.ffbFrontSteerGain.value or 0) / 5
    local frontSteerEffect = (self.desiredSteerFL + self.desiredSteerFR) * frontSteerGain

    local frontSlipGain = (setup.ffbFrontSlipGain.value or 10) / 10
    local frontSlipEffect = math.clamp(frontSlipAngle * -10, -6, 6) * frontSlipGain

    local rearSteerGain = (setup.ffbRearSteerGain.value or 0) / 5
    local rearSteerEffect = (self.desiredSteerRL + self.desiredSteerRR) * rearSteerGain

    local rearSlipGain = (setup.ffbRearSlipGain.value or 10) / 10
    local rearSlipEffect = 0 --math.clamp(rearSlipAngle * -15, -6, 6) * rearSlipGain

    local latGGain = (setup.ffbLatGGain.value or 0) / 10
    local latGEffect = math.clamp(Data.gForces.x or 0, -5, 5) * latGGain

    local steerLimitGain = (setup.ffbSteerLimitGain.value or 10) / 10
    local steerLimitEffect = math.clamp((steerOverLimitDelta ^ 2) * steerLimitGain, -(steerLimitGain * 4), (steerLimitGain * 4))

    -- sum all effects
    local helperEffect = frontSteerEffect + frontSlipEffect + rearSteerEffect + rearSlipEffect + latGEffect

    -- ensure helperEffect works in same direction as steerLimitEffect
    if math.abs(steerLimitEffect) > 0 then
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

    local steerChange = (Data.steer - self.previousSteer) / dt
    self.previousSteer = Data.steer

    -- update steer delta buffer
    if math.abs(steerChange) < 1000 then
        self.steerChangeHistory[self.historyIndex] = (steerChange * 0.3) + helperEffect
        self.historyIndex = (self.historyIndex % #self.steerChangeHistory) + 1
    end

    -- calc smoothed steer delta using steer delta buffer
    local avgSteerChange = 0
    for _, v in ipairs(self.steerChangeHistory) do
        avgSteerChange = avgSteerChange + (v or 0)
    end
    avgSteerChange = avgSteerChange / #self.steerChangeHistory

    -- prepare final FFB from smoothed steer delta
    local ffbSmoothing = (setup.ffbSmoothing.value or 10) / 100
    local targetFFB = (Data.steer * 0.2 or 0) + (avgSteerChange * 0.03)
    local smoothedFFB = (self.lastFFB * ffbSmoothing) + (targetFFB * (1 - ffbSmoothing))

    -- safety check final FFB value
    if math.abs(smoothedFFB) > 1000 or not (smoothedFFB == smoothedFFB) then  -- Check for NaN
        smoothedFFB = 0
    end

    -- return final safe FFB value, scaled by FFB multiplier
    self.lastFFB = smoothedFFB
    return math.clamp(smoothedFFB * ((setup.ffbMultiplier.value or 10) / 10), -1, 1)
end

function WheelSteerCtrlr:updateSetupValues() end

function WheelSteerCtrlr:update(dt)
    local driftAngleRad = -math.atan2(Data.localVelocity.x, Data.localVelocity.z) * helpers.mapRange(Data.speedKmh, 2, 20, 0, 1, true)

    self.steerNormalizedInput = math.clamp(Data.steer / setup.maxSteer.value, -1, 1)

    local driftGain = ((setup.driftGain.value or 7) * 0.25) + 1.0
    local targetDriftAngle = self.steerNormalizedInput * -driftGain
    self.driftOffsetCommand = self.driftPID:update(targetDriftAngle, driftAngleRad, dt)

    local frontSteerGain = (setup.frontSteerGain.value or 6) / 20
    self.desiredSteerFL = (math.deg(driftAngleRad) / 180) + self.steerNormalizedInput * frontSteerGain
    self.desiredSteerFR = (math.deg(driftAngleRad) / 180) + self.steerNormalizedInput * frontSteerGain
    self.desiredSteerRL = (math.deg(driftAngleRad) / 180) + self.driftOffsetCommand
    self.desiredSteerRR = (math.deg(driftAngleRad) / 180) + self.driftOffsetCommand

    -- Reverse override
    if car.gear == -1 then
        self.desiredSteerFL = self.steerNormalizedInput * 0.5
        self.desiredSteerFR = self.steerNormalizedInput * 0.5
        self.desiredSteerRL = self.steerNormalizedInput * -0.2
        self.desiredSteerRR = self.steerNormalizedInput * -0.2
    end

    -- Wheel lock overrides, reset fading
    self.resetFade = math.min(1, self.resetFade + dt)
    local fade = math.smootherstep(self.resetFade)
    self.steerStateFL = self.desiredSteerFL * (state.control.lockedFronts and 0 or 1) * fade
    self.steerStateFR = self.desiredSteerFR * (state.control.lockedFronts and 0 or 1) * fade
    self.steerStateRL = self.desiredSteerRL * (state.control.lockedRears and 0 or 1) * fade
    self.steerStateRR = self.desiredSteerRR * (state.control.lockedRears and 0 or 1) * fade

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
    self.resetFade = 0

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
