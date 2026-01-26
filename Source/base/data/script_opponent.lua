-- T-180 CSP Physics Script - Opponent Physics Module
-- Authored by ohyeah2389

local steerGainAtSpeed = ac.DataLUT11():add(0, 10):add(400, 10):add(800, 10)
local frontMultAtSpeed = ac.DataLUT11():add(0, -0.5):add(300, -0.5):add(800, -0.5)
local rearMultAtSpeed = ac.DataLUT11():add(0, 1):add(200, 1):add(600, 1)

local data = ac.accessCarPhysics()
local PIDController = require("script_pid")

local Wheel = class("Wheel")

function Wheel:initialize(wheelIndex)
    self.wheelIndex = wheelIndex
    self.liftPID = PIDController(50000.0, 0.0, 0.15, 0.0, 80000.0)
end

function Wheel:update(dt, steeringAngle, inputGas, inputBrake)
    local wheelData = data.wheels[self.wheelIndex]

    -- Suspension
    local height = physics.raycastTrack(wheelData.position, -data.up, 2)
    if height == -1 then height = 2 end
    local liftStrength = self.liftPID:update(0.4, height, dt)
    ac.addHubForce2(self.wheelIndex, wheelData.position - (-wheelData.up * 0.4), data.up * liftStrength)

    -- Convert steering angle to radians
    local steerRad = math.rad(steeringAngle or 0)
    local cosSteer = math.cos(steerRad)
    local sinSteer = math.sin(steerRad)

    -- IMPORTANT:
    -- For a steered wheel, "local velocity" must be measured in the wheel's rotated frame,
    -- not the car frame. Otherwise steering has little/no effect (especially with anisotropic
    -- damping like 10000 lateral vs 100 longitudinal).
    local wheelSide = data.side * cosSteer - data.look * sinSteer
    local wheelLook = data.side * sinSteer + data.look * cosSteer

    -- Calculate velocity in the *wheel* frame
    local localVel = vec3(
        wheelData.velocity:dot(wheelSide),
        wheelData.velocity:dot(data.up),
        wheelData.velocity:dot(wheelLook)
    )

    -- Grip and drive forces in wheel frame
    local gripForce = -localVel.x * 250 * math.clamp(data.gForces.y, 1, 4)
    local driveForce = (5000 * inputGas) + (-localVel.z * 400 * inputBrake)

    -- Convert to world space using the steered wheel frame
    local forceWorld = wheelSide * gripForce + wheelLook * driveForce
    ac.addHubForce2(self.wheelIndex, wheelData.position, forceWorld * (physics.raycastTrack(wheelData.position, -data.up, 0.45) > -1 and 1 or 0))

    return height, liftStrength
end

local Opponent = class("Opponent")

function Opponent:initialize(params)
    params = params or {}
    self.wheel_FL = Wheel(ac.Wheel.FrontLeft)
    self.wheel_FR = Wheel(ac.Wheel.FrontRight)
    self.wheel_RL = Wheel(ac.Wheel.RearLeft)
    self.wheel_RR = Wheel(ac.Wheel.RearRight)
end

local lastSteer = 0.0
local filteredAiSteer = 0.0
local aiSteerRateLimit = 400
local aiSteerDampingHz = 40
local filteredAccelWant = 0
local filteredSpeedWant = 0

local accelRiseHz = 30
local accelFallHz = 30

local speedRiseHz = 1
local speedFallHz = 15

local lastAngleSum = 0
local lookaheadConfig = {
    {distance = 30},
    {distance = 50},
    {distance = 60},
    {distance = 90},
    {distance = 120},
}
local lookaheadPoints = {}

