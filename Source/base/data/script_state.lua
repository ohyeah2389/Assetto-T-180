-- Mach 5 CSP Physics Script - State Module
-- Authored by ohyeah2389


local state = {
    control = {
        countersteer = 0.0; -- Angle of countersteer: 0 if neutral or steering into slide, up to steering max angle (e.g. 90) if steering against slide
        lockedRears = false; -- Whether the rears are locked forwards
        lockedFronts = false; -- Whether the fronts are locked forwards
        rearAntiCrab = false; -- Whether the rear anti-crab is engaged
        spinMode = false; -- Whether spin mode is engaged
        driftInversion = false; -- True when the car is sliding backwards in a 360 spin
    },
    electricSystem = nil,
    jumpJackSystem = {
        jackFL = {
            active = false,
            position = 0.0;
        };
        jackFR = {
            active = false,
            position = 0.0;
        };
        jackRL = {
            active = false,
            position = 0.0;
        };
        jackRR = {
            active = false,
            position = 0.0;
        };
    };
    turbine = {
        -- Legacy/shared fields for compatibility
        throttle = 0.0,
        throttleAfterburner = 0.0,
        thrust = 0.0,
        torque = 0.0,
        fuelPumpEnabled = true,
        rpm = 0.0,
        feedbackTorque = 0.0,
        fuelConsumption = 0.0,
        fuelLevel = 100.0,
        bleedBoost = 0.0,

        -- Dual turbine specific fields
        front = {
            throttle = 0.0,
            throttleAfterburner = 0.0,
            outputTorque = 0.0,
            fuelPumpEnabled = true,
            rpm = 0.0,
            feedbackTorque = 0.0,
            warnings = {},
            cautions = {}
        },
        rear = {
            throttle = 0.0,
            throttleAfterburner = 0.0, 
            outputTorque = 0.0,
            fuelPumpEnabled = true,
            rpm = 0.0,
            feedbackTorque = 0.0,
            warnings = {},
            cautions = {}
        }
    },
    warnings = {},
    cautions = {}
}



return state