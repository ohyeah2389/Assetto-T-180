-- T-180 Effect Coordinates - Mach 6
-- Authored by ohyeah2389

local config = {
    turbojetType = "single", -- "single" or "dual" or nil if not present
    turboshaftPresent = false, -- true or false

    coordinates = {
        turbineExhaust = vec3(0.0, 0.774, -2.69)
    },
    flame = {
        color = rgbm(1, 0.8, 0.7, 1),
        afterburnerColor = rgbm(1, 0.8, 0.7, 1),
        size = 3.2,
        temperatureMultiplier = 1.0,
        afterburnerTemperatureMultiplier = 1.2,
        intensity = 0.9,
        afterburnerIntensity = 1
    }
}

return config