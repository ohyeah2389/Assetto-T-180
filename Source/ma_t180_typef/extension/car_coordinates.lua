-- T-180 Effect Coordinates - Type F
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
            vec3(0.2155, 0.4925, -2.29),
            vec3(-0.2155, 0.4925, -2.29)
        }
    },
    plume = {
        radiusStart = 0.0,
        radiusChoke = 0.125,
        radiusEnd = 0.07,
        chokeFixedLength = 0.2,
        tempK = 4000,
    },
    turbineDamageGlowMesh = "exhausts"
}

return config
