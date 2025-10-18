-- T-180 CSP Graphics Script
-- Authored by ohyeah2389

local config = require("car_coordinates")
local car_phys = ac.getCarPhysics(0)


local fuelPumpRPMLUT = ac.DataLUT11():add(0, 4000):add(6000, 5000):add(18000, 4500)
local turbineExhaustGlow = ac.findMeshes(config.turbineExhaustGlowMesh)


-- MARK: Helper Functions
local function mapRange(n, start, stop, newStart, newStop, withinBounds)
    local value = ((n - start) / (stop - start)) * (newStop - newStart) + newStart
    if not withinBounds then return value end
    if newStart < newStop then
        return math.max(math.min(value, newStop), newStart)
    else
        return math.max(math.min(value, newStart), newStop)
    end
end

local function sound(eventName, position, direction, up, volume, interiorMult, autoStart)
    local audio = ac.AudioEvent("/cars/" .. ac.getCarID(0) .. "/" .. eventName, true, true)
    audio.cameraInteriorMultiplier = interiorMult or 0.5
    audio.volume = volume or 0.8
    audio:setPosition(position, direction or vec3(0, 1, 0), up or vec3(0, 0, -1))
    if autoStart ~= false then audio:start() end
    return audio
end


-- MARK: Particle Systems
local particles = {
    flameBoost = ac.Particles.Flame({
        color = config.flame.color,
        size = config.flame.size,
        temperatureMultiplier = config.flame.temperatureMultiplier,
        flameIntensity = config.flame.intensity
    }),
    flameTurbo = ac.Particles.Flame({
        color = config.flame.afterburnerColor,
        size = config.flame.size,
        temperatureMultiplier = config.flame.afterburnerTemperatureMultiplier,
        flameIntensity = config.flame.afterburnerIntensity
    }),
    exhaustSmoke = ac.Particles.Smoke({
        color = rgbm(0.3, 0.32, 0.35, 0.08),
        life = 10,
        size = 0.1,
        spreadK = 3,
        growK = 3,
        targetYVelocity = 0.5,
        flags = ac.Particles.SmokeFlags.FadeIn
    })
}

-- MARK: Jump Jack Config
local jumpJack = {
    left = sound("jumpjack", vec3(0, 0, 0), nil, nil, 2.5, nil, false),
    right = sound("jumpjack", vec3(0, 0, 0), nil, nil, 2.5, nil, false),
    all = sound("jumpjack", vec3(0, 0, 0), nil, nil, 2.5, nil, false),
    chargeL = sound("jumpjack_charge", vec3(0, 0, 0), nil, nil, 0.5, nil, false),
    chargeR = sound("jumpjack_charge", vec3(0, 0, 0), nil, nil, 0.5, nil, false),
    leftLast = false,
    rightLast = false,
    extraALast = false
}

-- MARK: Lighting Config
local lighting = {
    headlightLeft = ac.accessCarLight("LIGHT_HEADLIGHT_1"),
    headlightRight = ac.accessCarLight("LIGHT_HEADLIGHT_2"),
    fadeout = 0
}


-- MARK: Turbine Audio System
local turbines = {}

local function updateTurbineAudio(turbine, rpm, throttle, afterburner, damage, fuelPumpEnabled, dt)
    if not turbine then return end

    if turbine.main then
        turbine.main:setParam("rpm", rpm)
        turbine.main:setParam("throttle", throttle)
        turbine.main:setParam("afterburner", afterburner or 0)
        turbine.main:setParam("damage", damage or 0)
    end

    if turbine.fuelPump then
        turbine.fadeoutState = math.lerp(turbine.fadeoutState, fuelPumpEnabled, dt * 5)
        turbine.fuelPump:setParam("rpm", fuelPumpRPMLUT:get(rpm) * turbine.fadeoutState)
    end
end




-- MARK: Initialization
-- Piston engine audio
local audio_engine = sound("engine_custom", vec3(0.0, 1.2, 0.225), vec3(0, 0, 1), vec3(0, 1, 0), 0.8)

