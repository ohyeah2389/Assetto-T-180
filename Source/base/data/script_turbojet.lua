-- T-180 CSP Physics Script - Turbine Thruster Module
-- Authored by ohyeah2389


local config = require('car_config')
local game = require('script_acConnection')
local helpers = require('script_helpers')
local physics = require('script_physics')


local turbojet = class("turbojet")

function turbojet:initialize(params)
    self.id = params.id or 'single' -- 'single', 'left', or 'right'

    self.throttle = 0.0
    self.throttleAfterburner = 0.0
    self.targetThrottle = 0.0
    self.targetThrottleAfterburner = 0.0
    self.thrust = 0.0
    self.fuelPumpEnabled = true
    self.bleedBoost = 0.0

    self.thrustApplicationPoint = params.thrustApplicationPoint or config.turbojet.thrustApplicationPoint or vec3(0.0, 0.77, -2)
    self.shaft = physics({
        rotary = true,
        inertia = config.turbojet.inertia,
        forceMax = 10000,
        frictionCoef = config.turbojet.frictionCoef,
        staticFrictionCoef = 0
    })
    self.shaft.angularSpeed = 850
end

function turbojet:reset()
    self.shaft.angularSpeed = 850
    self.throttle = 0.0
    self.throttleAfterburner = 0.0
    self.targetThrottle = 0.0
    self.targetThrottleAfterburner = 0.0
    self.thrust = 0.0
    self.bleedBoost = 0.0
end

function turbojet:update(dt)
    self.throttle = math.applyLag(self.throttle, self.targetThrottle, config.turbojet.throttleLag, dt)
    self.throttleAfterburner = math.applyLag(self.throttleAfterburner, self.targetThrottleAfterburner, config.turbojet.throttleLagAfterburner, dt)

    -- Calculate speed in Mach number (assuming speed of sound = 1225 km/h at sea level)
    local machNumber = game.car_cphys.speedKmh / 1225

    -- Calculate speed-based thrust multiplier
    local speedThrustMultiplier
    if machNumber <= 1.0 then
        -- Subsonic: apply power curve based on thrust curve parameters
        -- Base is 1.0, then modified by thrustCurveLevel with the configured exponent
        speedThrustMultiplier = 1.0 + (config.turbojet.thrustCurveLevel * (machNumber ^ config.turbojet.thrustCurveExponent))
    else
        -- Supersonic: apply derate factor due to shock intake effects
        speedThrustMultiplier = (1.0 + config.turbojet.thrustCurveLevel) * config.turbojet.supersonicDeratingFactor
    end

    local currentThrust = self.shaft.angularSpeed * config.turbojet.thrustMultiplier * self.throttle * speedThrustMultiplier * (self.fuelPumpEnabled and 1 or 0)
    ac.addForce(self.thrustApplicationPoint, true, vec3(0, 0, currentThrust), true)
    self.thrust = currentThrust -- Store thrust for external use/display

    -- Turbine torque from itself
    self.shaft:step((self.fuelPumpEnabled and self.thrust * (helpers.mapRange(self.shaft.angularSpeed, 0, 2000, 1, 0, true) ^ 1.2) or 0), dt)

    -- Turbine afterburner extra thrust
    local thrustMagnitude = helpers.mapRange(self.throttleAfterburner, 0, 1, 0, 2500, true)
    local thrustVector
    if config.turbojet.thrustAngle then
        local angleRad = math.rad(config.turbojet.thrustAngle)
        thrustVector = vec3(0, thrustMagnitude * math.sin(-angleRad), thrustMagnitude * math.cos(-angleRad))
    else
        thrustVector = vec3(0, 0, thrustMagnitude)
    end
    ac.addForce(self.thrustApplicationPoint, true, thrustVector * (self.fuelPumpEnabled and 1 or 0), true)

    if self.id == 'single' then
        -- Bleed pressure from turbine engine (only for single engine interacting with piston engine)
        local baseBoost = self.thrust * config.turbojet.boostThrustFactor + self.shaft.angularSpeed * config.turbojet.boostSpeedFactor
        self.bleedBoost = math.remap(baseBoost, 0, 2.0, 1.0, 2.0)
        ac.overrideTurboBoost(0, self.bleedBoost, self.bleedBoost)
    end

    -- Clamp the turbine speed to a minimum of 0 RPM to prevent reversing weirdness
    if self.shaft.angularSpeed < 0 then
        self.shaft.angularSpeed = 0
    end

    -- Debug outputs (conditional on ID to avoid spamming)
    local debugPrefix = "turbojet." .. self.id .. "."
    ac.debug(debugPrefix .. "throttle", self.throttle)
    ac.debug(debugPrefix .. "throttleAfterburner", self.throttleAfterburner)
    ac.debug(debugPrefix .. "thrust", self.thrust)
    if self.id == 'single' then
        ac.debug(debugPrefix .. "bleedBoost", self.bleedBoost)
    end
    ac.debug(debugPrefix .. "turbine.torque", self.shaft.torque)
    ac.debug(debugPrefix .. "turbine.angularSpeed", self.shaft.angularSpeed)
    ac.debug(debugPrefix .. "turbine.RPM", self.shaft.angularSpeed * 60 / (2 * math.pi))
    ac.debug(debugPrefix .. "fuelPumpEnabled", self.fuelPumpEnabled)
    ac.debug(debugPrefix .. "machNumber", machNumber)
    ac.debug(debugPrefix .. "speedThrustMultiplier", speedThrustMultiplier)
end

return turbojet
