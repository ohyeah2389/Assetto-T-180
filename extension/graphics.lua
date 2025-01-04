-- T-180 CSP Graphics Script
-- Authored by ohyeah2389

local car_phys = ac.getCarPhysics(0)

local flameBoost = ac.Particles.Flame({color = rgbm(0.2, 0.6, 1, 1), size = 3.5, temperatureMultiplier = 2, flameIntensity = 0.8})
local flameTurbo = ac.Particles.Flame({color = rgbm(1, 0.4, 0.2, 1), size = 3.5, temperatureMultiplier = 2, flameIntensity = 0.8})

local light_headlight_left = ac.accessCarLight("LIGHT_HEADLIGHT_1")
local light_headlight_right = ac.accessCarLight("LIGHT_HEADLIGHT_2")
local lightFadeout = 0

-- math helper function, like Map Range in Blender
local function mapRange(n, start, stop, newStart, newStop, withinBounds)
    local value = ((n - start) / (stop - start)) * (newStop - newStart) + newStart

    -- Returns basic value
    if not withinBounds then
        return value
    end

    -- Returns values constrained to exact range
    if newStart < newStop then
        return math.max(math.min(value, newStop), newStart)
    else
        return math.max(math.min(value, newStart), newStop)
    end
end

---@diagnostic disable-next-line: duplicate-set-field
function script.update(dt)
    ac.boostFrameRate()

    flameBoost:emit(vec3(0.0 + car.localVelocity.x * 0.008, 0.77, -2.5 + car.localVelocity.z * 0.01), vec3(0, 0, -1.5) + (car.localVelocity * -0.35), 0.1 + car_phys.scriptControllerInputs[4] * mapRange(car.speedKmh, 0, 400, 5, 0.4, true))
    flameTurbo:emit(vec3(0.0 + car.localVelocity.x * 0.008, 0.77, -2.5 + car.localVelocity.z * 0.01), vec3(0, 0, -1.5) + (car.localVelocity * -0.35), 0.1 + car_phys.scriptControllerInputs[5] * mapRange(car.speedKmh, 0, 400, 0.5, 0.1, true))
    
    lightFadeout = math.lerp(lightFadeout, car.headlightsActive and 1 or 0, dt * 15)

    light_headlight_left.color = rgb(27, 25, 22)
    light_headlight_left.singleFrequency = 0
    light_headlight_left.intensity = 0.5 * lightFadeout
    light_headlight_left.rangeGradientOffset = 0.2
    light_headlight_left.secondSpotIntensity = 0.2
    light_headlight_left.secondSpot = 160
    light_headlight_left.spot = 40
    light_headlight_left.spotSharpness = 0.2
    light_headlight_left.direction = vec3(0.1, 0, 1)
    
    light_headlight_right.color = rgb(27, 25, 22)
    light_headlight_right.singleFrequency = 0
    light_headlight_right.intensity = 0.5 * lightFadeout
    light_headlight_right.rangeGradientOffset = 0.2
    light_headlight_right.secondSpotIntensity = 0.2
    light_headlight_right.secondSpot = 160
    light_headlight_right.spot = 40
    light_headlight_right.spotSharpness = 0.2
    light_headlight_right.direction = vec3(-0.1, 0, 1)
end
