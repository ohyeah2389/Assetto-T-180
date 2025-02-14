-- T-180 CSP Physics Script - Steering Controller Module
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
    self.maxSteeringSlewRate = 20.0  -- Maximum change in steering per second

    -- Initialize controllers with default values
    self.steerPower = 1.5 -- gets overridden by :updateSetupValues
    self.steerDamping = 0.02 -- gets overridden by highSpeedDamping in :update
    self.frontLeftPID = PIDController(1.5, 0, 0.0001, -1, 1, self.steerDamping)
    self.frontRightPID = PIDController(1.5, 0, 0.0001, -1, 1, self.steerDamping)
    self.rearLeftPID = PIDController(1.5, 0, 0.0001, -1, 1, self.steerDamping)
    self.rearRightPID = PIDController(1.5, 0, 0.0001, -1, 1, self.steerDamping)
    self.driftAnglePID = PIDController(0.05, 0, 0, -4, 4, 0.3)
    self.frontSteeringPID = PIDController(0.5, 0, 0, -10, 10, 0.8)
    self.rearSteeringPID = PIDController(0.7, 0, 0, -10, 10, 0.8)

    self.steerInputLast = game.car_cphys.steer
    self.lastFFB = 0
    self.steerChangeHistory = {0, 0, 0, 0, 0}  -- Circular buffer for averaging
    self.historyIndex = 1

    self.countersteerGainFront = 1 -- gets overridden by :updateSetupValues
    self.countersteerLimitFront = 0 -- gets overridden by :updateSetupValues
    self.countersteerGainRear = 1 -- gets overridden by :updateSetupValues
    self.countersteerLimitRear = 0 -- gets overridden by :updateSetupValues

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

    self.isReversing = false

    self.steeringModes = {
        normal = 1,
        spin = 2
    }
    self.currentMode = self.steeringModes.normal
    self.targetMode = self.steeringModes.normal
    self.modeBlendFactor = 1.0  -- 1.0 = fully in current mode
    self.modeTransitionSpeed = 0.2  -- Time in seconds for full transition

    -- Force an immediate update of all setup values
    self.setupUpdateCounter = 60
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
    if self.setupUpdateCounter < 60 then return end  -- Update every ~1 second at 60fps
    self.setupUpdateCounter = 0

    -- Set new values
    self.driftAnglePID.kP = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_7").value or 5) / 100
    self.driftAnglePID.dampingFactor = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_8").value or 30) / 100

    self.frontSteeringPower = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_9").value or 5) / 10
    self.frontSteeringDamping = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_10").value or 8) / 10

    self.rearSteeringPower = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_11").value or 7) / 10
    self.rearSteeringDamping = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_12").value or 8) / 10

    self.steerPower = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_13").value or 15) / 10

    self.ffbSmoothing = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_1").value or 10) / 100
    self.ffbMultiplier = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_0").value or 10) / 10
    self.crabAngleGainFront = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_14").value or 10) / 10
    self.crabAngleGainRear = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_15").value or -30) / 10

    self.countersteerGainFront = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_16").value or 10) / 10
    self.countersteerLimitFront = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_17").value or 0) / 20
    self.countersteerGainRear = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_18").value or 10) / 10
    self.countersteerLimitRear = (ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_19").value or 0) / 20
end


function WheelSteerCtrlr:update(dt)
    self:updateSetupValues()
    self.isReversing = helpers.getWheelsOffGround() > 3 or game.car_cphys.localVelocity.z < 0

    local driftAngle = math.atan(game.car_cphys.localVelocity.x / math.abs(game.car_cphys.localVelocity.z))

    local steerNormalizedInput = math.clamp(game.car_cphys.steer / ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_20").value, -1, 1)

    local targetDriftAngle = (steerNormalizedInput * 90) * math.rad(40)

    state.control.countersteer = math.sign(driftAngle) ~= math.sign(steerNormalizedInput) and math.abs(steerNormalizedInput * 90) * math.min(math.abs(driftAngle / math.rad(30)), 1) or 0
    state.control.countersteer = helpers.mapRange(car.speedKmh, 20, 40, 0, 1, true) * math.clamp(state.control.countersteer, -90, 90)

    self.frontSteeringPID.kP = helpers.mapRange(game.car_cphys.speedKmh, 0, 40, 3.0, self.frontSteeringPower * ((state.control.lockedRears or state.control.rearAntiCrab) and 2 or 1), true)
    self.rearSteeringPID.kP = helpers.mapRange(game.car_cphys.speedKmh, 0, 40, 0.1, self.rearSteeringPower * (state.control.rearAntiCrab and 1.5 or 1), true) * helpers.mapRange(state.control.countersteer, 0, 1, 1, 0, true) * helpers.mapRange(car.brake, 0, 1, 1, 0, true)

    local highSpeedDamping = helpers.mapRange(game.car_cphys.speedKmh, 100, 400, 0.01, 0.002, true)

    self.frontLeftPID.kP = helpers.mapRange(game.car_cphys.speedKmh, 2, 20, 0.008, self.steerPower, true)
    self.frontLeftPID.dampingFactor = helpers.mapRange(game.car_cphys.speedKmh, 1, 10, 0.001, highSpeedDamping, true)
    self.frontRightPID.kP = helpers.mapRange(game.car_cphys.speedKmh, 2, 20, 0.008, self.steerPower, true)
    self.frontRightPID.dampingFactor = helpers.mapRange(game.car_cphys.speedKmh, 1, 10, 0.001, highSpeedDamping, true)
    self.rearLeftPID.kP = helpers.mapRange(game.car_cphys.speedKmh, 2, 20, 0.004, self.steerPower, true)
    self.rearLeftPID.dampingFactor = helpers.mapRange(game.car_cphys.speedKmh, 1, 10, 0.001, highSpeedDamping, true)
    self.rearRightPID.kP = helpers.mapRange(game.car_cphys.speedKmh, 2, 20, 0.004, self.steerPower, true)
    self.rearRightPID.dampingFactor = helpers.mapRange(game.car_cphys.speedKmh, 1, 10, 0.001, highSpeedDamping, true)

    local driftAngleSetpoint = self.driftAnglePID:update(targetDriftAngle, driftAngle, dt)

    local slipAngleFrontCommanded = self.frontSteeringPID:update(driftAngleSetpoint, -game.car_cphys.localAngularVelocity.y, dt)
    local slipAngleRearCommanded = self.rearSteeringPID:update(-driftAngleSetpoint, game.car_cphys.localAngularVelocity.y, dt)

    local normalModeSteer = {
        fl = self.frontLeftPID:update(slipAngleFrontCommanded + (steerNormalizedInput * (self.crabAngleGainFront * (math.abs(steerNormalizedInput) ^ 0.6)) * helpers.mapRange(state.control.countersteer, 0, self.countersteerGainFront, 1, self.countersteerLimitFront, true)), -game.car_cphys.wheels[0].slipAngle, dt),
        fr = self.frontRightPID:update(slipAngleFrontCommanded + (steerNormalizedInput * (self.crabAngleGainFront * (math.abs(steerNormalizedInput) ^ 0.6)) * helpers.mapRange(state.control.countersteer, 0, self.countersteerGainFront, 1, self.countersteerLimitFront, true)), -game.car_cphys.wheels[1].slipAngle, dt),
        rl = self.rearLeftPID:update(slipAngleRearCommanded + (steerNormalizedInput * (self.crabAngleGainRear * (state.control.rearAntiCrab and -0.5 or 1) * (math.abs(steerNormalizedInput) ^ 0.6)) * helpers.mapRange(state.control.countersteer * (self.isReversing and -1 or 1), 0, self.countersteerGainRear, 1, self.countersteerLimitRear, true)), -game.car_cphys.wheels[2].slipAngle, dt),
        rr = self.rearRightPID:update(slipAngleRearCommanded + (steerNormalizedInput * (self.crabAngleGainRear * (state.control.rearAntiCrab and -0.5 or 1) * (math.abs(steerNormalizedInput) ^ 0.6)) * helpers.mapRange(state.control.countersteer * (self.isReversing and -1 or 1), 0, self.countersteerGainRear, 1, self.countersteerLimitRear, true)), -game.car_cphys.wheels[3].slipAngle, dt)
    }

    local spinModeSteer = {
        fl = steerNormalizedInput * 1,
        fr = steerNormalizedInput * 1,
        rl = -steerNormalizedInput * 1.5,
        rr = -steerNormalizedInput * 1.5
    }

    -- Update mode transition
    self.targetMode = state.control.spinMode and self.steeringModes.spin or self.steeringModes.normal
    
    -- Blend factor approaches 1 when current = target, 0 when transitioning
    if self.currentMode ~= self.targetMode then
        self.modeBlendFactor = math.max(0, self.modeBlendFactor - dt / self.modeTransitionSpeed)
        if self.modeBlendFactor == 0 then
            self.currentMode = self.targetMode
            self.modeBlendFactor = 1.0
        end
    else
        self.modeBlendFactor = math.min(1, self.modeBlendFactor + dt / self.modeTransitionSpeed)
    end

    -- Blend between modes using smoothstep
    local function blendSteer(normal, spin)
        local smoothBlend = math.smoothstep(self.modeBlendFactor)
        if self.currentMode == self.steeringModes.normal then
            return normal * smoothBlend + spin * (1 - smoothBlend)
        else
            return spin * smoothBlend + normal * (1 - smoothBlend)
        end
    end

    self.desiredSteerFL = blendSteer(normalModeSteer.fl, spinModeSteer.fl)
    self.desiredSteerFR = blendSteer(normalModeSteer.fr, spinModeSteer.fr)
    self.desiredSteerRL = blendSteer(normalModeSteer.rl, spinModeSteer.rl)
    self.desiredSteerRR = blendSteer(normalModeSteer.rr, spinModeSteer.rr)

    local maxDelta = self.maxSteeringSlewRate * dt
    self.steerStateFL = helpers.clampChange(self.desiredSteerFL * (state.control.lockedFronts and 0 or 1), self.steerStateFL_prev, maxDelta)
    self.steerStateFR = helpers.clampChange(self.desiredSteerFR * (state.control.lockedFronts and 0 or 1), self.steerStateFR_prev, maxDelta)
    self.steerStateRL = helpers.clampChange(self.desiredSteerRL * (state.control.lockedRears and 0 or 1), self.steerStateRL_prev, maxDelta)
    self.steerStateRR = helpers.clampChange(self.desiredSteerRR * (state.control.lockedRears and 0 or 1), self.steerStateRR_prev, maxDelta)
    
    game.car_cphys.controllerInputs[0], game.car_cphys.controllerInputs[1] = threesixtyctrlr_FL:update(self.steerStateFL / 2, dt)
    game.car_cphys.controllerInputs[2], game.car_cphys.controllerInputs[3] = threesixtyctrlr_FR:update(-self.steerStateFR / 2, dt)
    game.car_cphys.controllerInputs[4], game.car_cphys.controllerInputs[5] = threesixtyctrlr_RL:update(self.steerStateRL / 2, dt)
    game.car_cphys.controllerInputs[6], game.car_cphys.controllerInputs[7] = threesixtyctrlr_RR:update(-self.steerStateRR / 2, dt)

    self.steerStateFL_prev = self.steerStateFL
    self.steerStateFR_prev = self.steerStateFR
    self.steerStateRL_prev = self.steerStateRL
    self.steerStateRR_prev = self.steerStateRR

    --if any steer state is infinite, reset the steering states
    if not (self.steerStateFL == self.steerStateFL) or not (self.steerStateFR == self.steerStateFR) or not (self.steerStateRL == self.steerStateRL) or not (self.steerStateRR == self.steerStateRR) then
        self:reset()
    end

    ac.debug("steerctrl.slipAngleFrontCommanded", slipAngleFrontCommanded)
    ac.debug("steerctrl.slipAngleRearCommanded", slipAngleRearCommanded)
    ac.debug("steerctrl.steerStateFL", self.steerStateFL)
    ac.debug("steerctrl.steerStateFR", self.steerStateFR)
    ac.debug("steerctrl.steerStateRL", self.steerStateRL)
    ac.debug("steerctrl.steerStateRR", self.steerStateRR)
    ac.debug("steerctrl.localVelocity.x", game.car_cphys.localVelocity.x)
    ac.debug("steerctrl.localVelocity.y", game.car_cphys.localVelocity.y)
    ac.debug("steerctrl.localVelocity.z", game.car_cphys.localVelocity.z)
    ac.debug("steerctrl.modeBlendFactor", self.modeBlendFactor)
    ac.debug("steerctrl.game.car_cphys.steer", game.car_cphys.steer)
    ac.debug("steerctrl.driftAngle", driftAngle)
    ac.debug("steerctrl.driftAngleSetpoint", driftAngleSetpoint)
    ac.debug("steerctrl.state.control.countersteer", state.control.countersteer)
    ac.debug("steerctrl.state.control.lockedRears", state.control.lockedRears)
    ac.debug("steerctrl.state.control.rearAntiCrab", state.control.rearAntiCrab)
    ac.debug("steerctrl.state.control.spinMode", state.control.spinMode)
end


function WheelSteerCtrlr:reset()
    self.driftAnglePID:reset()
    self.frontSteeringPID:reset()
    self.rearSteeringPID:reset()
    self.frontLeftPID:reset()
    self.frontRightPID:reset()
    self.rearLeftPID:reset()
    self.rearRightPID:reset()
    self.currentDirectionBlend = 1.0
    
    -- Reset the previous steering states if needed
    self.steerStateFL_prev = (self.steerStateFL_prev ~= self.steerStateFL_prev or math.abs(self.steerStateFL_prev) == math.huge) and 0 or self.steerStateFL_prev
    self.steerStateFR_prev = (self.steerStateFR_prev ~= self.steerStateFR_prev or math.abs(self.steerStateFR_prev) == math.huge) and 0 or self.steerStateFR_prev
    self.steerStateRL_prev = (self.steerStateRL_prev ~= self.steerStateRL_prev or math.abs(self.steerStateRL_prev) == math.huge) and 0 or self.steerStateRL_prev
    self.steerStateRR_prev = (self.steerStateRR_prev ~= self.steerStateRR_prev or math.abs(self.steerStateRR_prev) == math.huge) and 0 or self.steerStateRR_prev

    self.steerStateFL = (self.steerStateFL ~= self.steerStateFL or math.abs(self.steerStateFL) == math.huge) and 0 or self.steerStateFL
    self.steerStateFR = (self.steerStateFR ~= self.steerStateFR or math.abs(self.steerStateFR) == math.huge) and 0 or self.steerStateFR
    self.steerStateRL = (self.steerStateRL ~= self.steerStateRL or math.abs(self.steerStateRL) == math.huge) and 0 or self.steerStateRL
    self.steerStateRR = (self.steerStateRR ~= self.steerStateRR or math.abs(self.steerStateRR) == math.huge) and 0 or self.steerStateRR

    self.currentMode = self.steeringModes.normal
    self.targetMode = self.steeringModes.normal
    self.modeBlendFactor = 1.0
end


return WheelSteerCtrlr
