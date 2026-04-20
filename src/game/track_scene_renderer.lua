local roadTypes = require("src.game.road_types")

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
local ROAD_PATTERN_OUTLINE = { 0.04, 0.05, 0.07, 0.98 }
local ROAD_PATTERN_FILL = { 0.97, 0.98, 1.0, 0.94 }
local TRACK_STRIPE_LENGTH = 14

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
    graphics.setColor(0.17, 0.21, 0.24, 0.95)
    graphics.setLineWidth(scene.trackWidth + 10)
    graphics.line(points)

    if stripeColors then
        renderer.drawStripedTrack(scene, points, scene.trackWidth, stripeColors, trackAlpha)
    else
        renderer.drawTrackLine(scene, points, scene.trackWidth, trackColor, trackAlpha)
    end
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

function renderer.drawControlOverlay(_, junction)
    local graphics = love.graphics
    local control = junction.control
    local centerX = junction.mergePoint.x
    local centerY = junction.mergePoint.y
    local innerRadius = junction.crossingRadius - 10

    if control.type == "delayed" then
        local ratio = 0
        if control.armed and control.delay > 0 then
            ratio = 1 - (control.remainingDelay / control.delay)
        end

        graphics.setColor(0.99, 0.77, 0.32, 0.24)
        graphics.circle("fill", centerX, centerY, innerRadius)
        graphics.setColor(0.99, 0.77, 0.32, 1)
        graphics.setLineWidth(5)
        graphics.arc(
            "line",
            centerX,
            centerY,
            innerRadius + 4,
            -math.pi * 0.5,
            -math.pi * 0.5 + math.pi * 2 * ratio
        )

        love.graphics.setColor(0.05, 0.06, 0.08, 1)
        love.graphics.printf(
            control.armed and string.format("%.1f", control.remainingDelay) or "D",
            centerX - 20,
            centerY - 9,
            40,
            "center"
        )
        return
    end

    if control.type == "pump" then
        local ratio = control.target > 0 and (control.pumpCount / control.target) or 0
        local startAngle = math.pi * 1.16
        local endAngle = math.pi * 1.84
        local outerRadius = innerRadius + 12
        local cutoutRadius = innerRadius + 1
        local railRadius = (outerRadius + cutoutRadius) * 0.5
        local capRadius = (outerRadius - cutoutRadius) * 0.5
        local fillEndAngle = startAngle + (endAngle - startAngle) * ratio

        local function drawPumpBand(segmentStart, segmentEnd, color)
            local segmentStartCapX = centerX + math.cos(segmentStart) * railRadius
            local segmentStartCapY = centerY + math.sin(segmentStart) * railRadius
            local segmentEndCapX = centerX + math.cos(segmentEnd) * railRadius
            local segmentEndCapY = centerY + math.sin(segmentEnd) * railRadius

            graphics.stencil(function()
                graphics.arc("fill", centerX, centerY, outerRadius, segmentStart, segmentEnd)
                graphics.circle("fill", segmentStartCapX, segmentStartCapY, capRadius)
                graphics.circle("fill", segmentEndCapX, segmentEndCapY, capRadius)
            end, "replace", 1)

            graphics.stencil(function()
                graphics.arc("fill", centerX, centerY, cutoutRadius, segmentStart, segmentEnd)
            end, "replace", 0, true)

            graphics.setStencilTest("greater", 0)
            graphics.setColor(color[1], color[2], color[3], color[4])
            graphics.circle("fill", centerX, centerY, outerRadius + capRadius)
            graphics.setStencilTest()
        end

        drawPumpBand(startAngle, endAngle, { 0.86, 0.16, 0.82, 0.22 })

        if ratio > 0 then
            drawPumpBand(startAngle, fillEndAngle, { 0.95, 0.12, 0.88, 1 })
        end

        love.graphics.setColor(0.05, 0.06, 0.08, 1)
        love.graphics.printf(
            string.format("%d%%", math.floor(ratio * 100 + 0.5)),
            centerX - 24,
            centerY - 9,
            48,
            "center"
        )
        return
    end

    if control.type == "spring" then
        local ratio = control.holdTime > 0 and (control.remainingHold / control.holdTime) or 0

        graphics.setColor(0.4, 0.96, 0.74, 0.2)
        graphics.circle("fill", centerX, centerY, innerRadius)
        graphics.setColor(0.4, 0.96, 0.74, 1)
        graphics.setLineWidth(5)
        graphics.arc(
            "line",
            centerX,
            centerY,
            innerRadius + 4,
            -math.pi * 0.5,
            -math.pi * 0.5 + math.pi * 2 * ratio
        )

        love.graphics.setColor(0.05, 0.06, 0.08, 1)
        love.graphics.printf(
            control.armed and string.format("%.1f", control.remainingHold) or "S",
            centerX - 20,
            centerY - 9,
            40,
            "center"
        )
        return
    end

    if control.type == "relay" then
        local flashAlpha = control.flashTimer > 0 and (control.flashTimer / RELAY_FLASH_DURATION) or 0

        graphics.setColor(0.56, 0.72, 0.98, 0.16 + flashAlpha * 0.18)
        graphics.circle("fill", centerX, centerY, innerRadius)
        graphics.setColor(0.56, 0.72, 0.98, 1)
        graphics.setLineWidth(4)
        graphics.circle("line", centerX, centerY, innerRadius + 3)

        love.graphics.setColor(0.05, 0.06, 0.08, 1)
        love.graphics.printf(
            string.format("%d:%d", junction.activeInputIndex, junction.activeOutputIndex),
            centerX - 28,
            centerY - 9,
            56,
            "center"
        )
        return
    end

    if control.type == "trip" then
        local flashAlpha = control.flashTimer > 0 and (control.flashTimer / TRIP_FLASH_DURATION) or 0

        graphics.setColor(0.98, 0.6, 0.28, 0.16 + flashAlpha * 0.18)
        graphics.circle("fill", centerX, centerY, innerRadius)
        graphics.setColor(0.98, 0.6, 0.28, 1)
        graphics.setLineWidth(4)
        graphics.circle("line", centerX, centerY, innerRadius + 3)

        love.graphics.setColor(0.05, 0.06, 0.08, 1)
        love.graphics.printf(
            control.remainingTrips > 0 and tostring(control.remainingTrips) or "T",
            centerX - 18,
            centerY - 9,
            36,
            "center"
        )
        return
    end

    if control.type == "crossbar" then
        local flashAlpha = control.flashTimer > 0 and (control.flashTimer / CROSSBAR_FLASH_DURATION) or 0

        graphics.setColor(0.92, 0.38, 0.68, 0.16 + flashAlpha * 0.18)
        graphics.circle("fill", centerX, centerY, innerRadius)
        graphics.setColor(0.92, 0.38, 0.68, 1)
        graphics.setLineWidth(4)
        graphics.arc("line", centerX, centerY, innerRadius + 4, math.pi * 0.15, math.pi * 0.85)
        graphics.arc("line", centerX, centerY, innerRadius + 4, math.pi * 1.15, math.pi * 1.85)

        love.graphics.setColor(0.05, 0.06, 0.08, 1)
        love.graphics.printf(
            string.format("%d:%d", junction.activeInputIndex, junction.activeOutputIndex),
            centerX - 28,
            centerY - 9,
            56,
            "center"
        )
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
    local pulse = 0.75 + 0.22 * math.sin(love.timer.getTime() * 4.2)
    local outerRadius = junction.crossingRadius + pulse * 4
    local panelPadding = 2
    local panelRadius = junction.crossingRadius + panelPadding
    local plateInset = 8
    local plateWidth = 16
    local x = junction.mergePoint.x
    local y = junction.mergePoint.y

    renderer.drawActiveRouteIndicator(scene, junction, activeInput, activeOutputColor)

    graphics.setColor(0.05, 0.06, 0.08, 1)
    graphics.circle("fill", x, y, panelRadius)

    graphics.setColor(activeInputColor[1], activeInputColor[2], activeInputColor[3], 0.18)
    graphics.circle("fill", x, y, outerRadius)

    graphics.setColor(activeInputColor[1], activeInputColor[2], activeInputColor[3], 1)
    graphics.setLineWidth(3)
    graphics.circle("line", x, y, junction.crossingRadius)

    if activeInput and #activeInput.path.points >= 2 then
        local angle = scene:getInputTrackAngle(activeInput) - math.pi * 0.5

        graphics.push()
        graphics.translate(x, y)
        graphics.rotate(angle)
        graphics.setColor(0.96, 0.97, 0.99, 0.95)
        graphics.rectangle("fill", -plateWidth * 0.5, -(junction.crossingRadius - plateInset), plateWidth, panelRadius + 4, 6, 6)
        graphics.setColor(activeInput.color[1], activeInput.color[2], activeInput.color[3], 1)
        graphics.circle("fill", 0, -28, 11)
        graphics.pop()
    end

    if #junction.outputs > 1 and junction.control.type ~= "relay" and junction.control.type ~= "crossbar" then
        local selectorY = y + 36
        graphics.setColor(0.08, 0.1, 0.13, 1)
        graphics.circle("fill", x, selectorY, 15)
        graphics.setColor(activeOutputColor[1], activeOutputColor[2], activeOutputColor[3], 1)
        graphics.circle("line", x, selectorY, 15)
        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.printf(tostring(junction.activeOutputIndex), x - 14, selectorY - 7, 28, "center")
    end

    renderer.drawControlOverlay(scene, junction)
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
    local height = 18
    local outlineWidth = 2
    local alpha = 1

    if train.exiting and scene.exitFadeDuration > 0 then
        alpha = clamp((train.exitFadeRemaining or 0) / scene.exitFadeDuration, 0, 1)
    end

    if alpha <= 0 then
        return
    end

    for carriageIndex = #carriages, 1, -1 do
        local carriage = carriages[carriageIndex]

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

        renderer.drawCrossing(scene, junction)

        for inputIndex = 1, #junction.inputs do
            renderer.drawTrackSignal(scene, junction, inputIndex)
        end
    end

    for _, track in pairs(scene.edges or {}) do
        if track and not drawnEdgeIds[track.id] then
            renderer.drawStandaloneTrack(scene, track, highlightedEdgeIds[track.id] == true)
        end
    end

    if drawOptions.drawTrains ~= false then
        for _, train in ipairs(scene.trains or {}) do
            renderer.drawTrain(scene, train)
        end
    end

    if drawOptions.drawCollision ~= false then
        renderer.drawCollisionMarker(scene)
    end
end

return renderer
