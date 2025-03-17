-- T-180 CSP Physics Script - Config and Parameters Module
-- Authored by ohyeah2389


local config = {
    misc = {
        brakeAutoHold = {
            torque = 200; -- Brake torque in Nm to apply when auto-holding the brakes
            speed = 10; -- Speed in kmh below which to auto-hold the brakes
        };
        debugFrequency = 0.1;
        jumpJackSize = 1;
    },
    turbojet = {
        present = false, -- Whether the car has a turbine or not
        frictionCoef = 1.35, -- Friction coefficient of the turbine shaft
        inertia = 0.002, -- Inertia of the turbine shaft
        minThrottle = 0.2, -- Idle throttle of the turbine
        throttleLag = 0.9, -- 0 to 1 where 0 represents instant turbine throttle response (unrealistic) and 1 represents no change in throttle
        throttleLagAfterburner = 0.8, -- 0 to 1 as above, but for afterburner fuel delivery
        gearRatio = 1.5, -- value:1, turbine:engine
        boostThrustFactor = 0.00001, -- Multiplier on turbine output thrust to form bleed air boost thrust component (speed component is added to this for total bleed air boost value)
        boostSpeedFactor = 0.001, -- Multiplier on turbine angular speed to form bleed air boost speed component (thrust component is added to this for total bleed air boost value)
        maximumEffectiveIntakeSpeed = 2000, -- kmh - Maximum effective intake speed of the turbine (used to calculate effective intake speed for thrust fadeout)
        thrustFadeoutExponent = 1.2, -- Exponent for the thrust fadeout curve (used to calculate effective intake speed for thrust fadeout)
        fuelTankCapacity = 100, -- Litres - Capacity of the fuel tank
        fuelConsThrottleFactor = 1.0, -- Throttle position fuel consumption multiplier
        fuelConsSpeedFactor = 0.0001, -- Angular speed fuel consumption multiplier
        fuelConsThrustFactor = 0.000125, -- Developed thrust fuel consumption multiplier
    },
    turboshaft = {
        present = true,
        type = "dual", -- "single" or "dual"

        -- Common parameters for both turbines
        designMaxNGRPM = 30000,
        designMaxTIT = 1200,
        boostNGMultiplier = 1.5,
        boostTITMultiplier = 1.5,
        inertiaNG = 0.02,
        pressureRatio = 7.8,
        compressorEfficiency = 0.82,
        freeTurbineEfficiency = 0.85,
        fuelLHV = 43.2e6,  -- J/kg (Jet-A)
        combustionEfficiency = 0.98,

        -- Power turbine specific parameters
        designPowerRPM = 40000,      -- Design RPM for power turbine
        inertiaNP = 0.03,            -- Power turbine rotor inertia
        powerTurbineEfficiency = 0.85,    -- Efficiency of power extraction from remaining energy
        totalTurbineEfficiency = 0.92,    -- Total efficiency of both turbines combined
        ngTurbineEfficiency = 0.75,       -- Portion of total power extracted by gas generator
    }
}


return config