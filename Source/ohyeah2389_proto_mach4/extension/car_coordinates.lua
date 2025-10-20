-- T-180 Effect Coordinates - Mach 4
-- Authored by ohyeah2389

local config = {
    turbojetType = "single",
    turboshaftPresent = false,
    turbines = {
        rear = {
            position = vec3(0.0, 0.684, -2.79),
            fuelPumpOffset = vec3(0, -0.07, 1.3),
            volume = 0.8,
            fuelPumpVolume = 0.45
        }
    },
    exhausts = {
        rear = {
            vec3(0.0, 0.684, -2.79)
        }
    },
    flame = {
        color = rgbm(1.0, 0.8, 0.75, 1),
        afterburnerColor = rgbm(1.0, 0.9, 0.8, 1),
        size = 3.2,
        temperatureMultiplier = 2,
        afterburnerTemperatureMultiplier = 2,
        intensity = 0.9,
        afterburnerIntensity = 1
    },
    turbineExhaustGlowMesh = "Thruster.001_SUB1",
    turbineDamageGlowMesh = "Thruster.001_SUB0"
}

return config