-- Turbine audio
for name, value in pairs(config.turbines or {}) do
    local pos = value.position or vec3(0, 0, 0)
    local dir = value.direction or vec3(0, 1, 0)
    local up = value.up or vec3(0, 0, -1)
    local vol = value.volume or 0.8
    local pumpVol = value.fuelPumpVolume or 0.45
    local pumpOffset = value.fuelPumpOffset or vec3(0, -0.07, 1.3)

    turbines[name] = {
        main = sound("turbine", pos, dir, up, vol),
        fuelPump = sound("turbine_fuelpump", pos + pumpOffset, vec3(0, 0, 1), vec3(0, 1, 0), pumpVol),
        fadeoutState = 0
    }
end


-- MARK: Update
---@diagnostic disable-next-line: duplicate-set-field
function script.update(dt)
    ac.boostFrameRate()

    -- Parse turbine data from physics
    local inputs = car_phys.scriptControllerInputs
    local turbineData = { rear = {}, left = {}, right = {}, front = {} }

    if config.turbojetType == "single" then
        turbineData.rear = {
            throttle = inputs[8] or 0,
            thrust = inputs[9] or 0,
            rpm = inputs[10] or 0,
            fuelPumpEnabled = inputs[11] or 0,
            afterburner = inputs[12] or 0,
            damage = 0
        }
    elseif config.turbojetType == "dual" then
        turbineData.left = {
            throttle = inputs[8] or 0,
            thrust = inputs[9] or 0,
            rpm = inputs[10] or 0,
            fuelPumpEnabled = inputs[11] or 0,
            afterburner = inputs[12] or 0,
            damage = 0
        }
        turbineData.right = {
            throttle = inputs[13] or 0,
            thrust = inputs[14] or 0,
            rpm = inputs[15] or 0,
            fuelPumpEnabled = inputs[16] or 0,
            afterburner = inputs[17] or 0,
            damage = 0
        }
    end

    if config.turboshaftPresent then
        if config.turbojetType ~= "single" then
            local rpm = (inputs[10] or 0) * 2.25
            turbineData.rear = {
                throttle = inputs[8] or 0,
                thrust = inputs[9] or 0,
                rpm = rpm,
                fuelPumpEnabled = (rpm > 4500) and 1 or 0,
                afterburner = inputs[11] or 0,
                damage = inputs[19] or 0
            }
        end
        if config.turbojetType ~= "dual" then
            local rpm = (inputs[15] or 0) * 2.25
            turbineData.front = {
                throttle = inputs[13] or 0,
                thrust = inputs[14] or 0,
                rpm = rpm,
                fuelPumpEnabled = (rpm > 4500) and 1 or 0,
                afterburner = inputs[16] or 0,
                damage = inputs[18] or 0
            }
        end
    end

    -- Update audio systems
    if not audio_engine:isPlaying() then audio_engine:start() end
    audio_engine:setParam("rpms", car.rpm)
    audio_engine:setParam("throttle", car.gas)

    for name, turbine in pairs(turbines) do
        local data = turbineData[name]
        if turbine.main and not turbine.main:isPlaying() then turbine.main:start() end
        if turbine.fuelPump and not turbine.fuelPump:isPlaying() then turbine.fuelPump:start() end
        if data and data.rpm then
            updateTurbineAudio(turbine, data.rpm, data.throttle, data.afterburner, data.damage, data.fuelPumpEnabled, dt)
        end
    end

    -- Particle effects
    local flameVector = config.vector or vec3(0, 0, -3)
    local carVelComponent = car.localVelocity * -0.35
    local particleScale = mapRange(car.speedKmh, 0, 400, 1, 0.1, true)

    for name, exhaustGroup in pairs(config.exhausts or {}) do
        local data = turbineData[name]
        if data and data.rpm and data.rpm > 0 then
            for _, pos in ipairs(exhaustGroup) do
                local particlePos = vec3(pos.x + car.localVelocity.x * 0.012, pos.y, pos.z + car.localVelocity.z * 0.01)
                local baseVel = flameVector:clone():mul(vec3((pos.x < 0.0 and -1 or 1), 1, 1)) + carVelComponent

                particles.flameBoost:emit(particlePos, baseVel, mapRange(data.throttle, 0.9, 1, 0, 1, true) * mapRange(car.speedKmh, 0, 400, 0.5, 0.1, true))
                particles.flameTurbo:emit(particlePos, baseVel, data.afterburner * particleScale * 0.6)
                particles.exhaustSmoke:emit(particlePos, baseVel * mapRange(data.throttle, 0, 1, 10, 20, true), mapRange(data.throttle, 0, 1, 0.05, 0.2, true) * (1 + data.afterburner))
            end
        end
    end

    -- Exhaust glow
    local glowThrottle = turbineData.rear.throttle or 0
    local glowAfterburner = turbineData.rear.afterburner or 0
    turbineExhaustGlow:setMaterialProperty("ksEmissive", (vec3(2, 2, 4) * glowThrottle * 10) + (vec3(1, 1, 1) * glowAfterburner * 20))

    -- Headlights
    lighting.fadeout = math.lerp(lighting.fadeout, car.headlightsActive and 1 or 0, dt * 15)

    local lightConfig = {
        color = rgb(27, 25, 22),
        singleFrequency = 0,
        intensity = 0.5 * lighting.fadeout,
        rangeGradientOffset = 0.2,
        secondSpotIntensity = 0.2,
        secondSpot = 160,
        spot = 40,
        spotSharpness = 0.2
    }

    for k, v in pairs(lightConfig) do
        lighting.headlightLeft[k] = v
        lighting.headlightRight[k] = v
    end

    lighting.headlightLeft.direction = vec3(0.1, 0, 1)
    lighting.headlightRight.direction = vec3(-0.1, 0, 1)

    -- Jump jack logic
    local jumpJackLeft = ac.ControlButton("__EXT_LIGHT_JUMPJACK_LEFT"):down()
    local jumpJackRight = ac.ControlButton("__EXT_LIGHT_JUMPJACK_RIGHT"):down()

    if car.extraA and not jumpJack.extraALast then
        jumpJack.chargeL:start()
        jumpJack.chargeR:start()
    elseif car.extraA ~= jumpJack.extraALast then
        jumpJack.chargeL:stop()
        jumpJack.chargeR:stop()
        jumpJack.all:start()
    end

    if jumpJackRight and not jumpJack.rightLast then
        jumpJack.chargeR:start()
    elseif not jumpJackRight and jumpJack.rightLast then
        jumpJack.chargeR:stop()
        jumpJack.right:start()
    end

    if jumpJackLeft and not jumpJack.leftLast then
        jumpJack.chargeL:start()
    elseif not jumpJackLeft and jumpJack.leftLast then
        jumpJack.chargeL:stop()
        jumpJack.left:start()
    end

    jumpJack.extraALast = car.extraA
    jumpJack.leftLast = jumpJackLeft
    jumpJack.rightLast = jumpJackRight

    -- Debug output
    ac.debug("Config: Turbojet Type", config.turbojetType or "N/A")
    ac.debug("Config: Turboshaft Present", config.turboshaftPresent and "Yes" or "No")

    local debugLabels = {
        rear = config.turbojetType == "single" and "TJ Single" or "TS Rear",
        left = "TJ Left",
        right = "TJ Right",
        front = "TS Front"
    }

    for name, data in pairs(turbineData) do
        if data.rpm and data.rpm > 0 and debugLabels[name] then
            local label = debugLabels[name]
            ac.debug(label .. ": Thr", data.throttle)
            ac.debug(label .. ": RPM", data.rpm)
            ac.debug(label .. ": Thrust", data.thrust)
            ac.debug(label .. ": AB", data.afterburner)
            ac.debug(label .. ": Pump", data.fuelPumpEnabled)
            ac.debug(label .. ": Dmg", data.damage)
        end
    end
end
