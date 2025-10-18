-- T-180 Effect Coordinates - Swordfish
-- Authored by ohyeah2389

local config = {
    turbojetType = "single",
    turboshaftPresent = false,

    turbines = {
        rear = {
            position = vec3(0.0, 0.617, -2.1),
            fuelPumpOffset = vec3(0, -0.07, 1.3),
            volume = 0.8,
            fuelPumpVolume = 0.45
        }
    },

    exhausts = {
        rear = {
            vec3(0.0, 0.617, -2.1)
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
