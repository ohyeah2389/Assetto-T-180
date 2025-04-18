-- T-180 CSP Graphics Script
-- Authored by ohyeah2389

local config = require("car_coordinates")

local car_phys = ac.getCarPhysics(0)

local flameBoost = ac.Particles.Flame({
    color = config.flame.color, 
    size = config.flame.size, 
    temperatureMultiplier = config.flame.temperatureMultiplier, 
    flameIntensity = config.flame.intensity
})

local flameTurbo = ac.Particles.Flame({
    color = config.flame.afterburnerColor, 
    size = config.flame.size, 
    temperatureMultiplier = config.flame.afterburnerTemperatureMultiplier, 
    flameIntensity = config.flame.afterburnerIntensity
})

local exhaustSmoke = ac.Particles.Smoke({color = rgbm(0.3, 0.32, 0.35, 0.1), life = 10, size = 0.1, spreadK = 1, growK = 1, targetYVelocity = 1, flags = ac.Particles.SmokeFlags.FadeIn})

local light_headlight_left = ac.accessCarLight("LIGHT_HEADLIGHT_1")
local light_headlight_right = ac.accessCarLight("LIGHT_HEADLIGHT_2")
local lightFadeout = 0

local audio_engine = ac.AudioEvent("/cars/" .. ac.getCarID(0) .. "/engine_custom", true, true)
audio_engine.cameraInteriorMultiplier = 0.5
audio_engine.volume = 0.8
audio_engine:setPosition(vec3(0.0, 1.2, 0.225), vec3(0, 0, 1), vec3(0, 1, 0))
audio_engine:start()

-- Rear turbine audio
local audio_turbine = ac.AudioEvent("/cars/" .. ac.getCarID(0) .. "/turbine", true, true)
audio_turbine.cameraInteriorMultiplier = 0.5
audio_turbine.volume = 0.8
audio_turbine:setPosition(vec3(0, 0.772, -2.05), vec3(0, 1, 0), vec3(0, 0, -1))
audio_turbine:start()

local audio_turbine_fuelpump = ac.AudioEvent("/cars/" .. ac.getCarID(0) .. "/turbine_fuelpump", true, true)
audio_turbine_fuelpump.cameraInteriorMultiplier = 0.5
audio_turbine_fuelpump.volume = 0.45
audio_turbine_fuelpump:setPosition(vec3(0, 0.7, -0.75), vec3(0, 0, 1), vec3(0, 1, 0))
audio_turbine_fuelpump:start()

-- Front turbine audio
local audio_turbine_front = ac.AudioEvent("/cars/" .. ac.getCarID(0) .. "/turbine", true, true)
audio_turbine_front.cameraInteriorMultiplier = 0.5
audio_turbine_front.volume = 0.8
audio_turbine_front:setPosition(vec3(0, 0.772, 1.05), vec3(0, 0, 1), vec3(0, 1, 0))
audio_turbine_front:start()

local audio_turbine_fuelpump_front = ac.AudioEvent("/cars/" .. ac.getCarID(0) .. "/turbine_fuelpump", true, true)
audio_turbine_fuelpump_front.cameraInteriorMultiplier = 0.5
audio_turbine_fuelpump_front.volume = 0.45
audio_turbine_fuelpump_front:setPosition(vec3(0, 0.7, 0.75), vec3(0, 0, 1), vec3(0, 1, 0))
audio_turbine_fuelpump_front:start()

local fuelPumpRPMLUT = ac.DataLUT11()
fuelPumpRPMLUT:add(0, 4000)
fuelPumpRPMLUT:add(6000, 5000)
fuelPumpRPMLUT:add(18000, 4500)
local fuelPumpFadeout = 0

