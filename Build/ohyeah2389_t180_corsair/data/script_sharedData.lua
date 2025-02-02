-- T-180 CSP Physics Script - Shared Data Module
-- Authored by ohyeah2389


local game = require('script_acConnection')


local sharedData = {}


game.sharedData = ac.connect({
    ac.StructItem.key('t180_shared_' .. car.index),
}, true, ac.SharedNamespace.CarDisplay)



function sharedData.update()
end


return sharedData