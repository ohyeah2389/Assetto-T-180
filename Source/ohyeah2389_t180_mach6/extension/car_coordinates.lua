-- T-180 Effect Coordinates - Mach 6
-- Authored by ohyeah2389

local config = {
    turbojetType = "single",
    turboshaftPresent = false,
    turbines = {
        rear = {
            position = vec3(0.0, 0.494, -1.91),
            fuelPumpOffset = vec3(0, -0.07, 1.3),
            volume = 0.8,
            fuelPumpVolume = 0.45
        }
    },
    exhausts = {
        rear = {
            vec3(0.0, 0.494, -1.91)
        }
    },
    flame = {
        color = rgbm(1, 1, 1, 1),
        afterburnerColor = rgbm(1, 1, 1, 1),
        size = 3.2,
        temperatureMultiplier = 8,
        afterburnerTemperatureMultiplier = 10,
        intensity = 0.9,
        afterburnerIntensity = 1
    },
    turbineExhaustGlowMesh = "Mach6Turbine_SUB3",
    turbineDamageGlowMesh = "Mach6Turbine_SUB0"
}

return config