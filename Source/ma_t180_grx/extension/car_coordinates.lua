-- T-180 Effect Coordinates - GRX
-- Authored by ohyeah2389

local config = {
    turbojetType = "single",
    turboshaftPresent = false,
    turbines = {
        rear = {
            position = vec3(0, 1.0, -1.2), -- Average of all exhaust positions
            fuelPumpOffset = vec3(0, -0.07, 1.3),
            volume = 0.8,
            fuelPumpVolume = 0.45
        }
    },
    exhausts = {
        rear = {
            vec3(0.391, 0.907, -0.525),
            vec3(0.257, 0.996, -1.15),
            vec3(0.214, 1.08, -1.6),
            vec3(0.168, 1.09, -2.0),
            vec3(-0.391, 0.907, -0.525),
            vec3(-0.257, 0.996, -1.15),
            vec3(-0.214, 1.08, -1.6),
            vec3(-0.168, 1.09, -2.0)
        }
    },
    flame = {
        color = rgbm(1, 0.8, 0.7, 1),
        afterburnerColor = rgbm(1, 0.9, 0.8, 1),
        size = 2.0,
        temperatureMultiplier = 0.95,
        afterburnerTemperatureMultiplier = 1.15,
        intensity = 0.5,
        afterburnerIntensity = 0.65
    },
    vector = vec3(0.35, 1.8, -1.0),
    turbineDamageGlowMesh = "air_intake"
}

return config