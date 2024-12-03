-- T-180 CSP Physics Script - Motor Controller Module
-- Authored by ohyeah2389

local MotorController = class("MotorController")

function MotorController:initialize(params)
    -- Control parameters
    self.motor = params.motor                    -- Reference to motor being controlled
    self.minRegenSpeed = params.minRegenSpeed or 0.001  -- Minimum speed for regen (as fraction of base RPM)
    self.regenTorqueFactor = params.regenTorqueFactor or 0.7  -- Max regen torque as fraction of peak torque
    self.mode = "drive"                          -- Current operating mode
end


function MotorController:determineMode(throttle, rpm)
    -- Determine if we should be in regen mode based on speed and throttle
    if (rpm > 0 and throttle < -0.01) or (rpm < 0 and throttle > 0.01) then
        return "regen"
    end
    return "drive"
end


function MotorController:calculateDriveTorque(throttle, rpm, availableVoltage)
    local motor = self.motor
    local speedRatio = rpm / motor.baseRPM
    local maxTorqueAtSpeed
    
    -- Calculate torque limit based on speed
    if speedRatio <= 1.0 then
        -- Constant torque region
        maxTorqueAtSpeed = motor.peakTorque
    else
        -- Constant power region
        maxTorqueAtSpeed = motor.peakTorque / speedRatio
    end
    
    -- Apply voltage limitation
    local backEMF = (rpm / motor.kV)
    local voltageRatio = (availableVoltage - backEMF) / motor.nominalVoltage
    voltageRatio = math.clamp(voltageRatio, 0, 1)
    
    return maxTorqueAtSpeed * throttle * voltageRatio
end


function MotorController:calculateRegenTorque(throttle, rpm)
    local motor = self.motor
    
    -- Only allow regen above minimum speed
    if math.abs(rpm) > (motor.baseRPM * self.minRegenSpeed) then
        local maxRegenTorque = motor.peakTorque * self.regenTorqueFactor
        local speedRatio = rpm / motor.baseRPM
        
        if speedRatio > 1.0 then
            maxRegenTorque = maxRegenTorque / speedRatio  -- Maintain power limit
        end
        
        return -math.sign(rpm) * maxRegenTorque * math.abs(throttle)
    else
        -- Below minimum speed: provide braking torque without regeneration
        return -math.sign(throttle) * motor.peakTorque * 0.2 * math.abs(throttle)
    end
end


function MotorController:update(throttle, rpm, batteryVoltage)
    -- Determine operating mode
    self.mode = self:determineMode(throttle, rpm)
    
    -- Calculate commanded torque based on mode
    local commandedTorque
    if self.mode == "drive" then
        commandedTorque = self:calculateDriveTorque(throttle, rpm, batteryVoltage)
    else
        commandedTorque = self:calculateRegenTorque(throttle, rpm)
    end
    
    -- Command the motor
    return commandedTorque, self.mode
end


return MotorController