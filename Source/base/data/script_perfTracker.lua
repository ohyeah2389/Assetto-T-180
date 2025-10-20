-- T-180 CSP Physics Script - Performance Tracker Module
-- Authored by ohyeah2389
--
-- This module tracks performance data during laps and outputs it to the log.
-- Data is recorded at 2 Hz (every 0.5 seconds) during each lap.
-- At lap completion, all data is printed to the log in CSV format.

local config = require('car_config')
local helpers = require('script_helpers')


local perfTracker = class("perfTracker")

function perfTracker:initialize(turbineInstances)
    self.perfData = {}
    self.lapData = {}
    self.recordTimer = 0
    self.recordInterval = 0.5 -- 2 Hz = 0.5 second interval
    self.currentLap = 0
    self.lastLapCount = 0

    -- Store references to turbine instances
    self.turbines = turbineInstances or {}
end

function perfTracker:reset()
    self.perfData = {}
    -- Don't reset lap data on reset, only on lap completion
end

function perfTracker:saveLapDataToCSV()
    if #self.lapData == 0 then
        return
    end

    -- Create CSV header
    local header = "Time,Speed_KMH,Speed_MPH,ThrustForce_N,AfterburnerForce_N,WheelForce_N,TotalForce_N," ..
        "PotentialAccel_MS2,PotentialAccel_G,WheelForce_FL,WheelForce_FR,WheelForce_RL,WheelForce_RR," ..
        "Mass_KG,PosX,PosY,PosZ"

    -- Build CSV content
    local csvContent = header .. "\n"
    for _, dataPoint in ipairs(self.lapData) do
        csvContent = csvContent .. string.format(
            "%.3f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.3f,%.3f,%.2f,%.2f,%.2f,%.2f,%.2f,%.3f,%.3f,%.3f\n",
            dataPoint.time,
            dataPoint.speedKmh,
            dataPoint.speedMph,
            dataPoint.thrustForce,
            dataPoint.afterburnerForce,
            dataPoint.wheelForce,
            dataPoint.totalForce,
            dataPoint.potentialAcceleration,
            dataPoint.potentialAccelerationG,
            dataPoint.wheelForceFrontLeft,
            dataPoint.wheelForceFrontRight,
            dataPoint.wheelForceRearLeft,
            dataPoint.wheelForceRearRight,
            dataPoint.mass,
            dataPoint.posX,
            dataPoint.posY,
            dataPoint.posZ
        )
    end

    -- Print CSV data to log
    print(csvContent)
end

function perfTracker:recordDataPoint(dt)
    local car = ac.getCar(0)

    -- Record data point
    local dataPoint = {
        time = car.lapTimeMs / 1000.0,      -- Convert to seconds
        speedKmh = car.speedKmh,
        speedMph = car.speedKmh * 0.621371, -- Convert km/h to mph
        thrustForce = self.perfData.thrustForce or 0,
        afterburnerForce = self.perfData.afterburnerForce or 0,
        wheelForce = self.perfData.wheelForce or 0,
        totalForce = self.perfData.totalForce or 0,
        potentialAcceleration = self.perfData.potentialAcceleration or 0,
        potentialAccelerationG = (self.perfData.potentialAcceleration or 0) / 9.81,
        wheelForceFrontLeft = self.perfData.wheelForces.frontLeft or 0,
        wheelForceFrontRight = self.perfData.wheelForces.frontRight or 0,
        wheelForceRearLeft = self.perfData.wheelForces.rearLeft or 0,
        wheelForceRearRight = self.perfData.wheelForces.rearRight or 0,
        mass = car.mass,
        posX = car.position.x,
        posY = car.position.y,
        posZ = car.position.z
    }

    table.insert(self.lapData, dataPoint)
end

function perfTracker:checkLapCompletion()
    local car = ac.getCar(0)
    local currentLapCount = car.lapCount

    -- Detect lap completion
    if currentLapCount > self.lastLapCount and self.lastLapCount > 0 then
        -- Lap completed, save data
        self.currentLap = self.lastLapCount
        self:saveLapDataToCSV()

        -- Clear lap data for new lap
        self.lapData = {}
        self.recordTimer = 0
    end

    self.lastLapCount = currentLapCount
end

