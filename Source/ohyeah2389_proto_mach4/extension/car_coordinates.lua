-- T-180 Effect Coordinates - Mach 4
-- Authored by ohyeah2389

local config = {
    turbojetType = "single",
    turboshaftPresent = false,
    turbines = {
        rear = {
            position = vec3(0.0, 0.684, -2.79),
            fuelPumpOffset = vec3(0, -0.07, 1.3),
            volume = 0.8,
            fuelPumpVolume = 0.45
        }
    },
    exhausts = {
        rear = {
            vec3(0.0, 0.688, -2.8)
        }
    },
    plume = {
        radiusStart = 0.0,
        radiusChoke = 0.11,
        radiusEnd = 0.06,
        chokeFixedLength = 0.25,
        color = rgbm(0.1, 0.4, 1),
        fadePower = 4,
        length = 2,
    },
    turbineExhaustGlowMesh = "Thruster.001_SUB1",
    turbineDamageGlowMesh = "Thruster.001_SUB0"
}

return config