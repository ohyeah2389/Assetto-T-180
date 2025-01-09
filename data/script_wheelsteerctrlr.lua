-- T-180 CSP Physics Script - Steering Controller Module
-- Authored by ohyeah2389

local state = require('script_state')
local game = require('script_acConnection')
local helpers = require('script_helpers')
local physics = require('script_physics')
local PIDController = require('script_pid')

local WheelSteerCtrlr = class("WheelSteerCtrlr")


function WheelSteerCtrlr:initialize()
    self.maxSteeringSlewRate = 20.0  -- Maximum change in steering per second

    self.driftAnglePower = 0.05
    self.driftAngleDamping = 0.3
    self.driftAnglePID = PIDController(self.driftAnglePower, 0, 0, -4, 4, self.driftAngleDamping)

    self.frontSteeringPower = 0.5
    self.frontSteeringDamping = 0.8
    self.rearSteeringPower = 0.7
    self.rearSteeringDamping = 0.8
    self.frontSteeringPID = PIDController(self.frontSteeringPower, 0, 0, -10, 10, self.frontSteeringDamping)
    self.rearSteeringPID = PIDController(self.rearSteeringPower, 0, 0, -10, 10, self.rearSteeringDamping)

    self.steerPower = 1.5
    self.steerDamping = 0.02 -- gets overridden by highSpeedDamping in :update
    self.frontLeftPID = PIDController(self.steerPower, 0, 0.0001, -1, 1, self.steerDamping)
    self.frontRightPID = PIDController(self.steerPower, 0, 0.0001, -1, 1, self.steerDamping)
    self.rearLeftPID = PIDController(self.steerPower, 0, 0.0001, -1, 1, self.steerDamping)
    self.rearRightPID = PIDController(self.steerPower, 0, 0.0001, -1, 1, self.steerDamping)

    self.steerInputLast = game.car_cphys.steer
    self.ffbSmoothing = 0.1  -- Higher = more smoothing (0-1)
    self.ffbMultiplier = 1.0
    self.lastFFB = 0
    self.steerChangeHistory = {0, 0, 0, 0, 0}  -- Circular buffer for averaging
    self.historyIndex = 1

    self.crabAngleGainFront = 1.0
    self.crabAngleGainRear = -3.0

    self.countersteerGainFront = 1
    self.countersteerLimitFront = 0
    self.countersteerGainRear = 1
    self.countersteerLimitRear = 0

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
end


function WheelSteerCtrlr:calculateFFB(dt)
    -- Prevent division by zero
    dt = math.max(dt, 0.001)
    
    -- Add safety check for NaN/infinite values
    if not game.car_cphys.steer or not self.steerInputLast then
        return 0
    end

    local steerChange = (game.car_cphys.steer - self.steerInputLast) / dt
    self.steerInputLast = game.car_cphys.steer

    -- Add null checks for wheel slip angles
    local frontSlipAngle = (game.car_cphys.wheels[0].slipAngle or 0) + (game.car_cphys.wheels[1].slipAngle or 0)
    local rearSlipAngle = (game.car_cphys.wheels[2].slipAngle or 0) + (game.car_cphys.wheels[3].slipAngle or 0)

    local frontSteerEffect = (self.desiredSteerFL + self.desiredSteerFR) * 0
    local frontSlipEffect = math.clamp(frontSlipAngle * -5, -6, 6)
    local rearSteerEffect = (self.desiredSteerRL + self.desiredSteerRR) * 0
    local rearSlipEffect = math.clamp(rearSlipAngle * -15, -6, 6)
    local latGEffect = math.clamp(game.car_cphys.gForces.x or 0, -5, 5) * 0
    local helperEffect = frontSteerEffect + frontSlipEffect + rearSteerEffect + rearSlipEffect + latGEffect

    -- Debug values
    ac.debug("ffb.helperEffect", helperEffect)
    ac.debug("ffb.frontSteerEffect", frontSteerEffect)
    ac.debug("ffb.frontSlipEffect", frontSlipEffect)
    ac.debug("ffb.rearSteerEffect", rearSteerEffect)
    ac.debug("ffb.rearSlipEffect", rearSlipEffect)
    ac.debug("ffb.latGEffect", latGEffect)
    
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


