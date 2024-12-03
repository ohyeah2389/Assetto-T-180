local Battery = require('electric_battery')
local ElectricMotor = require('electric_motor')
local MotorController = require('electric_motorController')
local CircuitSolver = require('script_circuitSolver')

-- Test helper function
local function printState(motor, battery, controller, time, output)
    -- Calculate powers correctly based on current flow
    local motorPower = math.abs(motor.voltage * motor.amperage)
    local batteryPower = math.abs(battery.voltage * battery.amperage)
    
    -- Calculate regen efficiency
    local regenEff = 0
    if controller.mode == "regen" and motorPower > 0 then
        regenEff = (batteryPower / motorPower) * controller.regenEfficiency * 100
    end
    
    return output .. string.format(
        "t=%.2fs | " ..
        "Motor: Speed=%.1f rad/s, Current=%.2fA, Torque=%.2fNm, BackEMF=%.1fV | " ..
        "Controller: Mode=%s, Throttle=%.2f, Voltage=%.1fV, Resistance=%.3fΩ | " ..
        "Battery: SoC=%.3f, Current=%.2fA, Voltage=%.1fV | " ..
        "Power: Motor=%.1fW, Battery=%.1fW, Regen Eff=%.1f%%\n",
        time,
        motor.physics.angularSpeed,
        motor.amperage,
        motor.torque,
        motor.backEMFConstant * motor.physics.angularSpeed,
        controller.mode,
        controller.throttle,
        controller.voltage,
        1 / controller:getConductance(),
        battery.soc,
        battery.amperage,
        battery.voltage,
        motorPower,
        batteryPower,
        regenEff
    )
end

-- Create test circuit
local function testRegenBraking()
    local output = ""
    local debug_output = ""
    
    -- Initialize components
    local battery = Battery({
        ratedVoltage = 400,
        capacity = 1000,
        internalResistance = 0.05,
        socCurve = {get = function(soc) return 1.0 end},
        debug = true
    })
    debug_output = debug_output .. "Created battery:" .. battery.class.name .. "\n"
    debug_output = debug_output .. (battery.initDebugOutput or "")
    
    local motor = ElectricMotor({
        resistance = 0.1,
        inductance = 0.001,
        backEMFConstant = 0.1,
        inertia = 0.1,
        frictionCoefficient = 0.01,
        linkedRPM = function() return 0 end -- Temporary placeholder
    })
    motor.linkedRPM = function() 
        return motor.physics.angularSpeed * 60 / (2 * math.pi)
    end

    local controller = MotorController({
        motor = motor,
        maxVoltage = 400,
        regenEnabled = true,
        regenMaxVoltage = 200,
        regenEfficiency = 0.7
    })

    local circuit = CircuitSolver({debug = true})
    
    -- Create nodes
    local batteryPos = circuit:addNode(battery.voltage)  -- Fixed voltage node
    local batteryNeg = circuit:addNode(0)               -- Ground
    local motorPos = circuit:addNode()
    
    -- Connect components
    output = output .. "Connecting battery between nodes " .. batteryPos .. " and " .. batteryNeg .. "\n"
    debug_output = debug_output .. circuit:addComponent(battery, batteryPos, batteryNeg)
    output = output .. "Connecting controller between nodes " .. motorPos .. " and " .. batteryPos .. "\n"
    debug_output = debug_output .. circuit:addComponent(controller, motorPos, batteryPos)
    output = output .. "Connecting motor between nodes " .. motorPos .. " and " .. batteryNeg .. "\n"
    debug_output = debug_output .. circuit:addComponent(motor, motorPos, batteryNeg)

    -- Test sequence
    local dt = 1/333
    local time = 0
    
    output = output .. "Starting Regenerative Braking Test\n"
    output = output .. "\n=== Acceleration Phase ===\n"
    -- First accelerate the motor
    for i = 1, 1000 do
        controller:setThrottle(1.0)
        local step_debug = circuit:solve(dt)
        if i % 200 == 0 then  -- Only store debug output when we print state
            debug_output = debug_output .. "\n=== Debug at t=" .. string.format("%.2f", time) .. "s ===\n"
            debug_output = debug_output .. step_debug
            output = printState(motor, battery, controller, time, output)
        end
        time = time + dt
    end

    output = output .. "\n=== Coast Phase ===\n"
    for i = 1, 200 do
        controller:setThrottle(0)
        local step_debug = circuit:solve(dt)
        if i % 50 == 0 then
            debug_output = debug_output .. "\n=== Debug at t=" .. string.format("%.2f", time) .. "s ===\n"
            debug_output = debug_output .. step_debug
            output = printState(motor, battery, controller, time, output)
        end
        time = time + dt
    end

    output = output .. "\n=== Regenerative Braking Phase ===\n"
    for i = 1, 1000 do
        controller:setThrottle(-0.5)
        local step_debug = circuit:solve(dt)
        if i % 200 == 0 then
            debug_output = debug_output .. "\n=== Debug at t=" .. string.format("%.2f", time) .. "s ===\n"
            debug_output = debug_output .. step_debug
            output = printState(motor, battery, controller, time, output)
        end
        time = time + dt
    end
    
    -- Print both normal output and debug info
    print(output)
    print("\n=== Debug Output ===\n")
    print(debug_output)
end

-- Run the test
testRegenBraking() 