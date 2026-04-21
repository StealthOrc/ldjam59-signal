return function(world, shared)
    -- Reuse the original module scope through a shared lookup table during the extraction refactor.
    setfenv(1, setmetatable({ world = world }, {
        __index = function(_, key)
            local sharedValue = shared[key]
            if sharedValue ~= nil then
                return sharedValue
            end

            return _G[key]
        end,
    }))

function world:getOutputDisplayColor(junction, outputIndex, isActive)
    local outputTrack = junction.outputs[outputIndex]
    if not outputTrack then
        return { 0.4, 0.4, 0.4 }, { 0.18, 0.18, 0.18 }
    end

    if outputTrack.adoptInputColor then
        local inputTrack = junction.inputs[junction.activeInputIndex]
        if inputTrack then
            return isActive and inputTrack.color or inputTrack.darkColor, inputTrack.darkColor
        end
    end

    return isActive and outputTrack.color or outputTrack.darkColor, outputTrack.darkColor
end

function world:pointOnPath(path, distance)
    return pointOnPath(path, distance)
end

function world:getRenderedTrackWindow(track)
    local trimStartDistance = 0
    local trimEndDistance = track.path.length

    if track.sourceType == "junction" then
        trimStartDistance = self.junctionTrackClearance
    end

    if track.targetType == "junction" then
        trimEndDistance = math.max(track.path.length - self.junctionTrackClearance, 0)
    end

    return trimStartDistance, trimEndDistance
end

function world:getRenderedTrackPoints(track)
    local trimStartDistance, trimEndDistance = self:getRenderedTrackWindow(track)
    return buildPathSlice(track.path, trimStartDistance, trimEndDistance)
end

function world:drawTrackPatternSegment(startX, startY, endX, endY, alpha, outlineWidth, fillWidth)
    return trackSceneRenderer.drawTrackPatternSegment(self, startX, startY, endX, endY, alpha, outlineWidth, fillWidth)
end

function world:drawTrackRoadTypeMarkers(track, isActive)
    return trackSceneRenderer.drawTrackRoadTypeMarkers(self, track, isActive)
end

function world:drawTrackLine(points, width, color, alpha)
    return trackSceneRenderer.drawTrackLine(self, points, width, color, alpha)
end

function world:drawStripedTrack(points, width, stripeColors, alpha)
    return trackSceneRenderer.drawStripedTrack(self, points, width, stripeColors, alpha)
end