local jumpJackSound_left = ac.AudioEvent("/cars/" .. ac.getCarID(0) .. "/jumpjack", true, true)
jumpJackSound_left.cameraInteriorMultiplier = 0.5
jumpJackSound_left.volume = 2.5
local jumpJackSound_right = ac.AudioEvent("/cars/" .. ac.getCarID(0) .. "/jumpjack", true, true)
jumpJackSound_right.cameraInteriorMultiplier = 0.5
jumpJackSound_right.volume = 2.5
local jumpJackSound_all = ac.AudioEvent("/cars/" .. ac.getCarID(0) .. "/jumpjack", true, true)
jumpJackSound_all.cameraInteriorMultiplier = 0.5
jumpJackSound_all.volume = 2.5

local jumpJackSound_chargeL = ac.AudioEvent("/cars/" .. ac.getCarID(0) .. "/jumpjack_charge", true, true)
jumpJackSound_chargeL.volume = 0.5
jumpJackSound_chargeL.cameraInteriorMultiplier = 0.5
local jumpJackSound_chargeR = ac.AudioEvent("/cars/" .. ac.getCarID(0) .. "/jumpjack_charge", true, true)
jumpJackSound_chargeR.volume = 0.5
jumpJackSound_chargeR.cameraInteriorMultiplier = 0.5


local jumpJack_left_last = false
local jumpJack_right_last = false
local extraA_last = false

