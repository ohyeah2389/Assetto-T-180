-- T-180 CSP Physics Script - Battery Module
-- Authored by ohyeah2389

local Battery = class("Battery")

function Battery:initialize(params)
    -- Core parameters
    self.capacity = params.capacity                   -- Watt-hours
    self.ratedVoltage = params.ratedVoltage          -- Nominal voltage
    self.internalResistance = params.internalResistance or 0.1  -- Internal resistance in ohms
    self.socCurve = params.socCurve                  -- State of charge curve
    
    -- Performance limits
    self.maxChargePower = params.maxChargePower or (self.capacity * 1.5)  -- Default to 1.5C charge rate
    self.maxDischargePower = params.maxDischargePower or (self.capacity * 3)  -- Default to 3C discharge rate
    
    -- Thermal parameters (for future use)
    self.thermalMass = params.thermalMass or 500     -- J/K - Heat capacity
    self.temperature = 20                            -- Celsius - Starting temperature
    
    -- State variables
    self.storedEnergy = self.capacity                -- Start at full charge
    self.soc = 1.0                                   -- State of charge (0.0 to 1.0)
    self.voltage = self.ratedVoltage                 -- Current voltage
    self.current = 0                                 -- Current in amps
    self.power = 0                                   -- Power in watts
end


function Battery:update(power, dt)
    -- Store current power draw
    self.power = power
    
    -- Calculate current based on power and voltage (P = VI)
    self.current = power / self.voltage
    
    -- Apply power limits
    if power > 0 then  -- Discharging
        power = math.min(power, self.maxDischargePower)
    else  -- Charging
        power = math.max(power, -self.maxChargePower)
    end
    
    -- Calculate voltage drop due to internal resistance (V = IR)
    local voltageDrop = math.abs(self.current) * self.internalResistance
    
    -- Convert power (watts) to energy (watt-hours) for this timestep
    local energyChange = power * (dt / 3600)
    
    -- Update stored energy (negative power = charging)
    self.storedEnergy = self.storedEnergy - energyChange
    
    -- Update state of charge
    self.soc = math.clamp(self.storedEnergy / self.capacity, 0.0, 1.0)
    
    -- Update voltage based on SoC curve and load
    local baseVoltage = self.ratedVoltage * self.socCurve:get(self.soc)
    if self.current > 0 then  -- Discharging
        self.voltage = baseVoltage - voltageDrop
    else  -- Charging
        self.voltage = baseVoltage + voltageDrop
    end
    
    -- Clamp voltage to reasonable limits
    local minVoltage = self.ratedVoltage * 0.7  -- 70% of rated voltage
    local maxVoltage = self.ratedVoltage * 1.2  -- 120% of rated voltage
    self.voltage = math.clamp(self.voltage, minVoltage, maxVoltage)
end


return Battery