-- T-180 CSP Physics Script - Jump Jacks Module
-- Authored by ohyeah2389

local physicsObject = require('script_physics')

local JumpJacks = class("JumpJacks")

function JumpJacks:initialize(params)
    self.jacks = {}

    self.chargeTime = params.chargeTime or 2                               -- Seconds, time it takes from the jack to charge from empty to full
    self.dischargeRate = params.dischargeRate or 10                        -- Charge units drained per second after release
    self.contactMargin = params.contactMargin or 0.01                      -- Meters, extra reach before the jack counts as touching
    self.penetrationForceScale = params.penetrationForceScale or 40000     -- Newtons, pushback force generated from penetration depth
    self.penetrationDrag = params.penetrationDrag or 0.05                  -- Multiplier resisting extension while compressed
    self.lateralFrictionMultiplier = params.lateralFrictionMultiplier or 2 -- Multiplier for sideways grip while planted
    self.lateralForceLimit = params.lateralForceLimit or 1000              -- Newtons per m/s cap for lateral friction buildup
    self.minLateralSpeed = params.minLateralSpeed or 0.1                   -- M/s sideways speed required before friction is applied

    self.right = vec3()                                                    -- Temporary normalized right vector reused each update
    self.down = vec3()                                                     -- Temporary downward vector reused each update
    self.worldJackPos = vec3()                                             -- Temporary world-space jack position reused for raycasts
    self.groundVelocity = vec3()                                           -- Temporary velocity with vertical motion removed
    self.projection = vec3()                                               -- Temporary projected vector reused during velocity decomposition
    self.lateralVelocity = vec3()                                          -- Temporary sideways velocity reused for friction force
    self.frictionForce = vec3()                                            -- Temporary world-space friction force reused for force application
    self.verticalForce = vec3()                                            -- Temporary local-space support force reused for force application

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
                springCoef = 0,               -- N/m natural spring force, unused for jump jacks
                frictionCoef = 10,            -- Dynamic damping/friction coefficient
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
    local right = self.right:setCrossNormalized(car.up, car.look)
    local down = self.down:setScaled(car.up, -1)
    if car.velocity then
        self.groundVelocity:set(car.velocity)
    else
        self.groundVelocity:set(0, 0, 0)
    end
    self.groundVelocity:sub(self.projection:setScaled(car.up, self.groundVelocity:dot(car.up)))
    local lateralVelocity = self.lateralVelocity:set(self.groundVelocity):sub(self.projection:setScaled(car.look, self.groundVelocity:dot(car.look)))
    local lateralSpeed = lateralVelocity:length()

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

            jack.raycast = physics.raycastTrack(
                self.worldJackPos:set(car.position):addScaled(right, jack.position.x):addScaled(car.up, jack.position.y):addScaled(car.look, jack.position.z),
                down,
                jack.length + 2
            )
            jack.isTouching = jack.raycast ~= -1 and jack.raycast < jack.physicsObject.position + self.contactMargin

            if jack.isTouching then
                jack.penetrationDepth = jack.physicsObject.position - jack.raycast
                jack.penetrationForce = math.max(0, jack.penetrationDepth) ^ 0.2 * self.penetrationForceScale

                if lateralSpeed > self.minLateralSpeed then
                    ac.addForce(
                        jack.position,
                        true,
                        self.frictionForce:set(lateralVelocity):normalize():scale(-math.min(
                            self.lateralFrictionMultiplier * jack.penetrationForce,
                            lateralSpeed * self.lateralForceLimit
                        )),
                        false
                    )
                end

                ac.addForce(
                    jack.position,
                    true,
                    self.verticalForce:set(0, jack.penetrationForce, 0),
                    true
                )
            else
                jack.penetrationDepth = 0
                jack.penetrationForce = 0
            end

            local jackInputForce = jack.jackActive and jack.baseForce * (jack.chargeState ^ 0.001) or 0
            jack.physicsObject:step(jackInputForce - jack.penetrationForce * self.penetrationDrag, dt)

            jack.chargeState = math.max(jack.chargeState - dt * self.dischargeRate, 0)
            if jack.chargeState == 0 then
                jack.jackActive = false
            end
        end

        if DEBUG then
            ac.debug(name .. " chargeState", jack.chargeState)
            ac.debug(name .. " jackCharging", jack.jackCharging)
            ac.debug(name .. " jackActive", jack.jackActive)
            ac.debug(name .. " penetrationDepth", jack.penetrationDepth)
            ac.debug(name .. " penetrationForce", jack.penetrationForce)
            ac.debug(name .. " position", jack.physicsObject.position)
        end
    end
end

return JumpJacks
