local junctionControls = require("src.game.junction_controls")

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

function pointInRect(x, y, rect)
    return x >= rect.x
        and x <= rect.x + rect.w
        and y >= rect.y
        and y <= rect.y + rect.h
end

function distanceSquaredToSegment(px, py, ax, ay, bx, by)
    local dx = bx - ax
    local dy = by - ay
    local lengthSquared = dx * dx + dy * dy
    if lengthSquared <= 0.0001 then
        local offsetX = px - ax
        local offsetY = py - ay
        return (offsetX * offsetX) + (offsetY * offsetY), ax, ay
    end

    local t = math.max(0, math.min(1, (((px - ax) * dx) + ((py - ay) * dy)) / lengthSquared))
    local closestX = ax + dx * t
    local closestY = ay + dy * t
    local offsetX = px - closestX
    local offsetY = py - closestY
    return (offsetX * offsetX) + (offsetY * offsetY), closestX, closestY
end

function lerp(a, b, t)
    return a + ((b - a) * t)
end

function trim(value)
    return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function safeUiText(value, fallback)
    local text = tostring(value or "")
    if text == "" then
        return fallback or ""
    end

    if utf8 and utf8.len then
        local isValidUtf8 = pcall(utf8.len, text)
        if isValidUtf8 then
            return text
        end
    end

    -- Keep output ASCII-only when input bytes are invalid UTF-8.
    return text:gsub("[^\r\n\t -~]", "?")
end

function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function angleBetweenPoints(a, b)
    local dx = (b and b.x or 0) - (a and a.x or 0)
    local dy = (b and b.y or 0) - (a and a.y or 0)
    if math.atan2 then
        return math.atan2(dy, dx)
    end

    if dx == 0 then
        if dy >= 0 then
            return math.pi * 0.5
        end
        return -math.pi * 0.5
    end

    local angle = math.atan(dy / dx)
    if dx < 0 then
        angle = angle + math.pi
    end
    return angle
end

function drawButton(rect, label, fillColor, strokeColor, font, isDisabled, labelAlpha)
    local graphics = love.graphics
    graphics.setColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 1)
    graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 16, 16)
    graphics.setColor(strokeColor[1], strokeColor[2], strokeColor[3], strokeColor[4] or 1)
    graphics.setLineWidth(2)
    graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 16, 16)
    love.graphics.setFont(font)
    local textAlpha = labelAlpha or 1
    if isDisabled then
        graphics.setColor(0.54, 0.58, 0.62, textAlpha)
    else
        graphics.setColor(0.97, 0.98, 1, textAlpha)
    end
    graphics.printf(label, rect.x, rect.y + math.floor((rect.h - font:getHeight()) * 0.5 + 0.5), rect.w, "center")
    graphics.setLineWidth(1)
end

function getWrappedLineCount(font, text, width)
    local firstValue, secondValue = font:getWrap(text, width)
    if type(firstValue) == "table" then
        return math.max(1, #firstValue)
    end
    if type(secondValue) == "table" then
        return math.max(1, #secondValue)
    end
    return 1
end

function drawProfileModeTooltip(game, rect, text)
    if not rect or not text or text == "" then
        return
    end

    local graphics = love.graphics
    local maxTextWidth = PROFILE_MODE_TOOLTIP_LAYOUT.maxWidth - (PROFILE_MODE_TOOLTIP_LAYOUT.paddingX * 2)
    local lineCount = getWrappedLineCount(game.fonts.small, text, maxTextWidth)
    local tooltipWidth = PROFILE_MODE_TOOLTIP_LAYOUT.maxWidth
    local tooltipHeight = (lineCount * game.fonts.small:getHeight()) + (PROFILE_MODE_TOOLTIP_LAYOUT.paddingY * 2)
    local tooltipX = math.floor(rect.x + (rect.w - tooltipWidth) * 0.5 + 0.5)
    local tooltipY = math.floor(rect.y - tooltipHeight - PROFILE_MODE_TOOLTIP_LAYOUT.gap + 0.5)

    graphics.setColor(0.08, 0.1, 0.14, 0.98)
    graphics.rectangle(
        "fill",
        tooltipX,
        tooltipY,
        tooltipWidth,
        tooltipHeight,
        PROFILE_MODE_TOOLTIP_LAYOUT.cornerRadius,
        PROFILE_MODE_TOOLTIP_LAYOUT.cornerRadius
    )
    graphics.setColor(0.28, 0.4, 0.52, 1)
    graphics.setLineWidth(2)
    graphics.rectangle(
        "line",
        tooltipX,
        tooltipY,
        tooltipWidth,
        tooltipHeight,
        PROFILE_MODE_TOOLTIP_LAYOUT.cornerRadius,
        PROFILE_MODE_TOOLTIP_LAYOUT.cornerRadius
    )
    graphics.setLineWidth(1)

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.58, 0.64, 0.7, 1)
    graphics.printf(
        text,
        tooltipX + PROFILE_MODE_TOOLTIP_LAYOUT.paddingX,
        tooltipY + PROFILE_MODE_TOOLTIP_LAYOUT.paddingY,
        tooltipWidth - (PROFILE_MODE_TOOLTIP_LAYOUT.paddingX * 2),
        "center"
    )
end

function formatScore(value)
    local formatted = string.format("%.2f", value or 0)
    formatted = formatted:gsub("(%..-)0+$", "%1")
    formatted = formatted:gsub("%.$", "")
    return formatted
end

function formatLeaderboardScore(value)
    return string.format("%." .. tostring(LEADERBOARD_SCORE_DECIMAL_PLACES) .. "f", value or 0)
end

function formatLeaderboardEntryTimestamp(value)
    if type(value) == "number" then
        return os.date("%Y-%m-%d %H:%M", value)
    end

    local text = trim(tostring(value or ""))
    if text == "" then
        return "Unknown"
    end

    local numericValue = tonumber(text)
    if numericValue then
        return os.date("%Y-%m-%d %H:%M", numericValue)
    end

    local year, month, day, hour, minute = text:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)[Tt%s](%d%d):(%d%d)")
    if year and month and day and hour and minute then
        return string.format("%s-%s-%s %s:%s", year, month, day, hour, minute)
    end

    local dateOnlyYear, dateOnlyMonth, dateOnlyDay = text:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    if dateOnlyYear and dateOnlyMonth and dateOnlyDay then
        return string.format("%s-%s-%s", dateOnlyYear, dateOnlyMonth, dateOnlyDay)
    end

    return safeUiText(text, "Unknown")
