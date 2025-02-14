-- T-180 CSP Graphics Script
-- Authored by ohyeah2389

local coordinates = require("car_coordinates")

local car_phys = ac.getCarPhysics(0)

local flameBoost = ac.Particles.Flame({color = rgbm(1, 0.8, 0.8, 1), size = 3.2, temperatureMultiplier = 2, flameIntensity = 0.9})
local flameTurbo = ac.Particles.Flame({color = rgbm(1, 1, 1, 1), size = 3.2, temperatureMultiplier = 1, flameIntensity = 1})

local exhaustSmoke = ac.Particles.Smoke({color = rgbm(0.3, 0.32, 0.35, 0.1), life = 10, size = 0.1, spreadK = 1, growK = 1, targetYVelocity = 1, flags = ac.Particles.SmokeFlags.FadeIn})

local light_headlight_left = ac.accessCarLight("LIGHT_HEADLIGHT_1")
local light_headlight_right = ac.accessCarLight("LIGHT_HEADLIGHT_2")
local lightFadeout = 0

local audio_engine = ac.AudioEvent("/cars/" .. ac.getCarID(0) .. "/engine_custom", true, true)
audio_engine.cameraInteriorMultiplier = 0.5
audio_engine:setPosition(vec3(0, 0.5, -1.5), vec3(0, 0, 1), vec3(0, 1, 0))
audio_engine:start()

local audio_turbine = ac.AudioEvent("/cars/" .. ac.getCarID(0) .. "/turbine", true, true)
audio_turbine.cameraInteriorMultiplier = 0.5

audio_turbine:setPosition(vec3(0, 0.772, -2.05), vec3(0, 0, 1), vec3(0, 1, 0))
audio_turbine:start()

local audio_turbine_fuelpump = ac.AudioEvent("/cars/" .. ac.getCarID(0) .. "/turbine_fuelpump", true, true)
audio_turbine_fuelpump.cameraInteriorMultiplier = 0.5
audio_turbine_fuelpump.volume = 0.5
audio_turbine_fuelpump:setPosition(vec3(0, 0.7, -0.75), vec3(0, 0, 1), vec3(0, 1, 0))
audio_turbine_fuelpump:start()

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

