-- PID Controller
-- Authored by ohyeah2389


local PIDController = class("PIDController")


function PIDController:initialize(kP, kI, kD, minOutput, maxOutput, dampingFactor)
    self.kP = kP or 0
    self.kI = kI or 0
    self.kD = kD or 0
    self.minOutput = minOutput or -1
    self.maxOutput = maxOutput or 1
    self.dampingFactor = dampingFactor or 1 -- Default is no damping

    self.previousError = 0
    self.integral = 0
    self.previousOutput = 0
end


function PIDController:update(setpoint, measurement, dt)
    -- Check for infinite values in state variables and reset if found
    if math.abs(self.integral) == math.huge or 
       math.abs(self.previousError) == math.huge or 
       math.abs(self.previousOutput) == math.huge then
        self:reset()
    end

    local error = setpoint - measurement

    -- Proportional term
    local P = self.kP * error

    -- Integral term with anti-windup
    self.integral = self.integral + error * dt
    local I = self.kI * self.integral

    -- Derivative term
    local derivative = (error - self.previousError) / dt
    local D = self.kD * derivative

    -- Calculate output before clamping (for anti-windup)
    local output = P + I + D

    -- If output would saturate, prevent integral from growing further
    if output > self.maxOutput then
        self.integral = self.integral - error * dt  -- Unwind the last integration
    elseif output < self.minOutput then
        self.integral = self.integral - error * dt  -- Unwind the last integration
    end

    -- Recalculate I term with possibly adjusted integral
    I = self.kI * self.integral

    -- Save error for next iteration
    self.previousError = error

    -- Calculate total output
    local totalOutput = P + I + D

    -- Apply damping
    totalOutput = (totalOutput * self.dampingFactor) + (self.previousOutput * (1 - self.dampingFactor))
    self.previousOutput = totalOutput

    -- Clamp output to limits
    return math.clamp(totalOutput, self.minOutput, self.maxOutput)
end


function PIDController:reset()
    self.previousError = 0
    self.integral = 0
    self.previousOutput = 0  -- Reset previous output
end


return PIDController