-- T-180 CSP Physics Script - State Module
-- Authored by ohyeah2389


local state = {
    control = {
        countersteer = 0.0,     -- Angle of countersteer: 0 if neutral or steering into slide, up to steering max angle (e.g. 90) if steering against slide
        lockedRears = false,    -- Whether the rears are locked forwards
        lockedFronts = false,   -- Whether the fronts are locked forwards
        rearAntiCrab = false,   -- Whether the rear anti-crab is engaged
        spinMode = false,       -- Whether spin mode is engaged
        driftInversion = false, -- True when the car is sliding backwards in a 360 spin
    },
    electricSystem = nil,
    jumpJackSystem = {
        jackFL = {
            active = false,
            position = 0.0,
        },
        jackFR = {
            active = false,
            position = 0.0,
        },
        jackRL = {
            active = false,
            position = 0.0,
        },
        jackRR = {
            active = false,
            position = 0.0,
        },
    }
}

return state
