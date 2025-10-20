-- T-180 CSP Physics Script - Main Module
-- Authored by ohyeah2389

---@diagnostic disable: undefined-field

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


local TurbojetEngine = require('script_turbojet')
local turbojetCenter = nil
local turbojetLeft = nil
local turbojetRight = nil

if config.turbojet.present then
    if config.turbojet.type == "single" then
        turbojetCenter = TurbojetEngine({ id = 'single' })
    elseif config.turbojet.type == "dual" then
        turbojetLeft = TurbojetEngine({
            id = 'left',
            thrustApplicationPoint = config.turbojet.leftEngineThrustApplicationPoint
        })
        turbojetRight = TurbojetEngine({
            id = 'right',
            thrustApplicationPoint = config.turbojet.rightEngineThrustApplicationPoint
        })
    end
end


local TurboshaftEngine = require('script_turboshaft')
local turboshaftFront = nil
local turboshaftRear = nil
local drivetrainFront = nil
local drivetrainRear = nil

if config.turboshaft.present then
    turboshaftFront = TurboshaftEngine('front')
    turboshaftRear = TurboshaftEngine('rear')
    drivetrainFront = CustomDrivetrain({
        drivenWheels = { ac.Wheel.FrontLeft, ac.Wheel.FrontRight },
        id = "front",
        clutchEngageRate = 3,
        finalDriveRatio = 4
    })
    drivetrainRear = CustomDrivetrain({
        drivenWheels = { ac.Wheel.RearLeft, ac.Wheel.RearRight },
        id = "rear",
        clutchEngageRate = 2,
        finalDriveRatio = 3
    })
end

-- Initialize perfTracker with turbine references
local turbineInstances = {}
if config.turbojet.present then
    if config.turbojet.type == "single" then
        turbineInstances.center = turbojetCenter
    elseif config.turbojet.type == "dual" then
        turbineInstances.left = turbojetLeft
        turbineInstances.right = turbojetRight
    end
elseif config.turboshaft.present then
    turbineInstances.front = turboshaftFront
    turbineInstances.rear = turboshaftRear
end
local perfTracker = PerfTracker(turbineInstances)


