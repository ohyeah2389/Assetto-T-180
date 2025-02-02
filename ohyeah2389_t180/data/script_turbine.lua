-- T-180 CSP Physics Script - Turbine Thruster Module
-- Authored by ohyeah2389


local state = require('script_state')
local config = require('car_config')
local controls = require('script_controls')
local game = require('script_acConnection')
local helpers = require('script_helpers')
local physics = require('script_physics')
local PIDController = require('script_pid')


local Turbine = class("Turbine")


function Turbine:initialize()
    self.carReversing = false
    self.turbine = physics({
        rotary = true,
        inertia = config.turbine.inertia,
        forceMax = 10000,
        frictionCoef = config.turbine.frictionCoef,
        staticFrictionCoef = 0
    })
    self.throttlePID = PIDController(
        0.0001, -- kP
        0, -- kI
        0.0001, -- kD
        config.turbine.minThrottle, -- minOutput
        1, -- maxOutput
        1 -- dampingFactor
    )
end


function Turbine:reset()
    self.carReversing = false
    self.turbine.angularSpeed = 0
    self.throttlePID:reset()
    state.turbine.throttle = 0.0
    state.turbine.thrust = 0.0
    state.turbine.bleedBoost = 0.0
    state.turbine.fuelLevel = config.turbine.fuelTankCapacity
    state.turbine.fuelConsumption = 0.0
end


