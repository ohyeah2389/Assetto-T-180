-- T-180 CSP Physics Script - Extended Turbine Physics Module
-- Authored by ohyeah2389


local state = require('script_state')
local config = require('car_config')
local physics = require('script_physics')
local FADEC = require('script_fadec')
local game = require('script_acConnection')


local Turboshaft = class("Turboshaft")


function Turboshaft:initialize(turbineId)
    self.turbineId = turbineId or 'rear'

    -- Gas Generator turbine (NG)
    self.gasTurbine = physics({
        rotary = true,
        inertia = config.turboshaft.inertiaNG or 0.02,
        forceMax = 10000,
        frictionCoef = 0.003,
        staticFrictionCoef = 1.2,
        expFrictionCoef = 1.3
    })

    -- Initial turbine speed
    self.gasTurbine.angularSpeed = config.turboshaft.designMaxNGRPM * math.pi / 60

    -- Ambient conditions
    self.ambientPressure = ac.getAirPressure(game.car_cphys.position)  -- kPa at sea level
    self.ambientTemp = 273.15 + game.car_cphys.ambientTemperature
    self.massFlowAirCoefficient = 1.5  -- kg/s

    -- Thermodynamic properties
    self.specificHeatCapacity = 1005  -- J/kg·K
    self.specificHeatRatio = 1.4
    self.stoichiometricFAR = 1/14.7
    self.targetFAR = 0.02
    self.combustorPressureLoss = 0.03
    self.TITLag = 1.0

    -- Damage constants
    self.damageTurbineOvertempK = 0.0004
    self.damageTurbineOvertempStart = 1500
    self.damageTurbineOvertempRecoveryK = 0.035
    self.damageCompressorOverspeedK = 0.00003
    self.damageCompressorOverspeedStart = 40000
    self.damageCompressorOverspeedRecoveryK = 0.035
    self.damageAccumulatorMaxTime = 5.0      -- Maximum accumulation time in seconds
    self.damageAccumulatorRampRate = 0.2     -- Higher = faster ramp up of damage
    self.damageAccumulatorDecayRate = 5.0    -- How fast accumulator decays when temp is normal

    -- State variables
    self.state = {
        massFlowAir = 0,
        flameoutTimer = 0,
        overtempTimer = 0,
        combustionActive = true,
        pressureRatio = 1,
        tit = self.ambientTemp, -- Start at ambient temperature
        damageTurbineBlades = 0,
        damageCompressorBlades = 0,
        warnings = {},
        cautions = {},
        damageAccumulatorTurbine = 0,
    }

    self.damageCompressorDerateCurve = ac.DataLUT11():add(0, 1):add(0.25, 0.5):add(0.5, 0.2):add(0.75, 0.15):add(1, 0.1)
    self.damageTurbineDerateCurve = ac.DataLUT11():add(0, 1):add(0.25, 0.9):add(0.5, 0.6):add(0.75, 0.3):add(1, 0.1)

    -- Combustion stability parameters
    self.flameoutDelay = 4.0  -- seconds of low fuel before flameout occurs
    self.minimumStableFuelFlow = 0.00001  -- minimum fuel flow for stable combustion

    -- FADEC controller
    self.fadec = FADEC(self.turbineId)
    self.maxNG = config.turboshaft.designMaxNGRPM
    self.maxTIT = config.turboshaft.designMaxTIT
    self.boostedMaxNG = config.turboshaft.designMaxNGRPM * config.turboshaft.boostNGMultiplier
    self.boostedMaxTIT = config.turboshaft.designMaxTIT * config.turboshaft.boostTITMultiplier

    -- Sensor variables, initialized with ambient state
    self.sensors = {
        ngRPM = 0,
        turbineInletTemp = self.ambientTemp,
        compressorDischargePressure = self.ambientPressure,
        fuelFlow = 0
    }

    -- Fuel system states and parameters
    self.fuelSystem = {
        commandedFuelFlow = 0.1,    -- kg/s, fuel flow commanded by FADEC
        actualFuelFlow = 0.1,       -- kg/s, actual fuel flow after lag
        timeConstant = 0.15   -- seconds, fuel system response time
    }

    -- Turbine efficiency
    self.turbineEfficiency = config.turboshaft.totalTurbineEfficiency or 0.85
end


