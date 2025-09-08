-- T-180 Effect Coordinates - Corsair
-- Authored by ohyeah2389

local config = {
    turbojetType = "single", -- "single" or "dual" or nil if not present
    turboshaftPresent = false, -- true or false

    coordinates = {
        turbineExhausts = {
            vec3(0.0, 0.321, -2.2)
        }
    },
    flame = {
        color = rgbm(1, 0.8, 0.7, 1),
        afterburnerColor = rgbm(1, 1, 1, 1),
        size = 3.5,
        temperatureMultiplier = 1,
        afterburnerTemperatureMultiplier = 1.5,
        intensity = 0.9,
        afterburnerIntensity = 1
    }
}

return config
