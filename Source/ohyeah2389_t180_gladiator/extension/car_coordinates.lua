-- T-180 Effect Coordinates - Gladiator
-- Authored by ohyeah2389

local config = {
    turbojetType = "single",
    turboshaftPresent = false,
    turbines = {
        rear = {
            position = vec3(0.0, 0.321, -2.2),
            fuelPumpOffset = vec3(0, -0.07, 1.3),
            volume = 0.8,
            fuelPumpVolume = 0.45
        }
    },
    exhausts = {
        rear = {
            vec3(0.0, 0.321, -2.2)
        }
    },
    plume = {
        radiusStart = 0.2,
        radiusChoke = 0.18,
        radiusEnd = 0.1,
        chokeFixedLength = 0.0,
        fadePower = 0.5,
        tempK = 1800,
    },
    turbineDamageGlowMesh = "GladiatorTurbine_SUB0"
}

return config
