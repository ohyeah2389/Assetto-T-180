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
        present = true,                                    -- Whether the car has a turbine or not
        type = "single",                                   -- "single" or "dual"
        thrustApplicationPoint = vec3(0.0, 0.321, -2.418), -- Position of the thrust application point relative to the CoG
        helperStartAngle = 30,                             -- Angle in degrees at which the turbojet starts to automatically apply throttle
        helperEndAngle = 80,                               -- Angle in degrees at which the turbojet ends automatically applying throttle
        frictionCoef = 0.1,                               -- Friction coefficient of the turbine shaft
        inertia = 0.2,                                     -- Inertia of the turbine shaft
        minThrottle = 0.1,                                 -- Idle throttle of the turbine
        throttleLag = 0.7,                                 -- 0 to 1 where 0 represents instant turbine throttle response (unrealistic) and 1 represents no change in throttle
        throttleLagAfterburner = 0.7,                      -- 0 to 1 as above, but for afterburner fuel delivery
        gearRatio = 5.0,                                   -- value:1, turbine:engine
        thrustMultiplier = 1.8,                            -- Multiplier on turbine output thrust
        boostThrustFactor = 0.0000075,                     -- Multiplier on turbine output thrust to form bleed air boost thrust component (speed component is added to this for total bleed air boost value)
        boostSpeedFactor = 0.001,                          -- Multiplier on turbine angular speed to form bleed air boost speed component (thrust component is added to this for total bleed air boost value)
        thrustCurveExponent = 0.75,                        -- Exponent for the thrust curve from 0 to Mach 1.0 (higher = more aggressive increase)
        thrustCurveLevel = 0.3,                            -- Level of thrust increase/decrease with speed: >0 increases thrust, <0 decreases thrust, 0 is neutral
        supersonicDeratingFactor = 0.7,                    -- Multiplier for thrust above Mach 1.0 due to shock intake effects (0-1, where 1 = no derate)
    },
    turboshaft = {
        present = false
    }
}


return config
