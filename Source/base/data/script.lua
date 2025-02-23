-- T-180 CSP Physics Script - Main Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local config = require('car_config')
local state = require('script_state')
local controls = require('script_controls')
local helpers = require('script_helpers')
local WheelSteerController = require('script_wheelsteerctrlr')
local JumpJack = require('script_jumpjack')
local Turbothruster = require('script_turbothruster')
local CustomDrivetrain = require('script_customDrivetrain')


local lastDebugTime = os.clock()
local function showDebugValues(dt)
    if os.clock() - lastDebugTime > config.misc.debugFrequency then
        lastDebugTime = os.clock()
    end
end


local jumpJackSystem = JumpJack({
    jacks = {
        frontLeft = {
            length = 1.2,
            baseForce = 60000,
            position = vec3(-0.545, 0.18, 0.77)
        },
        frontRight = {
            length = 1.2,
            baseForce = 60000,
            position = vec3(0.545, 0.18, 0.77)
        },
        rearLeft = {
            length = 1.2,
            baseForce = 60000,
            position = vec3(-0.45, 0.18, -0.77)
        },
        rearRight = {
            length = 1.2,
            baseForce = 60000,
            position = vec3(0.45, 0.18, -0.77)
        }
    }
})


local function brakeAutoHold()
    if game.car_cphys.speedKmh < config.misc.brakeAutoHold.speed and not (game.car_cphys.gas > 0.05) then
        ac.overrideBrakesTorque(2, config.misc.brakeAutoHold.torque, config.misc.brakeAutoHold.torque)
        ac.overrideBrakesTorque(3, config.misc.brakeAutoHold.torque, config.misc.brakeAutoHold.torque)
        ac.debug("brakeAutoHold", "brakes engaged")
    else
        ac.overrideBrakesTorque(2, math.nan, math.nan)
        ac.overrideBrakesTorque(3, math.nan, math.nan)
        ac.debug("brakeAutoHold", "brakes disengaged")
    end
end


local wheelSteerCtrlr = WheelSteerController()
local turbothruster = Turbothruster()

local frontTurbine = nil
local rearTurbine = nil
local frontDrivetrain = nil
local rearDrivetrain = nil

if config.torqueTurbine.present then
    local TorqueTurbine = require('script_torqueTurbine')
    frontTurbine = TorqueTurbine('front')
    rearTurbine = TorqueTurbine('rear')
    frontDrivetrain = CustomDrivetrain({
        finalDriveRatio = config.torqueTurbine.front.finalDriveRatio,
        drivenWheels = {ac.Wheel.FrontLeft, ac.Wheel.FrontRight},
        id = "front"
    })
    rearDrivetrain = CustomDrivetrain({
        finalDriveRatio = config.torqueTurbine.rear.finalDriveRatio,
        drivenWheels = {ac.Wheel.RearLeft, ac.Wheel.RearRight},
        id = "rear"
    })
end


---@diagnostic disable-next-line: duplicate-set-field
function script.reset()
    wheelSteerCtrlr:reset()
    jumpJackSystem:reset()
    if config.turbothruster.present then
        turbothruster:reset()
    end
    if config.torqueTurbine.present then
        frontTurbine:reset()
        rearTurbine:reset()
    end
end
script.reset()
ac.onCarJumped(0, script.reset)


