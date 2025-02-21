-- T-180 CSP Physics Script - Steering Controller Module, Type B
-- Authored by ohyeah2389

local state = require('script_state')
local game = require('script_acConnection')
local helpers = require('script_helpers')
local PIDController = require('script_pid')
local threesixtyctrlr = require('script_threesixtyctrlr')

local WheelSteerCtrlr = class("WheelSteerCtrlr")


local threesixtyctrlr_FL = threesixtyctrlr()
local threesixtyctrlr_FR = threesixtyctrlr()
local threesixtyctrlr_RL = threesixtyctrlr()
local threesixtyctrlr_RR = threesixtyctrlr()


function WheelSteerCtrlr:initialize()
    self.steerInputLast = game.car_cphys.steer
    self.lastFFB = 0
    self.steerChangeHistory = {0, 0, 0, 0, 0}  -- Circular buffer for averaging
    self.historyIndex = 1

    self.yawRatePID = PIDController(0.2, 0, 0, -1, 1, 1)

    self.FL_slipTargetPID = PIDController(0.9, 0, 0, -2, 2, 0.3)
    self.FR_slipTargetPID = PIDController(0.9, 0, 0, -2, 2, 0.3)
    self.RL_slipTargetPID = PIDController(0.9, 0, 0, -2, 2, 0.3)
    self.RR_slipTargetPID = PIDController(0.9, 0, 0, -2, 2, 0.3)

    self.desiredSteerFL = 0
    self.desiredSteerFR = 0
    self.desiredSteerRL = 0
    self.desiredSteerRR = 0

    self.steerStateFL = 0
    self.steerStateFR = 0
    self.steerStateRL = 0
    self.steerStateRR = 0

    self.steerStateFL_prev = 0
    self.steerStateFR_prev = 0
    self.steerStateRL_prev = 0
    self.steerStateRR_prev = 0

    self.slipAngleFL_prev = 0
    self.slipAngleFR_prev = 0
    self.slipAngleRL_prev = 0
    self.slipAngleRR_prev = 0

    self.isReversing = false

    self.inversionBlendSpeed = 2.0

    self.lastDriftAngle = 0
    self.inversionBlendState = 0

    self.setupUpdateCounter = 333
    self:updateSetupValues()
end


function WheelSteerCtrlr:calculateFFB(dt)
    -- Prevent division by zero
    dt = math.max(dt, 0.001)
    
    -- Add safety check for NaN/infinite values
    if not game.car_cphys.steer or not self.steerInputLast then
        return 0
    end

    local maxSteer = 90 * ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_20").value
    local steerOverLimitDelta = math.max(0, math.abs(car.steer) - maxSteer)

    local steerChange = (game.car_cphys.steer - self.steerInputLast) / dt
    self.steerInputLast = game.car_cphys.steer

    -- Add null checks for wheel slip angles
    local frontSlipAngle = (game.car_cphys.wheels[0].slipAngle or 0) + (game.car_cphys.wheels[1].slipAngle or 0)
    local rearSlipAngle = (game.car_cphys.wheels[2].slipAngle or 0) + (game.car_cphys.wheels[3].slipAngle or 0)

    -- Get FFB effect values
    local frontSteerGain = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_2").value or 0) / 5
    local frontSlipGain = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_3").value or 10) / 10
    local rearSteerGain = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_4").value or 0) / 5
    local rearSlipGain = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_5").value or 10) / 10
    local latGGain = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_6").value or 0) / 10
    local steerLimitGain = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_21").value or 10) / 20

    local frontSteerEffect = (self.desiredSteerFL + self.desiredSteerFR) * frontSteerGain
    local frontSlipEffect = math.clamp(frontSlipAngle * -5, -6, 6) * frontSlipGain
    local rearSteerEffect = (self.desiredSteerRL + self.desiredSteerRR) * rearSteerGain
    local rearSlipEffect = math.clamp(rearSlipAngle * -15, -6, 6) * rearSlipGain
    local latGEffect = math.clamp(game.car_cphys.gForces.x or 0, -5, 5) * latGGain
    local steerLimitEffect = math.clamp((steerOverLimitDelta ^ 2) * steerLimitGain, -(steerLimitGain * 2), (steerLimitGain * 2))
    local helperEffect = frontSteerEffect + frontSlipEffect + rearSteerEffect + rearSlipEffect + latGEffect
    if math.abs(steerLimitEffect) > 0 then
        -- Ensure helperEffect works in same direction as steerLimitEffect
        local steerSign = math.sign(car.steer)
        helperEffect = steerLimitEffect * steerSign + math.clamp(helperEffect * steerSign, 0, math.huge) * steerSign
    end

    -- Debug values
    ac.debug("ffb.helperEffect", helperEffect)
    ac.debug("ffb.frontSteerEffect", frontSteerEffect)
    ac.debug("ffb.frontSlipEffect", frontSlipEffect)
    ac.debug("ffb.rearSteerEffect", rearSteerEffect)
    ac.debug("ffb.rearSlipEffect", rearSlipEffect)
    ac.debug("ffb.latGEffect", latGEffect)
    ac.debug("ffb.steerOverLimitDelta", steerOverLimitDelta)
    ac.debug("ffb.steerLimitEffect", steerLimitEffect)
    
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
    local targetFFB = (game.car_cphys.steer or 0) + (avgSteerChange * 0.03)
    local smoothedFFB = self.lastFFB * self.ffbSmoothing + targetFFB * (1 - self.ffbSmoothing)
    
    -- Final safety check before returning
    if math.abs(smoothedFFB) > 1000 or not (smoothedFFB == smoothedFFB) then  -- Check for NaN
        smoothedFFB = 0
    end
    
    self.lastFFB = smoothedFFB
    return math.clamp(smoothedFFB * self.ffbMultiplier, -1, 1)
