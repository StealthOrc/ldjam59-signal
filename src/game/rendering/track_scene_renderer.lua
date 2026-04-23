local roadTypes = require("src.game.data.road_types")

local renderer = {}

local COLOR_OPTIONS = {
    { id = "blue", color = { 0.33, 0.8, 0.98 } },
    { id = "yellow", color = { 0.98, 0.82, 0.34 } },
    { id = "mint", color = { 0.4, 0.92, 0.76 } },
    { id = "rose", color = { 0.98, 0.48, 0.62 } },
    { id = "orange", color = { 0.98, 0.7, 0.28 } },
    { id = "violet", color = { 0.82, 0.56, 0.98 } },
}

local RELAY_FLASH_DURATION = 0.28
local TRIP_FLASH_DURATION = 0.28
local CROSSBAR_FLASH_DURATION = 0.28
local SPRING_RELEASE_DURATION = 0.42
local ROAD_PATTERN_OUTLINE = { 0.04, 0.05, 0.07, 0.98 }
local ROAD_PATTERN_FILL = { 0.97, 0.98, 1.0, 0.94 }
local TRACK_STRIPE_LENGTH = 14
local OUTPUT_SELECTOR_RADIUS = 15
local TRACK_LINE_JOIN = "bevel"

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function copyColor(color)
    if not color then
        return { 0.8, 0.8, 0.8 }
    end

    return { color[1], color[2], color[3] }
end

local function hasOutputSelector(junction)
    return junction
        and renderer.getDistinctOutputCount(junction) > 1
        and junction.control
        and junction.control.type ~= "relay"
        and junction.control.type ~= "crossbar"
end