function Turboshaft:update(dt)
    -- Get control inputs
    local controls = {
        throttle = state.turbine[self.turbineId].throttle,
    }

    -- Update and get FADEC-commanded fuel flow
    self.fuelSystem.commandedFuelFlow = self.fadec:update(dt, self.sensors, controls, car.extraB and self.boostedMaxNG or self.maxNG, car.extraB and self.boostedMaxTIT or self.maxTIT)

    -- Apply fuel system lag
    local fuelFlowDelta = self.fuelSystem.commandedFuelFlow - self.fuelSystem.actualFuelFlow
    self.fuelSystem.actualFuelFlow = self.fuelSystem.actualFuelFlow +
        (fuelFlowDelta * dt / self.fuelSystem.timeConstant)

    -- Calculate speed and pressure ratios
    self.speedRatio = (self.gasTurbine.angularSpeed * 60 / (2 * math.pi)) / config.turboshaft.designMaxNGRPM
    self.state.pressureRatio = 1 + config.turboshaft.pressureRatio * (self.speedRatio * self.speedRatio)

    -- Air mass flow (simplified estimation)
    self.state.massFlowAir = self.speedRatio * self.massFlowAirCoefficient * self.damageCompressorDerateCurve:get(self.state.damageCompressorBlades)

    -- Combustion stability and flameout check
    --if self.fuelSystem.actualFuelFlow < self.minimumStableFuelFlow then
    --    self.state.flameoutTimer = self.state.flameoutTimer + dt
    --    if self.state.flameoutTimer >= self.flameoutDelay then
    --        self.state.combustionActive = false
    --    end
    --else
    --    self.state.flameoutTimer = 0
    --end

    -- Calculate compressor discharge temperature using "isentropic relation", whatever that means
    local inletTemp = self.ambientTemp * (self.state.pressureRatio ^ ((self.specificHeatRatio - 1) / self.specificHeatRatio))

    -- Compressor torque calculations
    local powerRequired = self.state.massFlowAir * self.specificHeatCapacity * (inletTemp - self.ambientTemp) / config.turboshaft.compressorEfficiency
    -- Convert power from Watts to kilowatts for better numerical stability
    powerRequired = powerRequired / 1000 

    local compressorTorque = -powerRequired * 1000 / math.max(self.gasTurbine.angularSpeed, 1) / 
                            self.damageCompressorDerateCurve:get(self.state.damageCompressorBlades)

    -- Combustion calculations
    local fuelAirRatio = self.fuelSystem.actualFuelFlow / math.max(self.state.massFlowAir, 0.001)
    local combustionHeatAdded = self.fuelSystem.actualFuelFlow * config.turboshaft.fuelLHV * config.turboshaft.combustionEfficiency
    local totalMassFlow = self.state.massFlowAir + self.fuelSystem.actualFuelFlow
    local combustionExitTemp = inletTemp + (combustionHeatAdded / math.max(totalMassFlow, 0.001)) / self.specificHeatCapacity
    local combustionExitPressure = self.ambientPressure * self.state.pressureRatio * (1 - self.combustorPressureLoss)

    -- Implement "thermal mass" for TIT using lag
    self.state.tit = self.state.tit + dt * (combustionExitTemp - self.state.tit) / self.TITLag

    -- Update sensor readings
    self.sensors.ngRPM = self.gasTurbine.angularSpeed * 60 / (2 * math.pi)
    self.sensors.turbineInletTemp = self.state.tit
    self.sensors.compressorDischargePressure = self.ambientPressure * self.state.pressureRatio
    self.sensors.fuelFlow = self.fuelSystem.actualFuelFlow

    -- Turbine torque calculations
    local deltaTemp = combustionExitTemp - inletTemp
    local turbineTorque = 0

    if deltaTemp > 0 and self.state.combustionActive then
        -- Calculate total power available from combustion (in kW)
        local totalPowerAvailable = (totalMassFlow * self.specificHeatCapacity *
                                  deltaTemp * self.turbineEfficiency) / 1000

        -- Convert power (kW) to torque (Nm)
        turbineTorque = totalPowerAvailable * 1000 / math.max(self.gasTurbine.angularSpeed, 1)
    end

    -- Apply damage derating
    turbineTorque = turbineTorque * self.damageTurbineDerateCurve:get(self.state.damageTurbineBlades)

    -- Net torque for gas generator is turbine - compressor (note the sign change)
    local ngAppliedTorque = turbineTorque + compressorTorque

    -- Apply torque limits and step physics
    local finalNGTorque = math.clamp(ngAppliedTorque, -10000, 10000)

    self.gasTurbine:step(finalNGTorque - state.turbine[self.turbineId].feedbackTorque, dt)

    -- Update state values
    state.turbine[self.turbineId].outputTorque = turbineTorque -- Use gas turbine torque as output
    state.turbine[self.turbineId].outputRPM = self.gasTurbine.angularSpeed * 60 / (2 * math.pi)

    -- Debug outputs with turbine ID
    ac.debug("turboshaft." .. self.turbineId .. ".turbineTorque", turbineTorque)
    ac.debug("turboshaft." .. self.turbineId .. ".gasTurbine.RPM", self.gasTurbine.angularSpeed * 60 / (2 * math.pi))
    ac.debug("turboshaft." .. self.turbineId .. ".compressorTorque", compressorTorque)
    ac.debug("turboshaft." .. self.turbineId .. ".pressureRatio", self.state.pressureRatio)
    ac.debug("turboshaft." .. self.turbineId .. ".combustionExitTemp", combustionExitTemp)
    ac.debug("turboshaft." .. self.turbineId .. ".combustionExitPressure", combustionExitPressure)
    ac.debug("turboshaft." .. self.turbineId .. ".fuelAirRatio", fuelAirRatio)
    ac.debug("turboshaft." .. self.turbineId .. ".actualFuelFlow", self.fuelSystem.actualFuelFlow)
    ac.debug("turboshaft." .. self.turbineId .. ".combustionActive", self.state.combustionActive)
    ac.debug("turboshaft." .. self.turbineId .. ".damageTurbineBlades", self.state.damageTurbineBlades)
    ac.debug("turboshaft." .. self.turbineId .. ".damageCompressorBlades", self.state.damageCompressorBlades)
    ac.debug("turboshaft." .. self.turbineId .. ".finalNGTorque", finalNGTorque)

    -- Damage calculations

    if combustionExitTemp > self.damageTurbineOvertempStart then
        -- Accumulate damage potential
        self.state.damageAccumulatorTurbine = math.min(
            self.state.damageAccumulatorTurbine + dt,
            self.damageAccumulatorMaxTime
        )

        -- Calculate damage with exponential ramp-up
        local damageMultiplier = (1 - math.exp(-self.state.damageAccumulatorTurbine * self.damageAccumulatorRampRate))
        local damageAmount = self.damageTurbineOvertempK *
                            (combustionExitTemp - self.damageTurbineOvertempStart) *
                            dt *
                            damageMultiplier

        self.state.damageTurbineBlades = math.clamp(
            self.state.damageTurbineBlades + damageAmount,
            0, 1
        )
    else
        -- Reset accumulator and allow damage recovery
        self.state.damageAccumulatorTurbine = math.max(0, self.state.damageAccumulatorTurbine - dt * self.damageAccumulatorDecayRate)
        self.state.damageTurbineBlades = math.clamp(
            self.state.damageTurbineBlades - self.damageTurbineOvertempRecoveryK * dt,
            0, 1
        )
    end

    if (self.gasTurbine.angularSpeed * 60 / (2 * math.pi)) > self.damageCompressorOverspeedStart then
        self.state.damageCompressorBlades = math.clamp(self.state.damageCompressorBlades + self.damageCompressorOverspeedK * ((self.gasTurbine.angularSpeed * 60 / (2 * math.pi)) - self.damageCompressorOverspeedStart) * dt, 0, 1)
    else
        self.state.damageCompressorBlades = math.clamp(self.state.damageCompressorBlades - self.damageCompressorOverspeedRecoveryK * dt, 0, 1)
    end

    -- Damage notification
    self.state.warnings = {}  -- Clear previous warnings
    self.state.cautions = {}  -- Clear previous cautions

    -- Update overtemp timer
    if combustionExitTemp > self.damageTurbineOvertempStart then
        self.state.overtempTimer = self.state.overtempTimer + dt
    else
        self.state.overtempTimer = 0
    end

    -- Check for caution conditions
    if (self.gasTurbine.angularSpeed * 60 / (2 * math.pi)) > self.damageCompressorOverspeedStart then
        table.insert(self.state.cautions, "OVERSPEED")
    end
    if combustionExitTemp > self.damageTurbineOvertempStart and self.state.overtempTimer >= 1.0 then
        table.insert(self.state.cautions, "OVERTEMP")
    end

    -- Check for warning conditions
    if self.state.damageTurbineBlades > 0.2 then
        table.insert(self.state.warnings, "TURBINE DAMAGE")
    end
    if self.state.damageCompressorBlades > 0.2 then
        table.insert(self.state.warnings, "COMPRESSOR DAMAGE")
    end

    return (self.state.damageTurbineBlades * 0.5) + (self.state.damageCompressorBlades * 0.5)
end


function Turboshaft:reset()
    self.gasTurbine.angularSpeed = config.turboshaft.designMaxNGRPM * math.pi / 60
    self.state.combustionActive = true
    self.state.flameoutTimer = 0
    self.state.tit = self.ambientTemp
    self.fuelSystem.actualFuelFlow = 0
    self.fuelSystem.commandedFuelFlow = 0
    self.state.damageCompressorBlades = 0
    self.state.damageTurbineBlades = 0
end


return Turboshaft
