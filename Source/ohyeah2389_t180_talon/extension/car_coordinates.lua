-- T-180 Effect Coordinates - Talon
-- Authored by ohyeah2389

local config = {
    turbojetType = "dual",
    turboshaftPresent = false,
    turbines = {
        left = {
            position = vec3(-0.268, 0.618, -1.665),
            fuelPumpOffset = vec3(0, -0.07, 1.3),
            volume = 0.7,
            fuelPumpVolume = 0.40
        },
        right = {
            position = vec3(0.268, 0.618, -1.665),
            fuelPumpOffset = vec3(0, -0.07, 1.3),
            volume = 0.7,
            fuelPumpVolume = 0.40
        }
    },
    exhausts = {
        left = {
            vec3(-0.268, 0.62, -1.77)
        },
        right = {
            vec3(0.268, 0.62, -1.77)
        }
    },
    plume = {
        radiusStart = 0.0,
        radiusChoke = 0.13,
        radiusEnd = 0.1,
        chokeFixedLength = 0.3
    },
    turbineDamageGlowMesh = "TalonEngines_SUB0"
}

return config
