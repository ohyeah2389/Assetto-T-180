-- T-180 CSP Physics Script - Config and Parameters Module
-- Authored by ohyeah2389


local config = {
    misc = {
        brakeAutoHold = {
            torque = 200, -- Brake torque in Nm to apply when auto-holding the brakes
            speed = 10,   -- Speed in kmh below which to auto-hold the brakes
        },
        debugFrequency = 0.1,
        jumpJackSize = 1,
    },
    turbojet = {
        present = false,                    -- Whether the car has a turbine or not
        type = nil,                         -- Explicitly nil since present is false
        helperStartAngle = 20,              -- Angle in degrees at which the turbojet starts to automatically apply throttle
        helperEndAngle = 60,                -- Angle in degrees at which the turbojet ends automatically applying throttle
        frictionCoef = 0.08,                -- Friction coefficient of the turbine shaft
        inertia = 0.1,                      -- Inertia of the turbine shaft
        minThrottle = 0.1,                  -- Idle throttle of the turbine
        throttleLag = 0.5,                  -- 0 to 1 where 0 represents instant turbine throttle response (unrealistic) and 1 represents no change in throttle
        throttleLagAfterburner = 0.5,       -- 0 to 1 as above, but for afterburner fuel delivery
        gearRatio = 1.5,                    -- value:1, turbine:engine
        thrustMultiplier = 1.5,             -- Multiplier on turbine output thrust
        boostThrustFactor = 0.00001,        -- Multiplier on turbine output thrust to form bleed air boost thrust component (speed component is added to this for total bleed air boost value)
        boostSpeedFactor = 0.001,           -- Multiplier on turbine angular speed to form bleed air boost speed component (thrust component is added to this for total bleed air boost value)
        maximumEffectiveIntakeSpeed = 2000, -- kmh - Maximum effective intake speed of the turbine (used to calculate effective intake speed for thrust fadeout)
        thrustFadeoutExponent = 1.2,        -- Exponent for the thrust fadeout curve (used to calculate effective intake speed for thrust fadeout)
    },
    turboshaft = {
        present = true,
        type = "dual", -- "single" or "dual"

        -- Common parameters for both turbines
        designMaxNGRPM = 30000,
        designMaxTIT = 1200,
        boostNGMultiplier = 1.5,
        boostTITMultiplier = 1.5,
        inertiaNG = 1.2,
        pressureRatio = 7.8,
        compressorEfficiency = 0.82,
        totalTurbineEfficiency = 0.88, -- Total efficiency of both turbines combined
        fuelLHV = 43.2e6, -- J/kg (Jet-A)
        combustionEfficiency = 0.98,
        exhaustThrust = {
            nozzleArea = 0.2,                            -- m², cross-sectional area of exhaust nozzle
            nozzleEfficiency = 0.95,                     -- Efficiency of the exhaust nozzle
            thrustApplicationPoint = vec3(0, 0.5, -2.0), -- Point where thrust is applied (relative to car)
            exhaustAngle = 0,                            -- degrees, angle of exhaust relative to car's forward axis
        }
    }
}


return config