---@diagnostic disable-next-line: duplicate-set-field
function script.reset()
    if wheelSteerCtrlr then wheelSteerCtrlr:reset() end
    jumpJackSystem:reset()
    if perfTracker then perfTracker:reset() end
    if config.turbojet.present then
        if config.turbojet.type == "single" then
            turbojetCenter:reset()
        elseif config.turbojet.type == "dual" then
            turbojetLeft:reset()
            turbojetRight:reset()
        end
    end
    if config.turboshaft.present then
        turboshaftFront:reset()
        if turboshaftRear then turboshaftRear:reset() end
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
        if config.turbojet.type == "single" and turbojetCenter then
            -- Determine throttle
            local driftAngle = math.atan(game.car_cphys.localVelocity.x / math.abs(game.car_cphys.localVelocity.z))
            local baseThrottle = helpers.mapRange(game.car_cphys.gas * helpers.mapRange(math.abs(driftAngle), math.rad(config.turbojet.helperStartAngle), math.rad(config.turbojet.helperEndAngle), 0, 1, true), 0, 1, config.turbojet.minThrottle, 1, true)
            local clutchFactor = ((1 - game.car_cphys.clutch) * (car.isInPit and 0 or 1)) ^ 0.1
            baseThrottle = math.max(baseThrottle, clutchFactor) * (turbojetCenter.fuelPumpEnabled and 1 or 0)

            -- Set throttles
            if controls.turbine.throttle:down() and turbojetCenter.fuelPumpEnabled then
                turbojetCenter.targetThrottle = 1
                if turbojetCenter.throttle > 0.9 then
                    turbojetCenter.targetThrottleAfterburner = 1
                else
                    turbojetCenter.targetThrottleAfterburner = 0
                end
            else
                turbojetCenter.targetThrottleAfterburner = (clutchFactor > 0.9 and 1 or 0) * (turbojetCenter.fuelPumpEnabled and 1 or 0)
                turbojetCenter.targetThrottle = baseThrottle
            end

            -- Update turbine
            turbojetCenter:update(dt)

            -- Set controller channels
            game.car_cphys.controllerInputs[8] = helpers.mapRange(turbojetCenter.throttle, config.turbojet.minThrottle, 1, 0, 1, true)
            game.car_cphys.controllerInputs[9] = helpers.mapRange(turbojetCenter.thrust, 1000, 8000, 0, 1, true)
            game.car_cphys.controllerInputs[10] = turbojetCenter.shaft.angularSpeed * 60 / (2 * math.pi)
            game.car_cphys.controllerInputs[11] = turbojetCenter.fuelPumpEnabled and 1 or 0
            game.car_cphys.controllerInputs[12] = helpers.mapRange(turbojetCenter.thrustAfterburner, 0, 2000, 0, 1, true)
        elseif config.turbojet.type == "dual" and turbojetLeft and turbojetRight then
            -- Set throttles
            turbojetLeft.targetThrottle = math.clamp(game.car_cphys.gas + helpers.mapRange(game.car_cphys.steer, 0, 0.4, 0, 0.5, true) - helpers.mapRange(game.car_cphys.steer, -0.4, 0, 0.5, 0, true), config.turbojet.minThrottle, 1)
            turbojetRight.targetThrottle = math.clamp(game.car_cphys.gas + helpers.mapRange(game.car_cphys.steer, -0.4, 0, 0.5, 0, true) - helpers.mapRange(game.car_cphys.steer, 0, 0.4, 0, 0.5, true), config.turbojet.minThrottle, 1)

            -- Update turbines
            turbojetLeft:update(dt)
            turbojetRight:update(dt)

            -- Set controller channels
            game.car_cphys.controllerInputs[8] = helpers.mapRange(turbojetLeft.throttle, config.turbojet.minThrottle, 1, 0, 1, true)
            game.car_cphys.controllerInputs[9] = helpers.mapRange(turbojetLeft.thrust, 1000, 8000, 0, 1, true)
            game.car_cphys.controllerInputs[10] = turbojetLeft.shaft.angularSpeed * 60 / (2 * math.pi)
            game.car_cphys.controllerInputs[11] = turbojetLeft.fuelPumpEnabled and 1 or 0
            game.car_cphys.controllerInputs[12] = helpers.mapRange(turbojetLeft.thrustAfterburner, 0, 2000, 0, 1, true)
            game.car_cphys.controllerInputs[13] = helpers.mapRange(turbojetRight.throttle, config.turbojet.minThrottle, 1, 0, 1, true)
            game.car_cphys.controllerInputs[14] = helpers.mapRange(turbojetRight.thrust, 1000, 8000, 0, 1, true)
            game.car_cphys.controllerInputs[15] = turbojetRight.shaft.angularSpeed * 60 / (2 * math.pi)
            game.car_cphys.controllerInputs[16] = turbojetRight.fuelPumpEnabled and 1 or 0
            game.car_cphys.controllerInputs[17] = helpers.mapRange(turbojetRight.thrustAfterburner, 0, 2000, 0, 1, true)

            -- Common updates
            ac.overrideTurboBoost(0, 0, 0)
            ac.overrideEngineTorque(0)
            ac.overrideCarState('limiter', 38000 / 4)
            ac.setEngineRPM(0)
            game.car_cphys.requestedGearIndex = 1
        end
    end

    if config.turboshaft.present then
        if config.turboshaft.type == "dual" and turboshaftFront and turboshaftRear then
            -- Update drivetrains first to calculate slip
            local slipFront = (game.car_cphys.wheels[ac.Wheel.FrontLeft].ndSlip + game.car_cphys.wheels[ac.Wheel.FrontRight].ndSlip) / 2
            local slipRear = (game.car_cphys.wheels[ac.Wheel.RearLeft].ndSlip + game.car_cphys.wheels[ac.Wheel.RearRight].ndSlip) / 2

            local overLimitFront = math.max(0, slipFront - 1) * 0.02
            local overLimitRear = math.max(0, slipRear - 1) * 0.02

            ac.debug("slipFront", slipFront)
            ac.debug("slipRear", slipRear)
            ac.debug("overLimitFront", overLimitFront)
            ac.debug("overLimitRear", overLimitRear)

            -- Set turbine throttles
            turboshaftFront.throttle = math.clamp(game.car_cphys.gas + (ac.isControllerGearUpPressed() and 0.75 or 0) - overLimitFront, 0, 1)
            turboshaftRear.throttle = math.clamp(game.car_cphys.gas + (ac.isControllerGearDownPressed() and 0.75 or 0) - overLimitRear, 0, 1)

            -- Update controller channels
            game.car_cphys.controllerInputs[13] = helpers.mapRange(turboshaftFront.throttle, config.turbojet.minThrottle, 1, 0, 1, true)
            game.car_cphys.controllerInputs[14] = turboshaftFront.fuelSystem.actualFuelFlow / turboshaftFront.fadec.maxFuelFlow
            game.car_cphys.controllerInputs[15] = ((turboshaftFront.gasTurbine.angularSpeed * 60 / (2 * math.pi)) or 0) * (10000 / 45000)
            game.car_cphys.controllerInputs[16] = turboshaftFront.afterburner.throttleAfterburner
            game.car_cphys.controllerInputs[18] = turboshaftFront:update(dt)

            game.car_cphys.controllerInputs[8] = helpers.mapRange(turboshaftRear.throttle, config.turbojet.minThrottle, 1, 0, 1, true)
            game.car_cphys.controllerInputs[9] = turboshaftRear.fuelSystem.actualFuelFlow / turboshaftRear.fadec.maxFuelFlow
            game.car_cphys.controllerInputs[10] = ((turboshaftRear.gasTurbine.angularSpeed * 60 / (2 * math.pi)) or 0) * (10000 / 45000)
            game.car_cphys.controllerInputs[11] = turboshaftRear.afterburner.throttleAfterburner
            game.car_cphys.controllerInputs[19] = turboshaftRear:update(dt)

            -- Collect warnings and cautions
            local allWarnings = {}
            local allCautions = {}
            for _, warning in ipairs(turboshaftFront.warnings) do
                table.insert(allWarnings, "FRONT: " .. warning)
            end
            for _, caution in ipairs(turboshaftFront.cautions) do
                table.insert(allCautions, "FRONT: " .. caution)
            end
            for _, warning in ipairs(turboshaftRear.warnings) do
                table.insert(allWarnings, "REAR: " .. warning)
            end
            for _, caution in ipairs(turboshaftRear.cautions) do
                table.insert(allCautions, "REAR: " .. caution)
            end

            -- Display warnings and cautions
            if #allWarnings > 0 then
                ac.setMessage("MASTER WARNING", table.concat(allWarnings, ", "))
            elseif #allCautions > 0 then
                ac.setMessage("MASTER CAUTION", table.concat(allCautions, ", "))
            end

            -- Common updates
            ac.overrideTurboBoost(0, 0, 0)
            ac.overrideEngineTorque(0)
            ac.overrideCarState('limiter', 38000 / 4)
            ac.setEngineRPM(0)
            game.car_cphys.requestedGearIndex = 1

            -- Update drivetrains with turbine output
            local frontFeedback = drivetrainFront:update(turboshaftFront.outputRPM, turboshaftFront.outputTorque, math.clamp(turboshaftFront.throttle - game.car_cphys.brake, 0, 1), dt)
            local rearFeedback = drivetrainRear:update(turboshaftRear.outputRPM, turboshaftRear.outputTorque, math.clamp(turboshaftRear.throttle - game.car_cphys.brake, 0, 1), dt)
            turboshaftFront.feedbackTorque = frontFeedback
            turboshaftRear.feedbackTorque = rearFeedback
        elseif turboshaftFront then
            turboshaftFront.throttle = game.car_cphys.gas
            turboshaftFront:update(dt)

            -- Update controller channels
            game.car_cphys.controllerInputs[8] = helpers.mapRange(turboshaftFront.throttle, config.turbojet.minThrottle, 1, 0, 1, true)
            game.car_cphys.controllerInputs[9] = helpers.mapRange(turboshaftFront.outputTorque, 0, 2000, 0, 1, true)
            game.car_cphys.controllerInputs[10] = turboshaftFront.outputRPM / 2.5
            game.car_cphys.controllerInputs[11] = turboshaftFront.afterburner.throttleAfterburner
            game.car_cphys.controllerInputs[12] = turboshaftFront.throttleAfterburner

            -- Common updates
            ac.overrideTurboBoost(0, 0, 0)
            ac.overrideEngineTorque(0)
            ac.overrideCarState('limiter', 38000 / 4)
            ac.setEngineRPM(turboshaftFront.outputRPM * 0.4)

            -- Update drivetrains with turbine output
            local drivetrainFeedback = drivetrainRear:update(turboshaftFront.outputRPM, turboshaftFront.outputTorque, game.car_cphys.clutch, dt)
            turboshaftFront.feedbackTorque = drivetrainFeedback
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
        if ffb and ffb == ffb then -- Check if value exists and is not NaN
            ac.setSteeringFFB(ffb)
        end
    end

    if ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_9") then
        local rearSteerLinkageRatio = ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_9").value or 0
        game.car_cphys.controllerInputs[20] = rearSteerLinkageRatio
    end

    if perfTracker then perfTracker:update(dt) end

    local rideHeightSensor = physics.raycastTrack(car.position + (car.up * 0.4) + (car.look * 1.0), -car.up, 1.0)
    local suctionMult = math.clamp(math.remap(rideHeightSensor, 0.5, 0.9, 1, 0), 0, 1) * (rideHeightSensor == -1 and 0 or 1)
    local aeroForceBase = ((car.name == "ohyeah2389_proto_mach4") or (car.name == "ma_proto_uniron")) and -160 or -200
    local aeroForce = aeroForceBase * (math.abs(car.localVelocity.x) + math.abs(car.localVelocity.z)) * suctionMult

    ac.addForce(vec3(0, 0, 0), true, vec3(0, aeroForce, 0), true)

    ac.debug("aeroForce", aeroForce)
    ac.debug("suctionMult", suctionMult)
    ac.debug("rideHeightSensor", rideHeightSensor)

    showDebugValues(dt)
end
