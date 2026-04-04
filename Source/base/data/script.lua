-- T-180 CSP Physics Script - Main Module
-- Authored by ohyeah2389

DEBUG = ac.getCarName(0) == "T-180 Chassis DEV"
DEBUG_PERFTRACKER = false

---@diagnostic disable: undefined-field

local game = require('script_acConnection')
local config = require('car_config')
local state = require('script_state')
local controls = require('script_controls')
local helpers = require('script_helpers')
local JumpJacks = require('script_jumpjack')
local CustomDrivetrain = require('script_customDrivetrain')
local PerfTracker = require('script_perfTracker')
local Opponent = require('script_opponent')

local WheelSteerController = nil
local ActiveSuspension = nil

if not config.misc.traditionalSteering then
    WheelSteerController = require('script_wheelsteerctrlr')
    ActiveSuspension = require('script_activesusp')
end

local aiDriver = Opponent({})

local linkageRatioSetup = ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_9")
local steeringRangeSetup = ac.getScriptSetupValue("CUSTOM_SCRIPT_ITEM_20")

-- Configure jump jacks
local jumpJackSystem = JumpJacks({
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
    else
        ac.overrideBrakesTorque(2, math.nan, math.nan)
        ac.overrideBrakesTorque(3, math.nan, math.nan)
    end
end


local wheelSteerCtrlr = WheelSteerController and WheelSteerController() or nil
local activeSusp = ActiveSuspension and ActiveSuspension() or nil

-- Load and init turbojet engine(s)
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

-- Load and init turboshaft engine(s)
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


-- Initialize perfTracker, passing turbine references
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

local perfTracker = DEBUG_PERFTRACKER and PerfTracker(turbineInstances)

-- Run every time the car resets (reset to pits, teleport, etc.)
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
    if activeSusp then
        activeSusp:reset()
    end
end

-- Run a manual reset on script start before registering the loop to clear out all systems and to check their resets work
script.reset()

-- Run by game every physics tick (333 Hz)
---@diagnostic disable-next-line: duplicate-set-field
function script.update(dt)
    if car.index ~= 0 then -- If car is AI-controlled (not the player car) then...
        aiDriver:update(dt) -- ...run the AI control system
    else -- Car must be the player's, so...
        -- Disable the stock "lock car in place" system, and run brake holding to stop car from rolling around
        ac.awakeCarPhysics()
        brakeAutoHold()

        -- Prime controls table with current inputs
        controls.update()

        -- Run jump jack system
        jumpJackSystem:update({
            frontLeft = state.jumpJackSystem.jackFL.active,
            frontRight = state.jumpJackSystem.jackFR.active,
            rearLeft = state.jumpJackSystem.jackRL.active,
            rearRight = state.jumpJackSystem.jackRR.active
        }, dt)

        -- Run wheel steering controller code and FFB update if we have one
        if wheelSteerCtrlr then
            wheelSteerCtrlr:update(dt)
            local ffb = wheelSteerCtrlr:calculateFFB(dt)
            if ffb and ffb == ffb then -- Check if value exists and is not NaN
                ac.setSteeringFFB(ffb)
            end
        end
    end

    -- Run turbojet system if we have one
    if config.turbojet.present then
        if config.turbojet.type == "single" and turbojetCenter then
            -- Determine throttle
            local driftAngle = math.atan(game.car_cphys.localVelocity.x / math.abs(game.car_cphys.localVelocity.z))
            local baseThrottle = helpers.mapRange(game.car_cphys.gas * helpers.mapRange(math.abs(driftAngle), math.rad(config.turbojet.helperStartAngle), math.rad(config.turbojet.helperEndAngle), 0, 1, true), 0, 1, config.turbojet.minThrottle, 1, true)
            local clutchFactor = ((1 - game.car_cphys.clutch) * ((car.isInPit or game.sim.isInMainMenu) and 0 or 1)) ^ 0.1
            local gasFactor = game.car_cphys.gas * 0.4
            baseThrottle = math.min(math.max(baseThrottle, clutchFactor, gasFactor), 1) * (turbojetCenter.fuelPumpEnabled and 1 or 0)

            -- Set throttles
            if controls.turbine.burner:down() and turbojetCenter.fuelPumpEnabled then
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
            turbojetCenter.fuelPumpEnabled = state.turbine.fuelPumpEnabled
            turbojetCenter:update(dt)

            -- Set controller channels
            game.car_cphys.controllerInputs[8] = helpers.mapRange(turbojetCenter.throttle, config.turbojet.minThrottle, 1, 0, 1, true)                     -- throttle
            game.car_cphys.controllerInputs[9] = helpers.mapRange(turbojetCenter.thrust, 1000, 8000, 0, 1, true)                                           -- thrust
            game.car_cphys.controllerInputs[10] = turbojetCenter.shaft.angularSpeed * 60 / (2 * math.pi)                                                   -- rpm
            game.car_cphys.controllerInputs[11] = turbojetCenter.fuelPumpEnabled and 1 or 0                                                                -- fuel pump enabled
            game.car_cphys.controllerInputs[12] = helpers.mapRange(turbojetCenter.thrustAfterburner, 0, 2000, 0, 1, true)                                  -- burner throttle
            game.car_cphys.controllerInputs[18] = helpers.mapRange(math.max(turbojetCenter.heatFrame, turbojetCenter.heatCore / 2), 700, 1000, 0, 1, true) -- damage

            -- Set heat controller channels
            game.car_cphys.controllerInputs[21] = turbojetCenter.heatCore
            game.car_cphys.controllerInputs[22] = turbojetCenter.heatFrame
        elseif config.turbojet.type == "dual" and turbojetLeft and turbojetRight then
            -- Set throttles
            turbojetLeft.targetThrottle = math.clamp(game.car_cphys.gas + helpers.mapRange(game.car_cphys.steer, 0, 0.4, 0, 0.5, true) - helpers.mapRange(game.car_cphys.steer, -0.4, 0, 0.25, 0, true), config.turbojet.minThrottle, 1)
            turbojetRight.targetThrottle = math.clamp(game.car_cphys.gas + helpers.mapRange(game.car_cphys.steer, -0.4, 0, 0.5, 0, true) - helpers.mapRange(game.car_cphys.steer, 0, 0.4, 0, 0.25, true), config.turbojet.minThrottle, 1)
            turbojetLeft.targetThrottleAfterburner = helpers.mapRange(turbojetLeft.targetThrottle, 0.5, 1.0, 0.0, 1.0, true)
            turbojetRight.targetThrottleAfterburner = helpers.mapRange(turbojetRight.targetThrottle, 0.5, 1.0, 0.0, 1.0, true)

            -- Update turbines
            turbojetLeft.fuelPumpEnabled = state.turbine.fuelPumpEnabled
            turbojetRight.fuelPumpEnabled = state.turbine.fuelPumpEnabled
            turbojetLeft:update(dt)
            turbojetRight:update(dt)

            -- Clear their temperature (for now)
            turbojetLeft.heatFrame = 0
            turbojetLeft.heatCore = 0
            turbojetRight.heatFrame = 0
            turbojetRight.heatCore = 0

            -- Set controller channels
            game.car_cphys.controllerInputs[8] = helpers.mapRange(turbojetLeft.throttle, config.turbojet.minThrottle, 1, 0, 1, true)   -- throttle
            game.car_cphys.controllerInputs[9] = helpers.mapRange(turbojetLeft.thrust, 1000, 8000, 0, 1, true)                         -- thrust
            game.car_cphys.controllerInputs[10] = turbojetLeft.shaft.angularSpeed * 60 / (2 * math.pi)                                 -- rpm
            game.car_cphys.controllerInputs[11] = turbojetLeft.fuelPumpEnabled and 1 or 0                                              -- fuel pump enabled
            game.car_cphys.controllerInputs[12] = helpers.mapRange(turbojetLeft.thrustAfterburner, 0, 2000, 0, 1, true)                -- burner throttle
            game.car_cphys.controllerInputs[13] = helpers.mapRange(turbojetRight.throttle, config.turbojet.minThrottle, 1, 0, 1, true) -- secondary throttle
            game.car_cphys.controllerInputs[14] = helpers.mapRange(turbojetRight.thrust, 1000, 8000, 0, 1, true)                       -- secondary thrust
            game.car_cphys.controllerInputs[15] = turbojetRight.shaft.angularSpeed * 60 / (2 * math.pi)                                -- secondary rpm
            game.car_cphys.controllerInputs[16] = turbojetRight.fuelPumpEnabled and 1 or 0                                             -- secondary fuel pump enabled
            game.car_cphys.controllerInputs[17] = helpers.mapRange(turbojetRight.thrustAfterburner, 0, 2000, 0, 1, true)               -- secondary burner throttle

            -- Set controller channels for damage
            game.car_cphys.controllerInputs[18] = helpers.mapRange(math.max(turbojetLeft.heatFrame, turbojetLeft.heatCore / 2), 700, 1000, 0, 1, true)   -- damage
            game.car_cphys.controllerInputs[19] = helpers.mapRange(math.max(turbojetRight.heatFrame, turbojetRight.heatCore / 2), 700, 1000, 0, 1, true) -- secondary damage

            -- Set heat controller channels
            game.car_cphys.controllerInputs[21] = math.max(turbojetLeft.heatCore, turbojetRight.heatCore)
            game.car_cphys.controllerInputs[22] = math.max(turbojetLeft.heatFrame, turbojetRight.heatFrame)

            -- Common updates
            ac.overrideTurboBoost(0, 0, 0)
            ac.overrideEngineTorque(0)
            ac.overrideCarState('limiter', 38000 / 4)
            ac.setEngineRPM(0)
            game.car_cphys.requestedGearIndex = 1
        end
    end

    -- Run turboshaft system if we have one
    if config.turboshaft.present then
        if config.turboshaft.type == "dual" and turboshaftFront and turboshaftRear then
            -- Update drivetrains first to calculate slip
            local slipFront = (game.car_cphys.wheels[ac.Wheel.FrontLeft].ndSlip + game.car_cphys.wheels[ac.Wheel.FrontRight].ndSlip) / 2
            local slipRear = (game.car_cphys.wheels[ac.Wheel.RearLeft].ndSlip + game.car_cphys.wheels[ac.Wheel.RearRight].ndSlip) / 2

            local overLimitFront = math.max(0, slipFront - 1) * 0.02
            local overLimitRear = math.max(0, slipRear - 1) * 0.02

            if DEBUG then
                ac.debug("slipFront", slipFront)
                ac.debug("slipRear", slipRear)
                ac.debug("overLimitFront", overLimitFront)
                ac.debug("overLimitRear", overLimitRear)
            end

            -- Set turbine throttles
            turboshaftFront.throttle = math.clamp(game.car_cphys.gas + (ac.isControllerGearUpPressed() and 0.75 or 0) - overLimitFront, 0, 1)
            turboshaftRear.throttle = math.clamp(game.car_cphys.gas + (ac.isControllerGearDownPressed() and 0.75 or 0) - overLimitRear, 0, 1)

            -- Update turbines and get damage values
            local frontDamage = turboshaftFront:update(dt)
            local rearDamage = turboshaftRear:update(dt)

            -- Update controller channels for front turbine
            game.car_cphys.controllerInputs[13] = helpers.mapRange(turboshaftFront.throttle, config.turbojet.minThrottle, 1, 0, 1, true)
            game.car_cphys.controllerInputs[14] = turboshaftFront.fuelSystem.actualFuelFlow / turboshaftFront.fadec.maxFuelFlow
            game.car_cphys.controllerInputs[15] = ((turboshaftFront.gasTurbine.angularSpeed * 60 / (2 * math.pi)) or 0) * (10000 / 45000)
            game.car_cphys.controllerInputs[16] = turboshaftFront.fuelSystem.pumpEnabled and 1 or 0
            game.car_cphys.controllerInputs[17] = turboshaftFront.afterburner.throttleAfterburner
            game.car_cphys.controllerInputs[18] = frontDamage

            -- Update controller channels for rear turbine
            game.car_cphys.controllerInputs[8] = helpers.mapRange(turboshaftRear.throttle, config.turbojet.minThrottle, 1, 0, 1, true)
            game.car_cphys.controllerInputs[9] = turboshaftRear.fuelSystem.actualFuelFlow / turboshaftRear.fadec.maxFuelFlow
            game.car_cphys.controllerInputs[10] = ((turboshaftRear.gasTurbine.angularSpeed * 60 / (2 * math.pi)) or 0) * (10000 / 45000)
            game.car_cphys.controllerInputs[11] = turboshaftRear.fuelSystem.pumpEnabled and 1 or 0
            game.car_cphys.controllerInputs[12] = turboshaftRear.afterburner.throttleAfterburner
            game.car_cphys.controllerInputs[19] = rearDamage

            -- Set heat controller channels
            game.car_cphys.controllerInputs[21] = turboshaftRear.sensors.turbineInletTemp
            game.car_cphys.controllerInputs[22] = turboshaftRear.gasTurbine.angularSpeed

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

    -- If we're drifting backwards, don't allow clutch input
    if state.control.driftInversion then game.car_cphys.clutch = 0 end

    -- If the rear-mechanical-steer linkage ratio setup option exists, transmit it over its controller channel
    if linkageRatioSetup then game.car_cphys.controllerInputs[20] = linkageRatioSetup.value end

    -- If we have the active suspension module, run its code
    if activeSusp then activeSusp:update(dt) end

    -- If we have the performance tracker, run its code
    if perfTracker then perfTracker:update(dt) end

    -- Synthetic downforce code:

    -- Find the car's ride height
    local rideHeightSensor = physics.raycastTrack(car.position + (car.up * 0.4) + (car.look * 1.0), -car.up, 2.0)

    -- Determine if the car is close enough to the ground for the downforce to take effect, else fade it out
    local suctionMult = math.clamp(math.remap(rideHeightSensor, 0.5, 2.0, 1, 0), 0, 1) * (rideHeightSensor == -1 and 0 or 1)

    -- If it's a protocar, it gets a different amount of downforce
    local aeroForceBase = ((car.name == "ohyeah2389_proto_mach4") or (car.name == "ma_proto_uniron")) and -160 or -200

    -- Find the speed of the car in its XZ plane
    local velocityMagnitude = math.sqrt(car.localVelocity.x * car.localVelocity.x + car.localVelocity.z * car.localVelocity.z)

    -- Find the direction of the car in its XZ plane
    local forwardAngle = math.atan2(car.localVelocity.x, car.localVelocity.z)

    -- Set how much force remains at 90 degrees (0.0 = full dropoff, 1.0 = no dropoff)
    local directionalDropoff = 0.75

    -- Fade out the downforce with a cosine curve
    local cosineDropoff = math.lerp(directionalDropoff, 1.0, math.abs(math.cos(forwardAngle)))

    -- Final downforce magnitude product
    local aeroForce = aeroForceBase * velocityMagnitude * cosineDropoff * suctionMult

    -- Apply the downforce to the car
    ac.addForce(vec3(0, 0, 0), true, vec3(0, aeroForce, 0), true)

    -- Roll control code:

    -- Calculate control force magnitude from normalized steering angle (same normalization as wheelSteerCtrlr)
    local rollForce = math.clamp(game.car_cphys.steer / (90 * steeringRangeSetup.value / 180), -1, 1) * 100 * (1 - suctionMult)

    -- Apply left side force
    ac.addForce(vec3(-10, 0, 0), true, vec3(0, -rollForce, 0), true)

    -- Apply right side force
    ac.addForce(vec3(10, 0, 0), true, vec3(0, rollForce, 0), true)


    if DEBUG then
        ac.debug("aeroForce", -aeroForce, 0, 20000, 2)
        ac.debug("suctionMult", suctionMult, 0, 1, 2)
        ac.debug("rideHeightSensor", rideHeightSensor, 0, 2, 2)
    end
end
