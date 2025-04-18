-- T-180 CSP Physics Script - Turbine Thruster Module
-- Authored by ohyeah2389


local state = require('script_state')
local config = require('car_config')
local controls = require('script_controls')
local game = require('script_acConnection')
local helpers = require('script_helpers')
local physics = require('script_physics')
local PIDController = require('script_pid')


local turbojet = class("turbojet")


function turbojet:initialize()
    self.carReversing = false
    self.turbine = physics({
        rotary = true,
        inertia = config.turbojet.inertia,
        forceMax = 10000,
        frictionCoef = config.turbojet.frictionCoef,
        staticFrictionCoef = 0
    })
    self.throttlePID = PIDController(
        0.0001, -- kP
        0, -- kI
        0.0001, -- kD
        config.turbojet.minThrottle, -- minOutput
        1, -- maxOutput
        1 -- dampingFactor
    )
end


function turbojet:reset()
    self.carReversing = false
    self.turbine.angularSpeed = 0
    self.throttlePID:reset()
    state.turbine.throttle = 0.0
    state.turbine.thrust = 0.0
    state.turbine.bleedBoost = 0.0
    state.turbine.fuelLevel = config.turbojet.fuelTankCapacity
    state.turbine.fuelConsumption = 0.0
end


function turbojet:update(dt)
    -- Difference in RPM between piston engine and turbine engine
    local rpmDelta = (math.max(game.car_cphys.rpm, 0) - (self.turbine.angularSpeed * 60 / (2 * math.pi))) / config.turbojet.gearRatio

    -- Determine if car is traveling backwards (but not if it's in the air)
    if helpers.getWheelsOffGround() > 3 then
        self.carReversing = false
    else
        self.carReversing = game.car_cphys.localVelocity.z < 0
    end

    -- Drift angle from velocities
    local driftAngle = math.atan(game.car_cphys.localVelocity.x / math.abs(game.car_cphys.localVelocity.z))

    -- Base throttle request from drift
    local baseThrottle = helpers.mapRange(game.car_cphys.gas * helpers.mapRange(math.abs(driftAngle), math.rad(config.turbojet.helperStartAngle), math.rad(config.turbojet.helperEndAngle), 0, 1, true), 0, 1, config.turbojet.minThrottle, 1, true)

    -- Throttle final calculation
    if controls.turbine.throttle:down() then -- Full throttle override
        state.turbine.throttle = math.applyLag(state.turbine.throttle, 1, config.turbojet.throttleLag, dt)
        if state.turbine.throttle > 0.9 then
            state.turbine.throttleAfterburner = math.applyLag(state.turbine.throttleAfterburner, 1, config.turbojet.throttleLagAfterburner, dt)
        else
            state.turbine.throttleAfterburner = math.applyLag(state.turbine.throttleAfterburner, 0, config.turbojet.throttleLagAfterburner, dt)
        end
        self.throttlePID:reset()  -- Reset PID when override is active
    elseif state.control.spinMode then -- Zero throttle override for spin mode
        state.turbine.throttle = math.applyLag(state.turbine.throttle, 0, config.turbojet.throttleLag, dt)
        state.turbine.throttleAfterburner = math.applyLag(state.turbine.throttleAfterburner, 0, config.turbojet.throttleLagAfterburner, dt)
        self.throttlePID:reset()  -- Reset PID when override is active
    else
        state.turbine.throttleAfterburner = math.applyLag(state.turbine.throttleAfterburner, 0, config.turbojet.throttleLagAfterburner, dt)
        local pidOutput = state.turbine.clutchDisconnected and 0 or self.throttlePID:update(0, rpmDelta, dt)
        local correctedThrottle = math.clamp(baseThrottle * (1 + pidOutput), config.turbojet.minThrottle, 1)
        state.turbine.throttle = math.applyLag(state.turbine.throttle, correctedThrottle, config.turbojet.throttleLag, dt)
    end

    -- Turbine thrust with fadeout based on intake speed (is that realistic?)
    state.turbine.thrust = self.turbine.angularSpeed * config.turbojet.thrustMultiplier * state.turbine.throttle * (helpers.mapRange(car.speedKmh, 0, config.turbojet.maximumEffectiveIntakeSpeed, 1, 0, true) ^ config.turbojet.thrustFadeoutExponent)
    ac.addForce(vec3(0.0, 0.77, -2), true, vec3(0, 0, state.turbine.thrust), true)

    -- Turbine afterburner extra thrust
    ac.addForce(vec3(0.0, 0.77, -2), true, vec3(0, 0, helpers.mapRange(state.turbine.throttleAfterburner, 0, 1, 0, 2500, true)), true)

    -- Bleed pressure from turbine engine
    state.turbine.bleedBoost = state.turbine.thrust * config.turbojet.boostThrustFactor + self.turbine.angularSpeed * config.turbojet.boostSpeedFactor
    ac.overrideTurboBoost(0, state.turbine.bleedBoost, state.turbine.bleedBoost)

    -- Clamp the turbine speed to a minimum of 0 RPM to prevent reversing weirdness
    if self.turbine.angularSpeed < 0 then
        self.turbine.angularSpeed = 0
    end

    -- Calculate fuel consumption based on throttle, RPM and thrust
    state.turbine.fuelConsumption = (state.turbine.throttle * config.turbojet.fuelConsThrottleFactor) -- Throttle factor
        * (self.turbine.angularSpeed * config.turbojet.fuelConsSpeedFactor) -- RPM factor
        * (state.turbine.thrust * config.turbojet.fuelConsThrustFactor) -- Thrust factor
        * dt -- Time factor


    -- Take the fuel out of the turbine fuel tank
    state.turbine.fuelLevel = state.turbine.fuelLevel - state.turbine.fuelConsumption

    -- Update turbine RPM status for readouts and sync and stuff
    state.turbine.rpm = self.turbine.angularSpeed * 60 / (2 * math.pi)

    -- Debug outputs
    ac.debug("state.turbojet.throttle", state.turbine.throttle)
    ac.debug("state.turbojet.throttleAfterburner", state.turbine.throttleAfterburner)
    ac.debug("state.turbojet.thrust", state.turbine.thrust)
    ac.debug("state.turbojet.clutchDisconnected", state.turbine.clutchDisconnected)
    ac.debug("state.turbojet.bleedBoost", state.turbine.bleedBoost)
    ac.debug("turbojet.torque", self.turbine.torque)
    ac.debug("turbojet.angularSpeed", self.turbine.angularSpeed)
    ac.debug("turbojet.RPM", self.turbine.angularSpeed * 60 / (2 * math.pi))
    ac.debug("turbojet.rpmDelta", rpmDelta)
    ac.debug("state.turbojet.fuelConsumption", state.turbine.fuelConsumption)
    ac.debug("state.turbojet.fuelLevel", state.turbine.fuelLevel)
    ac.debug("state.turbojet.fuelPumpEnabled", state.turbine.fuelPumpEnabled)
    ac.debug("baseThrottle", baseThrottle)
end


return turbojet