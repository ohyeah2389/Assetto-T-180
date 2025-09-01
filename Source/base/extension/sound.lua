-- T-180 CSP Sound Script
-- Authored by ohyeah2389

local physObj = require("physics_object")

local car_phys = ac.getCarPhysics(0)

local torqueWobbler = physObj({
    mass = 0.01,
    frictionCoef = 1,
    expFrictionCoef = 1,
    posMax = 100,
    posMin = -100,
    center = 0,
    dampingCoef = 0.1,
})

local audio_xmsn = ac.AudioEvent("/cars/" .. ac.getCarID(0) .. "/xmsn_lua", true, true)
audio_xmsn.cameraInteriorMultiplier = 1.0
audio_xmsn.cameraExteriorMultiplier = 1.0
audio_xmsn.volume = 1.0
audio_xmsn:setPosition(vec3(0.0, 1.2, 0.225), vec3(0, 0, 1), vec3(0, 1, 0))
audio_xmsn:start()

---@diagnostic disable-next-line: duplicate-set-field
function script.update(dt)
    ac.boostFrameRate()

    local driveVel = car.drivetrainSpeed
    local rootVel = (car.gear ~= 0) and ((car.rpm * math.pi / 30) / car_phys.finalRatio * 0.955) or 0
    local torque = sim.isReplayActive and (car.gas * 80) or ((car.drivetrainTorque / 5) or 100)

    local delta = (torque - torqueWobbler.position) * 30

    torqueWobbler:step(delta, dt)

    local torqueOutput = torqueWobbler.position

    audio_xmsn:setParam("drive_vel", driveVel)
    audio_xmsn:setParam("root_vel", rootVel)
    audio_xmsn:setParam("torque", torqueOutput)

    ac.debug("drive_vel", driveVel)
    ac.debug("root_vel", rootVel)
    ac.debug("torqueOutput", torqueOutput)
    ac.debug("delta", delta)
    ac.debug("torqueWobbler.position", torqueWobbler.position)
    ac.debug("torque", torque)
    ac.debug("drivetrainTorque", car.drivetrainTorque)
end