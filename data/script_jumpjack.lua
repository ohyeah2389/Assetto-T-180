-- T-180 CSP Physics Script - Jump Jack Unit Module
-- Authored by ohyeah2389

local game = require('script_acConnection')
local physicsObject = require('script_physics')


local JumpJack = class("JumpJack")


function JumpJack:initialize(params)
    self.params = params

    -- Initialize all jacks
    self.jacks = {}
    for name, jackParams in pairs(params.jacks) do
        self.jacks[name] = {
            position = jackParams.position,
            length = jackParams.length,
            baseForce = jackParams.baseForce,
            physicsObject = physicsObject({
                posMin = 0,
                posMax = jackParams.length,
                center = 0,
                position = 0,
                mass = 10,
                springCoef = 0,
                frictionCoef = 10,
                staticFrictionCoef = 1,
                expFrictionCoef = 0.0001,
                forceMax = 1000000,
            }),
            -- State variables
            raycast = -1,
            isTouching = false,
            penetrationDepth = 0,
            penetrationForce = 0
        }
    end

    -- PID controller gains for leveling
    self.levelingP = -20000  -- Proportional gain
    self.levelingI = 0   -- Integral gain
    self.levelingD = 0   -- Derivative gain

    -- Error accumulation for integral term
    self.pitchErrorSum = 0
    self.rollErrorSum = 0
    self.lastPitchError = 0
    self.lastRollError = 0
end


function JumpJack:reset()
    for _, jack in pairs(self.jacks) do
        jack.physicsObject.position = 0
        jack.isTouching = false
        jack.penetrationDepth = 0
        jack.penetrationForce = 0
        jack.raycast = -1
    end

    self.pitchErrorSum = 0
    self.rollErrorSum = 0
    self.lastPitchError = 0
    self.lastRollError = 0
end


function JumpJack:update(activationPattern, dt)
    -- Calculate current pitch and roll angles using car's orientation
    local worldUp = vec3(0, 1, 0)
    local pitchCar = math.asin(math.dot(car.look, worldUp))
    local rightCar = math.cross(car.look, car.up):normalize()  -- Normalize the right vector
    local rollCar = math.asin(math.dot(rightCar, worldUp))

    -- PID control for leveling
    -- Pitch control (front-back)
    local pitchError = -pitchCar
    self.pitchErrorSum = self.pitchErrorSum + pitchError * dt
    local pitchDerivative = (pitchError - self.lastPitchError) / dt
    local pitchCorrection = self.levelingP * pitchError +
                           self.levelingI * self.pitchErrorSum +
                           self.levelingD * pitchDerivative
    self.lastPitchError = pitchError

    -- Roll control (left-right)
    local rollError = rollCar
    self.rollErrorSum = self.rollErrorSum + rollError * dt
    local rollDerivative = (rollError - self.lastRollError) / dt
    local rollCorrection = self.levelingP * rollError +
                          self.levelingI * self.rollErrorSum +
                          self.levelingD * rollDerivative
    self.lastRollError = rollError

    for name, jack in pairs(self.jacks) do
        -- Transform jack position from local to world space
        local right = math.cross(car.look, car.up):normalize()  -- Normalize right vector
        local jackLocalPos = vec3(
            jack.position.x,
            jack.position.y,
            jack.position.z
        )

        -- Transform local position to world space using car's orientation matrix
        local worldJackPos = car.position
            + (right * jackLocalPos.x)
            + (car.up * jackLocalPos.y)
            + (car.look * jackLocalPos.z)

        -- Use car's up vector for jack direction
        local jackDirection = -car.up
        jack.raycast = physics.raycastTrack(worldJackPos, jackDirection, jack.length + 2)

        -- Calculate force based on car's orientation
        local jackInputForce = activationPattern[name] and self.jacks[name].baseForce or -1000

        if activationPattern[name] then
            -- Apply corrections in car's local space
            local correctionForce = 0

            -- Pitch correction
            if name:find("front") then
                correctionForce = correctionForce + pitchCorrection
            elseif name:find("rear") then
                correctionForce = correctionForce - pitchCorrection
            end

            -- Roll correction
            if name:find("Left") then
                correctionForce = correctionForce + rollCorrection
            elseif name:find("right") then
                correctionForce = correctionForce - rollCorrection
            end

            jackInputForce = jackInputForce + correctionForce
        end

        jack.isTouching = jack.raycast ~= -1 and (jack.raycast < jack.physicsObject.position + 0.01)

        local forcePoint = worldJackPos + (jackDirection * jack.raycast)
        if jack.isTouching then
            jack.penetrationDepth = jack.physicsObject.position - jack.raycast
            jack.penetrationForce = math.max(0, (math.max(0, jack.penetrationDepth) ^ 0.2)) * 20000

            -- Calculate lateral velocity
            local carVelocity = car.velocity or vec3(0, 0, 0)
            local verticalComponent = math.dot(carVelocity, car.up) * car.up
            local groundVelocity = carVelocity - verticalComponent

            -- Calculate forward component
            local forwardComponent = math.dot(groundVelocity, car.look) * car.look
            local lateralVelocity = groundVelocity - forwardComponent

            -- Apply lateral friction force
            local lateralSpeed = #lateralVelocity
            if lateralSpeed > 0.1 then
                local frictionMultiplier = 2
                local lateralFrictionForce = -lateralVelocity:normalize() * math.min(
                    frictionMultiplier * jack.penetrationForce,
                    lateralSpeed * 1000
                )

                -- Apply friction force in world space
                ac.addForce(
                    jack.position,  -- Use local position
                    true,          -- Position is in local space
                    lateralFrictionForce,
                    false          -- Force is in world space
                )
            end

            -- Apply vertical force in local space
            ac.addForce(
                jack.position,     -- Use local position
                true,             -- Position is in local space
                vec3(0, jack.penetrationForce, 0),  -- Force in local space
                true              -- Force is in local space
            )
        else
            jack.penetrationDepth = 0
            jack.penetrationForce = 0
        end

        jack.physicsObject:step(jackInputForce - (jack.penetrationForce * 1.2), dt)
    end
end


return JumpJack