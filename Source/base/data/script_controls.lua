-- T-180 CSP Physics Script - Extended Controls Module
-- Authored by ohyeah2389


local state = require('script_state')


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
        spinMode = ac.ControlButton("__EXT_LIGHT_STEERMODE_SPINMODE")
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

function controls.update()
    state.jumpJackSystem.jackFL.active = controls.jumpJack.front:down() or controls.jumpJack.right:down() or controls.jumpJack.all:down()
    state.jumpJackSystem.jackFR.active = controls.jumpJack.front:down() or controls.jumpJack.left:down() or controls.jumpJack.all:down()
    state.jumpJackSystem.jackRL.active = controls.jumpJack.rear:down() or controls.jumpJack.right:down() or controls.jumpJack.all:down()
    state.jumpJackSystem.jackRR.active = controls.jumpJack.rear:down() or controls.jumpJack.left:down() or controls.jumpJack.all:down()
end


return controls