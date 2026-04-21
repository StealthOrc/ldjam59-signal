return function(ui, shared)
    local moduleEnvironment = setmetatable({ ui = ui }, {
        __index = function(_, key)
            local sharedValue = shared[key]
            if sharedValue ~= nil then
                return sharedValue
            end

            return _G[key]
        end,
        __newindex = shared,
    })

    setfenv(1, moduleEnvironment)

function getPlayBackRect(game)
    local width = game and game.currentRunOrigin == "editor" and 162 or 138
    local viewportWidth = game and game.viewport and game.viewport.w or 1280
    return {
        x = viewportWidth - width - 32,
        y = 28,
        w = width,
        h = 38,
    }
end

function getPlayStartRect()
    return {
        x = 1048,
        y = 74,
        w = 200,
        h = 46,
    }
end

function getRunBackLabel(game)
    if game and game.currentRunOrigin == "editor" then
        return "Back to Editor"
    end

    return "Level Select"
end

function formatTimeValue(value)
    if value == nil then
        return "--"
    end
    return string.format("%.1f", value)
end

function getColorLabel(colorId)
    if not colorId then
        return "--"
    end
    return colorId:sub(1, 1):upper() .. colorId:sub(2)
end

function getTrackOuterAnchor(track, isOutput)
    local points = track and track.path and track.path.points or {}
    if #points == 0 then
        return 0, 0, 0, -1
    end

    local outerPoint
    local innerPoint
    if isOutput then
        outerPoint = points[#points]
        innerPoint = points[#points - 1] or outerPoint
    else
        outerPoint = points[1]
        innerPoint = points[2] or outerPoint
    end

    local angle = angleBetweenPoints(outerPoint, innerPoint)
    local dirX = math.cos(angle)
    local dirY = math.sin(angle)
    if not isOutput then
        dirX = -dirX
        dirY = -dirY
    end

    return outerPoint.x, outerPoint.y, dirX, dirY
end

function getAnchoredPanelRect(game, anchorX, anchorY, dirX, dirY, width, height, offset)
    local push = offset or 18
    local targetX = anchorX + dirX * push
    local targetY = anchorY + dirY * push
    local rectX = targetX - width * 0.5
    local rectY

    if math.abs(dirX) > math.abs(dirY) then
        if dirX < 0 then
            rectX = targetX - width - 10
        else
            rectX = targetX + 10
        end
        rectY = targetY - height * 0.5
    else
        if dirY < 0 then
            rectY = targetY - height - 10
        else
            rectY = targetY + 10
        end
    end

    return {
        x = clamp(rectX, 18, game.viewport.w - width - 18),
        y = clamp(rectY or (targetY - height * 0.5), 82, game.viewport.h - height - 70),
        w = width,
        h = height,
    }
end

local PREP_TRAIN_ROW_SPACING = 8
local PREP_TRAIN_ARROW_LENGTH = 19
local getPrepTrainRowWidth

function getInputPrepCardRect(game, edge, trainCount, inputGroups)
    local rowCount = math.max(1, trainCount or 0)
    local height = 20 + rowCount * 44
    local width = 140

    for _, group in ipairs(inputGroups or game.world:getInputEdgeGroups()) do
        if group.edge.id == edge.id then
            for _, train in ipairs(group.trains or {}) do
                width = math.max(width, getPrepTrainRowWidth(game, train) + 20)
            end
            break
        end
    end

    local anchorX, anchorY, dirX, dirY = getTrackOuterAnchor(edge, false)
    return getAnchoredPanelRect(game, anchorX, anchorY, dirX, dirY, width, height, 12)
end

function getInputLiveCardRect(game, edge, train)
    local anchorX, anchorY, dirX, dirY = getTrackOuterAnchor(edge, false)
    local width = math.max(140, getPrepTrainRowWidth(game, train) + 20)
    return getAnchoredPanelRect(game, anchorX, anchorY, dirX, dirY, width, 54, 12)
end

function getOutputBadgeRect(game, edge, badge)
    local anchorX, anchorY, dirX, dirY = getTrackOuterAnchor(edge, true)
    love.graphics.setFont(game.fonts.body)
    local ratioText = string.format("%d / %d", badge.deliveredCount or 0, badge.expectedCount or 0)
    local width = math.max(64, game.fonts.body:getWidth(ratioText) + PREP_TRAIN_ROW_SPACING * 2 + 16)
    return getAnchoredPanelRect(game, anchorX, anchorY, dirX, dirY, width, 44, 12)
end

function getActivePlayGuideStep(game)
    if not game or not game.playGuide then
        return nil
    end

    local steps = game.playGuide.steps or {}
    if #steps == 0 then
        return nil
    end

    local stepIndex = clamp(game.playGuide.stepIndex or 1, 1, #steps)
    return steps[stepIndex], stepIndex, #steps
end

function getPlayGuideStepAtIndex(game, stepIndex)
    if not game or not game.playGuide then
        return nil, nil, nil
    end

    local steps = game.playGuide.steps or {}
    if #steps == 0 then
        return nil, nil, nil
    end

    local resolvedIndex = clamp(stepIndex or game.playGuide.stepIndex or 1, 1, #steps)
    return steps[resolvedIndex], resolvedIndex, #steps
end

function createGuideRectShape(rect, padding, cornerRadius)
    local extraPadding = padding or PLAY_GUIDE_LAYOUT.focusPadding
    return {
        kind = "rect",
        x = rect.x - extraPadding,
        y = rect.y - extraPadding,
        w = rect.w + extraPadding * 2,
        h = rect.h + extraPadding * 2,
        radius = cornerRadius or PLAY_GUIDE_LAYOUT.focusRadius,
    }
end

function flattenGuidePoints(points)
    local flattened = {}

    for _, point in ipairs(points or {}) do
        flattened[#flattened + 1] = point.x
        flattened[#flattened + 1] = point.y
    end

    return flattened
end

function createGuidePolylineShape(track, width)
    if not track or not track.path or #((track.path and track.path.points) or {}) < 2 then
        return nil
    end

    local flattenedPoints = flattenGuidePoints(track.path.points)
    if #flattenedPoints < 4 then
        return nil
    end

    return {
        kind = "polyline",
        points = flattenedPoints,
        width = width or 42,
    }
end

function appendTrackGuideFocusShape(shapes, track, width)
    if not shapes then
        return
    end

    local polylineShape = createGuidePolylineShape(track, width)
    if not polylineShape then
        return
    end

    shapes[#shapes + 1] = polylineShape
end

function getGuideTargetJunction(game, step)
    if not game or not game.world or type(step) ~= "table" then
        return nil
    end

    local junctionOrder = game.world.junctionOrder or {}
    if #junctionOrder == 0 then
        return nil
    end

    local targetJunctionId = tostring(step.junctionId or "")
    if targetJunctionId ~= "" then
        for _, junction in ipairs(junctionOrder) do
            if tostring(junction.id or "") == targetJunctionId then
                return junction
            end
        end
    end

    local targetIndex = tonumber(step.junctionIndex)
    if targetIndex then
        targetIndex = math.max(1, math.min(#junctionOrder, math.floor(targetIndex)))
        return junctionOrder[targetIndex]
    end

    return junctionOrder[1]
end

function buildPlayGuideJunctionShapes(game, step, options)
    if not game or not game.world or not step then
        return {}
    end

    local junction = getGuideTargetJunction(game, step)
    if not junction then
        return {}
    end

    local resolvedOptions = options or {}
    local includeJunction = resolvedOptions.includeJunction ~= false
    local includeSelector = resolvedOptions.includeSelector == true
    local shapes = {}

    if includeJunction then
        shapes[#shapes + 1] = {
            kind = "circle",
            x = junction.mergePoint.x,
            y = junction.mergePoint.y,
            radius = (junction.crossingRadius or 20) + 16,
        }
    end

    if includeSelector and step.target == "junction_with_selector" then
        local selectorX, selectorY, selectorRadius = trackSceneRenderer.getOutputSelectorLayout(junction)
        if selectorX and selectorY and selectorRadius then
            shapes[#shapes + 1] = {
                kind = "circle",
                x = selectorX,
                y = selectorY,
                radius = selectorRadius + 12,
            }
        end
    end

    if step.focusIncomingTracks == true then
        for _, inputTrack in ipairs(junction.inputs or {}) do
            appendTrackGuideFocusShape(shapes, inputTrack, 42)
        end
    end

    return shapes
end

function getPlayGuideFocusShapes(game, step)
    if not game or not game.world or not step then
        return {}
    end

    if step.target == "screen_center" then
        return {}
    end

    if step.target == "junction" or step.target == "junction_with_selector" then
        return buildPlayGuideJunctionShapes(game, step, {
            includeJunction = step.focusSelectorOnly ~= true,
            includeSelector = step.target == "junction_with_selector",
        })
    end

    if step.target == "first_input_card" then
        local inputGroups = game.world:getInputEdgeGroups()
        local group = inputGroups[1]
        if not group then
            return {}
        end
        return {
            createGuideRectShape(getInputPrepCardRect(game, group.edge, #(group.trains or {}), inputGroups), 10, 22),
        }
    end

    if step.target == "first_output_badge" then
        local outputGroups = game.world:getOutputBadgeGroups()
        local badge = outputGroups[1]
        if not badge then
            return {}
        end
        return {
            createGuideRectShape(getOutputBadgeRect(game, badge.edge, badge), 10, 22),
        }
    end

    if step.target == "start_run_button" then
        return {
            createGuideRectShape(getPlayStartRect(), 10, 22),
        }
    end

    return {}
end

function getPlayGuideAnchorShapes(game, step, focusShapes)
    if not game or not step then
        return focusShapes or {}
    end

    if step.anchorTarget == "junction" and (step.target == "junction" or step.target == "junction_with_selector") then
        return buildPlayGuideJunctionShapes(game, step, {
            includeJunction = true,
            includeSelector = false,
        })
    end

    return focusShapes or {}
end

function getGuideBounds(shapes, viewport)
    local minX = math.huge
    local minY = math.huge
    local maxX = -math.huge
    local maxY = -math.huge

    for _, shape in ipairs(shapes or {}) do
        if shape.kind == "circle" then
            minX = math.min(minX, shape.x - shape.radius)
            minY = math.min(minY, shape.y - shape.radius)
            maxX = math.max(maxX, shape.x + shape.radius)
            maxY = math.max(maxY, shape.y + shape.radius)
        elseif shape.kind == "polyline" then
            local halfWidth = (shape.width or 0) * 0.5
            for pointIndex = 1, #(shape.points or {}), 2 do
                local pointX = shape.points[pointIndex]
                local pointY = shape.points[pointIndex + 1]
                minX = math.min(minX, pointX - halfWidth)
                minY = math.min(minY, pointY - halfWidth)
                maxX = math.max(maxX, pointX + halfWidth)
                maxY = math.max(maxY, pointY + halfWidth)
            end
        else
            minX = math.min(minX, shape.x)
            minY = math.min(minY, shape.y)
            maxX = math.max(maxX, shape.x + shape.w)
            maxY = math.max(maxY, shape.y + shape.h)
        end
    end

    if minX == math.huge then
        local viewportWidth = viewport and viewport.w or 1280
        local viewportHeight = viewport and viewport.h or 720
        local centerX = viewportWidth * 0.5
        local centerY = viewportHeight * 0.5
        return {
            minX = centerX - 10,
            minY = centerY - 10,
            maxX = centerX + 10,
            maxY = centerY + 10,
            centerX = centerX,
            centerY = centerY,
        }
    end

    return {
        minX = minX,
        minY = minY,
        maxX = maxX,
        maxY = maxY,
        centerX = (minX + maxX) * 0.5,
        centerY = (minY + maxY) * 0.5,
    }
end

function getPlayGuideButtonRects(tooltipRect, showSkip)
    local resolvedShowSkip = showSkip ~= false
    local totalButtonWidth = PLAY_GUIDE_LAYOUT.buttonNextW
    if resolvedShowSkip then
        totalButtonWidth = PLAY_GUIDE_LAYOUT.buttonSkipW + PLAY_GUIDE_LAYOUT.buttonGap + PLAY_GUIDE_LAYOUT.buttonNextW
    end
    local buttonsX = tooltipRect.x + math.floor((tooltipRect.w - totalButtonWidth) * 0.5 + 0.5)
    local buttonsY = tooltipRect.y + tooltipRect.h - PLAY_GUIDE_LAYOUT.paddingY - PLAY_GUIDE_LAYOUT.buttonH

    local skipRect = nil
    local nextX = buttonsX
    if resolvedShowSkip then
        skipRect = {
            x = buttonsX,
            y = buttonsY,
            w = PLAY_GUIDE_LAYOUT.buttonSkipW,
            h = PLAY_GUIDE_LAYOUT.buttonH,
        }
        nextX = buttonsX + PLAY_GUIDE_LAYOUT.buttonSkipW + PLAY_GUIDE_LAYOUT.buttonGap
    end

    return skipRect, {
        x = nextX,
        y = buttonsY,
        w = PLAY_GUIDE_LAYOUT.buttonNextW,
        h = PLAY_GUIDE_LAYOUT.buttonH,
    }
end

function getPlayGuideLayout(game, overrideStepIndex)
    local step, stepIndex, stepCount = getPlayGuideStepAtIndex(game, overrideStepIndex)
    if not step then
        return nil
    end

    local width = PLAY_GUIDE_LAYOUT.width
    local textWidth = width - PLAY_GUIDE_LAYOUT.paddingX * 2
    love.graphics.setFont(game.fonts.small)
    local textLineCount = getWrappedLineCount(game.fonts.small, step.text or "", textWidth)
    local textHeight = textLineCount * game.fonts.small:getHeight()
    local height = PLAY_GUIDE_LAYOUT.paddingY * 2
        + textHeight
        + PLAY_GUIDE_LAYOUT.buttonGap
        + PLAY_GUIDE_LAYOUT.buttonH

    local focusShapes = getPlayGuideFocusShapes(game, step)
    local anchorShapes = getPlayGuideAnchorShapes(game, step, focusShapes)
    local bounds = getGuideBounds(anchorShapes, game.viewport)
    local tooltipX = bounds.centerX - width * 0.5
    local tooltipY = bounds.minY - height - PLAY_GUIDE_LAYOUT.gap

    if step.placement == "center" then
        tooltipY = bounds.centerY - height * 0.5
    elseif step.placement == "right" then
        tooltipX = bounds.maxX + PLAY_GUIDE_LAYOUT.gap
        tooltipY = bounds.centerY - height * 0.5
    elseif step.placement == "top_right" then
        tooltipX = bounds.maxX + PLAY_GUIDE_LAYOUT.gap
        tooltipY = bounds.minY - height - PLAY_GUIDE_LAYOUT.gap
    elseif step.placement == "below" then
        tooltipY = bounds.maxY + PLAY_GUIDE_LAYOUT.gap
    end

    tooltipX = clamp(tooltipX, PLAY_GUIDE_LAYOUT.margin, game.viewport.w - width - PLAY_GUIDE_LAYOUT.margin)
    tooltipY = clamp(
        tooltipY,
        PLAY_GUIDE_LAYOUT.minTop,
        game.viewport.h - height - PLAY_GUIDE_LAYOUT.margin
    )
    local tooltipRect = {
        x = tooltipX,
        y = tooltipY,
        w = width,
        h = height,
    }
    local showSkip = step.hideSkip ~= true and step.showSkip ~= false
    local skipRect, nextRect = getPlayGuideButtonRects(tooltipRect, showSkip)

    return {
        step = step,
        stepIndex = stepIndex,
        stepCount = stepCount,
        focusShapes = focusShapes,
        tooltipRect = tooltipRect,
        skipRect = skipRect,
        nextRect = nextRect,
        nextLabel = step.nextLabel or (stepIndex >= stepCount and "I'm Ready" or "Next"),
        skipLabel = step.skipLabel or "Skip",
    }
end

function easeInBack(t)
    local s = 1.70158
    return t * t * ((s + 1) * t - s)
end

function easeOutBack(t)
    local s = 1.70158
    local value = t - 1
    return 1 + value * value * ((s + 1) * value + s)
end

function easeInOutCubic(t)
    if t < 0.5 then
        return 4 * t * t * t
    end

    local value = -2 * t + 2
    return 1 - (value * value * value) * 0.5
end

function clamp01(value)
    return clamp(value or 0, 0, 1)
end

function getCollapsedGuideRect(rect)
    local collapsedWidth = math.max(28, rect.w * 0.16)
    local collapsedHeight = math.max(18, rect.h * 0.14)
    return {
        x = rect.x + (rect.w - collapsedWidth) * 0.5,
        y = rect.y + (rect.h - collapsedHeight) * 0.5,
        w = collapsedWidth,
        h = collapsedHeight,
    }
end

function interpolateRect(fromRect, toRect, t)
    return {
        x = lerp(fromRect.x, toRect.x, t),
        y = lerp(fromRect.y, toRect.y, t),
        w = lerp(fromRect.w, toRect.w, t),
        h = lerp(fromRect.h, toRect.h, t),
    }
end

function offsetRect(rect, offsetX, offsetY)
    return {
        x = rect.x + offsetX,
        y = rect.y + offsetY,
        w = rect.w,
        h = rect.h,
    }
end

function applyAnimatedGuideButtonRects(layout)
    local step = layout and layout.step or nil
    local showSkip = not step or (step.hideSkip ~= true and step.showSkip ~= false)
    layout.skipRect, layout.nextRect = getPlayGuideButtonRects(layout.tooltipRect, showSkip)
    return layout
end

function getAnimatedPlayGuideLayout(game)
    local currentLayout = getPlayGuideLayout(game)
    if not currentLayout then
        return nil
    end

    local transition = game and game.playGuideTransition or nil
    if not transition then
        currentLayout.contentAlpha = 1
        currentLayout.buttonAlpha = 1
        currentLayout.tooltipAlpha = 1
        currentLayout.outlineAlpha = 1
        return applyAnimatedGuideButtonRects(currentLayout)
    end

    local fromLayout = getPlayGuideLayout(game, transition.fromStepIndex) or currentLayout
    local toLayout = transition.toStepIndex and getPlayGuideLayout(game, transition.toStepIndex) or nil
    local progress = clamp01(transition.phaseProgress)
    local animatedLayout = {
        step = fromLayout.step,
        stepIndex = fromLayout.stepIndex,
        stepCount = fromLayout.stepCount,
        focusShapes = fromLayout.focusShapes,
        skipRect = fromLayout.skipRect,
        nextRect = fromLayout.nextRect,
        nextLabel = fromLayout.nextLabel,
        skipLabel = fromLayout.skipLabel,
        tooltipRect = fromLayout.tooltipRect,
        contentAlpha = 0,
        buttonAlpha = 0,
        tooltipAlpha = 1,
        outlineAlpha = 1,
    }

    if transition.kind == "dismiss" then
        local eased = easeInBack(progress)
        animatedLayout.tooltipRect = interpolateRect(fromLayout.tooltipRect, getCollapsedGuideRect(fromLayout.tooltipRect), eased)
        animatedLayout.contentAlpha = 1 - clamp01(progress * 2.2)
        animatedLayout.buttonAlpha = animatedLayout.contentAlpha
        animatedLayout.tooltipAlpha = 1 - clamp01(progress * 0.4)
        animatedLayout.outlineAlpha = 1 - clamp01(progress * 0.4)
        return applyAnimatedGuideButtonRects(animatedLayout)
    end

    local targetLayout = toLayout or fromLayout
    animatedLayout.focusShapes = transition.phase == "shrink" and fromLayout.focusShapes or targetLayout.focusShapes
    animatedLayout.step = targetLayout.step
    animatedLayout.stepIndex = targetLayout.stepIndex
    animatedLayout.stepCount = targetLayout.stepCount
    animatedLayout.nextLabel = targetLayout.nextLabel
    animatedLayout.skipLabel = targetLayout.skipLabel

    if transition.phase == "shrink" then
        local eased = easeInBack(progress)
        animatedLayout.step = fromLayout.step
        animatedLayout.stepIndex = fromLayout.stepIndex
        animatedLayout.stepCount = fromLayout.stepCount
        animatedLayout.nextLabel = fromLayout.nextLabel
        animatedLayout.skipLabel = fromLayout.skipLabel
        animatedLayout.tooltipRect = interpolateRect(fromLayout.tooltipRect, getCollapsedGuideRect(fromLayout.tooltipRect), eased)
        animatedLayout.contentAlpha = 1 - clamp01(progress * 2.2)
        animatedLayout.buttonAlpha = animatedLayout.contentAlpha
        return applyAnimatedGuideButtonRects(animatedLayout)
    end

    if transition.phase == "move" then
        local eased = easeInOutCubic(progress)
        local fromCollapsed = getCollapsedGuideRect(fromLayout.tooltipRect)
        local toCollapsed = getCollapsedGuideRect(targetLayout.tooltipRect)
        local movedRect = interpolateRect(fromCollapsed, toCollapsed, eased)
        local arcOffsetY = -math.sin(eased * math.pi) * 42
        animatedLayout.tooltipRect = offsetRect(movedRect, 0, arcOffsetY)
        animatedLayout.contentAlpha = 0
        animatedLayout.buttonAlpha = 0
        return applyAnimatedGuideButtonRects(animatedLayout)
    end

    local eased = easeOutBack(progress)
    animatedLayout.tooltipRect = interpolateRect(getCollapsedGuideRect(targetLayout.tooltipRect), targetLayout.tooltipRect, eased)
    animatedLayout.contentAlpha = clamp01((progress - 0.18) / 0.82)
    animatedLayout.buttonAlpha = clamp01((progress - 0.35) / 0.65)
    return applyAnimatedGuideButtonRects(animatedLayout)
end

function drawGuideFocusShape(shape)
    local graphics = love.graphics
    if shape.kind == "circle" then
        graphics.circle("fill", shape.x, shape.y, shape.radius)
    elseif shape.kind == "polyline" then
        graphics.setLineWidth(shape.width or 42)
        graphics.setLineJoin("bevel")
        graphics.setLineStyle("rough")
        graphics.line(shape.points)
    else
        graphics.rectangle("fill", shape.x, shape.y, shape.w, shape.h, shape.radius, shape.radius)
    end
end

function drawGuideFocusOutline(shape)
    local graphics = love.graphics
    if shape.kind == "circle" then
        graphics.circle("line", shape.x, shape.y, shape.radius)
    elseif shape.kind == "polyline" then
        return
    else
        graphics.rectangle("line", shape.x, shape.y, shape.w, shape.h, shape.radius, shape.radius)
    end
end

function ui.getPlayGuideActionAt(game, x, y)
    if game and game.playGuideTransition then
        return nil
    end

    local layout = getAnimatedPlayGuideLayout(game)
    if not layout then
        return nil
    end

    if pointInRect(x, y, layout.nextRect) then
        return "next"
    end

    if layout.skipRect and pointInRect(x, y, layout.skipRect) then
        return "skip"
    end

    return nil
end

function formatSecondsLabel(value)
    return string.format("%ss", formatTimeValue(value))
end

function getPrepTrainPreviewMetrics(game, train)
    local wagonCount = math.max(1, train.wagonCount or 1)
    local gap = 4
    local carriageWidth = 16
    local carriageHeight = 16
    local countText = nil
    local totalWidth
    local iconCount = math.min(wagonCount, 5)

    if wagonCount > 5 then
        love.graphics.setFont(game.fonts.small)
        countText = string.format("%dx", wagonCount)
        totalWidth = game.fonts.small:getWidth(countText) + gap + carriageWidth
        iconCount = 1
    else
        totalWidth = iconCount * carriageWidth + (iconCount - 1) * gap
    end

    return {
        gap = gap,
        wagonCount = wagonCount,
        iconCount = iconCount,
        countText = countText,
        carriageWidth = carriageWidth,
        carriageHeight = carriageHeight,
        totalWidth = totalWidth,
    }
end

function getPrepTrainRowLayout(game, rowRect, leadText, deadlineText, train)
    love.graphics.setFont(game.fonts.small)

    local centerY = rowRect.y + rowRect.h * 0.5
    local leadWidth = game.fonts.small:getWidth(leadText)
    local deadlineWidth = deadlineText and game.fonts.small:getWidth(deadlineText) or 0
    local contentStartX = rowRect.x + PREP_TRAIN_ROW_SPACING
    local metrics = getPrepTrainPreviewMetrics(game, train)
    local layout = {
        centerY = centerY,
        contentStartX = contentStartX,
        leadWidth = leadWidth,
        leadTextX = contentStartX,
        leadTextY = rowRect.y + 9,
        leadRect = {
            x = contentStartX - 4,
            y = rowRect.y + 5,
            w = leadWidth + 8,
            h = rowRect.h - 10,
        },
        previewX = contentStartX + leadWidth + PREP_TRAIN_ROW_SPACING,
        previewRect = nil,
        deadline = nil,
        metrics = metrics,
    }

    if deadlineText then
        local arrowStartX = layout.previewX
        local arrowEndX = arrowStartX + PREP_TRAIN_ARROW_LENGTH
        local deadlineTextX = arrowEndX + PREP_TRAIN_ROW_SPACING
        layout.deadline = {
            arrowStartX = arrowStartX,
            arrowEndX = arrowEndX,
            textX = deadlineTextX,
            textY = rowRect.y + 9,
            width = deadlineWidth,
            rect = {
                x = arrowStartX - 4,
                y = rowRect.y + 5,
                w = (deadlineTextX + deadlineWidth) - arrowStartX + 8,
                h = rowRect.h - 10,
            },
        }
        layout.previewX = deadlineTextX + deadlineWidth + PREP_TRAIN_ROW_SPACING
    end

    layout.previewRect = {
        x = layout.previewX - 4,
        y = math.floor(centerY - metrics.carriageHeight * 0.5 + 0.5) - 3,
        w = metrics.totalWidth + 8,
        h = metrics.carriageHeight + 6,
    }

    return layout
end

function getPrepTrainRowContentWidth(game, train)
    love.graphics.setFont(game.fonts.small)

    local startText = formatSecondsLabel(train.spawnTime or 0)
    local deadlineText = train.deadline ~= nil and formatSecondsLabel(train.deadline) or nil
    local startWidth = game.fonts.small:getWidth(startText)
    local deadlineWidth = deadlineText and game.fonts.small:getWidth(deadlineText) or 0
    local trainMetrics = getPrepTrainPreviewMetrics(game, train)

    if deadlineText then
        return startWidth
            + PREP_TRAIN_ROW_SPACING
            + PREP_TRAIN_ARROW_LENGTH
            + PREP_TRAIN_ROW_SPACING
            + deadlineWidth
            + PREP_TRAIN_ROW_SPACING
            + trainMetrics.totalWidth
    end

    return startWidth + PREP_TRAIN_ROW_SPACING + trainMetrics.totalWidth
end

getPrepTrainRowWidth = function(game, train)
    return getPrepTrainRowContentWidth(game, train) + PREP_TRAIN_ROW_SPACING * 2
end

function drawPrepTrainPreview(game, x, centerY, train)
    local graphics = love.graphics
    local metrics = getPrepTrainPreviewMetrics(game, train)
    local startX = x
    local carriageY = math.floor(centerY - metrics.carriageHeight * 0.5 + 0.5)
    local bodyColor = train.color or { 0.84, 0.88, 0.92 }
    local darkColor = train.darkColor or { bodyColor[1] * 0.42, bodyColor[2] * 0.42, bodyColor[3] * 0.42 }

    if metrics.countText then
        love.graphics.setFont(game.fonts.small)
        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.print(metrics.countText, startX, math.floor(centerY - game.fonts.small:getHeight() * 0.5 + 0.5))
        startX = startX + game.fonts.small:getWidth(metrics.countText) + metrics.gap
    end

    for carriageIndex = 1, metrics.iconCount do
        local carriageX = startX + (carriageIndex - 1) * (metrics.carriageWidth + metrics.gap)
        graphics.setColor(darkColor[1], darkColor[2], darkColor[3], 0.96)
        graphics.rectangle("fill", carriageX, carriageY, metrics.carriageWidth, metrics.carriageHeight, 4, 4)
        graphics.setColor(bodyColor[1], bodyColor[2], bodyColor[3], 1)
        graphics.setLineWidth(1.4)
        graphics.rectangle("line", carriageX, carriageY, metrics.carriageWidth, metrics.carriageHeight, 4, 4)

        local windowWidth = math.max(3, metrics.carriageWidth - 8)
        local windowHeight = math.max(4, metrics.carriageHeight - 8)
        graphics.setColor(0.95, 0.97, 1, 0.9)
        graphics.rectangle(
            "fill",
            carriageX + math.floor((metrics.carriageWidth - windowWidth) * 0.5 + 0.5),
            carriageY + math.floor((metrics.carriageHeight - windowHeight) * 0.5 + 0.5),
            windowWidth,
            windowHeight,
            2,
            2
        )
    end

    graphics.setLineWidth(1)
end

function drawTrainRow(game, rowRect, leadText, deadlineText, train)
    local graphics = love.graphics
    local layout = getPrepTrainRowLayout(game, rowRect, leadText, deadlineText, train)

    graphics.setColor(0.06, 0.08, 0.1, 0.96)
    graphics.rectangle("fill", rowRect.x, rowRect.y, rowRect.w, rowRect.h, 10, 10)
    graphics.setColor(0.24, 0.32, 0.4, 1)
    graphics.setLineWidth(1.1)
    graphics.rectangle("line", rowRect.x, rowRect.y, rowRect.w, rowRect.h, 10, 10)

    love.graphics.setFont(game.fonts.small)

    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.print(leadText, layout.leadTextX, layout.leadTextY)

    if layout.deadline then
        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.setLineWidth(2)
        graphics.line(layout.deadline.arrowStartX, layout.centerY, layout.deadline.arrowEndX, layout.centerY)
        graphics.line(layout.deadline.arrowEndX - 4, layout.centerY - 3, layout.deadline.arrowEndX, layout.centerY)
        graphics.line(layout.deadline.arrowEndX - 4, layout.centerY + 3, layout.deadline.arrowEndX, layout.centerY)
        graphics.setLineWidth(1)
        graphics.print(deadlineText, layout.deadline.textX, layout.deadline.textY)
    end

    drawPrepTrainPreview(game, layout.previewX, layout.centerY, train)
end

function drawInputPrepCard(game, group)
    local graphics = love.graphics
    local rect = getInputPrepCardRect(game, group.edge, #(group.trains or {}))
    local rowHeight = 34
    local rowGap = 10
    local rowCount = #(group.trains or {})
    local totalRowsHeight = rowCount > 0 and (rowCount * rowHeight) + ((rowCount - 1) * rowGap) or 0
    local rowY = rect.y + math.floor((rect.h - totalRowsHeight) * 0.5 + 0.5)

    drawMetalPanel(rect, 0.96)

    if rowCount == 0 then
        love.graphics.setFont(game.fonts.small)
        graphics.setColor(0.84, 0.88, 0.92, 1)
        graphics.printf("No scheduled trains.", rect.x + 16, rect.y + 14, rect.w - 32, "center")
        return
    end

    for _, train in ipairs(group.trains or {}) do
        local rowWidth = getPrepTrainRowWidth(game, train)
        local rowRect = {
            x = math.floor(rect.x + (rect.w - rowWidth) * 0.5 + 0.5),
            y = rowY,
            w = rowWidth,
            h = rowHeight,
        }
        local startText = formatSecondsLabel(train.spawnTime or 0)
        local deadlineText = train.deadline ~= nil and formatSecondsLabel(train.deadline) or nil
        drawTrainRow(game, rowRect, startText, deadlineText, train)
        rowY = rowY + rowHeight + rowGap
    end
end

function drawInputLiveCard(game, edge, train)
    local graphics = love.graphics
    local rect = getInputLiveCardRect(game, edge, train)
    local remainingSeconds = math.max(0, (train.spawnTime or 0) - (game.world.elapsedTime or 0))

    drawMetalPanel(rect, 0.96)
    drawTrainRow(
        game,
        {
            x = math.floor(rect.x + 10),
            y = math.floor(rect.y + 10),
            w = rect.w - 20,
            h = 34,
        },
        formatSecondsLabel(remainingSeconds),
        train.deadline ~= nil and formatSecondsLabel(train.deadline) or nil,
        train
    )
end

function drawOutputBadge(game, badge)
    local graphics = love.graphics
    local rect = getOutputBadgeRect(game, badge.edge, badge)
    local ratioText = string.format("%d / %d", badge.deliveredCount or 0, badge.expectedCount or 0)

    drawMetalPanel(rect, 0.96)

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.48, 0.92, 0.62, 1)
    graphics.printf(ratioText, rect.x, rect.y + math.floor((rect.h - game.fonts.body:getHeight()) * 0.5 + 0.5), rect.w, "center")
end

function getPrepTrainHoverInfo(game, x, y)
    local inputGroups = game.world:getInputEdgeGroups()

    for _, group in ipairs(inputGroups) do
        local rect = getInputPrepCardRect(game, group.edge, #(group.trains or {}), inputGroups)
        local rowHeight = 34
        local rowGap = 10
        local rowCount = #(group.trains or {})
        local totalRowsHeight = rowCount > 0 and (rowCount * rowHeight) + ((rowCount - 1) * rowGap) or 0
        local rowY = rect.y + math.floor((rect.h - totalRowsHeight) * 0.5 + 0.5)

        for _, train in ipairs(group.trains or {}) do
            local rowWidth = getPrepTrainRowWidth(game, train)
            local rowRect = {
                x = math.floor(rect.x + (rect.w - rowWidth) * 0.5 + 0.5),
                y = rowY,
                w = rowWidth,
                h = rowHeight,
            }
            local startText = formatSecondsLabel(train.spawnTime or 0)
            local deadlineText = train.deadline ~= nil and formatSecondsLabel(train.deadline) or nil
            local layout = getPrepTrainRowLayout(game, rowRect, startText, deadlineText, train)

            if pointInRect(x, y, layout.leadRect) then
                return {
                    x = layout.leadRect.x + layout.leadRect.w * 0.5,
                    y = rowRect.y + rowRect.h,
                    preferBelow = true,
                    title = "Start Time",
                    text = "This is when the train enters the map from this line.",
                }
            end

            if layout.deadline and pointInRect(x, y, layout.deadline.rect) then
                return {
                    x = layout.deadline.rect.x + layout.deadline.rect.w * 0.5,
                    y = rowRect.y + rowRect.h,
                    preferBelow = true,
                    title = "Deadline",
                    text = "This is the latest time the train can arrive without counting as late.",
                }
            end

            if pointInRect(x, y, layout.previewRect) then
                local colorLabel = formatTooltipColorLabel(train.goalColor or train.trainColor)
                return {
                    x = layout.previewRect.x + layout.previewRect.w * 0.5,
                    y = rowRect.y + rowRect.h,
                    preferBelow = true,
                    title = "Wagons & Color",
                    text = string.format(
                        "Shows how long the train is. The %s color also tells you which matching exit it needs to reach.",
                        colorLabel
                    ),
                }
            end

            rowY = rowY + rowHeight + rowGap
        end
    end

    return nil
end

function getOutputBadgeHoverInfo(game, x, y)
    for _, badge in ipairs(game.world:getOutputBadgeGroups()) do
        local rect = getOutputBadgeRect(game, badge.edge, badge)
        if pointInRect(x, y, rect) then
            return {
                x = rect.x + rect.w * 0.5,
                y = rect.y,
                title = "Expected Trains",
                text = string.format(
                    "Shows how many trains this exit expects based on the %s color routes assigned to this line.",
                    formatColorList(badge.acceptedColors)
                ),
            }
        end
    end

    return nil
end

function getJunctionHoverInfo(game, x, y)
    for _, junction in ipairs(game.world.junctionOrder or {}) do
        if game.world:isCrossingHit(junction, x, y) then
            return {
                x = junction.mergePoint.x,
                y = junction.mergePoint.y - junction.crossingRadius,
                title = getJunctionTooltipTitle(junction),
                text = getJunctionTooltipText(junction),
            }
        end
    end

    return nil
end

function getOutputSelectorHoverInfo(game, x, y)
    for _, junction in ipairs(game.world.junctionOrder or {}) do
        if game.world:isOutputSelectorHit(junction, x, y) then
            return getOutputSelectorTooltipInfo(junction)
        end
    end

    return nil
end

function getTrackSectionHoverInfo(game, x, y)
    local bestDistanceSquared = 14 * 14
    local bestInfo = nil

    for _, edge in pairs(game.world.edges or {}) do
        for _, section in ipairs(edge.styleSections or {}) do
            local roadTypeId = roadTypes.normalizeRoadType(section.roadType)
            if roadTypeId ~= roadTypes.DEFAULT_ID then
                for _, segment in ipairs(edge.path and edge.path.segments or {}) do
                    if segment.length > 0 then
                        local overlapStart = math.max(section.startDistance or 0, segment.startDistance or 0)
                        local overlapEnd = math.min(
                            section.endDistance or 0,
                            (segment.startDistance or 0) + (segment.length or 0)
                        )
                        if overlapEnd > overlapStart + 0.0001 then
                            local startRatio = (overlapStart - segment.startDistance) / segment.length
                            local endRatio = (overlapEnd - segment.startDistance) / segment.length
                            local sectionStartX = lerp(segment.a.x, segment.b.x, startRatio)
                            local sectionStartY = lerp(segment.a.y, segment.b.y, startRatio)
                            local sectionEndX = lerp(segment.a.x, segment.b.x, endRatio)
                            local sectionEndY = lerp(segment.a.y, segment.b.y, endRatio)
                            local distanceSquared, closestX, closestY = distanceSquaredToSegment(
                                x,
                                y,
                                sectionStartX,
                                sectionStartY,
                                sectionEndX,
                                sectionEndY
                            )
                            if distanceSquared <= bestDistanceSquared then
                                bestDistanceSquared = distanceSquared
                                bestInfo = getSpeedTooltipInfo(roadTypeId, closestX, closestY)
                            end
                        end
                    end
                end
            end
        end
    end

    return bestInfo
end

function ui.getPlayHoverInfoAt(game, x, y)
    if not game or game.playPhase ~= "prepare" or not game.world then
        return nil
    end

    return getPrepTrainHoverInfo(game, x, y)
        or getOutputBadgeHoverInfo(game, x, y)
        or getOutputSelectorHoverInfo(game, x, y)
        or getJunctionHoverInfo(game, x, y)
        or getTrackSectionHoverInfo(game, x, y)
end

function ui.getPlayBackHit(game, x, y)
    return pointInRect(x, y, getPlayBackRect(game))
end

function ui.getPlayStartHit(game, x, y)
    if game.playPhase ~= "prepare" then
        return false
    end

    return pointInRect(x, y, getPlayStartRect())
end

function ui.getPlayHeaderHintLines(game)
    local backLabel = getRunBackLabel(game)
    if game and game.playPhase == "prepare" then
        return {
            "F2 Help",
            "F3 Debug",
            string.format("M %s", backLabel),
            "E Editor",
            "R Reset Prep",
        }
    end

    return {
        "F2 Help",
        "F3 Debug",
        string.format("M %s", backLabel),
        "E Editor",
        "R Restart",
    }
end

function getResultsButtonRects(game)
    local widths = {
        replay = 112,
        leaderboard = 112,
        editor = 112,
        menu = game and game.currentRunOrigin == "editor" and 154 or 132,
    }
    local gap = 16
    local totalWidth = widths.replay + widths.leaderboard + widths.editor + widths.menu + (gap * 3)
    local panelX = math.floor((game.viewport.w - totalWidth) * 0.5 + 0.5)
    local buttonY = game.viewport.h - 72
    return {
        replay = { x = panelX, y = buttonY, w = widths.replay, h = 42 },
        leaderboard = { x = panelX + widths.replay + gap, y = buttonY, w = widths.leaderboard, h = 42 },
        editor = { x = panelX + widths.replay + widths.leaderboard + (gap * 2), y = buttonY, w = widths.editor, h = 42 },
        menu = {
            x = panelX + widths.replay + widths.leaderboard + widths.editor + (gap * 3),
            y = buttonY,
            w = widths.menu,
            h = 42,
        },
    }
end

function ui.getResultsPanelRect(game)
    return {
        x = game.viewport.w * 0.5 - 300,
        y = 50,
        w = 600,
        h = 580,
    }
end

function ui.getResultsBreakdownRowRects(game)
    local panel = ui.getResultsPanelRect(game)
    local breakdownX = panel.x + 58
    local valueX = panel.x + panel.w - 58
    local rows = {}
    local lineY = panel.y + 220

    for index = 1, 5 do
        rows[index] = {
            label = {
                x = breakdownX,
                y = lineY,
                w = math.max(0, valueX - breakdownX - 150),
                h = 24,
            },
            value = {
                x = valueX - 140,
                y = lineY,
                w = 140,
                h = 24,
            },
            row = {
                x = breakdownX,
                y = lineY - 2,
                w = valueX - breakdownX,
                h = 26,
            },
        }
        lineY = lineY + 28
    end

    return rows
end

function ui.getResultsHit(game, x, y)
    local buttons = getResultsButtonRects(game)
    if pointInRect(x, y, buttons.replay) then
        return "replay"
    end
    if pointInRect(x, y, buttons.leaderboard) then
        return "leaderboard"
    end
    if pointInRect(x, y, buttons.menu) then
        return "menu"
    end
    if pointInRect(x, y, buttons.editor) then
        return "editor"
    end
    return nil
end

function ui.getResultsHoverInfoAt(game, x, y)
    local summary = game.resultsSummary or {}
    local rowRects = ui.getResultsBreakdownRowRects(game)
    local onTimeRow = rowRects[1]
    if not onTimeRow or not pointInRect(x, y, onTimeRow.row) then
        return nil
    end

    local lossBreakdown = summary.onTimePointLossBreakdown or {}
    local lateLoss = lossBreakdown.lateClears or 0
    local wrongDestinationLoss = lossBreakdown.wrongDestinations or 0
    local unfinishedLoss = lossBreakdown.unfinished or 0
    local lines = {
        string.format(
            "Correct routing: +%s",
            formatScore((summary.scoreBreakdown and summary.scoreBreakdown.onTimeClears) or 0)
        ),
    }

    if lateLoss > 0 then
        lines[#lines + 1] = string.format("Late arrivals: -%s", formatScore(lateLoss))
    end

    if wrongDestinationLoss > 0 then
        lines[#lines + 1] = string.format("Wrong destinations: -%s", formatScore(wrongDestinationLoss))
    end

    if unfinishedLoss > 0 then
        lines[#lines + 1] = string.format("Unfinished trains: -%s", formatScore(unfinishedLoss))
    end

    return {
        title = "On-Time Points",
        text = table.concat(lines, "\n"),
        x = onTimeRow.row.x + (onTimeRow.row.w * 0.5),
        y = onTimeRow.row.y + onTimeRow.row.h,
        preferBelow = true,
    }
end

function drawPlayGuideOverlay(game)
    local layout = getAnimatedPlayGuideLayout(game)
    if not layout then
        return
    end

    local graphics = love.graphics
    local tooltip = layout.tooltipRect
    local outerRadius = math.max(8, math.min(20, math.min(tooltip.w, tooltip.h) * 0.35))
    local glowRadius = math.max(outerRadius + 3, math.min(24, outerRadius + 5))
    local innerInset = math.min(4, math.min(tooltip.w, tooltip.h) * 0.18)
    local innerRadius = math.max(4, outerRadius - innerInset)

    graphics.stencil(function()
        for _, shape in ipairs(layout.focusShapes or {}) do
            drawGuideFocusShape(shape)
        end
    end, "replace", 1)
    graphics.setStencilTest("equal", 0)
    graphics.setColor(0.01, 0.02, 0.03, 0.74)
    graphics.rectangle("fill", 0, 0, game.viewport.w, game.viewport.h)
    graphics.setStencilTest()

    for _, shape in ipairs(layout.focusShapes or {}) do
        graphics.setColor(0.48, 0.92, 0.98, 0.14 * (layout.outlineAlpha or 1))
        graphics.setLineWidth(10)
        drawGuideFocusOutline(shape)
        graphics.setColor(0.72, 0.97, 1, 0.98 * (layout.outlineAlpha or 1))
        graphics.setLineWidth(3)
        drawGuideFocusOutline(shape)
    end
    graphics.setLineWidth(1)

    graphics.setColor(0.16, 0.44, 0.54, 0.2 * (layout.tooltipAlpha or 1))
    graphics.rectangle("fill", tooltip.x - 8, tooltip.y - 8, tooltip.w + 16, tooltip.h + 16, glowRadius, glowRadius)
    graphics.setColor(0.06, 0.08, 0.11, 0.99 * (layout.tooltipAlpha or 1))
    graphics.rectangle("fill", tooltip.x, tooltip.y, tooltip.w, tooltip.h, outerRadius, outerRadius)
    graphics.setColor(0.68, 0.94, 1, 1 * (layout.tooltipAlpha or 1))
    graphics.setLineWidth(3)
    graphics.rectangle("line", tooltip.x, tooltip.y, tooltip.w, tooltip.h, outerRadius, outerRadius)
    graphics.setColor(0.32, 0.52, 0.64, 0.7 * (layout.tooltipAlpha or 1))
    graphics.setLineWidth(1)
    graphics.rectangle(
        "line",
        tooltip.x + innerInset,
        tooltip.y + innerInset,
        tooltip.w - innerInset * 2,
        tooltip.h - innerInset * 2,
        innerRadius,
        innerRadius
    )

    if (layout.contentAlpha or 0) > 0.01 then
        love.graphics.setFont(game.fonts.small)
        graphics.setColor(0.97, 0.98, 1, layout.contentAlpha or 1)
        graphics.printf(
            layout.step.text,
            tooltip.x + PLAY_GUIDE_LAYOUT.paddingX,
            tooltip.y + PLAY_GUIDE_LAYOUT.paddingY,
            tooltip.w - PLAY_GUIDE_LAYOUT.paddingX * 2,
            "left"
        )
    end

    if (layout.buttonAlpha or 0) > 0.01 then
        local buttonFillScale = layout.buttonAlpha or 1
        if layout.skipRect then
            drawButton(
                layout.skipRect,
                layout.skipLabel,
                { 0.11, 0.14, 0.18, 0.98 * buttonFillScale },
                { 0.34, 0.4, 0.48, 1 * buttonFillScale },
                game.fonts.small,
                false,
                buttonFillScale
            )
        end
        drawButton(
            layout.nextRect,
            layout.nextLabel,
            { 0.12, 0.17, 0.2, 0.98 * buttonFillScale },
            { 0.48, 0.92, 0.62, 1 * buttonFillScale },
            game.fonts.small,
            false,
            buttonFillScale
        )
    end
end

end
