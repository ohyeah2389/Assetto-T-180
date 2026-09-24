-- T-180 CSP Physics Script - Extended Controls Module
-- Authored by ohyeah2389

local state = require('script_state')
local rightStickAxis = ac.getScriptSetupValue("ACTIVE_RIGHT_STICK_AXIS") or refnumber(4)

local controls = {
    jumpJack = {
        left = ac.ControlButton("__EXT_LIGHT_JUMPJACK_LEFT"),
        right = ac.ControlButton("__EXT_LIGHT_JUMPJACK_RIGHT"),
        front = ac.ControlButton("__EXT_LIGHT_JUMPJACK_FRONT"),
        rear = ac.ControlButton("__EXT_LIGHT_JUMPJACK_REAR"),
        all = ac.ControlButton("__EXT_LIGHT_A")
    },
    turbine = {
        burner = ac.ControlButton("__EXT_LIGHT_B"),
        fuelPump = ac.ControlButton("__EXT_LIGHT_TURBINE_FUELPUMP"),
    },
    steeringModes = {
        lockRears = ac.ControlButton("__EXT_LIGHT_STEERMODE_LOCKREARS"),
        lockFronts = ac.ControlButton("__EXT_LIGHT_STEERMODE_LOCKFRONTS"),
        rearAntiCrab = ac.ControlButton("__EXT_LIGHT_STEERMODE_ANTICRAB"),
        spinMode = ac.ControlButton("__EXT_LIGHT_STEERMODE_SPINMODE"),
        spinLeft = ac.ControlButton("__EXT_LIGHT_STEERMODE_SPIN_LEFT"),
        spinRight = ac.ControlButton("__EXT_LIGHT_STEERMODE_SPIN_RIGHT"),
        autoCenter = ac.ControlButton("__EXT_LIGHT_STEERMODE_AUTOCENTER")
    }
}

controls.turbine.fuelPump:onPressed(function()
    state.turbine.fuelPumpEnabled = not state.turbine.fuelPumpEnabled
end)

controls.steeringModes.lockRears:onPressed(function()
    state.control.lockedRears = not state.control.lockedRears
end)

controls.steeringModes.lockFronts:onPressed(function()
    state.control.lockedFronts = not state.control.lockedFronts
end)

controls.steeringModes.autoCenter:onPressed(function()
    state.control.autoCenter = not state.control.autoCenter
    if not state.control.autoCenter then
        state.control.captureCurrentAngle = true
    end
end)

local function pollDirectInputAxis(targetAxis)
    if ac.getJoystickAxisValue then
        for devIdx = 0, 3 do
            local val = ac.getJoystickAxisValue(devIdx, targetAxis)
            if val and math.abs(val) > 0.05 then return val end
        end
    end
    if ac.getGamepadState then
        for padIdx = 0, 3 do
            local gp = ac.getGamepadState(padIdx)
            local rStick = gp and (gp.rightThumbstick or gp.rightStick or gp.thumbstickRight)
            if rStick then
                local rx = rStick.x or rStick[1] or rStick.X or 0.0
                local ry = rStick.y or rStick[2] or rStick.Y or 0.0
                if targetAxis == 3 and math.abs(rx) > 0.01 then return rx end
                if targetAxis == 4 and math.abs(ry) > 0.01 then return ry end
            end
        end
    end
    return ac.getJoystickAxisValue and ac.getJoystickAxisValue(0, targetAxis) or 0.0
end

local function updateStickInputs()
    local left = { x = Data.steer or 0.0, y = 0.0, mag = 0.0, angle = 0.0 }
    local right = { x = 0.0, y = 0.0, mag = 0.0, angle = 0.0 }

    local axisChoice = rightStickAxis.value

    if ac.getGamepadState then
        for padIdx = 0, 3 do
            local gp = ac.getGamepadState(padIdx)
            local lStick = gp and (gp.leftThumbstick or gp.leftStick or gp.thumbstickLeft)
            if lStick then
                local lx = lStick.x or lStick[1] or lStick.X or 0.0
                local ly = lStick.y or lStick[2] or lStick.Y or 0.0
                if math.abs(lx) > 0.01 or math.abs(ly) > 0.01 then
                    left.x, left.y = lx, ly
                    break
                end
            end
        end
    end

    if axisChoice == 0 then
        right.x = 0.0
    else
        right.x = pollDirectInputAxis(axisChoice - 1)
    end

    local leftBtn = controls.steeringModes.spinLeft:down() and 1.0 or 0.0
    local rightBtn = controls.steeringModes.spinRight:down() and 1.0 or 0.0
    if math.abs(rightBtn - leftBtn) > 0.01 then
        right.x = rightBtn - leftBtn
    end

    left.x, left.y = math.clamp(left.x, -1, 1), math.clamp(left.y, -1, 1)
    right.x, right.y = math.clamp(right.x, -1, 1), math.clamp(right.y, -1, 1)
    left.mag = math.sqrt(left.x * left.x + left.y * left.y)
    right.mag = math.sqrt(right.x * right.x + right.y * right.y)
    if left.mag > 0.01 then left.angle = math.atan2(left.x, left.y) end
    if right.mag > 0.01 then right.angle = math.atan2(right.x, right.y) end

    state.control.leftStick = left
    state.control.rightStick = right
    state.control.twinStickSpinSteer = right.x
end

function controls.update()
    state.jumpJackSystem.jackFL.active = controls.jumpJack.front:down() or controls.jumpJack.right:down() or controls.jumpJack.all:down()
    state.jumpJackSystem.jackFR.active = controls.jumpJack.front:down() or controls.jumpJack.left:down() or controls.jumpJack.all:down()
    state.jumpJackSystem.jackRL.active = controls.jumpJack.rear:down() or controls.jumpJack.right:down() or controls.jumpJack.all:down()
    state.jumpJackSystem.jackRR.active = controls.jumpJack.rear:down() or controls.jumpJack.left:down() or controls.jumpJack.all:down()
    updateStickInputs()
end

return controls
