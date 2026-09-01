-- T-180 CSP Physics Script - Opponent Physics Module
-- Authored by ohyeah2389

-- Settings
local accelRiseHz = 30
local accelFallHz = 30
local speedRiseHz = 1
local speedFallHz = 15
local driftGain = 1.0
local frontSteerGain = 0.6
local steerDirBlend = 0.2 -- 0 = chassis look, 1 = velocity

local PID = require("pid_v2")
local helpers = require("script_helpers")

local Wheel = class("Wheel")

function Wheel:initialize(wheelIndex)
    self.wheelIndex = wheelIndex
    self.liftPID = PID({
        kP = 200000.0,
        kI = 0.0,
        kD = 0.15,
        minOutput = 0.0,
        maxOutput = 80000,
    })
end

function Wheel:update(dt, steeringAngle, inputGas, inputBrake)
    local wheelData = Data.wheels[self.wheelIndex]

    -- Suspension
    local height = physics.raycastTrack(wheelData.position, -Data.up, 2)
    if height == -1 then height = 2 end
    local liftStrength = self.liftPID:update(0.4, height, dt)
    ac.addHubForce2(self.wheelIndex, wheelData.position - (-wheelData.up * 0.4), Data.up * liftStrength)

    -- Convert steering angle to radians
    local steerRad = math.rad(steeringAngle or 0)
    local cosSteer = math.cos(steerRad)
    local sinSteer = math.sin(steerRad)

    -- Calculate wheel facing vectors
    local wheelSide = Data.side * cosSteer - Data.look * sinSteer
    local wheelLook = Data.side * sinSteer + Data.look * cosSteer

    -- Calculate velocity in the wheel's frame
    local localVel = vec3(
        wheelData.velocity:dot(wheelSide),
        wheelData.velocity:dot(Data.up),
        wheelData.velocity:dot(wheelLook)
    )

    -- Grip and drive forces in the wheel's frame
    local gripForce = -localVel.x * 300 * math.clamp(Data.gForces.y, 1, 4)
    local driveForce = (5000 * inputGas) + (-localVel.z * 400 * inputBrake)

    -- Convert to world space from the steered wheel frame
    local forceWorld = wheelSide * gripForce + wheelLook * driveForce
    ac.addHubForce2(self.wheelIndex, wheelData.position, forceWorld * (physics.raycastTrack(wheelData.position, -Data.up, 0.45) > -1 and 1 or 0))

    -- Debug: facing (green), grip force (red)
    ac.drawDebugArrow(wheelData.position, wheelData.position + wheelLook * 0.5, rgbm(0, 1, 0, 1))
    ac.drawDebugArrow(wheelData.position, wheelData.position + wheelSide * gripForce * 0.0002, rgbm(1, 0, 0, 1))

    return height, liftStrength
end

local Opponent = class("Opponent")

function Opponent:initialize(params)
    params = params or {}
    self.wheel_FL = Wheel(ac.Wheel.FrontLeft)
    self.wheel_FR = Wheel(ac.Wheel.FrontRight)
    self.wheel_RL = Wheel(ac.Wheel.RearLeft)
    self.wheel_RR = Wheel(ac.Wheel.RearRight)

    self.steerPID = PID({
        kP = 1.0,
        kI = 0.0,
        kD = 0.1,
        derivativeOnMeasurement = true,
        dampingFactor = 0.05,
    })

    self.driftPID = PID({
        kP = 0.2,
        kI = 0,
        kD = 0.02,
        minOutput = -1,
        maxOutput = 1,
        dampingFactor = 0,
    })

    self.filteredSpeedWant = 0.0
    self.filteredAccelWant = 0.0
end

function Opponent:updateSteer(steerInput, dt)
    local driftAngleRad = math.atan2(Data.localVelocity.x, Data.localVelocity.z) * helpers.mapRange(car.speedKmh, 2, 20, 0, 1, true)
    local steerNormalized = math.clamp(-steerInput, -1, 1)
    local driftOffset = self.driftPID:update(steerNormalized * -driftGain, driftAngleRad, dt)

    local driftDeg = math.deg(driftAngleRad)
    local frontAngle = driftDeg + steerNormalized * frontSteerGain * 180
    local rearAngle = driftDeg + driftOffset * 180

    if DEBUG then
        ac.debug("opponent.driftAngle", driftAngleRad, -math.pi, math.pi, 3)
        ac.debug("opponent.driftOffset", driftOffset, -1, 1, 3)
        ac.debug("opponent.frontAngle", frontAngle, -180, 180, 3)
        ac.debug("opponent.rearAngle", rearAngle, -180, 180, 3)
    end

    return frontAngle, rearAngle
