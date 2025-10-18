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
        inertia = config.turboshaft.inertiaNG or 0.5,
        forceMax = 10000,
        frictionCoef = 0.006,
        staticFrictionCoef = 1.2,
        expFrictionCoef = 1.4
    })

    -- Initial turbine speed
    self.gasTurbine.angularSpeed = config.turboshaft.designMaxNGRPM * math.pi / 60

    -- Ambient conditions
    self.ambientPressure = ac.getAirPressure(game.car_cphys.position) -- kPa at sea level
    self.ambientTemp = 273.15 + game.car_cphys.ambientTemperature
    self.massFlowAirCoefficient = 1.5                                 -- kg/s

    -- Thermodynamic properties
    self.specificHeatCapacity = 1005 -- J/kg·K
    self.specificHeatRatio = 1.4
    self.stoichiometricFAR = 1 / 14.7
    self.targetFAR = 0.02
    self.combustorPressureLoss = 0.03
    self.TITLag = 1.0

    -- Damage constants
    self.damageTurbineOvertempK = 0.0
    self.damageTurbineOvertempStart = 1500
    self.damageTurbineOvertempRecoveryK = 0.05
    self.damageCompressorOverspeedK = 0.0
    self.damageCompressorOverspeedStart = 40000
    self.damageCompressorOverspeedRecoveryK = 0.05
    self.damageAccumulatorMaxTime = 5.0   -- Maximum accumulation time in seconds
    self.damageAccumulatorRampRate = 0.5  -- Higher = faster ramp up of damage
    self.damageAccumulatorDecayRate = 5.0 -- How fast accumulator decays when temp is normal

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
    self.flameoutDelay = 4.0             -- seconds of low fuel before flameout occurs
    self.minimumStableFuelFlow = 0.00001 -- minimum fuel flow for stable combustion

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
        commandedFuelFlow = 0.1, -- kg/s, fuel flow commanded by FADEC
        actualFuelFlow = 0.1,    -- kg/s, actual fuel flow after lag
        timeConstant = 0.15      -- seconds, fuel system response time
    }

    -- Afterburner system
    self.afterburner = {
        throttleAfterburner = 0.0,
        enabled = false
    }

    -- Turbine efficiency
    self.turbineEfficiency = config.turboshaft.totalTurbineEfficiency or 0.85

    -- Exhaust thrust parameters
    self.exhaustThrust = {
        lastThrust = 0,
        exhaustVelocity = 0,
        exhaustPressure = 0,
        exhaustTemp = 0
    }
end