end

function getNowSeconds()
    if love and love.timer and love.timer.getTime then
        return love.timer.getTime()
    end

    return os.clock()
end

function getNowUnixSeconds()
    if os and os.time then
        return os.time()
    end

    return math.floor(getNowSeconds())
end

function truncateText(text, maxCharacters)
    local resolvedText = tostring(text or "")
    local resolvedMaxCharacters = math.max(0, maxCharacters or 0)

    if resolvedText == "" then
        return resolvedText
    end

    if utf8 and utf8.len and utf8.offset then
        local characterCount = utf8.len(resolvedText)
        if characterCount and characterCount > resolvedMaxCharacters then
            local endByte = utf8.offset(resolvedText, resolvedMaxCharacters + 1)
            if endByte then
                return resolvedText:sub(1, endByte - 1)
            end
        end
        return resolvedText
    end

    if #resolvedText > resolvedMaxCharacters then
        return resolvedText:sub(1, resolvedMaxCharacters)
    end

    return resolvedText
end

function formatLevelSelectLeaderboardPlayerName(value)
    local displayName = tostring(value or "Unknown")
    if displayName == "" then
        displayName = "Unknown"
    end
    return truncateText(displayName, LEVEL_SELECT_LEADERBOARD_PLAYER_NAME_MAX_CHARACTERS)
end

function formatLoadingLabel(baseLabel, animationTime)
    local resolvedAnimationTime = animationTime or getNowSeconds()
    local animationFrame = math.floor(resolvedAnimationTime / REFRESH_LOADING_ANIMATION_STEP_SECONDS) % REFRESH_LOADING_ANIMATION_FRAME_COUNT
    return baseLabel .. string.rep(".", animationFrame + 1)
end

function formatLeaderboardRefreshLabel(nextRefreshAt, nowSeconds, isLoading, animationTime)
    if isLoading then
        return formatLoadingLabel("Refreshing", animationTime)
    end

    local resolvedNowSeconds = nowSeconds or getNowSeconds()
    if type(nextRefreshAt) ~= "number" then
        return "Refresh in 0s"
    end

    local remainingSeconds = math.max(0, math.ceil(nextRefreshAt - resolvedNowSeconds))
    return string.format("Refresh in %ds", remainingSeconds)
end

function formatLevelSelectLeaderboardRefreshLabel(nextRefreshAt, nowUnixSeconds, isLoading, animationTime)
    return formatLeaderboardRefreshLabel(nextRefreshAt, nowUnixSeconds or getNowUnixSeconds(), isLoading, animationTime)
end

function drawMetalPanel(rect, innerAlpha)
    local graphics = love.graphics
    local alpha = innerAlpha or 0.98

    graphics.setColor(PANEL_COLORS.panelFill[1], PANEL_COLORS.panelFill[2], PANEL_COLORS.panelFill[3], alpha)
    graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 20, 20)
    graphics.setLineWidth(3)
    graphics.setColor(PANEL_COLORS.panelLine[1], PANEL_COLORS.panelLine[2], PANEL_COLORS.panelLine[3], 1)
    graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 20, 20)
    graphics.setColor(PANEL_COLORS.panelInnerLine[1], PANEL_COLORS.panelInnerLine[2], PANEL_COLORS.panelInnerLine[3], PANEL_COLORS.panelInnerLine[4])
    graphics.rectangle("line", rect.x + 4, rect.y + 4, rect.w - 8, rect.h - 8, 17, 17)
    graphics.setLineWidth(1)
end