end

local lastAngleSum = 0
local lookaheadConfig = {
    {distance = 30},
    {distance = 45},
    {distance = 60},
    {distance = 100},
    {distance = 150},
}
local lookaheadPoints = {}

function Opponent:runCustomAIControl(dt)
    for i = 1, #lookaheadConfig do
        local distanceAhead = lookaheadConfig[i].distance * math.clamp(math.remap(car.speedKmh, 0, 400, 0, 1.0), 0.5, 1.5)
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

    local toTarget = targetPoint - car.position
    if toTarget:length() < 0.01 then
        toTarget = car.velocity -- avoid zero-length and keep steering stable
    end

    -- displacement measurement
    local displacementPoint = ac.trackProgressToWorldCoordinate((car.splinePosition + 150) % 1.0)
    local trackAhead = ac.trackProgressToWorldCoordinate(((car.splinePosition * sim.trackLengthM) + 1.0) / sim.trackLengthM % 1.0)
    local trackLook = trackAhead - displacementPoint
    trackLook = trackLook - car.up * trackLook:dot(car.up)
    local trackLookLen = trackLook:length()
    local trackSide = vec3(0, 0, 0)
    if trackLookLen > 1e-3 then
        trackLook = trackLook * (1 / trackLookLen)
        trackSide = vec3(
            car.up.y * trackLook.z - car.up.z * trackLook.y,
            car.up.z * trackLook.x - car.up.x * trackLook.z,
            car.up.x * trackLook.y - car.up.y * trackLook.x
        )
        local trackSideLen = trackSide:length()
        if trackSideLen > 1e-3 then
            trackSide = trackSide * (1 / trackSideLen)
        end
    end
    local displacement = (car.position - displacementPoint):dot(trackSide)

    -- Steering reference: blend chassis look <-> velocity in the car-up plane
    local chassisFwd = car.look - car.up * car.look:dot(car.up)
    local chassisFwdLen = chassisFwd:length()
    if chassisFwdLen > 1e-3 then
        chassisFwd = chassisFwd * (1 / chassisFwdLen)
    else
        chassisFwd = car.side - car.up * car.side:dot(car.up)
        chassisFwdLen = chassisFwd:length()
        chassisFwd = chassisFwdLen > 1e-3 and (chassisFwd * (1 / chassisFwdLen)) or vec3(0, 0, 1)
    end

    local velPlanar = car.velocity - car.up * car.velocity:dot(car.up)
    local velPlanarLen = velPlanar:length()
    local velForward = velPlanarLen > 0.1 and (velPlanar * (1 / velPlanarLen)) or chassisFwd

    local blend = math.clamp(steerDirBlend, 0, 1)
    local forward = chassisFwd * (1 - blend) + velForward * blend
    local forwardLen = forward:length()
    if forwardLen > 1e-3 then
        forward = forward * (1 / forwardLen)
    else
        forward = chassisFwd
    end

    local side = vec3(
        car.up.y * forward.z - car.up.z * forward.y,
        car.up.z * forward.x - car.up.x * forward.z,
        car.up.x * forward.y - car.up.y * forward.x
    )
    local sideLen = side:length()
    if sideLen > 1e-3 then
        side = side * (1 / sideLen)
    end

    local angleToTarget = math.atan2(toTarget:dot(side), toTarget:dot(forward))

    -- debug lines
    for i = 1, #lookaheadPoints do
        local point = lookaheadPoints[i]
        if point then
            ac.drawDebugLine(point, point + vec3(0, 1, 0), rgbm(1, 0, 0, 1))
        end
    end

    ac.drawDebugLine(targetPoint, targetPoint + vec3(0, 1, 0), rgbm(0.5, 0, 1, 1))
    ac.drawDebugLine(car.position, car.position + vec3(0, 1, 0), rgbm(0, 1, 0, 1))

    -- core steering algo
    local finalSteer = self.steerPID:update(0, angleToTarget + (displacement * -0.065), dt, {
        kP = math.clamp(math.abs(displacement) / 2, 1.0, 4.0)
    })

    local minSpeedTerm = math.clamp(math.remap(car.speedKmh, 0, 100, 3, 0), 0, 3)

    local baseSpeed = 600.0
    local bendChangerateMod = bendChangeNorm * 0
    local bendMod = ((absAngleSum / 2) ^ 1.2) * 400
    local steerMod = (math.abs(finalSteer) ^ 1.2) * 200
    local offlineMod = (math.abs(displacement)) * 10

    local speedWant = math.clamp(baseSpeed - bendChangerateMod - bendMod - steerMod - offlineMod, 100, 1000)
    local speedRateHz = speedWant < self.filteredSpeedWant and speedFallHz or speedRiseHz
    local speedDamping = 1 - math.exp(-dt * speedRateHz)
    self.filteredSpeedWant = self.filteredSpeedWant + (speedWant - self.filteredSpeedWant) * speedDamping

    local accelWant = math.clamp((self.filteredSpeedWant - car.speedKmh) * 0.01, -1, 1)
    local accelRateHz = accelWant < self.filteredAccelWant and accelFallHz or accelRiseHz
    local accelDamping = 1 - math.exp(-dt * accelRateHz)
    self.filteredAccelWant = self.filteredAccelWant + (accelWant - self.filteredAccelWant) * accelDamping

    local finalGas = math.clamp(self.filteredAccelWant + minSpeedTerm, 0, 1.0)
    local finalBrake = math.clamp(-self.filteredAccelWant - minSpeedTerm, 0, 1.0)

    if DEBUG then
        ac.debug("opponent.bendChangeNorm", bendChangeNorm, -0.1, 0.1, 4)
        ac.debug("opponent.displacement", displacement, -10, 10, 4)
        ac.debug("opponent.absAngleSum", absAngleSum, 0, 3, 4)
        ac.debug("opponent.angleToTarget", angleToTarget, -1, 1, 4)
        ac.debug("opponent.targetPoint", targetPoint)
        ac.debug("opponent.car.position", car.position)
        ac.debug("opponent.speedWant", speedWant, 0, 1000, 4)
        ac.debug("opponent.filteredSpeedWant", self.filteredSpeedWant, 0, 120, 4)
        ac.debug("opponent.accelWant", accelWant, -1, 1, 4)
        ac.debug("opponent.filteredAccelWant", self.filteredAccelWant, -1, 1, 4)
        ac.debug("opponent.minSpeedTerm", minSpeedTerm)
        ac.debug("opponent.finalGas", finalGas, 0, 1, 4)
        ac.debug("opponent.finalBrake", finalBrake, 0, 1, 4)
        ac.debug("opponent.finalSteer", finalSteer, -1, 1, 4)
    end

    return finalGas, finalBrake, finalSteer