function Turboshaft:update(dt)
    -- Get control inputs
    local controls = {
        throttle = state.turbine[self.turbineId].throttle,
    }

    -- Update and get FADEC-commanded fuel flow
    self.fuelSystem.commandedFuelFlow = state.turbine[self.turbineId].fuelPumpEnabled and self.fadec:update(dt, self.sensors, controls, self.maxNG, self.maxTIT) or 0

    -- Afterburner control logic
    local throttleLevel = car.extraB and 1 or (1 - game.car_cphys.clutch) * (car.isInPit and 0 or 1)
    self.afterburner.throttleAfterburner = math.applyLag(
        self.afterburner.throttleAfterburner,
        throttleLevel,
        config.turboshaft.throttleLagAfterburner or 0.5,
        dt
    )

    -- Apply fuel system lag
    local fuelFlowDelta = self.fuelSystem.commandedFuelFlow - self.fuelSystem.actualFuelFlow
    self.fuelSystem.actualFuelFlow = self.fuelSystem.actualFuelFlow + (fuelFlowDelta * dt / self.fuelSystem.timeConstant)

    -- Calculate ram air effects at inlet
    local speedOfSound = math.sqrt(self.specificHeatRatio * 287 * self.ambientTemp) -- m/s, R=287 J/(kg·K) for air
    local machNumber = game.car_cphys.localVelocity:length() / speedOfSound

    -- Inlet pressure recovery (simple inlet model with transonic effects)
    -- Subsonic: near-perfect recovery, Transonic: shock losses, Supersonic: normal shock losses
    local inletPressureRecovery = 1.0
    if machNumber < 1.0 then
        -- Subsonic: minimal losses
        inletPressureRecovery = 1.0 - 0.01 * machNumber -- ~1% loss at M=1.0
    else
        -- Supersonic: normal shock losses increase with Mach number
        -- Simplified normal shock relation
        local machSquared = machNumber * machNumber
        inletPressureRecovery = math.pow(
            ((self.specificHeatRatio + 1) * machSquared) / (2 + (self.specificHeatRatio - 1) * machSquared),
            self.specificHeatRatio / (self.specificHeatRatio - 1)
        ) * math.pow(
            (self.specificHeatRatio + 1) / (2 * self.specificHeatRatio * machSquared - (self.specificHeatRatio - 1)),
            1 / (self.specificHeatRatio - 1)
        )
    end

    -- Calculate total (stagnation) pressure and temperature at inlet
    local ramPressureRatio = math.pow(
        1 + ((self.specificHeatRatio - 1) / 2) * machNumber * machNumber,
        self.specificHeatRatio / (self.specificHeatRatio - 1)
    )
    local inletPressure = self.ambientPressure * ramPressureRatio * inletPressureRecovery

    -- Ram temperature rise (total temperature)
    local inletTemp = self.ambientTemp * (1 + ((self.specificHeatRatio - 1) / 2) * machNumber * machNumber)

    -- Calculate speed and pressure ratios
    self.speedRatio = (self.gasTurbine.angularSpeed * 60 / (2 * math.pi)) / config.turboshaft.designMaxNGRPM
    self.state.pressureRatio = 1 + config.turboshaft.pressureRatio * (self.speedRatio * self.speedRatio)

    -- Air mass flow (corrected for inlet pressure and temperature)
    -- Corrected flow: actual flow scaled by inlet conditions
    local pressureCorrection = inletPressure / self.ambientPressure
    local tempCorrection = math.sqrt(self.ambientTemp / inletTemp)
    self.state.massFlowAir = self.speedRatio * self.massFlowAirCoefficient * self.damageCompressorDerateCurve:get(self.state.damageCompressorBlades) * pressureCorrection * tempCorrection

    -- Calculate compressor discharge temperature using "isentropic relation", whatever that means
    local compressorDischargeTemp = inletTemp * (self.state.pressureRatio ^ ((self.specificHeatRatio - 1) / self.specificHeatRatio))

    -- Compressor torque calculations
    local powerRequired = self.state.massFlowAir * self.specificHeatCapacity * (compressorDischargeTemp - inletTemp) / config.turboshaft.compressorEfficiency
    local compressorTorque = -powerRequired / math.max(self.gasTurbine.angularSpeed, 1) / self.damageCompressorDerateCurve:get(self.state.damageCompressorBlades)

    -- Combustion calculations
    local fuelAirRatio = self.fuelSystem.actualFuelFlow / math.max(self.state.massFlowAir, 0.001)
    local combustionHeatAdded = self.fuelSystem.actualFuelFlow * config.turboshaft.fuelLHV * config.turboshaft.combustionEfficiency
    local totalMassFlow = self.state.massFlowAir + self.fuelSystem.actualFuelFlow
    local combustionExitTemp = compressorDischargeTemp + (combustionHeatAdded / math.max(totalMassFlow, 0.001)) / self.specificHeatCapacity
    local combustionExitPressure = inletPressure * self.state.pressureRatio * (1 - self.combustorPressureLoss)

    -- Implement "thermal mass" for TIT using lag
    self.state.tit = self.state.tit + dt * (combustionExitTemp - self.state.tit) / self.TITLag

    -- Update sensor readings
    self.sensors.ngRPM = self.gasTurbine.angularSpeed * 60 / (2 * math.pi)
    self.sensors.turbineInletTemp = self.state.tit
    self.sensors.compressorDischargePressure = combustionExitPressure / (1 - self.combustorPressureLoss)
    self.sensors.fuelFlow = self.fuelSystem.actualFuelFlow

    -- Turbine torque calculations
    local deltaTemp = combustionExitTemp - compressorDischargeTemp
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
    ac.debug("turboshaft." .. self.turbineId .. ".machNumber", machNumber)
    ac.debug("turboshaft." .. self.turbineId .. ".inletPressure", inletPressure)
    ac.debug("turboshaft." .. self.turbineId .. ".inletTemp", inletTemp)
    ac.debug("turboshaft." .. self.turbineId .. ".inletPressureRecovery", inletPressureRecovery)
    ac.debug("turboshaft." .. self.turbineId .. ".ramPressureRatio", ramPressureRatio)

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
        self.state.damageAccumulatorTurbine = math.max(0,
            self.state.damageAccumulatorTurbine - dt * self.damageAccumulatorDecayRate)
        self.state.damageTurbineBlades = math.clamp(
            self.state.damageTurbineBlades - self.damageTurbineOvertempRecoveryK * dt,
            0, 1
        )
    end

    if (self.gasTurbine.angularSpeed * 60 / (2 * math.pi)) > self.damageCompressorOverspeedStart then
        self.state.damageCompressorBlades = math.clamp(
            self.state.damageCompressorBlades +
            self.damageCompressorOverspeedK *
            ((self.gasTurbine.angularSpeed * 60 / (2 * math.pi)) - self.damageCompressorOverspeedStart) * dt, 0, 1)
    else
        self.state.damageCompressorBlades = math.clamp(
            self.state.damageCompressorBlades - self.damageCompressorOverspeedRecoveryK * dt, 0, 1)
    end

    -- Damage notification
    self.state.warnings = {} -- Clear previous warnings
    self.state.cautions = {} -- Clear previous cautions

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

    -- Calculate exhaust conditions and thrust
    local exhaustTemp = combustionExitTemp * (1 - self.turbineEfficiency)         -- Temperature after turbine
    local exhaustPressure = combustionExitPressure * (1 - self.turbineEfficiency) -- Pressure after turbine

    -- Debug intermediate values
    ac.debug("turboshaft." .. self.turbineId .. ".debug.exhaustTemp", exhaustTemp)
    ac.debug("turboshaft." .. self.turbineId .. ".debug.exhaustPressure", exhaustPressure)
    ac.debug("turboshaft." .. self.turbineId .. ".debug.ambientPressure", self.ambientPressure)
    ac.debug("turboshaft." .. self.turbineId .. ".debug.totalMassFlow", totalMassFlow)

    -- Calculate exhaust velocity using isentropic flow equations
    local pressureRatio = exhaustPressure / self.ambientPressure
    local velocityTerm = 1 - math.pow(pressureRatio, (self.specificHeatRatio - 1) / self.specificHeatRatio)

    ac.debug("turboshaft." .. self.turbineId .. ".debug.pressureRatio", pressureRatio)
    ac.debug("turboshaft." .. self.turbineId .. ".debug.velocityTerm", velocityTerm)

    -- Add safety check for velocity term
    if velocityTerm < 0 then
        ac.debug("turboshaft." .. self.turbineId .. ".debug.velocityTermError", "Negative velocity term")
        velocityTerm = 0
    end

    local exhaustVelocity = math.sqrt(2 * self.specificHeatCapacity * exhaustTemp * velocityTerm)
    ac.debug("turboshaft." .. self.turbineId .. ".debug.exhaustVelocity", exhaustVelocity)

    -- Calculate thrust using momentum equation
    local exhaustThrust = totalMassFlow * exhaustVelocity * config.turboshaft.exhaustThrust.nozzleEfficiency
    ac.debug("turboshaft." .. self.turbineId .. ".debug.exhaustThrust", exhaustThrust)

    -- Add pressure thrust component
    local pressureThrust = (exhaustPressure - self.ambientPressure) * config.turboshaft.exhaustThrust.nozzleArea
    ac.debug("turboshaft." .. self.turbineId .. ".debug.pressureThrust", pressureThrust)

    local totalThrust = exhaustThrust + pressureThrust
    ac.debug("turboshaft." .. self.turbineId .. ".debug.totalThrust", totalThrust)

    -- Safety checks for thrust calculation
    if not (totalThrust and totalThrust == totalThrust) then -- Check for NaN
        ac.debug("turboshaft." .. self.turbineId .. ".thrustError", "Invalid thrust value")
        ac.debug("turboshaft." .. self.turbineId .. ".error.exhaustThrust", exhaustThrust)
        ac.debug("turboshaft." .. self.turbineId .. ".error.pressureThrust", pressureThrust)
        totalThrust = 0
    end

    -- Clamp thrust to reasonable values
    totalThrust = math.clamp(totalThrust, -10000, 10000)

    -- Apply thrust force to vehicle
    local thrustVector = vec3(
        0,
        0,
        math.cos(math.rad(config.turboshaft.exhaustThrust.exhaustAngle))
    ) * totalThrust

    -- Add side thrust component if angle is non-zero
    if config.turboshaft.exhaustThrust.exhaustAngle ~= 0 then
        thrustVector.x = math.sin(math.rad(config.turboshaft.exhaustThrust.exhaustAngle)) * totalThrust
    end

    -- Safety check for thrust vector
    if not (thrustVector.x == thrustVector.x and
            thrustVector.y == thrustVector.y and
            thrustVector.z == thrustVector.z) then
        ac.debug("turboshaft." .. self.turbineId .. ".vectorError", "Invalid thrust vector")
        thrustVector = vec3(0, 0, 0)
    end

    -- Safety check for application point
    local applicationPoint = config.turboshaft.exhaustThrust.thrustApplicationPoint
    if not (applicationPoint and
            applicationPoint.x == applicationPoint.x and
            applicationPoint.y == applicationPoint.y and
            applicationPoint.z == applicationPoint.z) then
        ac.debug("turboshaft." .. self.turbineId .. ".pointError", "Invalid application point")
        applicationPoint = vec3(0, 0, 0)
    end

    -- Only apply force if all values are valid
    if totalThrust ~= 0 then
        ac.addForce(
            applicationPoint,
            true, -- position is local
            thrustVector,
            true  -- force is local
        )
    end

    -- Apply afterburner thrust
    local afterburnerThrust = self.afterburner.throttleAfterburner *
        (config.turboshaft.afterburnerMaxThrust or 2500) *
        (state.turbine[self.turbineId].fuelPumpEnabled and 1 or 0)

    -- Store afterburner thrust in state for performance tracking
    state.turbine[self.turbineId].afterburnerThrust = afterburnerThrust

    if afterburnerThrust > 0 then
        local afterburnerVector = vec3(
            0,
            0,
            math.cos(math.rad(config.turboshaft.exhaustThrust.exhaustAngle or 0))
        ) * afterburnerThrust

        -- Add side thrust component if angle is non-zero
        if (config.turboshaft.exhaustThrust.exhaustAngle or 0) ~= 0 then
            afterburnerVector.x = math.sin(math.rad(config.turboshaft.exhaustThrust.exhaustAngle)) * afterburnerThrust
        end

        ac.addForce(
            applicationPoint,
            true, -- position is local
            afterburnerVector,
            true  -- force is local
        )
    end

    -- Store exhaust conditions for debugging
    self.exhaustThrust.lastThrust = totalThrust
    self.exhaustThrust.exhaustVelocity = exhaustVelocity
    self.exhaustThrust.exhaustPressure = exhaustPressure
    self.exhaustThrust.exhaustTemp = exhaustTemp

    -- Add debug outputs
    ac.debug("turboshaft." .. self.turbineId .. ".afterburnerThrottle", self.afterburner.throttleAfterburner)
    ac.debug("turboshaft." .. self.turbineId .. ".afterburnerThrust", afterburnerThrust)
    ac.debug("turboshaft." .. self.turbineId .. ".exhaustThrust", totalThrust)
    ac.debug("turboshaft." .. self.turbineId .. ".exhaustVelocity", exhaustVelocity)
    ac.debug("turboshaft." .. self.turbineId .. ".exhaustPressure", exhaustPressure)
    ac.debug("turboshaft." .. self.turbineId .. ".exhaustTemp", exhaustTemp)
    ac.debug("turboshaft." .. self.turbineId .. ".thrustVector", thrustVector)
    ac.debug("turboshaft." .. self.turbineId .. ".applicationPoint", applicationPoint)

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
    self.afterburner.throttleAfterburner = 0.0
end

return Turboshaft
