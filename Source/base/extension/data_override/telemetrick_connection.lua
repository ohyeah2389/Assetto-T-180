---@ext
---@diagnostic disable: undefined-global, undefined-field

local CAR = ac.getCar(0) or {}
local CPHYS = ac.getCarPhysics(0) or {}

local Telem = ac.connect({
	ac.StructItem.key(ac.getCarID(0) .. "_t180_telem_0"),
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

local function wheelSteerDeg(i)
	local wheel = CAR.wheels and CAR.wheels[i]
	if not wheel or not wheel.look then return 0 end
	return math.deg(math.atan2(math.dot(wheel.look, CAR.side), math.dot(wheel.look, CAR.look)))
end

local function input(i)
	return (CPHYS.scriptControllerInputs and CPHYS.scriptControllerInputs[i]) or 0
end

local function ch(freq, name, shortname, units, mult)
	local c = { freq = freq, datatype = 7, datasize = 4, name = name, shortname = shortname }
	if units then c.units = units end
	if mult then c.mult = mult end
	return c
end

local function add(lineTable, ...)
	for i = 1, select("#", ...) do
		lineTable[#lineTable + 1] = select(i, ...)
	end
end

---@diagnostic disable-next-line: duplicate-set-field
extCar.loadExtChannels = function()
	local extChannels = {
		turbineCoreTemp = ch(10, "Turbine Core Temp", "turbineCoreTemp", "K"),
		turbineFrameTemp = ch(10, "Turbine Frame Temp", "turbineFrameTemp", "K"),
		turbineFuelPump = ch(10, "Turbine Fuel Pump", "turbineFuelPump"),
		turbineThermalDerate = ch(10, "Turbine Thermal Derate", "turbineThermalDerate", "%", 100),
		turbineRPM = ch(20, "Turbine RPM", "turbineRPM", "rpm"),
		turbineThrottle = ch(20, "Turbine Throttle", "turbineThrottle", "%", 100),
		turbineAfterburner = ch(20, "Turbine Afterburner", "turbineAfterburner", "%", 100),
		turbineCoreThrust = ch(20, "Turbine Core Thrust", "turbineCoreThrust", "N"),
		turbineAfterburnerThrust = ch(20, "Turbine Afterburner Thrust", "turbineAfterburnerThrust", "N"),
		systemTotalThrust = ch(20, "System Total Thrust", "systemTotalThrust", "N"),
		driftAngle = ch(20, "Drift Angle", "driftAngle", "deg"),
		syntheticDownforce = ch(20, "Synthetic Downforce", "syntheticDownforce", "N"),
		controlPedal = ch(20, "Control Pedal", "controlPedal", "%", 100),
		steerFL = ch(20, "Steer FL", "steerFL", "deg"),
		steerFR = ch(20, "Steer FR", "steerFR", "deg"),
		steerRL = ch(20, "Steer RL", "steerRL", "deg"),
		steerRR = ch(20, "Steer RR", "steerRR", "deg"),
		jackChargeFL = ch(20, "Jump Jack Charge FL", "jackChargeFL", "%", 100),
		jackChargeFR = ch(20, "Jump Jack Charge FR", "jackChargeFR", "%", 100),
		jackChargeRL = ch(20, "Jump Jack Charge RL", "jackChargeRL", "%", 100),
		jackChargeRR = ch(20, "Jump Jack Charge RR", "jackChargeRR", "%", 100),
		jackForceFL = ch(20, "Jump Jack Force FL", "jackForceFL", "N"),
		jackForceFR = ch(20, "Jump Jack Force FR", "jackForceFR", "N"),
		jackForceRL = ch(20, "Jump Jack Force RL", "jackForceRL", "N"),
		jackForceRR = ch(20, "Jump Jack Force RR", "jackForceRR", "N"),
		jackPosFL = ch(20, "Jump Jack Pos FL", "jackPosFL", "m"),
		jackPosFR = ch(20, "Jump Jack Pos FR", "jackPosFR", "m"),
		jackPosRL = ch(20, "Jump Jack Pos RL", "jackPosRL", "m"),
		jackPosRR = ch(20, "Jump Jack Pos RR", "jackPosRR", "m"),
	}

	local ordered_keys = {
		"turbineCoreTemp",
		"turbineFrameTemp",
		"turbineFuelPump",
		"turbineThermalDerate",
		"turbineRPM",
		"turbineThrottle",
		"turbineAfterburner",
		"turbineCoreThrust",
		"turbineAfterburnerThrust",
		"systemTotalThrust",
		"driftAngle",
		"syntheticDownforce",
		"controlPedal",
		"steerFL",
		"steerFR",
		"steerRL",
		"steerRR",
		"jackChargeFL",
		"jackChargeFR",
		"jackChargeRL",
		"jackChargeRR",
		"jackForceFL",
		"jackForceFR",
		"jackForceRL",
		"jackForceRR",
		"jackPosFL",
		"jackPosFR",
		"jackPosRL",
		"jackPosRR",
	}

	return extChannels, ordered_keys
end

---@diagnostic disable-next-line: duplicate-set-field
extCar.updateLogExt = function(lineTable, rate)
	if rate == 10 or not rate then
		add(lineTable,
		input(21),
		input(22),
		Telem.turbineFuelPump,
		Telem.turbineThermalDerate
	)
	end

	if rate == 20 or not rate then
		add(lineTable,
			Telem.turbineRPM,
			Telem.turbineThrottle,
			Telem.turbineAfterburner,
			Telem.turbineCoreThrust,
			Telem.turbineAfterburnerThrust,
			Telem.systemTotalThrust,
			Telem.driftAngle,
			Telem.syntheticDownforce,
			Telem.controlPedal,
			wheelSteerDeg(0),
			wheelSteerDeg(1),
			wheelSteerDeg(2),
			wheelSteerDeg(3),
			Telem.jackChargeFL,
			Telem.jackChargeFR,
			Telem.jackChargeRL,
			Telem.jackChargeRR,
			Telem.jackForceFL,
			Telem.jackForceFR,
			Telem.jackForceRL,
			Telem.jackForceRR,
			Telem.jackPosFL,
			Telem.jackPosFR,
			Telem.jackPosRL,
			Telem.jackPosRR
		)
	end

	return lineTable
end
