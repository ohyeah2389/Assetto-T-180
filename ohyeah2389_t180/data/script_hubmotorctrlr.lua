-- T-180 CSP Physics Script - Hub Motor Controller Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local config = require('script_config')
local helpers = require('script_helpers')
local state = require('script_state')


local HubMotorController = class("HubMotorController")

function HubMotorController:update(dt)
    local driveInverted = car.gear == -1
    local regenSpeedFadeout = helpers.mapRange(math.abs(car.speedKmh), 2, 5, 0, 1, true)

    local commandL = math.clamp(helpers.mapRange(game.car_cphys.steer, 0, 1, game.car_cphys.gas, 0, true) - (game.car_cphys.brake * regenSpeedFadeout), -1, 1)
    local commandR = math.clamp(helpers.mapRange(game.car_cphys.steer, -1, 0, 0, game.car_cphys.gas, true) - (game.car_cphys.brake * regenSpeedFadeout), -1, 1)

    -- During braking, use braking split
    -- During acceleration, scale from default to max based on countersteer
    local frontMultiplier
    if (game.car_cphys.brake > 0) and not driveInverted then
        frontMultiplier = config.electrics.torqueSplit.brakingFrontRatio
    else
        frontMultiplier = helpers.mapRange(state.control.countersteer, 0, 90, 
            config.electrics.torqueSplit.defaultFrontRatio, 
            config.electrics.torqueSplit.maxFrontRatio, 
            true)
    end
    local rearMultiplier = 1 - frontMultiplier
    
    local wheelCommands = {
        commandR * frontMultiplier,  -- Front Left
        commandL * frontMultiplier,  -- Front Right
        commandR * rearMultiplier,   -- Rear Left
        commandL * rearMultiplier     -- Rear Right
    }

    -- Find the maximum absolute value for normalization
    local maxValue = 0
    for _, command in ipairs(wheelCommands) do
        maxValue = math.max(maxValue, math.abs(command))
    end

    -- Normalize all values by dividing by maxValue (if not zero)
    -- Then scale by throttle input
    if maxValue > 0 then
        local throttleScale = math.abs(game.car_cphys.gas - game.car_cphys.brake)
        for i = 1, 4 do
            wheelCommands[i] = (wheelCommands[i] / maxValue) * throttleScale * (driveInverted and -1 or 1)
        end
    end

    local rearCoastOffset = helpers.mapRange(car.speedKmh, 0, 50, 0, 1, true) * 0.2

    local wheelCommands = {
        commandR,  -- Front Left
        commandL,  -- Front Right
        math.clamp(commandR + rearCoastOffset, -1, 1),   -- Rear Left
        math.clamp(commandL + rearCoastOffset, -1, 1)     -- Rear Right
    }

    local guessedSpeedDuringAccel
    if driveInverted then
        -- In reverse, use max speed when accelerating
        guessedSpeedDuringAccel = math.max(
            math.max(game.car_cphys.wheels[0].angularSpeed, game.car_cphys.wheels[1].angularSpeed),
            math.max(game.car_cphys.wheels[2].angularSpeed, game.car_cphys.wheels[3].angularSpeed)
        )
    else
        -- In forward, use min speed when accelerating
        guessedSpeedDuringAccel = math.min(
            math.min(game.car_cphys.wheels[0].angularSpeed, game.car_cphys.wheels[1].angularSpeed),
            math.min(game.car_cphys.wheels[2].angularSpeed, game.car_cphys.wheels[3].angularSpeed)
        ) + (math.min(
            math.max(game.car_cphys.wheels[0].angularSpeed, game.car_cphys.wheels[1].angularSpeed),
            math.max(game.car_cphys.wheels[2].angularSpeed, game.car_cphys.wheels[3].angularSpeed)
        ) - math.min(
            math.min(game.car_cphys.wheels[0].angularSpeed, game.car_cphys.wheels[1].angularSpeed),
            math.min(game.car_cphys.wheels[2].angularSpeed, game.car_cphys.wheels[3].angularSpeed)
        )) / 2
    end

    local guessedSpeedDuringBrake
    if driveInverted then
        -- In reverse, use min speed when braking
        guessedSpeedDuringBrake = math.min(
            math.min(game.car_cphys.wheels[0].angularSpeed, game.car_cphys.wheels[1].angularSpeed),
            math.min(game.car_cphys.wheels[2].angularSpeed, game.car_cphys.wheels[3].angularSpeed)
        )
    else
        -- In forward, use max speed when braking
        guessedSpeedDuringBrake = math.max(
            math.max(game.car_cphys.wheels[0].angularSpeed, game.car_cphys.wheels[1].angularSpeed),
            math.max(game.car_cphys.wheels[2].angularSpeed, game.car_cphys.wheels[3].angularSpeed)
        ) - (math.max(
            math.max(game.car_cphys.wheels[0].angularSpeed, game.car_cphys.wheels[1].angularSpeed),
            math.max(game.car_cphys.wheels[2].angularSpeed, game.car_cphys.wheels[3].angularSpeed)
        ) - math.max(
            math.min(game.car_cphys.wheels[0].angularSpeed, game.car_cphys.wheels[1].angularSpeed),
            math.min(game.car_cphys.wheels[2].angularSpeed, game.car_cphys.wheels[3].angularSpeed)
        )) / 2
    end

    -- Traction control
    local tcSlipThreshold = config.electrics.slipControl.slipThreshold
    local tcStrength = config.electrics.slipControl.cutStrength
    
    -- Calculate slip ratios and apply TC for each wheel
    for i = 1, 4 do
        local wheelSpeed = game.car_cphys.wheels[i-1].angularSpeed
        local targetSpeed
        
        -- Use appropriate guessed speed based on whether accelerating or braking
        if game.car_cphys.gas > game.car_cphys.brake then
            targetSpeed = guessedSpeedDuringAccel
        else
            targetSpeed = guessedSpeedDuringBrake
        end
        
        -- Calculate slip ratio
        local slipRatio = 0
        if math.abs(targetSpeed) > 0.1 then -- Avoid division by very small numbers
            slipRatio = (wheelSpeed - targetSpeed) / math.abs(targetSpeed)
        end
        
        -- Apply TC reduction if slip exceeds threshold
        if math.abs(slipRatio) > tcSlipThreshold then
            local tcFactor = 1 - (math.abs(slipRatio) - tcSlipThreshold) * tcStrength
            tcFactor = math.max(0.1, tcFactor) -- Don't cut power completely
            wheelCommands[i] = wheelCommands[i] * tcFactor
        end
    end

    ac.debug("torqueL", commandL)
    ac.debug("torqueR", commandR)
    ac.debug("wheel torqueFL", wheelCommands[1])
    ac.debug("wheel torqueFR", wheelCommands[2])
    ac.debug("wheel torqueRL", wheelCommands[3])
    ac.debug("wheel torqueRR", wheelCommands[4])
    ac.debug("regen speed fadeout", regenSpeedFadeout)

    return wheelCommands
end

return HubMotorController