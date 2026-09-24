-- T-180 CSP Physics Script - Steering Controller Module, Active
-- Authored by roun12 and ohyeah2389

-- NOTE: torque vectoring has been removed

local state = require('script_state')
local helpers = require('script_helpers')
local PIDController = require('pid_v1')
local threesixtyctrlr = require('script_threesixtyctrlr')

local WheelSteerCtrlr = class("WheelSteerCtrlr_active")

local threesixtyctrlr_FL = threesixtyctrlr()
local threesixtyctrlr_FR = threesixtyctrlr()
local threesixtyctrlr_RL = threesixtyctrlr()
local threesixtyctrlr_RR = threesixtyctrlr()

local function setupItem(id, default)
    return ac.getScriptSetupValue(id) or refnumber(default)
end

local setup = {
    ffbGain = setupItem("FFB_GAIN", 10),
    ffbSmoothing = setupItem("FFB_SMOOTHING", 10),
    frontAngleGain = setupItem("FFB_FRONT_ANGLE_GAIN", 0),
    frontSlipGain = setupItem("FFB_FRONT_SLIP_GAIN", 10),
    rearAngleGain = setupItem("FFB_REAR_ANGLE_GAIN", 0),
    rearSlipGain = setupItem("FFB_REAR_SLIP_GAIN", 10),
    latGEffect = setupItem("FFB_LATERAL_G", 0),
    steerLimitGain = setupItem("FFB_STEER_LIMIT_GAIN", 10),
    steeringRange = setupItem("STEERING_RANGE", 3),
    yawRatePower = setupItem("ACTIVE_YAW_RATE_POWER", 15),
    frontGain = setupItem("CORNER_FRONT_GAIN", 5),
    rearGain = setupItem("CORNER_REAR_GAIN", 8),
    cornerCurve = setupItem("CORNER_CURVE", 2),
    servoPower = setupItem("ACTIVE_SERVO_POWER", 25),
    servoDamping = setupItem("ACTIVE_SERVO_DAMPING", 15),
    yawPowerMultiplier = setupItem("CORNER_YAW_POWER", 0),
    servoLimit = setupItem("ACTIVE_SERVO_LIMIT", 2),
    inversionAssist = setupItem("ACTIVE_INVERSION_ASSIST", 1),
    steeringStyle = setupItem("ACTIVE_STEERING_STYLE", 0),
    spinStyle = setupItem("ACTIVE_SPIN_STYLE", 1),
    clutchSteerMode = setupItem("ACTIVE_CLUTCH_STEER_MODE", 1),
    controlType = setupItem("ACTIVE_CONTROL_TYPE", 0),
    ffbMode = setupItem("FFB_MODE", 1),
}

local ffbGain, ffbSmoothingSetup, frontAngleGain, frontSlipGainSetup, rearAngleGain, rearSlipGainSetup
local latGEffect, steerLimitGainSetup, steeringRange, yawRatePower, frontGain, rearGain, cornerCurve
local servoPowerSetup, servoDampingSetup, yawPowerMultiplier, servoLimit, inversionAssistSetup
local steeringStyle, spinStyle, clutchSteerMode, controlType, ffbMode

local function refreshSetup()
    ffbGain = setup.ffbGain.value
    ffbSmoothingSetup = setup.ffbSmoothing.value
    frontAngleGain = setup.frontAngleGain.value
    frontSlipGainSetup = setup.frontSlipGain.value
    rearAngleGain = setup.rearAngleGain.value
    rearSlipGainSetup = setup.rearSlipGain.value
    latGEffect = setup.latGEffect.value
    steerLimitGainSetup = setup.steerLimitGain.value
    steeringRange = setup.steeringRange.value
    yawRatePower = setup.yawRatePower.value
    frontGain = setup.frontGain.value
    rearGain = setup.rearGain.value
    cornerCurve = setup.cornerCurve.value
    servoPowerSetup = setup.servoPower.value
    servoDampingSetup = setup.servoDamping.value
    yawPowerMultiplier = setup.yawPowerMultiplier.value
    servoLimit = setup.servoLimit.value
    inversionAssistSetup = setup.inversionAssist.value
    steeringStyle = setup.steeringStyle.value
    spinStyle = setup.spinStyle.value
    clutchSteerMode = setup.clutchSteerMode.value
    controlType = setup.controlType.value
    ffbMode = setup.ffbMode.value
end

refreshSetup()

-- Normalizes any angle in radians to [-pi, pi]
local function normalizeAngle(angle)
    while angle > math.pi do angle = angle - 2 * math.pi end
    while angle < -math.pi do angle = angle + 2 * math.pi end
    return angle
end

