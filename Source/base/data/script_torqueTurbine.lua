-- T-180 CSP Physics Script - Extended Turbine Physics Module
-- Authored by ohyeah2389


local state = require('script_state')
local config = require('car_config')
local physics = require('script_physics')
local FADEC = require('script_fadec')


local torqueTurbine = class("torqueTurbine")


function torqueTurbine:initialize(turbineId)
    self.turbineId = turbineId or 'rear'

    self.turbineConfig = config.torqueTurbine[self.turbineId] or {
        inertia = 0.02,
        maxTorque = 2000,
        finalDriveRatio = 1/25
    }

    self.turbine = physics({
        rotary = true,
        inertia = self.turbineConfig.inertia,
        forceMax = self.turbineConfig.maxTorque * 10,
        frictionCoef = 0.003,
        staticFrictionCoef = 1.2,
        expFrictionCoef = 1.3
    })

    -- Initial turbine speed (half of design max RPM)
    self.turbine.angularSpeed = config.torqueTurbine.designRPM * math.pi / 60

    -- Ambient conditions
    self.ambientPressure = 101.325  -- kPa at sea level
    self.ambientTemp = 288.15  -- K (15°C)
    self.massFlowAirCoefficient = 3.3  -- kg/s

    -- Thermodynamic properties
    self.specificHeatCapacity = 1005  -- J/kg·K
    self.specificHeatRatio = 1.4
    self.stoichiometricFAR = 1/14.7
    self.targetFAR = 0.02
    self.combustorPressureLoss = 0.03

    -- State variables
    self.state = {
        massFlowAir = 0,
        flameoutTimer = 0,
        combustionActive = true,
        pressureRatio = 1,
        tit = self.ambientTemp -- Start at ambient temperature
    }

    -- Combustion stability parameters
    self.flameoutDelay = 2.0  -- seconds of low fuel before flameout occurs
    self.minimumStableFuelFlow = 0.001  -- minimum fuel flow for stable combustion

    -- FADEC controller
    self.fadec = FADEC(self.turbineId)

    -- Sensor variables
    self.sensors = {
        n1RPM = 0,
        turbineInletTemp = self.ambientTemp,
        compressorDischargePressure = self.ambientPressure,
        fuelFlow = 0
    }

    -- Fuel system states and parameters
    self.fuelSystem = {
        commandedFlow = 0,    -- kg/s, fuel flow commanded by FADEC
        actualFlow = 0,       -- kg/s, actual fuel flow after lag
        timeConstant = 0.15   -- seconds, fuel system response time
    }
end


