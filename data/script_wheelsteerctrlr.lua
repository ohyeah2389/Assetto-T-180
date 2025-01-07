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

    self.crabAngleGainFront = 1.0
    self.crabAngleGainRear = -3.0

    self.steerStateFL = 0
    self.steerStateFR = 0
    self.steerStateRL = 0
    self.steerStateRR = 0

    self.steerStateFL_prev = 0
    self.steerStateFR_prev = 0
    self.steerStateRL_prev = 0
    self.steerStateRR_prev = 0

    self.isReversing = false

    -- Initialize steering wheel physics
    self.steeringWheel = physics({
        rotary = false,
        posMin = -1,
        posMax = 1,
        center = 0,
        position = game.car_cphys.steer,
        mass = 0.1,  -- Steering wheel effective mass
        springCoef = 10.0,  -- Center spring force
        frictionCoef = 1.5,  -- Damping/friction coefficient
        staticFrictionCoef = 0,
        expFrictionCoef = 1.5,  -- Non-linear damping
        forceMax = 10,  -- Maximum force that can be applied
        endstopRate = 100  -- Strong resistance at ends of travel
    })
end


function WheelSteerCtrlr:calculateFFB(dt)
    -- Calculate force to apply to physics object to match wheel position
    local positionError = game.car_cphys.steer - self.steeringWheel.position
    local positionForce = positionError * 20  -- Position following strength

    -- Step the physics simulation
    self.steeringWheel:step(positionForce, dt)

    -- Convert the physics object's force to FFB output (-1 to 1)
    local steeringFFB = -self.steeringWheel.force / self.steeringWheel.forceMax

    ac.debug("steerctrl.steeringWheel.force", self.steeringWheel.force)
    ac.debug("steerctrl.steeringWheel.position", self.steeringWheel.position)
    ac.debug("steerctrl.positionError", positionError)
    ac.debug("steerctrl.steeringFFB", steeringFFB)

    return game.car_cphys.steer * 1
end


function WheelSteerCtrlr:update(dt)
    local wheelsOffGround = helpers.getWheelsOffGround()

    -- If more than 3 wheels off ground, return early
    if wheelsOffGround > 3 then
        self.isReversing = false
    else
        self.isReversing = game.car_cphys.localVelocity.z < 0
    end

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

    local steerNormalized = helpers.mapRange(car.steer, -90, 90, -1, 1, true)

    local desiredSteerFL = self.frontLeftPID:update(slipAngleFrontCommanded + (steerNormalized * (self.crabAngleGainFront * (math.abs(steerNormalized) ^ 0.6)) * helpers.mapRange(state.control.countersteer, 0, 1, 1, 0, true)), -game.car_cphys.wheels[0].slipAngle, dt)
    local desiredSteerFR = self.frontRightPID:update(slipAngleFrontCommanded + (steerNormalized * (self.crabAngleGainFront * (math.abs(steerNormalized) ^ 0.6)) * helpers.mapRange(state.control.countersteer, 0, 1, 1, 0, true)), -game.car_cphys.wheels[1].slipAngle, dt)
    local desiredSteerRL = self.rearLeftPID:update(slipAngleRearCommanded + (steerNormalized * (self.crabAngleGainRear * (state.control.rearAntiCrab and -0.5 or 1) * (math.abs(steerNormalized) ^ 0.6)) * helpers.mapRange(state.control.countersteer * (self.isReversing and -1 or 1), 0, 1, 1, 0, true)), -game.car_cphys.wheels[2].slipAngle, dt)
    local desiredSteerRR = self.rearRightPID:update(slipAngleRearCommanded + (steerNormalized * (self.crabAngleGainRear * (state.control.rearAntiCrab and -0.5 or 1) * (math.abs(steerNormalized) ^ 0.6)) * helpers.mapRange(state.control.countersteer * (self.isReversing and -1 or 1), 0, 1, 1, 0, true)), -game.car_cphys.wheels[3].slipAngle, dt)

    local maxDelta = self.maxSteeringSlewRate * dt
    self.steerStateFL = helpers.clampChange(desiredSteerFL, self.steerStateFL_prev, maxDelta)
    self.steerStateFR = helpers.clampChange(desiredSteerFR, self.steerStateFR_prev, maxDelta)
    self.steerStateRL = helpers.clampChange(desiredSteerRL * (state.control.lockedRears and 0 or 1), self.steerStateRL_prev, maxDelta)
    self.steerStateRR = helpers.clampChange(desiredSteerRR * (state.control.lockedRears and 0 or 1), self.steerStateRR_prev, maxDelta)
    
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
    ac.debug("steerctrl.driftAngle", driftAngle)
    ac.debug("steerctrl.state.control.countersteer", state.control.countersteer)
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
end


return WheelSteerCtrlr
