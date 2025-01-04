-- Mach 5 CSP Physics Script - State Module
-- Authored by ohyeah2389


local config = require('script_config')


local state = {
    control = {
        countersteer = 0.0; -- Angle of countersteer: 0 if neutral or steering into slide, up to steering max angle (e.g. 90) if steering against slide
    },
    electricSystem = nil,
    thrusterForce = 0.0,
    jumpJackSystem = {
        jackFL = {
            position = 0.0;
        };
        jackFR = {
            position = 0.0;
        };
        jackRL = {
            position = 0.0;
        };
        jackRR = {
            position = 0.0;
        };
    };
}


return state