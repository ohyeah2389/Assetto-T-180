-- Mach 5 CSP Physics Script - State Module
-- Authored by ohyeah2389


local config = require('script_config')


local state = {
    control = {
        countersteer = 0.0; -- Angle of countersteer: 0 if neutral or steering into slide, up to steering max angle (e.g. 90) if steering against slide
        lockedRears = false; -- Whether the rears are locked forwards
        lockedFronts = false; -- Whether the fronts are locked forwards
        rearAntiCrab = false; -- Whether the rear anti-crab is engaged
        spinMode = false; -- Whether spin mode is engaged
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
        throttle = 0.0;
        thrust = 0.0;
        fuelPumpEnabled = true;
        clutchDisconnected = false;
        fuelConsumption = 0.0; -- Fuel consumption in liters per second
        fuelLevel = 100.0; -- Fuel level in liters
        bleedBoost = 0.0;
    };
}


return state