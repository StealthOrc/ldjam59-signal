local ui = {}
local uiControls = require("src.game.ui_controls")
local roadTypes = require("src.game.road_types")

local LEVEL_SELECT = {
    titleBarY = 28,
    titleBarH = 74,
    carouselCenterY = 300,
    cardBaseW = 292,
    cardBaseH = 286,
    sideLift = 46,
    filterW = 536,
    filterH = 42,
    selectorGap = 10,
    searchGap = 16,
    bottomSelectorGap = 12,
    bottomBarY = 626,
    bottomBarH = 92,
}

local LEVEL_SELECT_ACTION_LAYOUT = {
    buttonH = 42,
    buttonGap = 18,
    startW = 170,
    editW = 148,
    toggleW = 188,
    uploadW = 170,
    downloadW = 170,
    refreshW = 148,
}

local MARKETPLACE_LAYOUT = {
    searchW = 460,
    searchH = 42,
    browseResultLimit = 10,
    searchResultLimit = 5,
    cardIndicatorInset = 14,
    cardIndicatorH = 28,
    cardIndicatorRadius = 14,
    favoriteButtonH = 30,
    favoriteButtonCornerRadius = 12,
    favoriteButtonHeartRadius = 5,
    favoriteButtonHeartInsetX = 18,
    favoriteButtonHeartInsetY = 9,
    favoriteButtonInset = 14,
    favoriteButtonMinH = 24,
    favoriteButtonMinW = 68,
    favoriteButtonOutlineWidth = 2,
    favoriteButtonTextInset = 34,
    favoriteButtonW = 86,
    favoriteLift = 14,
    favoriteSpacing = 10,
    favoritePlusOneBaseOffset = 12,
    favoritePlusOneRise = 18,
    titleMetaTop = 48,
}
local MARKETPLACE_REMOTE_SOURCE = "remote"
local MARKETPLACE_REMOTE_CATEGORY_USERS = "users"

local MARKETPLACE_FAVORITE_COLORS = {
    likedFill = { 0.42, 0.16, 0.22, 0.98 },
    likedLine = { 0.98, 0.48, 0.62, 1 },
    likedText = { 1, 0.94, 0.97, 1 },
    unlikedFill = { 0.1, 0.14, 0.19, 0.96 },
    unlikedLine = { 0.56, 0.72, 0.98, 1 },
    unlikedText = { 0.94, 0.96, 1, 1 },
}

local PREVIEW_COLORS = {
    background = { 0.06, 0.09, 0.12, 1 },
    frame = { 0.24, 0.32, 0.4, 1 },
    railBed = { 0.16, 0.2, 0.24, 1 },
    mutedTrack = { 0.26, 0.3, 0.36, 0.96 },
    label = { 0.84, 0.88, 0.92, 1 },
    control = {
        direct = { 0.34, 0.84, 0.98, 1 },
        delayed = { 0.99, 0.78, 0.32, 1 },
        pump = { 0.93, 0.22, 0.84, 1 },
        spring = { 0.4, 0.96, 0.74, 1 },
        relay = { 0.56, 0.72, 0.98, 1 },
        trip = { 0.98, 0.6, 0.28, 1 },
        crossbar = { 0.92, 0.38, 0.68, 1 },
    },
}

local CONTROL_SHORT_LABELS = {
    direct = "Direct",
    delayed = "Delay",
    pump = "Charge",
    spring = "Spring",
    relay = "Relay",
    trip = "Trip",
    crossbar = "Cross",
}

local LEVEL_SELECT_BADGE_DEFINITIONS = {
    direct = {
        label = "Direct",
        tooltipTitle = "Direct Junction",
        tooltipText = "This map contains a direct junction.",
    },
    delayed = {
        label = "Delay",
        tooltipTitle = "Delay Junction",
        tooltipText = "This map contains a delay junction.",
    },
    pump = {
        label = "Charge",
        tooltipTitle = "Charge Junction",
        tooltipText = "This map contains a charge junction.",
    },
    spring = {
        label = "Spring",
        tooltipTitle = "Spring Junction",
        tooltipText = "This map contains a spring junction.",
    },
    relay = {
        label = "Relay",
        tooltipTitle = "Relay Junction",
        tooltipText = "This map contains a relay junction.",
    },
    trip = {
        label = "Trip",
        tooltipTitle = "Trip Junction",
        tooltipText = "This map contains a trip junction.",
    },
    crossbar = {
        label = "Cross",
        tooltipTitle = "Crossbar Junction",
        tooltipText = "This map contains a crossbar junction.",
    },
    deadline = {
        label = "Deadline",
        tooltipTitle = "Map Deadline",
        tooltipText = "This map has an overall deadline.",
        fillColor = { 0.98, 0.66, 0.28, 0.98 },
        lineColor = { 0.99, 0.86, 0.44, 1 },
        textColor = { 0.2, 0.12, 0.02, 1 },
    },
    express = {
        label = "Express",
        tooltipTitle = "Express Train",
        tooltipText = "This map contains at least one train with a deadline.",
        fillColor = { 0.38, 0.94, 0.86, 0.98 },
        lineColor = { 0.74, 0.99, 0.95, 1 },
        textColor = { 0.05, 0.16, 0.14, 1 },
    },
}

local PANEL_COLORS = {
    background = { 0.05, 0.07, 0.09, 1 },
    panelFill = { 0.09, 0.11, 0.15, 0.98 },
    panelLine = { 0.25, 0.34, 0.42, 1 },
    panelInnerLine = { 0.44, 0.62, 0.78, 0.38 },
    titleText = { 0.97, 0.98, 1, 1 },
    bodyText = { 0.84, 0.88, 0.92, 1 },
    mutedText = { 0.68, 0.74, 0.8, 1 },
}

local getLevelSelectActionButtons
local getMapControlTypes
local buildMarketplaceDisplayEntries
local getLevelSelectFilterRect
local getMarketplaceEntryForDescriptor
local getMarketplaceIndicatorColors

local PLAY_OVERLAY = {
    margin = 24,
    width = 420,
    padding = 18,
    radius = 18,
    lineGap = 6,
    sectionGap = 14,
}
local PLAY_TOOLTIP_LAYOUT = {
    width = 340,
    gap = 16,
    paddingX = 16,
    paddingY = 14,
    cornerRadius = 14,
    dividerGap = 8,
}

local MENU_LAYOUT = {
    buttonWidth = 320,
    buttonHeight = 56,
    buttonGap = 16,
    firstButtonY = 248,
    debugMarginX = 36,
    debugMarginY = 36,
    debugWidth = 240,
    debugHeight = 48,
    footerY = 654,
}

local PROFILE_MODE_SETUP_LAYOUT = {
    panelW = 640,
    panelH = 360,
    buttonW = 220,
    buttonH = 72,
    buttonGap = 28,
    buttonY = 246,
}
local PROFILE_MODE_TOOLTIP_LAYOUT = {
    maxWidth = 268,
    paddingX = 14,
    paddingY = 12,
    cornerRadius = 12,
    gap = 10,
}

local LEADERBOARD_LOADING = {
    spinnerRadius = 18,
    spinnerThickness = 4,
    spinnerArcLength = math.pi * 1.35,
    spinnerSpeed = 3.2,
    emptyStateYOffset = 180,
    emptySpinnerYOffset = 34,
    emptyTextYOffset = 68,
}
local LEADERBOARD_SCORE_DECIMAL_PLACES = 3
local LEVEL_SELECT_LEADERBOARD_PLAYER_NAME_MAX_CHARACTERS = 14
local LEADERBOARD_REFRESH_INDICATOR_RIGHT_PADDING = 28
local LEADERBOARD_REFRESH_INDICATOR_BOTTOM_PADDING = 18
local REFRESH_LOADING_ANIMATION_STEP_SECONDS = 0.4
local REFRESH_LOADING_ANIMATION_FRAME_COUNT = 3

local LEADERBOARD_LAYOUT = {
    panelX = 36,
    panelY = 100,
    panelMargin = 72,
    contentPadding = 28,
    titlePadding = 24,
    headerY = 116,
    rowYOffset = 28,
    rowHeight = 34,
    rowGap = 8,
    rowRadius = 10,
    rankWidth = 40,
    mapGap = 28,
    mapMinWidth = 176,
    playerXOffset = 52,
    playerRightPadding = 36,
    scoreWidth = 120,
    maxVisibleRows = 12,
    recordWidth = 152,
    recordGap = 18,
    recordRightPadding = 16,
    rowBottomPadding = 56,
    rowPrimaryTextOffsetY = 2,
    tooltipWidth = 360,
    tooltipHeight = 62,
    tooltipOffsetY = 18,
    filterBadgeY = 74,
    filterBadgeHeight = 28,
    filterBadgePaddingX = 16,
    filterBadgeMaxWidth = 460,
}

local LEVEL_SELECT_LEADERBOARD_CARD = {
    inset = 18,
    titleTop = 20,
    maxRows = 5,
    rowTop = 56,
    rowHeight = 24,
    rowGap = 6,
    rowRadius = 10,
    rowPaddingX = 10,
    rankWidth = 32,
    scoreWidth = 76,
    pinnedGap = 12,
    statusPaddingX = 20,
    statusWidthMargin = 40,
    refreshPaddingRight = 8,
    refreshPaddingBottom = 2,
}

local function pointInRect(x, y, rect)
    return x >= rect.x
        and x <= rect.x + rect.w
        and y >= rect.y
        and y <= rect.y + rect.h
end

local function distanceSquaredToSegment(px, py, ax, ay, bx, by)
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

local function lerp(a, b, t)
    return a + ((b - a) * t)
end

local function trim(value)
    return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function safeUiText(value, fallback)
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

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function angleBetweenPoints(a, b)
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

local function drawButton(rect, label, fillColor, strokeColor, font, isDisabled)
    local graphics = love.graphics
    graphics.setColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 1)
    graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 16, 16)
    graphics.setColor(strokeColor[1], strokeColor[2], strokeColor[3], strokeColor[4] or 1)
    graphics.setLineWidth(2)
    graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 16, 16)
    love.graphics.setFont(font)
    if isDisabled then
        graphics.setColor(0.54, 0.58, 0.62, 1)
    else
        graphics.setColor(0.97, 0.98, 1, 1)
    end
    graphics.printf(label, rect.x, rect.y + math.floor((rect.h - font:getHeight()) * 0.5 + 0.5), rect.w, "center")
    graphics.setLineWidth(1)
end

