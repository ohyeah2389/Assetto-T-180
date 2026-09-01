-- T-180 Effect Coordinates - Type A
-- Authored by ohyeah2389

local config = {
    turbojetType = "single",
    turboshaftPresent = false,
    turbines = {
        rear = {
            position = vec3(0.0, 0.38, -2.61),
            fuelPumpOffset = vec3(0, -0.07, 1.3),
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