-- T-180 Effect Coordinates - Fumee
-- Authored by ohyeah2389

local config = {
    turbojetType = nil,
    turboshaftPresent = true,
    turbines = {
        rear = {
            position = vec3(0.0, 0.38, -2.61),
            fuelPumpOffset = vec3(0, -0.07, 1.3),
            volume = 0.8,
            fuelPumpVolume = 0.45
        },
        front = {
            position = vec3(0, 0.772, 1.05),
            direction = vec3(0, 0, 1), -- Front turbine faces forward
            fuelPumpOffset = vec3(0, -0.072, -0.3),
            volume = 0.8,
            fuelPumpVolume = 0.45
        }
    },
    exhausts = {
        rear = {
            vec3(0.0, 0.38, -2.61)
        }
    },
    turbineDamageGlowMesh = "FumeeBody.002"
}

return config
