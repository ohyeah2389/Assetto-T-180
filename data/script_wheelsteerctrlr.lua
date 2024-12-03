-- T-180 CSP Physics Script - Steering Controller Module
-- Authored by ohyeah2389

local state = require('script_state')
local game = require('script_acConnection')
local helpers = require('script_helpers')
local physics = require('script_physics')
local PIDController = require('script_pid')


local WheelSteerCtrlr = class("WheelSteerCtrlr")


function WheelSteerCtrlr:initialize()
    self.driftAnglePower = 0.07
    self.driftAngleDamping = 0.015
    self.driftAnglePID = PIDController(self.driftAnglePower, 0, 0, -4, 4, self.driftAngleDamping)

    self.frontSteeringPower = 0.5
    self.frontSteeringDamping = 0.8
    self.rearSteeringPower = 0.7
    self.rearSteeringDamping = 0.8
    self.frontSteeringPID = PIDController(self.frontSteeringPower, 0, 0, -10, 10, self.frontSteeringDamping)
    self.rearSteeringPID = PIDController(self.rearSteeringPower, 0, 0, -10, 10, self.rearSteeringDamping)

    self.steerPower = 1.5
    self.steerDamping = 0.02 -- gets overridden by highSpeedDamping in :update
    self.frontLeftPID = PIDController(self.steerPower, 0, 0, -1, 1, self.steerDamping)
    self.frontRightPID = PIDController(self.steerPower, 0, 0, -1, 1, self.steerDamping)
    self.rearLeftPID = PIDController(self.steerPower, 0, 0, -1, 1, self.steerDamping)
    self.rearRightPID = PIDController(self.steerPower, 0, 0, -1, 1, self.steerDamping)

    self.crabAngleGainFront = 0.5
    self.crabAngleGainRear = -4.0

    self.directionBlendTime = 0.2  -- Time in seconds for the transition
    self.currentDirectionBlend = 1.0

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
    local wheelsOnGround = {
        game.car_cphys.wheels[0].load > 0,
        game.car_cphys.wheels[1].load > 0,
        game.car_cphys.wheels[2].load > 0,
        game.car_cphys.wheels[3].load > 0
    }
    -- Count wheels not on ground
    local wheelsOffGround = 0
    for _, onGround in ipairs(wheelsOnGround) do
        if not onGround then
            wheelsOffGround = wheelsOffGround + 1
        end
    end

    local isReversing
    -- If more than 3 wheels off ground, return early
    if wheelsOffGround > 3 then
        isReversing = false
    else
        isReversing = game.car_cphys.localVelocity.z < 0
    end
    
    
    
    local targetDirectionBlend = isReversing and -1.0 or 1.0
    local alpha = 1.0 - math.exp(-dt / self.directionBlendTime)
    self.currentDirectionBlend = self.currentDirectionBlend + (targetDirectionBlend - self.currentDirectionBlend) * alpha
    
    local driftAngle = math.atan(game.car_cphys.localVelocity.x / math.abs(game.car_cphys.localVelocity.z))
    if isReversing then
        driftAngle = -driftAngle
    end
    
    local targetDriftAngle = car.steer * math.rad(30)
    
    state.control.countersteer = math.sign(driftAngle) ~= math.sign(car.steer) and math.abs(car.steer) * math.min(math.abs(driftAngle / math.rad(30)), 1) or 0
    state.control.countersteer = helpers.mapRange(car.speedKmh, 20, 40, 0, 1, true) * math.clamp(state.control.countersteer, -90, 90)

    self.frontSteeringPID.p = helpers.mapRange(game.car_cphys.speedKmh, 0, 20, 1.5, self.frontSteeringPower, true)
    self.rearSteeringPID.p = helpers.mapRange(game.car_cphys.speedKmh, 0, 20, 0.5, self.rearSteeringPower, true) * helpers.mapRange(state.control.countersteer, 0, 1, 1, 0, true) * helpers.mapRange(car.brake, 0, 1, 1, 0, true)
    self.frontLeftPID.p = helpers.mapRange(game.car_cphys.speedKmh, 2, 5, 0.05, self.steerPower, true)
    local highSpeedDamping = helpers.mapRange(game.car_cphys.speedKmh, 100, 400, 0.04, 0.01, true)
    self.frontLeftPID.dampingFactor = helpers.mapRange(game.car_cphys.speedKmh, 1, 5, 0.01, highSpeedDamping, true)
    self.frontRightPID.p = helpers.mapRange(game.car_cphys.speedKmh, 2, 5, 0.05, self.steerPower, true)
    self.frontRightPID.dampingFactor = helpers.mapRange(game.car_cphys.speedKmh, 1, 5, 0.01, highSpeedDamping, true)
    self.rearLeftPID.p = helpers.mapRange(game.car_cphys.speedKmh, 2, 5, 0.05, self.steerPower, true)
    self.rearLeftPID.dampingFactor = helpers.mapRange(game.car_cphys.speedKmh, 1, 5, 0.01, highSpeedDamping, true)
    self.rearRightPID.p = helpers.mapRange(game.car_cphys.speedKmh, 2, 5, 0.05, self.steerPower, true)
    self.rearRightPID.dampingFactor = helpers.mapRange(game.car_cphys.speedKmh, 1, 5, 0.01, highSpeedDamping, true)

    local driftAngleSetpoint = self.driftAnglePID:update(targetDriftAngle, driftAngle, dt)

    local slipAngleFrontCommanded = self.frontSteeringPID:update(driftAngleSetpoint, -game.car_cphys.localAngularVelocity.y, dt) * (car.extraC and 0 or 1)
    local slipAngleRearCommanded = self.rearSteeringPID:update(-driftAngleSetpoint, game.car_cphys.localAngularVelocity.y, dt) * (car.extraD and 0 or 1)

    local steerNormalized = helpers.mapRange(car.steer, -90, 90, -1, 1, true)

    local steerFrontLeft = self.frontLeftPID:update(slipAngleFrontCommanded + (steerNormalized * (self.crabAngleGainFront * (math.abs(steerNormalized) ^ 0.6)) * helpers.mapRange(state.control.countersteer, 0, 1, 1, 0, true)), -game.car_cphys.wheels[0].slipAngle, dt)
    local steerFrontRight = self.frontRightPID:update(slipAngleFrontCommanded + (steerNormalized * (self.crabAngleGainFront * (math.abs(steerNormalized) ^ 0.6)) * helpers.mapRange(state.control.countersteer, 0, 1, 1, 0, true)), -game.car_cphys.wheels[1].slipAngle, dt)
    local steerRearLeft = self.rearLeftPID:update(slipAngleRearCommanded + (steerNormalized * (self.crabAngleGainRear * (math.abs(steerNormalized) ^ 0.6)) * helpers.mapRange(state.control.countersteer, 0, 1, 1, 0, true)), -game.car_cphys.wheels[2].slipAngle, dt)
    local steerRearRight = self.rearRightPID:update(slipAngleRearCommanded + (steerNormalized * (self.crabAngleGainRear * (math.abs(steerNormalized) ^ 0.6)) * helpers.mapRange(state.control.countersteer, 0, 1, 1, 0, true)), -game.car_cphys.wheels[3].slipAngle, dt)

    game.car_cphys.controllerInputs[0] = (-steerFrontLeft)
    game.car_cphys.controllerInputs[1] = (steerFrontRight)
    game.car_cphys.controllerInputs[2] = (-steerRearLeft) * self.currentDirectionBlend
    game.car_cphys.controllerInputs[3] = (steerRearRight) * self.currentDirectionBlend

    local thrusterForce = 0
    if not isReversing then
        thrusterForce = game.car_cphys.gas * 10000 * helpers.mapRange(math.abs(driftAngle), math.rad(30), math.rad(90), 0, 1, true)
        ac.addForce(vec3(0.0, 0.77, -2), true, vec3(0, 0, thrusterForce), true)
    end

    ac.debug("steerctrl.slipAngleFrontCommanded", slipAngleFrontCommanded)
    ac.debug("steerctrl.slipAngleRearCommanded", slipAngleRearCommanded)
    ac.debug("steerctrl.steerFrontLeft", steerFrontLeft)
    ac.debug("steerctrl.steerFrontRight", steerFrontRight)
    ac.debug("steerctrl.steerRearLeft", steerRearLeft)
    ac.debug("steerctrl.steerRearRight", steerRearRight)
    ac.debug("steerctrl.localVelocity.x", game.car_cphys.localVelocity.x)
    ac.debug("steerctrl.localVelocity.y", game.car_cphys.localVelocity.y)
    ac.debug("steerctrl.localVelocity.z", game.car_cphys.localVelocity.z)
    ac.debug("steerctrl.steer", car.steer)
    ac.debug("steerctrl.driftAngle", driftAngle)
    ac.debug("steerctrl.state.control.countersteer", state.control.countersteer)
    ac.debug("steerctrl.thrusterForce", thrusterForce)
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
end

return WheelSteerCtrlr
