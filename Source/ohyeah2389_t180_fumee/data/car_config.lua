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
        present = true, -- Whether the car has a turbine or not
        type = "single", -- "single" or "dual"
        helperStartAngle = 20, -- Angle in degrees at which the turbojet starts to automatically apply throttle
        helperEndAngle = 60, -- Angle in degrees at which the turbojet ends automatically applying throttle
        frictionCoef = 0.08, -- Friction coefficient of the turbine shaft
        inertia = 0.1, -- Inertia of the turbine shaft
        minThrottle = 0.1, -- Idle throttle of the turbine
        throttleLag = 0.5, -- 0 to 1 where 0 represents instant turbine throttle response (unrealistic) and 1 represents no change in throttle
        throttleLagAfterburner = 0.5, -- 0 to 1 as above, but for afterburner fuel delivery
        gearRatio = 2.5, -- value:1, turbine:engine
        thrustMultiplier = 0.9, -- Multiplier on turbine output thrust
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
        present = false
    }
}


return config