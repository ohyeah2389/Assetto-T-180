-- T-180 CSP Physics Script - Config and Parameters Module
-- Authored by ohyeah2389


local config = {
    misc = {
        brakeAutoHold = {
            torque = 200, -- Brake torque in Nm to apply when auto-holding the brakes
            speed = 10,   -- Speed in kmh below which to auto-hold the brakes
        },
        debugFrequency = 0.1,
        jumpJackSize = 1,
        traditionalSteering = true,
    },
    turbojet = {
        present = false,
    },
    turboshaft = {
        present = false
    }
}


return config
