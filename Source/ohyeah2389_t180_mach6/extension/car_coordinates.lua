-- T-180 Effect Coordinates - Mach 6
-- Authored by ohyeah2389

local config = {
    turbojetType = "single",
    turboshaftPresent = false,
    turbines = {
        rear = {
            position = vec3(0.0, 0.494, -1.91),
            fuelPumpOffset = vec3(0, -0.07, 1.3),
            volume = 0.8,
            fuelPumpVolume = 0.45
        }
    },
    exhausts = {
        rear = {
            vec3(0.0, 0.494, -2.3)
        }
    },
    plume = {
        radiusStart = 0.18,
        radiusChoke = 0.11,
        radiusEnd = 0.06,
        chokeFixedLength = 0.2,
        color = rgbm(0.1, 0.4, 1),
        fadePower = 2,
        length = 1.5,
    },
    turbineExhaustGlowMesh = "Mach6Turbine_SUB3",
    turbineDamageGlowMesh = "Mach6Turbine_SUB0"
}

return config