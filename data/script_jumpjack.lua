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
    -- Calculate current pitch and roll angles
    local pitch = math.asin(math.dot(car.look, vec3(0, 1, 0)))  -- Pitch angle
    local right = math.cross(car.look, car.up)  -- Calculate right vector
    local roll = math.asin(math.dot(right, vec3(0, 1, 0)))  -- Roll angle using calculated right vector
    
    -- PID control for leveling
    -- Pitch control (front-back)
    local pitchError = -pitch
    self.pitchErrorSum = self.pitchErrorSum + pitchError * dt
    local pitchDerivative = (pitchError - self.lastPitchError) / dt
    local pitchCorrection = self.levelingP * pitchError + 
                           self.levelingI * self.pitchErrorSum + 
                           self.levelingD * pitchDerivative
    self.lastPitchError = pitchError
    
    -- Roll control (left-right)
    local rollError = roll
    self.rollErrorSum = self.rollErrorSum + rollError * dt
    local rollDerivative = (rollError - self.lastRollError) / dt
    local rollCorrection = self.levelingP * rollError + 
                          self.levelingI * self.rollErrorSum + 
                          self.levelingD * rollDerivative
    self.lastRollError = rollError
    
    for name, jack in pairs(self.jacks) do
        -- Transform jack position from local to world space using car's orientation vectors
        local right = math.cross(car.look, car.up)
        local worldJackPos = car.position + (right * jack.position.x) + (car.up * jack.position.y) + (car.look * jack.position.z)
        local jackDirection = -car.up
        jack.raycast = physics.raycastTrack(worldJackPos, jackDirection, jack.length + 2)

        -- Apply corrections based on jack position
        local jackInputForce = activationPattern[name] and self.jacks[name].baseForce or -1000
        
        if activationPattern[name] then
            -- Add pitch correction (front/rear)
            if name:find("front") then
                jackInputForce = jackInputForce + pitchCorrection
            else  -- rear
                jackInputForce = jackInputForce - pitchCorrection
            end
            
            -- Add roll correction (left/right)
            if name:find("Left") then
                jackInputForce = jackInputForce + rollCorrection
            else  -- right
                jackInputForce = jackInputForce - rollCorrection
            end
        end

        jack.isTouching = jack.raycast ~= -1 and (jack.raycast < jack.physicsObject.position + 0.01)

        local forcePoint = worldJackPos + jackDirection * jack.raycast
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
                local frictionMultiplier = 5
                local lateralFrictionForce = -lateralVelocity:normalize() * math.min(
                    frictionMultiplier * jack.penetrationForce,
                    lateralSpeed * 1000
                )
                
                --ac.addForce(forcePoint - car.position, true, lateralFrictionForce, true)
            end

            -- Apply vertical force at the contact point
            ac.addForce(
                forcePoint - car.position,
                true,
                car.up * jack.penetrationForce,
                true
            )
        else
            jack.penetrationDepth = 0
            jack.penetrationForce = 0
        end

        jack.physicsObject:step(jackInputForce - (jack.penetrationForce * 1.2), dt)
    end
end


return JumpJack