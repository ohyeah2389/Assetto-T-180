-- T-180 CSP Physics Script - Jump Jacks Module
-- Authored by ohyeah2389

local physicsObject = require('script_physics')

local JumpJacks = class("JumpJacks")

local function drawDebugOrientedBox(center, axisX, axisY, axisZ, size, color)
    local hx = axisX * (size.x * 0.5)
    local hy = axisY * (size.y * 0.5)
    local hz = axisZ * (size.z * 0.5)

    local p1 = center - hx - hy - hz
    local p2 = center + hx - hy - hz
    local p3 = center + hx - hy + hz
    local p4 = center - hx - hy + hz
    local p5 = center - hx + hy - hz
    local p6 = center + hx + hy - hz
    local p7 = center + hx + hy + hz
    local p8 = center - hx + hy + hz

    ac.drawDebugLine(p1, p2, color)
    ac.drawDebugLine(p2, p3, color)
    ac.drawDebugLine(p3, p4, color)
    ac.drawDebugLine(p4, p1, color)
    ac.drawDebugLine(p5, p6, color)
    ac.drawDebugLine(p6, p7, color)
    ac.drawDebugLine(p7, p8, color)
    ac.drawDebugLine(p8, p5, color)
    ac.drawDebugLine(p1, p5, color)
    ac.drawDebugLine(p2, p6, color)
    ac.drawDebugLine(p3, p7, color)
    ac.drawDebugLine(p4, p8, color)
end

function JumpJacks:initialize(params)
    self.jacks = {}

    self.chargeTime = params.chargeTime or 2                                           -- Seconds, time it takes from the jack to charge from empty to full
    self.dischargeRate = params.dischargeRate or 10                                    -- Charge units drained per second after release
    self.contactMargin = params.contactMargin or 0.01                                  -- Meters, extra reach before the jack counts as touching
    self.penetrationForceScale = params.penetrationForceScale or 100000                -- Newtons per meter, spring force generated from penetration depth
    self.penetrationDamping = params.penetrationDamping or 4000                        -- Newton-seconds per meter, damping from contact-point motion into the ground
    self.penetrationDrag = params.penetrationDrag or 0.05                              -- Multiplier resisting extension while compressed
    self.lateralFrictionMultiplier = params.lateralFrictionMultiplier or 0.1           -- Multiplier for sideways grip while planted
    self.longitudinalFrictionMultiplier = params.longitudinalFrictionMultiplier or 0.1 -- Multiplier for fore-aft grip while planted
    self.lateralForceLimit = params.lateralForceLimit or 200                           -- Newtons, maximum lateral friction force per jack
    self.longitudinalForceLimit = params.longitudinalForceLimit or 200                 -- Newtons, maximum longitudinal friction force per jack
    self.minLateralSpeed = params.minLateralSpeed or 0.02                              -- M/s sideways speed required before friction is applied
    self.minLongitudinalSpeed = params.minLongitudinalSpeed or 0.02                    -- M/s fore-aft speed required before friction is applied

    self.right = vec3()                                                                -- Temporary normalized right vector reused each update
    self.down = vec3()                                                                 -- Temporary downward vector reused each update
    self.worldJackPos = vec3()                                                         -- Temporary world-space jack position reused for raycasts
    self.contactPoint = vec3()                                                         -- Temporary local-space ground contact point reused for force application
    self.worldJackOffset = vec3()                                                      -- Temporary world-space offset from car origin to jack mount
    self.groundVelocity = vec3()                                                       -- Temporary velocity with vertical motion removed
    self.contactVelocity = vec3()                                                      -- Temporary world-space contact-point velocity reused for friction
    self.projection = vec3()                                                           -- Temporary projected vector reused during velocity decomposition
    self.frictionDirection = vec3()                                                    -- Temporary world-space lateral direction projected to the ground plane
    self.frictionForce = vec3()                                                        -- Temporary world-space friction force reused for force application
    self.verticalForce = vec3()                                                        -- Temporary world-space support force reused for force application
    self.debugWorldContactPoint = vec3()                                               -- Temporary world-space contact point reused for debug drawing
    self.debugLineEnd = vec3()                                                         -- Temporary world-space line endpoint reused for debug drawing
    self.debugBodyCenter = vec3()                                                      -- Temporary world-space jack body center reused for debug drawing
    self.debugRodCenter = vec3()                                                       -- Temporary world-space jack rod center reused for debug drawing
    self.debugFootCenter = vec3()                                                      -- Temporary world-space jack foot center reused for debug drawing

    for name, jackParams in pairs(params.jacks) do
        self.jacks[name] = {
            position = jackParams.position,   -- Local-space mounting point in meters from the car origin
            length = jackParams.length,       -- Meters, maximum downward extension travel
            baseForce = jackParams.baseForce, -- Newtons, extension force at full release
            physicsObject = physicsObject({
                posMin = 0,                   -- Meters, minimum extension
                posMax = jackParams.length,   -- Meters, maximum extension
                center = 0,                   -- Meters, neutral extension target
                position = 0,                 -- Meters, current extension state
                mass = 10,                    -- Kilograms, simulated jack mass
                springCoef = 4000,            -- N/m natural spring force, unused for jump jacks
                frictionCoef = 20,            -- Dynamic damping/friction coefficient
                staticFrictionCoef = 1,       -- Static friction coefficient
                expFrictionCoef = 0.0001,     -- Exponential friction smoothing coefficient
                forceMax = 1000000,           -- Newtons, maximum internal actuator force
            }),
            raycast = -1,                     -- Meters to track hit, or -1 if no surface was found
            isTouching = false,               -- True when the jack foot is contacting the ground
            penetrationDepth = 0,             -- Meters the jack has pushed into the contacted surface
            penetrationForce = 0,             -- Newtons, support force generated from penetration
            chargeState = 0,                  -- Charge: 0 = no charge and no force, 1 = full charge and full force after chargeTime seconds
            jackCharging = false,             -- True while the activation input is being held
            jackActive = false,               -- True after release while the stored charge is firing
        }
    end
