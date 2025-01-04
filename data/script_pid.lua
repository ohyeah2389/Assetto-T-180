local PIDController = class("PIDController")


function PIDController:initialize(kP, kI, kD, minOutput, maxOutput, dampingFactor)
    self.kP = kP or 0
    self.kI = kI or 0
    self.kD = kD or 0
    self.minOutput = minOutput or -1
    self.maxOutput = maxOutput or 1
    self.dampingFactor = dampingFactor or 1  -- Default to no damping
    
    self.previousError = 0
    self.integral = 0
    self.previousOutput = 0  -- Store previous output for damping
end


function PIDController:update(setpoint, measurement, dt)
    local error = setpoint - measurement
    
    -- Proportional term
    local P = self.kP * error
    
    -- Integral term
    self.integral = self.integral + error * dt
    local I = self.kI * self.integral
    
    -- Derivative term
    local derivative = (error - self.previousError) / dt
    local D = self.kD * derivative * dt
    
    -- Save error for next iteration
    self.previousError = error
    
    -- Calculate total output
    local output = P + I + D
    
    -- Apply damping
    output = (output * self.dampingFactor) + (self.previousOutput * (1 - self.dampingFactor))
    self.previousOutput = output
    
    -- Clamp output to limits
    return math.clamp(output, self.minOutput, self.maxOutput)
end


function PIDController:reset()
    self.previousError = 0
    self.integral = 0
    self.previousOutput = 0  -- Reset previous output
end


return PIDController 