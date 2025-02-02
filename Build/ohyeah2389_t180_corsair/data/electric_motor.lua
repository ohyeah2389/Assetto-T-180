-- T-180 CSP Physics Script - Electric Motor Module
-- Authored by ohyeah2389

local ElectricMotor = class("ElectricMotor")

function ElectricMotor:initialize(params)
    -- Core physical parameters
    self.nominalVoltage = params.nominalVoltage or 400    -- Nominal voltage (V)
    self.peakPower = params.peakPower or 150000           -- Peak power output (W)
    self.peakTorque = params.peakTorque or 500            -- Peak torque (Nm)
    self.maxRPM = params.maxRPM or 15000                  -- Maximum RPM
    
    -- Calculate derived parameters
    self.baseRPM = (self.peakPower * 60) / (2 * math.pi * self.peakTorque)
    self.kV = self.maxRPM / self.nominalVoltage           -- Motor velocity constant (RPM/V)
    self.kT = self.peakTorque / (self.peakPower / self.nominalVoltage)  -- Torque constant (Nm/A)
    
    -- Winding characteristics
    self.resistance = (self.nominalVoltage * self.nominalVoltage) / (4 * self.peakPower)
    self.inductance = params.inductance or (self.resistance / 100)
    
    -- Loss parameters
    self.copperLossFactor = params.copperLossFactor or 1.0
    self.ironLossFactor = params.ironLossFactor or 0.01
    self.mechanicalLossFactor = params.mechanicalLossFactor or 0.005
    self.regenEfficiency = params.regenEfficiency or 0.7
    
    -- State variables
    self.currentRPM = 0
    self.currentTorque = 0
    self.currentPower = 0
end


function ElectricMotor:calculateLosses(rpm, torque)
    local angularVelocity = rpm * (2 * math.pi / 60)
    local mechanicalPower = math.abs(torque * angularVelocity)
    
    -- Calculate various losses
    local copperLoss = (mechanicalPower / self.nominalVoltage)^2 * self.resistance * self.copperLossFactor
    local ironLoss = (rpm / self.maxRPM)^2 * self.peakPower * self.ironLossFactor
    local mechanicalLoss = (rpm / self.maxRPM)^2 * self.peakPower * self.mechanicalLossFactor
    
    return copperLoss, ironLoss, mechanicalLoss
end


function ElectricMotor:update(commandedTorque, rpm, mode)
    self.currentRPM = rpm
    self.currentTorque = commandedTorque
    
    -- Calculate power including losses
    local angularVelocity = rpm * (2 * math.pi / 60)
    local mechanicalPower = self.currentTorque * angularVelocity
    local copperLoss, ironLoss, mechanicalLoss = self:calculateLosses(rpm, self.currentTorque)
    
    if mode == "drive" then
        self.currentPower = mechanicalPower + copperLoss + ironLoss + mechanicalLoss
    else
        -- In regen mode, losses reduce recovered power
        local recoveredPower = math.abs(mechanicalPower) - ironLoss - mechanicalLoss
        self.currentPower = -math.max(0, recoveredPower * self.regenEfficiency)
    end
    
    -- Apply power limits
    self.currentPower = math.clamp(self.currentPower, -self.peakPower, self.peakPower)
end


return ElectricMotor
