-- T-180 CSP Physics Script - Main Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local config = require('script_config')
local state = require('script_state')
local controls = require('script_controls')
local helpers = require('script_helpers')
local WheelSteerController = require('script_wheelsteerctrlr')
local HubMotorController = require('script_hubmotorctrlr')
local JumpJack = require('script_jumpjack')
local Turbothruster = require('script_turbothruster')


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
    if game.car_cphys.speedKmh < config.misc.brakeAutoHold.speed and game.car_cphys.gas == 0 and game.car_cphys.brake == 0 then
        ac.overrideBrakesTorque(2, config.misc.brakeAutoHold.torque, config.misc.brakeAutoHold.torque)
        ac.overrideBrakesTorque(3, config.misc.brakeAutoHold.torque, config.misc.brakeAutoHold.torque)
    else
        ac.overrideBrakesTorque(2, math.nan, math.nan)
        ac.overrideBrakesTorque(3, math.nan, math.nan)
    end
end


local wheelSteerCtrlr = WheelSteerController()
local hubMotorCtrlr = HubMotorController()
local turbothruster = Turbothruster()


function script.reset()
    wheelSteerCtrlr:reset()
    jumpJackSystem:reset()
    turbothruster:reset()
end
script.reset()
ac.onCarJumped(0, script.reset)


-- Run by game every physics tick (~333 Hz)
---@diagnostic disable-next-line: duplicate-set-field
function script.update(dt)
    ac.awakeCarPhysics()
    brakeAutoHold()

    controls.update()

    wheelSteerCtrlr:update(dt)
    turbothruster:update(dt)
    --local wheelCommands = hubMotorCtrlr:update(dt)

    game.car_cphys.controllerInputs[4] = helpers.mapRange(state.turbine.throttle, config.turbine.minThrottle, 1, 0, 1, true)
    game.car_cphys.controllerInputs[5] = helpers.mapRange(state.turbine.thrust, 1000, 8000, 0, 1, true)

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

    ac.setSteeringFFB(wheelSteerCtrlr:calculateFFB(dt))
    showDebugValues(dt)
end
