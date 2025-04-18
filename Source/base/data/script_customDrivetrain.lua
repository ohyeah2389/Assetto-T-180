-- T-180 CSP Physics Script - Custom Drivetrain Physics Module
-- Authored by ohyeah2389


local game = require('script_acConnection')


local drivetrain = class("drivetrain")


function drivetrain:initialize(params)
    self.drivenWheels = params.drivenWheels or {ac.Wheel.RearLeft, ac.Wheel.RearRight}
    self.finalDriveRatio = params.finalDriveRatio or 6

    -- Open differential parameters with speed-dependent coupling
    self.couplingStiffness = params.couplingStiffness or 200
    self.couplingDamping = params.couplingDamping or self.couplingStiffness/2

    -- Clutch parameters
    self.clutchEngageRate = params.clutchEngageRate or 2
    self.minClutchCoupling = params.minClutchCoupling or 0.0

    self.torqueLimit = params.torqueLimit or 2000

    self.id = params.id or "rear"
end


function drivetrain:update(inputShaftSpeed, inputTorque, clutchPosition, dt)
    local leftWheel = game.carPhysics.wheels[self.drivenWheels[1]]
    local rightWheel = game.carPhysics.wheels[self.drivenWheels[2]]

    -- Clutch engagement is the clutch position to the power of the clutch engage rate
    local clutchEngagement = (clutchPosition ^ self.clutchEngageRate)

    -- Final drive output speed is the input shaft speed (which is in RPM, so we convert it back to rad/s) multiplied (?) by the final drive ratio
    local finalDriveOutputSpeed = (inputShaftSpeed * math.pi / 30) / self.finalDriveRatio

    -- Since this is an open differential (currently), we need the average wheel speed for calculating the torque on the differential input shaft
    local avgWheelSpeed = (leftWheel.shaftVelocity + rightWheel.shaftVelocity) / 2

    -- Clutch engagement should affect the coupling stiffness and damping, so we apply that here
    local currentStiffness = math.lerp(self.couplingStiffness * self.minClutchCoupling, self.couplingStiffness, clutchEngagement)
    local currentDamping = math.lerp(self.couplingDamping * self.minClutchCoupling, self.couplingDamping, clutchEngagement)

    -- Calculate coupling torque with speed-scaled spring-damper model
    local speedDiff = finalDriveOutputSpeed - avgWheelSpeed
    local couplingTorque = (speedDiff * currentStiffness * dt) + (speedDiff * currentDamping)

    -- Total torque is the input torque (corrected for final drive ratio and scaled by clutch engagement) plus the coupling torque
    local totalTorque = (((inputTorque / self.finalDriveRatio) * clutchEngagement) + couplingTorque)

    -- Calculate wheel speed difference for torque distribution
    local wheelSpeedDiff = math.abs(leftWheel.shaftVelocity - rightWheel.shaftVelocity)
    local speedRatio = wheelSpeedDiff / (math.max(math.abs(leftWheel.shaftVelocity), math.abs(rightWheel.shaftVelocity)) + 0.001)
    
    -- Base torque distribution (50/50)
    local leftRatio = 0.5
    local rightRatio = 0.5
    
    -- Adjust distribution based on which wheel is slower (up to 90/10 split)
    if leftWheel.shaftVelocity < rightWheel.shaftVelocity then
        leftRatio = math.lerp(0.5, 0.9, speedRatio)
        rightRatio = 1 - leftRatio
    else
        rightRatio = math.lerp(0.5, 0.9, speedRatio)
        leftRatio = 1 - rightRatio
    end

    -- Apply torques to wheels with new distribution (with limits)
    local limitedTorqueLeft = math.clamp(totalTorque * leftRatio, -self.torqueLimit, self.torqueLimit)
    local limitedTorqueRight = math.clamp(totalTorque * rightRatio, -self.torqueLimit, self.torqueLimit)
    ac.addElectricTorque(self.drivenWheels[1], limitedTorqueLeft, true)
    ac.addElectricTorque(self.drivenWheels[2], limitedTorqueRight, true)

    -- Calculate feedback torque through final drive
    local rawFeedback = ((leftWheel.feedbackTorque + (0.1 * leftWheel.brakeTorque)) + (rightWheel.feedbackTorque + (0.1 * rightWheel.brakeTorque))) * self.finalDriveRatio

    -- Scale feedback by clutch engagement
    local clutchFeedback = rawFeedback * clutchEngagement
    local finalFeedback = math.clamp(clutchFeedback, -self.torqueLimit, self.torqueLimit)

    -- Debug outputs
    ac.debug("drivetrain." .. self.id .. ".clutchEngagement", clutchEngagement)
    ac.debug("drivetrain." .. self.id .. ".finalDriveOutputSpeed (rads)", finalDriveOutputSpeed)
    ac.debug("drivetrain." .. self.id .. ".avgWheelSpeed (rads)", avgWheelSpeed)
    ac.debug("drivetrain." .. self.id .. ".speedDiff", speedDiff)
    ac.debug("drivetrain." .. self.id .. ".currentStiffness", currentStiffness)
    ac.debug("drivetrain." .. self.id .. ".couplingTorque", couplingTorque)
    ac.debug("drivetrain." .. self.id .. ".totalTorque", totalTorque)
    ac.debug("drivetrain." .. self.id .. ".wheelSpeedDiff", wheelSpeedDiff)
    ac.debug("drivetrain." .. self.id .. ".speedRatio", speedRatio)
    ac.debug("drivetrain." .. self.id .. ".leftRatio", leftRatio)
    ac.debug("drivetrain." .. self.id .. ".rightRatio", rightRatio)
    ac.debug("drivetrain." .. self.id .. ".limitedTorqueLeft", limitedTorqueLeft)
    ac.debug("drivetrain." .. self.id .. ".limitedTorqueRight", limitedTorqueRight)
    ac.debug("drivetrain." .. self.id .. ".output.rawFeedback", rawFeedback)
    ac.debug("drivetrain." .. self.id .. ".output.finalFeedback", finalFeedback)

    return finalFeedback
end


return drivetrain
