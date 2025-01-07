-- T-180 CSP Physics Script - Extended Controls Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local state = require('script_state')


local controls = {
    jumpJack = {
        left = ac.ControlButton("__EXT_LIGHT_JUMPJACK_LEFT"),
        right = ac.ControlButton("__EXT_LIGHT_JUMPJACK_RIGHT"),
        all = ac.ControlButton("__EXT_LIGHT_A")
    },
    turbine = {
        throttle = ac.ControlButton("__EXT_LIGHT_B"),
        fuelPump = ac.ControlButton("__EXT_LIGHT_TURBINE_FUELPUMP"),
        clutchDisconnect = ac.ControlButton("__EXT_LIGHT_TURBINE_CLUTCHDISCO")
    }
}


controls.turbine.fuelPump:onPressed(function()
    state.turbine.fuelPumpEnabled = not state.turbine.fuelPumpEnabled
end)

controls.turbine.clutchDisconnect:onPressed(function()
    state.turbine.clutchDisconnected = not state.turbine.clutchDisconnected
end)


function controls.update()
    state.jumpJackSystem.jackFL.active = controls.jumpJack.right:down() or controls.jumpJack.all:down()
    state.jumpJackSystem.jackFR.active = controls.jumpJack.left:down() or controls.jumpJack.all:down()
    state.jumpJackSystem.jackRL.active = controls.jumpJack.right:down() or controls.jumpJack.all:down()
    state.jumpJackSystem.jackRR.active = controls.jumpJack.left:down() or controls.jumpJack.all:down()
end


return controls