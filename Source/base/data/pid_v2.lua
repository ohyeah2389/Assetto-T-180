-- PID Controller, Version 2
-- Authored by ohyeah2389

local PIDController = class("PIDController")

local function isFinite(x)
    return x == x and x ~= math.huge and x ~= -math.huge
end

function PIDController:initialize(params)
    self.kP = params.kP or 0
    self.kI = params.kI or 0
    self.kD = params.kD or 0
    self.kFF = params.kFF or 0 -- Feed-forward gain applied to setpoint
    self.minOutput = params.minOutput or -1
    self.maxOutput = params.maxOutput or 1
    self.dampingFactor = params.dampingFactor or 0 -- Output smoothing time constant (s); 0 = off
    self.derivativeFilter = params.derivativeFilter or 0 -- Derivative low-pass time constant (s); 0 = off
    self.derivativeOnMeasurement = params.derivativeOnMeasurement or false -- Default is derivative on error

    -- Setpoint weighting: b weights the setpoint in P, c weights it in D (1 = classic PID)
    self.setpointWeightP = params.setpointWeightP or 1
    self.setpointWeightD = params.setpointWeightD or 1

    -- Output slew limit in units per second; unspecified = no limit
    self.slewRise = params.slewLimitIncrease or params.slewLimit
    self.slewFall = params.slewLimitDecrease or params.slewLimit

    -- Integral clamp; unspecified = no limit
    local base = params.integralLimit
    self.integralMax = params.integralLimitMax or base
    self.integralMin = params.integralLimitMin or (base and -base)

    self:reset()
end

function PIDController:update(setpoint, measurement, dt, paramOverride)
    if dt <= 0 then return self.previousOutput end

    -- Recover from any non-finite state
    if not (isFinite(self.integral) and isFinite(self.previousOutput)) then
        self:reset()
    end

    -- Per-update gain scheduling (nil leaves the configured gain unchanged)
    local kP, kI, kD, kFF = self.kP, self.kI, self.kD, self.kFF
    if paramOverride then
        if paramOverride.kP ~= nil then kP = paramOverride.kP end
        if paramOverride.kI ~= nil then kI = paramOverride.kI end
        if paramOverride.kD ~= nil then kD = paramOverride.kD end
        if paramOverride.kFF ~= nil then kFF = paramOverride.kFF end
    end

    local error = setpoint - measurement -- true error, used for the integral
    local P = kP * (self.setpointWeightP * setpoint - measurement)
    local FF = kFF * setpoint
    self.feedforward = FF

    -- Derivative term, skipped on first tick to avoid start kick
    local D = 0
    if self.initialized then
        local rate
        if self.derivativeOnMeasurement then
            rate = -(measurement - self.previousMeasurement) / dt
        else
            rate = (self.setpointWeightD * (setpoint - self.previousSetpoint) - (measurement - self.previousMeasurement)) / dt
        end
        if self.derivativeFilter > 0 then
            local beta = 1 - math.exp(-dt / self.derivativeFilter)
            self.derivativeState = self.derivativeState + beta * (rate - self.derivativeState)
            rate = self.derivativeState
        end
        D = kD * rate
    end

    -- Integral with conditional anti-windup:
    -- only commit the new integration when it does not push an already-saturated output further into saturation
    local candidate = self.integral + error * dt
    local testOutput = P + kI * candidate + D + FF
    local clamped = math.clamp(testOutput, self.minOutput, self.maxOutput)
    if error * (testOutput - clamped) <= 0 then
        self.integral = candidate
    end
    if self.integralMax then self.integral = math.min(self.integral, self.integralMax) end
    if self.integralMin then self.integral = math.max(self.integral, self.integralMin) end

    local output = P + kI * self.integral + D + FF

    -- Frame-rate independent output smoothing (dampingFactor is a time constant in seconds)
    if self.dampingFactor > 0 then
        local alpha = 1 - math.exp(-dt / self.dampingFactor)
        output = self.previousOutput + alpha * (output - self.previousOutput)
    end

    -- Asymmetric slew-rate limiting (units per second)
    local delta = output - self.previousOutput
    if delta > 0 and self.slewRise then
        delta = math.min(delta, self.slewRise * dt)
    elseif delta < 0 and self.slewFall then
        delta = math.max(delta, -self.slewFall * dt)
    end
    output = math.clamp(self.previousOutput + delta, self.minOutput, self.maxOutput)
    self.slewRate = (output - self.previousOutput) / dt

    self.previousError = error
    self.previousSetpoint = setpoint
    self.previousMeasurement = measurement
    self.previousOutput = output
    self.initialized = true

    return output
end

function PIDController:debug(name)
    ac.debug(name .. " Previous Error", self.previousError, -2, 2, 4)
    ac.debug(name .. " Integral", self.integral, self.integralMin or -20, self.integralMax or 20, 4)
    ac.debug(name .. " Previous Output", self.previousOutput, -5, 5, 4)
    ac.debug(name .. " Slew Rate", self.slewRate, -10, 10, 4)
    if self.kFF ~= 0 then
        ac.debug(name .. " Feedforward", self.feedforward, self.minOutput, self.maxOutput, 4)
    end
end

function PIDController:reset()
    self.previousError = 0
    self.previousSetpoint = 0
    self.previousMeasurement = 0
    self.integral = 0
    self.previousOutput = 0
    self.derivativeState = 0
    self.slewRate = 0
    self.feedforward = 0
    self.initialized = false
end

return PIDController
