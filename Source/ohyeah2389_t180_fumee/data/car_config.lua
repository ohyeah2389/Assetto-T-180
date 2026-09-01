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
        present = false,
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
