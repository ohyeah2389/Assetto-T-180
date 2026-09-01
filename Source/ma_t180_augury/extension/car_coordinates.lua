-- T-180 Effect Coordinates - Augury
-- Authored by ohyeah2389

local config = {
    turbojetType = "single",
    turboshaftPresent = false,
    turbines = {
        rear = {
            position = vec3(0, 1.108, -2.479),
            fuelPumpOffset = vec3(0, -0.07, 1.3),
            volume = 0.8,
            fuelPumpVolume = 0.45
        }
    },
    exhausts = {
        rear = {
            vec3(0, 1.108, -2.45)
        }
    },
    plume = {
        radiusStart = 0.115,
        radiusChoke = 0.1,
        radiusEnd = 0.06,
        chokeFixedLength = 0.1
    },
    turbineDamageGlowMesh = "turbine"
}

return config
