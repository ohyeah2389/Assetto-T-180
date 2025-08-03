-- T-180 CSP Graphics Script
-- Authored by ohyeah2389

local coordsConfig = require("car_coordinates")

local car_phys = ac.getCarPhysics(0)

local flameBoost = ac.Particles.Flame({
    color = coordsConfig.flame.color,
    size = coordsConfig.flame.size,
    temperatureMultiplier = coordsConfig.flame.temperatureMultiplier,
    flameIntensity = coordsConfig.flame.intensity
})

local flameTurbo = ac.Particles.Flame({
    color = coordsConfig.flame.afterburnerColor,
    size = coordsConfig.flame.size,
    temperatureMultiplier = coordsConfig.flame.afterburnerTemperatureMultiplier,
    flameIntensity = coordsConfig.flame.afterburnerIntensity
})

local exhaustSmoke = ac.Particles.Smoke({
    color = rgbm(0.3, 0.32, 0.35, 0.1),
    life = 10,
    size = 0.1,
    spreadK = 2,
    growK = 3,
    targetYVelocity = 0.5,
    flags =
        ac.Particles.SmokeFlags.FadeIn
})

local light_headlight_left = ac.accessCarLight("LIGHT_HEADLIGHT_1")
local light_headlight_right = ac.accessCarLight("LIGHT_HEADLIGHT_2")
local lightFadeout = 0

local turbineExhaustGlow = ac.findMeshes(coordsConfig.turbineExhaustGlowMesh)

local audio_engine = ac.AudioEvent("/cars/" .. ac.getCarID(0) .. "/engine_custom", true, true)
audio_engine.cameraInteriorMultiplier = 0.5
audio_engine.volume = 0.8
audio_engine:setPosition(vec3(0.0, 1.2, 0.225), vec3(0, 0, 1), vec3(0, 1, 0))
audio_engine:start()

-- Turbojet Audio Sources
local audio_turbine_rear = nil
local audio_turbine_fuelpump_rear = nil
local audio_turbine_left = nil
local audio_turbine_fuelpump_left = nil
local audio_turbine_right = nil
local audio_turbine_fuelpump_right = nil

