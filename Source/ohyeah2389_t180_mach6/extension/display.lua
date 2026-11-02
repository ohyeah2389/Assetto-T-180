-- T-180 Cockpit Display Script - Mach 6
-- Authored by ohyeah2389

local uiState = ac.getUI()
local physics = ac.getCarPhysics(car.index) or {}

local display = class("Display")

local vec2Zero = vec2(0, 0)
local fontSquare = ui.DWriteFont("ST-SimpleSquare.ttf")
local fontTime = ui.DWriteFont("EHSMB.ttf")
local fontBahnschrift = ui.DWriteFont("Bahnschrift")

local colors = {
    white = rgbm(1, 1, 1, 1),
    red = rgbm(1, 0, 0, 1),
    timeRed = rgbm(1, 0.4, 0.4, 1),
    black = rgbm(0, 0, 0, 1),
    tempBarBlue = rgbm(0, 0.2, 1, 1),
    tempBarGreen = rgbm(0, 1, 0, 1),
    tempBarYellow = rgbm(1, 1, 0, 1),
    tempBarRed = rgbm(1, 0, 0, 1),
}

local displaySizes = {
    center = vec2(315, 250),
    side = vec2(362, 250)
}
local backgroundInset = {
    center = displaySizes.center * 0.005,
    side = displaySizes.side * 0.02
}

local cameraCenter = ac.accessCarRenderingCamera("RENDERING_CAMERA_0") or {}
local cameraRenderPositions = {
    center = {
        pos = vec2(0, 0),
        size = displaySizes.center
    }
}

local uiItemPos = {
    speedUnits = vec2(displaySizes.center.x * 0.1275, displaySizes.center.y * 0.33),
    speedValue = vec2(displaySizes.center.x * 0.2675, displaySizes.center.y * 0.2875),
    coreTemp = vec2(displaySizes.center.x * 0.615, displaySizes.center.y * 0.6615),
    frameTemp = vec2(displaySizes.center.x * 0.615, displaySizes.center.y * 0.74),
    coreTempBars = vec2(displaySizes.center.x * 0.55, displaySizes.center.y * 0.675),
    frameTempBars = vec2(displaySizes.center.x * 0.55, displaySizes.center.y * 0.755),
    turbineRPM = vec2(displaySizes.center.x * 0.133, displaySizes.center.y * 0.5),
    engineRPM = vec2(displaySizes.center.x * 0.133, displaySizes.center.y * 0.335),
    accelLength = vec2(displaySizes.center.x * 0.85, displaySizes.center.y * 0.315),
    realTime = vec2(displaySizes.center.x * 0.29, displaySizes.center.y * 0.125),
    currentLapTime = vec2(displaySizes.center.x * 0.29, displaySizes.center.y * 0.19625),
    bestLapTime = vec2(displaySizes.center.x * 0.29, displaySizes.center.y * 0.2675),
    steerLR = vec2(displaySizes.center.x * 0.12, displaySizes.center.y * 0.488),
    steerLF = vec2(displaySizes.center.x * 0.21, displaySizes.center.y * 0.488),
    steerFR = vec2(displaySizes.center.x * 0.29, displaySizes.center.y * 0.488),
    steerRR = vec2(displaySizes.center.x * 0.38, displaySizes.center.y * 0.488),
}

