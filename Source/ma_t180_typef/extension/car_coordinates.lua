-- T-180 Effect Coordinates - Type F
-- Authored by ohyeah2389

local config = {
    turbojetType = "single",
    turboshaftPresent = false,
    turbines = {
        rear = {
            position = vec3(0.0, 0.321, -2.2),
            fuelPumpOffset = vec3(0, -0.07, 1.3),
            volume = 0.8,
            fuelPumpVolume = 0.45
        }
    },
    exhausts = {
        rear = {
            vec3(0.2155, 0.4925, -2.29),
            vec3(-0.2155, 0.4925, -2.29)
        }
    },
    flame = {
        color = rgbm(1, 0.8, 0.7, 1),
        afterburnerColor = rgbm(1, 0.8, 0.7, 1),
        size = 3.5,
        temperatureMultiplier = 1,
        afterburnerTemperatureMultiplier = 1.5,
        intensity = 0.8,
        afterburnerIntensity = 0.9
    },
    turbineDamageGlowMesh = "exhausts"
}

return config
