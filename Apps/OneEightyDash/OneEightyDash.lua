-- OneEightyDash CSP Lua App
-- Authored by ohyeah2389

local car = ac.getCar(0)
local sim = ac.getSim()
Font_whiteRabbit = ui.DWriteFont("fonts/whitrabt.ttf")

Config = {
    wheels = {
        width = 300,
        height = 300,
        spacing = 10,
        wheelScaleLateral = 0.5,
        wheelScaleVertical = 0.8,
        wheelCornerRadius = 12,
        middleLateralOffset = 0,
        bottomVerticalOffset = 0.8,
    }
}

SlipAngleArrowColors = {
    {
        color = rgbm(0.7, 0.7, 0.7, 1),
        startAngleDeg = 5
    },
    {
        color = rgbm(0.2, 1, 0.2, 1),
        startAngleDeg = 10
    },
    {
        color = rgbm(1, 0, 0, 1),
        startAngleDeg = 25
    }
}

local function drawWheel(x, y, width, height, steerDeg, slipAngleDeg, wheelContact, wheelSlip)
    steerDeg = steerDeg or 0

    -- Calculate the center point of the wheel for rotation pivot
    local centerX = x + width / 2
    local centerY = y + height / 2

    ui.drawRectFilled(vec2(x, y), vec2(x + width, y + height), rgbm(0.2, 0.2, 0.2, 0.3), 10, ui.CornerFlags.All)

    local wheelWidth = width * Config.wheels.wheelScaleLateral
    local wheelHeight = height * Config.wheels.wheelScaleVertical
    local wheelX = x + (width - wheelWidth) / 2
    local wheelY = y + (height - wheelHeight) / 2

    ui.beginRotation()

    ui.drawRectFilled(vec2(wheelX, wheelY), vec2(wheelX + wheelWidth, wheelY + wheelHeight), rgbm(0.1, 0.1, 0.1, 0.8), Config.wheels.wheelCornerRadius or 5, ui.CornerFlags.All)

    local lineSpacing = wheelWidth * 0.5
    local lineY1 = wheelY
    local lineY2 = wheelY + wheelHeight

    ui.drawLine(vec2(centerX, lineY1), vec2(centerX, lineY2), rgbm(0.4, 0.4, 0.4, 0.5), 1)

    local leftLineX = centerX - (lineSpacing / 2)
    ui.drawLine(vec2(leftLineX, lineY1), vec2(leftLineX, lineY2), rgbm(0.4, 0.4, 0.4, 0.5), 1)

    local rightLineX = centerX + (lineSpacing / 2)
    ui.drawLine(vec2(rightLineX, lineY1), vec2(rightLineX, lineY2), rgbm(0.4, 0.4, 0.4, 0.5), 1)

    -- Draw chevrons
    local chevronHeight = wheelHeight * 0.1
    local chevronColor = rgbm(0.4, 0.4, 0.4, 0.5)

    local chevronCount = Config.wheels.chevronCount or 3
    for i = 1, chevronCount do
        local chevronY = wheelY + wheelHeight * (i / (chevronCount + 1))
        local chevronLeftX = centerX - wheelWidth / 2
        local chevronRightX = centerX + wheelWidth / 2
        local chevronTopY = chevronY - chevronHeight / 2
        local chevronBottomY = chevronY + chevronHeight / 2

        ui.drawLine(vec2(chevronLeftX, chevronTopY), vec2(centerX, chevronBottomY), chevronColor, 1)
        ui.drawLine(vec2(centerX, chevronBottomY), vec2(chevronRightX, chevronTopY), chevronColor, 1)
    end

    -- Draw slip/lock lines
    local slipLineSpacingInner = lineSpacing / 4
    local slipLineSpacingOuter = lineSpacing * 0.75
    local slipLineY1 = wheelY + wheelHeight * 0.7
    local slipLineY2 = wheelY + wheelHeight * 0.3
    local slipLineColor = rgbm(0.8, 0.8, 0.8, 0.8 * wheelSlip)

    local leftInnerSlipLineX = centerX - slipLineSpacingInner
    ui.drawLine(vec2(leftInnerSlipLineX, slipLineY1), vec2(leftInnerSlipLineX, slipLineY2), slipLineColor, 5)

    local rightInnerSlipLineX = centerX + slipLineSpacingInner
    ui.drawLine(vec2(rightInnerSlipLineX, slipLineY1), vec2(rightInnerSlipLineX, slipLineY2), slipLineColor, 5)

    local leftOuterSlipLineX = centerX - slipLineSpacingOuter
    ui.drawLine(vec2(leftOuterSlipLineX, slipLineY1), vec2(leftOuterSlipLineX, slipLineY2), slipLineColor, 5)

    local rightOuterSlipLineX = centerX + slipLineSpacingOuter
    ui.drawLine(vec2(rightOuterSlipLineX, slipLineY1), vec2(rightOuterSlipLineX, slipLineY2), slipLineColor, 5)

    -- Draw slip angle indicator arrow
    local lineLength = wheelHeight / 2
    local lineCenter = vec2(centerX, centerY)
    local angle = math.rad(90) + (slipAngleDeg * math.pi / 180)

    local slipColor = SlipAngleArrowColors[1].color
    local absSlipAngle = math.abs(slipAngleDeg)
    absSlipAngle = absSlipAngle % 180
    if absSlipAngle > 90 then
        absSlipAngle = 180 - absSlipAngle
    end

    -- Find the appropriate color range and interpolate
    for i = 1, #SlipAngleArrowColors - 1 do
        local currentRange = SlipAngleArrowColors[i]
        local nextRange = SlipAngleArrowColors[i + 1]

        if absSlipAngle >= currentRange.startAngleDeg and absSlipAngle < nextRange.startAngleDeg then
            local t = (absSlipAngle - currentRange.startAngleDeg) / (nextRange.startAngleDeg - currentRange.startAngleDeg)
            slipColor = rgbm(
                currentRange.color.r + (nextRange.color.r - currentRange.color.r) * t,
                currentRange.color.g + (nextRange.color.g - currentRange.color.g) * t,
                currentRange.color.b + (nextRange.color.b - currentRange.color.b) * t,
                currentRange.color.mult + (nextRange.color.mult - currentRange.color.mult) * t
            )
            break
        elseif absSlipAngle >= nextRange.startAngleDeg then
            slipColor = nextRange.color
        end
    end

    slipColor.mult = wheelContact

    local arrowTipX = lineCenter.x + math.cos(angle) * lineLength
    local arrowTipY = lineCenter.y + math.sin(angle) * lineLength
    local arrowTip = vec2(arrowTipX, arrowTipY)

    -- Draw arrowhead
    local arrowheadLength = 20
    local arrowheadAngle = math.pi / 10

    local arrowLeft = vec2(
        arrowTip.x + math.cos(angle + math.pi - arrowheadAngle) * arrowheadLength,
        arrowTip.y + math.sin(angle + math.pi - arrowheadAngle) * arrowheadLength
    )

    local arrowRight = vec2(
        arrowTip.x + math.cos(angle + math.pi + arrowheadAngle) * arrowheadLength,
        arrowTip.y + math.sin(angle + math.pi + arrowheadAngle) * arrowheadLength
    )

    ui.drawTriangleFilled(arrowTip, arrowLeft, arrowRight, slipColor)

    -- Draw arrow shaft
    local lineShortening = arrowheadLength - 1
    local lineEndX = lineCenter.x + math.cos(angle) * (lineLength - lineShortening)
    local lineEndY = lineCenter.y + math.sin(angle) * (lineLength - lineShortening)
    local lineEnd = vec2(lineEndX, lineEndY)

    ui.drawLine(lineCenter, lineEnd, slipColor, 2)

    ui.endPivotRotation(steerDeg - 90, vec2(centerX, centerY))
