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

local rightStickGUID = nil
local rightStickPad = nil
local axisRest = {}

local function pollGamepadRightStick()
    if rightStickPad then return ac.getGamepadAxisValue(rightStickPad, ac.GamepadAxis.RightThumbX) end
    for padIdx = 0, 7 do
        local x = ac.getGamepadAxisValue(padIdx, ac.GamepadAxis.RightThumbX)
        if math.abs(x) > 0.5 then
            rightStickPad = padIdx
            return x
        end
    end
    return nil
end

local function pollDirectInputAxis(targetAxis)
    local devIdx = rightStickGUID and ac.getJoystickIndexByInstanceGUID(rightStickGUID)
    if devIdx then return ac.getJoystickAxisValue(devIdx, targetAxis) end
    for i = 0, ac.getJoystickCount() - 1 do
        local val = ac.getJoystickAxisValue(i, targetAxis)
        axisRest[i] = axisRest[i] or val
        if math.abs(val - axisRest[i]) > 0.5 then
            rightStickGUID = ac.getJoystickInstanceGUID(i)
            return val
        end
    end
    return 0.0
end

local function updateStickInputs()
    local left = { x = Data.steer or 0.0, y = 0.0, mag = 0.0, angle = 0.0 }
    local right = { x = 0.0, y = 0.0, mag = 0.0, angle = 0.0 }

    local axisChoice = rightStickAxis.value
    if axisChoice ~= 0 then
        right.x = pollGamepadRightStick() or pollDirectInputAxis(axisChoice - 1)
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
