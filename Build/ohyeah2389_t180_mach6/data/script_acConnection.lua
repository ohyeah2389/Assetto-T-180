-- Mach 5 CSP Physics Script - Assetto Corsa / CSP Connection Module
-- Authored by ohyeah2389


local acConnection = {}


--acConnection.sharedData = ac.connect({
--    ac.StructItem.key('asre2_' .. car.index),
--}, true, ac.SharedNamespace.CarDisplay) -- Remember to connect new items in script.lua transmitControllerValues() and to update every instance of sharedData in every script in /extension


acConnection.sim = ac.getSim()
acConnection.car_cphys = ac.accessCarPhysics()
acConnection.carPhysics = ac.getCarPhysics(0)


return acConnection