function drawLoadingSpinner(centerX, centerY, color)
    local graphics = love.graphics
    local tint = color or { 0.48, 0.92, 0.62, 1 }
    local startAngle = (love.timer.getTime() or 0) * LEADERBOARD_LOADING.spinnerSpeed
    local endAngle = startAngle + LEADERBOARD_LOADING.spinnerArcLength

    graphics.setColor(tint[1], tint[2], tint[3], tint[4] or 1)
    graphics.setLineWidth(LEADERBOARD_LOADING.spinnerThickness)
    graphics.arc("line", "open", centerX, centerY, LEADERBOARD_LOADING.spinnerRadius, startAngle, endAngle)
    graphics.setLineWidth(1)
end

function drawLeaderboardRefreshIndicator(game, panel, state)
    local graphics = love.graphics
    local label = state and state.refreshLabel or formatLeaderboardRefreshLabel(
        state and state.nextRefreshAt or nil,
        getNowSeconds(),
        state and state.status == "loading" or false,
        getNowSeconds()
    )
    local textWidth = game.fonts.small:getWidth(label)
    local textX = panel.x + panel.w - LEADERBOARD_REFRESH_INDICATOR_RIGHT_PADDING - textWidth
    local textY = panel.y + panel.h - LEADERBOARD_REFRESH_INDICATOR_BOTTOM_PADDING - game.fonts.small:getHeight()

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.68, 0.74, 0.8, 1)
    graphics.print(label, textX, textY)
end

function drawLevelSelectLeaderboardRefreshIndicator(game, contentRect, previewState)
    local graphics = love.graphics
    local label = previewState and previewState.refreshLabel or formatLevelSelectLeaderboardRefreshLabel(
        previewState and previewState.nextRefreshAt or nil,
        getNowUnixSeconds(),
        previewState and previewState.isLoading or false,
        getNowSeconds()
    )
    local textWidth = game.fonts.small:getWidth(label)
    local textX = contentRect.x + contentRect.w - LEVEL_SELECT_LEADERBOARD_CARD.refreshPaddingRight - textWidth
    local textY = contentRect.y + contentRect.h - LEVEL_SELECT_LEADERBOARD_CARD.refreshPaddingBottom - game.fonts.small:getHeight()

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(PANEL_COLORS.mutedText[1], PANEL_COLORS.mutedText[2], PANEL_COLORS.mutedText[3], PANEL_COLORS.mutedText[4])
    graphics.print(label, textX, textY)
end

function getLeaderboardPanelRect(game)
    return {
        x = LEADERBOARD_LAYOUT.panelX,
        y = LEADERBOARD_LAYOUT.panelY,
        w = game.viewport.w - LEADERBOARD_LAYOUT.panelMargin,
        h = game.viewport.h - 148,
    }
end

function shouldShowLeaderboardMapColumn(game)
    local state = game.leaderboardState or {}
    return state.scope == "global"
end

function formatLeaderboardRecordedAt(value)
    local timestamp = tonumber(value)
    if timestamp then
        return os.date("%Y-%m-%d %H:%M", timestamp)
    end

    local text = tostring(value or "")
    return text ~= "" and text or "Unknown"
end

function getLeaderboardContentLayout(game)
    local panel = getLeaderboardPanelRect(game)
    local contentX = panel.x + LEADERBOARD_LAYOUT.contentPadding
    local contentW = panel.w - (LEADERBOARD_LAYOUT.contentPadding * 2)
    local recordX = contentX + contentW - LEADERBOARD_LAYOUT.recordWidth - LEADERBOARD_LAYOUT.recordRightPadding
    local scoreX = contentX + math.floor((contentW - LEADERBOARD_LAYOUT.scoreWidth - LEADERBOARD_LAYOUT.recordWidth - LEADERBOARD_LAYOUT.recordGap) * 0.5 + 0.5)
    local mapX = scoreX + LEADERBOARD_LAYOUT.scoreWidth + LEADERBOARD_LAYOUT.mapGap
    local mapWidth = math.max(LEADERBOARD_LAYOUT.mapMinWidth, recordX - mapX - LEADERBOARD_LAYOUT.recordGap)
    local playerX = contentX + LEADERBOARD_LAYOUT.playerXOffset
    local playerRightEdge = shouldShowLeaderboardMapColumn(game)
        and (mapX - LEADERBOARD_LAYOUT.mapGap)
        or scoreX
    local playerWidth = playerRightEdge - playerX - LEADERBOARD_LAYOUT.playerRightPadding

    return {
        panel = panel,
        contentX = contentX,
        contentW = contentW,
        mapX = mapX,
        mapWidth = mapWidth,
        recordX = recordX,
        scoreX = scoreX,
        playerX = playerX,
        playerWidth = playerWidth,
    }
end

