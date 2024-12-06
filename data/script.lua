-- T-180 CSP Physics Script - Main Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local config = require('script_config')
local state = require('script_state')
local helpers = require('script_helpers')
local WheelSteerController = require('script_wheelsteerctrlr')
local HubMotorController = require('script_hubmotorctrlr')
local JumpJack = require('script_jumpjack')


local lastDebugTime = os.clock()
local function showDebugValues(dt)
    if os.clock() - lastDebugTime > config.misc.debugFrequency then
        lastDebugTime = os.clock()
    end
end


local function brakeAutoHold()
    if game.car_cphys.speedKmh < config.misc.brakeAutoHold.speed and game.car_cphys.gas == 0 then
        ac.overrideBrakesTorque(2, config.misc.brakeAutoHold.torque, config.misc.brakeAutoHold.torque)
        ac.overrideBrakesTorque(3, config.misc.brakeAutoHold.torque, config.misc.brakeAutoHold.torque)
    else
        ac.overrideBrakesTorque(2, math.nan, math.nan)
        ac.overrideBrakesTorque(3, math.nan, math.nan)
    end
end

local wheelSteerCtrlr = WheelSteerController()
local hubMotorCtrlr = HubMotorController()

local afterburnerAmountMaxSeconds = 1000
local afterburnerAmountSeconds = afterburnerAmountMaxSeconds
local afterburnerSpool = 0

local jumpJackLF = JumpJack({
    jackLength = 1.2,
    jackPosition = vec3(-0.2, 0.1, 0.3),
})
local jumpJackRF = JumpJack({
    jackLength = 1.2,
    jackPosition = vec3(0.2, 0.1, 0.3),
})
local jumpJackLR = JumpJack({
    jackLength = 1.2,
    jackPosition = vec3(-0.2, 0.1, -0.3),
})
local jumpJackRR = JumpJack({
    jackLength = 1.2,
    jackPosition = vec3(0.2, 0.1, -0.3),
})


function script.reset()
    wheelSteerCtrlr:reset()
    afterburnerAmountSeconds = afterburnerAmountMaxSeconds
    jumpJackLF:reset()
    jumpJackRF:reset()
    jumpJackLR:reset()
    jumpJackRR:reset()
end
script.reset()
ac.onCarJumped(0, script.reset)


-- Run by game every physics tick (~333 Hz)
---@diagnostic disable-next-line: duplicate-set-field
function script.update(dt)
    ac.awakeCarPhysics()
    brakeAutoHold()

    wheelSteerCtrlr:update(dt)
    --local wheelCommands = hubMotorCtrlr:update(dt)

    if car.extraA and afterburnerAmountSeconds > 0 then
        afterburnerAmountSeconds = math.max(afterburnerAmountSeconds - dt, 0)
        afterburnerSpool = math.min(afterburnerSpool + dt * 0.5, 1)
    else
        afterburnerSpool = math.max(afterburnerSpool - dt * 2, 0)
    end

    ac.debug("afterburnerAmountSeconds", afterburnerAmountSeconds)
    ac.debug("afterburnerSpool", afterburnerSpool)

    game.car_cphys.controllerInputs[4] = math.smootherstep(afterburnerSpool ^ 0.5)

    local newBoost = helpers.mapRange(math.abs(game.car_cphys.rpm), 0, 20000, 0, helpers.mapRange(afterburnerSpool, 0, 1, 1, 2), false)
    ac.overrideTurboBoost(0, newBoost, newBoost)

    jumpJackLF:update(car.extraB, dt)
    jumpJackRF:update(car.extraB, dt)
    jumpJackLR:update(car.extraB, dt)
    jumpJackRR:update(car.extraB, dt)

    ac.debug("jumpJackLF.jackRaycast", jumpJackLF.jackRaycast)
    ac.debug("jumpJackRF.jackRaycast", jumpJackRF.jackRaycast)
    ac.debug("jumpJackLR.jackRaycast", jumpJackLR.jackRaycast)
    ac.debug("jumpJackRR.jackRaycast", jumpJackRR.jackRaycast)
    ac.debug("jumpJackLF.physicsObject.position", jumpJackLF.physicsObject.position)
    ac.debug("jumpJackRF.physicsObject.position", jumpJackRF.physicsObject.position)
    ac.debug("jumpJackLR.physicsObject.position", jumpJackLR.physicsObject.position)
    ac.debug("jumpJackRR.physicsObject.position", jumpJackRR.physicsObject.position)
    ac.debug("jumpJackLF.isTouching", jumpJackLF.isTouching)
    ac.debug("jumpJackRF.isTouching", jumpJackRF.isTouching)
    ac.debug("jumpJackLR.isTouching", jumpJackLR.isTouching)
    ac.debug("jumpJackRR.isTouching", jumpJackRR.isTouching)
    ac.debug("jumpJackLF.penetrationDepth", jumpJackLF.penetrationDepth)
    ac.debug("jumpJackRF.penetrationDepth", jumpJackRF.penetrationDepth)
    ac.debug("jumpJackLR.penetrationDepth", jumpJackLR.penetrationDepth)
    ac.debug("jumpJackRR.penetrationDepth", jumpJackRR.penetrationDepth)
    ac.debug("jumpJackLF.penetrationForce", jumpJackLF.penetrationForce)
    ac.debug("jumpJackRF.penetrationForce", jumpJackRF.penetrationForce)
    ac.debug("jumpJackLR.penetrationForce", jumpJackLR.penetrationForce)
    ac.debug("jumpJackRR.penetrationForce", jumpJackRR.penetrationForce)
    ac.debug("car.position", car.position)

    ac.setSteeringFFB(wheelSteerCtrlr:calculateFFB(dt))
    showDebugValues(dt)
end
