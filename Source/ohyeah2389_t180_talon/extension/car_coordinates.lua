-- T-180 Effect Coordinates - Talon
-- Authored by ohyeah2389

local config = {
    turbojetType = "dual",
    turboshaftPresent = false,

    turbines = {
        left = {
            position = vec3(-0.268, 0.618, -1.665),
            fuelPumpOffset = vec3(0, -0.07, 1.3),
            volume = 0.7,
            fuelPumpVolume = 0.40
        },
        right = {
            position = vec3(0.268, 0.618, -1.665),
            fuelPumpOffset = vec3(0, -0.07, 1.3),
            volume = 0.7,
            fuelPumpVolume = 0.40
        }
    },

    exhausts = {
        left = {
            vec3(-0.268, 0.618, -1.665)
        },
        right = {
            vec3(0.268, 0.618, -1.665)
        }
    },
    
    flame = {
        color = rgbm(1, 0.8, 0.8, 1),
        afterburnerColor = rgbm(1, 0.9, 0.9, 1),
        size = 3.3,
        temperatureMultiplier = 1.0,
        afterburnerTemperatureMultiplier = 1.2,
        intensity = 0.5,
        afterburnerIntensity = 1.0
    }
}

return config
