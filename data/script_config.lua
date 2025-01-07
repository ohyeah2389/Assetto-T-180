-- T-180 CSP Physics Script - Config and Parameters Module
-- Authored by ohyeah2389


local game = require('script_acConnection')


local config = {
    misc = {
        brakeAutoHold = {
            torque = 100; -- Brake torque in Nm to apply when auto-holding the brakes
            speed = 10; -- Speed in kmh below which to auto-hold the brakes
        };
        debugFrequency = 0.1;
        jumpJackSize = 1;
    },
    electrics = {
        batteries = {
            mainBattery = {
                capacity = 150000, -- 150 kWh (Model S P100D = 100 kWh)
                ratedVoltage = 800, -- V (Nominal voltage)
                internalResistance = 0.1, -- 0.1 Ω
                socCurve = ac.DataLUT11.load("soc_curve_lithiumion.lut"),
            },
            mainSupercap = {
                capacity = 1500, -- Wh
                ratedVoltage = 800, -- V (Nominal voltage)
                capacitance = 500, -- F
                esr = 0.001, -- Ohms (Very low internal resistance)
            }
        },
        motors = {
            hubMotorConfig = {
                nominalVoltage = 800,        -- 800V nominal
                peakPower = 220000,          -- 220 kW peak power
                peakTorque = 2000,            -- 2000 Nm peak torque
                maxRPM = 20000,              -- Maximum motor speed
                resistance = 0.05,           -- 0.05Ω winding resistance
                inductance = 0.002,          -- 2mH inductance
                copperLossFactor = 1.0,
                ironLossFactor = 0.01,
                mechanicalLossFactor = 0.005,
                regenEfficiency = 0.7
            }
        },
        torqueSplit = {
            defaultFrontRatio = 0.45,     -- Default front torque ratio (0.45 = 45-55 front-rear split)
            maxFrontRatio = 0.6,         -- Maximum front ratio during countersteer (0.6 = 60-40 front-rear split)
            brakingFrontRatio = 0.55,     -- Front torque ratio during braking (0.55 = 55-45 front-rear split)
        },
        slipControl = {
            slipThreshold = 0.3, -- Slip ratio threshold
            cutStrength = 0.9, -- How aggressively TC cuts power
        }
    },
    turbine = {
        minThrottle = 0.2,
        throttleLag = 0.8, -- 0 to 1 where 1 represents unrealistically fast turbine throttle response and 0 represents no change in throttle
        gearRatio = 1.5, -- 1.5:1 gear ratio turbine:engine
        boostThrustFactor = 0.00001,
        boostSpeedFactor = 0.001,
    }
}


return config