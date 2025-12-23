-- T-180 Effect Coordinates - Krysha
-- Authored by ohyeah2389

local config = {
    turbojetType = "single",
    turboshaftPresent = false,
    turbines = {
        rear = {
            position = vec3(0, 0.9, -2.15),
            fuelPumpOffset = vec3(0, -0.07, 1.3),
            volume = 0.8,
            fuelPumpVolume = 0.45
        }
    },
    exhausts = {
        rear = {
            vec3(0.298, 0.9, -2.15),
            vec3(-0.298, 0.9, -2.15),
        }
    },
    flame = {
        color = rgbm(0.8, 0.3, 1.0, 1),
        afterburnerColor = rgbm(0.8, 0.3, 1.0, 1),
        size = 3.2,
        temperatureMultiplier = 1,
        afterburnerTemperatureMultiplier = 1.2,
        intensity = 0.8,
        afterburnerIntensity = 0.9
    },
    turbineDamageGlowMesh = "turbina"
}

return config