function getLeaderboardFilterBadgeRect(game)
    local panel = getLeaderboardPanelRect(game)
    local filterText = game.leaderboardMapUuid
        and string.format("Current Map: %s", game:getMapNameByUuid(game.leaderboardMapUuid))
        or "All Maps"
    local badgeWidth = math.min(
        LEADERBOARD_LAYOUT.filterBadgeMaxWidth,
        game.fonts.small:getWidth(filterText) + (LEADERBOARD_LAYOUT.filterBadgePaddingX * 2)
    )

    return {
        x = panel.x + math.floor((panel.w - badgeWidth) * 0.5 + 0.5),
        y = panel.y + LEADERBOARD_LAYOUT.filterBadgeY,
        w = badgeWidth,
        h = LEADERBOARD_LAYOUT.filterBadgeHeight,
        text = filterText,
    }
end

function buildLeaderboardRowRects(game, entries)
    local layout = getLeaderboardContentLayout(game)
    local rects = {}
    local rowHeight = LEADERBOARD_LAYOUT.rowHeight
    local rowStep = rowHeight + LEADERBOARD_LAYOUT.rowGap
    local availableHeight = layout.panel.h - LEADERBOARD_LAYOUT.headerY - LEADERBOARD_LAYOUT.rowYOffset - LEADERBOARD_LAYOUT.rowBottomPadding
    local maxEntries = math.min(
        LEADERBOARD_LAYOUT.maxVisibleRows,
        #(entries or {}),
        math.max(1, math.floor((availableHeight + LEADERBOARD_LAYOUT.rowGap) / rowStep))
    )
    local rowY = layout.panel.y + LEADERBOARD_LAYOUT.headerY + LEADERBOARD_LAYOUT.rowYOffset

    for index = 1, maxEntries do
        local entry = entries[index]
        local rowRect = {
            entry = entry,
            row = {
                x = layout.contentX,
                y = rowY - 6,
                w = layout.contentW,
                h = rowHeight,
            },
            player = {
                x = layout.playerX,
                y = rowY,
                w = layout.playerWidth,
                h = rowHeight - 8,
            },
            map = shouldShowLeaderboardMapColumn(game) and {
                x = layout.mapX,
                y = rowY,
                w = layout.mapWidth,
                h = rowHeight - 8,
            } or nil,
            record = {
                x = layout.recordX,
                y = rowY,
                w = LEADERBOARD_LAYOUT.recordWidth,
                h = rowHeight - 8,
            },
        }

        rects[#rects + 1] = rowRect
        rowY = rowY + rowStep
    end

    return rects
end

function drawLeaderboardTooltip(game, hoverInfo)
    if not hoverInfo or not hoverInfo.text or hoverInfo.text == "" then
        return
    end

    local graphics = love.graphics
    local tooltipX = math.min(game.viewport.w - LEADERBOARD_LAYOUT.tooltipWidth - 24, math.max(24, hoverInfo.x - (LEADERBOARD_LAYOUT.tooltipWidth * 0.5)))
    local tooltipY = math.min(game.viewport.h - LEADERBOARD_LAYOUT.tooltipHeight - 24, hoverInfo.y + LEADERBOARD_LAYOUT.tooltipOffsetY)

    graphics.setColor(0.06, 0.08, 0.12, 0.98)
    graphics.rectangle("fill", tooltipX, tooltipY, LEADERBOARD_LAYOUT.tooltipWidth, LEADERBOARD_LAYOUT.tooltipHeight, 14, 14)
    graphics.setColor(0.32, 0.42, 0.52, 1)
    graphics.rectangle("line", tooltipX, tooltipY, LEADERBOARD_LAYOUT.tooltipWidth, LEADERBOARD_LAYOUT.tooltipHeight, 14, 14)

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.84, 0.88, 0.92, 1)
    graphics.printf(hoverInfo.label, tooltipX + 16, tooltipY + 10, LEADERBOARD_LAYOUT.tooltipWidth - 32, "left")
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf(hoverInfo.text, tooltipX + 16, tooltipY + 28, LEADERBOARD_LAYOUT.tooltipWidth - 32, "left")
end