local function getWrappedLineCount(font, text, width)
    local firstValue, secondValue = font:getWrap(text, width)
    if type(firstValue) == "table" then
        return math.max(1, #firstValue)
    end
    if type(secondValue) == "table" then
        return math.max(1, #secondValue)
    end
    return 1
end

local function drawProfileModeTooltip(game, rect, text)
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

local function formatScore(value)
    local formatted = string.format("%.2f", value or 0)
    formatted = formatted:gsub("(%..-)0+$", "%1")
    formatted = formatted:gsub("%.$", "")
    return formatted
end

local function formatLeaderboardScore(value)
    return string.format("%." .. tostring(LEADERBOARD_SCORE_DECIMAL_PLACES) .. "f", value or 0)
end

local function formatLeaderboardEntryTimestamp(value)
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

local function getNowSeconds()
    if love and love.timer and love.timer.getTime then
        return love.timer.getTime()
    end

    return os.clock()
end

local function getNowUnixSeconds()
    if os and os.time then
        return os.time()
    end

    return math.floor(getNowSeconds())
end

local function truncateText(text, maxCharacters)
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

local function formatLevelSelectLeaderboardPlayerName(value)
    local displayName = tostring(value or "Unknown")
    if displayName == "" then
        displayName = "Unknown"
    end
    return truncateText(displayName, LEVEL_SELECT_LEADERBOARD_PLAYER_NAME_MAX_CHARACTERS)
end

local function formatLoadingLabel(baseLabel, animationTime)
    local resolvedAnimationTime = animationTime or getNowSeconds()
    local animationFrame = math.floor(resolvedAnimationTime / REFRESH_LOADING_ANIMATION_STEP_SECONDS) % REFRESH_LOADING_ANIMATION_FRAME_COUNT
    return baseLabel .. string.rep(".", animationFrame + 1)
end

local function formatLeaderboardRefreshLabel(nextRefreshAt, nowSeconds, isLoading, animationTime)
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

local function formatLevelSelectLeaderboardRefreshLabel(nextRefreshAt, nowUnixSeconds, isLoading, animationTime)
    return formatLeaderboardRefreshLabel(nextRefreshAt, nowUnixSeconds or getNowUnixSeconds(), isLoading, animationTime)
end

local function drawMetalPanel(rect, innerAlpha)
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

local function drawLoadingSpinner(centerX, centerY, color)
    local graphics = love.graphics
    local tint = color or { 0.48, 0.92, 0.62, 1 }
    local startAngle = (love.timer.getTime() or 0) * LEADERBOARD_LOADING.spinnerSpeed
    local endAngle = startAngle + LEADERBOARD_LOADING.spinnerArcLength

    graphics.setColor(tint[1], tint[2], tint[3], tint[4] or 1)
    graphics.setLineWidth(LEADERBOARD_LOADING.spinnerThickness)
    graphics.arc("line", "open", centerX, centerY, LEADERBOARD_LOADING.spinnerRadius, startAngle, endAngle)
    graphics.setLineWidth(1)
end

local function drawLeaderboardRefreshIndicator(game, panel, state)
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

local function drawLevelSelectLeaderboardRefreshIndicator(game, contentRect, previewState)
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

local function getLeaderboardPanelRect(game)
    return {
        x = LEADERBOARD_LAYOUT.panelX,
        y = LEADERBOARD_LAYOUT.panelY,
        w = game.viewport.w - LEADERBOARD_LAYOUT.panelMargin,
        h = game.viewport.h - 148,
    }
end

local function shouldShowLeaderboardMapColumn(game)
    local state = game.leaderboardState or {}
    return state.scope == "global"
end

local function formatLeaderboardRecordedAt(value)
    local timestamp = tonumber(value)
    if timestamp then
        return os.date("%Y-%m-%d %H:%M", timestamp)
    end

    local text = tostring(value or "")
    return text ~= "" and text or "Unknown"
end

local function getLeaderboardContentLayout(game)
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

local function getLeaderboardFilterBadgeRect(game)
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

local function buildLeaderboardRowRects(game, entries)
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

local function drawLeaderboardTooltip(game, hoverInfo)
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

local function drawPlayTooltip(game, hoverInfo)
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

local function getMenuDebugButton(game)
    return {
        id = "debug",
        x = MENU_LAYOUT.debugMarginX,
        y = game.viewport.h - MENU_LAYOUT.debugMarginY - MENU_LAYOUT.debugHeight,
        w = MENU_LAYOUT.debugWidth,
        h = MENU_LAYOUT.debugHeight,
        label = game:isDebugModeEnabled() and "Debug Mode: On" or "Debug Mode: Off",
    }
end

local function getPlayInfoOverlayRect(game)
    return {
        x = game.viewport.w - PLAY_OVERLAY.margin - PLAY_OVERLAY.width,
        y = PLAY_OVERLAY.margin,
        w = PLAY_OVERLAY.width,
        h = game.viewport.h - PLAY_OVERLAY.margin * 2,
    }
end

local function getJunctionRouteText(junction)
    local activeInput = junction.inputs[junction.activeInputIndex]
    local activeOutput = junction.outputs[junction.activeOutputIndex]
    return string.format(
        "%s -> %s",
        activeInput and activeInput.label or ("Input " .. tostring(junction.activeInputIndex)),
        activeOutput and activeOutput.label or ("Output " .. tostring(junction.activeOutputIndex))
    )
end

local function getJunctionHelpText(junction)
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

local function formatTooltipColorLabel(colorId)
    local text = tostring(colorId or "")
    if text == "" then
        return "unknown"
    end
    return text:sub(1, 1):upper() .. text:sub(2)
end

local function formatColorList(colorIds)
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

local function getJunctionTooltipTitle(junction)
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

local function getJunctionTooltipText(junction)
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

local function getOutputSelectorTooltipInfo(junction)
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

local function getSpeedTooltipInfo(roadTypeId, x, y)
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

local function getJunctionStateText(junction)
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

local function getTrainStatusText(worldState, train)
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

local function buildPlayHelpSections(game)
    local backTarget = game.currentRunOrigin == "editor" and "editor" or "level select"
    local controlLines = {
        "Left click a junction to activate its control.",
        "Left click the selector below a junction to cycle outputs forward.",
        "Right click the selector below a junction to cycle outputs backward.",
        string.format("M returns to the %s. E opens the editor. R restarts the run.", backTarget),
        "F2 closes this help panel. F3 opens the debug panel.",
    }

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

local function buildPlayDebugSections(game)
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

local function drawPlayInfoOverlay(game)
    if game.playOverlayMode ~= "help" and game.playOverlayMode ~= "debug" then
        return
    end

    local graphics = love.graphics
    local rect = getPlayInfoOverlayRect(game)
    local title = game.playOverlayMode == "help" and "Route Help" or "Route Debug"
    local accentColor = game.playOverlayMode == "help" and { 0.48, 0.92, 0.62, 1 } or { 0.99, 0.78, 0.32, 1 }
    local sections = game.playOverlayMode == "help" and buildPlayHelpSections(game) or buildPlayDebugSections(game)
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
        graphics.setColor(0.84, 0.88, 0.92, 1)
        for _, line in ipairs(section.lines or {}) do
            graphics.printf(line, contentX, currentY, contentWidth, "left")
            currentY = currentY
                + getWrappedLineCount(game.fonts.small, line, contentWidth) * game.fonts.small:getHeight()
                + PLAY_OVERLAY.lineGap
        end

        currentY = currentY + PLAY_OVERLAY.sectionGap
    end
end

local function drawCenteredOverlay(game, title, body, footer, accentColor)
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

local function getMapKind(descriptor)
    -- Check if it's a downloaded/remote import first
    if descriptor.source == "user" and descriptor.isRemoteImport then
        return "downloaded"
    end
    if descriptor.mapKind then
        return descriptor.mapKind
    end
    if descriptor.source == "user" then
        return "user"
    end
    return "campaign"
end

local function getMapKindLabel(descriptor)
    local kind = getMapKind(descriptor)
    if kind == "tutorial" then
        return "Tutorial"
    end
    if kind == "campaign" then
        return "Campaign"
    end
    if kind == "downloaded" then
        return "Downloaded"
    end
    return "User"
end

local function getMapDisplayName(descriptor)
    return descriptor.displayName or descriptor.name or "Untitled Map"
end

local function getLevelSelectFilterSegments()
    return {
        { id = "all", label = "All" },
        { id = "tutorial", label = "Tutorial" },
        { id = "campaign", label = "Campaign" },
        { id = "downloaded", label = "Downloaded" },
        { id = "user", label = "User" },
    }
end

local function getLevelSelectMaps(game)
    if game.levelSelectMode == "marketplace" then
        local marketplaceEntries = buildMarketplaceDisplayEntries(game)
        local maps = {}
        for _, entry in ipairs(marketplaceEntries) do
            maps[#maps + 1] = entry.descriptor
        end
        return maps
    end

    local maps = {}
    local filterId = game.levelSelectFilter or "all"

    for _, mapKind in ipairs({ "tutorial", "campaign", "downloaded", "user" }) do
        if filterId == "all" or filterId == mapKind then
            for _, descriptor in ipairs(game.availableMaps or {}) do
                if getMapKind(descriptor) == mapKind then
                    maps[#maps + 1] = descriptor
                end
            end
        end
    end

    return maps
end

local function getSelectedMapIndex(game, maps)
    local fallbackIndex = #maps > 0 and 1 or nil
    local selectedMapUuid = tostring(game.levelSelectSelectedMapUuid or "")

    for index, descriptor in ipairs(maps or {}) do
        if descriptor.id == game.levelSelectSelectedId then
            game.levelSelectSelectedMapUuid = descriptor.mapUuid
            return index
        end

        if selectedMapUuid ~= "" and tostring(descriptor.mapUuid or "") == selectedMapUuid then
            game.levelSelectSelectedId = descriptor.id
            game.levelSelectSelectedMapUuid = descriptor.mapUuid
            return index
        end
    end

    if fallbackIndex then
        game.levelSelectSelectedId = maps[fallbackIndex].id
        game.levelSelectSelectedMapUuid = maps[fallbackIndex].mapUuid
    else
        game.levelSelectSelectedId = nil
        game.levelSelectSelectedMapUuid = nil
    end

    return fallbackIndex
end

local function getLevelSelectBottomBarRect(game)
    return {
        x = 2,
        y = LEVEL_SELECT.bottomBarY,
        w = game.viewport.w - 4,
        h = LEVEL_SELECT.bottomBarH,
    }
end

local function getLevelSelectTitleBarRect(game)
    return {
        x = 118,
        y = LEVEL_SELECT.titleBarY,
        w = 1044,
        h = LEVEL_SELECT.titleBarH,
    }
end

local function getLevelSelectModeSegments()
    return {
        { id = "library", label = "Local Maps" },
        { id = "marketplace", label = "Online Maps" },
    }
end

local function getLevelSelectModeSelectorRect(game)
    local bottomBarRect = getLevelSelectBottomBarRect(game)
    return {
        x = math.floor(game.viewport.w * 0.5 - LEVEL_SELECT.filterW * 0.5 + 0.5),
        y = bottomBarRect.y - LEVEL_SELECT.bottomSelectorGap - LEVEL_SELECT.filterH,
        w = LEVEL_SELECT.filterW,
        h = LEVEL_SELECT.filterH,
    }
end

local function getMarketplaceTabSegments()
    return {
        { id = "top", label = "Top Maps" },
        { id = "random", label = "Random" },
        { id = "search", label = "Search" },
    }
end

local function getMarketplaceTabsRect(game)
    local filterRect = getLevelSelectFilterRect(game)
    return {
        x = filterRect.x,
        y = filterRect.y,
        w = filterRect.w,
        h = filterRect.h,
    }
end

local function getMarketplaceSearchRect(game)
    local selectorRect = getLevelSelectFilterRect(game)
    return {
        x = math.floor(game.viewport.w * 0.5 - MARKETPLACE_LAYOUT.searchW * 0.5 + 0.5),
        y = selectorRect.y - LEVEL_SELECT.searchGap - MARKETPLACE_LAYOUT.searchH,
        w = MARKETPLACE_LAYOUT.searchW,
        h = MARKETPLACE_LAYOUT.searchH,
    }
end

local function getMarketplaceHash(text)
    local hash = 0
    for index = 1, #text do
        hash = (hash * 33 + text:byte(index)) % 2147483647
    end
    return hash
end

local function normalizeMarketplaceMapKind(category)
    local normalizedCategory = string.lower(trim(category or ""))
    if normalizedCategory == "tutorial" then
        return "tutorial"
    end
    if normalizedCategory == "campaign" then
        return "campaign"
    end
    if normalizedCategory == MARKETPLACE_REMOTE_CATEGORY_USERS then
        return "user"
    end

    return "user"
end

local function buildMarketplaceDescriptor(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local remoteMap = type(entry.map) == "table" and entry.map or {}
    local mapUuid = tostring(entry.map_uuid or "")
    if mapUuid ~= "" then
        remoteMap.id = remoteMap.id or mapUuid
        remoteMap.mapUuid = remoteMap.mapUuid or mapUuid
    end

    local displayName = tostring(entry.map_name or "Untitled Map")
    return {
        id = string.format(
            "%s:%s:%s",
            MARKETPLACE_REMOTE_SOURCE,
            tostring(entry.creator_uuid or "unknown"),
            mapUuid ~= "" and mapUuid or tostring(entry.internal_identifier or "map")
        ),
        mapUuid = mapUuid,
        source = MARKETPLACE_REMOTE_SOURCE,
        name = displayName,
        displayName = displayName,
        favoriteCount = tonumber(entry.favorite_count or 0) or 0,
        likedByPlayer = entry.liked_by_player == true,
        mapKind = normalizeMarketplaceMapKind(entry.map_category),
        savedAt = entry.updated_at,
        hasEditor = false,
        hasLevel = type(entry.map) == "table",
        hasErrors = false,
        isTemplate = false,
        previewLevel = remoteMap,
        previewDescription = remoteMap.previewDescription or remoteMap.description or nil,
        remoteSourceEntry = entry,
    }
end

local function getMarketplaceControlsSummary(descriptor)
    local labels = {}
    for _, controlType in ipairs(getMapControlTypes(descriptor)) do
        labels[#labels + 1] = CONTROL_SHORT_LABELS[controlType] or controlType
    end
    if #labels == 0 then
        return "No control tags"
    end
    return table.concat(labels, ", ")
end

local function buildMarketplaceEntries(game)
    local entries = {}
    for _, sourceEntry in ipairs(game:getMarketplaceEntries() or {}) do
        local descriptor = buildMarketplaceDescriptor(sourceEntry)
        if descriptor then
            local displayName = getMapDisplayName(descriptor)
            local kindLabel = getMapKindLabel(descriptor)
            local controlsSummary = getMarketplaceControlsSummary(descriptor)
            local favoriteAnimation = descriptor.mapUuid ~= "" and game:getMarketplaceFavoriteAnimation(descriptor.mapUuid) or nil
            entries[#entries + 1] = {
                descriptor = descriptor,
                title = displayName,
                subtitle = string.format("%s  |  %s", kindLabel, controlsSummary),
                creatorDisplayName = tostring(sourceEntry.creator_display_name or "Unknown"),
                creatorUuid = tostring(sourceEntry.creator_uuid or ""),
                favoriteCount = descriptor.favoriteCount or 0,
                favoriteAnimation = favoriteAnimation,
                internalIdentifier = tostring(sourceEntry.internal_identifier or ""),
                likedByPlayer = descriptor.likedByPlayer == true,
                featuredWeight = descriptor.favoriteCount or 0,
                randomWeight = getMarketplaceHash(table.concat({
                    tostring(sourceEntry.map_uuid or ""),
                    tostring(sourceEntry.internal_identifier or ""),
                    tostring(sourceEntry.creator_uuid or ""),
                }, ":")),
            }
        end
    end

    return entries
end

buildMarketplaceDisplayEntries = function(game)
    local entries = buildMarketplaceEntries(game)
    local tabId = game.levelSelectMarketplaceTab or "top"
    local searchQuery = string.lower((game.levelSelectMarketplaceSearchQuery or ""):gsub("^%s+", ""):gsub("%s+$", ""))

    if tabId == "top" then
        table.sort(entries, function(a, b)
            if a.featuredWeight ~= b.featuredWeight then
                return a.featuredWeight > b.featuredWeight
            end
            return a.title < b.title
        end)
    elseif tabId == "random" then
        table.sort(entries, function(a, b)
            if a.randomWeight ~= b.randomWeight then
                return a.randomWeight < b.randomWeight
            end
            return a.title < b.title
        end)
    end

    for index, entry in ipairs(entries) do
        entry.position = index
        if tabId == "top" then
            entry.positionLabel = string.format("#%d", index)
        elseif tabId == "random" then
            entry.positionLabel = string.format("Rnd %d", index)
        else
            entry.positionLabel = string.format("Hit %d", index)
        end
    end

    if tabId == "search" then
        local limitedEntries = {}
        for index, entry in ipairs(entries) do
            if index > MARKETPLACE_LAYOUT.searchResultLimit then
                break
            end
            limitedEntries[#limitedEntries + 1] = entry
        end
        return limitedEntries, #entries, searchQuery
    end

    local limitedEntries = {}
    for index, entry in ipairs(entries) do
        if index > MARKETPLACE_LAYOUT.browseResultLimit then
            break
        end
        limitedEntries[#limitedEntries + 1] = entry
    end

    return limitedEntries, #entries, searchQuery
end

local function appendUniqueControl(controls, seen, controlType)
    if controlType and not seen[controlType] then
        seen[controlType] = true
        controls[#controls + 1] = controlType
    end
end

local function mapHasLevelDeadline(descriptor)
    local level = descriptor and descriptor.previewLevel or nil
    return level and level.timeLimit ~= nil
end

local function mapHasExpressTrain(descriptor)
    local level = descriptor and descriptor.previewLevel or nil
    for _, train in ipairs(level and level.trains or {}) do
        if train.deadline ~= nil then
            return true
        end
    end
    return false
end

local function buildLevelSelectBadges(descriptor)
    local badges = {}

    for _, controlType in ipairs(getMapControlTypes(descriptor)) do
        local definition = LEVEL_SELECT_BADGE_DEFINITIONS[controlType] or {}
        badges[#badges + 1] = {
            key = controlType,
            controlType = controlType,
            label = definition.label or CONTROL_SHORT_LABELS[controlType] or controlType,
            tooltipTitle = definition.tooltipTitle or (definition.label or controlType),
            tooltipText = definition.tooltipText or string.format("This map contains %s.", definition.label or controlType),
            fillColor = definition.fillColor,
            lineColor = definition.lineColor,
            textColor = definition.textColor,
        }
    end

    if mapHasLevelDeadline(descriptor) then
        local definition = LEVEL_SELECT_BADGE_DEFINITIONS.deadline
        badges[#badges + 1] = {
            key = "deadline",
            label = definition.label,
            tooltipTitle = definition.tooltipTitle,
            tooltipText = definition.tooltipText,
            fillColor = definition.fillColor,
            lineColor = definition.lineColor,
            textColor = definition.textColor,
        }
    end

    if mapHasExpressTrain(descriptor) then
        local definition = LEVEL_SELECT_BADGE_DEFINITIONS.express
        badges[#badges + 1] = {
            key = "express",
            label = definition.label,
            tooltipTitle = definition.tooltipTitle,
            tooltipText = definition.tooltipText,
            fillColor = definition.fillColor,
            lineColor = definition.lineColor,
            textColor = definition.textColor,
        }
    end

    return badges
end

getMapControlTypes = function(descriptor)
    local controls = {}
    local seen = {}
    local level = descriptor.previewLevel

    for _, junction in ipairs(level and level.junctions or {}) do
        appendUniqueControl(controls, seen, junction.control and junction.control.type or "direct")
    end

    return controls
end

local function getPreviewPoint(point, rect)
    local normalizedX = math.max(0, math.min(1, point.x or 0))
    local normalizedY = math.max(0, math.min(1, point.y or 0))
    return rect.x + normalizedX * rect.w, rect.y + normalizedY * rect.h
end

local function buildPreviewTracks(level)
    local tracks = {}
    local junctions = {}

    if not level then
        return tracks, junctions
    end

    if level.edges and level.junctions then
        local edgeLookup = {}
        for _, edge in ipairs(level.edges or {}) do
            edgeLookup[edge.id] = edge
            tracks[#tracks + 1] = {
                points = edge.points or {},
                color = edge.color,
                muted = false,
            }
        end

        for _, junction in ipairs(level.junctions or {}) do
            local point = nil
            local inputEdge = edgeLookup[(junction.inputEdgeIds or {})[1]]
            local outputEdge = edgeLookup[(junction.outputEdgeIds or {})[1]]

            if inputEdge and #(inputEdge.points or {}) > 0 then
                point = inputEdge.points[#inputEdge.points]
            elseif outputEdge and #(outputEdge.points or {}) > 0 then
                point = outputEdge.points[1]
            end

            if point then
                junctions[#junctions + 1] = {
                    x = point.x,
                    y = point.y,
                    controlType = junction.control and junction.control.type or "direct",
                    outputCount = #(junction.outputEdgeIds or {}),
                }
            end
        end

        return tracks, junctions
    end

    for _, junction in ipairs(level.junctions or {}) do
        for _, input in ipairs(junction.inputs or {}) do
            tracks[#tracks + 1] = {
                points = input.inputPoints or {},
                color = input.color,
                muted = false,
            }
        end

        for _, output in ipairs(junction.outputs or {}) do
            tracks[#tracks + 1] = {
                points = output.outputPoints or {},
                color = output.color,
                muted = output.adoptInputColor == true,
            }
        end

        local point = nil
        if #(junction.inputs or {}) > 0 and #((junction.inputs or {})[1].inputPoints or {}) > 0 then
            local points = (junction.inputs or {})[1].inputPoints
            point = points[#points]
        elseif #(junction.outputs or {}) > 0 and #((junction.outputs or {})[1].outputPoints or {}) > 0 then
            point = ((junction.outputs or {})[1].outputPoints)[1]
        end

        if point then
            junctions[#junctions + 1] = {
                x = point.x,
                y = point.y,
                controlType = junction.control and junction.control.type or "direct",
                outputCount = #(junction.outputs or {}),
            }
        end
    end

    return tracks, junctions
end

local function drawMapPreview(descriptor, rect)
    local graphics = love.graphics
    local tracks, junctions = buildPreviewTracks(descriptor.previewLevel)

    graphics.setColor(PREVIEW_COLORS.background[1], PREVIEW_COLORS.background[2], PREVIEW_COLORS.background[3], PREVIEW_COLORS.background[4])
    graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 16, 16)
    graphics.setColor(PREVIEW_COLORS.frame[1], PREVIEW_COLORS.frame[2], PREVIEW_COLORS.frame[3], PREVIEW_COLORS.frame[4])
    graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 16, 16)

    if #tracks == 0 then
        graphics.setColor(PREVIEW_COLORS.label[1], PREVIEW_COLORS.label[2], PREVIEW_COLORS.label[3], PREVIEW_COLORS.label[4])
        graphics.printf("No Preview", rect.x, rect.y + rect.h * 0.5 - 8, rect.w, "center")
        return
    end

    for _, track in ipairs(tracks) do
        local points = {}
        for _, point in ipairs(track.points or {}) do
            local x, y = getPreviewPoint(point, rect)
            points[#points + 1] = x
            points[#points + 1] = y
        end

        if #points >= 4 then
            graphics.setLineStyle("smooth")
            graphics.setLineJoin("bevel")
            graphics.setLineWidth(10)
            graphics.setColor(PREVIEW_COLORS.railBed[1], PREVIEW_COLORS.railBed[2], PREVIEW_COLORS.railBed[3], PREVIEW_COLORS.railBed[4])
            graphics.line(points)

            local color = track.color or PREVIEW_COLORS.mutedTrack
            local alpha = track.muted and 0.78 or 0.96
            graphics.setLineWidth(5)
            graphics.setColor(color[1], color[2], color[3], alpha)
            graphics.line(points)
        end
    end

    for _, junction in ipairs(junctions) do
        local x, y = getPreviewPoint(junction, rect)
        local color = PREVIEW_COLORS.control[junction.controlType] or PREVIEW_COLORS.control.direct

        graphics.setColor(0.04, 0.06, 0.08, 1)
        graphics.circle("fill", x, y, 10)
        graphics.setColor(color[1], color[2], color[3], color[4] or 1)
        graphics.circle("fill", x, y, 7)

        if junction.outputCount > 1 and junction.controlType ~= "relay" and junction.controlType ~= "crossbar" then
            graphics.setColor(0.99, 0.78, 0.32, 1)
            graphics.circle("line", x, y + 12, 5)
        end
    end
end

local function buildCardBadges(game, descriptor, maxWidth)
    local font = game.fonts.small
    local badges = {}
    local totalWidth = 0
    local marketplaceEntry = getMarketplaceEntryForDescriptor(game, descriptor)

    local function appendBadge(badge)
        local nextWidth = totalWidth + badge.width
        if #badges > 0 then
            nextWidth = nextWidth + 6
        end
        if nextWidth > maxWidth then
            return false
        end
        badges[#badges + 1] = badge
        totalWidth = nextWidth
        return true
    end

    if game.levelSelectMode == "marketplace" and game.levelSelectMarketplaceTab == "top" and marketplaceEntry then
        local rankColors = getMarketplaceIndicatorColors(game, marketplaceEntry)
        appendBadge({
            label = marketplaceEntry.positionLabel or "#0",
            width = font:getWidth(marketplaceEntry.positionLabel or "#0") + 22,
            fillColor = rankColors.fill,
            lineColor = rankColors.line,
            textColor = rankColors.text,
        })
    end

    for _, badgeDefinition in ipairs(buildLevelSelectBadges(descriptor)) do
        local label = badgeDefinition.label
        local appended = appendBadge({
            key = badgeDefinition.key,
            controlType = badgeDefinition.controlType,
            label = label,
            width = font:getWidth(label) + 22,
            tooltipTitle = badgeDefinition.tooltipTitle,
            tooltipText = badgeDefinition.tooltipText,
            fillColor = badgeDefinition.fillColor,
            lineColor = badgeDefinition.lineColor,
            textColor = badgeDefinition.textColor,
        })
        if not appended then
            break
        end
    end

    return badges, totalWidth
end

local function getLevelSelectBackRect(game)
    local bottomBarRect = getLevelSelectBottomBarRect(game)
    return {
        x = bottomBarRect.x + 24,
        y = bottomBarRect.y + math.floor((bottomBarRect.h - LEVEL_SELECT_ACTION_LAYOUT.buttonH) * 0.5 + 0.5),
        w = 120,
        h = LEVEL_SELECT_ACTION_LAYOUT.buttonH,
    }
end

local function getSettledSelectedCardRect(game)
    local width = LEVEL_SELECT.cardBaseW
    local height = LEVEL_SELECT.cardBaseH
    return {
        x = math.floor(game.viewport.w * 0.5 - width * 0.5 + 0.5),
        y = math.floor(LEVEL_SELECT.carouselCenterY - height * 0.5 + 0.5),
        w = width,
        h = height,
    }
end

getLevelSelectFilterRect = function(game)
    local modeRect = getLevelSelectModeSelectorRect(game)

    return {
        x = math.floor(game.viewport.w * 0.5 - LEVEL_SELECT.filterW * 0.5 + 0.5),
        y = modeRect.y - LEVEL_SELECT.selectorGap - LEVEL_SELECT.filterH,
        w = LEVEL_SELECT.filterW,
        h = LEVEL_SELECT.filterH,
    }
end

getLevelSelectActionButtons = function(game)
    local bottomBarRect = getLevelSelectBottomBarRect(game)
    local maps = getLevelSelectMaps(game)
    local selectedIndex = getSelectedMapIndex(game, maps)
    local selectedMap = selectedIndex and maps[selectedIndex] or nil
    local buttonY = bottomBarRect.y + math.floor((bottomBarRect.h - LEVEL_SELECT_ACTION_LAYOUT.buttonH) * 0.5 + 0.5)
    local buttons = {}
    local sideInset = 24
    local primarySpec
    local rightButtonSpecs = {}

    buttons[#buttons + 1] = {
        id = "back",
        label = "Back",
        x = bottomBarRect.x + sideInset,
        y = buttonY,
        w = 120,
        h = LEVEL_SELECT_ACTION_LAYOUT.buttonH,
    }

    if game.levelSelectMode == "marketplace" then
        primarySpec = { id = "download_map", label = "Download", w = LEVEL_SELECT_ACTION_LAYOUT.downloadW }
        rightButtonSpecs = {
            { id = "refresh_marketplace", label = "Refresh", w = LEVEL_SELECT_ACTION_LAYOUT.refreshW },
        }
    else
        local editButtonId = "edit_map"
        local editButtonLabel = "Edit"
        if selectedMap and selectedMap.isRemoteImport then
            editButtonId = "clone_map"
            editButtonLabel = "Clone"
        end

        primarySpec = { id = "open_map", label = "Start", w = LEVEL_SELECT_ACTION_LAYOUT.startW }

        if selectedMap and game:isUploadSelectedMapAvailable(selectedMap) then
            rightButtonSpecs[#rightButtonSpecs + 1] = {
                id = "upload_map",
                label = "Upload",
                w = LEVEL_SELECT_ACTION_LAYOUT.uploadW,
            }
        end

        rightButtonSpecs[#rightButtonSpecs + 1] = {
            id = editButtonId,
            label = editButtonLabel,
            w = LEVEL_SELECT_ACTION_LAYOUT.editW,
        }
    end

    buttons[#buttons + 1] = {
        id = primarySpec.id,
        label = primarySpec.label,
        x = math.floor(game.viewport.w * 0.5 - primarySpec.w * 0.5 + 0.5),
        y = buttonY,
        w = primarySpec.w,
        h = LEVEL_SELECT_ACTION_LAYOUT.buttonH,
    }

    local totalRightWidth = 0
    for index, spec in ipairs(rightButtonSpecs) do
        totalRightWidth = totalRightWidth + spec.w
        if index > 1 then
            totalRightWidth = totalRightWidth + LEVEL_SELECT_ACTION_LAYOUT.buttonGap
        end
    end

    local currentX = bottomBarRect.x + bottomBarRect.w - sideInset - totalRightWidth
    for _, spec in ipairs(rightButtonSpecs) do
        buttons[#buttons + 1] = {
            id = spec.id,
            label = spec.label,
            x = currentX,
            y = buttonY,
            w = spec.w,
            h = LEVEL_SELECT_ACTION_LAYOUT.buttonH,
        }
        currentX = currentX + spec.w + LEVEL_SELECT_ACTION_LAYOUT.buttonGap
    end

    return buttons
end

local function findLevelSelectActionButton(buttons, buttonId)
    for _, button in ipairs(buttons or {}) do
        if button.id == buttonId then
            return button
        end
    end

    return nil
end

local function getLevelIssueOverlayRects(game)
    local panel = {
        x = game.viewport.w * 0.5 - 280,
        y = game.viewport.h * 0.5 - 170,
        w = 560,
        h = 340,
    }

    return {
        panel = panel,
        edit = {
            x = panel.x + 42,
            y = panel.y + panel.h - 68,
            w = 220,
            h = 40,
        },
        cancel = {
            x = panel.x + panel.w - 262,
            y = panel.y + panel.h - 68,
            w = 220,
            h = 40,
        },
    }
end

local function getCardScale(distance)
    local absDistance = math.abs(distance)
    if absDistance <= 1 then
        return lerp(1, 0.84, absDistance)
    end
    if absDistance <= 2 then
        return lerp(0.84, 0.68, absDistance - 1)
    end
    return lerp(0.68, 0.54, math.min(1, absDistance - 2))
end

local function getCarouselOffset(distance)
    local direction = distance < 0 and -1 or 1
    local absDistance = math.abs(distance)
    local magnitude

    if absDistance <= 1 then
        magnitude = lerp(0, 304, absDistance)
    elseif absDistance <= 2 then
        magnitude = lerp(304, 560, absDistance - 1)
    else
        magnitude = lerp(560, 720, math.min(1, absDistance - 2))
    end

    return magnitude * direction
end

local function getCarouselLift(distance)
    local absDistance = math.abs(distance)

    if absDistance <= 1 then
        return lerp(0, 42, absDistance)
    elseif absDistance <= 2 then
        return lerp(42, 76, absDistance - 1)
    end

    return lerp(76, 104, math.min(1, absDistance - 2))
end

local function getWrappedDistance(index, visualIndex, count)
    local distance = index - visualIndex
    local halfCount = count * 0.5

    while distance > halfCount do
        distance = distance - count
    end

    while distance < -halfCount do
        distance = distance + count
    end

    return distance
end

local function getMarketplaceFavoriteButtonRect(rect)
    if not rect then
        return nil
    end

    local buttonScale = rect.scale or 1
    local buttonWidth = math.max(
        MARKETPLACE_LAYOUT.favoriteButtonMinW,
        math.floor(MARKETPLACE_LAYOUT.favoriteButtonW * buttonScale + 0.5)
    )
    local buttonHeight = math.max(
        MARKETPLACE_LAYOUT.favoriteButtonMinH,
        math.floor(MARKETPLACE_LAYOUT.favoriteButtonH * buttonScale + 0.5)
    )
    local inset = math.floor(MARKETPLACE_LAYOUT.favoriteButtonInset * buttonScale + 0.5)
    return {
        x = rect.x + math.floor((rect.w - buttonWidth) * 0.5 + 0.5),
        y = rect.y + rect.h - buttonHeight + MARKETPLACE_LAYOUT.favoriteLift,
        w = buttonWidth,
        h = buttonHeight,
    }
end

local function getMarketplaceFavoriteHoverId(descriptor)
    return descriptor and ("favorite:" .. tostring(descriptor.id or "")) or nil
end

local function formatMarketplaceFavoriteLabel(favoriteCount)
    local resolvedFavoriteCount = tonumber(favoriteCount or 0) or 0
    return tostring(resolvedFavoriteCount)
end

local function getMarketplaceFavoriteLabel(marketplaceEntry)
    local favoriteCount = tonumber(marketplaceEntry and marketplaceEntry.favoriteCount or 0) or 0
    return formatMarketplaceFavoriteLabel(favoriteCount)
end

local function getMarketplaceFavoriteContentLayout(rect)
    local horizontalPadding = math.max(6, math.floor(rect.h * 0.22 + 0.5))
    local iconBoxW = math.max(14, math.floor(rect.h * 1.15 + 0.5))
    local iconCenterX = rect.x + horizontalPadding + math.floor(iconBoxW * 0.5 + 0.5)
    local iconCenterY = rect.y + math.floor(rect.h * 0.5 + 0.5)
    local textX = rect.x + horizontalPadding + iconBoxW + math.max(4, math.floor(rect.h * 0.16 + 0.5))
    local textRightInset = math.max(6, math.floor(rect.h * 0.22 + 0.5))

    return {
        iconCenterX = iconCenterX,
        iconCenterY = iconCenterY,
        textX = textX,
        textRightInset = textRightInset,
    }
end

local function drawMarketplaceHeartIcon(rect, isLiked, lineColor, fillColor)
    local graphics = love.graphics
    local contentLayout = getMarketplaceFavoriteContentLayout(rect)
    local radius = math.max(3, math.floor(rect.h * 0.18 + 0.5))
    local leftCenterX = contentLayout.iconCenterX - math.floor(radius * 0.9 + 0.5)
    local rightCenterX = contentLayout.iconCenterX + math.floor(radius * 0.9 + 0.5)
    local topCenterY = contentLayout.iconCenterY - math.floor(radius * 0.25 + 0.5)
    local bottomY = contentLayout.iconCenterY + math.floor(radius * 1.35 + 0.5)
    local centerX = contentLayout.iconCenterX

    if isLiked then
        graphics.setColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 1)
        graphics.circle("fill", leftCenterX, topCenterY, radius)
        graphics.circle("fill", rightCenterX, topCenterY, radius)
        graphics.polygon(
            "fill",
            leftCenterX - radius,
            topCenterY,
            rightCenterX + radius,
            topCenterY,
            centerX,
            bottomY
        )
    end

    graphics.setColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4] or 1)
    graphics.setLineWidth(MARKETPLACE_LAYOUT.favoriteButtonOutlineWidth)
    graphics.circle("line", leftCenterX, topCenterY, radius)
    graphics.circle("line", rightCenterX, topCenterY, radius)
    graphics.line(leftCenterX - radius, topCenterY, centerX, bottomY, rightCenterX + radius, topCenterY)
    graphics.setLineWidth(1)
end

local function drawMarketplaceFavoriteButton(game, descriptor, rect, marketplaceEntry)
    if not rect or not marketplaceEntry then
        return
    end

    local graphics = love.graphics
    local hoverId = getMarketplaceFavoriteHoverId(descriptor)
    local isHovered = game.levelSelectHoverId == hoverId
    local isLiked = marketplaceEntry.likedByPlayer == true
    local fillColor = isLiked and MARKETPLACE_FAVORITE_COLORS.likedFill or MARKETPLACE_FAVORITE_COLORS.unlikedFill
    local lineColor = isLiked and MARKETPLACE_FAVORITE_COLORS.likedLine or MARKETPLACE_FAVORITE_COLORS.unlikedLine
    local textColor = isLiked and MARKETPLACE_FAVORITE_COLORS.likedText or MARKETPLACE_FAVORITE_COLORS.unlikedText

    graphics.setColor(fillColor[1], fillColor[2], fillColor[3], isHovered and 1 or (fillColor[4] or 1))
    graphics.rectangle(
        "fill",
        rect.x,
        rect.y,
        rect.w,
        rect.h,
        MARKETPLACE_LAYOUT.favoriteButtonCornerRadius,
        MARKETPLACE_LAYOUT.favoriteButtonCornerRadius
    )
    graphics.setColor(lineColor[1], lineColor[2], lineColor[3], isHovered and 1 or (lineColor[4] or 1))
    graphics.setLineWidth(MARKETPLACE_LAYOUT.favoriteButtonOutlineWidth)
    graphics.rectangle(
        "line",
        rect.x,
        rect.y,
        rect.w,
        rect.h,
        MARKETPLACE_LAYOUT.favoriteButtonCornerRadius,
        MARKETPLACE_LAYOUT.favoriteButtonCornerRadius
    )
    graphics.setLineWidth(1)
    drawMarketplaceHeartIcon(rect, isLiked, lineColor, fillColor)

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
    local contentLayout = getMarketplaceFavoriteContentLayout(rect)
    local textRightEdge = rect.x + rect.w - contentLayout.textRightInset
    graphics.printf(
        getMarketplaceFavoriteLabel(marketplaceEntry),
        contentLayout.textX,
        rect.y + math.floor((rect.h - game.fonts.small:getHeight()) * 0.5 + 0.5),
        math.max(0, textRightEdge - contentLayout.textX),
        "right"
    )

    local favoriteAnimation = marketplaceEntry.favoriteAnimation
    local favoriteAnimationDelta = type(favoriteAnimation) == "table" and tonumber(favoriteAnimation.delta or 0) or 0
    if favoriteAnimationDelta ~= 0 then
        local progress = math.max(0, math.min(1, tonumber(favoriteAnimation.progress or 0) or 0))
        local alpha = 1 - progress
        local deltaLabel = string.format("%+d", favoriteAnimationDelta)
        graphics.setColor(textColor[1], textColor[2], textColor[3], alpha)
        graphics.printf(
            deltaLabel,
            contentLayout.textX,
            rect.y - MARKETPLACE_LAYOUT.favoritePlusOneBaseOffset - math.floor(MARKETPLACE_LAYOUT.favoritePlusOneRise * progress + 0.5),
            math.max(0, textRightEdge - contentLayout.textX),
            "right"
        )
    end
end

local function buildLevelSelectCardRects(game)
    local maps = getLevelSelectMaps(game)
    local selectedIndex = getSelectedMapIndex(game, maps)
    local rects = {}

    if not selectedIndex then
        return rects, maps, nil
    end

    local visualIndex = game.levelSelectVisualIndex or selectedIndex
    local centerX = game.viewport.w * 0.5
    for index, descriptor in ipairs(maps) do
        local distance = getWrappedDistance(index, visualIndex, #maps)
        if math.abs(distance) <= 2.4 then
            local scale = getCardScale(distance)
            local width = math.floor(LEVEL_SELECT.cardBaseW * scale + 0.5)
            local height = math.floor(LEVEL_SELECT.cardBaseH * scale + 0.5)
            local centerOffset = getCarouselOffset(distance)
            local x = math.floor(centerX + centerOffset - width * 0.5 + 0.5)
            local y = math.floor(LEVEL_SELECT.carouselCenterY - height * 0.5 + getCarouselLift(distance) + 0.5)
            rects[#rects + 1] = {
                map = descriptor,
                index = index,
                selected = math.abs(distance) < 0.35,
                distance = distance,
                scale = scale,
                x = x,
                y = y,
                w = width,
                h = height,
            }
            if game.levelSelectMode == "marketplace" and descriptor.source == MARKETPLACE_REMOTE_SOURCE then
                rects[#rects].favoriteButtonRect = getMarketplaceFavoriteButtonRect(rects[#rects])
            end

            local badgeGap = 12
            local badgeH = 22
            local badgeWidths, badgeTotalWidth = buildCardBadges(game, descriptor, width - 36)
            local badgeBottomPadding = 18
            local favoriteButtonRect = rects[#rects].favoriteButtonRect
            local badgeY = y + height - badgeH - badgeBottomPadding
            if favoriteButtonRect then
                badgeY = favoriteButtonRect.y - badgeH - MARKETPLACE_LAYOUT.favoriteSpacing
            end
            local previewTop = y + 18
            local previewBottom = badgeY - badgeGap
            rects[#rects].previewRect = {
                x = x + 18,
                y = previewTop,
                w = width - 36,
                h = math.max(56, previewBottom - previewTop),
            }
            rects[#rects].badgeRow = {
                x = x + math.floor((width - badgeTotalWidth) * 0.5 + 0.5),
                y = badgeY,
                badges = badgeWidths,
                totalWidth = badgeTotalWidth,
            }
            local badgeRects = {}
            local badgeX = rects[#rects].badgeRow.x
            for _, badge in ipairs(badgeWidths) do
                badgeRects[#badgeRects + 1] = {
                    badge = badge,
                    x = badgeX,
                    y = badgeY,
                    w = badge.width,
                    h = badgeH,
                }
                badgeX = badgeX + badge.width + 6
            end
            rects[#rects].badgeRow.badgeRects = badgeRects
        end
    end

    table.sort(rects, function(a, b)
        local aDistance = math.abs(a.distance)
        local bDistance = math.abs(b.distance)
        if aDistance ~= bDistance then
            return aDistance > bDistance
        end
        return a.distance < b.distance
    end)

    return rects, maps, selectedIndex
end

local function drawControlBadges(game, descriptor, x, y, maxWidth, badgeRow)
    local graphics = love.graphics
    love.graphics.setFont(game.fonts.small)

    local widths = {}
    local totalWidth = 0

    if badgeRow and badgeRow.badges then
        widths = badgeRow.badges
        totalWidth = badgeRow.totalWidth or 0
    else
        widths, totalWidth = buildCardBadges(game, descriptor, maxWidth)
    end

    local badgeX = x + math.floor((maxWidth - totalWidth) * 0.5 + 0.5)
    for _, badge in ipairs(widths) do
        local fillColor = badge.fillColor or PREVIEW_COLORS.control[badge.controlType] or PREVIEW_COLORS.control.direct
        local lineColor = badge.lineColor or { 0.06, 0.08, 0.1, 0.4 }
        local textColor = badge.textColor or { 0.08, 0.1, 0.14, 1 }
        graphics.setColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 0.96)
        graphics.rectangle("fill", badgeX, y, badge.width, 22, 11, 11)
        graphics.setColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4] or 1)
        graphics.rectangle("line", badgeX, y, badge.width, 22, 11, 11)
        graphics.setColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
        graphics.printf(badge.label, badgeX, y + 3, badge.width, "center")
        badgeX = badgeX + badge.width + 6
    end
end

local function getLevelSelectBadgeHoverInfo(game, x, y)
    for _, rect in ipairs(buildLevelSelectCardRects(game)) do
        local badgeRow = rect.badgeRow
        for _, badgeRect in ipairs(badgeRow and badgeRow.badgeRects or {}) do
            if pointInRect(x, y, badgeRect) then
                return {
                    x = badgeRect.x + badgeRect.w * 0.5,
                    y = badgeRect.y,
                    title = badgeRect.badge.tooltipTitle or badgeRect.badge.label,
                    text = badgeRect.badge.tooltipText or badgeRect.badge.label,
                }
            end
        end
    end

    return nil
end

local function drawLevelSelectChrome(game)
    local graphics = love.graphics
    local bottomBarRect = getLevelSelectBottomBarRect(game)
    graphics.setColor(0.08, 0.12, 0.18, 0.82)
    graphics.circle("fill", 164, 188, 168)
    graphics.circle("fill", 1082, 274, 214)
    graphics.circle("fill", 1014, 628, 178)

    graphics.setColor(0.18, 0.26, 0.34, 0.5)
    graphics.setLineWidth(2)
    graphics.setLineWidth(1)

    drawMetalPanel(bottomBarRect, 0.98)
end

getMarketplaceEntryForDescriptor = function(game, descriptor)
    if game.levelSelectMode ~= "marketplace" or not descriptor then
        return nil
    end

    local entries = buildMarketplaceDisplayEntries(game)
    for _, entry in ipairs(entries) do
        if entry.descriptor.id == descriptor.id then
            return entry
        end
    end

    return nil
end

getMarketplaceIndicatorColors = function(game, marketplaceEntry)
    local defaultColors = {
        fill = { 0.12, 0.17, 0.24, 0.98 },
        line = { 0.56, 0.72, 0.98, 1 },
        text = PANEL_COLORS.titleText,
    }

    if game.levelSelectMarketplaceTab ~= "top" or not marketplaceEntry then
        return defaultColors
    end

    local position = tonumber(marketplaceEntry.position) or 0
    if position == 1 then
        return {
            fill = { 0.42, 0.31, 0.08, 0.98 },
            line = { 0.99, 0.83, 0.32, 1 },
            text = { 1, 0.97, 0.82, 1 },
        }
    end
    if position == 2 then
        return {
            fill = { 0.24, 0.28, 0.34, 0.98 },
            line = { 0.82, 0.88, 0.96, 1 },
            text = { 0.97, 0.98, 1, 1 },
        }
    end
    if position == 3 then
        return {
            fill = { 0.34, 0.18, 0.1, 0.98 },
            line = { 0.91, 0.58, 0.32, 1 },
            text = { 1, 0.92, 0.86, 1 },
        }
    end
    if position >= 4 and position <= 10 then
        return {
            fill = { 0.14, 0.2, 0.28, 0.98 },
            line = { 0.48, 0.66, 0.88, 1 },
            text = { 0.93, 0.96, 1, 1 },
        }
    end

    return defaultColors
end

local function getLevelSelectTitleText(game, selectedMap)
    if game.levelSelectMode == "marketplace" then
        local sectionLabel = "Top Maps"
        local selectedEntry = getMarketplaceEntryForDescriptor(game, selectedMap)
        local marketplaceState = game.getMarketplaceViewState and game:getMarketplaceViewState() or nil
        if game.levelSelectMarketplaceTab == "random" then
            sectionLabel = "Random"
        elseif game.levelSelectMarketplaceTab == "search" then
            sectionLabel = "Search"
        end

        if selectedEntry then
            return selectedEntry.title, string.format(
                "Online Maps  |  %s  |  %s votes  |  by %s",
                selectedEntry.positionLabel or sectionLabel,
                tostring(selectedEntry.favoriteCount or 0),
                selectedEntry.creatorDisplayName or "Unknown"
            )
        end
        if marketplaceState and marketplaceState.message and marketplaceState.status ~= "ready" then
            return "Online Maps", marketplaceState.message
        end
        return "Online Maps", string.format("Online Maps  |  %s", sectionLabel)
    end

    if not selectedMap then
        return "Level Select", "Pick a map to start or edit."
    end

    return getMapDisplayName(selectedMap), getMapKindLabel(selectedMap)
end

local function drawLevelSelectTitleBar(game, selectedMap)
    local graphics = love.graphics
    local barRect = getLevelSelectTitleBarRect(game)

    graphics.setColor(PANEL_COLORS.panelFill[1], PANEL_COLORS.panelFill[2], PANEL_COLORS.panelFill[3], PANEL_COLORS.panelFill[4])
    graphics.rectangle("fill", barRect.x, barRect.y, barRect.w, barRect.h, 12, 12)
    graphics.setLineWidth(2)
    graphics.setColor(PANEL_COLORS.panelLine[1], PANEL_COLORS.panelLine[2], PANEL_COLORS.panelLine[3], PANEL_COLORS.panelLine[4])
    graphics.rectangle("line", barRect.x, barRect.y, barRect.w, barRect.h, 12, 12)
    graphics.setColor(PANEL_COLORS.panelInnerLine[1], PANEL_COLORS.panelInnerLine[2], PANEL_COLORS.panelInnerLine[3], PANEL_COLORS.panelInnerLine[4])
    graphics.rectangle("line", barRect.x + 4, barRect.y + 4, barRect.w - 8, barRect.h - 8, 10, 10)
    graphics.setLineWidth(1)

    local titleText, subtitleText = getLevelSelectTitleText(game, selectedMap)

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(PANEL_COLORS.titleText[1], PANEL_COLORS.titleText[2], PANEL_COLORS.titleText[3], PANEL_COLORS.titleText[4])
    graphics.printf(titleText, barRect.x + 30, barRect.y + 8, barRect.w - 60, "center")

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(PANEL_COLORS.bodyText[1], PANEL_COLORS.bodyText[2], PANEL_COLORS.bodyText[3], PANEL_COLORS.bodyText[4])
    graphics.printf(subtitleText, barRect.x + 30, barRect.y + MARKETPLACE_LAYOUT.titleMetaTop, barRect.w - 60, "center")
end

local function isLevelSelectLeaderboardCardFlipped(game, rect)
    local mapUuid = rect and rect.map and rect.map.mapUuid or nil
    return rect
        and rect.selected
        and mapUuid
        and mapUuid ~= ""
        and game.levelSelectLeaderboardFlipMapUuid == mapUuid
end

local function drawLevelSelectLeaderboardRow(game, rowRect, entry, isHighlighted)
    local graphics = love.graphics
    local fillColor = isHighlighted and { 0.16, 0.28, 0.38, 0.98 } or { 0.08, 0.11, 0.15, 0.96 }
    local lineColor = isHighlighted and { 0.48, 0.72, 0.92, 1 } or { 0.24, 0.32, 0.4, 1 }

    graphics.setColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4])
    graphics.rectangle("fill", rowRect.x, rowRect.y, rowRect.w, rowRect.h, LEVEL_SELECT_LEADERBOARD_CARD.rowRadius, LEVEL_SELECT_LEADERBOARD_CARD.rowRadius)
    graphics.setColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
    graphics.rectangle("line", rowRect.x, rowRect.y, rowRect.w, rowRect.h, LEVEL_SELECT_LEADERBOARD_CARD.rowRadius, LEVEL_SELECT_LEADERBOARD_CARD.rowRadius)

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(PANEL_COLORS.bodyText[1], PANEL_COLORS.bodyText[2], PANEL_COLORS.bodyText[3], PANEL_COLORS.bodyText[4])
    graphics.printf(
        tostring(entry.rank or "-"),
        rowRect.x + LEVEL_SELECT_LEADERBOARD_CARD.rowPaddingX,
        rowRect.y + 4,
        LEVEL_SELECT_LEADERBOARD_CARD.rankWidth,
        "left"
    )

    local nameX = rowRect.x + LEVEL_SELECT_LEADERBOARD_CARD.rowPaddingX + LEVEL_SELECT_LEADERBOARD_CARD.rankWidth
    local nameWidth = rowRect.w - LEVEL_SELECT_LEADERBOARD_CARD.rankWidth - LEVEL_SELECT_LEADERBOARD_CARD.scoreWidth - (LEVEL_SELECT_LEADERBOARD_CARD.rowPaddingX * 2)
    graphics.printf(
        formatLevelSelectLeaderboardPlayerName(entry.playerDisplayName or "Unknown"),
        nameX,
        rowRect.y + 4,
        math.max(0, nameWidth),
        "left"
    )

    graphics.printf(
        formatLeaderboardScore(entry.score or 0),
        rowRect.x + rowRect.w - LEVEL_SELECT_LEADERBOARD_CARD.scoreWidth - LEVEL_SELECT_LEADERBOARD_CARD.rowPaddingX,
        rowRect.y + 4,
        LEVEL_SELECT_LEADERBOARD_CARD.scoreWidth,
        "right"
    )
end

local function getLevelSelectLeaderboardVisibleEntries(topEntries, pinnedPlayerEntry, maxRows)
    local resolvedMaxRows = math.max(0, tonumber(maxRows) or LEVEL_SELECT_LEADERBOARD_CARD.maxRows)
    local visibleTopEntries = {}
    local visiblePinnedPlayerEntry = pinnedPlayerEntry
    local visibleTopEntryLimit = resolvedMaxRows

    if visiblePinnedPlayerEntry and visibleTopEntryLimit > 0 then
        visibleTopEntryLimit = visibleTopEntryLimit - 1
    end

    for index, entry in ipairs(topEntries or {}) do
        if index > visibleTopEntryLimit then
            break
        end

        visibleTopEntries[#visibleTopEntries + 1] = entry
    end

    if resolvedMaxRows <= 0 then
        visiblePinnedPlayerEntry = nil
    end

    return visibleTopEntries, visiblePinnedPlayerEntry
end

local function getLevelSelectLeaderboardPinnedRowY(contentRect, visibleEntryCount)
    local resolvedVisibleEntryCount = math.max(0, tonumber(visibleEntryCount) or 0)
    local baseRowY = contentRect.y + LEVEL_SELECT_LEADERBOARD_CARD.rowTop

    if resolvedVisibleEntryCount == 0 then
        return baseRowY
    end

    return baseRowY
        + (resolvedVisibleEntryCount * LEVEL_SELECT_LEADERBOARD_CARD.rowHeight)
        + ((resolvedVisibleEntryCount - 1) * LEVEL_SELECT_LEADERBOARD_CARD.rowGap)
        + LEVEL_SELECT_LEADERBOARD_CARD.pinnedGap
end

local function shouldShowLevelSelectLeaderboardMessage(topEntries, pinnedPlayerEntry, previewState)
    local hasTopEntries = #(topEntries or {}) > 0
    local hasPinnedEntry = pinnedPlayerEntry ~= nil

    return not hasTopEntries
        and not hasPinnedEntry
        and not (previewState and previewState.isLoading)
        and previewState
        and previewState.message ~= nil
end

local function drawLevelSelectLeaderboardBack(game, rect)
    local graphics = love.graphics
    local contentRect = {
        x = rect.x + LEVEL_SELECT_LEADERBOARD_CARD.inset,
        y = rect.y + LEVEL_SELECT_LEADERBOARD_CARD.inset,
        w = rect.w - (LEVEL_SELECT_LEADERBOARD_CARD.inset * 2),
        h = rect.h - (LEVEL_SELECT_LEADERBOARD_CARD.inset * 2),
    }
    local previewState = game:getLevelSelectPreviewDisplayState(rect.map.mapUuid)
    local topEntries, pinnedPlayerEntry = getLevelSelectLeaderboardVisibleEntries(
        previewState.topEntries or {},
        previewState.pinnedPlayerEntry,
        LEVEL_SELECT_LEADERBOARD_CARD.maxRows
    )
    local rowY = contentRect.y + LEVEL_SELECT_LEADERBOARD_CARD.rowTop

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(PANEL_COLORS.titleText[1], PANEL_COLORS.titleText[2], PANEL_COLORS.titleText[3], PANEL_COLORS.titleText[4])
    graphics.printf(previewState.title or "Leaderboard", contentRect.x, contentRect.y + LEVEL_SELECT_LEADERBOARD_CARD.titleTop, contentRect.w, "center")

    for index, entry in ipairs(topEntries) do
        local rowRect = {
            x = contentRect.x,
            y = rowY,
            w = contentRect.w,
            h = LEVEL_SELECT_LEADERBOARD_CARD.rowHeight,
        }
        local profilePlayerUuid = tostring(game.profile and (game.profile.player_uuid or game.profile.playerId or game.profile.playerUuid) or "")
        local isPlayerEntry = tostring(entry.playerUuid or "") == profilePlayerUuid
        drawLevelSelectLeaderboardRow(game, rowRect, entry, isPlayerEntry)
        rowY = rowY + LEVEL_SELECT_LEADERBOARD_CARD.rowHeight + LEVEL_SELECT_LEADERBOARD_CARD.rowGap
        if index >= LEVEL_SELECT_LEADERBOARD_CARD.maxRows then
            break
        end
    end

    if pinnedPlayerEntry then
        local pinnedRowRect = {
            x = contentRect.x,
            y = getLevelSelectLeaderboardPinnedRowY(contentRect, #topEntries),
            w = contentRect.w,
            h = LEVEL_SELECT_LEADERBOARD_CARD.rowHeight,
        }
        drawLevelSelectLeaderboardRow(game, pinnedRowRect, pinnedPlayerEntry, true)
    elseif previewState.isLoading and #topEntries == 0 then
        drawLoadingSpinner(
            contentRect.x + math.floor(contentRect.w * 0.5 + 0.5),
            contentRect.y + math.floor(contentRect.h * 0.56 + 0.5),
            { 0.48, 0.92, 0.62, 1 }
        )
    elseif shouldShowLevelSelectLeaderboardMessage(topEntries, pinnedPlayerEntry, previewState) then
        love.graphics.setFont(game.fonts.small)
        graphics.setColor(PANEL_COLORS.mutedText[1], PANEL_COLORS.mutedText[2], PANEL_COLORS.mutedText[3], PANEL_COLORS.mutedText[4])
        graphics.printf(
            previewState.message,
            contentRect.x + LEVEL_SELECT_LEADERBOARD_CARD.statusPaddingX,
            contentRect.y + math.floor(contentRect.h * 0.52 + 0.5),
            math.max(0, contentRect.w - LEVEL_SELECT_LEADERBOARD_CARD.statusWidthMargin),
            "center"
        )
    end

    drawLevelSelectLeaderboardRefreshIndicator(game, contentRect, previewState)
end

local function drawLevelCard(game, rect)
    local graphics = love.graphics
    local descriptor = rect.map
    local marketplaceEntry = getMarketplaceEntryForDescriptor(game, descriptor)
    local selected = rect.selected
    local cardFill = selected and { 0.09, 0.11, 0.15, 0.98 } or { 0.08, 0.1, 0.13, 0.94 }
    local trim = selected and { 0.45, 0.7, 0.92, 1 } or { 0.24, 0.34, 0.44, 0.95 }

    graphics.setColor(0.09, 0.1, 0.11, 0.26)
    graphics.rectangle("fill", rect.x + 6, rect.y + rect.h - 8, rect.w, 16, 10, 10)

    graphics.setColor(cardFill[1], cardFill[2], cardFill[3], cardFill[4])
    graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 18, 18)
    graphics.setColor(trim[1], trim[2], trim[3], trim[4])
    graphics.setLineWidth(selected and 4 or 3)
    graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 18, 18)
    graphics.rectangle("line", rect.x + 4, rect.y + 4, rect.w - 8, rect.h - 8, 14, 14)

    if selected then
        graphics.setColor(0.2, 0.72, 0.96, 0.18)
        graphics.rectangle("line", rect.x - 6, rect.y - 6, rect.w + 12, rect.h + 12, 22, 22)
    end

    if isLevelSelectLeaderboardCardFlipped(game, rect) then
        drawLevelSelectLeaderboardBack(game, rect)
    else
        drawMapPreview(descriptor, rect.previewRect)
        drawMarketplaceFavoriteButton(game, descriptor, rect.favoriteButtonRect, marketplaceEntry)

        local badgeY = rect.badgeRow and rect.badgeRow.y or (rect.y + rect.h - 40)
        drawControlBadges(game, descriptor, rect.x + 18, badgeY, rect.w - 36, rect.badgeRow)
    end
end

local function drawLevelSelectEmptyState(game, filterId)
    local graphics = love.graphics
    local panel = {
        x = game.viewport.w * 0.5 - 210,
        y = 250,
        w = 420,
        h = 150,
    }

    drawMetalPanel(panel, 0.96)

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(PANEL_COLORS.titleText[1], PANEL_COLORS.titleText[2], PANEL_COLORS.titleText[3], PANEL_COLORS.titleText[4])
    graphics.printf("No maps in this section yet.", panel.x + 24, panel.y + 38, panel.w - 48, "center")

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(PANEL_COLORS.bodyText[1], PANEL_COLORS.bodyText[2], PANEL_COLORS.bodyText[3], PANEL_COLORS.bodyText[4])
    if filterId == "marketplace" then
        local marketplaceState = game.getMarketplaceViewState and game:getMarketplaceViewState() or nil
        graphics.printf(
            (marketplaceState and marketplaceState.message) or "Try a different online tab or broaden the search term.",
            panel.x + 34,
            panel.y + 78,
            panel.w - 68,
            "center"
        )
    elseif filterId == "user" then
        graphics.printf("Open the editor and save a map to have it show up here.", panel.x + 34, panel.y + 78, panel.w - 68, "center")
    elseif filterId == "downloaded" then
        graphics.printf("Download a map from the online store to have it show up here.", panel.x + 34, panel.y + 78, panel.w - 68, "center")
    else
        graphics.printf("Switch filters or pick All to browse the full level list.", panel.x + 34, panel.y + 78, panel.w - 68, "center")
    end
end

local function drawMarketplaceSearchField(game)
    local graphics = love.graphics
    local searchRect = getMarketplaceSearchRect(game)
    local query = game.levelSelectMarketplaceSearchQuery or ""
    local hasQuery = query ~= ""

    graphics.setColor(0.08, 0.1, 0.14, 0.98)
    graphics.rectangle("fill", searchRect.x, searchRect.y, searchRect.w, searchRect.h, 14, 14)
    graphics.setColor(0.44, 0.62, 0.78, 1)
    graphics.rectangle("line", searchRect.x, searchRect.y, searchRect.w, searchRect.h, 14, 14)

    love.graphics.setFont(game.fonts.body)
    if hasQuery then
        graphics.setColor(PANEL_COLORS.titleText[1], PANEL_COLORS.titleText[2], PANEL_COLORS.titleText[3], PANEL_COLORS.titleText[4])
    else
        graphics.setColor(PANEL_COLORS.mutedText[1], PANEL_COLORS.mutedText[2], PANEL_COLORS.mutedText[3], PANEL_COLORS.mutedText[4])
    end
    graphics.printf(
        hasQuery and query or "Search maps, ids, or tags",
        searchRect.x + 16,
        searchRect.y + 11,
        searchRect.w - 32,
        "left"
    )
end

local function getMenuButtons(game)
    local centerX = math.floor((game.viewport.w - MENU_LAYOUT.buttonWidth) * 0.5 + 0.5)
    local buttonY = MENU_LAYOUT.firstButtonY
    return {
        {
            id = "play",
            x = centerX,
            y = buttonY,
            w = MENU_LAYOUT.buttonWidth,
            h = MENU_LAYOUT.buttonHeight,
            label = "Level Select",
        },
        {
            id = "leaderboard",
            x = centerX,
            y = buttonY + MENU_LAYOUT.buttonHeight + MENU_LAYOUT.buttonGap,
            w = MENU_LAYOUT.buttonWidth,
            h = MENU_LAYOUT.buttonHeight,
            label = game:getLeaderboardButtonLabel(),
        },
        {
            id = "editor",
            x = centerX,
            y = buttonY + ((MENU_LAYOUT.buttonHeight + MENU_LAYOUT.buttonGap) * 2),
            w = MENU_LAYOUT.buttonWidth,
            h = MENU_LAYOUT.buttonHeight,
            label = "Map Editor",
        },
        {
            id = "toggle_play_mode",
            x = centerX,
            y = buttonY + ((MENU_LAYOUT.buttonHeight + MENU_LAYOUT.buttonGap) * 3),
            w = MENU_LAYOUT.buttonWidth,
            h = MENU_LAYOUT.buttonHeight,
            label = game:getPlayModeButtonLabel(),
        },
        {
            id = "quit",
            x = centerX,
            y = buttonY + ((MENU_LAYOUT.buttonHeight + MENU_LAYOUT.buttonGap) * 4),
            w = MENU_LAYOUT.buttonWidth,
            h = MENU_LAYOUT.buttonHeight,
            label = "Quit",
        },
    }
end

local function getProfileSetupConfirmRect(game)
    return {
        x = game.viewport.w * 0.5 - 110,
        y = 430,
        w = 220,
        h = 52,
    }
end

local function getProfileModeSetupPanelRect(game)
    return {
        x = math.floor(game.viewport.w * 0.5 - PROFILE_MODE_SETUP_LAYOUT.panelW * 0.5 + 0.5),
        y = math.floor(game.viewport.h * 0.5 - PROFILE_MODE_SETUP_LAYOUT.panelH * 0.5 + 0.5),
        w = PROFILE_MODE_SETUP_LAYOUT.panelW,
        h = PROFILE_MODE_SETUP_LAYOUT.panelH,
    }
end

local function getProfileModeSetupOptionRects(game)
    local panel = getProfileModeSetupPanelRect(game)
    local totalWidth = (PROFILE_MODE_SETUP_LAYOUT.buttonW * 2) + PROFILE_MODE_SETUP_LAYOUT.buttonGap
    local startX = panel.x + math.floor((panel.w - totalWidth) * 0.5 + 0.5)

    return {
        online = {
            x = startX,
            y = panel.y + PROFILE_MODE_SETUP_LAYOUT.buttonY,
            w = PROFILE_MODE_SETUP_LAYOUT.buttonW,
            h = PROFILE_MODE_SETUP_LAYOUT.buttonH,
        },
        offline = {
            x = startX + PROFILE_MODE_SETUP_LAYOUT.buttonW + PROFILE_MODE_SETUP_LAYOUT.buttonGap,
            y = panel.y + PROFILE_MODE_SETUP_LAYOUT.buttonY,
            w = PROFILE_MODE_SETUP_LAYOUT.buttonW,
            h = PROFILE_MODE_SETUP_LAYOUT.buttonH,
        },
    }
end

local function getLeaderboardActionRects(game)
    return {
        back = { x = 42, y = 38, w = 148, h = 42 },
    }
end

function ui.getLevelSelectMapDescriptors(game)
    return getLevelSelectMaps(game)
end

function ui.getLevelSelectScrollUnit()
    return 1
end

function ui.clampLevelSelectScroll(_, _)
    return 0
end

function ui.scrollLevelSelectToMap(_, _, currentScroll)
    return currentScroll or 0
end

function ui.getMenuActionAt(game, x, y)
    local buttons = getMenuButtons(game)

    for _, rect in ipairs(buttons) do
        if pointInRect(x, y, rect) then
            return rect.id
        end
    end

    if pointInRect(x, y, getMenuDebugButton(game)) then
        return "debug"
    end

    return nil
end

function ui.getProfileSetupActionAt(game, x, y)
    if pointInRect(x, y, getProfileSetupConfirmRect(game)) then
        return "confirm"
    end
    return nil
end

function ui.getProfileModeSetupActionAt(game, x, y)
    local optionRects = getProfileModeSetupOptionRects(game)
    if pointInRect(x, y, optionRects.online) then
        return "online"
    end
    if pointInRect(x, y, optionRects.offline) then
        return "offline"
    end
    return nil
end

function ui.getLeaderboardActionAt(game, x, y)
    local buttons = getLeaderboardActionRects(game)
    if pointInRect(x, y, buttons.back) then
        return "back"
    end
    if pointInRect(x, y, getLeaderboardFilterBadgeRect(game)) then
        return "cycle_filter"
    end
    return nil
end

function ui.getLeaderboardHoverInfoAt(game, x, y)
    local state = game.leaderboardState or { entries = {} }
    local rowRects = buildLeaderboardRowRects(game, state.entries or {})

    for _, rowRect in ipairs(rowRects) do
        if pointInRect(x, y, rowRect.player) then
            return {
                x = x,
                y = y,
                label = "Player ID",
                text = rowRect.entry.playerUuid or "No player ID",
            }
        end

        if rowRect.map and pointInRect(x, y, rowRect.map) then
            local mapCount = tonumber(rowRect.entry.mapCount) or 0
            local mapLabel = mapCount > 1
                and string.format("Latest map UUID, %d maps total", mapCount)
                or "Latest map UUID"
            return {
                x = x,
                y = y,
                label = mapLabel,
                text = rowRect.entry.mapUuid or "No map UUID",
            }
        end
    end

    if pointInRect(x, y, getLeaderboardFilterBadgeRect(game)) then
        return {
            x = x,
            y = y,
            label = game.leaderboardMapUuid and "Map UUID" or "Map Filter",
            text = game.leaderboardMapUuid or "Click to cycle through all maps.",
        }
    end

    return nil
end

function ui.getLeaderboardMapHitAt(game, x, y)
    local state = game.leaderboardState or { entries = {} }
    local rowRects = buildLeaderboardRowRects(game, state.entries or {})

    for _, rowRect in ipairs(rowRects) do
        if rowRect.map and pointInRect(x, y, rowRect.map) and rowRect.entry.mapUuid and rowRect.entry.mapUuid ~= "" then
            return {
                mapUuid = rowRect.entry.mapUuid,
                mapName = rowRect.entry.mapName,
            }
        end
    end

    return nil
end

function ui.getLevelSelectHit(game, x, y, button)
    if game.levelSelectIssue then
        local overlay = getLevelIssueOverlayRects(game)
        if pointInRect(x, y, overlay.edit) then
            return { kind = "issue_edit", map = game.levelSelectIssue.map }
        end
        if pointInRect(x, y, overlay.cancel) then
            return { kind = "issue_cancel" }
        end
        if not pointInRect(x, y, overlay.panel) then
            return { kind = "issue_cancel" }
        end
        return { kind = "issue_blocked" }
    end

    if pointInRect(x, y, getLevelSelectBackRect(game)) then
        return { kind = "back" }
    end

    local modeSelectorRect = getLevelSelectModeSelectorRect(game)
    if pointInRect(x, y, modeSelectorRect) then
        local modeSegments = getLevelSelectModeSegments()
        for index, segment in ipairs(modeSegments) do
            if pointInRect(x, y, uiControls.segmentRect(modeSelectorRect, index, #modeSegments)) then
                if segment.id == "marketplace" and not game:isOnlineMode() then
                    return nil
                end
                return { kind = "set_mode", mode = segment.id }
            end
        end
    end

    if game.levelSelectMode == "marketplace" then
        local tabsRect = getMarketplaceTabsRect(game)
        local tabSegments = getMarketplaceTabSegments()
        if pointInRect(x, y, tabsRect) then
            for index, segment in ipairs(tabSegments) do
                if pointInRect(x, y, uiControls.segmentRect(tabsRect, index, #tabSegments)) then
                    return { kind = "set_marketplace_tab", tab = segment.id }
                end
            end
        end
        local marketplaceMaps = getLevelSelectMaps(game)
        local selectedMarketplaceIndex = getSelectedMapIndex(game, marketplaceMaps)
        local selectedMarketplaceMap = selectedMarketplaceIndex and marketplaceMaps[selectedMarketplaceIndex] or nil
        for _, buttonRect in ipairs(getLevelSelectActionButtons(game)) do
            if buttonRect.id ~= "back" and pointInRect(x, y, buttonRect) then
                return {
                    kind = buttonRect.id,
                    map = selectedMarketplaceMap,
                }
            end
        end
        for _, rect in ipairs(buildLevelSelectCardRects(game)) do
            if rect.favoriteButtonRect and pointInRect(x, y, rect.favoriteButtonRect) then
                return { kind = "favorite_map", map = rect.map }
            end
            if pointInRect(x, y, rect) then
                return { kind = "select_map", map = rect.map }
            end
        end
        return nil
    end

    local cardRects = buildLevelSelectCardRects(game)
    local filterRect = getLevelSelectFilterRect(game)
    local filterSegments = getLevelSelectFilterSegments()
    if pointInRect(x, y, filterRect) then
        for index, segment in ipairs(filterSegments) do
            if pointInRect(x, y, uiControls.segmentRect(filterRect, index, #filterSegments)) then
                return { kind = "set_filter", filter = segment.id }
            end
        end
    end

    local maps = getLevelSelectMaps(game)
    local selectedIndex = getSelectedMapIndex(game, maps)
    local selectedMap = selectedIndex and maps[selectedIndex] or nil
    for _, buttonRect in ipairs(getLevelSelectActionButtons(game)) do
        if buttonRect.id ~= "back" and pointInRect(x, y, buttonRect) then
            return {
                kind = buttonRect.id,
                map = selectedMap,
            }
        end
    end

    for _, rect in ipairs(cardRects) do
        if pointInRect(x, y, rect) then
            if button == 2 and rect.selected then
                return { kind = "toggle_leaderboard_card", map = rect.map }
            end
            if rect.selected then
                return { kind = "open_map", map = rect.map }
            end
            return { kind = "select_map", map = rect.map }
        end
    end

    return nil
end

function ui.getLevelSelectHoverId(game, x, y)
    if game.levelSelectIssue then
        return nil
    end

    if game.levelSelectMode == "marketplace" then
        local tabsRect = getMarketplaceTabsRect(game)
        if pointInRect(x, y, tabsRect) then
            local tabSegments = getMarketplaceTabSegments()
            for index, segment in ipairs(tabSegments) do
                if pointInRect(x, y, uiControls.segmentRect(tabsRect, index, #tabSegments)) then
                    return segment.id
                end
            end
        end
        local modeSelectorRect = getLevelSelectModeSelectorRect(game)
        if pointInRect(x, y, modeSelectorRect) then
            local modeSegments = getLevelSelectModeSegments()
            for index, segment in ipairs(modeSegments) do
                if pointInRect(x, y, uiControls.segmentRect(modeSelectorRect, index, #modeSegments)) then
                    if segment.id == "marketplace" and not game:isOnlineMode() then
                        return nil
                    end
                    return segment.id
                end
            end
        end
        for _, rect in ipairs(buildLevelSelectCardRects(game)) do
            if rect.favoriteButtonRect and pointInRect(x, y, rect.favoriteButtonRect) then
                return getMarketplaceFavoriteHoverId(rect.map)
            end
        end
        return nil
    end

    local filterRect = getLevelSelectFilterRect(game)
    if pointInRect(x, y, filterRect) then
        local filterSegments = getLevelSelectFilterSegments()
        for index, segment in ipairs(filterSegments) do
            if pointInRect(x, y, uiControls.segmentRect(filterRect, index, #filterSegments)) then
                return segment.id
            end
        end
    end

    local modeSelectorRect = getLevelSelectModeSelectorRect(game)
    if pointInRect(x, y, modeSelectorRect) then
        local modeSegments = getLevelSelectModeSegments()
        for index, segment in ipairs(modeSegments) do
            if pointInRect(x, y, uiControls.segmentRect(modeSelectorRect, index, #modeSegments)) then
                if segment.id == "marketplace" and not game:isOnlineMode() then
                    return nil
                end
                return segment.id
            end
        end
    end

    return nil
end

function ui.getLevelSelectHoverInfoAt(game, x, y)
    if game.levelSelectIssue then
        return nil
    end

    return getLevelSelectBadgeHoverInfo(game, x, y)
end

local function getPlayBackRect(game)
    local width = game and game.currentRunOrigin == "editor" and 162 or 138
    local viewportWidth = game and game.viewport and game.viewport.w or 1280
    return {
        x = viewportWidth - width - 32,
        y = 28,
        w = width,
        h = 38,
    }
end

local function getPlayStartRect()
    return {
        x = 1048,
        y = 74,
        w = 200,
        h = 46,
    }
end

local function getRunBackLabel(game)
    if game and game.currentRunOrigin == "editor" then
        return "Back to Editor"
    end

    return "Level Select"
end

local function formatTimeValue(value)
    if value == nil then
        return "--"
    end
    return string.format("%.1f", value)
end

local function getColorLabel(colorId)
    if not colorId then
        return "--"
    end
    return colorId:sub(1, 1):upper() .. colorId:sub(2)
end

local function getTrackOuterAnchor(track, isOutput)
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

local function getAnchoredPanelRect(game, anchorX, anchorY, dirX, dirY, width, height, offset)
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

local function getInputPrepCardRect(game, edge, trainCount, inputGroups)
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

local function getInputLiveCardRect(game, edge, train)
    local anchorX, anchorY, dirX, dirY = getTrackOuterAnchor(edge, false)
    local width = math.max(140, getPrepTrainRowWidth(game, train) + 20)
    return getAnchoredPanelRect(game, anchorX, anchorY, dirX, dirY, width, 54, 12)
end

local function getOutputBadgeRect(game, edge, badge)
    local anchorX, anchorY, dirX, dirY = getTrackOuterAnchor(edge, true)
    love.graphics.setFont(game.fonts.body)
    local ratioText = string.format("%d / %d", badge.deliveredCount or 0, badge.expectedCount or 0)
    local width = math.max(64, game.fonts.body:getWidth(ratioText) + PREP_TRAIN_ROW_SPACING * 2 + 16)
    return getAnchoredPanelRect(game, anchorX, anchorY, dirX, dirY, width, 44, 12)
end

local function formatSecondsLabel(value)
    return string.format("%ss", formatTimeValue(value))
end

local function getPrepTrainPreviewMetrics(game, train)
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

local function getPrepTrainRowLayout(game, rowRect, leadText, deadlineText, train)
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

local function getPrepTrainRowContentWidth(game, train)
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

local function drawPrepTrainPreview(game, x, centerY, train)
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

local function drawTrainRow(game, rowRect, leadText, deadlineText, train)
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

local function drawInputPrepCard(game, group)
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

local function drawInputLiveCard(game, edge, train)
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

local function drawOutputBadge(game, badge)
    local graphics = love.graphics
    local rect = getOutputBadgeRect(game, badge.edge, badge)
    local ratioText = string.format("%d / %d", badge.deliveredCount or 0, badge.expectedCount or 0)

    drawMetalPanel(rect, 0.96)

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.48, 0.92, 0.62, 1)
    graphics.printf(ratioText, rect.x, rect.y + math.floor((rect.h - game.fonts.body:getHeight()) * 0.5 + 0.5), rect.w, "center")
end

local function getPrepTrainHoverInfo(game, x, y)
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

local function getOutputBadgeHoverInfo(game, x, y)
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

local function getJunctionHoverInfo(game, x, y)
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

local function getOutputSelectorHoverInfo(game, x, y)
    for _, junction in ipairs(game.world.junctionOrder or {}) do
        if game.world:isOutputSelectorHit(junction, x, y) then
            return getOutputSelectorTooltipInfo(junction)
        end
    end

    return nil
end

local function getTrackSectionHoverInfo(game, x, y)
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

local function getResultsButtonRects(game)
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

function ui.drawMenu(game)
    local graphics = love.graphics
    local buttons = getMenuButtons(game)
    local debugButton = getMenuDebugButton(game)

    graphics.setColor(0.05, 0.07, 0.1, 1)
    graphics.rectangle("fill", 0, 0, game.viewport.w, game.viewport.h)

    graphics.setColor(0, 0, 0, 0.22)
    graphics.circle("fill", 200, 140, 180)
    graphics.circle("fill", 1080, 560, 220)

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf("Out of Signal", 0, 128, game.viewport.w, "center")

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.84, 0.88, 0.92, 1)
    graphics.printf(
        game:isOfflineMode()
            and "Route trains through lever-controlled merges and keep your personal scores on this device."
            or "Route trains through lever-controlled merges, upload cleared scores, and compare runs online.",
        game.viewport.w * 0.5 - 280,
        188,
        560,
        "center"
    )

    for _, rect in ipairs(buttons) do
        drawButton(rect, rect.label, { 0.09, 0.11, 0.15, 0.98 }, { 0.48, 0.92, 0.62, 1 }, game.fonts.body)
    end

    local debugStrokeColor = game:isDebugModeEnabled() and { 0.99, 0.78, 0.32, 1 } or { 0.3, 0.42, 0.54, 1 }
    drawButton(debugButton, debugButton.label, { 0.09, 0.11, 0.15, 0.98 }, debugStrokeColor, game.fonts.small)

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.72, 0.78, 0.84, 1)
    graphics.printf(
        game:isOfflineMode()
            and "Enter starts. L opens personal scores. O toggles online or offline mode. D toggles debug mode. Esc quits."
            or "Enter starts. L opens the leaderboard. O toggles online or offline mode. D toggles debug mode. Esc quits.",
        0,
        MENU_LAYOUT.footerY,
        game.viewport.w,
        "center"
    )
end

function ui.drawProfileSetup(game)
    local graphics = love.graphics
    local panel = {
        x = game.viewport.w * 0.5 - 280,
        y = game.viewport.h * 0.5 - 150,
        w = 560,
        h = 300,
    }
    local inputRect = {
        x = panel.x + 56,
        y = panel.y + 126,
        w = panel.w - 112,
        h = 56,
    }
    local confirmRect = getProfileSetupConfirmRect(game)

    graphics.setColor(0.05, 0.07, 0.1, 1)
    graphics.rectangle("fill", 0, 0, game.viewport.w, game.viewport.h)
    drawMetalPanel(panel, 0.98)

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf("Choose Name", panel.x + 24, panel.y + 34, panel.w - 48, "center")

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.84, 0.88, 0.92, 1)
    graphics.printf("Enter the name to use in the game.", panel.x + 42, panel.y + 84, panel.w - 84, "center")

    graphics.setColor(0.48, 0.92, 0.62, 0.12)
    graphics.rectangle("fill", inputRect.x - 4, inputRect.y - 4, inputRect.w + 8, inputRect.h + 8, 16, 16)
    graphics.setColor(0.08, 0.1, 0.14, 0.98)
    graphics.rectangle("fill", inputRect.x, inputRect.y, inputRect.w, inputRect.h, 14, 14)
    graphics.setColor(0.48, 0.92, 0.62, 1)
    graphics.rectangle("line", inputRect.x, inputRect.y, inputRect.w, inputRect.h, 14, 14)
    graphics.setColor(0.48, 0.92, 0.62, 0.24)
    graphics.rectangle("line", inputRect.x - 4, inputRect.y - 4, inputRect.w + 8, inputRect.h + 8, 16, 16)

    love.graphics.setFont(game.fonts.body)
    local typedText = game.profileSetupNameBuffer or ""
    local hasTypedText = typedText ~= ""
    local nameText = hasTypedText and typedText or "Type a name..."
    if hasTypedText then
        graphics.setColor(0.97, 0.98, 1, 1)
    else
        graphics.setColor(0.5, 0.58, 0.66, 1)
    end
    graphics.printf(nameText, inputRect.x + 18, inputRect.y + 16, inputRect.w - 36, "left")

    if math.floor((love.timer.getTime() or 0) * 2) % 2 == 0 then
        local textWidth = game.fonts.body:getWidth(typedText)
        local caretX = hasTypedText
            and math.min(inputRect.x + inputRect.w - 24, inputRect.x + 18 + textWidth + 2)
            or (inputRect.x + 12)
        graphics.setColor(0.48, 0.92, 0.62, 1)
        graphics.rectangle("fill", caretX, inputRect.y + 12, 3, inputRect.h - 24, 1, 1)
    end

    love.graphics.setFont(game.fonts.small)
    if game.profileSetupError then
        graphics.setColor(0.99, 0.78, 0.32, 1)
        graphics.printf(game.profileSetupError, panel.x + 42, panel.y + 194, panel.w - 84, "center")
    end

    drawButton(confirmRect, "Continue", { 0.09, 0.11, 0.15, 0.98 }, { 0.48, 0.92, 0.62, 1 }, game.fonts.body)
end

function ui.drawProfileModeSetup(game)
    local graphics = love.graphics
    local panel = getProfileModeSetupPanelRect(game)
    local optionRects = getProfileModeSetupOptionRects(game)
    local isOnlineSelected = game.profileModeSelection == "online"
    local promptText = "Do you want to use online features such as online leaderboards and community maps?"
    local offlineTooltipText = "We're only storing your username as well as the uploaded maps and leaderboard stats. You can turn this on or off at any time in the main menu."
    local promptWidth = panel.w - 88
    local promptLineCount = getWrappedLineCount(game.fonts.body, promptText, promptWidth)
    local promptHeight = promptLineCount * game.fonts.body:getHeight()
    local textBlockHeight = promptHeight
    local textAreaTop = panel.y + 84
    local textAreaBottom = optionRects.online.y - 34
    local textBlockY = textAreaTop + math.floor(((textAreaBottom - textAreaTop) - textBlockHeight) * 0.5 + 0.5)
    local promptX = panel.x + math.floor((panel.w - promptWidth) * 0.5 + 0.5)

    graphics.setColor(0.05, 0.07, 0.1, 1)
    graphics.rectangle("fill", 0, 0, game.viewport.w, game.viewport.h)
    drawMetalPanel(panel, 0.98)

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf("Enable Online Functionality?", panel.x + 24, panel.y + 34, panel.w - 48, "center")

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.84, 0.88, 0.92, 1)
    graphics.printf(
        promptText,
        promptX,
        textBlockY,
        promptWidth,
        "center"
    )

    drawButton(
        optionRects.online,
        "Online",
        isOnlineSelected and { 0.1, 0.22, 0.14, 0.98 } or { 0.08, 0.18, 0.11, 0.98 },
        isOnlineSelected and { 0.54, 0.96, 0.66, 1 } or { 0.42, 0.86, 0.55, 1 },
        game.fonts.body
    )
    drawButton(
        optionRects.offline,
        "Offline",
        { 0.08, 0.1, 0.14, 0.98 },
        { 0.3, 0.42, 0.54, 1 },
        game.fonts.body
    )

    if game.profileModeHoverId == "offline" then
        drawProfileModeTooltip(game, optionRects.offline, offlineTooltipText)
    end

    if game.profileModeSetupError then
        graphics.setColor(0.99, 0.78, 0.32, 1)
        graphics.printf(game.profileModeSetupError, panel.x + 40, panel.y + panel.h - 42, panel.w - 80, "center")
    end
end

function ui.drawLeaderboard(game)
    local graphics = love.graphics
    local layout = getLeaderboardContentLayout(game)
    local panel = layout.panel
    local buttons = getLeaderboardActionRects(game)
    local state = game.leaderboardState or { status = "idle", entries = {} }
    local hasEntries = #(state.entries or {}) > 0
    local contentX = layout.contentX
    local contentW = layout.contentW

    graphics.setColor(0.05, 0.07, 0.1, 1)
    graphics.rectangle("fill", 0, 0, game.viewport.w, game.viewport.h)
    drawMetalPanel(panel, 0.98)

    drawButton(buttons.back, "Back", { 0.1, 0.14, 0.18, 0.98 }, { 0.3, 0.42, 0.54, 1 }, game.fonts.small)

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf(game.leaderboardTitle or "Online Leaderboard", panel.x + 24, panel.y + 24, panel.w - 48, "center")

    local badgeRect = getLeaderboardFilterBadgeRect(game)

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.1, 0.14, 0.18, 0.98)
    graphics.rectangle("fill", badgeRect.x, badgeRect.y, badgeRect.w, badgeRect.h, 14, 14)
    graphics.setColor(game.leaderboardMapUuid and 0.56 or 0.3, game.leaderboardMapUuid and 0.72 or 0.42, game.leaderboardMapUuid and 0.98 or 0.54, 1)
    graphics.rectangle("line", badgeRect.x, badgeRect.y, badgeRect.w, badgeRect.h, 14, 14)
    graphics.setColor(0.9, 0.94, 0.98, 1)
    graphics.printf(
        badgeRect.text,
        badgeRect.x + LEADERBOARD_LAYOUT.filterBadgePaddingX,
        badgeRect.y + 6,
        badgeRect.w - (LEADERBOARD_LAYOUT.filterBadgePaddingX * 2),
        "center"
    )

    if state.status ~= "ready" and not hasEntries then
        if state.status == "loading" then
            drawLoadingSpinner(
                panel.x + panel.w * 0.5,
                panel.y + LEADERBOARD_LOADING.emptyStateYOffset + LEADERBOARD_LOADING.emptySpinnerYOffset,
                { 0.48, 0.92, 0.62, 1 }
            )
        end

        love.graphics.setFont(game.fonts.body)
        graphics.setColor(state.status == "loading" and 0.84 or 0.99, state.status == "loading" and 0.88 or 0.78, state.status == "loading" and 0.92 or 0.32, 1)
        graphics.printf(
            state.message or "The leaderboard is not ready.",
            contentX,
            panel.y + LEADERBOARD_LOADING.emptyStateYOffset + LEADERBOARD_LOADING.emptyTextYOffset,
            contentW,
            "center"
        )
        drawLeaderboardRefreshIndicator(game, panel, state)
        return
    end

    if not hasEntries then
        love.graphics.setFont(game.fonts.body)
        graphics.setColor(0.84, 0.88, 0.92, 1)
        graphics.printf(state.message or "No entries are available yet.", contentX, panel.y + 180, contentW, "center")
        drawLeaderboardRefreshIndicator(game, panel, state)
        return
    end

    local headerY = panel.y + LEADERBOARD_LAYOUT.headerY
    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.68, 0.74, 0.8, 1)
    graphics.print("#", contentX, headerY)
    graphics.print("Player", layout.playerX, headerY)
    graphics.printf("Score", layout.scoreX, headerY, LEADERBOARD_LAYOUT.scoreWidth, "center")
    if shouldShowLeaderboardMapColumn(game) then
        graphics.printf(game:isOfflineMode() and "Map" or "Latest Map", layout.mapX, headerY, layout.mapWidth, "left")
    end
    graphics.printf(game:isOfflineMode() and "Recorded" or "Record", layout.recordX, headerY, LEADERBOARD_LAYOUT.recordWidth, "left")

    local rowRects = buildLeaderboardRowRects(game, state.entries or {})
    for _, rowRect in ipairs(rowRects) do
        local entry = rowRect.entry
        local rowY = rowRect.player.y
        graphics.setColor(0.1, 0.13, 0.17, 0.94)
        graphics.rectangle("fill", rowRect.row.x, rowRect.row.y, rowRect.row.w, rowRect.row.h, LEADERBOARD_LAYOUT.rowRadius, LEADERBOARD_LAYOUT.rowRadius)
        graphics.setColor(0.26, 0.34, 0.42, 1)
        graphics.rectangle("line", rowRect.row.x, rowRect.row.y, rowRect.row.w, rowRect.row.h, LEADERBOARD_LAYOUT.rowRadius, LEADERBOARD_LAYOUT.rowRadius)

        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.print(tostring(entry.rank or 0), contentX + 12, rowY + LEADERBOARD_LAYOUT.rowPrimaryTextOffsetY)
        graphics.printf(
            entry.playerDisplayName or "Unknown",
            rowRect.player.x,
            rowY + LEADERBOARD_LAYOUT.rowPrimaryTextOffsetY,
            rowRect.player.w,
            "left"
        )
        graphics.printf(
            formatLeaderboardScore(entry.score or 0),
            layout.scoreX,
            rowY + LEADERBOARD_LAYOUT.rowPrimaryTextOffsetY,
            LEADERBOARD_LAYOUT.scoreWidth,
            "center"
        )
        if rowRect.map then
            graphics.setColor(0.72, 0.78, 0.84, 1)
            graphics.printf(
                entry.mapName or "Unknown Map",
                rowRect.map.x,
                rowY + LEADERBOARD_LAYOUT.rowPrimaryTextOffsetY,
                rowRect.map.w,
                "left"
            )
        end

        graphics.setColor(0.68, 0.74, 0.8, 1)
        graphics.printf(
            game:isOfflineMode()
                and formatLeaderboardRecordedAt(entry.recordedAt or entry.updatedAt)
                or formatLeaderboardEntryTimestamp(entry.updatedAt or entry.recordedAt),
            rowRect.record.x,
            rowY + 2,
            rowRect.record.w,
            "left"
        )
    end

    if #(state.entries or {}) > #rowRects then
        graphics.setColor(0.68, 0.74, 0.8, 1)
        graphics.printf(
            string.format("%d more entry/entries hidden.", #(state.entries or {}) - #rowRects),
            contentX,
            panel.y + panel.h - 44,
            contentW,
            "center"
        )
    end

    drawLeaderboardRefreshIndicator(game, panel, state)
    drawLeaderboardTooltip(game, game.leaderboardHoverInfo)
end

function ui.drawLevelSelect(game)
    local graphics = love.graphics
    local maps = getLevelSelectMaps(game)
    local selectedIndex = getSelectedMapIndex(game, maps)
    local selectedMap = selectedIndex and maps[selectedIndex] or nil
    local cardRects = buildLevelSelectCardRects(game)
    local actionButtons = getLevelSelectActionButtons(game)
    local primarySelectionRect = game.levelSelectMode == "marketplace" and getMarketplaceTabsRect(game) or getLevelSelectFilterRect(game)
    local primarySelectionSegments = game.levelSelectMode == "marketplace" and getMarketplaceTabSegments() or getLevelSelectFilterSegments()
    local primarySelectionValue = game.levelSelectMode == "marketplace" and (game.levelSelectMarketplaceTab or "top") or (game.levelSelectFilter or "all")
    local modeSelectionRect = getLevelSelectModeSelectorRect(game)
    local modeSelectionSegments = getLevelSelectModeSegments()

    graphics.setColor(PANEL_COLORS.background[1], PANEL_COLORS.background[2], PANEL_COLORS.background[3], PANEL_COLORS.background[4])
    graphics.rectangle("fill", 0, 0, game.viewport.w, game.viewport.h)

    drawLevelSelectChrome(game)
    drawLevelSelectTitleBar(game, selectedMap)

    for _, cardRect in ipairs(cardRects) do
        drawLevelCard(game, cardRect)
    end

    if #maps == 0 then
        drawLevelSelectEmptyState(game, game.levelSelectMode == "marketplace" and "marketplace" or (game.levelSelectFilter or "all"))
    end

    uiControls.drawSegmentedToggle(
        primarySelectionRect,
        primarySelectionSegments,
        primarySelectionValue,
        game.levelSelectHoverId,
        game.fonts.small,
        {
            backgroundColor = { 0.08, 0.1, 0.14, 0.98 },
            activeFillColor = { 0.78, 0.88, 0.98, 0.94 },
            hoverColor = { 0.3, 0.4, 0.5, 0.22 },
            outlineColor = { 0.26, 0.38, 0.5, 1 },
            innerOutlineColor = { 0.44, 0.62, 0.78, 0.34 },
            selectedTextColor = { 0.08, 0.11, 0.15, 1 },
            textColor = { 0.9, 0.93, 0.97, 1 },
        }
    )

    uiControls.drawSegmentedToggle(
        modeSelectionRect,
        modeSelectionSegments,
        game.levelSelectMode or "library",
        game.levelSelectHoverId,
        game.fonts.small,
        {
            backgroundColor = { 0.08, 0.1, 0.14, 0.98 },
            activeFillColor = { 0.78, 0.88, 0.98, 0.94 },
            hoverColor = { 0.3, 0.4, 0.5, 0.22 },
            outlineColor = { 0.26, 0.38, 0.5, 1 },
            innerOutlineColor = { 0.44, 0.62, 0.78, 0.34 },
            selectedTextColor = { 0.08, 0.11, 0.15, 1 },
            textColor = { 0.9, 0.93, 0.97, 1 },
        }
    )

    if game.levelSelectMode == "marketplace" then
        if game.levelSelectMarketplaceTab == "search" then
            drawMarketplaceSearchField(game)
        end
    end

    for _, buttonRect in ipairs(actionButtons) do
        local fillColor = { 0.1, 0.12, 0.15, 0.98 }
        local strokeColor = { 0.24, 0.3, 0.36, 1 }
        local font = game.fonts.body
        local isDisabled = false

        if buttonRect.id == "open_map" and selectedMap then
            fillColor = { 0.12, 0.17, 0.2, 0.98 }
            strokeColor = { 0.48, 0.92, 0.62, 1 }
        elseif buttonRect.id == "edit_map" and selectedMap then
            fillColor = { 0.12, 0.17, 0.2, 0.98 }
            strokeColor = { 0.99, 0.78, 0.32, 1 }
        elseif buttonRect.id == "clone_map" and selectedMap then
            fillColor = { 0.12, 0.17, 0.2, 0.98 }
            strokeColor = { 0.56, 0.72, 0.98, 1 }
        elseif buttonRect.id == "back" then
            fillColor = { 0.1, 0.12, 0.15, 0.98 }
            strokeColor = { 0.3, 0.42, 0.54, 1 }
            font = game.fonts.small
        elseif buttonRect.id == "upload_map" then
            fillColor = { 0.12, 0.17, 0.2, 0.98 }
            strokeColor = { 0.48, 0.72, 0.92, 1 }
        elseif buttonRect.id == "download_map" and selectedMap then
            fillColor = { 0.12, 0.17, 0.2, 0.98 }
            strokeColor = { 0.48, 0.92, 0.62, 1 }
        elseif buttonRect.id == "refresh_marketplace" then
            fillColor = { 0.12, 0.17, 0.2, 0.98 }
            strokeColor = { 0.56, 0.72, 0.98, 1 }
        end

        drawButton(buttonRect, buttonRect.label, fillColor, strokeColor, font, isDisabled)
    end

    if game.levelSelectActionState and game.levelSelectActionState.message then
        local bottomBarRect = getLevelSelectBottomBarRect(game)
        local actionStatus = game.levelSelectActionState
        local statusText = safeUiText(actionStatus.message, "Status message unavailable.")
        local statusColor = PANEL_COLORS.bodyText
        if actionStatus.status == "success" then
            statusColor = { 0.48, 0.92, 0.62, 1 }
        elseif actionStatus.status == "error" then
            statusColor = { 0.99, 0.78, 0.32, 1 }
        end

        love.graphics.setFont(game.fonts.small)
        local toastMaxWidth = math.min(game.viewport.w - 56, 760)
        local toastTextWidth = toastMaxWidth - 28
        local lineCount = getWrappedLineCount(game.fonts.small, statusText, toastTextWidth)
        local toastHeight = (lineCount * game.fonts.small:getHeight()) + 14
        local toastY = bottomBarRect.y - toastHeight - 10
        local toastWidth = toastMaxWidth
        local toastX = math.floor((game.viewport.w - toastWidth) * 0.5 + 0.5)

        graphics.setColor(0.02, 0.03, 0.04, 0.82)
        graphics.rectangle("fill", toastX, toastY, toastWidth, toastHeight, 14, 14)
        graphics.setColor(0.18, 0.22, 0.26, 0.92)
        graphics.rectangle("line", toastX, toastY, toastWidth, toastHeight, 14, 14)

        graphics.setColor(statusColor[1], statusColor[2], statusColor[3], statusColor[4] or 1)
        graphics.printf(
            statusText,
            toastX + 14,
            toastY + 7,
            toastTextWidth,
            "center"
        )
    end

    if game.levelSelectIssue then
        local overlay = getLevelIssueOverlayRects(game)
        local issue = game.levelSelectIssue

        graphics.setColor(0, 0, 0, 0.62)
        graphics.rectangle("fill", 0, 0, game.viewport.w, game.viewport.h)

        graphics.setColor(0.09, 0.11, 0.15, 0.98)
        graphics.rectangle("fill", overlay.panel.x, overlay.panel.y, overlay.panel.w, overlay.panel.h, 18, 18)
        graphics.setColor(0.3, 0.36, 0.42, 1)
        graphics.rectangle("line", overlay.panel.x, overlay.panel.y, overlay.panel.w, overlay.panel.h, 18, 18)

        love.graphics.setFont(game.fonts.title)
        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.printf("Map Has Issues", overlay.panel.x, overlay.panel.y + 20, overlay.panel.w, "center")

        love.graphics.setFont(game.fonts.body)
        graphics.setColor(0.99, 0.78, 0.32, 1)
        graphics.printf(safeUiText(issue.map and issue.map.name, "Untitled Map"), overlay.panel.x + 24, overlay.panel.y + 74, overlay.panel.w - 48, "center")

        love.graphics.setFont(game.fonts.small)
        graphics.setColor(0.84, 0.88, 0.92, 1)
        graphics.printf(
            "Fix these issues in the editor before this run can start:",
            overlay.panel.x + 30,
            overlay.panel.y + 114,
            overlay.panel.w - 60,
            "left"
        )

        local errorY = overlay.panel.y + 146
        local maxErrors = math.min(5, #(issue.errors or {}))
        for index = 1, maxErrors do
            local message = issue.errors[index]
            graphics.setColor(0.99, 0.78, 0.32, 1)
            graphics.print(string.format("%d.", index), overlay.panel.x + 34, errorY)
            graphics.setColor(0.84, 0.88, 0.92, 1)
            graphics.printf(message, overlay.panel.x + 58, errorY, overlay.panel.w - 92)
            local lineCount = getWrappedLineCount(game.fonts.small, message, overlay.panel.w - 92)
            errorY = errorY + math.max(game.fonts.small:getHeight(), lineCount * game.fonts.small:getHeight()) + 8
        end

        if #(issue.errors or {}) > maxErrors then
            graphics.setColor(0.68, 0.74, 0.8, 1)
            graphics.printf(
                string.format("%d more issue(s) hidden here. Open the editor for the full list.", #(issue.errors or {}) - maxErrors),
                overlay.panel.x + 30,
                overlay.panel.y + 262,
                overlay.panel.w - 60,
                "center"
            )
        end

        drawButton(overlay.edit, "Open In Editor", { 0.1, 0.14, 0.18, 0.98 }, { 0.99, 0.78, 0.32, 1 }, game.fonts.small)
        drawButton(overlay.cancel, "Cancel", { 0.1, 0.14, 0.18, 0.98 }, { 0.3, 0.36, 0.42, 1 }, game.fonts.small)
    end

    if game.levelSelectHoverInfo and not game.levelSelectIssue then
        drawPlayTooltip(game, game.levelSelectHoverInfo)
    end
end

function ui.drawPlay(game)
    local graphics = love.graphics
    local runSummary = game.world:getRunSummary()
    local inputGroups = game.world:getInputEdgeGroups()
    local outputGroups = game.world:getOutputBadgeGroups()
    local scorePanel = {
        x = math.floor(game.viewport.w - 274 + 0.5),
        y = math.floor(game.viewport.h * 0.5 - 52 + 0.5),
        w = 236,
        h = 104,
    }

    graphics.setColor(0.08, 0.1, 0.13, 0.94)
    graphics.rectangle("fill", scorePanel.x, scorePanel.y, scorePanel.w, scorePanel.h, 18, 18)
    graphics.setColor(0.3, 0.36, 0.42, 1)
    graphics.rectangle("line", scorePanel.x, scorePanel.y, scorePanel.w, scorePanel.h, 18, 18)

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.8, 0.84, 0.9, 0.95)
    graphics.printf("Score", scorePanel.x + 20, scorePanel.y + 18, scorePanel.w - 40, "left")

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf(formatScore(runSummary.finalScore or 0), scorePanel.x + 20, scorePanel.y + 44, scorePanel.w - 40, "left")

    for _, badge in ipairs(outputGroups) do
        drawOutputBadge(game, badge)
    end

    if game.playPhase == "prepare" then
        for _, group in ipairs(inputGroups) do
            drawInputPrepCard(game, group)
        end
    else
        for _, group in ipairs(inputGroups) do
            local nextTrain = game.world:getNextPendingTrainForInputEdge(group.edge.id)
            if nextTrain then
                drawInputLiveCard(game, group.edge, nextTrain)
            end
        end
    end

    drawButton(getPlayBackRect(game), getRunBackLabel(game), { 0.09, 0.11, 0.15, 0.98 }, { 0.3, 0.36, 0.42, 1 }, game.fonts.small)

    if game.playPhase == "prepare" then
        drawButton(getPlayStartRect(), "Start Run", { 0.12, 0.17, 0.2, 0.98 }, { 0.48, 0.92, 0.62, 1 }, game.fonts.body)
        love.graphics.setFont(game.fonts.small)
        graphics.setColor(0.84, 0.88, 0.92, 1)
        graphics.printf("Preparation Phase: set your routes, then start the clock.", 0, 34, game.viewport.w, "center")

        local blinkAlpha = 0.3
        if love and love.timer and love.timer.getTime then
            blinkAlpha = (math.sin(love.timer.getTime() * 4.8) > 0) and 1 or 0.3
        end
        graphics.setColor(1, 1, 1, blinkAlpha)
        graphics.printf("Press Spacebar to Start", 0, game.viewport.h - 86, game.viewport.w, "center")
    end

    graphics.setColor(0, 0, 0, 0.3)
    graphics.rectangle("fill", game.viewport.w - 286, game.viewport.h - 54, 250, 30, 15, 15)
    graphics.setColor(0.8, 0.84, 0.9, 0.82)
    graphics.printf(
        game.playPhase == "prepare"
            and string.format("Press F2 for help, F3 for debug, M for %s, E for editor, or R to reset prep", getRunBackLabel(game))
            or string.format("Press F2 for help, F3 for debug, M for %s, E for editor, or R to restart", getRunBackLabel(game)),
        0,
        game.viewport.h - 42,
        game.viewport.w,
        "center"
    )

    drawPlayInfoOverlay(game)
    if game.playPhase == "prepare" and not game.playOverlayMode and game.playHoverInfo then
        drawPlayTooltip(game, game.playHoverInfo)
    end
end

function ui.drawResults(game)
    local graphics = love.graphics
    local summary = game.resultsSummary or {}
    local level = game.world and game.world:getLevel() or {}
    local panel = {
        x = game.viewport.w * 0.5 - 300,
        y = 50,
        w = 600,
        h = 580,
    }
    local buttons = getResultsButtonRects(game)

    graphics.setColor(0.05, 0.07, 0.1, 1)
    graphics.rectangle("fill", 0, 0, game.viewport.w, game.viewport.h)
    graphics.setColor(0, 0, 0, 0.22)
    graphics.circle("fill", 190, 130, 170)
    graphics.circle("fill", 1080, 560, 210)

    graphics.setColor(0.09, 0.11, 0.15, 0.98)
    graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 20, 20)
    graphics.setColor(0.26, 0.34, 0.42, 1)
    graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h, 20, 20)

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)
    local title = "Level Clear"
    local accent = { 0.48, 0.92, 0.62, 1 }
    if summary.endReason == "collision" then
        title = "Collision"
        accent = { 0.97, 0.36, 0.3, 1 }
    elseif summary.endReason == "timeout" then
        title = "Time Up"
        accent = { 0.99, 0.83, 0.44, 1 }
    end
    graphics.printf(title, panel.x, panel.y + 24, panel.w, "center")

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.84, 0.88, 0.92, 1)
    graphics.printf(level.title or "Run Results", panel.x, panel.y + 74, panel.w, "center")

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(accent[1], accent[2], accent[3], 1)
    graphics.printf(string.format("Score %s", formatScore(summary.finalScore or 0)), panel.x, panel.y + 108, panel.w, "center")

    love.graphics.setFont(game.fonts.small)
    local onlineState = game.resultsOnlineState or {}
    local onlineColor = { 0.72, 0.78, 0.84, 1 }
    if onlineState.status == "submitted" or onlineState.status == "kept" then
        onlineColor = { 0.48, 0.92, 0.62, 1 }
    elseif onlineState.status == "error" or onlineState.status == "disabled" then
        onlineColor = { 0.99, 0.78, 0.32, 1 }
    end
    graphics.setColor(onlineColor[1], onlineColor[2], onlineColor[3], onlineColor[4])
    graphics.printf(
        onlineState.message or (game:isOfflineMode() and "Local score pending." or "Online sync pending."),
        panel.x + 38,
        panel.y + 158,
        panel.w - 76,
        "center"
    )

    local breakdownX = panel.x + 58
    local valueX = panel.x + panel.w - 58
    local lineY = panel.y + 220
    local rows = {
        { "On-time clears", string.format("+%s", formatScore((summary.scoreBreakdown and summary.scoreBreakdown.onTimeClears) or 0)) },
        { "Late clears", string.format("+%s", formatScore((summary.scoreBreakdown and summary.scoreBreakdown.lateClears) or 0)) },
        { "Time penalty", string.format("-%s", formatScore((summary.scoreBreakdown and summary.scoreBreakdown.timePenalty) or 0)) },
        { "Interaction penalty", string.format("-%s", formatScore((summary.scoreBreakdown and summary.scoreBreakdown.interactionPenalty) or 0)) },
        { "Distance penalty", string.format("-%s", formatScore((summary.scoreBreakdown and summary.scoreBreakdown.extraDistancePenalty) or 0)) },
    }

    for _, row in ipairs(rows) do
        graphics.setColor(0.84, 0.88, 0.92, 1)
        graphics.print(row[1], breakdownX, lineY)
        graphics.printf(row[2], valueX - 140, lineY, 140, "right")
        lineY = lineY + 28
    end

    lineY = lineY + 20
    local stats = {
        string.format("On-time trains: %d", summary.correctOnTimeCount or 0),
        string.format("Late trains: %d", summary.correctLateCount or 0),
        string.format("Wrong destinations: %d", summary.wrongDestinationCount or 0),
        string.format("Elapsed time: %.1fs", summary.elapsedSeconds or 0),
        string.format("Interactions: %d", summary.interactionCount or 0),
        string.format("Map UUID: %s", summary.mapUuid or "n/a"),
    }

    for _, stat in ipairs(stats) do
        graphics.setColor(0.72, 0.78, 0.84, 1)
        graphics.print(stat, breakdownX, lineY)
        lineY = lineY + 26
    end

    drawButton(buttons.replay, "Replay", { 0.1, 0.14, 0.18, 0.98 }, { 0.48, 0.92, 0.62, 1 }, game.fonts.small)
    drawButton(
        buttons.leaderboard,
        game:isOfflineMode() and "Scores" or "Leaderboard",
        { 0.1, 0.14, 0.18, 0.98 },
        { 0.56, 0.72, 0.98, 1 },
        game.fonts.small
    )
    drawButton(buttons.editor, "Open In Editor", { 0.1, 0.14, 0.18, 0.98 }, { 0.99, 0.78, 0.32, 1 }, game.fonts.small)
    drawButton(buttons.menu, getRunBackLabel(game), { 0.1, 0.14, 0.18, 0.98 }, { 0.3, 0.36, 0.42, 1 }, game.fonts.small)
end

ui.formatLeaderboardScore = formatLeaderboardScore
ui.formatLeaderboardRecordedAt = formatLeaderboardRecordedAt
ui.formatLeaderboardEntryTimestamp = formatLeaderboardEntryTimestamp
ui.formatLevelSelectLeaderboardPlayerName = formatLevelSelectLeaderboardPlayerName
ui.formatLeaderboardRefreshLabel = formatLeaderboardRefreshLabel
ui.formatLevelSelectLeaderboardRefreshLabel = formatLevelSelectLeaderboardRefreshLabel
ui.getLevelSelectLeaderboardVisibleEntries = getLevelSelectLeaderboardVisibleEntries
ui.getLevelSelectLeaderboardPinnedRowY = getLevelSelectLeaderboardPinnedRowY
ui.formatMarketplaceFavoriteLabel = formatMarketplaceFavoriteLabel
ui.getLevelSelectBadges = buildLevelSelectBadges

return ui