-- Add these variables at the top level, with the other local variables
local replayFadeouts = {
    throttle = 0,
    thrust = 0,
    rpm = 4000,
    afterburner = 0,
    frontThrottle = 0,
    frontThrust = 0,
    frontRpm = 4000,
    frontAfterburner = 0
}

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

    local ctrlrData = {
        -- Rear turbine data
        turbineThrottle = car_phys.scriptControllerInputs[8] or 0,
        turbineThrust = car_phys.scriptControllerInputs[9] or 0,
        turbineRPM = car_phys.scriptControllerInputs[10] or 0,
        fuelPumpEnabled = car_phys.scriptControllerInputs[11] or 0,
        turbineAfterburner = car_phys.scriptControllerInputs[12] or 0,
        turbineDamage = car_phys.scriptControllerInputs[18] or 0,
        -- Front turbine data
        frontTurbineThrottle = car_phys.scriptControllerInputs[13] or 0,
        frontTurbineThrust = car_phys.scriptControllerInputs[14] or 0,
        frontTurbineRPM = car_phys.scriptControllerInputs[15] or 0,
        frontFuelPumpEnabled = car_phys.scriptControllerInputs[16] or 0,
        frontTurbineAfterburner = car_phys.scriptControllerInputs[17] or 0,
        frontTurbineDamage = car_phys.scriptControllerInputs[19] or 0
    }

    if ac.isInReplayMode() then
        -- Calculate target values
        local targetThrottle = math.min(car.gas + (car.extraB and 1 or 0), 1)
        local targetThrust = math.min(((car.rpm / 2) / car.rpmLimiter) + (car.extraB and 1 or 0), 1)
        local targetRPM = (math.min(car.gas + (car.extraB and 1 or 0), 1) * 10000) + 4000
        local targetAfterburner = car.extraB and 1 or 0

        -- Apply fadeouts with lerp
        replayFadeouts.throttle = math.lerp(replayFadeouts.throttle, targetThrottle, dt * 5)
        replayFadeouts.thrust = math.lerp(replayFadeouts.thrust, targetThrust, dt * 5)
        replayFadeouts.rpm = math.lerp(replayFadeouts.rpm, targetRPM, dt * 1)
        replayFadeouts.afterburner = math.lerp(replayFadeouts.afterburner, targetAfterburner, dt * 8)

        -- Front turbine replay handling
        replayFadeouts.frontThrottle = math.lerp(replayFadeouts.frontThrottle, targetThrottle, dt * 5)
        replayFadeouts.frontThrust = math.lerp(replayFadeouts.frontThrust, targetThrust, dt * 5)
        replayFadeouts.frontRpm = math.lerp(replayFadeouts.frontRpm, targetRPM, dt * 1)
        replayFadeouts.frontAfterburner = math.lerp(replayFadeouts.frontAfterburner, targetAfterburner, dt * 8)

        -- Apply faded values
        ctrlrData.turbineThrottle = replayFadeouts.throttle
        ctrlrData.turbineThrust = replayFadeouts.thrust
        ctrlrData.turbineRPM = replayFadeouts.rpm
        ctrlrData.fuelPumpEnabled = 1
        ctrlrData.turbineAfterburner = replayFadeouts.afterburner * (ac.getCarID(0) == "ohyeah2389_t180_fumee" and 0 or 1)
        ctrlrData.turbineDamage = 0

        -- Front turbine faded values
        ctrlrData.frontTurbineThrottle = replayFadeouts.frontThrottle
        ctrlrData.frontTurbineThrust = replayFadeouts.frontThrust
        ctrlrData.frontTurbineRPM = replayFadeouts.frontRpm
        ctrlrData.frontFuelPumpEnabled = 1
        ctrlrData.frontTurbineAfterburner = replayFadeouts.frontAfterburner * (ac.getCarID(0) == "ohyeah2389_t180_fumee" and 0 or 1)
        ctrlrData.frontTurbineDamage = 0
    end

    if not audio_turbine:isPlaying() then audio_turbine:start() end
    if not audio_turbine_fuelpump:isPlaying() then audio_turbine_fuelpump:start() end
    if not audio_turbine_front:isPlaying() then audio_turbine_front:start() end
    if not audio_turbine_fuelpump_front:isPlaying() then audio_turbine_fuelpump_front:start() end
    if not audio_engine:isPlaying() then audio_engine:start() end

    fuelPumpFadeout = math.lerp(fuelPumpFadeout, ctrlrData.fuelPumpEnabled, dt * 5)
    local frontFuelPumpFadeout = math.lerp(fuelPumpFadeout, ctrlrData.frontFuelPumpEnabled, dt * 5)

    audio_engine:setParam("rpms", car.rpm)
    audio_engine:setParam("throttle", car.gas)

    -- Rear turbine audio
    audio_turbine:setParam("rpm", ctrlrData.turbineRPM)
    audio_turbine:setParam("throttle", ctrlrData.turbineThrottle)
    audio_turbine:setParam("afterburner", ctrlrData.turbineAfterburner)
    audio_turbine_fuelpump:setParam("rpm", fuelPumpRPMLUT:get(ctrlrData.turbineRPM) * fuelPumpFadeout)
    audio_turbine:setParam("damage", ctrlrData.turbineDamage)

    -- Front turbine audio
    audio_turbine_front:setParam("rpm", ctrlrData.frontTurbineRPM)
    audio_turbine_front:setParam("throttle", ctrlrData.frontTurbineThrottle)
    audio_turbine_front:setParam("afterburner", ctrlrData.frontTurbineAfterburner)
    audio_turbine_fuelpump_front:setParam("rpm", fuelPumpRPMLUT:get(ctrlrData.frontTurbineRPM) * frontFuelPumpFadeout)
    audio_turbine_front:setParam("damage", ctrlrData.frontTurbineDamage)

    flameBoost:emit(vec3(config.coordinates.turbineExhaust.x + car.localVelocity.x * 0.012, config.coordinates.turbineExhaust.y, config.coordinates.turbineExhaust.z + car.localVelocity.z * 0.01),
        vec3(0 + car.localVelocity.x * 0.01, 0, -3) + (car.localVelocity * -0.35),
        mapRange(ctrlrData.turbineThrottle, 0.9, 1, 0, 1, true) * mapRange(car.speedKmh, 0, 400, 0.5, 0.1, true))

    flameTurbo:emit(vec3(config.coordinates.turbineExhaust.x + car.localVelocity.x * 0.012, config.coordinates.turbineExhaust.y, config.coordinates.turbineExhaust.z + car.localVelocity.z * 0.01),
        vec3(0 + car.localVelocity.x * 0.01, 0, -1.5) + (car.localVelocity * -0.35),
        ctrlrData.turbineThrust * mapRange(car.speedKmh, 0, 400, 1, 0.1, true) * 0.5)

    exhaustSmoke:emit(vec3(config.coordinates.turbineExhaust.x + car.localVelocity.x * 0.012, config.coordinates.turbineExhaust.y, config.coordinates.turbineExhaust.z + car.localVelocity.z * 0.01),
        vec3(0 + car.localVelocity.x * 0.01, 0, -30 * mapRange(car.gas, 0, 1, 0.5, 1, true)) + (car.localVelocity * -0.35),
        mapRange(ctrlrData.turbineThrust, 0, 1, 0.2, 0.4, true))


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

    if car.extraA and not extraA_last then
        jumpJackSound_chargeL:start()
        jumpJackSound_chargeR:start()
    elseif car.extraA ~= extraA_last then
        jumpJackSound_chargeL:stop()
        jumpJackSound_chargeR:stop()
        jumpJackSound_all:start()
    end

    if ac.ControlButton("__EXT_LIGHT_JUMPJACK_RIGHT"):down() and not jumpJack_right_last then
        jumpJackSound_chargeR:start()
    elseif not ac.ControlButton("__EXT_LIGHT_JUMPJACK_RIGHT"):down() and jumpJack_right_last then
        jumpJackSound_chargeR:stop()
        jumpJackSound_right:start()
    end

    if ac.ControlButton("__EXT_LIGHT_JUMPJACK_LEFT"):down() and not jumpJack_left_last then
        jumpJackSound_chargeL:start()
    elseif not ac.ControlButton("__EXT_LIGHT_JUMPJACK_LEFT"):down() and jumpJack_left_last then
        jumpJackSound_chargeL:stop()
        jumpJackSound_left:start()
    end

    extraA_last = car.extraA
    jumpJack_left_last = ac.ControlButton("__EXT_LIGHT_JUMPJACK_LEFT"):down()
    jumpJack_right_last = ac.ControlButton("__EXT_LIGHT_JUMPJACK_RIGHT"):down()

    -- Debug section
    ac.debug("audio_engine.isPlaying", audio_engine:isPlaying())
    ac.debug("audio_turbine.isPlaying", audio_turbine:isPlaying())
    ac.debug("audio_turbine_fuelpump.isPlaying", audio_turbine_fuelpump:isPlaying())
    ac.debug("audio_turbine_front.isPlaying", audio_turbine_front:isPlaying())
    ac.debug("audio_turbine_fuelpump_front.isPlaying", audio_turbine_fuelpump_front:isPlaying())
    ac.debug("ctrlrData.turbineThrottle", ctrlrData.turbineThrottle)
    ac.debug("ctrlrData.turbineThrust", ctrlrData.turbineThrust)
    ac.debug("ctrlrData.turbineRPM", ctrlrData.turbineRPM)
    ac.debug("ctrlrData.fuelPumpEnabled", ctrlrData.fuelPumpEnabled)
    ac.debug("ctrlrData.turbineAfterburner", ctrlrData.turbineAfterburner)
    ac.debug("ctrlrData.frontTurbineThrottle", ctrlrData.frontTurbineThrottle)
    ac.debug("ctrlrData.frontTurbineThrust", ctrlrData.frontTurbineThrust)
    ac.debug("ctrlrData.frontTurbineRPM", ctrlrData.frontTurbineRPM)
    ac.debug("ctrlrData.frontFuelPumpEnabled", ctrlrData.frontFuelPumpEnabled)
    ac.debug("ctrlrData.frontTurbineAfterburner", ctrlrData.frontTurbineAfterburner)
    ac.debug("car.name", ac.getCarID(0))
    
end