end


function WheelSteerCtrlr:updateSetupValues()
    -- Only check for updates every N frames to reduce overhead
    if not self.setupUpdateCounter then self.setupUpdateCounter = 0 end
    self.setupUpdateCounter = self.setupUpdateCounter + 1
    if self.setupUpdateCounter < 333 then return end  -- Update every ~1 second at 333fps
    self.setupUpdateCounter = 0

    -- Set new values
    -- self.driftAnglePID.kP = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_7").value or 5) / 100
    -- self.driftAnglePID.dampingFactor = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_8").value or 30) / 100

    -- self.frontSteeringPower = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_9").value or 5) / 10
    -- self.frontSteeringDamping = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_10").value or 8) / 10

    -- self.rearSteeringPower = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_11").value or 7) / 10
    -- self.rearSteeringDamping = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_12").value or 8) / 10

    -- self.steerPower = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_13").value or 15) / 10

    self.ffbSmoothing = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_1").value or 10) / 100
    self.ffbMultiplier = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_0").value or 10) / 10
    -- self.crabAngleGainFront = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_14").value or 10) / 10
    -- self.crabAngleGainRear = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_15").value or -30) / 10

    -- self.countersteerGainFront = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_16").value or 10) / 10
    -- self.countersteerLimitFront = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_17").value or 0) / 20
    -- self.countersteerGainRear = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_18").value or 10) / 10
    -- self.countersteerLimitRear = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_19").value or 0) / 20
end