function Turbine:update(dt)
    -- Difference in RPM between piston engine and turbine engine
    local rpmDelta = (math.max(game.car_cphys.rpm, 0) - (self.turbine.angularSpeed * 60 / (2 * math.pi))) / config.turbine.gearRatio

    -- Determine if car is traveling backwards (but not if it's in the air)
    if helpers.getWheelsOffGround() > 3 then
        self.carReversing = false
    else
        self.carReversing = game.car_cphys.localVelocity.z < 0
    end

    -- Drift angle from velocities
    local driftAngle = math.atan(game.car_cphys.localVelocity.x / math.abs(game.car_cphys.localVelocity.z))

    -- Base throttle request from drift
    local baseThrottle = helpers.mapRange(game.car_cphys.gas * helpers.mapRange(math.abs(driftAngle), math.rad(30), math.rad(90), 0, 1, true), 0, 1, config.turbine.minThrottle, 1, true)

    -- Throttle final calculation
    if controls.turbine.throttle:down() then -- Full throttle override
        state.turbine.throttle = math.applyLag(state.turbine.throttle, 1, config.turbine.throttleLag, dt)
        if state.turbine.throttle > 0.9 then
            state.turbine.throttleAfterburner = math.applyLag(state.turbine.throttleAfterburner, 1, config.turbine.throttleLagAfterburner, dt)
        else
            state.turbine.throttleAfterburner = math.applyLag(state.turbine.throttleAfterburner, 0, config.turbine.throttleLagAfterburner, dt)
        end
        self.throttlePID:reset()  -- Reset PID when override is active
    elseif state.control.spinMode then -- Zero throttle override for spin mode
        state.turbine.throttle = math.applyLag(state.turbine.throttle, 0, config.turbine.throttleLag, dt)
        state.turbine.throttleAfterburner = math.applyLag(state.turbine.throttleAfterburner, 0, config.turbine.throttleLagAfterburner, dt)
        self.throttlePID:reset()  -- Reset PID when override is active
    else
        state.turbine.throttleAfterburner = math.applyLag(state.turbine.throttleAfterburner, 0, config.turbine.throttleLagAfterburner, dt)
        local pidOutput = state.turbine.clutchDisconnected and 0 or self.throttlePID:update(0, rpmDelta, dt)
        local correctedThrottle = math.clamp(baseThrottle * (1 + pidOutput), config.turbine.minThrottle, 1)
        state.turbine.throttle = math.applyLag(state.turbine.throttle, correctedThrottle, config.turbine.throttleLag, dt)
    end

    -- Turbine thrust with fadeout based on intake speed (is that realistic?)
    state.turbine.thrust = self.turbine.angularSpeed * 4 * state.turbine.throttle * (helpers.mapRange(car.speedKmh, 0, config.turbine.maximumEffectiveIntakeSpeed, 1, 0, true) ^ config.turbine.thrustFadeoutExponent)
    ac.addForce(vec3(0.0, 0.77, -2), true, vec3(0, 0, state.turbine.thrust), true)

    -- Turbine afterburner extra thrust
    ac.addForce(vec3(0.0, 0.77, -2), true, vec3(0, 0, helpers.mapRange(state.turbine.throttleAfterburner, 0, 1, 0, 2500, true)), true)

    -- Bleed pressure from turbine engine
    state.turbine.bleedBoost = state.turbine.thrust * config.turbine.boostThrustFactor + self.turbine.angularSpeed * config.turbine.boostSpeedFactor
    ac.overrideTurboBoost(0, state.turbine.bleedBoost, state.turbine.bleedBoost)

    -- Torque transfers between piston engine and turbine engine
    local turbineTorqueFromEngine = rpmDelta * 0.1
    local engineTorqueFromTurbine = rpmDelta * config.turbine.gearRatio * 0.0001
    ac.setExtraTorque(state.turbine.clutchDisconnected and 0 or engineTorqueFromTurbine) -- Engine torque from turbine
    self.turbine:step((state.turbine.clutchDisconnected and 0 or turbineTorqueFromEngine) + (state.turbine.fuelPumpEnabled and 10 * state.turbine.thrust * (helpers.mapRange(self.turbine.angularSpeed, 0, 2000, 0.1, 0, true) ^ 0.8) or 0), dt) -- Turbine torque from engine plus turbine internally generated torque

    -- Clamp the turbine speed to a minimum of 0 RPM to prevent reversing weirdness
    if self.turbine.angularSpeed < 0 then
        self.turbine.angularSpeed = 0
    end

    -- Calculate fuel consumption based on throttle, RPM and thrust
    state.turbine.fuelConsumption = (state.turbine.throttle * config.turbine.fuelConsThrottleFactor) -- Throttle factor
        * (self.turbine.angularSpeed * config.turbine.fuelConsSpeedFactor) -- RPM factor
        * (state.turbine.thrust * config.turbine.fuelConsThrustFactor) -- Thrust factor
        * dt -- Time factor


    -- Take the fuel out of the turbine fuel tank
    state.turbine.fuelLevel = state.turbine.fuelLevel - state.turbine.fuelConsumption

    -- Update turbine RPM status for readouts and sync and stuff
    state.turbine.rpm = self.turbine.angularSpeed * 60 / (2 * math.pi)

    -- Debug outputs
    ac.debug("state.turbine.throttle", state.turbine.throttle)
    ac.debug("state.turbine.throttleAfterburner", state.turbine.throttleAfterburner)
    ac.debug("state.turbine.thrust", state.turbine.thrust)
    ac.debug("state.turbine.clutchDisconnected", state.turbine.clutchDisconnected)
    ac.debug("state.turbine.bleedBoost", state.turbine.bleedBoost)
    ac.debug("turbine.torque", self.turbine.torque)
    ac.debug("turbine.angularSpeed", self.turbine.angularSpeed)
    ac.debug("turbine.RPM", self.turbine.angularSpeed * 60 / (2 * math.pi))
    ac.debug("turbine.rpmDelta", rpmDelta)
    ac.debug("state.turbine.fuelConsumption", state.turbine.fuelConsumption)
    ac.debug("state.turbine.fuelLevel", state.turbine.fuelLevel)
    ac.debug("state.turbine.fuelPumpEnabled", state.turbine.fuelPumpEnabled)
    ac.debug("baseThrottle", baseThrottle)
end


return Turbine