function world:getInputTrackAngle(track)
    if not track or #track.path.points < 2 then
        return -math.pi * 0.5
    end

    local points = track.path.points
    return angleBetweenPoints(points[#points - 1], points[#points])
end

function world:drawInputTrack(track, isActive)
    return trackSceneRenderer.drawInputTrack(self, track, isActive)
end

function world:drawStandaloneTrack(track, isActive)
    return trackSceneRenderer.drawStandaloneTrack(self, track, isActive)
end

function world:drawOutputTrack(junction, outputIndex, isActive)
    return trackSceneRenderer.drawOutputTrack(self, junction, outputIndex, isActive)
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

local function drawTimerPie(graphics, centerX, centerY, radius, color, ratio)
    local fillRatio = clamp(ratio or 0, 0, 1)

    graphics.setColor(color[1], color[2], color[3], 0.12)
    graphics.circle("fill", centerX, centerY, radius)

    if fillRatio >= 0.999 then
        graphics.setColor(color[1], color[2], color[3], 0.3)
        graphics.circle("fill", centerX, centerY, radius)
    elseif fillRatio > 0.001 then
        graphics.setColor(color[1], color[2], color[3], 0.3)
        graphics.arc(
            "fill",
            centerX,
            centerY,
            radius,
            -math.pi * 0.5,
            -math.pi * 0.5 + math.pi * 2 * fillRatio
        )
    end

    graphics.setColor(color[1], color[2], color[3], 0.92)
    graphics.setLineWidth(3)
    graphics.circle("line", centerX, centerY, radius + 1.5)
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
        graphics.polygon(
            "fill",
            -halfWidth + inset,
            -halfHeight + inset,
            halfWidth - inset,
            -halfHeight + inset,
            0,
            -size * 0.06
        )
        graphics.polygon(
            "fill",
            -halfWidth + inset,
            halfHeight - inset,
            halfWidth - inset,
            halfHeight - inset,
            0,
            size * 0.06
        )
        graphics.pop()
    end, "replace", 1)

    graphics.setStencilTest("greater", 0)

    if sourceFill > 0.02 then
        graphics.setColor(color[1], color[2], color[3], 0.94)
        graphics.polygon(
            "fill",
            sourceCenterX - sourceWidth,
            sourceBaseY,
            sourceCenterX + sourceWidth,
            sourceBaseY,
            sourceCenterX,
            sourceTipY
        )
    end

    if targetFill > 0.02 then
        graphics.setColor(color[1], color[2], color[3], 0.94)
        graphics.polygon(
            "fill",
            targetCenterX - targetWidth,
            targetBaseY,
            targetCenterX + targetWidth,
            targetBaseY,
            targetCenterX,
            targetTipY
        )
    end

    if streamAlpha > 0.04 then
        graphics.setColor(color[1], color[2], color[3], 0.82 * streamAlpha)
        graphics.polygon(
            "fill",
            centerX - middleWidth,
            middleY,
            centerX + middleWidth,
            middleY,
            centerX,
            middleTipY
        )

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

        local scaleX = baseScale * lerp(1, 1.08, animatedCompression)
        local scaleY = baseScale * lerp(1, 0.7, animatedCompression)

        graphics.setColor(1, 1, 1, 1)
        graphics.draw(
            springImage,
            centerX,
            centerY + yOffset,
            0,
            scaleX,
            scaleY,
            imageWidth * 0.5,
            imageHeight * 0.5
        )
        return
    end

    local fullHeight = size * 1.12
    local compressedHeight = size * 0.64
    local coilHeight = lerp(fullHeight, compressedHeight, clampedCompression)
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
        local y = lerp(-coilHeight * 0.5, coilHeight * 0.5, ratio)
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
    graphics.setColor(0.05, 0.06, 0.08, 1)

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
        graphics.draw(
            relayImage,
            centerX,
            centerY,
            0,
            baseScale * pulseScale,
            baseScale * pulseScale,
            imageWidth * 0.5,
            imageHeight * 0.5
        )
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
    graphics.draw(
        image,
        centerX,
        centerY,
        0,
        scale,
        scale,
        imageWidth * 0.5,
        imageHeight * 0.5
    )
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
    local bubbleRadius = junction.crossingRadius - 4
    local bubbleX = junction.mergePoint.x
    local bubbleY = junction.mergePoint.y

    return bubbleX, bubbleY, bubbleRadius
end

local function drawControlBubble(graphics, junction, ringColor)
    local junctionX = junction.mergePoint.x
    local junctionY = junction.mergePoint.y
    local bubbleX, bubbleY, bubbleRadius = getControlBubbleLayout(junction)
    local dx = bubbleX - junctionX
    local dy = bubbleY - junctionY
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance > 0.001 then
        local nx = dx / distance
        local ny = dy / distance
        local startX = junctionX + nx * (junction.crossingRadius + 4)
        local startY = junctionY + ny * (junction.crossingRadius + 4)
        local endX = bubbleX - nx * (bubbleRadius + 1)
        local endY = bubbleY - ny * (bubbleRadius + 1)

        graphics.setLineStyle("rough")
        graphics.setLineWidth(8)
        graphics.setColor(0.05, 0.06, 0.08, 0.92)
        graphics.line(startX, startY, endX, endY)
        graphics.setLineWidth(3)
        graphics.setColor(ringColor[1], ringColor[2], ringColor[3], 0.65)
        graphics.line(startX, startY, endX, endY)
    end

    graphics.setColor(0.05, 0.06, 0.08, 0.9)
    graphics.circle("fill", bubbleX, bubbleY, bubbleRadius)

    graphics.setColor(ringColor[1], ringColor[2], ringColor[3], 0.12)
    graphics.circle("fill", bubbleX, bubbleY, bubbleRadius)

    graphics.setColor(ringColor[1], ringColor[2], ringColor[3], 0.88)
    graphics.setLineWidth(3)
    graphics.circle("line", bubbleX, bubbleY, bubbleRadius)

    return bubbleX, bubbleY, bubbleRadius
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

function world:drawControlOverlay(junction)
    return trackSceneRenderer.drawControlOverlay(self, junction)
end

function world:getOutputTrackAngle(track)
    if not track or #track.path.points < 2 then
        return math.pi * 0.5
    end

    local points = track.path.points
    return angleBetweenPoints(points[1], points[2])
end

function world:drawActiveRouteIndicator(junction, activeInput, activeOutputColor)
    return trackSceneRenderer.drawActiveRouteIndicator(self, junction, activeInput, activeOutputColor)
end

function world:drawCrossing(junction)
    return trackSceneRenderer.drawCrossing(self, junction)
end

function world:drawTrackSignal(junction, inputIndex)
    return trackSceneRenderer.drawTrackSignal(self, junction, inputIndex)
end

function world:drawTrain(train)
    return trackSceneRenderer.drawTrain(self, train)
end

function world:drawCollisionMarker()
    return trackSceneRenderer.drawCollisionMarker(self)
end

function world:draw()
    return trackSceneRenderer.drawScene(self, {
        backgroundColor = { 0.08, 0.1, 0.12, 1 },
    })
end


end
