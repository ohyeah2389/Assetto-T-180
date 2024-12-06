-- T-180 CSP Physics Script - Jump Jack Unit Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local physicsObject = require('script_physics')


local JumpJack = class("JumpJack")


function JumpJack:initialize(params)
    self.params = params
    self.jackLength = params.jackLength
    self.jackPosition = params.jackPosition
    self.physicsObject = physicsObject({
        posMin = 0,
        posMax = self.jackLength,
        center = 0,
        position = 0,
        mass = 1,
        springCoef = 0,
        frictionCoef = 200,
        staticFrictionCoef = 0,
        expFrictionCoef = 2,
        forceMax = 1000000,
    })

    -- State variables
    self.jackRaycast = -1
    self.isTouching = false
    self.penetrationDepth = 0
    self.penetrationForce = 0
end


function JumpJack:reset()
    self.physicsObject.position = 0
    self.isTouching = false
    self.penetrationDepth = 0
    self.penetrationForce = 0
    self.jackRaycast = -1
end

function JumpJack:update(isActive, dt)
    -- Transform jack position from local to world space using car's orientation vectors
    local right = math.cross(car.look, car.up)
    local worldJackPos = car.position + right * self.jackPosition.x + car.up * self.jackPosition.y + car.look * self.jackPosition.z
    self.jackRaycast = physics.raycastTrack(worldJackPos, vec3(car.up.x, -car.up.y, car.up.z), self.jackLength + 2)

    local jackInputForce = isActive and 5000 or -1000

    self.isTouching = self.jackRaycast ~= -1 and (self.jackRaycast < self.physicsObject.position)

    if self.isTouching then
        self.penetrationDepth = self.physicsObject.position - self.jackRaycast
        self.penetrationForce = self.penetrationDepth * 100000
    else
        self.penetrationDepth = 0
        self.penetrationForce = 0
    end

    self.physicsObject:step(jackInputForce - self.penetrationForce, dt)

    if self.isTouching then ac.addForce(self.jackPosition, true, vec3(0, self.penetrationForce * 2, 0), true) end
end


return JumpJack