end

function Opponent:update(dt)
    ac.awakeCarPhysics()
    ac.overrideBrakesTorque(ac.Wheel.All, 0, 0, 0)
    ac.overrideSpecificValue(ac.CarPhysicsValueID.ForcelessTyres, true, ac.Wheel.All)

    local autoGas, autoBrake, autoSteer = self:runCustomAIControl(dt)

    ac.overrideGasInput(autoGas)

    local steeringAngleFront, steeringAngleRear = self:updateSteer(autoSteer, dt)
    local height_FL, strength_FL = self.wheel_FL:update(dt, steeringAngleFront, autoGas, autoBrake)
    local height_FR, strength_FR = self.wheel_FR:update(dt, steeringAngleFront, autoGas, autoBrake)
    local height_RL, strength_RL = self.wheel_RL:update(dt, steeringAngleRear, autoGas, autoBrake)
    local height_RR, strength_RR = self.wheel_RR:update(dt, steeringAngleRear, autoGas, autoBrake)

    local averageWheelSpeed = (Data.wheels[0].angularSpeed + Data.wheels[1].angularSpeed + Data.wheels[2].angularSpeed + Data.wheels[3].angularSpeed) / 4
    local drivetrainSpeed = averageWheelSpeed * Physics.finalRatio * Physics.gearRatios[7]

    ac.setEngineRPM(drivetrainSpeed * (60/(2*math.pi)))

    ac.overrideCarState('steer', autoSteer)

    ac.debug("opponent.height_FL", height_FL)
    ac.debug("opponent.height_FR", height_FR)
    ac.debug("opponent.height_RL", height_RL)
    ac.debug("opponent.height_RR", height_RR)
    ac.debug("opponent.strength_FL", strength_FL)
    ac.debug("opponent.strength_FR", strength_FR)
    ac.debug("opponent.strength_RL", strength_RL)
    ac.debug("opponent.strength_RR", strength_RR)
end

function Opponent:reset()
    self.driftPID:reset()
end

return Opponent
