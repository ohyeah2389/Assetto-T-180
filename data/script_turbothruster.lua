-- T-180 CSP Physics Script - Turbine Thruster Module
-- Authored by ohyeah2389

local state = require('script_state')
local config = require('script_config')
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
        inertia = 0.002,
        forceMax = 10000,
        frictionCoef = 1.35,
        staticFrictionCoef = 0
    })
    self.throttlePID = PIDController(
        0.0001,   -- kP
        0,   -- kI
        0.0001,    -- kD
        config.turbine.minThrottle,      -- minOutput
        1,      -- maxOutput
        1    -- dampingFactor
    )
end


function Turbothruster:reset()
    self.carReversing = false
    self.turbine.angularSpeed = 0
    self.throttlePID:reset()
    state.turbine.throttle = 0.0
    state.turbine.thrust = 0.0
    state.turbine.bleedBoost = 0.0
    state.turbine.fuelLevel = 100.0
    state.turbine.fuelConsumption = 0.0
end


function Turbothruster:update(dt)
    local rpmDelta = (game.car_cphys.rpm - (self.turbine.angularSpeed * 60 / (2 * math.pi))) / config.turbine.gearRatio

    local wheelsOffGround = helpers.getWheelsOffGround()

    if wheelsOffGround > 3 then
        self.carReversing = false
    else
        self.carReversing = game.car_cphys.localVelocity.z < 0
    end

    local driftAngle = math.atan(game.car_cphys.localVelocity.x / math.abs(game.car_cphys.localVelocity.z))

    -- Calculate base throttle request from drift
    local baseThrottle = helpers.mapRange(game.car_cphys.gas * helpers.mapRange(math.abs(driftAngle), math.rad(30), math.rad(90), 0, 1, true), 0, 1, config.turbine.minThrottle, 1, true)

    if controls.turbine.throttle:down() then
        state.turbine.throttle = math.applyLag(state.turbine.throttle, 1, config.turbine.throttleLag, dt)
        self.throttlePID:reset()  -- Reset PID when override is active
    elseif not self.carReversing then
        local targetRPMDiff = 0
        local pidOutput = state.turbine.clutchDisconnected and 0 or self.throttlePID:update(targetRPMDiff, rpmDelta, dt)
        local correctedThrottle = math.clamp(baseThrottle * (1 + pidOutput), config.turbine.minThrottle, 1)
        state.turbine.throttle = math.applyLag(state.turbine.throttle, correctedThrottle, config.turbine.throttleLag, dt)
    else
        state.turbine.throttle = math.applyLag(state.turbine.throttle, config.turbine.minThrottle, config.turbine.throttleLag, dt)
        self.throttlePID:reset()  -- Reset PID when reversing
    end

    state.turbine.thrust = self.turbine.angularSpeed * 6 * state.turbine.throttle * (helpers.mapRange(car.speedKmh, 0, 1000, 1, 0, true) ^ 1.2)
    ac.addForce(vec3(0.0, 0.77, -2), true, vec3(0, 0, state.turbine.thrust), true)

    state.turbine.bleedBoost = state.turbine.thrust * config.turbine.boostThrustFactor + self.turbine.angularSpeed * config.turbine.boostSpeedFactor
    ac.overrideTurboBoost(0, state.turbine.bleedBoost, state.turbine.bleedBoost)

    local turbineTorqueFromEngine = rpmDelta * 0.1
    local engineTorqueFromTurbine = rpmDelta * config.turbine.gearRatio * 0.0001
    ac.setExtraTorque(state.turbine.clutchDisconnected and 0 or engineTorqueFromTurbine) -- Engine torque from turbine
    self.turbine:step((state.turbine.clutchDisconnected and 0 or turbineTorqueFromEngine) + (state.turbine.fuelPumpEnabled and 10 * state.turbine.thrust * (helpers.mapRange(self.turbine.angularSpeed, 0, 2000, 0.1, 0, true) ^ 0.8) or 0), dt) -- Turbine torque from engine

    -- Calculate fuel consumption based on throttle, RPM and thrust
    state.turbine.fuelConsumption = state.turbine.throttle 
        * (self.turbine.angularSpeed / 10000) -- RPM factor
        * (state.turbine.thrust / 8000)      -- Thrust factor
        * dt                                  -- Time factor

    state.turbine.fuelLevel = state.turbine.fuelLevel - state.turbine.fuelConsumption
    
    ac.debug("state.turbine.throttle", state.turbine.throttle)
    ac.debug("state.turbine.thrust", state.turbine.thrust)
    ac.debug("state.turbine.clutchDisconnected", state.turbine.clutchDisconnected)
    ac.debug("state.turbine.bleedBoost", state.turbine.bleedBoost)
    ac.debug("turbothruster.turbine.torque", self.turbine.torque)
    ac.debug("turbothruster.turbine.angularSpeed", self.turbine.angularSpeed)
    ac.debug("turbothruster.turbine.RPM", self.turbine.angularSpeed * 60 / (2 * math.pi))
    ac.debug("turbothruster.rpmDelta", rpmDelta)
    ac.debug("state.turbine.fuelConsumption", state.turbine.fuelConsumption)
    ac.debug("state.turbine.fuelLevel", state.turbine.fuelLevel)
    ac.debug("state.turbine.fuelPumpEnabled", state.turbine.fuelPumpEnabled)
end


return Turbothruster