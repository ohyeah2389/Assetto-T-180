-- T-180 CSP Physics Script - 360deg Wheel Angle Control Computer
-- Authored by ohyeah2389


local ThreeSixtyCtrlr = class("ThreeSixtyCtrlr")


function ThreeSixtyCtrlr:initialize()
    -- Calculate initial piston lengths at 0 degrees rotation
    self.initial_p1_length = 0.5  -- Distance from (0, 0.5) to (0,1)
    self.initial_p2_length = math.sqrt(1.25)  -- Distance from (0, 0.5) to (1,0)
    
    -- Current offsets and angle
    self.current_p1_offset = 0
    self.current_p2_offset = 0
    self.current_angle = 0
    
    -- Angle limits
    self.max_angle = 180
    self.min_angle = -180
end


function ThreeSixtyCtrlr:calculatePistonLengths(target_angle)
    -- Normalize angle to -180 to 180 range
    while target_angle > 180 do target_angle = target_angle - 360 end
    while target_angle < -180 do target_angle = target_angle + 360 end
    
    -- Convert angle to radians
    local angle_rad = math.rad(target_angle)
    
    -- Calculate rotated position of attachment point (0, 0.5)
    local x = 0.5 * math.sin(angle_rad)
    local y = 0.5 * math.cos(angle_rad)
    
    -- Calculate new piston lengths
    local p1_length = math.sqrt(x * x + (1 - y) * (1 - y))
    local p2_length = math.sqrt((1 - x) * (1 - x) + y * y)
    
    -- Calculate required offsets from initial positions
    local p1_offset = p1_length - self.initial_p1_length
    local p2_offset = p2_length - self.initial_p2_length
    
    return p1_offset, p2_offset
end


function ThreeSixtyCtrlr:update(steerNormalized, dt)
    -- Get current steering input (-1 to 1) and convert to angle (-180 to 180)
    local target_angle = steerNormalized * 180
    
    -- Calculate shortest path to target angle
    local angle_diff = target_angle - self.current_angle
    if math.abs(angle_diff) > 180 then
        -- If difference is more than 180, go the other way around
        if angle_diff > 0 then
            angle_diff = angle_diff - 360
        else
            angle_diff = angle_diff + 360
        end
    end
    
    -- Angle transition (rate limited)
    local rotation_speed = 360  -- degrees per second allowed
    local max_angle_change = rotation_speed * dt
    angle_diff = math.min(math.max(angle_diff, -max_angle_change), max_angle_change)
    self.current_angle = self.current_angle + angle_diff
    
    -- Calculate required piston offsets
    local p1_offset, p2_offset = self:calculatePistonLengths(self.current_angle)
    
    -- Store current offsets
    self.current_p1_offset = p1_offset
    self.current_p2_offset = p2_offset

    return p1_offset, p2_offset
end


function ThreeSixtyCtrlr:reset()
    self.current_p1_offset = 0
    self.current_p2_offset = 0
    self.current_angle = 0
end


return ThreeSixtyCtrlr
