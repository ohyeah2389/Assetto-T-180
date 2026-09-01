-- T-180 Effect Coordinates - Gigerbon
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
            vec3(0.347, 0.753, -2.38),
            vec3(-0.347, 0.753, -2.38),
        }
    },
    plume = {
        radiusStart = 0.03,
        radiusChoke = 0.15,
        radiusEnd = 0.08,
        chokeFixedLength = 0.25,
        color = rgb(0.6, 0.05, 1),
        length = 3.5,
        fadePower = 6
    },
    turbineDamageGlowMesh = "Cilindro.013"
}

return config