local afterburnerMeshExpand = ac.findMeshes("AftbExpand")
local afterburnerMeshOutside = ac.findMeshes("AftbOutside?")
local afterburnerMeshCone = ac.findMeshes("AftbCone?")
local afterburnerMeshExpand_originalLocation = afterburnerMeshExpand:getPosition()
local afterburnerMeshOutside_originalLocation = afterburnerMeshOutside:getPosition()
local afterburnerMeshCone_originalLocation = afterburnerMeshCone:getPosition()
local shockConeMesh = ac.findMeshes("ShockCone")
local shockConeNode = ac.findNodes("ShockConeParent")
local shockConeNode_originalLocation = shockConeNode:getPosition()


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

    if not audio_turbine:isPlaying() then audio_turbine:start() end
    if not audio_turbine_fuelpump:isPlaying() then audio_turbine_fuelpump:start() end
    if not audio_engine:isPlaying() then audio_engine:start() end

    fuelPumpFadeout = math.lerp(fuelPumpFadeout, car_phys.scriptControllerInputs[11], dt * 5)

    audio_engine:setParam("rpms", car.rpm)
    audio_engine:setParam("throttle", car.gas)

    audio_turbine:setParam("rpm", car_phys.scriptControllerInputs[10])
    audio_turbine:setParam("throttle", car_phys.scriptControllerInputs[8])
    audio_turbine:setParam("afterburner", car_phys.scriptControllerInputs[12])

    audio_turbine_fuelpump:setParam("rpm", fuelPumpRPMLUT:get(car_phys.scriptControllerInputs[10]) * fuelPumpFadeout)

    flameBoost:emit(vec3(coordinates.turbine_exhaust.x + car.localVelocity.x * 0.012, coordinates.turbine_exhaust.y, coordinates.turbine_exhaust.z + car.localVelocity.z * 0.01),
        vec3(0 + car.localVelocity.x * 0.01, 0, -3) + (car.localVelocity * -0.35),
        mapRange(car_phys.scriptControllerInputs[8], 0.9, 1, 0, 1, true) * mapRange(car.speedKmh, 0, 400, 0.5, 0.1, true))

    flameTurbo:emit(vec3(coordinates.turbine_exhaust.x + car.localVelocity.x * 0.012, coordinates.turbine_exhaust.y, coordinates.turbine_exhaust.z + car.localVelocity.z * 0.01),
        vec3(0 + car.localVelocity.x * 0.01, 0, -1.5) + (car.localVelocity * -0.35),
        car_phys.scriptControllerInputs[9] * mapRange(car.speedKmh, 0, 400, 1, 0.1, true) * 0.5)

    exhaustSmoke:emit(vec3(coordinates.turbine_exhaust.x + car.localVelocity.x * 0.012, coordinates.turbine_exhaust.y, coordinates.turbine_exhaust.z + car.localVelocity.z * 0.01),
        vec3(0 + car.localVelocity.x * 0.01, 0, -30 * mapRange(car.gas, 0, 1, 0.5, 1, true)) + (car.localVelocity * -0.35),
        mapRange(car_phys.scriptControllerInputs[9], 0, 1, 0.2, 0.4, true))


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

    afterburnerMeshExpand:setShadows(false)
    afterburnerMeshExpand:setMaterialTexture('txDiffuse', rgbm(0.1, 0.1, 0.1, car_phys.scriptControllerInputs[12]))
    afterburnerMeshExpand:setMaterialProperty("alpha", car_phys.scriptControllerInputs[12] * 0.2 * mapRange(math.perlin(sim.time * 0.1, 1, 0.5), 0, 1, 0.2, 1, true))
    afterburnerMeshExpand:setMaterialProperty("ksAmbient", car_phys.scriptControllerInputs[12])
    afterburnerMeshExpand:setMaterialProperty("ksEmissive", rgb(4, 8, 24) * car_phys.scriptControllerInputs[12] * 20)

    afterburnerMeshOutside:setShadows(false)
    afterburnerMeshOutside:setMaterialTexture('txDiffuse', rgbm(0.1, 0.1, 0.1, car_phys.scriptControllerInputs[12]))
    afterburnerMeshOutside:setMaterialProperty("alpha", car_phys.scriptControllerInputs[12] * 0.2 * mapRange(math.perlin(sim.time * 0.1, 1, 0.5), 0, 1, 0.2, 1, true))
    afterburnerMeshOutside:setMaterialProperty("ksAmbient", car_phys.scriptControllerInputs[12])
    afterburnerMeshOutside:setMaterialProperty("ksEmissive", rgb(24, 8, 4) * car_phys.scriptControllerInputs[12] * 20)

    afterburnerMeshCone:setShadows(false)
    afterburnerMeshCone:setMaterialTexture('txDiffuse', rgbm(0.1, 0.1, 0.1, car_phys.scriptControllerInputs[12]))
    afterburnerMeshCone:setMaterialProperty("alpha", car_phys.scriptControllerInputs[12] * 0.2 * mapRange(math.perlin(sim.time * 0.1, 1, 0.5), 0, 1, 0.2, 1, true))
    afterburnerMeshCone:setMaterialProperty("ksAmbient", car_phys.scriptControllerInputs[12])
    afterburnerMeshCone:setMaterialProperty("ksEmissive", rgb(20, 12, 4) * car_phys.scriptControllerInputs[12] * 20)

    afterburnerMeshExpand:setPosition(afterburnerMeshExpand_originalLocation + vec3(0.02 * math.sin(sim.time * 0.1), 0.02 * math.sin(sim.time * 0.4), 0.02 * math.sin(sim.time * 0.7)))
    afterburnerMeshOutside:setPosition(afterburnerMeshOutside_originalLocation + vec3(0.02 * math.sin(sim.time * 0.2), 0.02 * math.sin(sim.time * 0.5), 0.02 * math.sin(sim.time * 0.8)))
    afterburnerMeshCone:setPosition(afterburnerMeshCone_originalLocation + vec3(0.02 * math.sin(sim.time * 0.3), 0.02 * math.sin(sim.time * 0.6), 0.02 * math.sin(sim.time * 0.9)))

    if car.speedKmh > 950 then
        local shockEffect = mapRange(car.speedKmh, 950, 1050, 0, 1, true) * mapRange(car.speedKmh, 1200, 1300, 1, 0, true)
        shockConeMesh:setMaterialProperty("alpha", mapRange(math.perlin(sim.time * 0.01, 3, 0.5) * shockEffect, 0, 1, 0.2, 3, true))
        shockConeNode:setPosition(shockConeNode_originalLocation + vec3(0.02 * math.sin(sim.time * 0.2), 0.02 * math.sin(sim.time * 0.3), 0.02 * math.sin(sim.time * 0.1)))
    else
        shockConeMesh:setMaterialProperty("alpha", 0)
    end

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
end