function WheelSteerCtrlr:update(dt)
    self:updateSetupValues()
    self.isReversing = helpers.getWheelsOffGround() > 3 or game.car_cphys.localVelocity.z < 0

    local driftAngle = math.atan2(game.car_cphys.localVelocity.x, game.car_cphys.localVelocity.z)
    
    -- Check for drift angle inversion (crossing +/-pi boundary)
    local angleDiff = driftAngle - self.lastDriftAngle
    if angleDiff > math.pi then
        -- Crossed from +π to -π
        state.control.driftInversion = true
    elseif angleDiff < -math.pi then
        -- Crossed from -π to +π
        state.control.driftInversion = true
    end

    -- Reset inversion flag once car is drifting less than 120 deg
    if math.abs(driftAngle) < math.rad(120) then
        state.control.driftInversion = false
    end
    
    self.lastDriftAngle = driftAngle

    local steerNormalizedInput = math.clamp(game.car_cphys.steer / ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_20").value, -1, 1)

    local targetYawRate = steerNormalizedInput * -15
    local actualYawRate = car.localAngularVelocity.y

    local yawRateOutput = self.yawRatePID:update(targetYawRate, actualYawRate, dt)

    local driftAngleMultiplier = helpers.mapRange(math.abs(driftAngle) * math.sign(steerNormalizedInput), math.rad(90), math.rad(180), 1, 8, true)

    local slipAngleFL = (game.car_cphys.wheels[0].slipAngle ~= 0 and game.car_cphys.wheels[0].slipAngle or self.slipAngleFL_prev)
    local slipAngleFR = (game.car_cphys.wheels[1].slipAngle ~= 0 and game.car_cphys.wheels[1].slipAngle or self.slipAngleFR_prev)
    local slipAngleRL = (game.car_cphys.wheels[2].slipAngle ~= 0 and game.car_cphys.wheels[2].slipAngle or self.slipAngleRL_prev)
    local slipAngleRR = (game.car_cphys.wheels[3].slipAngle ~= 0 and game.car_cphys.wheels[3].slipAngle or self.slipAngleRR_prev)

    self.slipAngleFL_prev = slipAngleFL
    self.slipAngleFR_prev = slipAngleFR
    self.slipAngleRL_prev = slipAngleRL
    self.slipAngleRR_prev = slipAngleRR

    local slipOffsetFL = yawRateOutput * -0.5 * driftAngleMultiplier * helpers.mapRange(car.acceleration.y, 3, 6, 1, 0.5, true)
    local slipOffsetFR = yawRateOutput * -0.5 * driftAngleMultiplier * helpers.mapRange(car.acceleration.y, 3, 6, 1, 0.5, true)
    local slipOffsetRL = yawRateOutput * 0.5 * driftAngleMultiplier * helpers.mapRange(car.acceleration.y, 3, 6, 1, 0.5, true)
    local slipOffsetRR = yawRateOutput * 0.5 * driftAngleMultiplier * helpers.mapRange(car.acceleration.y, 3, 6, 1, 0.5, true)

    -- Calculate base PID-controlled steering targets
    local pidSteerFL = self.FL_slipTargetPID:update(slipOffsetFL, -math.clamp(slipAngleFL, -0.5, 0.5), dt) * helpers.mapRange(car.speedKmh, 10, 60, 0.2, 1, true)
    local pidSteerFR = self.FR_slipTargetPID:update(slipOffsetFR, -math.clamp(slipAngleFR, -0.5, 0.5), dt) * helpers.mapRange(car.speedKmh, 10, 60, 0.2, 1, true)
    local pidSteerRL = self.RL_slipTargetPID:update(slipOffsetRL, -math.clamp(slipAngleRL, -0.5, 0.5), dt) * helpers.mapRange(car.speedKmh, 10, 60, 0.2, 1, true) * helpers.mapRange(car.gas, 0, 1, 1, 0.8, true)
    local pidSteerRR = self.RR_slipTargetPID:update(slipOffsetRR, -math.clamp(slipAngleRR, -0.5, 0.5), dt) * helpers.mapRange(car.speedKmh, 10, 60, 0.2, 1, true) * helpers.mapRange(car.gas, 0, 1, 1, 0.8, true)

    -- Update inversion blend factor
    if state.control.driftInversion then
        self.inversionBlendState = math.min(self.inversionBlendState + dt * self.inversionBlendSpeed, 1)
    else
        self.inversionBlendState = math.max(self.inversionBlendState - dt * self.inversionBlendSpeed, 0)
    end

    -- Calculate inversion steering targets
    local inversionSteerFL = steerNormalizedInput * 4
    local inversionSteerFR = steerNormalizedInput * 4
    local inversionSteerRL = steerNormalizedInput * -2
    local inversionSteerRR = steerNormalizedInput * -2

    -- Blend between normal and inversion steering
    self.desiredSteerFL = math.lerp(pidSteerFL, inversionSteerFL, self.inversionBlendState)
    self.desiredSteerFR = math.lerp(pidSteerFR, inversionSteerFR, self.inversionBlendState)
    self.desiredSteerRL = math.lerp(pidSteerRL, inversionSteerRL, self.inversionBlendState)
    self.desiredSteerRR = math.lerp(pidSteerRR, inversionSteerRR, self.inversionBlendState)

    if car.gear == -1 then
        state.control.driftInversion = false
        self.desiredSteerFL = steerNormalizedInput * 0.5
        self.desiredSteerFR = steerNormalizedInput * 0.5
        self.desiredSteerRL = steerNormalizedInput * -0.2
        self.desiredSteerRR = steerNormalizedInput * -0.2
    end

    self.steerStateFL = self.desiredSteerFL * (state.control.lockedFronts and 0 or 1)
    self.steerStateFR = self.desiredSteerFR * (state.control.lockedFronts and 0 or 1)
    self.steerStateRL = self.desiredSteerRL * (state.control.lockedRears and 0 or 1)
    self.steerStateRR = self.desiredSteerRR * (state.control.lockedRears and 0 or 1)
    
    game.car_cphys.controllerInputs[0], game.car_cphys.controllerInputs[1] = threesixtyctrlr_FL:update(self.steerStateFL, dt)
    game.car_cphys.controllerInputs[2], game.car_cphys.controllerInputs[3] = threesixtyctrlr_FR:update(-self.steerStateFR, dt)
    game.car_cphys.controllerInputs[4], game.car_cphys.controllerInputs[5] = threesixtyctrlr_RL:update(self.steerStateRL, dt)
    game.car_cphys.controllerInputs[6], game.car_cphys.controllerInputs[7] = threesixtyctrlr_RR:update(-self.steerStateRR, dt)

    self.steerStateFL_prev = self.steerStateFL
    self.steerStateFR_prev = self.steerStateFR
    self.steerStateRL_prev = self.steerStateRL
    self.steerStateRR_prev = self.steerStateRR

    --if any steer state is infinite, reset the steering states
    if not (self.steerStateFL == self.steerStateFL) or not (self.steerStateFR == self.steerStateFR) or not (self.steerStateRL == self.steerStateRL) or not (self.steerStateRR == self.steerStateRR) then
        self:reset()
    end

    ac.debug("steerctrl.steerStateFL", self.steerStateFL)
    ac.debug("steerctrl.steerStateFR", self.steerStateFR)
    ac.debug("steerctrl.steerStateRL", self.steerStateRL)
    ac.debug("steerctrl.steerStateRR", self.steerStateRR)
    ac.debug("steerctrl.localVelocity.x", game.car_cphys.localVelocity.x)
    ac.debug("steerctrl.localVelocity.y", game.car_cphys.localVelocity.y)
    ac.debug("steerctrl.localVelocity.z", game.car_cphys.localVelocity.z)
    ac.debug("steerctrl.game.car_cphys.steer", game.car_cphys.steer)
    ac.debug("steerctrl.rawDriftAngle", driftAngle)
    ac.debug("steerctrl.driftAngle", driftAngle)
    ac.debug("steerctrl.targetYawRate", targetYawRate)
    ac.debug("steerctrl.actualYawRate", actualYawRate)
    ac.debug("steerctrl.state.control.lockedRears", state.control.lockedRears)
    ac.debug("steerctrl.state.control.rearAntiCrab", state.control.rearAntiCrab)
    ac.debug("steerctrl.state.control.spinMode", state.control.spinMode)
    ac.debug("steerctrl.FL_slipTargetPID.previousError", self.FL_slipTargetPID.previousError)
    ac.debug("steerctrl.FR_slipTargetPID.previousError", self.FR_slipTargetPID.previousError)
    ac.debug("steerctrl.RL_slipTargetPID.previousError", self.RL_slipTargetPID.previousError)
    ac.debug("steerctrl.RR_slipTargetPID.previousError", self.RR_slipTargetPID.previousError)
    ac.debug("steerctrl.slipAngleFL", game.car_cphys.wheels[0].slipAngle)
    ac.debug("steerctrl.slipAngleFR", game.car_cphys.wheels[1].slipAngle)
    ac.debug("steerctrl.slipAngleRL", game.car_cphys.wheels[2].slipAngle)
    ac.debug("steerctrl.slipAngleRR", game.car_cphys.wheels[3].slipAngle)
    ac.debug("steerctrl.driftInversion", state.control.driftInversion)
    ac.debug("steerctrl.acceleration.y", car.acceleration.y)
end


function WheelSteerCtrlr:reset()
    -- Reset direction and blend states
    self.currentDirectionBlend = 1.0
    self.inversionBlendState = 0
    state.control.driftInversion = false
    self.lastDriftAngle = 0
    
    -- Reset steering states and their previous values
    self.steerStateFL_prev = 0
    self.steerStateFR_prev = 0
    self.steerStateRL_prev = 0
    self.steerStateRR_prev = 0

    self.steerStateFL = 0
    self.steerStateFR = 0
    self.steerStateRL = 0
    self.steerStateRR = 0

    -- Reset desired steering values
    self.desiredSteerFL = 0
    self.desiredSteerFR = 0
    self.desiredSteerRL = 0
    self.desiredSteerRR = 0

    -- Reset slip angle history
    self.slipAngleFL_prev = 0
    self.slipAngleFR_prev = 0
    self.slipAngleRL_prev = 0
    self.slipAngleRR_prev = 0

    -- Reset PID controllers
    self.yawRatePID:reset()
    self.FL_slipTargetPID:reset()
    self.FR_slipTargetPID:reset()
    self.RL_slipTargetPID:reset()
    self.RR_slipTargetPID:reset()

    -- Reset FFB-related values
    self.steerInputLast = 0
    self.lastFFB = 0
    for i = 1, #self.steerChangeHistory do
        self.steerChangeHistory[i] = 0
    end
    self.historyIndex = 1
end


return WheelSteerCtrlr