if coordsConfig.turbojetType and coordsConfig.coordinates.turbineExhausts then
    if coordsConfig.turbojetType == "single" then
        -- For single turbojet, use the center/average position of all exhausts
        local centerPos = vec3(0, 0, 0)
        for _, pos in ipairs(coordsConfig.coordinates.turbineExhausts) do
            centerPos = centerPos + pos
        end
        centerPos = centerPos / #coordsConfig.coordinates.turbineExhausts
        
        audio_turbine_rear = ac.AudioEvent("/cars/" .. ac.getCarID(0) .. "/turbine", true, true)
        audio_turbine_rear.cameraInteriorMultiplier = 0.5
        audio_turbine_rear.volume = 0.8
        audio_turbine_rear:setPosition(centerPos, vec3(0, 1, 0), vec3(0, 0, -1))
        audio_turbine_rear:start()

        audio_turbine_fuelpump_rear = ac.AudioEvent("/cars/" .. ac.getCarID(0) .. "/turbine_fuelpump", true, true)
        audio_turbine_fuelpump_rear.cameraInteriorMultiplier = 0.5
        audio_turbine_fuelpump_rear.volume = 0.45
        audio_turbine_fuelpump_rear:setPosition(
            vec3(centerPos.x, centerPos.y - 0.07, centerPos.z + 1.3), vec3(0, 0, 1), vec3(0, 1, 0))
        audio_turbine_fuelpump_rear:start()
    elseif coordsConfig.turbojetType == "dual" then
        -- For dual turbojet, automatically find left and right positions
        local leftPos = nil
        local rightPos = nil
        
        for _, pos in ipairs(coordsConfig.coordinates.turbineExhausts) do
            if pos.x < 0 then
                -- Left side (negative x)
                if not leftPos then
                    leftPos = pos
                else
                    -- If multiple left positions, use the average
                    leftPos = (leftPos + pos) / 2
                end
            elseif pos.x > 0 then
                -- Right side (positive x)
                if not rightPos then
                    rightPos = pos
                else
                    -- If multiple right positions, use the average
                    rightPos = (rightPos + pos) / 2
                end
            end
            -- Skip center positions (x == 0) for dual setup
        end
        
        -- Create left turbine audio if left position exists
        if leftPos then
            audio_turbine_left = ac.AudioEvent("/cars/" .. ac.getCarID(0) .. "/turbine", true, true)
            audio_turbine_left.cameraInteriorMultiplier = 0.5
            audio_turbine_left.volume = 0.7
            audio_turbine_left:setPosition(leftPos, vec3(0, 1, 0), vec3(0, 0, -1))
            audio_turbine_left:start()

            audio_turbine_fuelpump_left = ac.AudioEvent("/cars/" .. ac.getCarID(0) .. "/turbine_fuelpump", true, true)
            audio_turbine_fuelpump_left.cameraInteriorMultiplier = 0.5
            audio_turbine_fuelpump_left.volume = 0.40
            audio_turbine_fuelpump_left:setPosition(
                vec3(leftPos.x, leftPos.y - 0.07, leftPos.z + 1.3), vec3(0, 0, 1), vec3(0, 1, 0))
            audio_turbine_fuelpump_left:start()
        end
        
        -- Create right turbine audio if right position exists
        if rightPos then
            audio_turbine_right = ac.AudioEvent("/cars/" .. ac.getCarID(0) .. "/turbine", true, true)
            audio_turbine_right.cameraInteriorMultiplier = 0.5
            audio_turbine_right.volume = 0.7
            audio_turbine_right:setPosition(rightPos, vec3(0, 1, 0), vec3(0, 0, -1))
            audio_turbine_right:start()

            audio_turbine_fuelpump_right = ac.AudioEvent("/cars/" .. ac.getCarID(0) .. "/turbine_fuelpump", true, true)
            audio_turbine_fuelpump_right.cameraInteriorMultiplier = 0.5
            audio_turbine_fuelpump_right.volume = 0.40
            audio_turbine_fuelpump_right:setPosition(
                vec3(rightPos.x, rightPos.y - 0.07, rightPos.z + 1.3), vec3(0, 0, 1), vec3(0, 1, 0))
            audio_turbine_fuelpump_right:start()
        end
    end
end

-- Front turbine audio
local audio_turbine_front = nil
local audio_turbine_fuelpump_front = nil
if coordsConfig.turboshaftPresent then -- Use value from coordsConfig
    audio_turbine_front = ac.AudioEvent("/cars/" .. ac.getCarID(0) .. "/turbine", true, true)
    audio_turbine_front.cameraInteriorMultiplier = 0.5
    audio_turbine_front.volume = 0.8
    audio_turbine_front:setPosition(vec3(0, 0.772, 1.05), vec3(0, 0, 1), vec3(0, 1, 0))
    audio_turbine_front:start()

    audio_turbine_fuelpump_front = ac.AudioEvent("/cars/" .. ac.getCarID(0) .. "/turbine_fuelpump", true, true)
    audio_turbine_fuelpump_front.cameraInteriorMultiplier = 0.5
    audio_turbine_fuelpump_front.volume = 0.45
    audio_turbine_fuelpump_front:setPosition(vec3(0, 0.7, 0.75), vec3(0, 0, 1), vec3(0, 1, 0))
    audio_turbine_fuelpump_front:start()
end

-- Fuel Pump Load Curve
local fuelPumpRPMLUT = ac.DataLUT11()
fuelPumpRPMLUT:add(0, 4000)
fuelPumpRPMLUT:add(6000, 5000)
fuelPumpRPMLUT:add(18000, 4500)

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