function torqueTurbine:update(dt)
    -- Get control inputs
    local inputs = {
        throttle = state.turbine[self.turbineId].throttle,
    }

    -- Update and get FADEC-commanded fuel flow
    self.fuelSystem.commandedFlow = self.fadec:update(dt, self.sensors, inputs)

    -- Apply fuel system lag
    local fuelFlowDelta = self.fuelSystem.commandedFlow - self.fuelSystem.actualFlow
    self.fuelSystem.actualFlow = self.fuelSystem.actualFlow +
        (fuelFlowDelta * dt / self.fuelSystem.timeConstant)

    -- Calculate speed and pressure ratios
    self.speedRatio = (self.turbine.angularSpeed * 60 / (2 * math.pi)) / config.torqueTurbine.designRPM
    self.state.pressureRatio = 1 + config.torqueTurbine.pressureRatio * (self.speedRatio * self.speedRatio)

    -- Air mass flow (simplified estimation)
    self.state.massFlowAir = self.speedRatio * self.massFlowAirCoefficient

    -- Combustion stability and flameout check
    if self.fuelSystem.actualFlow < self.minimumStableFuelFlow then
        self.state.flameoutTimer = self.state.flameoutTimer + dt
        if self.state.flameoutTimer >= self.flameoutDelay then
            self.state.combustionActive = false
        end
    else
        self.state.flameoutTimer = 0
    end

    -- Calculate compressor discharge temperature using "isentropic relation", whatever that means
    local t1 = 288.15  -- ambient temperature in Kelvin
    local inletTemp = t1 * (self.state.pressureRatio ^ ((self.specificHeatRatio - 1) / self.specificHeatRatio))

    -- Combustion calculations
    local far = self.fuelSystem.actualFlow / self.state.massFlowAir
    local heatAdded = self.fuelSystem.actualFlow * config.torqueTurbine.fuelLHV * config.torqueTurbine.combustionEfficiency
    local totalMassFlow = self.state.massFlowAir + self.fuelSystem.actualFlow
    local exitTemp = inletTemp + heatAdded / (totalMassFlow * self.specificHeatCapacity)
    local exitPressure = self.ambientPressure * self.state.pressureRatio * (1 - self.combustorPressureLoss)

    local combustion = {
        exitTemp = exitTemp,
        exitPressure = exitPressure,
        totalMassFlow = totalMassFlow,
        far = far
    }

    -- Implement thermal mass for TIT using a first-order lag filter
    local tauTemp = 1  -- time constant in seconds
    self.state.tit = self.state.tit + dt * (combustion.exitTemp - self.state.tit) / tauTemp

    -- Update sensor readings
    self.sensors.n1RPM = self.turbine.angularSpeed * 60 / (2 * math.pi)
    self.sensors.turbineInletTemp = self.state.tit
    self.sensors.compressorDischargePressure = self.ambientPressure * self.state.pressureRatio
    self.sensors.fuelFlow = self.fuelSystem.actualFlow

    -- Turbine torque calculations
    local deltaTemp = combustion.exitTemp - inletTemp
    local turbineTorque = 0
    if deltaTemp > 0 and combustion.far >= 1e-6 then
        local powerAvailable = combustion.totalMassFlow * self.specificHeatCapacity *
                             deltaTemp * config.torqueTurbine.turbineEfficiency
        turbineTorque = powerAvailable / math.max(self.turbine.angularSpeed, 1)
    end

    -- Compressor torque calculations
    local t2 = t1 * (self.state.pressureRatio ^ ((self.specificHeatRatio - 1) / self.specificHeatRatio))
    local powerRequired = self.state.massFlowAir * self.specificHeatCapacity * (t2 - t1) / config.torqueTurbine.compressorEfficiency
    local compressorTorque = -powerRequired / math.max(self.turbine.angularSpeed, 1)

    -- Net torque is turbine + compressor
    local appliedTorque = turbineTorque + compressorTorque

    -- Apply torque limits from config
    local limitedTorque = math.clamp(appliedTorque, -self.turbineConfig.maxTorque, self.turbineConfig.maxTorque)
    self.turbine:step(limitedTorque - state.turbine[self.turbineId].feedbackTorque, dt)
    state.turbine[self.turbineId].torque = limitedTorque
    state.turbine[self.turbineId].rpm = self.turbine.angularSpeed * 60 / (2 * math.pi)

    -- Debug outputs with turbine ID
    local rpm = self.turbine.angularSpeed * 60 / (2 * math.pi)
    ac.debug("torqueTurbine." .. self.turbineId .. ".turbineTorque", turbineTorque)
    ac.debug("torqueTurbine." .. self.turbineId .. ".compressorTorque", compressorTorque)
    ac.debug("torqueTurbine." .. self.turbineId .. ".netTorque", limitedTorque)
    ac.debug("torqueTurbine." .. self.turbineId .. ".RPM", rpm)
    ac.debug("torqueTurbine." .. self.turbineId .. ".pressureRatio", self.state.pressureRatio)
    ac.debug("torqueTurbine." .. self.turbineId .. ".outletPressure", self.ambientPressure * self.state.pressureRatio)
    ac.debug("torqueTurbine." .. self.turbineId .. ".combustion.exitTemp", combustion.exitTemp)
    ac.debug("torqueTurbine." .. self.turbineId .. ".combustion.exitPressure", combustion.exitPressure)
    ac.debug("torqueTurbine." .. self.turbineId .. ".combustion.FAR", combustion.far)
    ac.debug("torqueTurbine." .. self.turbineId .. ".combustion.fuelFlow", self.fuelSystem.actualFlow)
    ac.debug("torqueTurbine." .. self.turbineId .. ".combustionActive", self.state.combustionActive)
end


function torqueTurbine:reset()
    self.turbine.angularSpeed = config.torqueTurbine.designRPM * math.pi / 60
    self.state.combustionActive = true
    self.state.flameoutTimer = 0
    self.state.tit = self.ambientTemp
    self.fuelSystem.actualFlow = 0
    self.fuelSystem.commandedFlow = 0
end


return torqueTurbine
