-- T-180 CSP Physics Script - Turbine Thruster Module
-- Authored by ohyeah2389


local state = require('script_state')
local config = require('car_config')
local controls = require('script_controls')
local game = require('script_acConnection')
local helpers = require('script_helpers')
local physics = require('script_physics')
local PIDController = require('script_pid')


local Turbothruster = class("Turbothruster")


function Turbothruster:initialize()
    self.carReversing = false
    self.turbine = physics({
        rotary = true,
        inertia = config.turbothruster.inertia,
        forceMax = 10000,
        frictionCoef = config.turbothruster.frictionCoef,
        staticFrictionCoef = 0
    })
    self.throttlePID = PIDController(
        0.0001, -- kP
        0, -- kI
        0.0001, -- kD
        config.turbothruster.minThrottle, -- minOutput
        1, -- maxOutput
        1 -- dampingFactor
    )
end


function Turbothruster:reset()
    self.carReversing = false
    self.turbine.angularSpeed = 0
    self.throttlePID:reset()
    state.turbine.throttle = 0.0
    state.turbine.thrust = 0.0
    state.turbine.bleedBoost = 0.0
    state.turbine.fuelLevel = config.turbothruster.fuelTankCapacity
    state.turbine.fuelConsumption = 0.0
end


function Turbothruster:update(dt)
    -- Difference in RPM between piston engine and turbine engine
    local rpmDelta = (math.max(game.car_cphys.rpm, 0) - (self.turbine.angularSpeed * 60 / (2 * math.pi))) / config.turbothruster.gearRatio

    -- Determine if car is traveling backwards (but not if it's in the air)
    if helpers.getWheelsOffGround() > 3 then
        self.carReversing = false
    else
        self.carReversing = game.car_cphys.localVelocity.z < 0
    end

    -- Drift angle from velocities
    local driftAngle = math.atan(game.car_cphys.localVelocity.x / math.abs(game.car_cphys.localVelocity.z))

    -- Base throttle request from drift
    local baseThrottle = helpers.mapRange(game.car_cphys.gas * helpers.mapRange(math.abs(driftAngle), math.rad(30), math.rad(90), 0, 1, true), 0, 1, config.turbothruster.minThrottle, 1, true)

    -- Throttle final calculation
    if controls.turbine.throttle:down() then -- Full throttle override
        state.turbine.throttle = math.applyLag(state.turbine.throttle, 1, config.turbothruster.throttleLag, dt)
        if state.turbine.throttle > 0.9 then
            state.turbine.throttleAfterburner = math.applyLag(state.turbine.throttleAfterburner, 1, config.turbothruster.throttleLagAfterburner, dt)
        else
            state.turbine.throttleAfterburner = math.applyLag(state.turbine.throttleAfterburner, 0, config.turbothruster.throttleLagAfterburner, dt)
        end
        self.throttlePID:reset()  -- Reset PID when override is active
    elseif state.control.spinMode then -- Zero throttle override for spin mode
        state.turbine.throttle = math.applyLag(state.turbine.throttle, 0, config.turbothruster.throttleLag, dt)
        state.turbine.throttleAfterburner = math.applyLag(state.turbine.throttleAfterburner, 0, config.turbothruster.throttleLagAfterburner, dt)
        self.throttlePID:reset()  -- Reset PID when override is active
    else
        state.turbine.throttleAfterburner = math.applyLag(state.turbine.throttleAfterburner, 0, config.turbothruster.throttleLagAfterburner, dt)
        local pidOutput = state.turbine.clutchDisconnected and 0 or self.throttlePID:update(0, rpmDelta, dt)
        local correctedThrottle = math.clamp(baseThrottle * (1 + pidOutput), config.turbothruster.minThrottle, 1)
        state.turbine.throttle = math.applyLag(state.turbine.throttle, correctedThrottle, config.turbothruster.throttleLag, dt)
    end

    -- Turbine thrust with fadeout based on intake speed (is that realistic?)
    state.turbine.thrust = self.turbine.angularSpeed * 4 * state.turbine.throttle * (helpers.mapRange(car.speedKmh, 0, config.turbothruster.maximumEffectiveIntakeSpeed, 1, 0, true) ^ config.turbothruster.thrustFadeoutExponent)
    ac.addForce(vec3(0.0, 0.77, -2), true, vec3(0, 0, state.turbine.thrust), true)

    -- Turbine afterburner extra thrust
    ac.addForce(vec3(0.0, 0.77, -2), true, vec3(0, 0, helpers.mapRange(state.turbine.throttleAfterburner, 0, 1, 0, 2500, true)), true)

    -- Bleed pressure from turbine engine
    state.turbine.bleedBoost = state.turbine.thrust * config.turbothruster.boostThrustFactor + self.turbine.angularSpeed * config.turbothruster.boostSpeedFactor
    ac.overrideTurboBoost(0, state.turbine.bleedBoost, state.turbine.bleedBoost)

    -- Torque transfers between piston engine and turbine engine
    local turbineTorqueFromEngine = rpmDelta * 0.1
    local engineTorqueFromTurbine = rpmDelta * config.turbothruster.gearRatio * 0.0001
    ac.setExtraTorque(state.turbine.clutchDisconnected and 0 or engineTorqueFromTurbine) -- Engine torque from turbine
    self.turbine:step((state.turbine.clutchDisconnected and 0 or turbineTorqueFromEngine) + (state.turbine.fuelPumpEnabled and 10 * state.turbine.thrust * (helpers.mapRange(self.turbine.angularSpeed, 0, 2000, 0.1, 0, true) ^ 0.8) or 0), dt) -- Turbine torque from engine plus turbine internally generated torque

    -- Clamp the turbine speed to a minimum of 0 RPM to prevent reversing weirdness
    if self.turbine.angularSpeed < 0 then
        self.turbine.angularSpeed = 0
    end

    -- Calculate fuel consumption based on throttle, RPM and thrust
    state.turbine.fuelConsumption = (state.turbine.throttle * config.turbothruster.fuelConsThrottleFactor) -- Throttle factor
        * (self.turbine.angularSpeed * config.turbothruster.fuelConsSpeedFactor) -- RPM factor
        * (state.turbine.thrust * config.turbothruster.fuelConsThrustFactor) -- Thrust factor
        * dt -- Time factor


    -- Take the fuel out of the turbine fuel tank
    state.turbine.fuelLevel = state.turbine.fuelLevel - state.turbine.fuelConsumption

    -- Update turbine RPM status for readouts and sync and stuff
    state.turbine.rpm = self.turbine.angularSpeed * 60 / (2 * math.pi)

    -- Debug outputs
    ac.debug("state.turbothruster.throttle", state.turbine.throttle)
    ac.debug("state.turbothruster.throttleAfterburner", state.turbine.throttleAfterburner)
    ac.debug("state.turbothruster.thrust", state.turbine.thrust)
    ac.debug("state.turbothruster.clutchDisconnected", state.turbine.clutchDisconnected)
    ac.debug("state.turbothruster.bleedBoost", state.turbine.bleedBoost)
    ac.debug("turbothruster.torque", self.turbine.torque)
    ac.debug("turbothruster.angularSpeed", self.turbine.angularSpeed)
    ac.debug("turbothruster.RPM", self.turbine.angularSpeed * 60 / (2 * math.pi))
    ac.debug("turbothruster.rpmDelta", rpmDelta)
    ac.debug("state.turbothruster.fuelConsumption", state.turbine.fuelConsumption)
    ac.debug("state.turbothruster.fuelLevel", state.turbine.fuelLevel)
    ac.debug("state.turbothruster.fuelPumpEnabled", state.turbine.fuelPumpEnabled)
    ac.debug("baseThrottle", baseThrottle)
end


return Turbothruster