-- Fuel Pump Fadeout State Variables
local rearFuelPumpFadeoutState = 0
local leftFuelPumpFadeoutState = 0
local rightFuelPumpFadeoutState = 0
local frontFuelPumpFadeoutState = 0

-- Define estimated RPM ranges (adjust if necessary)
local TURBOJET_IDLE_RPM = 4000
local TURBOJET_MAX_RPM = 18000
local TURBOJET_AB_RPM_BOOST = 2000
local TURBOSHAFT_IDLE_RPM = 5000
local TURBOSHAFT_MAX_RPM = 45000
local TURBOSHAFT_PHYSICS_RPM_SCALE = (20000 / 45000) -- Scale used in physics script controller output

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

    -- Read all potentially relevant controller inputs
    local rawCtrlrData = {
        -- Inputs [8-12] (Single TJ OR Left Dual TJ OR Rear TS)
        input8 = car_phys.scriptControllerInputs[8] or 0,   -- TJ/TS Throttle
        input9 = car_phys.scriptControllerInputs[9] or 0,   -- TJ Thrust / TS Fuel Flow Ratio
        input10 = car_phys.scriptControllerInputs[10] or 0, -- TJ RPM / TS Scaled RPM
        input11 = car_phys.scriptControllerInputs[11] or 0, -- TJ Fuel Pump Enabled
        input12 = car_phys.scriptControllerInputs[12] or 0, -- TJ Afterburner
        -- Inputs [13-17] (Right Dual TJ OR Front TS)
        input13 = car_phys.scriptControllerInputs[13] or 0, -- TJ/TS Throttle (Right/Front)
        input14 = car_phys.scriptControllerInputs[14] or 0, -- TJ Thrust / TS Fuel Flow Ratio (Right/Front)
        input15 = car_phys.scriptControllerInputs[15] or 0, -- TJ RPM / TS Scaled RPM (Right/Front)
        input16 = car_phys.scriptControllerInputs[16] or 0, -- TJ Fuel Pump Enabled (Right)
        input17 = car_phys.scriptControllerInputs[17] or 0, -- TJ Afterburner (Right)
        -- Inputs [18-19] (Turboshaft Damage)
        input18 = car_phys.scriptControllerInputs[18] or 0, -- Front Turboshaft Damage
        input19 = car_phys.scriptControllerInputs[19] or 0  -- Rear Turboshaft Damage
    }

    -- Structure to hold processed state based on config
    local ctrlrData = {}


    if coordsConfig.turbojetType then
        if coordsConfig.turbojetType == "single" then
            ctrlrData.turbineThrottle = rawCtrlrData.input8
            ctrlrData.turbineThrust = rawCtrlrData.input9
            ctrlrData.turbineRPM = rawCtrlrData.input10
            ctrlrData.fuelPumpEnabled = rawCtrlrData.input11
            ctrlrData.turbineAfterburner = rawCtrlrData.input12
            ctrlrData.turbineDamage = 0 -- Assume no damage input from physics
        elseif coordsConfig.turbojetType == "dual" then
            -- Left
            ctrlrData.leftThrottle = rawCtrlrData.input8
            ctrlrData.leftThrust = rawCtrlrData.input9
            ctrlrData.leftRPM = rawCtrlrData.input10
            ctrlrData.leftFuelPumpEnabled = rawCtrlrData.input11
            ctrlrData.leftAfterburner = rawCtrlrData.input12
            ctrlrData.leftDamage = 0 -- Assume no damage input
            -- Right
            ctrlrData.rightThrottle = rawCtrlrData.input13
            ctrlrData.rightThrust = rawCtrlrData.input14
            ctrlrData.rightRPM = rawCtrlrData.input15
            ctrlrData.rightFuelPumpEnabled = rawCtrlrData.input16
            ctrlrData.rightAfterburner = rawCtrlrData.input17
            ctrlrData.rightDamage = 0 -- Assume no damage input
        end
    end

    -- Populate/Overwrite with Turboshaft data if present and not masked
    if coordsConfig.turboshaftPresent then
        -- Rear Turboshaft (Inputs 8, 9, 10, 11, 19)
        if not coordsConfig.turbojetType or coordsConfig.turbojetType ~= "single" then
            ctrlrData.turbineThrottle = rawCtrlrData.input8 -- Throttle
            ctrlrData.turbineThrust = rawCtrlrData.input9   -- Fuel Flow Ratio
            -- Unscale RPM from physics input (input10 is RPM * scale)
            ctrlrData.turbineRPM = (rawCtrlrData.input10 ~= 0 and TURBOSHAFT_PHYSICS_RPM_SCALE ~= 0) and (rawCtrlrData.input10 / TURBOSHAFT_PHYSICS_RPM_SCALE) or 0
            ctrlrData.turbineAfterburner = rawCtrlrData.input11 -- Read actual afterburner from physics
            ctrlrData.turbineDamage = rawCtrlrData.input19      -- Damage
            -- Estimate fuel pump state based on unscaled RPM vs idle threshold
            ctrlrData.fuelPumpEnabled = (ctrlrData.turbineRPM > (TURBOSHAFT_IDLE_RPM * 0.9)) and 1 or 0
        end
        -- Front Turboshaft (Inputs 13, 14, 15, 16, 18)
        if coordsConfig.turbojetType ~= "dual" then
            ctrlrData.frontTurbineThrottle = rawCtrlrData.input13 -- Throttle
            ctrlrData.frontTurbineThrust = rawCtrlrData.input14   -- Fuel Flow Ratio
            -- Unscale RPM from physics input (input15 is RPM * scale)
            ctrlrData.frontTurbineRPM = (rawCtrlrData.input15 ~= 0 and TURBOSHAFT_PHYSICS_RPM_SCALE ~= 0) and (rawCtrlrData.input15 / TURBOSHAFT_PHYSICS_RPM_SCALE) or 0
            ctrlrData.frontTurbineAfterburner = rawCtrlrData.input16 -- Read actual afterburner from physics
            ctrlrData.frontTurbineDamage = rawCtrlrData.input18      -- Damage
            -- Estimate fuel pump state based on unscaled RPM vs idle threshold
            ctrlrData.frontFuelPumpEnabled = (ctrlrData.frontTurbineRPM > (TURBOSHAFT_IDLE_RPM * 0.9)) and 1 or 0
        end
    end

    -- Ensure default numerical values (0) for any fields that might not have been set by the logic above
    ctrlrData.turbineThrottle = ctrlrData.turbineThrottle or 0
    ctrlrData.turbineThrust = ctrlrData.turbineThrust or 0
    ctrlrData.turbineRPM = ctrlrData.turbineRPM or 0
    ctrlrData.fuelPumpEnabled = ctrlrData.fuelPumpEnabled or 0
    ctrlrData.turbineAfterburner = ctrlrData.turbineAfterburner or 0
    ctrlrData.turbineDamage = ctrlrData.turbineDamage or 0
    ctrlrData.leftThrottle = ctrlrData.leftThrottle or 0
    ctrlrData.leftThrust = ctrlrData.leftThrust or 0
    ctrlrData.leftRPM = ctrlrData.leftRPM or 0
    ctrlrData.leftFuelPumpEnabled = ctrlrData.leftFuelPumpEnabled or 0
    ctrlrData.leftAfterburner = ctrlrData.leftAfterburner or 0
    ctrlrData.leftDamage = ctrlrData.leftDamage or 0
    ctrlrData.rightThrottle = ctrlrData.rightThrottle or 0
    ctrlrData.rightThrust = ctrlrData.rightThrust or 0
    ctrlrData.rightRPM = ctrlrData.rightRPM or 0
    ctrlrData.rightFuelPumpEnabled = ctrlrData.rightFuelPumpEnabled or 0
    ctrlrData.rightAfterburner = ctrlrData.rightAfterburner or 0
    ctrlrData.rightDamage = ctrlrData.rightDamage or 0
    ctrlrData.frontTurbineThrottle = ctrlrData.frontTurbineThrottle or 0
    ctrlrData.frontTurbineThrust = ctrlrData.frontTurbineThrust or 0
    ctrlrData.frontTurbineRPM = ctrlrData.frontTurbineRPM or 0
    ctrlrData.frontFuelPumpEnabled = ctrlrData.frontFuelPumpEnabled or 0
    ctrlrData.frontTurbineDamage = ctrlrData.frontTurbineDamage or 0

    -- Ensure Audio Sources are Playing
    if not audio_engine:isPlaying() then audio_engine:start() end
    if audio_turbine_rear and not audio_turbine_rear:isPlaying() then audio_turbine_rear:start() end
    if audio_turbine_fuelpump_rear and not audio_turbine_fuelpump_rear:isPlaying() then
        audio_turbine_fuelpump_rear:start()
    end
    if audio_turbine_left and not audio_turbine_left:isPlaying() then audio_turbine_left:start() end
    if audio_turbine_fuelpump_left and not audio_turbine_fuelpump_left:isPlaying() then
        audio_turbine_fuelpump_left:start()
    end
    if audio_turbine_right and not audio_turbine_right:isPlaying() then audio_turbine_right:start() end
    if audio_turbine_fuelpump_right and not audio_turbine_fuelpump_right:isPlaying() then
        audio_turbine_fuelpump_right:start()
    end
    if audio_turbine_front and not audio_turbine_front:isPlaying() then audio_turbine_front:start() end
    if audio_turbine_fuelpump_front and not audio_turbine_fuelpump_front:isPlaying() then
        audio_turbine_fuelpump_front:start()
    end

    -- Calculate Fuel Pump Fadeouts (Using state variables)
    local rearPumpTarget = ctrlrData.fuelPumpEnabled or 0
    local leftPumpTarget = ctrlrData.leftFuelPumpEnabled or 0
    local rightPumpTarget = ctrlrData.rightFuelPumpEnabled or 0
    local frontPumpTarget = ctrlrData.frontFuelPumpEnabled or 0

    -- Lerp the state variables towards the target
    rearFuelPumpFadeoutState = math.lerp(rearFuelPumpFadeoutState, rearPumpTarget, dt * 5)
    leftFuelPumpFadeoutState = math.lerp(leftFuelPumpFadeoutState, leftPumpTarget, dt * 5)
    rightFuelPumpFadeoutState = math.lerp(rightFuelPumpFadeoutState, rightPumpTarget, dt * 5)
    frontFuelPumpFadeoutState = math.lerp(frontFuelPumpFadeoutState, frontPumpTarget, dt * 5)

    -- Use the state variables for setting audio parameters
    local rearFuelPumpFadeout = rearFuelPumpFadeoutState
    local leftFuelPumpFadeout = leftFuelPumpFadeoutState
    local rightFuelPumpFadeout = rightFuelPumpFadeoutState
    local frontFuelPumpFadeout = frontFuelPumpFadeoutState

    -- Control Audio Parameters (Update to use configuration-specific ctrlrData fields)
    audio_engine:setParam("rpms", car.rpm)
    audio_engine:setParam("throttle", car.gas)

    if coordsConfig.turbojetType then
        if coordsConfig.turbojetType == "single" then
            if audio_turbine_rear then
                audio_turbine_rear:setParam("rpm", ctrlrData.turbineRPM)
                audio_turbine_rear:setParam("throttle", ctrlrData.turbineThrottle)
                audio_turbine_rear:setParam("afterburner", ctrlrData.turbineAfterburner)
                audio_turbine_rear:setParam("damage", ctrlrData.turbineDamage)
            end
            if audio_turbine_fuelpump_rear then
                audio_turbine_fuelpump_rear:setParam("rpm", fuelPumpRPMLUT:get(ctrlrData.turbineRPM) * rearFuelPumpFadeout)
            end
        elseif coordsConfig.turbojetType == "dual" then
            -- Left
            if audio_turbine_left then
                audio_turbine_left:setParam("rpm", ctrlrData.leftRPM)
                audio_turbine_left:setParam("throttle", ctrlrData.leftThrottle)
                audio_turbine_left:setParam("afterburner", ctrlrData.leftAfterburner)
                audio_turbine_left:setParam("damage", ctrlrData.leftDamage)
            end
            if audio_turbine_fuelpump_left then
                audio_turbine_fuelpump_left:setParam("rpm", fuelPumpRPMLUT:get(ctrlrData.leftRPM) * leftFuelPumpFadeout)
            end
            -- Right
            if audio_turbine_right then
                audio_turbine_right:setParam("rpm", ctrlrData.rightRPM)
                audio_turbine_right:setParam("throttle", ctrlrData.rightThrottle)
                audio_turbine_right:setParam("afterburner", ctrlrData.rightAfterburner)
                audio_turbine_right:setParam("damage", ctrlrData.rightDamage)
            end
            if audio_turbine_fuelpump_right then
                audio_turbine_fuelpump_right:setParam("rpm", fuelPumpRPMLUT:get(ctrlrData.rightRPM) * rightFuelPumpFadeout)
            end
        end
    end

    -- Control Turboshaft Audio
    if coordsConfig.turboshaftPresent then
        -- Control Rear Turboshaft Audio (if not single turbojet config)
        if not coordsConfig.turbojetType or coordsConfig.turbojetType ~= "single" then
            if audio_turbine_rear then -- This audio source might be shared/overwritten by single TJ, handle carefully
                audio_turbine_rear:setParam("rpm", ctrlrData.turbineRPM)
                audio_turbine_rear:setParam("throttle", ctrlrData.turbineThrottle)
                audio_turbine_rear:setParam("afterburner", ctrlrData.turbineAfterburner or 0)
                audio_turbine_rear:setParam("damage", ctrlrData.turbineDamage)
            end
            if audio_turbine_fuelpump_rear then
                audio_turbine_fuelpump_rear:setParam("rpm", fuelPumpRPMLUT:get(ctrlrData.turbineRPM) * rearFuelPumpFadeout)
            end
        end
        -- Control Front Turboshaft Audio (if not dual turbojet config)
        if coordsConfig.turbojetType ~= "dual" then
            if audio_turbine_front then
                audio_turbine_front:setParam("rpm", ctrlrData.frontTurbineRPM)
                audio_turbine_front:setParam("throttle", ctrlrData.frontTurbineThrottle)
                audio_turbine_front:setParam("afterburner", ctrlrData.frontTurbineAfterburner or 0)
                audio_turbine_front:setParam("damage", ctrlrData.frontTurbineDamage)
            end
            if audio_turbine_fuelpump_front then
                audio_turbine_fuelpump_front:setParam("rpm", fuelPumpRPMLUT:get(ctrlrData.frontTurbineRPM) * frontFuelPumpFadeout)
            end
        end
    end

    -- Emit turbojet particle effects
    if coordsConfig.turbojetType then
        local scale = mapRange(car.speedKmh, 0, 400, 1, 0.1, true)
        
        if coordsConfig.turbojetType == "single" then
            -- For single turbojet, emit flames at all exhaust positions
            for _, pos in ipairs(coordsConfig.coordinates.turbineExhausts) do
                local baseVel = vec3(0, 0, -3) + (car.localVelocity * -0.35)
                local afterburnerBaseEjectionVel = vec3(0, 0, -3 * 0.5)
                local afterburnerVel = afterburnerBaseEjectionVel + (car.localVelocity * -0.35)
                local particlePos = vec3(pos.x + car.localVelocity.x * 0.012, pos.y, pos.z + car.localVelocity.z * 0.01)
                
                flameBoost:emit(particlePos, baseVel, mapRange(ctrlrData.turbineThrottle, 0.9, 1, 0, 1, true) * mapRange(car.speedKmh, 0, 400, 0.5, 0.1, true))
                flameTurbo:emit(particlePos, afterburnerVel, ctrlrData.turbineAfterburner * scale * 0.6)
                exhaustSmoke:emit(particlePos, baseVel * mapRange(ctrlrData.turbineThrottle, 0, 1, 10, 20, true), mapRange(ctrlrData.turbineThrottle, 0, 1, 0.05, 0.2, true) * (1 + ctrlrData.turbineAfterburner))
            end
        elseif coordsConfig.turbojetType == "dual" then
            -- Calculate common components first
            local afterburnerBaseEjectionVel = vec3(0, 0, -3 * 0.5)
            local carVelComponent = car.localVelocity * -0.35
            
            -- Iterate through all exhaust positions
            for _, pos in ipairs(coordsConfig.coordinates.turbineExhausts) do
                local particlePos = vec3(pos.x + car.localVelocity.x * 0.012, pos.y, pos.z + car.localVelocity.z * 0.01)
                local baseVel = vec3(0, 0, -3) + carVelComponent
                local afterburnerVel = afterburnerBaseEjectionVel + carVelComponent
                
                -- Determine which engine's parameters to use based on x-coordinate
                local throttle, afterburner
                if pos.x > 0 then
                    -- Right engine
                    throttle = ctrlrData.rightThrottle
                    afterburner = ctrlrData.rightAfterburner
                elseif pos.x < 0 then
                    -- Left engine
                    throttle = ctrlrData.leftThrottle
                    afterburner = ctrlrData.leftAfterburner
                else
                    -- Center, use average of left and right
                    throttle = (ctrlrData.leftThrottle + ctrlrData.rightThrottle) / 2
                    afterburner = (ctrlrData.leftAfterburner + ctrlrData.rightAfterburner) / 2
                end
                
                flameBoost:emit(particlePos, baseVel, mapRange(throttle, 0.9, 1, 0, 1, true) * mapRange(car.speedKmh, 0, 400, 0.5, 0.1, true))
                flameTurbo:emit(particlePos, afterburnerVel, afterburner * scale * 0.6)
                exhaustSmoke:emit(particlePos, baseVel * mapRange(throttle, 0, 1, 10, 20, true), mapRange(throttle, 0, 1, 0.05, 0.2, true) * (1 + afterburner))
            end
        end
    end

    -- Add turboshaft flame effects
    if coordsConfig.turboshaftPresent then
        local scale = mapRange(car.speedKmh, 0, 400, 1, 0.1, true)
        local afterburnerBaseEjectionVel = vec3(0, 0, -3 * 0.5)
        local carVelComponent = car.localVelocity * -0.35
        local baseVel = vec3(0, 0, -3) + carVelComponent
        local afterburnerVel = afterburnerBaseEjectionVel + carVelComponent

        -- Rear turboshaft flames (if not single turbojet config)
        if not coordsConfig.turbojetType or coordsConfig.turbojetType ~= "single" then
            for _, pos in ipairs(coordsConfig.coordinates.turbineExhausts) do
                local particlePos = vec3(pos.x + car.localVelocity.x * 0.012, pos.y, pos.z + car.localVelocity.z * 0.01)
                
                flameBoost:emit(particlePos, baseVel, mapRange(ctrlrData.turbineThrottle, 0.9, 1, 0, 1, true) * mapRange(car.speedKmh, 0, 400, 0.5, 0.1, true))
                flameTurbo:emit(particlePos, afterburnerVel, (ctrlrData.turbineAfterburner or 0) * scale * 0.6)
                exhaustSmoke:emit(particlePos, baseVel * mapRange(ctrlrData.turbineThrottle, 0, 1, 10, 20, true), mapRange(ctrlrData.turbineThrottle, 0, 1, 0.05, 0.2, true) * (1 + (ctrlrData.turbineAfterburner or 0)))
            end
        end
    end

    -- Turbine exhaust glow logic
    turbineExhaustGlow:setMaterialProperty("ksEmissive",
        (vec3(2, 2, 4) * ctrlrData.turbineThrottle * 10) + (vec3(1, 1, 1) * ctrlrData.turbineAfterburner * 20))

    -- Headlight Logic
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

    -- Jump Jack Logic
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
    ac.debug("Config: Turbojet Type", coordsConfig.turbojetType or "N/A")
    ac.debug("Config: Turboshaft Present", coordsConfig.turboshaftPresent and "Yes" or "No")

    if coordsConfig.turbojetType then
        if coordsConfig.turbojetType == "single" then
            ac.debug("TJ Single: Thr", string.format("%.2f", ctrlrData.turbineThrottle))
            ac.debug("TJ Single: RPM", string.format("%.0f", ctrlrData.turbineRPM))
            ac.debug("TJ Single: Thrust", string.format("%.2f", ctrlrData.turbineThrust))
            ac.debug("TJ Single: AB", string.format("%.0f", ctrlrData.turbineAfterburner))
            ac.debug("TJ Single: Pump", string.format("%.0f", ctrlrData.fuelPumpEnabled))
            ac.debug("TJ Single: Dmg", string.format("%.2f", ctrlrData.turbineDamage))
        elseif coordsConfig.turbojetType == "dual" then
            ac.debug("TJ Left: Thr", string.format("%.2f", ctrlrData.leftThrottle))
            ac.debug("TJ Left: RPM", string.format("%.0f", ctrlrData.leftRPM))
            ac.debug("TJ Left: Thrust", string.format("%.2f", ctrlrData.leftThrust))
            ac.debug("TJ Left: AB", string.format("%.0f", ctrlrData.leftAfterburner))
            ac.debug("TJ Left: Pump", string.format("%.0f", ctrlrData.leftFuelPumpEnabled))
            ac.debug("TJ Right: Thr", string.format("%.2f", ctrlrData.rightThrottle))
            ac.debug("TJ Right: RPM", string.format("%.0f", ctrlrData.rightRPM))
            ac.debug("TJ Right: Thrust", string.format("%.2f", ctrlrData.rightThrust))
            ac.debug("TJ Right: AB", string.format("%.0f", ctrlrData.rightAfterburner))
            ac.debug("TJ Right: Pump", string.format("%.0f", ctrlrData.rightFuelPumpEnabled))
        end
    end

    if coordsConfig.turboshaftPresent then
        -- Debug Rear Turboshaft (if active)
        if not coordsConfig.turbojetType or coordsConfig.turbojetType ~= "single" then
            ac.debug("TS Rear: Thr", string.format("%.2f", ctrlrData.turbineThrottle))
            ac.debug("TS Rear: RPM", string.format("%.0f", ctrlrData.turbineRPM))
            ac.debug("TS Rear: FuelFlow%", string.format("%.2f", ctrlrData.turbineThrust)) -- Note: Using 'thrust' field for fuel flow ratio
            ac.debug("TS Rear: Pump", string.format("%.0f", ctrlrData.fuelPumpEnabled))
            ac.debug("TS Rear: Dmg", string.format("%.2f", ctrlrData.turbineDamage))
        end
        -- Debug Front Turboshaft (if active)
        if coordsConfig.turbojetType ~= "dual" then
            ac.debug("TS Front: Thr", string.format("%.2f", ctrlrData.frontTurbineThrottle))
            ac.debug("TS Front: RPM", string.format("%.0f", ctrlrData.frontTurbineRPM))
            ac.debug("TS Front: FuelFlow%", string.format("%.2f", ctrlrData.frontTurbineThrust))
            ac.debug("TS Front: Pump", string.format("%.0f", ctrlrData.frontFuelPumpEnabled))
            ac.debug("TS Front: Dmg", string.format("%.2f", ctrlrData.frontTurbineDamage))
        end
    end
end
