-- T-180 Effect Coordinates - Corsair
-- Authored by ohyeah2389

local config = {
    turbojetType = "single",
    turboshaftPresent = false,
    turbines = {
        rear = {
            position = vec3(0.0, 0.37, -2.37),
            fuelPumpOffset = vec3(0, -0.07, 1.3),
            volume = 0.8,
            fuelPumpVolume = 0.45
        }
    },
    exhausts = {
        rear = {
            vec3(0.0, 0.37, -2.37)
        }
    },
    plume = {
        radiusStart = 0.0,
        radiusChoke = 0.15,
        radiusEnd = 0.1,
        chokeFixedLength = 0.3,
        tempK = 1800,
        fadePower = 0.5,
    },
    turbineDamageGlowMesh = "Turbine.001"
}

return config
