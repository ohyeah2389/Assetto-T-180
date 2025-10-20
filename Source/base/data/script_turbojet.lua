-- T-180 CSP Physics Script - Turbine Thruster Module
-- Authored by ohyeah2389


local config = require('car_config')
local game = require('script_acConnection')
local helpers = require('script_helpers')
local physics = require('script_physics')
local PIDController = require('script_pid')

local thrustHeatCoefCore = 0.05
local burnerHeatCoefCore = 0.02

local thrustHeatCoefFrame = 0.001
local burnerHeatCoefFrame = 0.05

local coreTransferToFrame = 0.01
local frameTransferToCore = 0.01

local shaftSpeedCoolCoefCore = 0.05
local airSpeedCoolCoefCore = 0.025
local staticCoolCoefCore = 0.008

local bleedCoolCoefFrame = 50.0
local airSpeedCoolCoefFrame = 0.04
local staticCoolCoefFrame = 0.04

local frameTempLimit = 1000
local coreTempLimit = 1800
local bleedRedirectThreshold = 850


local turbojet = class("turbojet")

function turbojet:initialize(params)
    self.id = params.id or 'single' -- 'single', 'left', or 'right'

    self.throttle = 0.0
    self.throttleAfterburner = 0.0
    self.targetThrottle = 0.0
    self.targetThrottleAfterburner = 0.0
    self.thrust = 0.0
    self.thrustAfterburner = 0.0
    self.fuelPumpEnabled = true
    self.bleedBoost = 0.0
    self.heatFrame = game.sim.ambientTemperature + 273.15
    self.heatCore = game.sim.ambientTemperature + 273.15

    self.pidDerateHeatCore = PIDController(0.001, 0, 0, 0, 1)
    self.pidDerateHeatFrame = PIDController(0.04, 0, 0, 0, 1)
    self.pidValveCoolFrame = PIDController(0.01, 0, 0, 0, 1)

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
    self.thrustAfterburner = 0.0
    self.bleedBoost = 0.0
    self.heatFrame = game.sim.ambientTemperature + 273.15
    self.heatCore = game.sim.ambientTemperature + 273.15
end