end

function JumpJacks:reset()
    for _, jack in pairs(self.jacks) do
        jack.physicsObject.position = 0 -- Meters, current extension state
        jack.raycast = -1               -- Meters to track hit, or -1 if no surface was found
        jack.isTouching = false         -- True when the jack foot is contacting the ground
        jack.penetrationDepth = 0       -- Meters the jack has pushed into the contacted surface
        jack.penetrationForce = 0       -- Newtons, support force generated from penetration
        jack.chargeState = 0            -- 0 = no charge and no force, 1 = full charge and full force after chargeTime seconds
        jack.jackCharging = false       -- True while the activation input is being held
        jack.jackActive = false         -- True after release while the stored charge is firing
    end
end

function JumpJacks:update(activationPattern, dt)
    local right = car.side or self.right:setCrossNormalized(car.up, car.look)
    local down = self.down:setScaled(car.up, -1)
    local carVelocity = car.velocity or self.groundVelocity:set(0, 0, 0)
    local angularVelocity = car.angularVelocity
    local groundNormal = car.groundNormal or car.up

    for name, jack in pairs(self.jacks) do
        local pressed = activationPattern[name]

        -- Jack charges while held, then fires when released
        if pressed then
            jack.chargeState = math.min(jack.chargeState + dt / self.chargeTime, 1)
            jack.jackCharging = true
            jack.jackActive = false
        else
            if jack.jackCharging then
                jack.jackCharging = false
                jack.jackActive = true
            end
        end

        jack.raycast = physics.raycastTrack(
            self.worldJackPos:set(car.position):addScaled(right, jack.position.x):addScaled(car.up, jack.position.y):addScaled(car.look, jack.position.z),
            down,
            jack.length + 2
        )
        jack.isTouching = jack.raycast ~= -1 and jack.raycast < jack.physicsObject.position + self.contactMargin

        if jack.isTouching then
            jack.penetrationDepth = jack.physicsObject.position - jack.raycast

            local contactPoint = self.contactPoint:set(jack.position.x, jack.position.y - jack.raycast, jack.position.z)
            local worldJackOffset = self.worldJackOffset:setScaled(right, contactPoint.x):addScaled(car.up, contactPoint.y):addScaled(car.look, contactPoint.z)
            local worldContactPoint = self.debugWorldContactPoint:set(car.position):add(worldJackOffset)
            local contactVelocity = self.contactVelocity:set(carVelocity)
            if angularVelocity then
                contactVelocity:add(self.projection:set(
                    angularVelocity.y * worldJackOffset.z - angularVelocity.z * worldJackOffset.y,
                    angularVelocity.z * worldJackOffset.x - angularVelocity.x * worldJackOffset.z,
                    angularVelocity.x * worldJackOffset.y - angularVelocity.y * worldJackOffset.x
                ))
            end

            local compression = math.max(0, jack.penetrationDepth)
            jack.penetrationForce = math.max(
                0,
                (compression * self.penetrationForceScale) - (contactVelocity:dot(groundNormal) * self.penetrationDamping)
            )

            local lateralDirection = self.frictionDirection:set(right):sub(self.projection:setScaled(groundNormal, right:dot(groundNormal)))
            local lateralDirectionLength = lateralDirection:length()
            if lateralDirectionLength > 0.001 then
                lateralDirection:scale(1 / lateralDirectionLength)
            end
            local forwardDirection = car.look - (groundNormal * car.look:dot(groundNormal))
            local forwardDirectionLength = forwardDirection:length()
            if forwardDirectionLength > 0.001 then
                forwardDirection = forwardDirection / forwardDirectionLength
            else
                forwardDirection = car.look
            end

            local lateralSpeed = contactVelocity:dot(lateralDirection)
            local lateralForceMagnitude = 0
            if jack.penetrationForce > 0 and lateralDirectionLength > 0.001 and math.abs(lateralSpeed) > self.minLateralSpeed then
                lateralForceMagnitude = math.min(
                    self.lateralFrictionMultiplier * jack.penetrationForce,
                    self.lateralForceLimit
                )
                self.frictionForce:setScaled(lateralDirection, -math.sign(lateralSpeed) * lateralForceMagnitude)
                ac.addForce(contactPoint, true, self.frictionForce, false)
            end
            local longitudinalSpeed = contactVelocity:dot(forwardDirection)
            local longitudinalForceMagnitude = 0
            if jack.penetrationForce > 0 and math.abs(longitudinalSpeed) > self.minLongitudinalSpeed then
                longitudinalForceMagnitude = math.min(
                    self.longitudinalFrictionMultiplier * jack.penetrationForce,
                    self.longitudinalForceLimit
                )
                self.frictionForce:setScaled(forwardDirection, -math.sign(longitudinalSpeed) * longitudinalForceMagnitude)
                ac.addForce(contactPoint, true, self.frictionForce, false)
            end

            ac.addForce(
                contactPoint,
                true,
                self.verticalForce:setScaled(groundNormal, jack.penetrationForce),
                false
            )

            if DEBUG then
                drawDebugOrientedBox(
                    self.debugBodyCenter:set(self.worldJackPos):addScaled(down, 0.08),
                    right,
                    car.up,
                    car.look,
                    vec3(0.08, 0.16, 0.08),
                    rgbm(1, 0.8, 0.1, 0.35)
                )
                drawDebugOrientedBox(
                    self.debugRodCenter:set(self.worldJackPos):addScaled(down, math.max(jack.physicsObject.position * 0.5, 0.04)),
                    right,
                    car.up,
                    car.look,
                    vec3(0.03, math.max(jack.physicsObject.position, 0.08), 0.03),
                    rgbm(0.85, 0.85, 0.9, 0.35)
                )
                drawDebugOrientedBox(
                    self.debugFootCenter:set(worldContactPoint):addScaled(groundNormal, 0.02),
                    lateralDirection,
                    groundNormal,
                    forwardDirection,
                    vec3(0.14, 0.04, 0.14),
                    rgbm(0.2, 1, 0.2, 0.35)
                )
                ac.drawDebugSquare(worldContactPoint, groundNormal, 0.18, rgbm(0.2, 1, 0.2, 1))
                ac.drawDebugCross(self.worldJackPos, 0.06, rgbm(1, 0.8, 0.1, 1))
                ac.drawDebugArrow(self.worldJackPos, worldContactPoint, rgbm(1, 1, 0, 1))
                ac.drawDebugLine(self.worldJackPos, worldContactPoint, rgbm(1, 1, 0, 1))
                ac.drawDebugLine(worldContactPoint, self.debugLineEnd:set(worldContactPoint):addScaled(groundNormal, 0.08), rgbm(0, 1, 0, 1))
                ac.drawDebugArrow(
                    worldContactPoint,
                    self.debugLineEnd:set(worldContactPoint):addScaled(groundNormal, jack.penetrationForce / math.max(self.penetrationForceScale, 1)),
                    rgbm(0, 0.6, 1, 1)
                )
                if jack.penetrationForce > 0 and lateralDirectionLength > 0.001 and math.abs(lateralSpeed) > self.minLateralSpeed then
                    ac.drawDebugArrow(
                        worldContactPoint,
                        self.debugLineEnd:set(worldContactPoint):addScaled(lateralDirection, -math.sign(lateralSpeed) * lateralForceMagnitude / math.max(self.lateralForceLimit, 1)),
                        rgbm(1, 0, 1, 1)
                    )
                end
                if jack.penetrationForce > 0 and math.abs(longitudinalSpeed) > self.minLongitudinalSpeed then
                    ac.drawDebugArrow(
                        worldContactPoint,
                        self.debugLineEnd:set(worldContactPoint):addScaled(forwardDirection, -math.sign(longitudinalSpeed) * longitudinalForceMagnitude / math.max(self.longitudinalForceLimit, 1)),
                        rgbm(0, 1, 1, 1)
                    )
                end
                ac.drawDebugArrow(
                    worldContactPoint,
                    self.debugLineEnd:set(worldContactPoint):addScaled(contactVelocity, 0.05),
                    rgbm(1, 0.4, 0, 1)
                )
            end
        else
            jack.penetrationDepth = 0
            jack.penetrationForce = 0

            if DEBUG then
                drawDebugOrientedBox(
                    self.debugBodyCenter:set(self.worldJackPos):addScaled(down, 0.08),
                    right,
                    car.up,
                    car.look,
                    vec3(0.08, 0.16, 0.08),
                    rgbm(1, 0.4, 0.1, 0.35)
                )
                drawDebugOrientedBox(
                    self.debugRodCenter:set(self.worldJackPos):addScaled(down, math.max(jack.physicsObject.position * 0.5, 0.04)),
                    right,
                    car.up,
                    car.look,
                    vec3(0.03, math.max(jack.physicsObject.position, 0.08), 0.03),
                    rgbm(0.85, 0.85, 0.9, 0.2)
                )
                ac.drawDebugCross(self.worldJackPos, 0.06, rgbm(1, 0.4, 0.1, 1))
                ac.drawDebugLine(
                    self.worldJackPos,
                    self.debugLineEnd:set(self.worldJackPos):addScaled(down, jack.length),
                    rgbm(1, 0, 0, 1)
                )
            end
        end

        local jackInputForce = jack.jackActive and jack.baseForce * jack.chargeState or 0
        jack.physicsObject:step(jackInputForce - jack.penetrationForce * self.penetrationDrag, dt)

        if not pressed then
            jack.chargeState = math.max(jack.chargeState - dt * self.dischargeRate, 0)
            if jack.chargeState == 0 then
                jack.jackActive = false
            end
        end

        if DEBUG then
            ac.debug(name .. " chargeState", jack.chargeState)
            ac.debug(name .. " jackCharging", jack.jackCharging)
            ac.debug(name .. " jackActive", jack.jackActive)
            ac.debug(name .. " penetrationDepth", jack.penetrationDepth, 0, 2, 3)
            ac.debug(name .. " penetrationForce", jack.penetrationForce, 0, 10000, 3)
            ac.debug(name .. " position", jack.physicsObject.position, 0, 2, 3)
        end
    end
end

return JumpJacks
