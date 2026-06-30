-- T-180 Cockpit Display Script - Mach 6
-- Authored by ohyeah2389

local uiState = ac.getUI()
local physics = ac.getCarPhysics(car.index) or {}

local display = class("Display")

local vec2Zero = vec2(0, 0)
local fontSquare = ui.DWriteFont("ST-SimpleSquare.ttf")
local fontTime = ui.DWriteFont("EHSMB.ttf")

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

local function drawScreen1(dt)
    ui.drawImage("dynamic::rear_view_0_post", cameraRenderPositions.center.pos, cameraRenderPositions.center.size, ui.ImageFit.Stretch)
    ui.drawImage("Center 1.png", vec2Zero + backgroundInset.center, displaySizes.center - backgroundInset.center, colors.white, ui.ImageFit.Stretch)

    ui.dwriteDrawText(uiState.useImperialUnits and "MPH" or "KPH", 18, uiItemPos.speedUnits, colors.red)
    ui.dwriteDrawText(string.format("%.0f", uiState.useImperialUnits and car.speedKmh * 0.621371 or car.speedKmh), 29, uiItemPos.speedValue, colors.red)
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
            mesh = ac.findMeshes("SteerWheelKnobsNStuff_SUB2"),
            canvas = ui.ExtraCanvas(displaySizes.center, 2),
            drawFn = drawScreen1
        },
        {
            mesh = ac.findMeshes("Cockpit.001_SUB5"),
            canvas = ui.ExtraCanvas(displaySizes.side, 2),
            drawFn = drawScreen2
        },
        {
            mesh = ac.findMeshes("Cockpit.001_SUB4"),
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