end

local displays = {}

function displays.drawWheels()
    local wheelWidth = (Config.wheels.width - Config.wheels.spacing) / 2
    local wheelHeight = (Config.wheels.height - Config.wheels.spacing) / 2
    local spacing = Config.wheels.spacing

    local wheelLFsteer = math.deg(math.asin(math.dot(car.wheels[0].look, car.side)))
    local wheelRFsteer = math.deg(math.asin(math.dot(car.wheels[1].look, car.side)))
    local wheelLRsteer = math.deg(math.asin(math.dot(car.wheels[2].look, car.side)))
    local wheelRRsteer = math.deg(math.asin(math.dot(car.wheels[3].look, car.side)))

    local wheelLF_reverse = car.wheels[0].angularSpeed < -1
    local wheelRF_reverse = car.wheels[1].angularSpeed < -1
    local wheelLR_reverse = car.wheels[2].angularSpeed < -1
    local wheelRR_reverse = car.wheels[3].angularSpeed < -1

    local wheelLFSlipAngle = (car.wheels[0].slipAngle + (wheelLF_reverse and 180 or 0)) * (wheelLF_reverse and -1 or 1)
    local wheelRFSlipAngle = (car.wheels[1].slipAngle + (wheelRF_reverse and 180 or 0)) * (wheelRF_reverse and -1 or 1)
    local wheelLRSlipAngle = (car.wheels[2].slipAngle + (wheelLR_reverse and 180 or 0)) * (wheelLR_reverse and -1 or 1)
    local wheelRRSlipAngle = (car.wheels[3].slipAngle + (wheelRR_reverse and 180 or 0)) * (wheelRR_reverse and -1 or 1)

    local wheelLF_contact = math.clamp(math.remap(car.wheels[0].load, 0.01, 100, 0, 1), 0, 1)
    local wheelRF_contact = math.clamp(math.remap(car.wheels[1].load, 0.01, 100, 0, 1), 0, 1)
    local wheelLR_contact = math.clamp(math.remap(car.wheels[2].load, 0.01, 100, 0, 1), 0, 1)
    local wheelRR_contact = math.clamp(math.remap(car.wheels[3].load, 0.01, 100, 0, 1), 0, 1)

    local wheelLF_slip = math.smootherstep(math.abs(car.wheels[0].slipRatio))
    local wheelRF_slip = math.smootherstep(math.abs(car.wheels[1].slipRatio))
    local wheelLR_slip = math.smootherstep(math.abs(car.wheels[2].slipRatio))
    local wheelRR_slip = math.smootherstep(math.abs(car.wheels[3].slipRatio))

    -- Front left wheel (top left)
    drawWheel(0, 0, wheelWidth, wheelHeight, wheelLFsteer, wheelLFSlipAngle, wheelLF_contact, wheelLF_slip)

    -- Front right wheel (top right)
    drawWheel(wheelWidth + spacing, 0, wheelWidth, wheelHeight, wheelRFsteer, wheelRFSlipAngle, wheelRF_contact, wheelRF_slip)

    -- Rear left wheel (bottom left)
    drawWheel(0, wheelHeight + spacing, wheelWidth, wheelHeight, wheelLRsteer, wheelLRSlipAngle, wheelLR_contact, wheelLR_slip)

    -- Rear right wheel (bottom right)
    drawWheel(wheelWidth + spacing, wheelHeight + spacing, wheelWidth, wheelHeight, wheelRRsteer, wheelRRSlipAngle, wheelRR_contact, wheelRR_slip)
end

function script.windowMain(dt)
    if not ac.isInReplayMode() then
        -- Calculate base position (centered)
        local baseX = (sim.windowWidth / 2) - (Config.wheels.width / 2)
        local baseY = (sim.windowHeight / 2) - (Config.wheels.height / 2)

        -- Scale offsets by the maximum possible offset to stay on screen
        -- At 1.0/-1.0, the display will be at the edge; at 0.9, it's 90% of the way to the edge
        local lateralOffsetPixels = -Config.wheels.middleLateralOffset * baseX
        local verticalOffsetPixels = Config.wheels.bottomVerticalOffset * baseY

        -- Apply offsets
        local finalX = baseX - lateralOffsetPixels
        local finalY = baseY - verticalOffsetPixels

        ui.transparentWindow("OneEightyDash_Wheels", vec2(finalX, finalY), vec2(Config.wheels.width, Config.wheels.height), true, true, function() displays.drawWheels() end)
    end
end

---@diagnostic disable-next-line: duplicate-set-field
function script.update(dt)
end
