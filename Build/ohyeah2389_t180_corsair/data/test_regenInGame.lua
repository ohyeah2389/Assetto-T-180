local TestRegenInGame = class("TestRegenInGame")
local game = require('script_acConnection')

function TestRegenInGame:initialize(params)
    self.startTime = nil
    self.phase = "waiting"  -- waiting, accel, coast, regen
    self.data = {}
    self.lastLogTime = 0
    self.logInterval = 0.5  -- Log every 0.5 seconds
    self.output = ""  -- Accumulate output here
    
    -- Store component references
    self.motor = params.motor
    self.controller = params.controller
    self.battery = params.battery
    self.circuitSolver = params.circuitSolver
end

function TestRegenInGame:update(dt)
    if not self.startTime then
        -- Wait for car to be stationary before starting
        if math.abs(game.car_cphys.speedKmh) < 0.1 then
            self.startTime = os.clock()
            self.phase = "accel"
            self.output = "\n=== Starting In-Game Regen Test ===\n\n"
        end
        return false
    end

    local testTime = os.clock() - self.startTime

    -- Control inputs based on test phase
    if self.phase == "accel" and testTime < 5.0 then
        -- Full acceleration for 5s
        -- Should reach ~140 km/h
        game.car_cphys.gas = 1.0
        game.car_cphys.brake = 0
        game.car_cphys.steer = 0
        
    elseif self.phase == "accel" and testTime >= 5.0 then
        -- Switch to coast phase
        self.phase = "coast"
        game.car_cphys.gas = 0
        
    elseif self.phase == "coast" and testTime < 7.0 then
        -- Coast for 2s
        -- Should drop to ~70 km/h
        game.car_cphys.gas = 0
        game.car_cphys.brake = 0
        game.car_cphys.steer = 0
        
    elseif self.phase == "coast" and testTime >= 7.0 then
        -- Switch to regen phase
        self.phase = "regen"
        game.car_cphys.gas = -0.5
        
    elseif self.phase == "regen" and testTime < 15.0 then
        -- Regen for 8s
        -- Should drop to ~0 km/h
        game.car_cphys.gas = -0.5  -- 50% regen
        game.car_cphys.brake = 0
        game.car_cphys.steer = 0
        
    elseif game.car_cphys.speedKmh < 0.1 then
        -- Test complete when car stops
        game.car_cphys.gas = 0
        game.car_cphys.brake = 0
        game.car_cphys.steer = 0
        print(self.output)
        return true
        
    else
        -- Keep braking until car stops
        game.car_cphys.gas = -0.5
        game.car_cphys.brake = 0
        game.car_cphys.steer = 0
    end

    -- Log data at regular intervals
    if testTime - self.lastLogTime >= self.logInterval then
        self.lastLogTime = testTime
        
        -- Get values directly from components
        local motorSpeed = game.car_cphys.wheels[0].angularSpeed
        local motorTorque = self.motor.torque
        local motorCurrent = self.motor.amperage
        local motorVoltage = self.motor.voltage
        local controllerMode = self.controller.mode
        local batteryPower = math.abs(self.battery.voltage * self.battery.amperage)
        local batteryCurrent = self.battery.amperage  -- Keep sign for charge/discharge
        local batteryVoltage = self.battery.voltage
        local batterySoC = self.battery.soc
        
        local entry = {
            time = string.format("%.2f", testTime),
            phase = self.phase,
            speed = game.car_cphys.speedKmh,
            throttle = game.car_cphys.gas,
            motorSpeed = motorSpeed,
            motorTorque = motorTorque,
            motorCurrent = motorCurrent,
            motorVoltage = motorVoltage,
            controllerMode = controllerMode,
            batteryPower = batteryPower,
            batteryCurrent = batteryCurrent,
            batteryVoltage = batteryVoltage,
            batterySoC = batterySoC,
            motorDebug = self.motor.debug,
            controllerDebug = self.controller.debug,
            circuitDebug = self.circuitSolver.debug
        }
        table.insert(self.data, entry)
        
        -- Add data point to output string
        self.output = self.output .. string.format(
            "t=%ss | Phase=%s | Speed=%.1fkm/h | Throttle=%.2f\n" ..
            "Motor: Speed=%.1frad/s, Current=%.1fA, Voltage=%.1fV, Torque=%.1fNm\n" ..
            "Controller: Mode=%s\n" ..
            "Battery: Power=%.1fkW, Current=%.1fA, Voltage=%.1fV, SoC=%.3f\n",
            entry.time, entry.phase, entry.speed, entry.throttle,
            entry.motorSpeed, entry.motorCurrent, entry.motorVoltage, entry.motorTorque,
            entry.controllerMode,
            entry.batteryPower / 1000, entry.batteryCurrent, entry.batteryVoltage, entry.batterySoC
        )

        -- Add debug info if available
        if entry.motorDebug and entry.motorDebug.regen then
            self.output = self.output .. string.format(
                "Debug:\n" ..
                "  Motor BackEMF=%.1fV\n" ..
                "  Controller LoadR=%.1fΩ\n" ..
                "  Power: Motor=%.1fkW, Battery=%.1fkW\n" ..
                "  Efficiency=%.1f%%\n",
                entry.motorDebug.regen.backEMF or 0,
                entry.controllerDebug.regen.loadResistance or 0,
                (entry.controllerDebug.regen.motorPower or 0) / 1000,
                (entry.controllerDebug.regen.batteryPower or 0) / 1000,
                entry.controllerDebug.regen.efficiency and (entry.controllerDebug.regen.efficiency * 100) or 0
            )
        end

        self.output = self.output .. "\n"
    end

    return false  -- Test still running
end

return TestRegenInGame 