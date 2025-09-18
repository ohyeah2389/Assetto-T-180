-- T-180 Effect Coordinates - Mach 4
-- Authored by ohyeah2389

local config = {
    turbojetType = "single", -- "single" or "dual" or nil if not present
    turboshaftPresent = false, -- true or false

    coordinates = {
        turbineExhausts = {
            vec3(0.0, 0.684, -2.79)
        }
    },
    flame = {
        color = rgbm(1.0, 0.8, 0.75, 1),
        afterburnerColor = rgbm(1.0, 0.9, 0.8, 1),
        size = 3.2,
        temperatureMultiplier = 2,
        afterburnerTemperatureMultiplier = 2,
        intensity = 0.9,
        afterburnerIntensity = 1
    },
    turbineExhaustGlowMesh = "Mach6Turbine_SUB3"
}

return config