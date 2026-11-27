-- T-180 CSP Physics Script - Turbocharger Thruster Module
-- Authored by ohyeah2389

local config = require('car_config')

local turbothruster = class("turbothruster")

function turbothruster:initialize(params)
    self.thrust = 0.0
    self.thrustApplicationPoint = params.thrustApplicationPoint or config.turbothruster.thrustApplicationPoint or vec3(0.0, 0.77, -2)

    if config.turbothruster.thrustAngle then
        local angleRad = math.rad(config.turbothruster.thrustAngle)
        self.thrustVector = vec3(0, math.sin(-angleRad), math.cos(-angleRad))
    else
        self.thrustVector = vec3(0, 0, 1)
    end
end

function turbothruster:reset() end

function turbothruster:update(dt)
    -- Find the direction of the car in its XZ plane
    local driftAngle = math.atan2(Data.localVelocity.x, Data.localVelocity.z)

    -- Set how much force remains at zero drift angle (0.0 = full dropoff, 1.0 = no dropoff)
    local directionalDropoff = 0.6

    -- Fade out the thrust with a cosine curve
    local cosineDropoff = math.lerp(1.0, directionalDropoff, math.abs(math.cos(driftAngle)))

    -- Main thrust calculation
    self.thrust = Data.turboBoost * config.turbothruster.thrustFactor * cosineDropoff

    -- Apply thrust to car
    ac.addForce(self.thrustApplicationPoint, true, self.thrustVector * self.thrust, true)

    if DEBUG then
        local debugPrefix = "turbothruster."
        ac.debug(debugPrefix .. "thrust", self.thrust, 0, 8000, 3)
        ac.debug(debugPrefix .. "cosineDropoff", cosineDropoff, 0, 8000, 3)
    end
end

return turbothruster