local function runCustomAIControl(dt)
    for i = 1, #lookaheadConfig do
        local distanceAhead = lookaheadConfig[i].distance
        local targetSplinePos = ((car.splinePosition * sim.trackLengthM) + distanceAhead) / sim.trackLengthM
        lookaheadPoints[i] = ac.trackProgressToWorldCoordinate(targetSplinePos % 1.0)
    end

    local planarLook = car.look - car.up * car.look:dot(car.up)
    local planarLookLen = planarLook:length()
    if planarLookLen < 1e-3 then
        planarLook = car.side - car.up * car.side:dot(car.up)
        planarLookLen = planarLook:length()
    end
    if planarLookLen < 1e-3 then
        planarLook = vec3(0, 0, 1)
        planarLookLen = 1
    end
    planarLook = planarLook * (1 / planarLookLen)
    -- Manual cross to avoid mutating read-only vectors
    local planarSide = vec3(
        car.up.y * planarLook.z - car.up.z * planarLook.y,
        car.up.z * planarLook.x - car.up.x * planarLook.z,
        car.up.x * planarLook.y - car.up.y * planarLook.x
    )
    local planarSideLen = planarSide:length()
    if planarSideLen > 1e-3 then
        planarSide = planarSide * (1 / planarSideLen)
    end

    local angleChangeSum = 0
    local prevPos = car.position
    local prevDir = planarLook
    for i = 2, #lookaheadPoints do
        local point = lookaheadPoints[i]
        if point then
            local segment = point - prevPos
            local segmentLength = segment:length()
            if segmentLength > 0.01 then
                local dir = segment * (1 / segmentLength)
                local prevYaw = math.atan2(prevDir:dot(planarSide), prevDir:dot(planarLook))
                local dirYaw = math.atan2(dir:dot(planarSide), dir:dot(planarLook))
                local diff = math.atan2(math.sin(dirYaw - prevYaw), math.cos(dirYaw - prevYaw))
                angleChangeSum = angleChangeSum + math.abs(diff)
                prevDir = dir
                prevPos = point
            end
        end
    end

    local signedAngleSum = angleChangeSum
    local absAngleSum = math.abs(signedAngleSum)

    local deltaAngle = signedAngleSum - lastAngleSum
    local changePerSecond = math.abs(deltaAngle) / math.max(dt, 1e-3)
    local speedNorm = math.max(car.speedKmh, 1)
    local bendChangeNorm = changePerSecond / speedNorm

    ac.debug("bendChangeNorm", bendChangeNorm, -0.1, 0.1, 4)
    ac.debug("absAngleSum", absAngleSum, 0, 3, 4)
    lastAngleSum = signedAngleSum

    local targetIndices = {1, 2}
    local sumPoint = vec3(0, 0, 0)
    local used = 0
    for i = 1, #targetIndices do
        local point = lookaheadPoints[targetIndices[i]]
        if point then
            sumPoint = sumPoint + point
            used = used + 1
        end
    end
    local targetPoint = used > 0 and (sumPoint * (1 / used)) or car.position

    ac.debug("targetPoint", targetPoint)
    ac.debug("car.position", car.position)

    local toTarget = targetPoint - car.position
    if toTarget:length() < 0.01 then
        toTarget = car.look  -- avoid zero-length and keep steering stable
    end

    -- Steering target in car space (car-local axes)
    local localTarget = vec3(
        toTarget:dot(car.side),
        toTarget:dot(car.up),
        toTarget:dot(car.look)
    )
    local angleToTarget = math.atan2(localTarget.x, localTarget.z)

    ac.debug("angleToTarget", angleToTarget)

    for i = 1, #lookaheadPoints do
        local point = lookaheadPoints[i]
        if point then
            ac.drawDebugLine(point, point + vec3(0, 1, 0), rgbm(1, 0, 0, 1))
        end
    end

    ac.drawDebugLine(targetPoint, targetPoint + vec3(0, 1, 0), rgbm(0.5, 0, 1, 1))
    ac.drawDebugLine(car.position, car.position + vec3(0, 1, 0), rgbm(0, 1, 0, 1))

    local rawSteer = angleToTarget * -2.0
    local damping = 1 - math.exp(-dt * aiSteerDampingHz)
    filteredAiSteer = filteredAiSteer + (rawSteer - filteredAiSteer) * damping

    local maxDelta = aiSteerRateLimit * dt
    local desiredDelta = filteredAiSteer - lastSteer
    local limitedDelta = math.clamp(desiredDelta, -maxDelta, maxDelta)
    local newSteer = lastSteer + limitedDelta

    local finalSteer = newSteer

    local minSpeedTerm = math.clamp(math.remap(car.speedKmh, 0, 100, 3, 0), 0, 3)

    local speedWant = math.clamp(450.0 + (bendChangeNorm * 0) - ((absAngleSum ^ 2.0) * 80) - (math.abs(rawSteer) * 300), 100, 1000)
    local speedRateHz = speedWant < filteredSpeedWant and speedFallHz or speedRiseHz
    local speedDamping = 1 - math.exp(-dt * speedRateHz)
    filteredSpeedWant = filteredSpeedWant + (speedWant - filteredSpeedWant) * speedDamping

    local accelWant = math.clamp((filteredSpeedWant - car.speedKmh) * 0.01, -1, 1)
    local accelRateHz = accelWant < filteredAccelWant and accelFallHz or accelRiseHz
    local accelDamping = 1 - math.exp(-dt * accelRateHz)
    filteredAccelWant = filteredAccelWant + (accelWant - filteredAccelWant) * accelDamping

    ac.debug("speedWant", speedWant, 0, 1000, 4)
    ac.debug("filteredSpeedWant", filteredSpeedWant, 0, 120, 4)
    ac.debug("accelWant", accelWant, -1, 1, 4)
    ac.debug("filteredAccelWant", filteredAccelWant, -1, 1, 4)
    ac.debug("minSpeedTerm", minSpeedTerm)

    local finalGas = math.clamp(filteredAccelWant + minSpeedTerm, 0, 1.0)
    local finalBrake = math.clamp(-filteredAccelWant - minSpeedTerm, 0, 1.0)

    lastSteer = newSteer

    ac.debug("finalGas", finalGas, 0, 1, 3)
    ac.debug("finalBrake", finalBrake, 0, 1, 3)
    ac.debug("finalSteer", finalSteer, -1, 1, 3)

    return finalGas, finalBrake, finalSteer
