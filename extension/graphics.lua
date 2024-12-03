-- T-180 CSP Graphics Script
-- Authored by ohyeah2389

local flameTest = ac.Particles.Flame({color = rgbm(0.2, 0.6, 1, 1), size = 3.5, temperatureMultiplier = 2, flameIntensity = 0.8})

---@diagnostic disable-next-line: duplicate-set-field
function script.update(dt)
    ac.boostFrameRate()

    --flameTest:emit(vec3(0.0, 0.77, -2.5), vec3(car.localVelocity.x * 0.05, 0, -1.5) + (car.localVelocity * -0.4), 0.1 + car.gas * 1)
end
