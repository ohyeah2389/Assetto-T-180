-- T-180 Effect Coordinates - Mach 6
-- Authored by ohyeah2389

local config = {
    turbojetType = "single", -- "single" or "dual" or nil if not present
    turboshaftPresent = false, -- true or false

    coordinates = {
        turbineExhaust = vec3(0.0, 0.494, -1.91)
    },
    flame = {
        color = rgbm(0, 0, 0, 0),
        afterburnerColor = rgbm(0, 0, 0, 0),
        size = 0,
        temperatureMultiplier = 8,
        afterburnerTemperatureMultiplier = 10,
        intensity = 0,
        afterburnerIntensity = 0
    }
}

return config