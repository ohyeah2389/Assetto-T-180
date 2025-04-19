-- T-180 Effect Coordinates - Talon
-- Authored by ohyeah2389

local config = {
    turbojetType = "dual", -- "single" or "dual" or nil if not present
    turboshaftPresent = false, -- true or false

    coordinates = {
        turbineExhaust = vec3(0, 0.77, -2.5),
        turbineExhaustLeft = vec3(0.268, 0.618, -1.665),
        turbineExhaustRight = vec3(-0.268, 0.618, -1.665),
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
