-- T-180 Effect Coordinates - Demo Car
-- Authored by ohyeah2389

local config = {
    turbojetType = "single",
    turboshaftPresent = false,
    turbines = {
        rear = {
            position = vec3(0, 0.77, -2.5),
            fuelPumpOffset = vec3(0, -0.07, 1.3),
            volume = 0.8,
            fuelPumpVolume = 0.45
        }
    },
    exhausts = {
        rear = {
            vec3(0, 0.77, -2.65)
        }
    },
    plume = {
        radiusStart = 0.0,
        radiusChoke = 0.155,
        radiusEnd = 0.1,
        chokeFixedLength = 0.35,
        fadePower = 0.6,
    },
    turbineDamageGlowMesh = "Turbine"
}

return config
