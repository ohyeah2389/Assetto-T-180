-- T-180 Effect Coordinates - Mach 6
-- Authored by ohyeah2389

local config = {
    turbojetType = nil, -- "single" or "dual" or nil if not present
    turboshaftPresent = true, -- true or false

    coordinates = {
        turbineExhaust = vec3(0.0, 0.38, -2.61)
    },
    flame = {
        color = rgbm(1, 1, 1, 1),
        afterburnerColor = rgbm(1, 1, 1, 1),
        size = 3.2,
        temperatureMultiplier = 8,
        afterburnerTemperatureMultiplier = 10,
        intensity = 0.9,
        afterburnerIntensity = 1
    }
}

return config