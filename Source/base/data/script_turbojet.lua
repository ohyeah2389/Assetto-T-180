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


function turbojet:initialize(params)
    self.id = params.id or 'single' -- 'single', 'left', or 'right'
    self.state = self.id == 'single' and state.turbine or state.turbine[self.id] -- Reference correct state sub-table

    self.carReversing = false
    self.thrustApplicationPoint = params.thrustApplicationPoint or vec3(0.0, 0.77, -2)
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
    self.turbine.angularSpeed = 100
end


function turbojet:reset()
    self.carReversing = false
    self.turbine.angularSpeed = 0
    self.throttlePID:reset()
    self.state.throttle = 0.0
    self.state.thrust = 0.0 -- Only relevant for single engine
    self.state.bleedBoost = 0.0 -- Only relevant for single engine
    self.state.fuelConsumption = 0.0
    self.turbine.angularSpeed = 100
    self.state.throttleAfterburner = 0.0
    self.state.rpm = 0.0
end


function turbojet:update(dt)
    local rpmDelta = 0
    if self.id == 'single' then
        -- Difference in RPM between piston engine and turbine engine
        rpmDelta = (math.max(game.car_cphys.rpm, 0) - (self.turbine.angularSpeed * 60 / (2 * math.pi))) / config.turbojet.gearRatio
    end

    -- Determine if car is traveling backwards (but not if it's in the air)
    if helpers.getWheelsOffGround() > 3 then
        self.carReversing = false
    else
        self.carReversing = game.car_cphys.localVelocity.z < 0
    end

    -- Throttle logic
    if self.id == 'single' then
        -- Drift angle from velocities
        local driftAngle = math.atan(game.car_cphys.localVelocity.x / math.abs(game.car_cphys.localVelocity.z))
        -- Base throttle request from drift
        local baseThrottle = helpers.mapRange(game.car_cphys.gas * helpers.mapRange(math.abs(driftAngle), math.rad(config.turbojet.helperStartAngle), math.rad(config.turbojet.helperEndAngle), 0, 1, true), 0, 1, config.turbojet.minThrottle, 1, true)

        -- Throttle final calculation
        if controls.turbine.throttle:down() and state.turbine.fuelPumpEnabled then -- Full throttle override
            self.state.throttle = math.applyLag(self.state.throttle, 1, config.turbojet.throttleLag, dt)
            if self.state.throttle > 0.9 then
                self.state.throttleAfterburner = math.applyLag(self.state.throttleAfterburner, 1, config.turbojet.throttleLagAfterburner, dt)
            else
                self.state.throttleAfterburner = math.applyLag(self.state.throttleAfterburner, 0, config.turbojet.throttleLagAfterburner, dt)
            end
            self.throttlePID:reset()  -- Reset PID when override is active
        else
            self.state.throttleAfterburner = math.applyLag(self.state.throttleAfterburner, 0, config.turbojet.throttleLagAfterburner, dt)
            local pidOutput = self.throttlePID:update(0, rpmDelta, dt)
            local correctedThrottle = math.clamp(baseThrottle * (1 + pidOutput), config.turbojet.minThrottle, 1)
            self.state.throttle = math.applyLag(self.state.throttle, correctedThrottle, config.turbojet.throttleLag, dt)
        end
    else -- Dual engine: Throttle is set externally in script.lua
        -- Apply lag to the externally set throttle
        -- Note: We are reading and writing to the same state variable here. This assumes script.lua sets the *target* throttle.
        self.state.throttle = math.applyLag(self.state.throttle, self.state.throttle, config.turbojet.throttleLag, dt)
    end


    -- Turbine thrust calculation (common for both)
    local currentThrust = self.turbine.angularSpeed * config.turbojet.thrustMultiplier * self.state.throttle * (helpers.mapRange(car.speedKmh, 0, config.turbojet.maximumEffectiveIntakeSpeed, 1, 0, true) ^ config.turbojet.thrustFadeoutExponent) * (self.state.fuelPumpEnabled and 1 or 0)
    ac.addForce(self.thrustApplicationPoint, true, vec3(0, 0, currentThrust), true)
    self.state.thrust = currentThrust -- Store thrust for potential external use/display

    -- Turbine torque from itself
    self.turbine:step((self.state.fuelPumpEnabled and self.state.thrust * (helpers.mapRange(self.turbine.angularSpeed, 0, 2000, 1, 0, true) ^ 1.2) or 0), dt)

    -- Turbine afterburner extra thrust
    ac.addForce(self.thrustApplicationPoint, true, vec3(0, 0, helpers.mapRange(self.state.throttleAfterburner, 0, 1, 0, 2500, true) * (self.state.fuelPumpEnabled and 1 or 0)), true)

    if self.id == 'single' then
        -- Bleed pressure from turbine engine (only for single engine interacting with piston engine)
        self.state.bleedBoost = self.state.thrust * config.turbojet.boostThrustFactor + self.turbine.angularSpeed * config.turbojet.boostSpeedFactor
        ac.overrideTurboBoost(0, self.state.bleedBoost, self.state.bleedBoost)
    end

    -- Clamp the turbine speed to a minimum of 0 RPM to prevent reversing weirdness
    if self.turbine.angularSpeed < 0 then
        self.turbine.angularSpeed = 0
    end

    -- Calculate fuel consumption based on throttle, RPM and thrust (common logic)
    self.state.fuelConsumption = (self.state.throttle * config.turbojet.fuelConsThrottleFactor) -- Throttle factor
        * (self.turbine.angularSpeed * config.turbojet.fuelConsSpeedFactor) -- RPM factor
        * (self.state.thrust * config.turbojet.fuelConsThrustFactor) -- Thrust factor
        * dt -- Time factor

    -- Take the fuel out of the turbine fuel tank
    -- Assume a shared fuel tank for now. This might need adjustment if separate tanks are desired.
    state.turbine.fuelLevel = state.turbine.fuelLevel - self.state.fuelConsumption

    -- Update turbine RPM status for readouts and sync and stuff
    self.state.rpm = self.turbine.angularSpeed * 60 / (2 * math.pi)

    -- Debug outputs (conditional on ID to avoid spamming)
    local debugPrefix = "state.turbojet." .. self.id .. "."
    ac.debug(debugPrefix .. "throttle", self.state.throttle)
    ac.debug(debugPrefix .. "throttleAfterburner", self.state.throttleAfterburner)
    ac.debug(debugPrefix .. "thrust", self.state.thrust)
    if self.id == 'single' then
        ac.debug(debugPrefix .. "bleedBoost", self.state.bleedBoost)
        ac.debug("turbojet.rpmDelta", rpmDelta)
        ac.debug("baseThrottle", baseThrottle) -- Only relevant for single
    end
    ac.debug(debugPrefix .. "turbine.torque", self.turbine.torque)
    ac.debug(debugPrefix .. "turbine.angularSpeed", self.turbine.angularSpeed)
    ac.debug(debugPrefix .. "turbine.RPM", self.state.rpm)
    ac.debug(debugPrefix .. "fuelConsumption", self.state.fuelConsumption)
    ac.debug(debugPrefix .. "fuelLevel", state.turbine.fuelLevel) -- Shared fuel level
    ac.debug(debugPrefix .. "fuelPumpEnabled", self.state.fuelPumpEnabled)
end


return turbojet