-- Smooth final output
local function smoothFFB(self, finalFFB)
    local ffbSmoothing = ffbSmoothingSetup / 100
    local ffbMultiplier = ffbGain / 10
    local lastVal = self.lastFFB or 0
    local smoothed = lastVal * ffbSmoothing + finalFFB * (1.0 - ffbSmoothing)
    if math.abs(smoothed) > 100.0 or not (smoothed == smoothed) then smoothed = 0 end
    self.lastFFB = smoothed
    return math.clamp(smoothed * ffbMultiplier, -1.0, 1.0)
end

function WheelSteerCtrlr:initialize()
    -- Standard 25 degree moment angle across all T-180 chassis
    self.maxMomentSteerAngle = 25.0

    -- Dynamically read chassis dimensions and coilovers from suspensions.ini
    local suspensionsConfig = ac.INIConfig.carData(car.index, "suspensions.ini")
    local wheelbase = suspensionsConfig:get("BASIC", "WHEELBASE", 3.2)
    local cgLocation = suspensionsConfig:get("BASIC", "CG_LOCATION", 0.5)

    self.a = wheelbase * (1 - cgLocation)
    self.b = wheelbase * cgLocation
    self.halfTrackFront = suspensionsConfig:get("FRONT", "TRACK", 1.6) / 2
    self.halfTrackRear = suspensionsConfig:get("REAR", "TRACK", 1.6) / 2
    self.frontSpringRate = suspensionsConfig:get("FRONT_COILOVER_0", "RATE", 50000)

    -- Dynamically read tire friction limit angles from tyres.ini
    local tyresConfig = ac.INIConfig.carData(car.index, "tyres.ini")
    self.peakSlipFront = math.rad(tyresConfig:get("FRONT", "FRICTION_LIMIT_ANGLE", 9.5))
    self.peakSlipRear = math.rad(tyresConfig:get("REAR", "FRICTION_LIMIT_ANGLE", 11.0))

    -- History and filter states
    self.steerInputLast = Data.steer or 0
    self.lastFFB = 0
    self.steerChangeHistory = {0, 0, 0, 0, 0}
    self.historyIndex = 1
    self.ffbVelocityHistory = {0, 0, 0, 0}
    self.lastClutchFactor = 0
    self.lastSpinFactor = 0
    self.prevSuspTravelL = 0
    self.prevSuspTravelR = 0

    -- Stance angle hold and closed-loop beta error tracking
    self.heldSpinAngle = 0.0
    self.heldSpinInput = 0.0
    self.hasHeldAngle = true
    self.wasDeflectedLast = false
    self.betaErrorIntegral = 0.0
    self.prevBeta = 0.0
    self.ffb = ffbMode == 0 and self.calculateFFB or self.calculateFFBNextGen

    state.control.autoCenter = true

    -- Per-wheel telemetry tables
    self.wheelVelocities = { lf = vec2(0, 0), rf = vec2(0, 0), rl = vec2(0, 0), rr = vec2(0, 0) }
    self.wheelSlipAngles = { lf = 0, rf = 0, rl = 0, rr = 0 }
    self.desiredSteers = { lf = 0, rf = 0, rl = 0, rr = 0 }

    -- Per-wheel geometry, coordinate signs, and output controller channel indices
    self.wheels = {
        { id = "lf", index = 0, distLong = self.a, distLat = self.halfTrackFront, momentSign = -1, staticSign = 1, latSign = -1, cmdSign = 1, isFront = true, servo = threesixtyctrlr_FL, outIdx = 0 },
        { id = "rf", index = 1, distLong = self.a, distLat = -self.halfTrackFront, momentSign = -1, staticSign = 1, latSign = 1, cmdSign = -1, isFront = true, servo = threesixtyctrlr_FR, outIdx = 2 },
        { id = "rl", index = 2, distLong = -self.b, distLat = self.halfTrackRear, momentSign = 1, staticSign = -1, latSign = -1, cmdSign = 1, isFront = false, servo = threesixtyctrlr_RL, outIdx = 4 },
        { id = "rr", index = 3, distLong = -self.b, distLat = -self.halfTrackRear, momentSign = 1, staticSign = -1, latSign = 1, cmdSign = -1, isFront = false, servo = threesixtyctrlr_RR, outIdx = 6 }
    }

    for _, w in ipairs(self.wheels) do w.servo.maxServoSlewRate = 1200.0 end
end

function WheelSteerCtrlr:updateSetupValues() end

-- Filtered steering wheel velocity
local function sampleSteer(self, dt)
    local steerVal = Data.steer
    if not steerVal or not self.steerInputLast then return nil end
    local steerChange = (steerVal - self.steerInputLast) / dt
    self.steerInputLast = steerVal
    if not self.ffbVelocityHistory then self.ffbVelocityHistory = {0, 0, 0, 0} end
    table.remove(self.ffbVelocityHistory, 1)
    table.insert(self.ffbVelocityHistory, steerChange)
    local filteredSteerVelocity = 0
    for _, v in ipairs(self.ffbVelocityHistory) do filteredSteerVelocity = filteredSteerVelocity + v end
    return steerVal, steerChange, filteredSteerVelocity / #self.ffbVelocityHistory
