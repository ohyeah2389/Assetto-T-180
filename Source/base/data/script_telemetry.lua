-- T-180 CSP Physics Script - Telemetry Module
-- Authored by ohyeah2389

local data = ac.connect({
    ac.StructItem.key(ac.getCarID(car.index) .. "_t180_telem_" .. car.index),
    turbineRPM = ac.StructItem.float(),
    turbineThrottle = ac.StructItem.float(),
    turbineAfterburner = ac.StructItem.float(),
    turbineFuelPump = ac.StructItem.float(),
    turbineThermalDerate = ac.StructItem.float(),
    turbineCoreThrust = ac.StructItem.float(),
    turbineAfterburnerThrust = ac.StructItem.float(),
    systemTotalThrust = ac.StructItem.float(),
    driftAngle = ac.StructItem.float(),
    syntheticDownforce = ac.StructItem.float(),
    controlPedal = ac.StructItem.float(),
    jackChargeFL = ac.StructItem.float(),
    jackChargeFR = ac.StructItem.float(),
    jackChargeRL = ac.StructItem.float(),
    jackChargeRR = ac.StructItem.float(),
    jackForceFL = ac.StructItem.float(),
    jackForceFR = ac.StructItem.float(),
    jackForceRL = ac.StructItem.float(),
    jackForceRR = ac.StructItem.float(),
    jackPosFL = ac.StructItem.float(),
    jackPosFR = ac.StructItem.float(),
    jackPosRL = ac.StructItem.float(),
    jackPosRR = ac.StructItem.float(),
}, true, ac.SharedNamespace.Shared)

local function jack(j)
    j = j or {}
    return j.chargeState or 0, j.appliedForce or 0, (j.physicsObject and j.physicsObject.position) or 0
end

local Telem = {}

function Telem.publish(s)
    data.turbineRPM = s.rpm or 0
    data.turbineThrottle = s.throttle or 0
    data.turbineAfterburner = s.afterburner or 0
    data.turbineFuelPump = s.fuelPump or 0
    data.turbineThermalDerate = s.derate or 1
    data.turbineCoreThrust = s.coreThrust or 0
    data.turbineAfterburnerThrust = s.afterburnerThrust or 0
    data.systemTotalThrust = s.systemTotalThrust or 0
    data.driftAngle = s.driftAngle or 0
    data.syntheticDownforce = s.syntheticDownforce or 0
    data.controlPedal = s.controlPedal or 0

    local jacks = s.jacks or {}
    data.jackChargeFL, data.jackForceFL, data.jackPosFL = jack(jacks.frontLeft)
    data.jackChargeFR, data.jackForceFR, data.jackPosFR = jack(jacks.frontRight)
    data.jackChargeRL, data.jackForceRL, data.jackPosRL = jack(jacks.rearLeft)
    data.jackChargeRR, data.jackForceRR, data.jackPosRR = jack(jacks.rearRight)
end

return Telem
