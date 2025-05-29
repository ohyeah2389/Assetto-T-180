-- T-180 CSP Physics Script - Performance Tracker Module
-- Authored by ohyeah2389

local state = require('script_state')
local config = require('car_config')
local helpers = require('script_helpers')


local perfTracker = class("perfTracker")

function perfTracker:initialize()
    self.perfData = {}
end

function perfTracker:reset()
    self.perfData = {}
end

function perfTracker:update(dt)
    local car = ac.getCar(0)
    local carPhysics = ac.accessCarPhysics()

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
        if config.turbojet.type == "single" then
            totalThrustForce = state.turbine.thrust or 0
            -- Afterburner calculation for turbojet (matches script_turbojet.lua logic)
            local afterburnerThrust = helpers.mapRange(state.turbine.throttleAfterburner or 0, 0, 1, 0, 2500, true) *
                (state.turbine.fuelPumpEnabled and 1 or 0)
            totalAfterburnerForce = afterburnerThrust

            ac.debug("perfTracker_turbojet_single_force", totalThrustForce)
            ac.debug("perfTracker_turbojet_single_afterburner", afterburnerThrust)
        elseif config.turbojet.type == "dual" then
            local leftThrust = state.turbine.left.thrust or 0
            local rightThrust = state.turbine.right.thrust or 0
            totalThrustForce = leftThrust + rightThrust

            -- Afterburner for dual turbojets
            local leftAfterburner = helpers.mapRange(state.turbine.left.throttleAfterburner or 0, 0, 1, 0, 2500, true) *
                (state.turbine.left.fuelPumpEnabled and 1 or 0)
            local rightAfterburner = helpers.mapRange(state.turbine.right.throttleAfterburner or 0, 0, 1, 0, 2500, true) *
                (state.turbine.right.fuelPumpEnabled and 1 or 0)
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
        
        totalWheelForce = wheelForces.frontLeft + wheelForces.frontRight + 
                         wheelForces.rearLeft + wheelForces.rearRight
        
        ac.debug("perfTracker_turbojet_wheel_force_FL", wheelForces.frontLeft)
        ac.debug("perfTracker_turbojet_wheel_force_FR", wheelForces.frontRight)
        ac.debug("perfTracker_turbojet_wheel_force_RL", wheelForces.rearLeft)
        ac.debug("perfTracker_turbojet_wheel_force_RR", wheelForces.rearRight)
        ac.debug("perfTracker_turbojet_total_wheel_force", totalWheelForce)
        ac.debug("perfTracker_turbojet_force_source", "cphys_fx")
    end

    -- Calculate torque forces from turboshafts (convert torque to force)
    if config.turboshaft.present then
        if config.turboshaft.type == "dual" then
            -- Dual turboshaft system with separate front/rear
            local frontTorque = state.turbine.front.outputTorque or 0
            local rearTorque = state.turbine.rear.outputTorque or 0

            local frontForce = frontTorque / wheelRadius
            local rearForce = rearTorque / wheelRadius

            -- Distribute forces to individual wheels (assuming even distribution)
            wheelForces.frontLeft = frontForce / 2
            wheelForces.frontRight = frontForce / 2
            wheelForces.rearLeft = rearForce / 2
            wheelForces.rearRight = rearForce / 2

            totalWheelForce = frontForce + rearForce

            -- Read afterburner thrust directly from state (calculated by turboshaft module)
            local frontAfterburner = state.turbine.front.afterburnerThrust or 0
            local rearAfterburner = state.turbine.rear.afterburnerThrust or 0
            totalAfterburnerForce = frontAfterburner + rearAfterburner

            ac.debug("perfTracker_turboshaft_front_torque", frontTorque)
            ac.debug("perfTracker_turboshaft_rear_torque", rearTorque)
            ac.debug("perfTracker_turboshaft_front_force", frontForce)
            ac.debug("perfTracker_turboshaft_rear_force", rearForce)
            ac.debug("perfTracker_turboshaft_front_afterburner", frontAfterburner)
            ac.debug("perfTracker_turboshaft_rear_afterburner", rearAfterburner)
            ac.debug("perfTracker_turboshaft_total_afterburner", totalAfterburnerForce)
        else
            -- Single turboshaft system
            local totalTorque = state.turbine.outputTorque or 0
            totalWheelForce = totalTorque / wheelRadius

            -- Distribute to all four wheels equally (AWD)
            local forcePerWheel = totalWheelForce / 4
            wheelForces.frontLeft = forcePerWheel
            wheelForces.frontRight = forcePerWheel
            wheelForces.rearLeft = forcePerWheel
            wheelForces.rearRight = forcePerWheel

            -- Read afterburner thrust directly from state (calculated by turboshaft module)
            totalAfterburnerForce = state.turbine.afterburnerThrust or 0

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
end

return perfTracker
