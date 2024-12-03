-- T-180 CSP Physics Script - Main Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local config = require('script_config')
local state = require('script_state')
local helpers = require('script_helpers')
local WheelSteerController = require('script_wheelsteerctrlr')
local HubMotorController = require('script_hubmotorctrlr')


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

local afterburnerAmountMaxSeconds = 20
local afterburnerAmountSeconds = afterburnerAmountMaxSeconds
local afterburnerSpool = 0

function script.reset()
    wheelSteerCtrlr:reset()
    afterburnerAmountSeconds = afterburnerAmountMaxSeconds
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

    ac.setSteeringFFB(wheelSteerCtrlr:calculateFFB(dt))
    showDebugValues(dt)
end
