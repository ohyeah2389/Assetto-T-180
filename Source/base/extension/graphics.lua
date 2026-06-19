-- T-180 CSP Graphics Script
-- Authored by ohyeah2389

DEBUG = false

Config = require("car_coordinates")
Physics = ac.getCarPhysics(0) or {}

local fuelPumpRPMLUT = ac.DataLUT11():add(0, 4000):add(6000, 5000):add(18000, 4500)
local turbineExhaustGlow = ac.findMeshes(Config.turbineExhaustGlowMesh):ensureUniqueMaterials()
local turbineDamageGlow = ac.findMeshes(Config.turbineDamageGlowMesh):ensureUniqueMaterials()
local turbineExhaustGlowThrottleBaseColor = rgbm(20, 20, 40, 1)
local turbineExhaustGlowAfterburnerBaseColor = rgbm(20, 20, 20, 1)
local turbineDamageGlowBaseColor = rgbm(30, 7.5, 0, 1)
local turbineExhaustGlowColor = rgbm()
local turbineDamageGlowColor = rgbm()
local flameVectorDefault = vec3(0, 0, -3)
local particlePos = vec3()
local baseVel = vec3()
local smokeVel = vec3()

local debugLabels = {
    rear = Config.turbojetType == "single" and "TJ Single" or "TS Rear",
    left = "TJ Left",
    right = "TJ Right",
    front = "TS Front"
}

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
        color = Config.flame.color,
        size = Config.flame.size,
        temperatureMultiplier = Config.flame.temperatureMultiplier,
        flameIntensity = Config.flame.intensity
    }),
    flameTurbo = ac.Particles.Flame({
        color = Config.flame.afterburnerColor,
        size = Config.flame.size,
        temperatureMultiplier = Config.flame.afterburnerTemperatureMultiplier,
        flameIntensity = Config.flame.afterburnerIntensity
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
    front = sound("jumpjack", vec3(0, 0, 0), nil, nil, 2.5, nil, false),
    rear = sound("jumpjack", vec3(0, 0, 0), nil, nil, 2.5, nil, false),
    all = sound("jumpjack", vec3(0, 0, 0), nil, nil, 2.5, nil, false),
    chargeL = sound("jumpjack_charge", vec3(0, 0, 0), nil, nil, 0.5, nil, false),
    chargeR = sound("jumpjack_charge", vec3(0, 0, 0), nil, nil, 0.5, nil, false),
    chargeFr = sound("jumpjack_charge", vec3(0, 0, 0), nil, nil, 0.5, nil, false),
    chargeRe = sound("jumpjack_charge", vec3(0, 0, 0), nil, nil, 0.5, nil, false),
    controlLeft = ac.ControlButton("__EXT_LIGHT_JUMPJACK_LEFT"),
    controlRight = ac.ControlButton("__EXT_LIGHT_JUMPJACK_RIGHT"),
    controlFront = ac.ControlButton("__EXT_LIGHT_JUMPJACK_FRONT"),
    controlRear = ac.ControlButton("__EXT_LIGHT_JUMPJACK_REAR"),
    leftLast = false,
    rightLast = false,
    frontLast = false,
    rearLast = false,
    allLast = false
}

-- MARK: Lighting Config
local headlightLeft = ac.accessCarLight("LIGHT_HEADLIGHT_1")
local headlightRight = ac.accessCarLight("LIGHT_HEADLIGHT_2")
local headlightFade = 0
local lightConfig = {
    color = rgb(27, 25, 22),
    singleFrequency = 0,
    rangeGradientOffset = 0.2,
    secondSpotIntensity = 0.2,
    secondSpot = 160,
    spot = 40,
    spotSharpness = 0.2
}

headlightLeft.direction = vec3(0.1, 0, 1)
headlightRight.direction = vec3(-0.1, 0, 1)

-- MARK: Turbine Audio System
local turbines = {}
local turbineData = {
    rear = { throttle = 0, thrust = 0, rpm = 0, fuelPumpEnabled = 0, afterburner = 0, damage = 0 },
    left = { throttle = 0, thrust = 0, rpm = 0, fuelPumpEnabled = 0, afterburner = 0, damage = 0 },
    right = { throttle = 0, thrust = 0, rpm = 0, fuelPumpEnabled = 0, afterburner = 0, damage = 0 },
    front = { throttle = 0, thrust = 0, rpm = 0, fuelPumpEnabled = 0, afterburner = 0, damage = 0 }
}

local function setTurbineData(targetTurbine, throttle, thrust, rpm, fuelPumpEnabled, afterburner, damage)
    targetTurbine.throttle = throttle
    targetTurbine.thrust = thrust
    targetTurbine.rpm = rpm
    targetTurbine.fuelPumpEnabled = fuelPumpEnabled
    targetTurbine.afterburner = afterburner
    targetTurbine.damage = damage
end

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

-- Turbine audio
for name, value in pairs(Config.turbines or {}) do
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
    local inputs = Physics.scriptControllerInputs
    setTurbineData(turbineData.rear, 0, 0, 0, 0, 0, 0)
    setTurbineData(turbineData.left, 0, 0, 0, 0, 0, 0)
    setTurbineData(turbineData.right, 0, 0, 0, 0, 0, 0)
    setTurbineData(turbineData.front, 0, 0, 0, 0, 0, 0)

    if Config.turbojetType == "single" then
        setTurbineData(
            turbineData.rear,
            inputs[8] or 0,
            inputs[9] or 0,
            inputs[10] or 0,
            inputs[11] or 0,
            inputs[12] or 0,
            inputs[18] or 0
        )
    elseif Config.turbojetType == "dual" then
        setTurbineData(
            turbineData.left,
            inputs[8] or 0,
            inputs[9] or 0,
            inputs[10] or 0,
            inputs[11] or 0,
            inputs[12] or 0,
            inputs[18] or 0
        )
        setTurbineData(
            turbineData.right,
            inputs[13] or 0,
            inputs[14] or 0,
            inputs[15] or 0,
            inputs[16] or 0,
            inputs[17] or 0,
            inputs[19] or 0
        )
    end

    if Config.turboshaftPresent then
        if Config.turbojetType ~= "single" then
            setTurbineData(
                turbineData.rear,
                inputs[8] or 0,
                inputs[9] or 0,
                (inputs[10] or 0) * 2.25,
                inputs[11] or 0,
                inputs[12] or 0,
                inputs[19] or 0
            )
        end
        if Config.turbojetType ~= "dual" then
            setTurbineData(
                turbineData.front,
                inputs[13] or 0,
                inputs[14] or 0,
                (inputs[15] or 0) * 2.25,
                inputs[16] or 0,
                inputs[17] or 0,
                inputs[18] or 0
            )
        end
    end

    -- Audio systems
    for name, turbine in pairs(turbines) do
        local data = turbineData[name]
        if turbine.main and not turbine.main:isPlaying() then turbine.main:start() end
        if turbine.fuelPump and not turbine.fuelPump:isPlaying() then turbine.fuelPump:start() end
        if data and data.rpm and data.rpm > 0 then
            updateTurbineAudio(turbine, data.rpm, data.throttle, data.afterburner, data.damage, data.fuelPumpEnabled, dt)
        end
    end

    -- Particle effects
    local flameVector = Config.vector or flameVectorDefault

    for name, exhaustGroup in pairs(Config.exhausts or {}) do
        local data = turbineData[name]
        if data and data.rpm and data.rpm > 0 then
            local boostAmount = mapRange(data.throttle, 0.9, 1, 0, 1, true) * mapRange(car.speedKmh, 0, 400, 0.5, 0.1, true)
            local turboAmount = data.afterburner * mapRange(car.speedKmh, 0, 400, 0.6, 0.06, true)
            local smokeVelocityScale = mapRange(data.throttle, 0, 1, 10, 20, true)
            local smokeAmount = mapRange(data.throttle, 0, 1, 0.05, 0.2, true) * (1 + data.afterburner)

            for _, pos in ipairs(exhaustGroup) do
                particlePos:set(pos.x + car.localVelocity.x * 0.012, pos.y, pos.z + car.localVelocity.z * 0.01)

                baseVel:set(flameVector)
                if pos.x < 0.0 then baseVel.x = -baseVel.x end
                baseVel:addScaled(car.localVelocity, -0.35)

                smokeVel:setScaled(baseVel, smokeVelocityScale)

                particles.flameBoost:emit(particlePos, baseVel, boostAmount)
                particles.flameTurbo:emit(particlePos, baseVel, turboAmount)
                particles.exhaustSmoke:emit(particlePos, smokeVel, smokeAmount)
            end
        end
    end

    -- Exhaust glow
    local glowThrottle = 0
    local glowAfterburner = 0
    local glowDamage = 0

    if Config.turbojetType == "single" then
        glowThrottle = turbineData.rear.throttle or 0
        glowAfterburner = turbineData.rear.afterburner or 0
        glowDamage = (turbineData.rear.damage or 0) ^ 1.5
    elseif Config.turbojetType == "dual" then
        -- Use max of both engines for glow effect
        glowThrottle = math.max(turbineData.left.throttle or 0, turbineData.right.throttle or 0)
        glowAfterburner = math.max(turbineData.left.afterburner or 0, turbineData.right.afterburner or 0)
        glowDamage = math.max((turbineData.left.damage or 0) ^ 1.5, (turbineData.right.damage or 0) ^ 1.5)
    elseif Config.turboshaftPresent then
        glowThrottle = turbineData.rear.throttle or 0
        glowAfterburner = turbineData.rear.afterburner or 0
        glowDamage = (turbineData.rear.damage or 0) ^ 1.5
    end

    turbineExhaustGlowColor:set(turbineExhaustGlowThrottleBaseColor, glowThrottle):addScaled(turbineExhaustGlowAfterburnerBaseColor, glowAfterburner)
    turbineDamageGlowColor:set(turbineDamageGlowBaseColor, glowDamage)

    turbineExhaustGlow:setMaterialProperty("ksEmissive", turbineExhaustGlowColor)
    turbineDamageGlow:setMaterialProperty("ksEmissive", turbineDamageGlowColor)

    -- Headlights
    headlightFade = math.lerp(headlightFade, car.headlightsActive and 1 or 0, dt * 15)

    for k, v in pairs(lightConfig) do
        headlightLeft[k] = v
        headlightRight[k] = v
    end

    headlightLeft.intensity = headlightFade
    headlightRight.intensity = headlightFade

    -- Jump jack logic
    local jumpJackAll = car.extraA
    local jumpJackLeft = jumpJack.controlLeft:down()
    local jumpJackRight = jumpJack.controlRight:down()
    local jumpJackFront = jumpJack.controlFront:down()
    local jumpJackRear = jumpJack.controlRear:down()

    if jumpJackAll and not jumpJack.allLast then
        jumpJack.chargeL:start()
        jumpJack.chargeR:start()
    elseif jumpJackAll ~= jumpJack.allLast then
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

    if jumpJackFront and not jumpJack.frontLast then
        jumpJack.chargeFr:start()
    elseif not jumpJackFront and jumpJack.frontLast then
        jumpJack.chargeFr:stop()
        jumpJack.front:start()
    end

    if jumpJackRear and not jumpJack.rearLast then
        jumpJack.chargeRe:start()
    elseif not jumpJackRear and jumpJack.rearLast then
        jumpJack.chargeRe:stop()
        jumpJack.rear:start()
    end

    jumpJack.allLast = jumpJackAll
    jumpJack.leftLast = jumpJackLeft
    jumpJack.rightLast = jumpJackRight
    jumpJack.frontLast = jumpJackFront
    jumpJack.rearLast = jumpJackRear

    -- Debug output
    if DEBUG then
        ac.debug("Config: Turbojet Type", Config.turbojetType or "N/A")
        ac.debug("Config: Turboshaft Present", Config.turboshaftPresent and "Yes" or "No")

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
end