function WheelSteerCtrlr:update(dt)
    self.isReversing = helpers.getWheelsOffGround() > 3 or game.car_cphys.localVelocity.z < 0

    local driftAngle = math.atan(game.car_cphys.localVelocity.x / math.abs(game.car_cphys.localVelocity.z))

    local targetDriftAngle = car.steer * math.rad(40)

    state.control.countersteer = math.sign(driftAngle) ~= math.sign(car.steer) and math.abs(car.steer) * math.min(math.abs(driftAngle / math.rad(30)), 1) or 0
    state.control.countersteer = helpers.mapRange(car.speedKmh, 20, 40, 0, 1, true) * math.clamp(state.control.countersteer, -90, 90)

    self.frontSteeringPID.p = helpers.mapRange(game.car_cphys.speedKmh, 0, 40, 3.0, self.frontSteeringPower * ((state.control.lockedRears or state.control.rearAntiCrab) and 2 or 1), true)
    self.rearSteeringPID.p = helpers.mapRange(game.car_cphys.speedKmh, 0, 40, 0.1, self.rearSteeringPower * (state.control.rearAntiCrab and 1.5 or 1), true) * helpers.mapRange(state.control.countersteer, 0, 1, 1, 0, true) * helpers.mapRange(car.brake, 0, 1, 1, 0, true)

    local highSpeedDamping = helpers.mapRange(game.car_cphys.speedKmh, 100, 400, 0.01, 0.002, true)

    self.frontLeftPID.p = helpers.mapRange(game.car_cphys.speedKmh, 2, 5, 0.05, self.steerPower, true)
    self.frontLeftPID.dampingFactor = helpers.mapRange(game.car_cphys.speedKmh, 1, 10, 0.001, highSpeedDamping, true)
    self.frontRightPID.p = helpers.mapRange(game.car_cphys.speedKmh, 2, 5, 0.05, self.steerPower, true)
    self.frontRightPID.dampingFactor = helpers.mapRange(game.car_cphys.speedKmh, 1, 10, 0.001, highSpeedDamping, true)
    self.rearLeftPID.p = helpers.mapRange(game.car_cphys.speedKmh, 2, 5, 0.05, self.steerPower, true)
    self.rearLeftPID.dampingFactor = helpers.mapRange(game.car_cphys.speedKmh, 1, 10, 0.001, highSpeedDamping, true)
    self.rearRightPID.p = helpers.mapRange(game.car_cphys.speedKmh, 2, 5, 0.05, self.steerPower, true)
    self.rearRightPID.dampingFactor = helpers.mapRange(game.car_cphys.speedKmh, 1, 10, 0.001, highSpeedDamping, true)

    local driftAngleSetpoint = self.driftAnglePID:update(targetDriftAngle, driftAngle, dt)

    local slipAngleFrontCommanded = self.frontSteeringPID:update(driftAngleSetpoint, -game.car_cphys.localAngularVelocity.y, dt)
    local slipAngleRearCommanded = self.rearSteeringPID:update(-driftAngleSetpoint, game.car_cphys.localAngularVelocity.y, dt)

    local normalModeSteer = {
        fl = self.frontLeftPID:update(slipAngleFrontCommanded + (game.car_cphys.steer * (self.crabAngleGainFront * (math.abs(game.car_cphys.steer) ^ 0.6)) * helpers.mapRange(state.control.countersteer, 0, self.countersteerGainFront, 1, self.countersteerLimitFront, true)), -game.car_cphys.wheels[0].slipAngle, dt),
        fr = self.frontRightPID:update(slipAngleFrontCommanded + (game.car_cphys.steer * (self.crabAngleGainFront * (math.abs(game.car_cphys.steer) ^ 0.6)) * helpers.mapRange(state.control.countersteer, 0, self.countersteerGainFront, 1, self.countersteerLimitFront, true)), -game.car_cphys.wheels[1].slipAngle, dt),
        rl = self.rearLeftPID:update(slipAngleRearCommanded + (game.car_cphys.steer * (self.crabAngleGainRear * (state.control.rearAntiCrab and -0.5 or 1) * (math.abs(game.car_cphys.steer) ^ 0.6)) * helpers.mapRange(state.control.countersteer * (self.isReversing and -1 or 1), 0, self.countersteerGainRear, 1, self.countersteerLimitRear, true)), -game.car_cphys.wheels[2].slipAngle, dt),
        rr = self.rearRightPID:update(slipAngleRearCommanded + (game.car_cphys.steer * (self.crabAngleGainRear * (state.control.rearAntiCrab and -0.5 or 1) * (math.abs(game.car_cphys.steer) ^ 0.6)) * helpers.mapRange(state.control.countersteer * (self.isReversing and -1 or 1), 0, self.countersteerGainRear, 1, self.countersteerLimitRear, true)), -game.car_cphys.wheels[3].slipAngle, dt)
    }

    local spinModeSteer = {
        fl = game.car_cphys.steer * 1,
        fr = game.car_cphys.steer * 1,
        rl = -game.car_cphys.steer * 1.5,
        rr = -game.car_cphys.steer * 1.5
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
    
    game.car_cphys.controllerInputs[0] = (self.steerStateFL)
    game.car_cphys.controllerInputs[1] = (-self.steerStateFR)
    game.car_cphys.controllerInputs[2] = (-self.steerStateRL)
    game.car_cphys.controllerInputs[3] = (self.steerStateRR)

    self.steerStateFL_prev = self.steerStateFL
    self.steerStateFR_prev = self.steerStateFR
    self.steerStateRL_prev = self.steerStateRL
    self.steerStateRR_prev = self.steerStateRR

    ac.debug("steerctrl.slipAngleFrontCommanded", slipAngleFrontCommanded)
    ac.debug("steerctrl.slipAngleRearCommanded", slipAngleRearCommanded)
    ac.debug("steerctrl.steerStateFL", self.steerStateFL)
    ac.debug("steerctrl.steerStateFR", self.steerStateFR)
    ac.debug("steerctrl.steerStateRL", self.steerStateRL)
    ac.debug("steerctrl.steerStateRR", self.steerStateRR)
    ac.debug("steerctrl.localVelocity.x", game.car_cphys.localVelocity.x)
    ac.debug("steerctrl.localVelocity.y", game.car_cphys.localVelocity.y)
    ac.debug("steerctrl.localVelocity.z", game.car_cphys.localVelocity.z)
    ac.debug("steerctrl.steer", car.steer)
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
    
    -- Reset the previous steering states
    self.steerStateFL_prev = 0
    self.steerStateFR_prev = 0
    self.steerStateRL_prev = 0
    self.steerStateRR_prev = 0

    self.steerStateFL = 0
    self.steerStateFR = 0
    self.steerStateRL = 0
    self.steerStateRR = 0

    self.currentMode = self.steeringModes.normal
    self.targetMode = self.steeringModes.normal
    self.modeBlendFactor = 1.0
end


return WheelSteerCtrlr