function perfTracker:update(dt)
    local car = ac.getCar(0)
    local carPhysics = ac.accessCarPhysics()

    -- Check for lap completion
    self:checkLapCompletion()

    -- Update recording timer
    self.recordTimer = self.recordTimer + dt

    -- Get wheel radius from car state
    local wheelRadius = car.wheels[0].tyreRadius

    -- Calculate individual wheel forces (for debugging)
    local wheelForces = {
        frontLeft = 0,
        frontRight = 0,
        rearLeft = 0,
        rearRight = 0
    }

    local totalWheelForce = 0
    local totalThrustForce = 0
    local totalAfterburnerForce = 0

    -- Calculate thrust forces from turbojets
    if config.turbojet.present then
        if config.turbojet.type == "single" and self.turbines.center then
            totalThrustForce = self.turbines.center.thrust or 0
            -- Afterburner calculation for turbojet (matches script_turbojet.lua logic)
            local afterburnerThrust = helpers.mapRange(self.turbines.center.throttleAfterburner or 0, 0, 1, 0, 2500, true) *
                (self.turbines.center.fuelPumpEnabled and 1 or 0)
            totalAfterburnerForce = afterburnerThrust

            ac.debug("perfTracker_turbojet_single_force", totalThrustForce)
            ac.debug("perfTracker_turbojet_single_afterburner", afterburnerThrust)
        elseif config.turbojet.type == "dual" and self.turbines.left and self.turbines.right then
            local leftThrust = self.turbines.left.thrust or 0
            local rightThrust = self.turbines.right.thrust or 0
            totalThrustForce = leftThrust + rightThrust

            -- Afterburner for dual turbojets
            local leftAfterburner = helpers.mapRange(self.turbines.left.throttleAfterburner or 0, 0, 1, 0, 2500, true) *
                (self.turbines.left.fuelPumpEnabled and 1 or 0)
            local rightAfterburner = helpers.mapRange(self.turbines.right.throttleAfterburner or 0, 0, 1, 0, 2500, true) *
                (self.turbines.right.fuelPumpEnabled and 1 or 0)
            totalAfterburnerForce = leftAfterburner + rightAfterburner

            ac.debug("perfTracker_turbojet_left_force", leftThrust)
            ac.debug("perfTracker_turbojet_right_force", rightThrust)
            ac.debug("perfTracker_turbojet_total_force", totalThrustForce)
            ac.debug("perfTracker_turbojet_left_afterburner", leftAfterburner)
            ac.debug("perfTracker_turbojet_right_afterburner", rightAfterburner)
            ac.debug("perfTracker_turbojet_total_afterburner", totalAfterburnerForce)
        end

        -- For turbojet cars, get wheel forces directly from CPhys
        -- fx is "Force along car tyre" which should be the driving force
        wheelForces.frontLeft = carPhysics.wheels[0].fx * -1
        wheelForces.frontRight = carPhysics.wheels[1].fx * -1
        wheelForces.rearLeft = carPhysics.wheels[2].fx * -1
        wheelForces.rearRight = carPhysics.wheels[3].fx * -1

        totalWheelForce = wheelForces.frontLeft + wheelForces.frontRight + wheelForces.rearLeft + wheelForces.rearRight

        ac.debug("perfTracker_turbojet_wheel_force_FL", wheelForces.frontLeft)
        ac.debug("perfTracker_turbojet_wheel_force_FR", wheelForces.frontRight)
        ac.debug("perfTracker_turbojet_wheel_force_RL", wheelForces.rearLeft)
        ac.debug("perfTracker_turbojet_wheel_force_RR", wheelForces.rearRight)
        ac.debug("perfTracker_turbojet_total_wheel_force", totalWheelForce)
        ac.debug("perfTracker_turbojet_force_source", "cphys_fx")
    end

    -- Calculate torque forces from turboshafts (convert torque to force)
    if config.turboshaft.present then
        if config.turboshaft.type == "dual" and self.turbines.front and self.turbines.rear then
            -- Dual turboshaft system with separate front/rear
            local frontTorque = self.turbines.front.outputTorque or 0
            local rearTorque = self.turbines.rear.outputTorque or 0

            local frontForce = frontTorque / wheelRadius
            local rearForce = rearTorque / wheelRadius

            -- Distribute forces to individual wheels (assuming even distribution)
            wheelForces.frontLeft = frontForce / 2
            wheelForces.frontRight = frontForce / 2
            wheelForces.rearLeft = rearForce / 2
            wheelForces.rearRight = rearForce / 2

            totalWheelForce = frontForce + rearForce

            -- Read afterburner thrust directly from turbine instances
            local frontAfterburner = self.turbines.front.afterburnerThrust or 0
            local rearAfterburner = self.turbines.rear.afterburnerThrust or 0
            totalAfterburnerForce = frontAfterburner + rearAfterburner

            ac.debug("perfTracker_turboshaft_front_torque", frontTorque)
            ac.debug("perfTracker_turboshaft_rear_torque", rearTorque)
            ac.debug("perfTracker_turboshaft_front_force", frontForce)
            ac.debug("perfTracker_turboshaft_rear_force", rearForce)
            ac.debug("perfTracker_turboshaft_front_afterburner", frontAfterburner)
            ac.debug("perfTracker_turboshaft_rear_afterburner", rearAfterburner)
            ac.debug("perfTracker_turboshaft_total_afterburner", totalAfterburnerForce)
        elseif self.turbines.front then
            -- Single turboshaft system
            local totalTorque = self.turbines.front.outputTorque or 0
            totalWheelForce = totalTorque / wheelRadius

            -- Distribute to all four wheels equally (AWD)
            local forcePerWheel = totalWheelForce / 4
            wheelForces.frontLeft = forcePerWheel
            wheelForces.frontRight = forcePerWheel
            wheelForces.rearLeft = forcePerWheel
            wheelForces.rearRight = forcePerWheel

            -- Read afterburner thrust directly from turbine instance
            totalAfterburnerForce = self.turbines.front.afterburnerThrust or 0

            ac.debug("perfTracker_turboshaft_total_torque", totalTorque)
            ac.debug("perfTracker_turboshaft_total_force", totalWheelForce)
            ac.debug("perfTracker_turboshaft_single_afterburner", totalAfterburnerForce)
        end
    end

    -- Calculate total force from all sources
    local totalForce = totalThrustForce + totalWheelForce + totalAfterburnerForce

    -- Debug output for individual wheels
    ac.debug("perfTracker_wheel_force_FL", wheelForces.frontLeft)
    ac.debug("perfTracker_wheel_force_FR", wheelForces.frontRight)
    ac.debug("perfTracker_wheel_force_RL", wheelForces.rearLeft)
    ac.debug("perfTracker_wheel_force_RR", wheelForces.rearRight)

    -- Debug output for system totals
    ac.debug("perfTracker_total_thrust_force", totalThrustForce)
    ac.debug("perfTracker_total_afterburner_force", totalAfterburnerForce)
    ac.debug("perfTracker_total_wheel_force", totalWheelForce)
    ac.debug("perfTracker_total_force_all", totalForce)

    -- Calculate potential acceleration (velocity-independent performance metric)
    local vehicleMass = car.mass
    local potentialAcceleration = totalForce / vehicleMass
    local potentialAccelerationG = potentialAcceleration / 9.81 -- Convert to g-force for comparison
    ac.debug("perfTracker_potential_acceleration", potentialAcceleration)
    ac.debug("perfTracker_potential_acceleration_g", potentialAccelerationG)

    -- Debug wheel radius and mass for verification
    ac.debug("perfTracker_wheel_radius", wheelRadius)
    ac.debug("perfTracker_vehicle_mass", vehicleMass)

    -- Additional debug to check if we're missing forces
    ac.debug("perfTracker_debug_expected_3g_force", vehicleMass * 29.4) -- What force would give 3g

    -- Store for other uses
    self.perfData = {
        thrustForce = totalThrustForce,
        afterburnerForce = totalAfterburnerForce,
        wheelForce = totalWheelForce,
        totalForce = totalForce,
        potentialAcceleration = potentialAcceleration,
        wheelForces = wheelForces
    }

    -- Record data at 2 Hz if we're in a lap and recording is requested
    if self.recordTimer >= self.recordInterval and car.lapCount > 0 and car.extraC then
        self:recordDataPoint(dt)
        self.recordTimer = 0
        ac.debug("perfTracker_recording", "Recording data point #" .. #self.lapData)
    end

    -- Debug output for recording status
    ac.debug("perfTracker_lap_count", car.lapCount)
    ac.debug("perfTracker_data_points", #self.lapData)
end

return perfTracker