local function serializeTrackPointList(points)
    local parts = {}
    for _, point in ipairs(points or {}) do
        parts[#parts + 1] = string.format("%.3f,%.3f", point.x or 0, point.y or 0)
    end
    return table.concat(parts, ";")
end

local function getColorById(colorId)
    for _, option in ipairs(COLOR_OPTIONS) do
        if option.id == colorId then
            return copyColor(option.color)
        end
    end
    return copyColor(COLOR_OPTIONS[1].color)
end

local function buildTrackStripeColors(colorIds, isActive)
    if #(colorIds or {}) <= 1 then
        return nil
    end

    local brightness = isActive and 1 or 0.58
    local colors = {}
    for _, colorId in ipairs(colorIds or {}) do
        local color = getColorById(colorId)
        colors[#colors + 1] = {
            color[1] * brightness,
            color[2] * brightness,
            color[3] * brightness,
        }
    end

    return colors
end

local function flattenPoints(points)
    local flattened = {}
    for _, point in ipairs(points or {}) do
        flattened[#flattened + 1] = point.x
        flattened[#flattened + 1] = point.y
    end
    return flattened
end

local function pointOnCircle(centerX, centerY, angle, radius)
    return {
        x = centerX + math.cos(angle) * radius,
        y = centerY + math.sin(angle) * radius,
    }
end

local function buildCubicCurvePoints(startPoint, controlPointA, controlPointB, endPoint, stepCount)
    local points = {}

    for stepIndex = 0, stepCount do
        local t = stepIndex / stepCount
        local oneMinusT = 1 - t
        local x = oneMinusT ^ 3 * startPoint.x
            + 3 * oneMinusT ^ 2 * t * controlPointA.x
            + 3 * oneMinusT * t ^ 2 * controlPointB.x
            + t ^ 3 * endPoint.x
        local y = oneMinusT ^ 3 * startPoint.y
            + 3 * oneMinusT ^ 2 * t * controlPointA.y
            + 3 * oneMinusT * t ^ 2 * controlPointB.y
            + t ^ 3 * endPoint.y

        points[#points + 1] = { x = x, y = y }
    end

    return points
end

local function getTimerRatio(armed, remaining, duration)
    if duration <= 0 then
        return armed and 1 or 0
    end

    if not armed then
        return 0
    end

    return clamp(remaining / duration, 0, 1)
end

local function drawStripedSector(graphics, centerX, centerY, radius, startAngle, endAngle, colors, alpha)
    local palette = colors or {}
    if #palette == 0 or endAngle <= startAngle then
        return
    end

    local totalAngle = endAngle - startAngle
    local segmentAngle = totalAngle / #palette

    for index, stripeColor in ipairs(palette) do
        local segmentStart = startAngle + segmentAngle * (index - 1)
        local segmentEnd = startAngle + segmentAngle * index
        graphics.setColor(stripeColor[1], stripeColor[2], stripeColor[3], alpha)
        graphics.arc("fill", centerX, centerY, radius, segmentStart, segmentEnd)
    end
end

local function drawStripedCircleOutline(graphics, centerX, centerY, radius, colors, alpha, lineWidth)
    local palette = colors or {}
    if #palette == 0 then
        return
    end

    local segmentAngle = (math.pi * 2) / #palette
    graphics.setLineWidth(lineWidth or 3)
    for index, stripeColor in ipairs(palette) do
        local segmentStart = -math.pi * 0.5 + segmentAngle * (index - 1)
        local segmentEnd = -math.pi * 0.5 + segmentAngle * index
        graphics.setColor(stripeColor[1], stripeColor[2], stripeColor[3], alpha)
        graphics.arc("line", centerX, centerY, radius, segmentStart, segmentEnd)
    end
end

local function getJunctionInputStyle(junction, inputIndex)
    local resolvedInputIndex = clamp(inputIndex or junction.activeInputIndex or 1, 1, math.max(1, #junction.inputs))
    local inputTrack = junction.inputs[resolvedInputIndex]
    if not inputTrack then
        return { 0.4, 0.4, 0.4 }, nil
    end

    return inputTrack.color or { 0.4, 0.4, 0.4 }, buildTrackStripeColors(inputTrack.colors, true)
end

local function drawJunctionTimerPie(graphics, centerX, centerY, radius, primaryColor, stripeColors, ratio, drawOutline, drawBackground)
    local fillRatio = clamp(ratio or 0, 0, 1)
    local fillAlpha = 1
    local outlineRadius = radius - 0.5

    if drawBackground == true then
        graphics.setColor(primaryColor[1], primaryColor[2], primaryColor[3], 0.12)
        graphics.circle("fill", centerX, centerY, radius)
    end

    if fillRatio >= 0.999 then
        if stripeColors then
            drawStripedSector(graphics, centerX, centerY, radius, -math.pi * 0.5, math.pi * 1.5, stripeColors, fillAlpha)
        else
            graphics.setColor(primaryColor[1], primaryColor[2], primaryColor[3], fillAlpha)
            graphics.circle("fill", centerX, centerY, radius)
        end
    elseif fillRatio > 0.001 then
        local endAngle = -math.pi * 0.5 + math.pi * 2 * fillRatio
        if stripeColors then
            drawStripedSector(graphics, centerX, centerY, radius, -math.pi * 0.5, endAngle, stripeColors, fillAlpha)
        else
            graphics.setColor(primaryColor[1], primaryColor[2], primaryColor[3], fillAlpha)
            graphics.arc("fill", centerX, centerY, radius, -math.pi * 0.5, endAngle)
        end
    end

    if drawOutline == false then
        return
    end

    if stripeColors then
        drawStripedCircleOutline(graphics, centerX, centerY, outlineRadius, stripeColors, 0.96, 3)
    else
        graphics.setColor(primaryColor[1], primaryColor[2], primaryColor[3], 0.92)
        graphics.setLineWidth(3)
        graphics.circle("line", centerX, centerY, outlineRadius)
    end
end

local function drawHourglassIcon(graphics, centerX, centerY, size, progress, color)
    local clampedProgress = clamp(progress or 0, 0, 1)
    local halfWidth = size * 0.48
    local halfHeight = size * 0.64
    local neckWidth = size * 0.12
    local inset = size * 0.13
    local sourceFill = 1 - clampedProgress
    local targetFill = clampedProgress
    local angle = math.pi * clampedProgress
    local sinAngle = math.sin(angle)
    local cosAngle = math.cos(angle)
    local streamAlpha = math.sin(clampedProgress * math.pi)
    local chamberOffset = halfHeight * 0.42

    local function rotateLocal(x, y)
        return centerX + x * cosAngle - y * sinAngle, centerY + x * sinAngle + y * cosAngle
    end

    local chamberAX, chamberAY = rotateLocal(0, -chamberOffset)
    local chamberBX, chamberBY = rotateLocal(0, chamberOffset)
    local sourceCenterX, sourceCenterY = chamberBX, chamberBY
    local targetCenterX, targetCenterY = chamberAX, chamberAY
    local sourceBaseY = sourceCenterY + size * 0.18
    local targetBaseY = targetCenterY + size * 0.18
    local sourceWidth = size * (0.08 + sourceFill * 0.18)
    local targetWidth = size * (0.08 + targetFill * 0.18)
    local sourceTipY = sourceBaseY - size * (0.04 + sourceFill * 0.18)
    local targetTipY = targetBaseY - size * (0.04 + targetFill * 0.18)
    local middleY = centerY + size * 0.1
    local middleWidth = size * (0.03 + streamAlpha * 0.07)
    local middleTipY = middleY - size * (0.04 + streamAlpha * 0.08)

    graphics.stencil(function()
        graphics.push()
        graphics.translate(centerX, centerY)
        graphics.rotate(angle)
        graphics.polygon("fill", -halfWidth + inset, -halfHeight + inset, halfWidth - inset, -halfHeight + inset, 0, -size * 0.06)
        graphics.polygon("fill", -halfWidth + inset, halfHeight - inset, halfWidth - inset, halfHeight - inset, 0, size * 0.06)
        graphics.pop()
    end, "replace", 1)

    graphics.setStencilTest("greater", 0)

    if sourceFill > 0.02 then
        graphics.setColor(color[1], color[2], color[3], 0.94)
        graphics.polygon("fill", sourceCenterX - sourceWidth, sourceBaseY, sourceCenterX + sourceWidth, sourceBaseY, sourceCenterX, sourceTipY)
    end

    if targetFill > 0.02 then
        graphics.setColor(color[1], color[2], color[3], 0.94)
        graphics.polygon("fill", targetCenterX - targetWidth, targetBaseY, targetCenterX + targetWidth, targetBaseY, targetCenterX, targetTipY)
    end

    if streamAlpha > 0.04 then
        graphics.setColor(color[1], color[2], color[3], 0.82 * streamAlpha)
        graphics.polygon("fill", centerX - middleWidth, middleY, centerX + middleWidth, middleY, centerX, middleTipY)

        graphics.setLineWidth(2)
        graphics.setColor(color[1], color[2], color[3], 0.88 * streamAlpha)
        graphics.line(centerX, centerY - size * 0.08, centerX, middleTipY)
    end

    graphics.setStencilTest()

    graphics.push()
    graphics.translate(centerX, centerY)
    graphics.rotate(angle)
    graphics.setLineWidth(2.4)
    graphics.setColor(0.05, 0.06, 0.08, 0.96)
    graphics.line(-halfWidth, -halfHeight, halfWidth, -halfHeight)
    graphics.line(-halfWidth, halfHeight, halfWidth, halfHeight)
    graphics.line(-halfWidth, -halfHeight, -neckWidth, 0, -halfWidth, halfHeight)
    graphics.line(halfWidth, -halfHeight, neckWidth, 0, halfWidth, halfHeight)
    graphics.pop()
end

local function drawSpringIcon(graphics, springImage, centerX, centerY, size, compression, releaseProgress, color)
    local clampedCompression = clamp(compression or 0, 0, 1)
    if springImage then
        local imageWidth, imageHeight = springImage:getDimensions()
        local baseScale = math.min((size * 1.18) / imageWidth, (size * 2) / imageHeight)
        local animatedCompression = clampedCompression
        local yOffset = size * 0.14 * animatedCompression

        if releaseProgress and releaseProgress > 0 then
            local t = clamp(releaseProgress, 0, 1)
            local relax = 1 - (1 - t) ^ 3
            local rebound = math.sin(t * math.pi) * math.exp(-2.2 * t)
            animatedCompression = math.max(0, 1 - relax - 0.16 * rebound)
            yOffset = size * 0.14 * animatedCompression - size * 0.2 * rebound
        end

        local scaleX = baseScale * (1 + 0.08 * animatedCompression)
        local scaleY = baseScale * (1 - 0.3 * animatedCompression)

        graphics.setColor(1, 1, 1, 1)
        graphics.draw(springImage, centerX, centerY + yOffset, 0, scaleX, scaleY, imageWidth * 0.5, imageHeight * 0.5)
        return
    end

    local fullHeight = size * 1.12
    local compressedHeight = size * 0.64
    local coilHeight = fullHeight + (compressedHeight - fullHeight) * clampedCompression
    local coilWidth = size * 0.48
    local turnCount = 4.35
    local sampleCount = 88
    local hookLength = size * 0.16
    local points = {}

    if releaseProgress and releaseProgress > 0 then
        local damped = math.cos(releaseProgress * math.pi * 4.2) * math.exp(-4.1 * releaseProgress)
        coilHeight = fullHeight - (fullHeight - compressedHeight) * damped
    end

    coilHeight = clamp(coilHeight, size * 0.34, size * 1.28)

    for index = 0, sampleCount do
        local ratio = index / sampleCount
        local angle = ratio * math.pi * 2 * turnCount
        local x = math.sin(angle) * coilWidth
        local y = (-coilHeight * 0.5) + (coilHeight * ratio)
        points[#points + 1] = x
        points[#points + 1] = y
    end

    local topX = points[1]
    local topY = points[2]
    local bottomX = points[#points - 1]
    local bottomY = points[#points]

    graphics.push()
    graphics.translate(centerX, centerY)
    graphics.setLineWidth(3.1)
    graphics.setColor(color[1], color[2], color[3], 1)
    graphics.line(topX + hookLength * 0.35, topY - hookLength, topX, topY)
    graphics.line(points)
    graphics.line(bottomX, bottomY, bottomX + hookLength * 0.4, bottomY + hookLength)
    graphics.pop()
end

local function drawRelayIcon(graphics, relayImage, centerX, centerY, size, flashAlpha)
    if relayImage then
        local imageWidth, imageHeight = relayImage:getDimensions()
        local baseScale = math.min((size * 1.45) / imageWidth, (size * 1.45) / imageHeight)
        local pulseScale = 1 + flashAlpha * 0.06
        graphics.setColor(1, 1, 1, 0.96)
        graphics.draw(relayImage, centerX, centerY, 0, baseScale * pulseScale, baseScale * pulseScale, imageWidth * 0.5, imageHeight * 0.5)
        return
    end

    graphics.setColor(0.05, 0.06, 0.08, 1)
    graphics.printf("R", centerX - size * 0.4, centerY - size * 0.24, size * 0.8, "center")
end

local function drawStaticJunctionIcon(graphics, image, centerX, centerY, size, scaleMultiplier, alpha)
    if not image then
        return false
    end

    local imageWidth, imageHeight = image:getDimensions()
    local scale = math.min((size * scaleMultiplier) / imageWidth, (size * scaleMultiplier) / imageHeight)
    graphics.setColor(1, 1, 1, alpha or 1)
    graphics.draw(image, centerX, centerY, 0, scale, scale, imageWidth * 0.5, imageHeight * 0.5)
    return true
end

local function withIconScale(graphics, centerX, centerY, iconScale, drawFn)
    graphics.push()
    graphics.translate(centerX, centerY)
    graphics.scale(iconScale, iconScale)
    graphics.translate(-centerX, -centerY)
    drawFn()
    graphics.pop()
end

local function getControlBubbleLayout(junction)
    return junction.mergePoint.x, junction.mergePoint.y, junction.crossingRadius
end

local function drawJunctionCircle(graphics, junction, primaryColor, stripeColors)
    local centerX, centerY, radius = getControlBubbleLayout(junction)
    local backgroundAlpha = 0.28

    graphics.setColor(0.05, 0.06, 0.08, 0.9)
    graphics.circle("fill", centerX, centerY, radius)

    if stripeColors then
        drawStripedSector(graphics, centerX, centerY, radius, -math.pi * 0.5, math.pi * 1.5, stripeColors, backgroundAlpha)
        drawStripedCircleOutline(graphics, centerX, centerY, radius, stripeColors, 0.92, 3)
    else
        graphics.setColor(primaryColor[1], primaryColor[2], primaryColor[3], backgroundAlpha)
        graphics.circle("fill", centerX, centerY, radius)
        graphics.setColor(primaryColor[1], primaryColor[2], primaryColor[3], 0.88)
        graphics.setLineWidth(3)
        graphics.circle("line", centerX, centerY, radius)
    end

    return centerX, centerY, radius
end

local function getControlIconScale(control)
    local press = clamp(control and control.iconPress or 0, -0.4, 1.2)
    return 1 - press * 0.25
end

local function getSelectorIconScale(junction)
    local press = clamp(junction and junction.selectorPress or 0, -0.4, 1.2)
    return 1 - press * 0.25
end

function renderer.getControlBubbleLayout(junction)
    return getControlBubbleLayout(junction)
end

function renderer.getDistinctOutputCount(junction)
    local distinctCount = 0
    local seenSignatures = {}

    for _, outputTrack in ipairs(junction and junction.outputs or {}) do
        local signature = serializeTrackPointList(outputTrack and outputTrack.path and outputTrack.path.points or {})
        if signature ~= "" and not seenSignatures[signature] then
            seenSignatures[signature] = true
            distinctCount = distinctCount + 1
        end
    end

    return distinctCount
end

function renderer.getOutputSelectorLayout(junction)
    if not hasOutputSelector(junction) then
        return nil
    end

    local bubbleX, bubbleY, bubbleRadius = getControlBubbleLayout(junction)
    return bubbleX, bubbleY + bubbleRadius, OUTPUT_SELECTOR_RADIUS
end

function renderer.drawTrackPatternSegment(_, startX, startY, endX, endY, alpha, outlineWidth, fillWidth)
    local graphics = love.graphics
    graphics.setColor(ROAD_PATTERN_OUTLINE[1], ROAD_PATTERN_OUTLINE[2], ROAD_PATTERN_OUTLINE[3], alpha)
    graphics.setLineWidth(outlineWidth)
    graphics.line(startX, startY, endX, endY)
    graphics.setColor(ROAD_PATTERN_FILL[1], ROAD_PATTERN_FILL[2], ROAD_PATTERN_FILL[3], alpha)
    graphics.setLineWidth(fillWidth)
    graphics.line(startX, startY, endX, endY)
end

function renderer.drawTrackRoadTypeMarkers(scene, track, isActive)
    local startDistance, endDistance = scene:getRenderedTrackWindow(track)
    local alpha = isActive and 0.95 or 0.78

    for _, section in ipairs(track.styleSections or {}) do
        local roadTypeConfig = roadTypes.getConfig(section.roadType)
        if roadTypeConfig.pattern ~= "plain" then
            local sectionStartDistance = math.max(startDistance, section.startDistance)
            local sectionEndDistance = math.min(endDistance, section.endDistance)
            local markerDistance = sectionStartDistance + roadTypeConfig.markerSpacing * 0.5
            local markerSize = roadTypeConfig.markerSize
            local outlineWidth = roadTypeConfig.markerWidth + 2
            local fillWidth = roadTypeConfig.markerWidth

            while markerDistance < sectionEndDistance do
                local markerX, markerY, angle = scene:pointOnPath(track.path, markerDistance)
                local directionX = math.cos(angle)
                local directionY = math.sin(angle)
                local normalX = -directionY
                local normalY = directionX

                if roadTypeConfig.pattern == "chevron" then
                    local tipX = markerX + directionX * markerSize
                    local tipY = markerY + directionY * markerSize
                    local leftX = markerX - normalX * markerSize * 0.7
                    local leftY = markerY - normalY * markerSize * 0.7
                    local rightX = markerX + normalX * markerSize * 0.7
                    local rightY = markerY + normalY * markerSize * 0.7
                    renderer.drawTrackPatternSegment(scene, leftX, leftY, tipX, tipY, alpha, outlineWidth, fillWidth)
                    renderer.drawTrackPatternSegment(scene, rightX, rightY, tipX, tipY, alpha, outlineWidth, fillWidth)
                elseif roadTypeConfig.pattern == "crossbar" then
                    local startX = markerX - normalX * markerSize
                    local startY = markerY - normalY * markerSize
                    local endX = markerX + normalX * markerSize
                    local endY = markerY + normalY * markerSize
                    renderer.drawTrackPatternSegment(scene, startX, startY, endX, endY, alpha, outlineWidth, fillWidth)
                end

                markerDistance = markerDistance + roadTypeConfig.markerSpacing
            end
        end
    end
end

function renderer.drawTrackLine(_, points, width, color, alpha)
    local graphics = love.graphics
    graphics.setColor(color[1], color[2], color[3], alpha or 1)
    graphics.setLineWidth(width)
    graphics.line(points)
end

function renderer.drawStripedTrack(_, points, width, stripeColors, alpha)
    local graphics = love.graphics
    local stripeIndex = 1

    graphics.setLineWidth(width)
    for pointIndex = 1, #points - 3, 2 do
        local ax = points[pointIndex]
        local ay = points[pointIndex + 1]
        local bx = points[pointIndex + 2]
        local by = points[pointIndex + 3]
        local dx = bx - ax
        local dy = by - ay
        local length = math.sqrt(dx * dx + dy * dy)

        if length > 0.0001 then
            local unitX = dx / length
            local unitY = dy / length
            local stripeLength = math.max(8, TRACK_STRIPE_LENGTH - #stripeColors)

            for offset = 0, math.ceil(length / stripeLength) - 1 do
                local startDistance = offset * stripeLength
                local endDistance = math.min(length, startDistance + stripeLength)
                local color = stripeColors[stripeIndex]
                graphics.setColor(color[1], color[2], color[3], alpha or 1)
                graphics.line(
                    ax + unitX * startDistance,
                    ay + unitY * startDistance,
                    ax + unitX * endDistance,
                    ay + unitY * endDistance
                )
                stripeIndex = stripeIndex + 1
                if stripeIndex > #stripeColors then
                    stripeIndex = 1
                end
            end
        end
    end
end

function renderer.drawInputTrack(scene, track, isActive)
    local graphics = love.graphics
    local trackColor = isActive and track.color or track.darkColor
    local trackAlpha = isActive and 0.96 or 0.72
    local stripeColors = buildTrackStripeColors(track.colors, isActive)
    local renderedPoints = scene:getRenderedTrackPoints(track)
    if #renderedPoints < 2 then
        return
    end

    local points = flattenPoints(renderedPoints)

    graphics.setLineStyle("rough")
    graphics.setLineJoin(TRACK_LINE_JOIN)
    graphics.setColor(0.17, 0.21, 0.24, 0.95)
    graphics.setLineWidth(scene.trackWidth + 10)
    graphics.line(points)

    if stripeColors then
        renderer.drawStripedTrack(scene, points, scene.trackWidth, stripeColors, trackAlpha)
    else
        renderer.drawTrackLine(scene, points, scene.trackWidth, trackColor, trackAlpha)
    end

    renderer.drawTrackRoadTypeMarkers(scene, track, isActive)
end

function renderer.drawStandaloneTrack(scene, track, isActive)
    local graphics = love.graphics
    local trackColor = isActive and track.color or track.darkColor
    local trackAlpha = isActive and 0.96 or 0.72
    local stripeColors = nil

    if not track.adoptInputColor then
        stripeColors = buildTrackStripeColors(track.colors, isActive)
    end

    local renderedPoints = scene:getRenderedTrackPoints(track)
    if #renderedPoints < 2 then
        return
    end

    local points = flattenPoints(renderedPoints)

    graphics.setLineStyle("rough")
    graphics.setLineJoin(TRACK_LINE_JOIN)
    graphics.setColor(0.17, 0.21, 0.24, 0.95)
    graphics.setLineWidth(scene.trackWidth + 10)
    graphics.line(points)

    if stripeColors then
        renderer.drawStripedTrack(scene, points, scene.trackWidth, stripeColors, trackAlpha)
    else
        renderer.drawTrackLine(scene, points, scene.trackWidth, trackColor, trackAlpha)
    end

    renderer.drawTrackRoadTypeMarkers(scene, track, isActive)
end

function renderer.drawOutputTrack(scene, junction, outputIndex, isActive)
    local graphics = love.graphics
    local outputTrack = junction.outputs[outputIndex]
    local color = scene:getOutputDisplayColor(junction, outputIndex, isActive)
    local stripeColors = outputTrack and not outputTrack.adoptInputColor and buildTrackStripeColors(outputTrack.colors, isActive) or nil
    local renderedPoints = scene:getRenderedTrackPoints(outputTrack)
    if #renderedPoints < 2 then
        return
    end

    local points = flattenPoints(renderedPoints)

    graphics.setLineStyle("rough")
    graphics.setLineJoin(TRACK_LINE_JOIN)
    graphics.setColor(0.17, 0.21, 0.24, 0.95)
    graphics.setLineWidth(scene.sharedWidth + 10)
    graphics.line(points)

    if stripeColors then
        renderer.drawStripedTrack(scene, points, scene.sharedWidth, stripeColors, isActive and 0.98 or 0.7)
    else
        renderer.drawTrackLine(scene, points, scene.sharedWidth, color, isActive and 0.98 or 0.7)
    end

    renderer.drawTrackRoadTypeMarkers(scene, outputTrack, isActive)
end

function renderer.drawControlOverlay(scene, junction)
    local graphics = love.graphics
    local control = junction.control
    local inputColor, inputStripeColors = getJunctionInputStyle(junction)
    local iconScale = getControlIconScale(control)

    if control.type == "direct" then
        local centerX, centerY, innerRadius = drawJunctionCircle(graphics, junction, inputColor, inputStripeColors)
        withIconScale(graphics, centerX, centerY, iconScale, function()
            if not drawStaticJunctionIcon(graphics, scene.directImage, centerX, centerY, innerRadius, 1.42, 0.98) then
                local activeInput = junction.inputs[junction.activeInputIndex]
                graphics.setLineWidth(6)
                graphics.setColor(0.05, 0.06, 0.08, 0.98)
                graphics.line(centerX - innerRadius * 0.34, centerY + innerRadius * 0.2, centerX + innerRadius * 0.02, centerY - innerRadius * 0.12)
                graphics.circle("fill", centerX + innerRadius * 0.18, centerY - innerRadius * 0.28, innerRadius * 0.15)
                if activeInput and #activeInput.path.points >= 2 then
                    local angle = scene:getInputTrackAngle(activeInput) - math.pi * 0.5
                    graphics.push()
                    graphics.translate(centerX, centerY)
                    graphics.rotate(angle)
                    graphics.setLineWidth(4)
                    graphics.setColor(0.05, 0.06, 0.08, 0.9)
                    graphics.line(0, -innerRadius * 0.48, 0, -innerRadius * 0.2)
                    graphics.pop()
                end
            end
        end)
        return
    end

    if control.type == "delayed" then
        local centerX, centerY, innerRadius = drawJunctionCircle(graphics, junction, inputColor, inputStripeColors)
        local ratio = 1
        local progress = 0
        if control.armed and control.delay > 0 then
            ratio = clamp(control.remainingDelay / control.delay, 0, 1)
            progress = 1 - ratio
        elseif control.armed then
            ratio = 0
            progress = 1
        end
        drawJunctionTimerPie(graphics, centerX, centerY, innerRadius, inputColor, inputStripeColors, ratio)
        withIconScale(graphics, centerX, centerY, iconScale, function()
            drawHourglassIcon(graphics, centerX, centerY, innerRadius * 0.84, progress, { 0.05, 0.06, 0.08 })
        end)
        return
    end

    if control.type == "pump" then
        local centerX, centerY, innerRadius = drawJunctionCircle(graphics, junction, inputColor, inputStripeColors)
        local previewInputIndex = junction.activeInputIndex + 1
        if previewInputIndex > #junction.inputs then
            previewInputIndex = 1
        end
        local previewColor, previewStripeColors = getJunctionInputStyle(junction, previewInputIndex)
        local ratio = control.target > 0 and (control.pumpCount / control.target) or 0
        drawJunctionTimerPie(graphics, centerX, centerY, innerRadius, previewColor, previewStripeColors, ratio, false, false)
        withIconScale(graphics, centerX, centerY, iconScale, function()
            if not drawStaticJunctionIcon(graphics, scene.chargeImage, centerX, centerY, innerRadius, 1.34, 0.98) then
                graphics.setColor(0.05, 0.06, 0.08, 1)
                graphics.printf(string.format("%d%%", math.floor(ratio * 100 + 0.5)), centerX - 24, centerY - 9, 48, "center")
            end
        end)
        return
    end

    if control.type == "spring" then
        local centerX, centerY, innerRadius = drawJunctionCircle(graphics, junction, inputColor, inputStripeColors)
        local ratio = getTimerRatio(control.armed, control.remainingHold, control.holdTime)
        local compression = 0
        local releaseProgress = nil
        if control.armed then
            compression = 1 - ratio
        elseif control.releaseTimer > 0 then
            compression = 1
            releaseProgress = 1 - (control.releaseTimer / SPRING_RELEASE_DURATION)
        end
        drawJunctionTimerPie(graphics, centerX, centerY, innerRadius, inputColor, inputStripeColors, ratio)
        withIconScale(graphics, centerX, centerY, iconScale, function()
            drawSpringIcon(graphics, scene.springImage, centerX, centerY, innerRadius * 0.8, compression, releaseProgress, { 0.4, 0.96, 0.74 })
        end)
        return
    end

    if control.type == "relay" then
        local centerX, centerY, innerRadius = drawJunctionCircle(graphics, junction, inputColor, inputStripeColors)
        local flashAlpha = control.flashTimer > 0 and (control.flashTimer / RELAY_FLASH_DURATION) or 0
        graphics.setColor(inputColor[1], inputColor[2], inputColor[3], 0.14 + flashAlpha * 0.14)
        graphics.circle("fill", centerX, centerY, innerRadius)
        withIconScale(graphics, centerX, centerY, iconScale, function()
            drawRelayIcon(graphics, scene.relayImage, centerX, centerY, innerRadius * 0.84, flashAlpha)
        end)
        return
    end

    if control.type == "trip" then
        local centerX, centerY, innerRadius = drawJunctionCircle(graphics, junction, inputColor, inputStripeColors)
        local flashAlpha = control.flashTimer > 0 and (control.flashTimer / TRIP_FLASH_DURATION) or 0
        graphics.setColor(inputColor[1], inputColor[2], inputColor[3], 0.14 + flashAlpha * 0.14)
        graphics.circle("fill", centerX, centerY, innerRadius)
        withIconScale(graphics, centerX, centerY, iconScale, function()
            if not drawStaticJunctionIcon(graphics, scene.tripImage, centerX, centerY, innerRadius, 1.4, 0.98) then
                graphics.setColor(0.05, 0.06, 0.08, 1)
                graphics.printf(control.remainingTrips > 0 and tostring(control.remainingTrips) or "T", centerX - 18, centerY - 9, 36, "center")
            end
        end)
        return
    end

    if control.type == "crossbar" then
        local centerX, centerY, innerRadius = drawJunctionCircle(graphics, junction, inputColor, inputStripeColors)
        local flashAlpha = control.flashTimer > 0 and (control.flashTimer / CROSSBAR_FLASH_DURATION) or 0
        graphics.setColor(inputColor[1], inputColor[2], inputColor[3], 0.14 + flashAlpha * 0.14)
        graphics.circle("fill", centerX, centerY, innerRadius)
        withIconScale(graphics, centerX, centerY, iconScale, function()
            if not drawStaticJunctionIcon(graphics, scene.crossImage, centerX, centerY, innerRadius, 1.42, 0.98) then
                graphics.setLineWidth(4)
                graphics.setColor(0.05, 0.06, 0.08, 0.96)
                graphics.arc("line", centerX, centerY, innerRadius - 2, math.pi * 0.15, math.pi * 0.85)
                graphics.arc("line", centerX, centerY, innerRadius - 2, math.pi * 1.15, math.pi * 1.85)
                graphics.setColor(0.05, 0.06, 0.08, 1)
                graphics.printf(string.format("%d:%d", junction.activeInputIndex, junction.activeOutputIndex), centerX - 28, centerY - 9, 56, "center")
            end
        end)
    end
end

function renderer.drawActiveRouteIndicator(scene, junction, activeInput, activeOutputColor)
    local graphics = love.graphics
    local activeOutput = junction.outputs[junction.activeOutputIndex]
    if not activeInput or not activeOutput then
        return
    end

    local coverPadding = 4
    local routeInset = 2
    local coverRadius = junction.crossingRadius + coverPadding
    local routeRadius = coverRadius - routeInset
    local routeOutlineWidth = scene.trackWidth + 8
    local routeInnerWidth = scene.trackWidth
    local curveControlDistance = routeRadius * 0.58
    local curveStepCount = 12
    local x = junction.mergePoint.x
    local y = junction.mergePoint.y
    local inputAngle = scene:getInputTrackAngle(activeInput)
    local outputAngle = scene:getOutputTrackAngle(activeOutput)
    local inputPoint = pointOnCircle(x, y, inputAngle + math.pi, routeRadius)
    local outputPoint = pointOnCircle(x, y, outputAngle, routeRadius)
    local controlPointA = pointOnCircle(inputPoint.x, inputPoint.y, inputAngle, curveControlDistance)
    local controlPointB = pointOnCircle(outputPoint.x, outputPoint.y, outputAngle + math.pi, curveControlDistance)
    local curvePoints = flattenPoints(buildCubicCurvePoints(
        inputPoint,
        controlPointA,
        controlPointB,
        outputPoint,
        curveStepCount
    ))

    graphics.setColor(0.04, 0.05, 0.07, 0.98)
    graphics.circle("fill", x, y, coverRadius)

    graphics.setLineStyle("rough")
    graphics.setLineJoin(TRACK_LINE_JOIN)
    graphics.setLineWidth(routeOutlineWidth)
    graphics.setColor(0.12, 0.15, 0.18, 1)
    graphics.line(curvePoints)

    graphics.setLineWidth(routeInnerWidth)
    graphics.setColor(activeOutputColor[1], activeOutputColor[2], activeOutputColor[3], 1)
    graphics.line(curvePoints)
end

function renderer.drawCrossing(scene, junction)
    local graphics = love.graphics
    local activeInput = junction.inputs[junction.activeInputIndex]
    local activeOutputColor = scene:getOutputDisplayColor(junction, junction.activeOutputIndex, true)
    local activeInputColor = activeInput and activeInput.color or activeOutputColor
    local x = junction.mergePoint.x
    local y = junction.mergePoint.y
    local inputStripeColors = activeInput and buildTrackStripeColors(activeInput.colors, true) or nil

    graphics.setColor(0.05, 0.06, 0.08, 1)
    graphics.circle("fill", x, y, junction.crossingRadius)

    if inputStripeColors then
        drawStripedSector(graphics, x, y, junction.crossingRadius + 4, -math.pi * 0.5, math.pi * 1.5, inputStripeColors, 0.12)
    else
        graphics.setColor(activeInputColor[1], activeInputColor[2], activeInputColor[3], 0.12)
        graphics.circle("fill", x, y, junction.crossingRadius + 4)
    end

    renderer.drawControlOverlay(scene, junction)
end

function renderer.drawOutputSelector(scene, junction)
    local graphics = love.graphics
    local activeOutputColor = scene:getOutputDisplayColor(junction, junction.activeOutputIndex, true)
    local selectorX, selectorY, selectorRadius = renderer.getOutputSelectorLayout(junction)
    if selectorX then
        local selectorScale = getSelectorIconScale(junction)
        withIconScale(graphics, selectorX, selectorY, selectorScale, function()
            graphics.setColor(activeOutputColor[1], activeOutputColor[2], activeOutputColor[3], 1)
            graphics.circle("fill", selectorX, selectorY, selectorRadius)
            graphics.setLineWidth(3)
            graphics.setColor(0.05, 0.06, 0.08, 1)
            graphics.circle("line", selectorX, selectorY, selectorRadius)
        end)
    end
end

function renderer.drawTrackSignal(_, junction, inputIndex)
    local graphics = love.graphics
    local track = junction.inputs[inputIndex]
    local signalPoint = track.signalPoint
    local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 6 + inputIndex)
    local signalRadius = 12 + pulse * 3

    graphics.setLineWidth(6)
    if inputIndex == junction.activeInputIndex then
        graphics.setColor(0.42, 0.92, 0.54, 1)
    else
        graphics.setColor(0.92, 0.26, 0.2, 1)
    end
    graphics.circle("fill", signalPoint.x, signalPoint.y, signalRadius)
end

function renderer.drawTrain(scene, train)
    if train.completed and not train.exiting then
        return
    end

    local graphics = love.graphics
    local carriages = scene:getTrainCarriagePositions(train)
    local width = scene.carriageLength
    local height = scene.carriageHeight or 18
    local outlineWidth = 2

    for carriageIndex = #carriages, 1, -1 do
        local carriage = carriages[carriageIndex]
        local alpha = carriage.alpha or 1

        graphics.push()
        graphics.translate(carriage.x, carriage.y)
        graphics.rotate(carriage.angle)
        graphics.setColor(train.darkColor[1], train.darkColor[2], train.darkColor[3], 0.95 * alpha)
        graphics.rectangle("fill", -width * 0.5, -height * 0.5, width, height, 5, 5)
        graphics.setColor(train.color[1], train.color[2], train.color[3], alpha)
        graphics.setLineWidth(outlineWidth)
        graphics.rectangle("line", -width * 0.5, -height * 0.5, width, height, 5, 5)
        graphics.setColor(0.94, 0.96, 0.98, 0.9 * alpha)
        graphics.rectangle("fill", -width * 0.22, -height * 0.28, width * 0.44, height * 0.56, 3, 3)
        graphics.pop()
    end
end

function renderer.drawCollisionMarker(scene)
    if not scene.collisionPoint then
        return
    end

    local graphics = love.graphics
    local x = scene.collisionPoint.x
    local y = scene.collisionPoint.y

    graphics.setColor(0.98, 0.28, 0.22, 0.95)
    graphics.setLineWidth(6)
    graphics.line(x - 24, y - 24, x + 24, y + 24)
    graphics.line(x - 24, y + 24, x + 24, y - 24)
    graphics.circle("line", x, y, 30)
end

function renderer.drawScene(scene, options)
    local graphics = love.graphics
    local drawOptions = options or {}
    local highlightedEdgeIds = drawOptions.highlightedEdgeIds or scene:getHighlightedEdgeIds()
    local drawnEdgeIds = {}

    if drawOptions.backgroundColor then
        local color = drawOptions.backgroundColor
        graphics.setColor(color[1], color[2], color[3], color[4] or 1)
        graphics.rectangle("fill", 0, 0, scene.viewport.w, scene.viewport.h)
    end

    for _, junction in ipairs(scene.junctionOrder or {}) do
        for outputIndex = 1, #junction.outputs do
            local outputTrack = junction.outputs[outputIndex]
            renderer.drawOutputTrack(scene, junction, outputIndex, outputTrack and highlightedEdgeIds[outputTrack.id] == true)
            if outputTrack then
                drawnEdgeIds[outputTrack.id] = true
            end
        end

        for inputIndex = 1, #junction.inputs do
            local inputTrack = junction.inputs[inputIndex]
            renderer.drawInputTrack(scene, inputTrack, inputTrack and highlightedEdgeIds[inputTrack.id] == true)
            if inputTrack then
                drawnEdgeIds[inputTrack.id] = true
            end
        end

    end

    for _, track in pairs(scene.edges or {}) do
        if track and not drawnEdgeIds[track.id] then
            renderer.drawStandaloneTrack(scene, track, highlightedEdgeIds[track.id] == true)
        end
    end

    for _, junction in ipairs(scene.junctionOrder or {}) do
        renderer.drawCrossing(scene, junction)
    end

    for _, junction in ipairs(scene.junctionOrder or {}) do
        for inputIndex = 1, #junction.inputs do
            renderer.drawTrackSignal(scene, junction, inputIndex)
        end
    end

    if drawOptions.drawTrains ~= false then
        for _, train in ipairs(scene.trains or {}) do
            renderer.drawTrain(scene, train)
        end
    end

    for _, junction in ipairs(scene.junctionOrder or {}) do
        renderer.drawOutputSelector(scene, junction)
    end

    if drawOptions.drawCollision ~= false then
        renderer.drawCollisionMarker(scene)
    end
end

return renderer