-- Run by game every physics tick (~333 Hz)
---@diagnostic disable-next-line: duplicate-set-field
function script.update(dt)
    ac.awakeCarPhysics()

    brakeAutoHold()

    controls.update()

    --sharedData.update()

    wheelSteerCtrlr:update(dt)

    if config.turbothruster.present then
        turbothruster:update(dt)
        game.car_cphys.controllerInputs[8] = helpers.mapRange(state.turbine.throttle, config.turbothruster.minThrottle, 1, 0, 1, true)
        game.car_cphys.controllerInputs[9] = helpers.mapRange(state.turbine.thrust, 1000, 8000, 0, 1, true)
        game.car_cphys.controllerInputs[10] = state.turbine.rpm
        game.car_cphys.controllerInputs[11] = state.turbine.fuelPumpEnabled and 1 or 0
        game.car_cphys.controllerInputs[12] = state.turbine.throttleAfterburner    
    end

    if config.torqueTurbine.present then
        if config.torqueTurbine.type == "dual" then
            -- Update front turbine
            frontTurbine:update(dt)
            game.car_cphys.controllerInputs[13] = helpers.mapRange(state.turbine.front.throttle, config.turbothruster.minThrottle, 1, 0, 1, true)
            game.car_cphys.controllerInputs[14] = frontTurbine.fuelSystem.actualFlow / frontTurbine.fadec.maxFuelFlow
            game.car_cphys.controllerInputs[15] = state.turbine.front.rpm / 2.5
            
            -- Update rear turbine
            rearTurbine:update(dt)
            game.car_cphys.controllerInputs[8] = helpers.mapRange(state.turbine.rear.throttle, config.turbothruster.minThrottle, 1, 0, 1, true)
            game.car_cphys.controllerInputs[9] = rearTurbine.fuelSystem.actualFlow / rearTurbine.fadec.maxFuelFlow
            game.car_cphys.controllerInputs[10] = state.turbine.rear.rpm / 2.5

            -- Common updates
            ac.overrideTurboBoost(0, 0, 0)
            ac.overrideEngineTorque(0)
            ac.overrideCarState('limiter', 38000 / 4)
            ac.setEngineRPM(0)
            ac.switchToNeutralGear()

            local clutchFadeout = helpers.mapRange(game.car_cphys.speedKmh, 0, 300, 1, 0, true) ^ 0.01

            -- Update drivetrains
            state.turbine.front.throttle = math.clamp(game.car_cphys.gas - (ac.isControllerGearDownPressed() and 0.75 or 0), 0, 1)
            state.turbine.rear.throttle = math.clamp(game.car_cphys.gas - (ac.isControllerGearUpPressed() and 0.75 or 0), 0, 1)
            local frontFeedback = frontDrivetrain:update(state.turbine.front.rpm, state.turbine.front.torque, math.clamp(game.car_cphys.gas - game.car_cphys.brake, 0, 1), dt)
            local rearFeedback = rearDrivetrain:update(state.turbine.rear.rpm, state.turbine.rear.torque, math.clamp(game.car_cphys.gas - game.car_cphys.brake, 0, 1), dt)
            state.turbine.front.feedbackTorque = frontFeedback
            state.turbine.rear.feedbackTorque = rearFeedback
        else
            -- Original single turbine code
            frontTurbine:update(dt)
            game.car_cphys.controllerInputs[8] = helpers.mapRange(state.turbine.throttle, config.turbothruster.minThrottle, 1, 0, 1, true)
            game.car_cphys.controllerInputs[9] = helpers.mapRange(state.turbine.torque, 0, 2000, 0, 1, true)
            game.car_cphys.controllerInputs[10] = state.turbine.rpm / 2.5
            game.car_cphys.controllerInputs[11] = state.turbine.fuelPumpEnabled and 1 or 0
            game.car_cphys.controllerInputs[12] = state.turbine.throttleAfterburner
            ac.overrideTurboBoost(0, 0, 0)
            ac.overrideEngineTorque(0)
            ac.overrideCarState('limiter', 38000 / 4)
            ac.setEngineRPM(state.turbine.rpm * 0)
            state.turbine.throttle = game.car_cphys.gas
            local drivetrainFeedback = rearDrivetrain:update(state.turbine.rpm, state.turbine.torque, game.car_cphys.clutch, dt)
            state.turbine.feedbackTorque = drivetrainFeedback
        end
    end

    if state.control.driftInversion then game.car_cphys.clutch = 0 end

    jumpJackSystem:update({
        frontLeft = state.jumpJackSystem.jackFL.active,
        frontRight = state.jumpJackSystem.jackFR.active,
        rearLeft = state.jumpJackSystem.jackRL.active,
        rearRight = state.jumpJackSystem.jackRR.active
    }, dt)

    state.jumpJackSystem.jackFL.position = jumpJackSystem.jacks.frontLeft.physicsObject.position
    state.jumpJackSystem.jackFR.position = jumpJackSystem.jacks.frontRight.physicsObject.position
    state.jumpJackSystem.jackRL.position = jumpJackSystem.jacks.rearLeft.physicsObject.position
    state.jumpJackSystem.jackRR.position = jumpJackSystem.jacks.rearRight.physicsObject.position

    local ffb = wheelSteerCtrlr:calculateFFB(dt)
    if ffb and ffb == ffb then  -- Check if value exists and is not NaN
        ac.setSteeringFFB(ffb)
    end

    showDebugValues(dt)
end
