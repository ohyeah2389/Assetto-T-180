-- T-180 CSP Physics Script - Main Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local config = require('car_config')
local state = require('script_state')
local controls = require('script_controls')
local helpers = require('script_helpers')
local WheelSteerController = nil
if not config.misc.traditionalSteering then
    WheelSteerController = require('script_wheelsteerctrlr')
end
local JumpJack = require('script_jumpjack')
local Turbojet = require('script_turbojet')
local CustomDrivetrain = require('script_customDrivetrain')
local PerfTracker = require('script_perfTracker')


local perfTracker = PerfTracker()


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
            position = vec3(-0.8, 0.18, 0.77)
        },
        frontRight = {
            length = 1.2,
            baseForce = 60000,
            position = vec3(0.8, 0.18, 0.77)
        },
        rearLeft = {
            length = 1.2,
            baseForce = 60000,
            position = vec3(-0.8, 0.18, -0.77)
        },
        rearRight = {
            length = 1.2,
            baseForce = 60000,
            position = vec3(0.8, 0.18, -0.77)
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


local wheelSteerCtrlr = WheelSteerController and WheelSteerController() or nil


local turbojet = nil
local turbojetLeft = nil
local turbojetRight = nil
if config.turbojet.present then
    if config.turbojet.type == "single" then
        turbojet = Turbojet({ id = 'single' })
    elseif config.turbojet.type == "dual" then
        turbojetLeft = Turbojet({
            id = 'left',
            thrustApplicationPoint = config.turbojet.leftEngineThrustApplicationPoint
        })
        turbojetRight = Turbojet({
            id = 'right',
            thrustApplicationPoint = config.turbojet.rightEngineThrustApplicationPoint
        })
    end
end


local frontTurbine = nil
local rearTurbine = nil
local frontDrivetrain = nil
local rearDrivetrain = nil


if config.turboshaft.present then
    local Turboshaft = require('script_turboshaft')
    frontTurbine = Turboshaft('front')
    rearTurbine = Turboshaft('rear')
    frontDrivetrain = CustomDrivetrain({
        drivenWheels = {ac.Wheel.FrontLeft, ac.Wheel.FrontRight},
        id = "front",
        clutchEngageRate = 3,
        finalDriveRatio = 4
    })
    rearDrivetrain = CustomDrivetrain({
        drivenWheels = {ac.Wheel.RearLeft, ac.Wheel.RearRight},
        id = "rear",
        clutchEngageRate = 2,
        finalDriveRatio = 3
    })
end


---@diagnostic disable-next-line: duplicate-set-field
function script.reset()
    if wheelSteerCtrlr then wheelSteerCtrlr:reset() end
    jumpJackSystem:reset()
    perfTracker:reset()
    if config.turbojet.present then
        if config.turbojet.type == "single" then
            turbojet:reset()
            state.turbine.fuelLevel = config.turbojet.fuelTankCapacity
        elseif config.turbojet.type == "dual" then
            turbojetLeft:reset()
            turbojetRight:reset()
            state.turbine.fuelLevel = config.turbojet.fuelTankCapacity
        end
    end
    if config.turboshaft.present then
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

    if wheelSteerCtrlr then wheelSteerCtrlr:update(dt) end

    if config.turbojet.present then
        if config.turbojet.type == "single" then
            turbojet:update(dt)
            game.car_cphys.controllerInputs[8] = helpers.mapRange(state.turbine.throttle, config.turbojet.minThrottle, 1, 0, 1, true)
            game.car_cphys.controllerInputs[9] = helpers.mapRange(state.turbine.thrust, 1000, 8000, 0, 1, true)
            game.car_cphys.controllerInputs[10] = state.turbine.rpm
            game.car_cphys.controllerInputs[11] = state.turbine.fuelPumpEnabled and 1 or 0
            game.car_cphys.controllerInputs[12] = state.turbine.throttleAfterburner
        elseif config.turbojet.type == "dual" then
            state.turbine.left.throttle = math.clamp(game.car_cphys.gas + helpers.mapRange(game.car_cphys.steer, 0, 0.4, 0, 0.5, true) - helpers.mapRange(game.car_cphys.steer, -0.4, 0, 0.5, 0, true), config.turbojet.minThrottle, 1)
            state.turbine.right.throttle = math.clamp(game.car_cphys.gas + helpers.mapRange(game.car_cphys.steer, -0.4, 0, 0.5, 0, true) - helpers.mapRange(game.car_cphys.steer, 0, 0.4, 0, 0.5, true), config.turbojet.minThrottle, 1)
            state.turbine.left.throttleAfterburner = helpers.mapRange(game.car_cphys.gas, 0.9, 1, 0, 1, true)
            state.turbine.right.throttleAfterburner = helpers.mapRange(game.car_cphys.gas, 0.9, 1, 0, 1, true)
            turbojetLeft:update(dt)
            turbojetRight:update(dt)
            game.car_cphys.controllerInputs[8] = helpers.mapRange(state.turbine.left.throttle, config.turbojet.minThrottle, 1, 0, 1, true)
            game.car_cphys.controllerInputs[9] = helpers.mapRange(state.turbine.left.thrust, 1000, 8000, 0, 1, true)
            game.car_cphys.controllerInputs[10] = state.turbine.left.rpm
            game.car_cphys.controllerInputs[11] = state.turbine.left.fuelPumpEnabled and 1 or 0
            game.car_cphys.controllerInputs[12] = state.turbine.left.throttleAfterburner
            game.car_cphys.controllerInputs[13] = helpers.mapRange(state.turbine.right.throttle, config.turbojet.minThrottle, 1, 0, 1, true)
            game.car_cphys.controllerInputs[14] = helpers.mapRange(state.turbine.right.thrust, 1000, 8000, 0, 1, true)
            game.car_cphys.controllerInputs[15] = state.turbine.right.rpm
            game.car_cphys.controllerInputs[16] = state.turbine.right.fuelPumpEnabled and 1 or 0
            game.car_cphys.controllerInputs[17] = state.turbine.right.throttleAfterburner
            ac.overrideTurboBoost(0, 0, 0)
            ac.overrideEngineTorque(0)
            ac.overrideCarState('limiter', 38000 / 4)
            ac.setEngineRPM(0)
            game.car_cphys.requestedGearIndex = 1
        end
    end

    if config.turboshaft.present then
        if config.turboshaft.type == "dual" then
            -- Clear previous warnings/cautions
            state.warnings = {}
            state.cautions = {}
            state.turbine.front.warnings = {}
            state.turbine.front.cautions = {}
            state.turbine.rear.warnings = {}
            state.turbine.rear.cautions = {}

            -- Update front turbine
            game.car_cphys.controllerInputs[13] = helpers.mapRange(state.turbine.front.throttle, config.turbojet.minThrottle, 1, 0, 1, true)
            game.car_cphys.controllerInputs[14] = frontTurbine.fuelSystem.actualFuelFlow / frontTurbine.fadec.maxFuelFlow
            game.car_cphys.controllerInputs[15] = ((frontTurbine.gasTurbine.angularSpeed * 60 / (2 * math.pi)) or 0) * (10000 / 45000)
            game.car_cphys.controllerInputs[16] = frontTurbine.afterburner.throttleAfterburner
            game.car_cphys.controllerInputs[18] = frontTurbine:update(dt)
            -- Copy warnings/cautions from turbine to state
            for _, warning in ipairs(frontTurbine.state.warnings) do
                table.insert(state.turbine.front.warnings, warning)
                table.insert(state.warnings, "FRONT: " .. warning)
            end
            for _, caution in ipairs(frontTurbine.state.cautions) do
                table.insert(state.turbine.front.cautions, caution)
                table.insert(state.cautions, "FRONT: " .. caution)
            end

            -- Update rear turbine
            game.car_cphys.controllerInputs[8] = helpers.mapRange(state.turbine.rear.throttle, config.turbojet.minThrottle, 1, 0, 1, true)
            game.car_cphys.controllerInputs[9] = rearTurbine.fuelSystem.actualFuelFlow / rearTurbine.fadec.maxFuelFlow
            game.car_cphys.controllerInputs[10] = ((rearTurbine.gasTurbine.angularSpeed * 60 / (2 * math.pi)) or 0) * (10000 / 45000)
            game.car_cphys.controllerInputs[11] = rearTurbine.afterburner.throttleAfterburner
            game.car_cphys.controllerInputs[19] = rearTurbine:update(dt)
            -- Copy warnings/cautions from turbine to state
            for _, warning in ipairs(rearTurbine.state.warnings) do
                table.insert(state.turbine.rear.warnings, warning)
                table.insert(state.warnings, "REAR: " .. warning)
            end
            for _, caution in ipairs(rearTurbine.state.cautions) do
                table.insert(state.turbine.rear.cautions, caution)
                table.insert(state.cautions, "REAR: " .. caution)
            end

            -- Display warnings and cautions
            if #state.warnings > 0 then
                ac.setMessage("MASTER WARNING", table.concat(state.warnings, ", "))
            elseif #state.cautions > 0 then
                ac.setMessage("MASTER CAUTION", table.concat(state.cautions, ", "))
            end

            -- Common updates
            ac.overrideTurboBoost(0, 0, 0)
            ac.overrideEngineTorque(0)
            ac.overrideCarState('limiter', 38000 / 4)
            ac.setEngineRPM(0)
            game.car_cphys.requestedGearIndex = 1

            -- Update drivetrains
            local slipFront = (game.car_cphys.wheels[ac.Wheel.FrontLeft].ndSlip + game.car_cphys.wheels[ac.Wheel.FrontRight].ndSlip) / 2
            local slipRear = (game.car_cphys.wheels[ac.Wheel.RearLeft].ndSlip + game.car_cphys.wheels[ac.Wheel.RearRight].ndSlip) / 2

            local overLimitFront = math.max(0, slipFront - 1) * 0.02
            local overLimitRear = math.max(0, slipRear - 1) * 0.02

            ac.debug("slipFront", slipFront)
            ac.debug("slipRear", slipRear)
            ac.debug("overLimitFront", overLimitFront)
            ac.debug("overLimitRear", overLimitRear)


            state.turbine.front.throttle = math.clamp(game.car_cphys.gas + (ac.isControllerGearUpPressed() and 0.75 or 0) - overLimitFront, 0, 1)
            state.turbine.rear.throttle = math.clamp(game.car_cphys.gas + (ac.isControllerGearDownPressed() and 0.75 or 0) - overLimitRear, 0, 1)
            local frontFeedback = frontDrivetrain:update(state.turbine.front.outputRPM, state.turbine.front.outputTorque, math.clamp(state.turbine.front.throttle - game.car_cphys.brake, 0, 1), dt)
            local rearFeedback = rearDrivetrain:update(state.turbine.rear.outputRPM, state.turbine.rear.outputTorque, math.clamp(state.turbine.rear.throttle - game.car_cphys.brake, 0, 1), dt)
            state.turbine.front.feedbackTorque = frontFeedback
            state.turbine.rear.feedbackTorque = rearFeedback
        else
            frontTurbine:update(dt)
            game.car_cphys.controllerInputs[8] = helpers.mapRange(state.turbine.throttle, config.turbojet.minThrottle, 1, 0, 1, true)
            game.car_cphys.controllerInputs[9] = helpers.mapRange(state.turbine.outputTorque, 0, 2000, 0, 1, true)
            game.car_cphys.controllerInputs[10] = state.turbine.outputRPM / 2.5
            game.car_cphys.controllerInputs[11] = frontTurbine.afterburner.throttleAfterburner
            game.car_cphys.controllerInputs[12] = state.turbine.throttleAfterburner
            ac.overrideTurboBoost(0, 0, 0)
            ac.overrideEngineTorque(0)
            ac.overrideCarState('limiter', 38000 / 4)
            ac.setEngineRPM(state.turbine.outputRPM * 0.4)
            state.turbine.throttle = game.car_cphys.gas
            local drivetrainFeedback = rearDrivetrain:update(state.turbine.outputRPM, state.turbine.outputTorque, game.car_cphys.clutch, dt)
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

    if wheelSteerCtrlr then
        local ffb = wheelSteerCtrlr:calculateFFB(dt)
        if ffb and ffb == ffb then  -- Check if value exists and is not NaN
            ac.setSteeringFFB(ffb)
        end
    end

    if ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_9") then
        local rearSteerLinkageRatio = ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_9").value or 0
        game.car_cphys.controllerInputs[20] = rearSteerLinkageRatio
    end

    perfTracker:update(dt)

    local rideHeightSensor = physics.raycastTrack(car.position + (car.up * 0.4) + (car.look * 1.0), -car.up, 1.0)
    local suctionMult = math.clamp(math.remap(rideHeightSensor, 0.5, 0.9, 1, 0), 0, 1) * (rideHeightSensor == -1 and 0 or 1)
    local aeroForce = -325 * (math.abs(car.localVelocity.x) + math.abs(car.localVelocity.z)) * suctionMult

    ac.addForce(vec3(0, 0, 0), true, vec3(0, aeroForce, 0), true)

    ac.debug("aeroForce", aeroForce)
    ac.debug("suctionMult", suctionMult)
    ac.debug("rideHeightSensor", rideHeightSensor)

    showDebugValues(dt)
end
