-- T-180 Effect Coordinates - Mach 6
-- Authored by ohyeah2389

local config = {
    turbojetType = "single", -- "single" or "dual" or nil if not present
    turboshaftPresent = false, -- true or false

    coordinates = {
        turbineExhausts = {
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
    turbineExhaustGlowMesh = "Mach6Turbine_SUB3"
}

return config