end

-- Mode 0: Legacy rate-of-change and steering angle calculations
function WheelSteerCtrlr:calculateFFB(dt)
    refreshSetup()
    dt = math.max(dt, 0.001)
    local steerVal, steerChange = sampleSteer(self, dt)
    if not steerVal or not steerChange then return 0 end

    local frontSteerGain = frontAngleGain / 5
    local frontSlipGain = frontSlipGainSetup / 10
    local rearSteerGain = rearAngleGain / 5
    local rearSlipGain = rearSlipGainSetup / 10
    local latGGain = latGEffect / 10
    local steerLimitGain = steerLimitGainSetup / 10
    local maxSteerDeg = 90 * steeringRange

    local desiredFL = self.desiredSteers.lf or 0
    local desiredFR = self.desiredSteers.rf or 0
    local desiredRL = self.desiredSteers.rl or 0
    local desiredRR = self.desiredSteers.rr or 0

    local frontSlip = (Data.wheels[0].slipAngle or 0) + (Data.wheels[1].slipAngle or 0)
    local rearSlip = (Data.wheels[2].slipAngle or 0) + (Data.wheels[3].slipAngle or 0)
    local steerOverLimit = math.max(0, math.abs(car.steer) - maxSteerDeg)
    local frontSteerEffect = (desiredFL + desiredFR) * frontSteerGain
    local frontSlipEffect = math.clamp(frontSlip * -5, -6, 6) * frontSlipGain
    local rearSteerEffect = (desiredRL + desiredRR) * rearSteerGain
    local rearSlipEffect = math.clamp(rearSlip * -15, -6, 6) * rearSlipGain
    local latG = math.clamp(Data.gForces.x or 0, -5, 5) * latGGain
    local steerLimitEffect = math.clamp((steerOverLimit ^ 2) * (steerLimitGain * 0.5), -(steerLimitGain * 2), (steerLimitGain * 2))
    local legacyEffect = frontSteerEffect + frontSlipEffect + rearSteerEffect + rearSlipEffect + latG

    if math.abs(steerLimitEffect) > 0 then
        local steerSign = math.sign(car.steer)
        legacyEffect = steerLimitEffect * steerSign + math.clamp(legacyEffect * steerSign, 0, math.huge) * steerSign
    end

    if math.abs(steerChange) < 1000 then
        self.steerChangeHistory[self.historyIndex] = (steerChange * 0.3) + legacyEffect
        self.historyIndex = (self.historyIndex % #self.steerChangeHistory) + 1
    end

    local avgSteerChange = 0
    for _, v in ipairs(self.steerChangeHistory) do avgSteerChange = avgSteerChange + (v or 0) end
    avgSteerChange = avgSteerChange / #self.steerChangeHistory

    local output = smoothFFB(self, (steerVal * 0.2) + (avgSteerChange * 0.03))
    ac.debug("Force Feedback", output, -1, 1)
    return output
end

-- Mode 1: Dynamic physical FFB scaled dynamically to vehicle mass and tire data
function WheelSteerCtrlr:calculateFFBNextGen(dt)
    refreshSetup()
    dt = math.max(dt, 0.001)
    local steerVal, _, filteredSteerVelocity = sampleSteer(self, dt)
    if not steerVal or not filteredSteerVelocity then return 0 end

    local frontSteerGain = frontAngleGain / 5
    local frontSlipGain = frontSlipGainSetup / 10
    local rearSteerGain = rearAngleGain / 5
    local rearSlipGain = rearSlipGainSetup / 10
    local latGGain = latGEffect / 10
    local steerLimitGain = steerLimitGainSetup / 10
    local maxSteerDeg = 90 * steeringRange

    local totalStaticWeight = math.max(car.mass * 9.80665, 1000.0)
    local totalLever = math.max(self.a + self.b, 0.5)
    local staticLoadFront = (totalStaticWeight * (self.b / totalLever)) * 0.5
    local staticLoadRear = (totalStaticWeight * (self.a / totalLever)) * 0.5

    local loadLF = Data.wheels[0].load or staticLoadFront
    local loadRF = Data.wheels[1].load or staticLoadFront
    local loadRL = Data.wheels[2].load or staticLoadRear
    local loadRR = Data.wheels[3].load or staticLoadRear
    local frontLoadRatio = math.clamp((loadLF + loadRF) / (2.0 * staticLoadFront), 0.1, 3.5)
    local rearLoadRatio = math.clamp((loadRL + loadRR) / (2.0 * staticLoadRear), 0.1, 3.5)

    -- Front self-aligning torque normalized by tyre friction angle and caster floor
    local avgFrontSlip = ((self.wheelSlipAngles.lf or 0) + (self.wheelSlipAngles.rf or 0)) * 0.5
    local normSlipF = avgFrontSlip / (self.peakSlipFront or math.rad(9.5))
    local aligningTorqueFront = -normSlipF * math.max(math.exp(1.0 - math.abs(normSlipF)), 0.30) * math.sqrt(frontLoadRatio) * frontSlipGain * 0.42

    -- Rear aligning torque
    local avgRearSlip = ((self.wheelSlipAngles.rl or 0) + (self.wheelSlipAngles.rr or 0)) * 0.5
    local normSlipR = avgRearSlip / (self.peakSlipRear or math.rad(11.0))
    local aligningTorqueRear = -normSlipR * math.max(math.exp(1.0 - math.abs(normSlipR)), 0.25) * math.sqrt(rearLoadRatio) * rearSlipGain * 0.14

    -- Lateral G force feedback
    local latGForce = math.clamp(-(Data.gForces.x or 0) * 0.20, -1.5, 1.5) * latGGain
    -- Servo resistance
    local frontServoResistance = ((self.desiredSteers.lf or 0) + (self.desiredSteers.rf or 0)) * 0.5 * frontSteerGain * 0.25
    local rearServoResistance = ((self.desiredSteers.rl or 0) + (self.desiredSteers.rr or 0)) * 0.5 * rearSteerGain * 0.10
    -- On-center centering force
    local centeringForce = -steerVal * 0.22 * math.clamp(car.speedKmh / 120.0, 0.4, 1.6)

    -- Suspension travel velocity scaled by spring rate to prevent buzzing on soft cars
    local suspTravelL = Data.wheels[0].suspensionTravel or 0
    local suspTravelR = Data.wheels[1].suspensionTravel or 0
    local dTravelL = (suspTravelL - (self.prevSuspTravelL or suspTravelL)) / dt
    local dTravelR = (suspTravelR - (self.prevSuspTravelR or suspTravelR)) / dt
    self.prevSuspTravelL = suspTravelL
    self.prevSuspTravelR = suspTravelR
    local rateScale = math.clamp(50000 / math.max(self.frontSpringRate or 50000, 5000), 0.4, 2.5)
    local roadTextureEffect = (math.clamp((dTravelL - dTravelR) * (0.06 / rateScale), -0.3, 0.3) + math.clamp((loadLF - loadRF) / (loadLF + loadRF + 100.0) * 0.25, -0.3, 0.3)) * math.clamp(car.speedKmh / 40.0, 0.0, 1.0)
    -- Gyroscopic high-speed steering wheel damping
    local viscousDamping = -filteredSteerVelocity * math.clamp(0.0025 * (1.0 + (car.speedKmh / 200.0)), 0.002, 0.008)

    -- Soft steering lock bumpstop resistance
    local bumpstopForce = 0
    local steerOverLimit = math.max(0, math.abs(car.steer) - maxSteerDeg)
    if steerOverLimit > 0 then
        local pTerm = (steerOverLimit ^ 1.4) * steerLimitGain * 0.25
        local dTerm = math.max(0, filteredSteerVelocity * math.sign(car.steer)) * 0.005 * steerLimitGain
        bumpstopForce = -(pTerm + dTerm) * math.sign(car.steer)
    end

    local output = smoothFFB(self, centeringForce + aligningTorqueFront + aligningTorqueRear + latGForce + frontServoResistance + rearServoResistance + roadTextureEffect + viscousDamping + bumpstopForce)
    ac.debug("Force Feedback", output, -1, 1)
    return output
end

function WheelSteerCtrlr:update(dt)
    refreshSetup()
    dt = math.max(dt, 0.001)
    self.ffb = ffbMode == 0 and self.calculateFFB or self.calculateFFBNextGen

    local localVel = Data.localVelocity
    local speed = math.sqrt(localVel.x * localVel.x + localVel.z * localVel.z)
    local speedKmh = car.speedKmh
    local r_physics = car.localAngularVelocity.y
    local r_logical = -r_physics -- Positive represents right-hand yaw across logical systems

    -- Measure live wheel loads and calculate axle-specific load ratios
    local totalStaticWeight = math.max(car.mass * 9.80665, 1000.0)
    local totalLever = math.max(self.a + self.b, 0.5)
    local staticLoadFront = (totalStaticWeight * (self.b / totalLever)) * 0.5
    local staticLoadRear = (totalStaticWeight * (self.a / totalLever)) * 0.5
    local staticPerWheelLoad = totalStaticWeight * 0.25

    local loadRatios = { 0, 0, 0, 0 }
    local totalLoad = 0
    local wheelsOffGround = 0
    for i = 0, 3 do
        local l = Data.wheels[i].load or 0
        totalLoad = totalLoad + l
        if l < 200 then wheelsOffGround = wheelsOffGround + 1 end
        local nominalLoad = (i < 2) and staticLoadFront or staticLoadRear
        loadRatios[i + 1] = math.clamp(l / nominalLoad, 0.0, 3.5)
    end
    local avgLoadRatio = math.clamp((totalLoad / 4.0) / staticPerWheelLoad, 0.2, 4.0)
    local contactQuality = math.clamp(1.0 - (wheelsOffGround / 4.0), 0.1, 1.0)

    -- Servo travel limit lookup
    local function applyServoLimit(val)
        if servoLimit >= 2.0 then return val end
        return math.clamp(val, -servoLimit, servoLimit)
    end

    -- Smooth logical yaw rate
    if not self.smoothedYaw then self.smoothedYaw = r_logical end
    self.smoothedYaw = self.smoothedYaw * 0.82 + r_logical * 0.18

    -- Read driver steering and clutch inputs
    local maxSteer = 90 * steeringRange
    local steerInputNormalized = math.clamp(car.steer / maxSteer, -1, 1)
    -- Clutch depression factor (0.0 = released, 1.0 = fully depressed)
    local clutchFactor = math.clamp(1.0 - Data.clutch, 0, 1)
    local isTwinStick = (controlType == 1)
    local isNoAutocenter = isTwinStick and (not state.control.autoCenter)

    -- Poll right stick spin inputs
    local rawSpinSteerInput = state.control.twinStickSpinSteer or 0
    local rightStick = state.control.rightStick
    local stickDeflected = false
    local inputAngle = 0.0
    local inputSpin = 0.0

    if rightStick and rightStick.mag and rightStick.mag > 0.0001 then
        stickDeflected = true
        if math.abs(rightStick.y or 0) > 0.0001 then
            inputAngle = rightStick.angle or 0.0
            inputSpin = math.clamp(inputAngle / math.pi, -1.0, 1.0)
        else
            inputSpin = rawSpinSteerInput
            inputAngle = rawSpinSteerInput * math.pi
        end
    elseif math.abs(rawSpinSteerInput) > 0.0001 then
        stickDeflected = true
        inputSpin = rawSpinSteerInput
        inputAngle = rawSpinSteerInput * math.pi
    end

    local travelAngle = speed > 0.15 and math.atan2(localVel.x, localVel.z) or 0
    local currentBeta = speed > 0.5 and math.atan2(localVel.x, localVel.z) or 0
    local directionSign = (localVel.z >= 0) and 1 or -1

    -- Capture current slip angle when toggling auto-centering off mid-corner
    if state.control.captureCurrentAngle then
        state.control.captureCurrentAngle = false
        self.heldSpinAngle = currentBeta
        self.heldSpinInput = math.clamp(currentBeta / math.pi, -1.0, 1.0)
        self.hasHeldAngle = true
    end

    -- 1. STANCE TARGET MANAGEMENT & CONFLICT MONITORING
    local spinSteerInput = 0.0
    local targetAngle = 0.0

    if isTwinStick then
        if isNoAutocenter then
            if spinStyle == 0 then
                -- Strict Angle Hold: Set and hold absolute stance angle
                if stickDeflected then
                    self.heldSpinAngle = inputAngle
                    self.heldSpinInput = inputSpin
                    self.hasHeldAngle = true
                end
            -- Loose Spin Speed: Command rotation rate, freeze angle upon release
            elseif stickDeflected then
                self.heldSpinInput = inputSpin
            elseif self.wasDeflectedLast then
                self.heldSpinAngle = currentBeta
                self.heldSpinInput = math.clamp(currentBeta / math.pi, -1.0, 1.0)
                self.hasHeldAngle = true
            end
            self.wasDeflectedLast = stickDeflected
            if stickDeflected then
                spinSteerInput = inputSpin
                targetAngle = inputAngle
            else
                spinSteerInput = self.heldSpinInput or 0.0
                targetAngle = self.heldSpinAngle or 0.0
            end
        -- Auto-centering: Revert to 0 when stick is released
        elseif stickDeflected then
            spinSteerInput = inputSpin
            targetAngle = (spinStyle == 0) and inputAngle or (inputSpin * math.pi)
        end
        state.control.heldSpinAngle = self.heldSpinAngle or 0.0
    end

    local stanceActive = false
    if isTwinStick then
        stanceActive = isNoAutocenter or stickDeflected or (math.abs(spinSteerInput) > 0.0001)
    end
    local spinFactor = stanceActive and math.max(math.abs(spinSteerInput), 0.25) or 0.0

    -- Reset PID integrators when releasing stick stance
    if isTwinStick and not stanceActive and self.lastSpinFactor > 0 then
        if self.yawPID then self.yawPID:reset() end
        self.betaErrorIntegral = 0.0
    end
    -- Reset PID integrators when releasing the clutch pedal in either mode
    if clutchSteerMode == 1 and clutchFactor == 0 and self.lastClutchFactor > 0 then
        if self.yawPID then self.yawPID:reset() end
        self.betaErrorIntegral = 0.0
    end
    self.lastClutchFactor = clutchFactor
    self.lastSpinFactor = spinFactor

    local gripOffsetRad = 0
    local momentOffsetRad = 0
    local y_effort = 0
    -- 2. TARGET HEADING & CLOSED-LOOP SIDESLIP ANGLE RETENTION
    local speedActive = math.clamp((speedKmh - 2.0) / 8.0, 0.0, 1.0) -- Smooth fade-in above 2 km/h
    local targetYawRateMain = 0

    if steeringStyle == 0 then
        targetYawRateMain = math.clamp(normalizeAngle(steerInputNormalized * math.pi - travelAngle) * 3.2 * speedActive, -2.5 * math.pi, 2.5 * math.pi)
    elseif math.abs(steerInputNormalized) >= 0.0001 then
        targetYawRateMain = steerInputNormalized * math.pi * 1.2
    end

    -- Dynamic tire grip offset based on vehicle travel direction
    local normalGripOffsetRad = 0
    if speed > 2.0 then
        local absTravel = math.abs(travelAngle)
        local gripMag = 0
        if absTravel < math.rad(45) then
            gripMag = helpers.mapRange(absTravel, 0, math.rad(45), 0, math.rad(9), true)
        elseif absTravel < math.rad(65) then
            gripMag = helpers.mapRange(absTravel, math.rad(45), math.rad(65), math.rad(9), math.rad(15), true)
        elseif absTravel < math.rad(90) then
            gripMag = math.rad(15)
        else
            gripMag = helpers.mapRange(absTravel, math.rad(90), math.rad(180), math.rad(15), 0, true)
        end
        normalGripOffsetRad = gripMag * math.sign(travelAngle)
    end

    local betaError = 0.0
    local effectiveBetaError = 0.0

    if isTwinStick then
        local targetYawRate = 0
        if not stanceActive then
            targetYawRate = targetYawRateMain
            gripOffsetRad = normalGripOffsetRad
            self.betaErrorIntegral = self.betaErrorIntegral * math.exp(-dt / 0.5)
        else
            local omegaTraj = (steerInputNormalized * 22.0) / (math.max(speed, 1.0) + 3.5)
            if (spinStyle == 0) or (isNoAutocenter and not stickDeflected) then
                betaError = normalizeAngle(targetAngle - currentBeta)
                local dBeta = (currentBeta - (self.prevBeta or currentBeta)) / dt
                self.prevBeta = currentBeta
                effectiveBetaError = betaError
                if speed > 1.5 then
                    self.betaErrorIntegral = math.clamp(self.betaErrorIntegral + (effectiveBetaError * dt * 1.5), -2.5, 2.5)
                else
                    self.betaErrorIntegral = self.betaErrorIntegral * math.exp(-dt / 0.15)
                end
                targetYawRate = omegaTraj + math.clamp(effectiveBetaError * 8.2 + self.betaErrorIntegral * 3.0 + (-math.clamp(dBeta, -8.0, 8.0) * 0.45), -4.5 * math.pi, 4.5 * math.pi)
            else
                targetYawRate = omegaTraj + spinSteerInput * math.pi * 1.6
                self.betaErrorIntegral = 0.0
            end
        end

        local steerFF = (not stanceActive and steeringStyle == 0) and math.clamp(targetYawRateMain / (2.5 * math.pi), -0.4, 0.4) or (steerInputNormalized * 0.20)
        local y_ff = math.clamp(steerFF + ((isNoAutocenter and not stickDeflected) and 0.0 or (spinSteerInput * 0.85)) + math.clamp(effectiveBetaError * 1.6, -0.70, 0.70), -1, 1)

        -- Unified Twin Stick clutch spin integration
        if clutchSteerMode == 1 and clutchFactor > 0 then
            targetYawRate = math.lerp(targetYawRate, steerInputNormalized * (2 * math.pi), clutchFactor)
            y_ff = math.lerp(y_ff, steerInputNormalized, clutchFactor)
            gripOffsetRad = math.lerp(gripOffsetRad, 0, clutchFactor)
        end

        if not self.yawPID then self.yawPID = PIDController(0.48, 0.08, 0.0, -1.0, 1.0, 1.0) end
        local baseGain = 0.48 * (yawRatePower / 15.0) * (1.0 / math.sqrt(avgLoadRatio)) * math.clamp(1.0 - (speedKmh / 500.0), 0.35, 1.0)
        self.yawPID.kP = baseGain
        self.yawPID.kI = baseGain * 0.25
        -- Anti-windup during clutch spins
        if clutchSteerMode == 1 and clutchFactor > 0.05 then
            if math.abs(steerInputNormalized) < 0.0001 and not stickDeflected then self.yawPID:reset() end
            self.yawPID.integral = 0
        elseif math.abs(targetYawRate) < 0.05 and math.abs(steerInputNormalized) < 0.0001 then
            self.yawPID.integral = self.yawPID.integral * math.exp(-dt / 0.15)
        end
        y_effort = math.clamp(y_ff + self.yawPID:update(targetYawRate, self.smoothedYaw, dt), -1, 1)
        momentOffsetRad = y_effort * directionSign * math.rad(self.maxMomentSteerAngle)

        if stanceActive then
            local absTarget = math.abs(targetAngle)
            if absTarget > math.rad(5.0) then
                local stanceBlend = math.clamp((absTarget - math.rad(5.0)) / math.rad(15.0), 0.0, 1.0)
                local effectiveTrajAngle = math.min(math.rad(14.0), math.max(math.rad(4.0), math.rad(36.0) - math.abs(momentOffsetRad)))
                gripOffsetRad = math.lerp(normalGripOffsetRad, steerInputNormalized * effectiveTrajAngle, stanceBlend)
            else
                gripOffsetRad = normalGripOffsetRad
            end
            if clutchSteerMode == 1 and clutchFactor > 0 then
                gripOffsetRad = gripOffsetRad * (1.0 - clutchFactor)
            end
        end
    else
        -- Single Stick Mode: Clutch-blended yaw rate tracking
        local targetYawRate = targetYawRateMain
        gripOffsetRad = (clutchSteerMode == 1) and (normalGripOffsetRad * (1.0 - clutchFactor)) or normalGripOffsetRad
        local y_ff = math.clamp(targetYawRateMain / (2 * math.pi), -1, 1)
        if clutchSteerMode == 1 and clutchFactor > 0 then
            targetYawRate = math.lerp(targetYawRateMain, steerInputNormalized * (2 * math.pi), clutchFactor)
            y_ff = math.lerp(y_ff, steerInputNormalized, clutchFactor)
        end
        if not self.yawPID then self.yawPID = PIDController(0.4, 0.4, 0.0, -1.0, 1.0, 1.0) end
        if clutchSteerMode == 1 and clutchFactor > 0.05 then
            if math.abs(steerInputNormalized) < 0.0001 then self.yawPID:reset() end
            self.yawPID.integral = 0
        else
            if math.abs(targetYawRate) < 0.1 then self.yawPID:reset() end
            self.yawPID.integral = math.clamp(self.yawPID.integral * math.exp(-dt / 1.0), -2.0, 2.0)
        end
        local baseGain = 0.40 * (yawRatePower / 15.0) * (1.0 / math.sqrt(avgLoadRatio)) * math.clamp(1.0 - (speedKmh / 400.0), 0.20, 1.0)
        self.yawPID.kP, self.yawPID.kI = baseGain, baseGain
        y_effort = math.clamp(y_ff + self.yawPID:update(targetYawRate, self.smoothedYaw, dt), -1, 1)
        momentOffsetRad = y_effort * directionSign * math.rad(self.maxMomentSteerAngle)
    end

    -- Corner Control calculation
    local cornerControlGainF = frontGain / 20
    local cornerControlGainR = rearGain / 20
    local cornerControl = (clutchSteerMode == 2) and clutchFactor or 0.0
    local steerSigmoidInput = steerInputNormalized
    if cornerCurve < 0 then
        steerSigmoidInput = steerInputNormalized * (1 + math.abs(cornerCurve) * math.abs(steerInputNormalized)) / (1 + math.abs(cornerCurve))
    elseif cornerCurve > 0 then
        steerSigmoidInput = steerInputNormalized / (1 + cornerCurve * math.abs(steerInputNormalized)) * (1 + cornerCurve)
    end
    if clutchSteerMode == 2 and cornerControl > 0 then
        y_effort = y_effort * (1 + (cornerControl * (yawPowerMultiplier / 2)))
    end

    -- 3. ACTUATOR & TORQUE VECTORING SCALING
    local activeMultiplier = servoPowerSetup / 25.0
    local effectiveClutch = (clutchSteerMode == 1) and clutchFactor or 0.0
    if isTwinStick then
        activeMultiplier = isNoAutocenter and 1.0 or math.lerp(servoPowerSetup / 25.0, 1.0, math.max(spinFactor, effectiveClutch))
    elseif clutchSteerMode == 1 then
        activeMultiplier = math.lerp(servoPowerSetup / 25.0, 1.0, clutchFactor)
    end
    local baseSlewRate = 1200.0 * (servoDampingSetup / 15.0)

    local staticOffset = steerInputNormalized * (self.maxMomentSteerAngle / 180.0)
    -- 4. DETECT REVERSE GEAR
    if car.gear == -1 then
        if self.yawPID then self.yawPID:reset() end
        self.betaErrorIntegral = 0.0
        for _, w in ipairs(self.wheels) do
            local cmd = applyServoLimit(staticOffset * (w.isFront and 0.5 or -0.2))
            if (w.isFront and state.control.lockedFronts) or (not w.isFront and state.control.lockedRears) then cmd = 0 end
            self.wheelSlipAngles[w.id] = 0
            self.desiredSteers[w.id] = cmd
            Data.controllerInputs[w.outIdx], Data.controllerInputs[w.outIdx + 1] = w.servo:update(cmd * w.cmdSign, dt)
        end
        return
    end

    local lowSpeedTransition = math.clamp((speedKmh - 3.0) / 32.0, 0.0, 1.0)
    local lowSpeedCutoff = math.clamp((speedKmh - 2.0) / 4.0, 0.0, 1.0)

    -- 5. PER-WHEEL ALLOCATION, TORQUE VECTORING & SERVO EXECUTION
    for _, w in ipairs(self.wheels) do
        -- Hub velocity vector in car local coordinates
        local v_w = vec2(localVel.x + r_physics * (w.isFront and self.a or -self.b), localVel.z + r_physics * w.distLat)
        self.wheelVelocities[w.id] = v_w

        local staticOffset_w = steerInputNormalized * (self.maxMomentSteerAngle / 180.0)
        if isTwinStick then
            local spinOffsetInput = (isNoAutocenter and not stickDeflected) and (self.heldSpinInput or 0) or spinSteerInput
            -- Blend rear wheels into spin mode when clutch is pressed without right stick input
            if clutchSteerMode == 1 and clutchFactor > 0 and not stickDeflected then
                spinOffsetInput = math.lerp(spinOffsetInput, steerInputNormalized, clutchFactor)
            end
            staticOffset_w = (w.isFront and steerInputNormalized or spinOffsetInput) * (self.maxMomentSteerAngle / 180.0)
        end

        local transitionBlend = lowSpeedTransition
        if isTwinStick then
            transitionBlend = (isNoAutocenter and 1.0 or math.lerp(lowSpeedTransition, 1.0, math.max(spinFactor, effectiveClutch))) * lowSpeedCutoff
        elseif clutchSteerMode == 1 then
            transitionBlend = math.lerp(lowSpeedTransition, 1.0, clutchFactor) * lowSpeedCutoff
        end

        local cmd = staticOffset_w * w.staticSign
        if speed > 0.8 and transitionBlend > 0.001 then
            local dyn = -(math.atan2(v_w.x, v_w.y) + w.momentSign * momentOffsetRad) / math.pi + (gripOffsetRad / math.pi)
            if clutchSteerMode == 2 and cornerControl > 0.001 then
                dyn = dyn - ((cornerControl * steerSigmoidInput * (w.isFront and cornerControlGainF or cornerControlGainR)) / math.pi)
            end
            cmd = math.lerp(cmd, dyn, transitionBlend)
        end

        cmd = applyServoLimit(cmd)
        if (w.isFront and state.control.lockedFronts) or (not w.isFront and state.control.lockedRears) then cmd = 0 end
        self.desiredSteers[w.id] = cmd

        -- Step 360-degree dual-piston kinematics
        local cmd_scaled = cmd * activeMultiplier
        self.wheelSlipAngles[w.id] = normalizeAngle(math.atan2(v_w.x, v_w.y) - cmd_scaled * math.pi)
        w.servo.maxServoSlewRate = baseSlewRate * math.clamp(loadRatios[w.index + 1] or 1.0, 0.4, 1.2)
        Data.controllerInputs[w.outIdx], Data.controllerInputs[w.outIdx + 1] = w.servo:update(cmd_scaled * w.cmdSign, dt)
    end

    -- 6. INVERSION ASSIST & TELEMETRY DISPLAY
    state.control.driftInversion = inversionAssistSetup == 1 and (math.cos(currentBeta) < -0.2) or false

    if DEBUG then
        ac.debug("steerctrl_active.contact", contactQuality)
        ac.debug("steerctrl_active.beta", math.deg(currentBeta))
        ac.debug("steerctrl_active.yawEffort", y_effort)
    end
end

function WheelSteerCtrlr:reset()
    self.smoothedYaw = 0
    self.prevSuspTravelL = 0
    self.prevSuspTravelR = 0
    self.lastFFB = 0
    self.steerInputLast = Data.steer or 0
    self.heldSpinAngle = 0.0
    self.heldSpinInput = 0.0
    self.hasHeldAngle = true
    self.wasDeflectedLast = false
    self.betaErrorIntegral = 0.0
    self.prevBeta = 0.0
    self.ffb = ffbMode == 0 and self.calculateFFB or self.calculateFFBNextGen
    state.control.autoCenter = true
    for i = 1, #self.steerChangeHistory do self.steerChangeHistory[i] = 0 end
    self.historyIndex = 1
    if self.yawPID then self.yawPID:reset() end
    for _, w in ipairs(self.wheels) do w.servo:reset() end
end

return WheelSteerCtrlr