local rpmBoxes = {
    { vec2(55.51, 48.44), vec2(62.72, 42.10), vec2(71.14, 49.58), vec2(62.66, 55.79) },
    { vec2(64.55, 40.50), vec2(72.80, 35.05), vec2(80.14, 44.02), vec2(72.54, 48.56) },
    { vec2(74.34, 34.03), vec2(82.98, 29.22), vec2(89.78, 39.09), vec2(81.84, 43.15) },
    { vec2(84.30, 28.58), vec2(92.93, 24.42), vec2(100.21, 35.50), vec2(91.31, 38.50) },
    { vec2(94.67, 23.81), vec2(103.34, 20.79), vec2(109.65, 32.79), vec2(101.78, 34.97) },
    { vec2(104.92, 20.23), vec2(113.03, 17.98), vec2(119.33, 30.96), vec2(111.32, 32.47) },
    { vec2(114.80, 17.57), vec2(123.37, 15.63), vec2(128.23, 29.87), vec2(120.94, 30.66) },
    { vec2(125.08, 15.24), vec2(133.28, 14.27), vec2(137.47, 29.35), vec2(129.82, 29.78) },
    { vec2(135.04, 14.06), vec2(143.07, 13.14), vec2(145.79, 29.39), vec2(139.04, 29.27) },
    { vec2(144.83, 13.12), vec2(152.68, 13.03), vec2(154.43, 30.01), vec2(147.34, 29.50) },
    { vec2(154.43, 13.01), vec2(162.50, 13.06), vec2(162.17, 30.81), vec2(155.94, 30.12) },
    { vec2(163.63, 31.08), vec2(164.22, 13.21), vec2(171.67, 13.88), vec2(169.94, 32.28) },
    { vec2(171.36, 32.55), vec2(173.36, 14.03), vec2(179.13, 14.55), vec2(181.23, 14.95), vec2(177.35, 34.00) },
    { vec2(178.72, 34.43), vec2(182.90, 15.27), vec2(190.51, 16.72), vec2(185.18, 36.46) },
    { vec2(186.54, 36.88), vec2(192.21, 17.04), vec2(197.04, 17.97), vec2(199.75, 18.78), vec2(192.41, 38.77) },
    { vec2(193.70, 39.36), vec2(201.41, 19.27), vec2(208.98, 21.52), vec2(199.60, 42.08) },
    { vec2(200.87, 42.67), vec2(210.64, 22.02), vec2(218.58, 24.86), vec2(206.80, 45.40) },
    { vec2(208.12, 46.02), vec2(220.25, 25.55), vec2(227.82, 28.67), vec2(213.41, 49.35) },
    { vec2(214.60, 50.11), vec2(229.49, 29.36), vec2(237.62, 33.58), vec2(219.74, 53.37) },
    { vec2(221.00, 54.17), vec2(239.28, 34.49), vec2(246.77, 38.60), vec2(226.94, 58.84) },
    { vec2(228.01, 59.75), vec2(248.27, 39.64), vec2(256.05, 45.05), vec2(233.02, 64.05) },
    { vec2(234.16, 65.04), vec2(257.68, 46.18), vec2(265.27, 52.36), vec2(238.77, 69.94) },
    { vec2(239.75, 71.08), vec2(266.78, 53.69), vec2(273.99, 60.34), vec2(244.46, 76.58) },
    { vec2(245.45, 77.74), vec2(275.33, 61.85), vec2(282.82, 70.35), vec2(249.28, 83.71) },
    { vec2(250.06, 85.02), vec2(284.11, 72.01), vec2(290.03, 80.87), vec2(254.24, 91.97) },
}

local tempBarColorStops = {
    { t = 0.0, color = colors.tempBarBlue },
    { t = 0.25, color = colors.tempBarGreen },
    { t = 0.5, color = colors.tempBarYellow },
    { t = 0.8, color = colors.tempBarRed },
}

local barRectMin = vec2()
local barRectMax = vec2()
local barColor = rgbm()

local function lerpBarColor(a, b, t)
    barColor.r = a.r + (b.r - a.r) * t
    barColor.g = a.g + (b.g - a.g) * t
    barColor.b = a.b + (b.b - a.b) * t
    barColor.mult = a.mult + (b.mult - a.mult) * t
    return barColor
end

local function tempBarColor(t, stops)
    local color = stops[1].color
    for i = 1, #stops - 1 do
        local current = stops[i]
        local next = stops[i + 1]
        if t >= current.t and t < next.t then
            return lerpBarColor(current.color, next.color, (t - current.t) / (next.t - current.t))
        elseif t >= next.t then
            color = next.color
        end
    end
    return color
end

local function drawTempBars(basePos, temp, barCountMax, tempForMaxBars, barHeight, barWidth, colorStops)
    local nBars = math.floor(math.clamp((temp / tempForMaxBars) * barCountMax + 0.01, 0, barCountMax))
    local spacing = barWidth * 1.0
    local step = barWidth + spacing
    local tScale = 1 / math.max(barCountMax - 1, 1)
    for i = 0, nBars - 1 do
        local barStartX = basePos.x - i * step
        barRectMin:set(barStartX - barWidth, basePos.y)
        barRectMax:set(barStartX, basePos.y + barHeight)
        ui.drawRectFilled(barRectMin, barRectMax, tempBarColor(i * tScale, colorStops))
    end
end

