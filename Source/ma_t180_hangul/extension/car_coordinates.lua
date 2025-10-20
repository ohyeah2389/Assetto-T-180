-- T-180 Effect Coordinates - Hangul
-- Authored by ohyeah2389

local config = {
    turbojetType = "single",
    turboshaftPresent = false,
    turbines = {
        rear = {
            position = vec3(0.0, 0.754, -2.623), -- Average of exhaust positions
            fuelPumpOffset = vec3(0, -0.07, 1.3),
            volume = 0.8,
            fuelPumpVolume = 0.45
        }
    },
    exhausts = {
        rear = {
            vec3(0.0, 0.872, -2.59),
            vec3(0.136, 0.695, -2.64),
            vec3(-0.136, 0.695, -2.64)
        }
    },
    flame = {
        color = rgbm(1, 0.8, 0.7, 1),
        afterburnerColor = rgbm(1, 0.8, 0.7, 1),
        size = 3.2,
        temperatureMultiplier = 1.0,
        afterburnerTemperatureMultiplier = 1.2,
        intensity = 0.9,
        afterburnerIntensity = 1
    },
    turbineDamageGlowMesh = "turbina.001"
}

return config