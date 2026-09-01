-- T-180 Effect Coordinates - Krysha
-- Authored by ohyeah2389

local config = {
    turbojetType = "single",
    turboshaftPresent = false,
    turbines = {
        rear = {
            position = vec3(0, 0.9, -2.15),
            fuelPumpOffset = vec3(0, -0.07, 1.3),
            volume = 0.8,
            fuelPumpVolume = 0.45
        }
    },
    exhausts = {
        rear = {
            vec3(0.295, 0.892, -2.13),
            vec3(-0.295, 0.892, -2.13),
        }
    },
    plume = {
        radiusStart = 0.115,
        radiusChoke = 0.13,
        radiusEnd = 0.1,
        chokeFixedLength = 0.2,
        color = rgb(1, 0.1, 1),
        length = 3,
        fadePower = 2.5,
    },
    turbineDamageGlowMesh = "turbina"
}

return config