end

function Opponent:update(dt)
    ac.awakeCarPhysics()
    ac.overrideBrakesTorque(ac.Wheel.All, 0, 0, 0)
    ac.overrideSpecificValue(ac.CarPhysicsValueID.ForcelessTyres, true, ac.Wheel.All)

    local autoGas, autoBrake, autoSteer = runCustomAIControl(dt)

    ac.overrideGasInput(autoGas)

    local steeringAngleFront = autoSteer * steerGainAtSpeed:get(data.speedKmh) * frontMultAtSpeed:get(data.speedKmh)
    local steeringAngleRear = autoSteer * steerGainAtSpeed:get(data.speedKmh) * rearMultAtSpeed:get(data.speedKmh)
    local height_FL, strength_FL = self.wheel_FL:update(dt, steeringAngleFront, autoGas, autoBrake)
    local height_FR, strength_FR = self.wheel_FR:update(dt, steeringAngleFront, autoGas, autoBrake)
    local height_RL, strength_RL = self.wheel_RL:update(dt, steeringAngleRear, autoGas, autoBrake)
    local height_RR, strength_RR = self.wheel_RR:update(dt, steeringAngleRear, autoGas, autoBrake)

    local rideHeightSensor = physics.raycastTrack(car.position + (car.up * 0.4) + (car.look * 1.0), -car.up, 1.0)
    local suctionMult = math.clamp(math.remap(rideHeightSensor, 0.5, 1.5, 1, 0), 0, 1) * (rideHeightSensor == -1 and 0 or 1)
    local aeroForceBase = ((car.name == "ohyeah2389_proto_mach4") or (car.name == "ma_proto_uniron")) and -160 or -200
    local velocityMagnitude = math.sqrt(car.localVelocity.x * car.localVelocity.x + car.localVelocity.z * car.localVelocity.z)
    local forwardAngle = math.atan2(car.localVelocity.x, car.localVelocity.z)
    local directionalDropoff = 1.0 -- How much force remains at 90 degrees (0.0 = full dropoff, 1.0 = no dropoff)
    local cosineDropoff = math.lerp(directionalDropoff, 1.0, math.abs(math.cos(forwardAngle)))
    local aeroForce = aeroForceBase * velocityMagnitude * cosineDropoff * suctionMult

    ac.addForce(vec3(0, 0, 0), true, vec3(0, aeroForce, 0), true)

    ac.debug("aeroForce", aeroForce)
    ac.debug("suctionMult", suctionMult)
    ac.debug("rideHeightSensor", rideHeightSensor)

    ac.debug("height_FL", height_FL)
    ac.debug("height_FR", height_FR)
    ac.debug("height_RL", height_RL)
    ac.debug("height_RR", height_RR)
    ac.debug("strength_FL", strength_FL)
    ac.debug("strength_FR", strength_FR)
    ac.debug("strength_RL", strength_RL)
    ac.debug("strength_RR", strength_RR)
end

function Opponent:reset() end

return Opponent