function drawPlayTooltip(game, hoverInfo)
    if not hoverInfo or not hoverInfo.title or hoverInfo.title == "" or not hoverInfo.text or hoverInfo.text == "" then
        return
    end

    local graphics = love.graphics
    local width = PLAY_TOOLTIP_LAYOUT.width
    local contentWidth = width - (PLAY_TOOLTIP_LAYOUT.paddingX * 2)
    local titleLineCount = getWrappedLineCount(game.fonts.body, hoverInfo.title, contentWidth)
    local bodyLineCount = getWrappedLineCount(game.fonts.small, hoverInfo.text, contentWidth)
    local titleHeight = titleLineCount * game.fonts.body:getHeight()
    local bodyHeight = bodyLineCount * game.fonts.small:getHeight()
    local height = (PLAY_TOOLTIP_LAYOUT.paddingY * 2)
        + titleHeight
        + bodyHeight
        + (PLAY_TOOLTIP_LAYOUT.dividerGap * 2)
        + 1
    local tooltipX = clamp(
        math.floor((hoverInfo.x or 0) - (width * 0.5) + 0.5),
        18,
        game.viewport.w - width - 18
    )
    local preferredY = math.floor((hoverInfo.y or 0) - height - PLAY_TOOLTIP_LAYOUT.gap + 0.5)
    local fallbackY = math.floor((hoverInfo.y or 0) + PLAY_TOOLTIP_LAYOUT.gap + 0.5)
    local tooltipY
    if hoverInfo.preferBelow then
        tooltipY = fallbackY <= (game.viewport.h - height - 24) and fallbackY or preferredY
    else
        tooltipY = preferredY >= 82 and preferredY or fallbackY
    end
    tooltipY = clamp(tooltipY, 82, game.viewport.h - height - 24)

    graphics.setColor(0.06, 0.08, 0.12, 0.98)
    graphics.rectangle("fill", tooltipX, tooltipY, width, height, PLAY_TOOLTIP_LAYOUT.cornerRadius, PLAY_TOOLTIP_LAYOUT.cornerRadius)
    graphics.setColor(0.32, 0.42, 0.52, 1)
    graphics.setLineWidth(2)
    graphics.rectangle("line", tooltipX, tooltipY, width, height, PLAY_TOOLTIP_LAYOUT.cornerRadius, PLAY_TOOLTIP_LAYOUT.cornerRadius)
    graphics.setLineWidth(1)

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf(
        hoverInfo.title,
        tooltipX + PLAY_TOOLTIP_LAYOUT.paddingX,
        tooltipY + PLAY_TOOLTIP_LAYOUT.paddingY,
        contentWidth,
        "left"
    )

    local dividerY = tooltipY + PLAY_TOOLTIP_LAYOUT.paddingY + titleHeight + PLAY_TOOLTIP_LAYOUT.dividerGap
    graphics.setColor(0.28, 0.4, 0.52, 0.92)
    graphics.line(
        tooltipX + PLAY_TOOLTIP_LAYOUT.paddingX,
        dividerY,
        tooltipX + width - PLAY_TOOLTIP_LAYOUT.paddingX,
        dividerY
    )

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.84, 0.88, 0.92, 1)
    graphics.printf(
        hoverInfo.text,
        tooltipX + PLAY_TOOLTIP_LAYOUT.paddingX,
        dividerY + PLAY_TOOLTIP_LAYOUT.dividerGap,
        contentWidth,
        "left"
    )
end

function getPlayInfoOverlayRect(game)
    return {
        x = game.viewport.w - PLAY_OVERLAY.margin - PLAY_OVERLAY.width,
        y = PLAY_OVERLAY.margin,
        w = PLAY_OVERLAY.width,
        h = game.viewport.h - PLAY_OVERLAY.margin * 2,
    }
end

function getJunctionRouteText(junction)
    local activeInput = junction.inputs[junction.activeInputIndex]
    local activeOutput = junction.outputs[junction.activeOutputIndex]
    return string.format(
        "%s -> %s",
        activeInput and activeInput.label or ("Input " .. tostring(junction.activeInputIndex)),
        activeOutput and activeOutput.label or ("Output " .. tostring(junction.activeOutputIndex))
    )
end

function getJunctionHelpText(junction)
    local control = junction.control or {}

    if control.type == "delayed" then
        return string.format("Click the junction to arm a %.1fs delayed swap.", control.delay or 0)
    end

    if control.type == "pump" then
        return string.format("Click the junction %d times before the charge drains.", control.target or 0)
    end

    if control.type == "spring" then
        return string.format("Click the junction to flip the route for %.1fs before it springs back.", control.holdTime or 0)
    end

    if control.type == "relay" then
        return "Click the junction to rotate the active input and output together."
    end

    if control.type == "trip" then
        return string.format("Click the junction to divert the next %d train(s), then reset automatically.", control.passCount or 1)
    end

    if control.type == "crossbar" then
        return "Click the junction to rotate linked crossing routes together."
    end

    return "Click the junction to switch the active input immediately."
end

function formatTooltipColorLabel(colorId)
    local text = tostring(colorId or "")
    if text == "" then
        return "unknown"
    end
    return text:sub(1, 1):upper() .. text:sub(2)
end

