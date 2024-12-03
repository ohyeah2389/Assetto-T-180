-- T-180 CSP Physics Script - Main Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local config = require('script_config')
local state = require('script_state')
local electricComponents = require('script_electric_components')
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
        ac.overrideBrakesTorque(0, config.misc.brakeAutoHold.torque, config.misc.brakeAutoHold.torque)
        ac.overrideBrakesTorque(1, config.misc.brakeAutoHold.torque, config.misc.brakeAutoHold.torque)
        ac.overrideBrakesTorque(2, config.misc.brakeAutoHold.torque, config.misc.brakeAutoHold.torque)
        ac.overrideBrakesTorque(3, config.misc.brakeAutoHold.torque, config.misc.brakeAutoHold.torque)
    else
        ac.overrideBrakesTorque(0, math.nan, math.nan)
        ac.overrideBrakesTorque(1, math.nan, math.nan)
        ac.overrideBrakesTorque(2, math.nan, math.nan)
        ac.overrideBrakesTorque(3, math.nan, math.nan)
    end
end


-- Initialize components
local mainBattery = electricComponents.Battery(config.electrics.batteries.mainBattery)


-- Initialize motors
local frontLeftMotor = electricComponents.ElectricMotor(config.electrics.motors.hubMotorConfig)
local frontLeftController = electricComponents.MotorController({ motor = frontLeftMotor })
local frontRightMotor = electricComponents.ElectricMotor(config.electrics.motors.hubMotorConfig)
local frontRightController = electricComponents.MotorController({ motor = frontRightMotor })
local rearLeftMotor = electricComponents.ElectricMotor(config.electrics.motors.hubMotorConfig)
local rearLeftController = electricComponents.MotorController({ motor = rearLeftMotor })
local rearRightMotor = electricComponents.ElectricMotor(config.electrics.motors.hubMotorConfig)
local rearRightController = electricComponents.MotorController({ motor = rearRightMotor })


local wheelSteerCtrlr = WheelSteerController()
local hubMotorCtrlr = HubMotorController()


function script.reset()
    wheelSteerCtrlr:reset()
end
script.reset()
ac.onCarJumped(0, script.reset)


-- Run by game every physics tick (~333 Hz)
---@diagnostic disable-next-line: duplicate-set-field
function script.update(dt)
    ac.awakeCarPhysics()
    brakeAutoHold()

    wheelSteerCtrlr:update(dt)
    local wheelCommands = hubMotorCtrlr:update(dt)

    -- Update motors
    local torque, mode = frontLeftController:update(wheelCommands[1],
        game.car_cphys.wheels[0].angularSpeed * (60 / (2 * math.pi)),
        mainBattery.voltage)
    frontLeftMotor:update(torque,
        game.car_cphys.wheels[0].angularSpeed * (60 / (2 * math.pi)),
        mode)

    torque, mode = frontRightController:update(wheelCommands[2],
        game.car_cphys.wheels[1].angularSpeed * (60 / (2 * math.pi)),
        mainBattery.voltage)
    frontRightMotor:update(torque,
        game.car_cphys.wheels[1].angularSpeed * (60 / (2 * math.pi)),
        mode)

    torque, mode = rearLeftController:update(wheelCommands[3],
        game.car_cphys.wheels[2].angularSpeed * (60 / (2 * math.pi)),
        mainBattery.voltage)
    rearLeftMotor:update(torque,
        game.car_cphys.wheels[2].angularSpeed * (60 / (2 * math.pi)),
        mode)

    torque, mode = rearRightController:update(wheelCommands[4],
        game.car_cphys.wheels[3].angularSpeed * (60 / (2 * math.pi)),
        mainBattery.voltage)
    rearRightMotor:update(torque,
        game.car_cphys.wheels[3].angularSpeed * (60 / (2 * math.pi)),
        mode)

    -- Calculate total power draw
    local totalPower = frontLeftMotor.currentPower + 
                      frontRightMotor.currentPower +
                      rearLeftMotor.currentPower +
                      rearRightMotor.currentPower

    -- Update battery
    mainBattery:update(totalPower, dt)

    -- Apply torques
    ac.addElectricTorque(ac.Wheel.FrontLeft, frontLeftMotor.currentTorque, true)
    ac.addElectricTorque(ac.Wheel.FrontRight, frontRightMotor.currentTorque, true)
    ac.addElectricTorque(ac.Wheel.RearLeft, rearLeftMotor.currentTorque, true)
    ac.addElectricTorque(ac.Wheel.RearRight, rearRightMotor.currentTorque, true)

    ac.debug("mainBattery.voltage", mainBattery.voltage)
    ac.debug("mainBattery.soc", mainBattery.soc)
    ac.debug("mainBattery.storedEnergy", mainBattery.storedEnergy)
    ac.debug("motors frontLeft currentTorque", frontLeftMotor.currentTorque)
    ac.debug("motors frontLeft currentPower", frontLeftMotor.currentPower)
    ac.debug("motors frontLeft currentRPM", frontLeftMotor.currentRPM)
    ac.debug("motors frontLeft mode", frontLeftController.mode)
    ac.debug("motors frontRight currentTorque", frontRightMotor.currentTorque)
    ac.debug("motors frontRight currentPower", frontRightMotor.currentPower)
    ac.debug("motors frontRight currentRPM", frontRightMotor.currentRPM)
    ac.debug("motors frontRight mode", frontRightController.mode)
    ac.debug("motors rearLeft currentTorque", rearLeftMotor.currentTorque)
    ac.debug("motors rearLeft currentPower", rearLeftMotor.currentPower)
    ac.debug("motors rearLeft currentRPM", rearLeftMotor.currentRPM)
    ac.debug("motors rearLeft mode", rearLeftController.mode)
    ac.debug("motors rearRight currentTorque", rearRightMotor.currentTorque)
    ac.debug("motors rearRight currentPower", rearRightMotor.currentPower)
    ac.debug("motors rearRight currentRPM", rearRightMotor.currentRPM)
    ac.debug("motors rearRight mode", rearRightController.mode)

    ac.setSteeringFFB(wheelSteerCtrlr:calculateFFB(dt))
    ac.overrideGasInput(0)
    ac.overrideEngineTorque(0)
    game.car_cphys.clutch = 0
    showDebugValues(dt)
end
