-- T-180 Effect Coordinates - Demo Car
-- Authored by ohyeah2389

local config = {
    coordinates = {
        turbineExhaust = vec3(0, 0.77, -2.5)
    },
    flame = {
        color = rgbm(1, 0.8, 0.8, 1),
        afterburnerColor = rgbm(1, 1, 1, 1),
        size = 3.2,
        temperatureMultiplier = 1,
        afterburnerTemperatureMultiplier = 2,
        intensity = 0.9,
        afterburnerIntensity = 1
    }
}

return config