function formatColorList(colorIds)
    local labels = {}
    for _, colorId in ipairs(colorIds or {}) do
        labels[#labels + 1] = formatTooltipColorLabel(colorId)
    end

    if #labels == 0 then
        return "matching"
    end
    if #labels == 1 then
        return labels[1]
    end
    if #labels == 2 then
        return labels[1] .. " or " .. labels[2]
    end

    return table.concat(labels, ", ", 1, #labels - 1) .. ", or " .. labels[#labels]
end

function getJunctionTooltipTitle(junction)
    local controlType = junction and junction.control and junction.control.type or "direct"
    local titles = {
        direct = "Direct Junction",
        delayed = "Delay Junction",
        pump = "Charge Junction",
        spring = "Spring Junction",
        relay = "Relay Junction",
        trip = "Trip Junction",
        crossbar = "Crossbar Junction",
    }

    return titles[controlType] or "Junction"
end

function getJunctionTooltipText(junction)
    local control = junction.control or {}

    if control.type == "delayed" then
        return string.format("Arms a route change that triggers after %.1f seconds instead of switching immediately.", control.delay or 0)
    end
    if control.type == "pump" then
        return string.format("Needs %d clicks to charge before it swaps, then the charge drains over time.", control.target or 0)
    end
    if control.type == "spring" then
        return string.format("Flips the route for %.1f seconds, then springs back to its earlier setting.", control.holdTime or 0)
    end
    if control.type == "relay" then
        return "Rotates the active input and output together so the matching lanes stay linked."
    end
    if control.type == "trip" then
        return string.format("Diverts the next %d train(s), then resets itself automatically.", control.passCount or 1)
    end
    if control.type == "crossbar" then
        return "Rotates mirrored crossing routes together so both sides stay synchronized."
    end

    return "Switches to the next input as soon as you click it."
end

function getOutputSelectorTooltipInfo(junction)
    if not junctionControls.hasManualOutputSelector(junction) then
        return nil
    end

    local activeOutput = junction and junction.outputs and junction.outputs[junction.activeOutputIndex] or nil
    local outputLabel = activeOutput and activeOutput.label or ("Output " .. tostring(junction and junction.activeOutputIndex or 1))

    return {
        x = junction.mergePoint.x,
        y = junction.mergePoint.y + junction.crossingRadius,
        title = "Output Selector",
        text = string.format(
            "Controls which outgoing line is active. Left click to cycle forward, right click to cycle backward. Current route: %s.",
            outputLabel
        ),
    }
end

function getSpeedTooltipInfo(roadTypeId, x, y)
    local config = roadTypes.getConfig(roadTypeId)
    if not config or config.id == roadTypes.DEFAULT_ID then
        return nil
    end

    if config.id == "fast" then
        return {
            x = x,
            y = y,
            title = "Fast Section",
            text = "Trains move faster on this marked stretch, so they clear the track sooner.",
        }
    end

    if config.id == "slow" then
        return {
            x = x,
            y = y,
            title = "Slow Section",
            text = "Trains move slower on this marked stretch, so they stay on the track longer.",
        }
    end

    return {
        x = x,
        y = y,
        title = string.format("%s Section", config.label or "Track"),
        text = "This marked stretch changes how quickly trains move through it.",
    }
end

function getJunctionStateText(junction)
    local control = junction.control or {}

    if control.type == "delayed" then
        if control.armed then
            return string.format("State: armed, %.1fs left", control.remainingDelay or 0)
        end
        return string.format("State: idle, %.1fs delay", control.delay or 0)
    end

    if control.type == "pump" then
        return string.format("State: charge %d / %d", control.pumpCount or 0, control.target or 0)
    end

    if control.type == "spring" then
        if control.armed then
            return string.format("State: held, %.1fs left", control.remainingHold or 0)
        end
        return string.format("State: idle, %.1fs hold", control.holdTime or 0)
    end

    if control.type == "relay" then
        return string.format("State: synced output %d / %d", junction.activeOutputIndex or 1, math.max(1, #junction.outputs))
    end

    if control.type == "trip" then
        if control.remainingTrips and control.remainingTrips > 0 then
            return string.format("State: %d trip(s) remaining", control.remainingTrips)
        end
        return string.format("State: idle, next %d trip(s)", control.passCount or 1)
    end

    if control.type == "crossbar" then
        return string.format("State: crossed output %d / %d", junction.activeOutputIndex or 1, math.max(1, #junction.outputs))
    end

    return "State: instant switch"
end

function getTrainStatusText(worldState, train)
    if train.completed then
        return "cleared"
    end

    local currentEdge, occupiedEdges = worldState:getCurrentEdge(train)
    if not currentEdge then
        return "inactive"
    end

    if currentEdge.targetType == "junction" then
        local junction = worldState.junctions[currentEdge.targetId]
        local activeInput = junction and junction.inputs[junction.activeInputIndex] or nil
        if activeInput and activeInput.id ~= currentEdge.id then
            return string.format("waiting at %s", junction.label or currentEdge.targetId)
        end

        local localProgress = worldState:getHeadLocalProgress(train, occupiedEdges)
        return string.format("%s %.0f / %.0f", junction and (junction.label or junction.id) or currentEdge.targetId, localProgress, currentEdge.path.length)
    end

    return currentEdge.label or currentEdge.id
end

function buildPlayHelpSections(game)
    local backTarget = game.currentRunOrigin == "editor" and "editor" or "level select"
    local controlLines = {
        "Left click a junction to activate its control.",
        string.format("M returns to the %s. E opens the editor. R restarts the run.", backTarget),
        "F2 closes this help panel. F3 opens the debug panel.",
    }

    local hasManualSelector = false
    for _, junction in ipairs(game.world and game.world.junctionOrder or {}) do
        if junctionControls.hasManualOutputSelector(junction) then
            hasManualSelector = true
            break
        end
    end

    if hasManualSelector then
        table.insert(controlLines, 2, "Left click the selector below a junction to cycle outputs forward.")
        table.insert(controlLines, 3, "Right click the selector below a junction to cycle outputs backward.")
    end

    if game.playPhase == "prepare" then
        controlLines[#controlLines + 1] = "Use the Start button when your routes are set."
    end

    local sections = {
        {
            title = "Controls",
            lines = controlLines,
        },
        {
            title = "Junctions",
            lines = {},
        },
    }

    for _, junction in ipairs(game.world.junctionOrder or {}) do
        sections[2].lines[#sections[2].lines + 1] = string.format("%s | %s", junction.label, getJunctionRouteText(junction))
        sections[2].lines[#sections[2].lines + 1] = getJunctionHelpText(junction)
    end

    return sections
end

function buildPlayDebugSections(game)
    local currentMapDescriptor = game.currentMapDescriptor or {}
    local runSummary = game.world:getRunSummary()
    local nextTrain = game.world:getNextQueuedTrain()
    local nextDeadline = game.world:getNearestPendingDeadline()
    local sections = {
        {
            title = "Run Stats",
            lines = {
                string.format("Phase: %s", game.playPhase == "prepare" and "Preparation" or "Play"),
                string.format("Elapsed: %.1fs", game.world.elapsedTime or 0),
                game.world.timeRemaining and string.format("Time left: %.1fs", game.world.timeRemaining) or "Time left: Unlimited",
                string.format("Trains cleared: %d / %d", game.world:countCompletedTrains(), #game.world.trains),
                string.format("Interactions: %d", runSummary.interactionCount or 0),
                string.format("Score: %s", formatScore(runSummary.finalScore or 0)),
                {
                    text = string.format("Map UUID: %s", currentMapDescriptor.mapUuid or "n/a"),
                    copyValue = currentMapDescriptor.mapUuid,
                    copyLabel = "Map UUID",
                },
                {
                    text = string.format("Map Hash: %s", currentMapDescriptor.mapHash or "n/a"),
                    copyValue = currentMapDescriptor.mapHash,
                    copyLabel = "Map Hash",
                },
                nextTrain and string.format(
                    "Next spawn: %s at %.1fs",
                    game.world:getTrainSummary(nextTrain),
                    nextTrain.spawnTime or 0
                ) or "Next spawn: none",
                nextDeadline and string.format(
                    "Nearest deadline: %s by %.1fs",
                    game.world:getTrainSummary(nextDeadline),
                    nextDeadline.deadline or 0
                ) or "Nearest deadline: none",
            },
        },
        {
            title = "Active Routes",
            lines = { game.world:getActiveRouteSummary() },
        },
        {
            title = "Junction State",
            lines = {},
        },
        {
            title = "Train Queue",
            lines = {},
        },
        {
            title = "Run Stats",
            lines = {
                string.format("Trains cleared: %d / %d", game.world:countCompletedTrains(), #(game.world.trains or {})),
                string.format("Interactions: %d", runSummary.interactionCount or 0),
                string.format("Score: %s", formatScore(runSummary.finalScore or 0)),
            },
        },
    }
    local worldState = game.world

    for _, junction in ipairs(worldState.junctionOrder or {}) do
        sections[3].lines[#sections[3].lines + 1] = string.format("%s | %s", junction.label, getJunctionRouteText(junction))
        sections[3].lines[#sections[3].lines + 1] = getJunctionStateText(junction)
    end

    for _, group in ipairs(worldState:getInputEdgeGroups()) do
        sections[4].lines[#sections[4].lines + 1] = string.format("%s queue", group.edge.label or group.edge.id)
        for index, train in ipairs(group.trains) do
            sections[4].lines[#sections[4].lines + 1] = string.format(
                "%d. %s | start %.0f | %.2fx | %s",
                index,
                train.id,
                train.spawnTime or 0,
                train.speed / math.max(1, worldState.trainSpeed),
                getTrainStatusText(worldState, train)
            )
        end
    end

    return sections
end

local function getPlayInfoOverlaySections(game)
    return game.playOverlayMode == "help" and buildPlayHelpSections(game) or buildPlayDebugSections(game)
end

local function getPlayInfoOverlayLineText(line)
    if type(line) == "table" then
        return safeUiText(line.text, "")
    end

    return safeUiText(line, "")
end

local function isPlayInfoOverlayLineCopyable(line)
    return type(line) == "table" and tostring(line.copyValue or "") ~= ""
end

function ui.getPlayOverlayCopyTargets(game)
    if not game or game.playOverlayMode ~= "debug" then
        return {}
    end

    local rect = getPlayInfoOverlayRect(game)
    local sections = getPlayInfoOverlaySections(game)
    local currentY = rect.y + PLAY_OVERLAY.padding
    local contentX = rect.x + PLAY_OVERLAY.padding
    local contentWidth = rect.w - PLAY_OVERLAY.padding * 2
    local targets = {}

    love.graphics.setFont(game.fonts.title)
    currentY = currentY + game.fonts.title:getHeight() + PLAY_OVERLAY.sectionGap

    for _, section in ipairs(sections) do
        love.graphics.setFont(game.fonts.body)
        currentY = currentY + game.fonts.body:getHeight() + PLAY_OVERLAY.lineGap

        love.graphics.setFont(game.fonts.small)
        for _, line in ipairs(section.lines or {}) do
            local lineText = getPlayInfoOverlayLineText(line)
            local lineHeight = getWrappedLineCount(game.fonts.small, lineText, contentWidth) * game.fonts.small:getHeight()
            if isPlayInfoOverlayLineCopyable(line) then
                targets[#targets + 1] = {
                    x = contentX,
                    y = currentY,
                    w = contentWidth,
                    h = lineHeight,
                    copyText = tostring(line.copyValue or ""),
                    copyLabel = tostring(line.copyLabel or "Value"),
                }
            end
            currentY = currentY + lineHeight + PLAY_OVERLAY.lineGap
        end

        currentY = currentY + PLAY_OVERLAY.sectionGap
    end

    return targets
end

function ui.getPlayOverlayHit(game, x, y)
    if not game or (game.playOverlayMode ~= "help" and game.playOverlayMode ~= "debug") then
        return nil
    end

    local rect = getPlayInfoOverlayRect(game)
    if not pointInRect(x, y, rect) then
        return nil
    end

    for _, target in ipairs(ui.getPlayOverlayCopyTargets(game)) do
        if pointInRect(x, y, target) then
            return {
                kind = "copy_debug_value",
                copyText = target.copyText,
                copyLabel = target.copyLabel,
            }
        end
    end

    return { kind = "overlay_blocked" }
end

function drawPlayInfoOverlay(game)
    if game.playOverlayMode ~= "help" and game.playOverlayMode ~= "debug" then
        return
    end

    local graphics = love.graphics
    local rect = getPlayInfoOverlayRect(game)
    local title = game.playOverlayMode == "help" and "Route Help" or "Route Debug"
    local accentColor = game.playOverlayMode == "help" and { 0.48, 0.92, 0.62, 1 } or { 0.99, 0.78, 0.32, 1 }
    local sections = getPlayInfoOverlaySections(game)
    local currentY = rect.y + PLAY_OVERLAY.padding
    local contentX = rect.x + PLAY_OVERLAY.padding
    local contentWidth = rect.w - PLAY_OVERLAY.padding * 2

    graphics.setColor(0, 0, 0, 0.62)
    graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, PLAY_OVERLAY.radius, PLAY_OVERLAY.radius)
    graphics.setColor(0.24, 0.3, 0.36, 1)
    graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, PLAY_OVERLAY.radius, PLAY_OVERLAY.radius)

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf(title, contentX, currentY, contentWidth, "left")
    currentY = currentY + game.fonts.title:getHeight() + PLAY_OVERLAY.sectionGap

    for _, section in ipairs(sections) do
        love.graphics.setFont(game.fonts.body)
        graphics.setColor(accentColor[1], accentColor[2], accentColor[3], accentColor[4])
        graphics.printf(section.title, contentX, currentY, contentWidth, "left")
        currentY = currentY + game.fonts.body:getHeight() + PLAY_OVERLAY.lineGap

        love.graphics.setFont(game.fonts.small)
        for _, line in ipairs(section.lines or {}) do
            local lineText = getPlayInfoOverlayLineText(line)
            if isPlayInfoOverlayLineCopyable(line) then
                graphics.setColor(0.56, 0.72, 0.98, 1)
            else
                graphics.setColor(0.84, 0.88, 0.92, 1)
            end
            graphics.printf(lineText, contentX, currentY, contentWidth, "left")
            currentY = currentY
                + getWrappedLineCount(game.fonts.small, lineText, contentWidth) * game.fonts.small:getHeight()
                + PLAY_OVERLAY.lineGap
        end

        currentY = currentY + PLAY_OVERLAY.sectionGap
    end

    local copyStatus = game.playOverlayCopyStatus or nil
    if copyStatus and copyStatus.message and copyStatus.message ~= "" then
        love.graphics.setFont(game.fonts.small)
        if copyStatus.status == "error" then
            graphics.setColor(0.99, 0.78, 0.32, 1)
        else
            graphics.setColor(0.56, 0.72, 0.98, 1)
        end
        graphics.printf(
            copyStatus.message,
            contentX,
            rect.y + rect.h - PLAY_OVERLAY.padding - game.fonts.small:getHeight(),
            contentWidth,
            "center"
        )
    end
end

function drawCenteredOverlay(game, title, body, footer, accentColor)
    local graphics = love.graphics
    local accent = accentColor or { 0.48, 0.92, 0.62 }

    graphics.setColor(0, 0, 0, 0.52)
    graphics.rectangle(
        "fill",
        game.viewport.w * 0.5 - 280,
        game.viewport.h * 0.5 - 118,
        560,
        236,
        18,
        18
    )

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf(title, 0, game.viewport.h * 0.5 - 72, game.viewport.w, "center")

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.84, 0.88, 0.92, 1)
    graphics.printf(body, game.viewport.w * 0.5 - 220, game.viewport.h * 0.5 - 10, 440, "center")

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(accent[1], accent[2], accent[3], 1)
    graphics.printf(footer, 0, game.viewport.h * 0.5 + 72, game.viewport.w, "center")
end

end
