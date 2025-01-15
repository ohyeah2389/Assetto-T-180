-- T-180 CSP Physics Script - Shared Data Module
-- Authored by ohyeah2389


local game = require('script_acConnection')


local sharedData = {}


game.sharedData = ac.connect({
    ac.StructItem.key('t180_shared_' .. car.index),
    engineDesign = ac.StructItem.int8(),
}, true, ac.SharedNamespace.CarDisplay)



function sharedData.update()
    sharedData.engineDesign = ac.getScriptSetupValue('CUSTOM_SCRIPT_ITEM_0').value

    ac.debug("sharedData.engineDesign", sharedData.engineDesign)

    ac.store('t180_shared_' .. car.index .. '.engineDesign', sharedData.engineDesign)
end


return sharedData