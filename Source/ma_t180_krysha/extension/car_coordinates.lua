-- T-180 Effect Coordinates - Krysha
-- Authored by ohyeah2389

local config = {
    turbojetType = "single", -- "single" or "dual" or nil if not present
    turboshaftPresent = false, -- true or false

    coordinates = {
        turbineExhaust = vec3(0, 0.9, -2.149),
        turbineExhaustLeft = vec3(0.268, 0.618, -1.665),
        turbineExhaustRight = vec3(-0.268, 0.618, -1.665),
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