function turbojet:update(dt)
    -- Update heat derating PIDs (inverted: output 1 when cool, reduce when over limit)
    local throttleDerate = 1 - self.pidDerateHeatCore:update(self.heatCore, coreTempLimit, dt)
    local burnerDerate = 1 - self.pidDerateHeatFrame:update(self.heatFrame, frameTempLimit, dt)

    -- Apply throttle values with lag
    self.throttle = math.applyLag(self.throttle, self.targetThrottle * throttleDerate, config.turbojet.throttleLag, dt)
    self.throttleAfterburner = math.applyLag(self.throttleAfterburner, self.targetThrottleAfterburner * burnerDerate, config.turbojet.throttleLagAfterburner, dt)

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

    -- Main thrust calculation
    local coreThrust = self.shaft.angularSpeed * config.turbojet.thrustMultiplier * self.throttle * speedThrustMultiplier * (self.fuelPumpEnabled and 1 or 0)
    ac.addForce(self.thrustApplicationPoint, true, vec3(0, 0, coreThrust), true)
    self.thrust = coreThrust

    -- Turbine torque application from itself
    self.shaft:step((self.fuelPumpEnabled and self.thrust * (helpers.mapRange(self.shaft.angularSpeed, 0, 2000, 1, 0, true) ^ 1.2) or 0), dt)

    -- Afterburner extra thrust calculation
    self.thrustAfterburner = helpers.mapRange(self.throttleAfterburner, 0, 1, 0, 2500, true)
    local thrustVector = vec3(0, 0, 0)
    if config.turbojet.thrustAngle then
        local angleRad = math.rad(config.turbojet.thrustAngle)
        thrustVector = vec3(0, self.thrustAfterburner * math.sin(-angleRad), self.thrustAfterburner * math.cos(-angleRad))
    else
        thrustVector = vec3(0, 0, self.thrustAfterburner)
    end

    -- Apply thrust to car
    ac.addForce(self.thrustApplicationPoint, true, thrustVector * (self.fuelPumpEnabled and 1 or 0), true)

    -- Bleed pressure from turbine engine (only for single engine interacting with piston engine)
    local bleedCoolingFrame = 0
    if self.id == 'single' then
        local baseBoost = self.thrust * config.turbojet.boostThrustFactor + self.shaft.angularSpeed * config.turbojet.boostSpeedFactor
        bleedCoolingFrame = baseBoost * self.pidValveCoolFrame:update(self.heatFrame, bleedRedirectThreshold, dt)
        local remainingBoost = baseBoost - bleedCoolingFrame
        self.bleedBoost = math.remap(remainingBoost, 0, 2.0, 1.0, 2.0)
        ac.overrideTurboBoost(0, self.bleedBoost, self.bleedBoost)
    end

    -- Clamp the turbine speed to a minimum of 0.1 rad/s to prevent reversing weirdness
    if self.shaft.angularSpeed < 0.1 then
        self.shaft.angularSpeed = 0.1
    end

    local heatTransferCoreToFrameRate = (self.heatCore - self.heatFrame) * coreTransferToFrame
    local heatTransferFrameToCoreRate = (self.heatFrame - self.heatCore) * frameTransferToCore

    local coreHeating = (coreThrust * thrustHeatCoefCore) + (self.thrustAfterburner * burnerHeatCoefCore)
    local coreCooling = (game.car_cphys.speedKmh * airSpeedCoolCoefCore) + (self.shaft.angularSpeed * shaftSpeedCoolCoefCore) + staticCoolCoefCore
    self.heatCore = math.max(self.heatCore + ((coreHeating - coreCooling - heatTransferCoreToFrameRate + heatTransferFrameToCoreRate) * dt), game.sim.ambientTemperature + 273.15)

    local frameHeating = (coreThrust * thrustHeatCoefFrame) + (self.thrustAfterburner * burnerHeatCoefFrame)
    local frameCooling = (game.car_cphys.speedKmh * airSpeedCoolCoefFrame) + (bleedCoolingFrame * bleedCoolCoefFrame) + staticCoolCoefFrame
    self.heatFrame = math.max(self.heatFrame + ((frameHeating - frameCooling + heatTransferCoreToFrameRate - heatTransferFrameToCoreRate) * dt), game.sim.ambientTemperature + 273.15)

    -- Debug outputs (conditional on ID to avoid spamming)
    local debugPrefix = "turbojet." .. self.id .. "."
    ac.debug(debugPrefix .. "throttle", self.throttle, 0, 1, 3)
    ac.debug(debugPrefix .. "throttleAfterburner", self.throttleAfterburner, 0, 1, 3)
    ac.debug(debugPrefix .. "thrust", self.thrust, 0, 4000, 3)
    ac.debug(debugPrefix .. "thrustAfterburner", self.thrustAfterburner, 0, 4000, 3)
    if self.id == 'single' then
        ac.debug(debugPrefix .. "bleedBoost", self.bleedBoost)
    end
    ac.debug(debugPrefix .. "turbine.torque", self.shaft.torque)
    ac.debug(debugPrefix .. "turbine.angularSpeed", self.shaft.angularSpeed)
    ac.debug(debugPrefix .. "turbine.RPM", self.shaft.angularSpeed * 60 / (2 * math.pi))
    ac.debug(debugPrefix .. "fuelPumpEnabled", self.fuelPumpEnabled)
    ac.debug(debugPrefix .. "machNumber", machNumber)
    ac.debug(debugPrefix .. "speedThrustMultiplier", speedThrustMultiplier)
    ac.debug(debugPrefix .. "coreHeating", coreHeating, 0, 400, 3)
    ac.debug(debugPrefix .. "coreCooling", coreCooling, 0, 400, 3)
    ac.debug(debugPrefix .. "frameHeating", frameHeating, 0, 400, 3)
    ac.debug(debugPrefix .. "frameCooling", frameCooling, 0, 400, 3)
    ac.debug(debugPrefix .. "heatFrame", self.heatFrame, 0, 1000, 3)
    ac.debug(debugPrefix .. "heatCore", self.heatCore, 0, 2000, 3)
    ac.debug(debugPrefix .. "pidDerateHeatCore.previousOutput", self.pidDerateHeatCore.previousOutput)
    ac.debug(debugPrefix .. "pidValveCoolFrame.previousOutput", self.pidValveCoolFrame.previousOutput)
    ac.debug(debugPrefix .. "pidDerateHeatFrame.previousOutput", self.pidDerateHeatFrame.previousOutput)
    ac.debug(debugPrefix .. "throttleDerate", throttleDerate)
    ac.debug(debugPrefix .. "burnerDerate", burnerDerate)
end

return turbojet
