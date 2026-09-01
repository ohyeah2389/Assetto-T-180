-- T-180 Effect Coordinates - Hangul
-- Authored by ohyeah2389

local config = {
    turbojetType = "single",
    turboshaftPresent = false,
    turbines = {
        rear = {
            position = vec3(0.0, 0.754, -2.623), -- Average of exhaust positions
            fuelPumpOffset = vec3(0, -0.07, 1.3),
            volume = 0.8,
            fuelPumpVolume = 0.45
        }
    },
    exhausts = {
        rear = {
            vec3(0.0, 0.872, -2.59),
            vec3(0.134, 0.692, -2.64),
            vec3(-0.134, 0.692, -2.64)
        }
    },
    plume = {
        radiusStart = 0.0,
        radiusChoke = 0.1,
        radiusEnd = 0.05,
        chokeFixedLength = 0.15,
    },
    turbineDamageGlowMesh = "turbina.001"
}

return config