local function drawRpmBoxes()
    local t = (car.rpm / car.rpmLimiter - 0.5) * 2
    local n = math.floor(math.clamp(t * #rpmBoxes + 0.01, 0, #rpmBoxes))
    for i = 1, n do
        ui.pathClear()
        local box = rpmBoxes[i]
        for j = 1, #box do
            ui.pathLineTo(box[j])
        end
        ui.pathFillConvex(colors.red)
    end
end

local function wheelSteerDeg(index)
    local look = car.wheels[index].look
    return math.deg(math.atan2(car.side:dot(look), car.look:dot(look)))
end

local function drawSteerReadouts()
    ui.pushDWriteFont(fontBahnschrift)
    ui.dwriteDrawText(string.format("%+.0f°", wheelSteerDeg(2)), 11, uiItemPos.steerLR, colors.red)
    ui.dwriteDrawText(string.format("%+.0f°", wheelSteerDeg(0)), 11, uiItemPos.steerLF, colors.red)
    ui.dwriteDrawText(string.format("%+.0f°", wheelSteerDeg(1)), 11, uiItemPos.steerFR, colors.red)
    ui.dwriteDrawText(string.format("%+.0f°", wheelSteerDeg(3)), 11, uiItemPos.steerRR, colors.red)
    ui.popDWriteFont()
end

local function drawScreen1(dt)
    ui.drawImage("dynamic::rear_view_0_post", cameraRenderPositions.center.pos, cameraRenderPositions.center.size, ui.ImageFit.Stretch)
    ui.drawImage("Center 1.png", vec2Zero + backgroundInset.center, displaySizes.center - backgroundInset.center, colors.white, ui.ImageFit.Stretch)
    drawRpmBoxes()

    ui.dwriteDrawText(uiState.useImperialUnits and "MPH" or "KPH", 18, uiItemPos.speedUnits, colors.red)
    ui.dwriteDrawText(string.format("%.0f", uiState.useImperialUnits and car.speedKmh * 0.621371 or car.speedKmh), 29, uiItemPos.speedValue, colors.red)
    drawSteerReadouts()
end

local function drawScreen2(dt)
    ui.drawImage("Left 2.png", vec2Zero + backgroundInset.side, displaySizes.side - backgroundInset.side, colors.white, ui.ImageFit.Stretch)
end

local function drawScreen3(dt)
    ui.drawImage("Right 3.png", vec2Zero + backgroundInset.side, displaySizes.side - backgroundInset.side, colors.white, ui.ImageFit.Stretch)

    -- Turbine temp
    local coreTemp = physics.scriptControllerInputs[21]
    local frameTemp = physics.scriptControllerInputs[22]

    ui.dwriteDrawText(string.format("%.0f", coreTemp), 20, uiItemPos.coreTemp, colors.red)
    ui.dwriteDrawText(string.format("%.0f", frameTemp), 20, uiItemPos.frameTemp, colors.red)

    drawTempBars(uiItemPos.coreTempBars, coreTemp, 10, 800, 15, 5, tempBarColorStops)
    drawTempBars(uiItemPos.frameTempBars, frameTemp, 10, 800, 15, 5, tempBarColorStops)

    -- Turbine, engine RPM
    local turbineRPM = physics.scriptControllerInputs[10]
    ui.dwriteDrawText(string.format("%07.0f", turbineRPM), 35, uiItemPos.turbineRPM, colors.red)
    ui.dwriteDrawText(string.format("%07.0f", car.rpm), 35, uiItemPos.engineRPM, colors.red)

    -- Acceleration length
    local accelLength = car.acceleration:length()
    ui.dwriteDrawText(string.format("%04.1f", accelLength), 22, uiItemPos.accelLength, colors.red)

    -- Timing
    ui.pushDWriteFont(fontTime)
    local clock = os.date("*t")
    local currentLapTime = car.lapTimeMs / 1000
    local bestLapTime = car.bestLapTimeMs / 1000

    ui.dwriteDrawText(string.format("%02d:%02d:%02d", clock.hour, clock.min, clock.sec), 18, uiItemPos.realTime, colors.timeRed)
    ui.dwriteDrawText(string.format("%02d:%05.2f", math.floor((currentLapTime % 3600) / 60), currentLapTime % 60), 18, uiItemPos.currentLapTime, colors.timeRed)
    ui.dwriteDrawText(string.format("%02d:%05.2f", math.floor((bestLapTime % 3600) / 60), bestLapTime % 60), 18, uiItemPos.bestLapTime, colors.timeRed)
    ui.popDWriteFont()
end

function display:initialize()
    self.screens = {
        {
            mesh = ac.findMeshes("SteerWheelKnobsNStuff_SUB1"),
            canvas = ui.ExtraCanvas(displaySizes.center, 2),
            drawFn = drawScreen1
        },
        {
            mesh = ac.findMeshes("Mach6Cockpit_SUB6"),
            canvas = ui.ExtraCanvas(displaySizes.side, 2),
            drawFn = drawScreen2
        },
        {
            mesh = ac.findMeshes("Mach6Cockpit_SUB5"),
            canvas = ui.ExtraCanvas(displaySizes.side, 2),
            drawFn = drawScreen3
        },
    }

    for _, screen in ipairs(self.screens) do
        screen.mesh:setMaterialProperty('ksEmissive', rgb(1, 1, 1) * 10)
    end
end

function display:update(dt)
    ui.pushDWriteFont(fontSquare)

    cameraCenter.up.x = math.sin(car.steer / car.steerLock * math.pi)
    cameraCenter.up.y = math.cos(car.steer / car.steerLock * math.pi)
    cameraCenter.look.x = car.localVelocity.x / car.localVelocity:length() * -2 * math.saturate(math.remap(car.speedKmh, 10, 40, 0, 1))

    for _, screen in ipairs(self.screens) do
        screen.canvas:clear(colors.black)
        screen.canvas:update(screen.drawFn)
        screen.mesh:setMaterialTexture('txDiffuse', screen.canvas)
        screen.mesh:setMaterialTexture('txEmissive', screen.canvas)
    end

    ui.popDWriteFont()
end

function display:reset() end

return display