-- Mach 5 CSP Physics Script - Physics Object Class Definition
-- Authored by ohyeah2389


local physics = class("Physics")


function physics:initialize(params)
    self.posMax = params.posMax or 1
    self.posMin = params.posMin or 0
    self.center = params.center or 0.5
    self.position = params.position or self.center
    self.speed = 0 -- meters per second (m/s)
    self.force = 0 -- Newtons (N)
    self.accel = 0 -- meters per second squared (m/s^2)
    self.frictionCoef = params.frictionCoef or 0.1
    self.staticFrictionCoef = params.staticFrictionCoef or 1.5
    self.expFrictionCoef = params.expFrictionCoef or 1.0
    self.mass = params.mass or 1 -- kilograms (kg)
    self.springCoef = params.springCoef or 0 -- Newtons per meter (N/m)
    self.forceMax = params.forceMax or 10000
    self.constantForce = params.constantForce or 0
    self.endstopRate = params.endstopRate or 1
    self.rotary = params.rotary or false

    if self.rotary then
        self.angle = params.initialAngle or 0  -- Current angle in radians
        self.angularSpeed = 0  -- Angular speed in radians per second
        self.inertia = params.inertia or 1  -- Moment of inertia in kg*m^2
        self.torque = 0  -- Applied torque in Nm
        self.angularAccel = 0  -- Angular acceleration in rad/s^2
    end
end


function physics:step(force, dt)
    if self.rotary then
        -- Rotary motion calculations
        local distanceFromCenter = (self.angle % (2 * math.pi)) - math.pi
        self.torque = math.clamp(force * self.inertia, -self.forceMax, self.forceMax) + (distanceFromCenter * -self.springCoef) + self.constantForce

        -- Static friction
        local staticFrictionTorque = self.frictionCoef * self.staticFrictionCoef * self.inertia
        if math.abs(self.torque) < staticFrictionTorque and self.angularSpeed == 0 then
            self.angularAccel = 0
        else
            -- Kinetic friction with speed-dependent component
            local frictionTorque = self.frictionCoef * self.inertia * 
                                 (math.abs(self.angularSpeed) ^ self.expFrictionCoef) * 
                                 math.sign(self.angularSpeed)
            self.angularAccel = (self.torque - frictionTorque) / self.inertia
        end

        -- Update angular speed and position
        local newAngularSpeed = self.angularSpeed + self.angularAccel * dt
        if math.sign(newAngularSpeed) == math.sign(self.angularSpeed) or self.angularSpeed == 0 then
            self.angularSpeed = newAngularSpeed
        else
            self.angularSpeed = 0 -- Prevent reversing direction due to friction
        end

        self.angle = self.angle + self.angularSpeed * dt

        -- Normalize angle to [0, 2π)
        self.angle = self.angle % (2 * math.pi)
    else
        -- Linear motion calculations (updated with similar friction model)
        local distanceFromCenter = self.position - self.center
        self.force = math.clamp(force * self.mass, -self.forceMax, self.forceMax) + 
                     (distanceFromCenter * -self.springCoef) + self.constantForce

        -- Static friction
        local staticFrictionForce = self.frictionCoef * self.staticFrictionCoef * self.mass
        if math.abs(self.force) < staticFrictionForce and self.speed == 0 then
            self.accel = 0
        else
            -- Kinetic friction
            local frictionForce = self.frictionCoef * self.mass * math.sign(self.speed)
            self.accel = (self.force - frictionForce) / self.mass
        end

        -- Update speed and prevent reversing direction due to friction
        local newSpeed = self.speed + self.accel * dt
        if math.sign(newSpeed) == math.sign(self.speed) or self.speed == 0 then
            self.speed = newSpeed
        else
            self.speed = 0
        end

        -- Update position after all forces are calculated
        self.position = self.position + (self.speed * dt)
        if self.position > self.posMax then
            local overshoot = self.position - self.posMax
            local endstopForce = overshoot * self.endstopRate
            self.force = math.clamp(self.force - endstopForce, -self.forceMax, self.forceMax)
            self.position = self.posMax
            self.speed = 0
        elseif self.position < self.posMin then
            local overshoot = self.posMin - self.position
            local endstopForce = overshoot * self.endstopRate
            self.force = math.clamp(self.force + endstopForce, -self.forceMax, self.forceMax)
            self.position = self.posMin
            self.speed = 0
        end
    end
end


return physics