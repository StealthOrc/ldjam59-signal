local ui = {}
local uiControls = require("src.game.ui_controls")

local LEVEL_SELECT = {
    chromeH = 74,
    titleBarY = 100,
    titleBarH = 74,
    carouselCenterY = 354,
    cardBaseW = 292,
    cardBaseH = 286,
    sideLift = 46,
    filterW = 536,
    filterH = 42,
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
    titleMetaTop = 48,
}
local MARKETPLACE_REMOTE_SOURCE = "remote"
local MARKETPLACE_REMOTE_CATEGORY_USERS = "users"

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
    delayed = "Timer",
    pump = "Charge",
    spring = "Spring",
    relay = "Relay",
    trip = "Trip",
    crossbar = "Cross",
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

local LEADERBOARD_LOADING = {
    spinnerRadius = 18,
    spinnerThickness = 4,
    spinnerArcLength = math.pi * 1.35,
    spinnerSpeed = 3.2,
    emptyStateYOffset = 180,
    emptySpinnerYOffset = 34,
    emptyTextYOffset = 68,
}

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
    mapWidth = 260,
    playerXOffset = 52,
    playerRightPadding = 36,
    scoreWidth = 120,
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
}

local function pointInRect(x, y, rect)
    return x >= rect.x
        and x <= rect.x + rect.w
        and y >= rect.y
        and y <= rect.y + rect.h
end

local function lerp(a, b, t)
    return a + ((b - a) * t)
end

local function trim(value)
    return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
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

local function formatScore(value)
    local formatted = string.format("%.2f", value or 0)
    formatted = formatted:gsub("(%..-)0+$", "%1")
    formatted = formatted:gsub("%.$", "")
    return formatted
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

local function getLeaderboardContentLayout(game)
    local panel = getLeaderboardPanelRect(game)
    local contentX = panel.x + LEADERBOARD_LAYOUT.contentPadding
    local contentW = panel.w - (LEADERBOARD_LAYOUT.contentPadding * 2)
    local scoreX = contentX + math.floor((contentW - LEADERBOARD_LAYOUT.scoreWidth) * 0.5 + 0.5)
    local mapX = scoreX + LEADERBOARD_LAYOUT.scoreWidth + LEADERBOARD_LAYOUT.mapGap
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
    local maxEntries = math.min(12, #(entries or {}))
    local rowY = layout.panel.y + LEADERBOARD_LAYOUT.headerY + LEADERBOARD_LAYOUT.rowYOffset

    for index = 1, maxEntries do
        local entry = entries[index]
        local rowRect = {
            entry = entry,
            row = {
                x = layout.contentX,
                y = rowY - 6,
                w = layout.contentW,
                h = LEADERBOARD_LAYOUT.rowHeight,
            },
            player = {
                x = layout.playerX,
                y = rowY,
                w = layout.playerWidth,
                h = game.fonts.small:getHeight() + 8,
            },
            map = shouldShowLeaderboardMapColumn(game) and {
                x = layout.mapX,
                y = rowY,
                w = LEADERBOARD_LAYOUT.mapWidth,
                h = game.fonts.small:getHeight() + 8,
            } or nil,
        }

        rects[#rects + 1] = rowRect
        rowY = rowY + LEADERBOARD_LAYOUT.rowHeight + LEADERBOARD_LAYOUT.rowGap
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
    local controlLines = {
        "Left click a junction to activate its control.",
        "Left click the selector below a junction to cycle outputs forward.",
        "Right click the selector below a junction to cycle outputs backward.",
        "M opens the menu. E opens the editor. R restarts the run.",
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

    for index, descriptor in ipairs(maps or {}) do
        if descriptor.id == game.levelSelectSelectedId then
            return index
        end
    end

    if fallbackIndex then
        game.levelSelectSelectedId = maps[fallbackIndex].id
    else
        game.levelSelectSelectedId = nil
    end

    return fallbackIndex
end

local function getLevelSelectChromeRect(game)
    return {
        x = 2,
        y = 2,
        w = game.viewport.w - 4,
        h = LEVEL_SELECT.chromeH,
    }
end

local function getLevelSelectBottomBarRect(game)
    return {
        x = 2,
        y = LEVEL_SELECT.bottomBarY,
        w = game.viewport.w - 4,
        h = LEVEL_SELECT.bottomBarH,
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
    local chromeRect = getLevelSelectChromeRect(game)
    return {
        x = math.floor(game.viewport.w * 0.5 - MARKETPLACE_LAYOUT.searchW * 0.5 + 0.5),
        y = chromeRect.y + math.floor((chromeRect.h - MARKETPLACE_LAYOUT.searchH) * 0.5 + 0.5),
        w = MARKETPLACE_LAYOUT.searchW,
        h = MARKETPLACE_LAYOUT.searchH,
    }
end

local function getLevelSelectModeButtonRect(game)
    for _, button in ipairs(getLevelSelectActionButtons(game)) do
        if button.id == "toggle_mode" then
            return button
        end
    end

    return nil
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
            entries[#entries + 1] = {
                descriptor = descriptor,
                title = displayName,
                subtitle = string.format("%s  |  %s", kindLabel, controlsSummary),
                creatorDisplayName = tostring(sourceEntry.creator_display_name or "Unknown"),
                creatorUuid = tostring(sourceEntry.creator_uuid or ""),
                favoriteCount = tonumber(sourceEntry.favorite_count or 0) or 0,
                internalIdentifier = tostring(sourceEntry.internal_identifier or ""),
                featuredWeight = tonumber(sourceEntry.favorite_count or 0) or 0,
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
    local controls = getMapControlTypes(descriptor)
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

    for _, controlType in ipairs(controls) do
        local label = CONTROL_SHORT_LABELS[controlType] or controlType
        local appended = appendBadge({
            controlType = controlType,
            label = label,
            width = font:getWidth(label) + 22,
        })
        if not appended then
            break
        end
    end

    return badges, totalWidth
end

local function getLevelSelectBackRect(game)
    local chromeRect = getLevelSelectChromeRect(game)
    return {
        x = 24,
        y = chromeRect.y + math.floor((chromeRect.h - 40) * 0.5 + 0.5),
        w = 120,
        h = 40,
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
    local panelTop = LEVEL_SELECT.bottomBarY
    local selectedCardRect = getSettledSelectedCardRect(game)
    local selectedBottom = selectedCardRect.y + selectedCardRect.h
    local centerY = math.floor((selectedBottom + panelTop) * 0.5 + 0.5)

    return {
        x = math.floor(game.viewport.w * 0.5 - LEVEL_SELECT.filterW * 0.5 + 0.5),
        y = centerY - math.floor(LEVEL_SELECT.filterH * 0.5 + 0.5),
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
    local buttonSpecs

    if game.levelSelectMode == "marketplace" then
        buttonSpecs = {
            { id = "download_map", label = "Download", w = LEVEL_SELECT_ACTION_LAYOUT.downloadW },
            { id = "refresh_marketplace", label = "Refresh", w = LEVEL_SELECT_ACTION_LAYOUT.refreshW },
            { id = "toggle_mode", label = "Local Maps", w = LEVEL_SELECT_ACTION_LAYOUT.toggleW },
        }
    else
        local editButtonId = "edit_map"
        local editButtonLabel = "Edit"
        if selectedMap and selectedMap.isRemoteImport then
            editButtonId = "clone_map"
            editButtonLabel = "Clone"
        end

        buttonSpecs = {
            { id = "open_map", label = "Start", w = LEVEL_SELECT_ACTION_LAYOUT.startW },
            { id = editButtonId, label = editButtonLabel, w = LEVEL_SELECT_ACTION_LAYOUT.editW },
            { id = "toggle_mode", label = "Online Maps", w = LEVEL_SELECT_ACTION_LAYOUT.toggleW },
        }

        if selectedMap and game:isUploadSelectedMapAvailable(selectedMap) then
            buttonSpecs[#buttonSpecs + 1] = {
                id = "upload_map",
                label = "Upload",
                w = LEVEL_SELECT_ACTION_LAYOUT.uploadW,
            }
        end
    end

    local totalWidth = 0
    for index, spec in ipairs(buttonSpecs) do
        totalWidth = totalWidth + spec.w
        if index > 1 then
            totalWidth = totalWidth + LEVEL_SELECT_ACTION_LAYOUT.buttonGap
        end
    end

    local currentX = math.floor(game.viewport.w * 0.5 - totalWidth * 0.5 + 0.5)
    local buttons = {}
    for _, spec in ipairs(buttonSpecs) do
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

            local badgeGap = 12
            local badgeH = 22
            local badgeWidths, badgeTotalWidth = buildCardBadges(game, descriptor, width - 36)
            local badgeBottomPadding = 18
            local badgeY = y + height - badgeH - badgeBottomPadding
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
                widths = badgeWidths,
                totalWidth = badgeTotalWidth,
            }
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

    if badgeRow and badgeRow.widths then
        widths = badgeRow.widths
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

local function drawLevelSelectChrome(game)
    local graphics = love.graphics
    local chromeRect = getLevelSelectChromeRect(game)
    local bottomBarRect = getLevelSelectBottomBarRect(game)
    graphics.setColor(0.08, 0.12, 0.18, 0.82)
    graphics.circle("fill", 164, 188, 168)
    graphics.circle("fill", 1082, 274, 214)
    graphics.circle("fill", 1014, 628, 178)

    graphics.setColor(0.18, 0.26, 0.34, 0.5)
    graphics.setLineWidth(2)
    graphics.setLineWidth(1)

    drawMetalPanel(chromeRect, 0.98)
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
    local barRect = {
        x = 118,
        y = LEVEL_SELECT.titleBarY,
        w = 1044,
        h = LEVEL_SELECT.titleBarH,
    }

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
        tostring(entry.playerDisplayName or "Unknown"),
        nameX,
        rowRect.y + 4,
        math.max(0, nameWidth),
        "left"
    )

    graphics.printf(
        formatScore(entry.score or 0),
        rowRect.x + rowRect.w - LEVEL_SELECT_LEADERBOARD_CARD.scoreWidth - LEVEL_SELECT_LEADERBOARD_CARD.rowPaddingX,
        rowRect.y + 4,
        LEVEL_SELECT_LEADERBOARD_CARD.scoreWidth,
        "right"
    )
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
    local topEntries = previewState.topEntries or {}
    local pinnedPlayerEntry = previewState.pinnedPlayerEntry
    local rowY = contentRect.y + LEVEL_SELECT_LEADERBOARD_CARD.rowTop

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(PANEL_COLORS.titleText[1], PANEL_COLORS.titleText[2], PANEL_COLORS.titleText[3], PANEL_COLORS.titleText[4])
    graphics.printf("Leaderboard", contentRect.x, contentRect.y + LEVEL_SELECT_LEADERBOARD_CARD.titleTop, contentRect.w, "center")

    for index, entry in ipairs(topEntries) do
        local rowRect = {
            x = contentRect.x,
            y = rowY,
            w = contentRect.w,
            h = LEVEL_SELECT_LEADERBOARD_CARD.rowHeight,
        }
        local isPlayerEntry = tostring(entry.playerUuid or "") == tostring(game.profile and game.profile.playerId or "")
        drawLevelSelectLeaderboardRow(game, rowRect, entry, isPlayerEntry)
        rowY = rowY + LEVEL_SELECT_LEADERBOARD_CARD.rowHeight + LEVEL_SELECT_LEADERBOARD_CARD.rowGap
        if index >= LEVEL_SELECT_LEADERBOARD_CARD.maxRows then
            break
        end
    end

    if pinnedPlayerEntry then
        local pinnedRowRect = {
            x = contentRect.x,
            y = contentRect.y + contentRect.h - LEVEL_SELECT_LEADERBOARD_CARD.rowHeight,
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
    elseif previewState.message then
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
end

local function drawLevelCard(game, rect)
    local graphics = love.graphics
    local descriptor = rect.map
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
            label = "Online Leaderboard",
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
            id = "quit",
            x = centerX,
            y = buttonY + ((MENU_LAYOUT.buttonHeight + MENU_LAYOUT.buttonGap) * 3),
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

    local modeButtonRect = getLevelSelectModeButtonRect(game)
    if modeButtonRect and pointInRect(x, y, modeButtonRect) then
        if modeButtonRect.id == "toggle_mode" and game.levelSelectMode ~= "marketplace" and not game:isOnlineMapsAvailable() then
            return nil
        end
        return { kind = "toggle_mode" }
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
            if buttonRect.id ~= "toggle_mode" and pointInRect(x, y, buttonRect) then
                return {
                    kind = buttonRect.id,
                    map = selectedMarketplaceMap,
                }
            end
        end
        for _, rect in ipairs(buildLevelSelectCardRects(game)) do
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
        if buttonRect.id ~= "toggle_mode" and pointInRect(x, y, buttonRect) then
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

    return nil
end

local function getPlayBackRect()
    return {
        x = 1114,
        y = 28,
        w = 134,
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

local function getInputPrepCardRect(game, edge, trainCount)
    local rowCount = math.max(1, trainCount or 0)
    local height = 20 + rowCount * 44
    local width = 140

    for _, group in ipairs(game.world:getInputEdgeGroups()) do
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
    local centerY = rowRect.y + rowRect.h * 0.5

    graphics.setColor(0.06, 0.08, 0.1, 0.96)
    graphics.rectangle("fill", rowRect.x, rowRect.y, rowRect.w, rowRect.h, 10, 10)
    graphics.setColor(0.24, 0.32, 0.4, 1)
    graphics.setLineWidth(1.1)
    graphics.rectangle("line", rowRect.x, rowRect.y, rowRect.w, rowRect.h, 10, 10)

    love.graphics.setFont(game.fonts.small)
    local leadWidth = game.fonts.small:getWidth(leadText)
    local deadlineWidth = deadlineText and game.fonts.small:getWidth(deadlineText) or 0
    local contentStartX = rowRect.x + PREP_TRAIN_ROW_SPACING

    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.print(leadText, contentStartX, rowRect.y + 9)

    local nextX = contentStartX + leadWidth + PREP_TRAIN_ROW_SPACING
    if deadlineText then
        local arrowStartX = nextX
        local arrowEndX = arrowStartX + PREP_TRAIN_ARROW_LENGTH
        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.setLineWidth(2)
        graphics.line(arrowStartX, centerY, arrowEndX, centerY)
        graphics.line(arrowEndX - 4, centerY - 3, arrowEndX, centerY)
        graphics.line(arrowEndX - 4, centerY + 3, arrowEndX, centerY)
        graphics.setLineWidth(1)
        nextX = arrowEndX + PREP_TRAIN_ROW_SPACING
        graphics.print(deadlineText, nextX, rowRect.y + 9)
        nextX = nextX + deadlineWidth + PREP_TRAIN_ROW_SPACING
    end

    drawPrepTrainPreview(game, nextX, centerY, train)
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

function ui.getPlayBackHit(_, x, y)
    return pointInRect(x, y, getPlayBackRect())
end

function ui.getPlayStartHit(game, x, y)
    if game.playPhase ~= "prepare" then
        return false
    end

    return pointInRect(x, y, getPlayStartRect())
end

local function getResultsButtonRects(game)
    local panelX = game.viewport.w * 0.5 - 240
    local buttonY = game.viewport.h - 72
    return {
        replay = { x = panelX, y = buttonY, w = 112, h = 42 },
        leaderboard = { x = panelX + 128, y = buttonY, w = 112, h = 42 },
        editor = { x = panelX + 256, y = buttonY, w = 112, h = 42 },
        menu = { x = panelX + 384, y = buttonY, w = 112, h = 42 },
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
        "Route trains through lever-controlled merges, upload cleared scores, and compare runs online.",
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
    graphics.printf("Enter starts. L opens the leaderboard. D toggles debug mode. Esc quits.", 0, MENU_LAYOUT.footerY, game.viewport.w, "center")
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
    graphics.printf("Enter the name to use in the leaderboard.", panel.x + 42, panel.y + 84, panel.w - 84, "center")

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
        return
    end

    if not hasEntries then
        love.graphics.setFont(game.fonts.body)
        graphics.setColor(0.84, 0.88, 0.92, 1)
        graphics.printf(state.message or "No entries are available yet.", contentX, panel.y + 180, contentW, "center")
        return
    end

    local headerY = panel.y + LEADERBOARD_LAYOUT.headerY
    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.68, 0.74, 0.8, 1)
    graphics.print("#", contentX, headerY)
    graphics.print("Player", layout.playerX, headerY)
    graphics.printf("Score", layout.scoreX, headerY, LEADERBOARD_LAYOUT.scoreWidth, "center")
    if shouldShowLeaderboardMapColumn(game) then
        graphics.printf("Latest Map", layout.mapX, headerY, LEADERBOARD_LAYOUT.mapWidth, "left")
    end

    local rowRects = buildLeaderboardRowRects(game, state.entries or {})
    for _, rowRect in ipairs(rowRects) do
        local entry = rowRect.entry
        local rowY = rowRect.player.y
        graphics.setColor(0.1, 0.13, 0.17, 0.94)
        graphics.rectangle("fill", rowRect.row.x, rowRect.row.y, rowRect.row.w, rowRect.row.h, LEADERBOARD_LAYOUT.rowRadius, LEADERBOARD_LAYOUT.rowRadius)
        graphics.setColor(0.26, 0.34, 0.42, 1)
        graphics.rectangle("line", rowRect.row.x, rowRect.row.y, rowRect.row.w, rowRect.row.h, LEADERBOARD_LAYOUT.rowRadius, LEADERBOARD_LAYOUT.rowRadius)

        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.print(tostring(entry.rank or 0), contentX + 12, rowY + 2)
        graphics.printf(entry.playerDisplayName or "Unknown", rowRect.player.x, rowY + 2, rowRect.player.w, "left")
        graphics.printf(formatScore(entry.score or 0), layout.scoreX, rowY + 2, LEADERBOARD_LAYOUT.scoreWidth, "center")
        if rowRect.map then
            graphics.setColor(0.72, 0.78, 0.84, 1)
            graphics.printf(entry.mapName or "Unknown Map", rowRect.map.x, rowY + 2, rowRect.map.w, "left")
        end
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

    drawLeaderboardTooltip(game, game.leaderboardHoverInfo)
end

function ui.drawLevelSelect(game)
    local graphics = love.graphics
    local maps = getLevelSelectMaps(game)
    local selectedIndex = getSelectedMapIndex(game, maps)
    local selectedMap = selectedIndex and maps[selectedIndex] or nil
    local cardRects = buildLevelSelectCardRects(game)
    local actionButtons = getLevelSelectActionButtons(game)
    local selectionRect = game.levelSelectMode == "marketplace" and getMarketplaceTabsRect(game) or getLevelSelectFilterRect(game)
    local selectionSegments = game.levelSelectMode == "marketplace" and getMarketplaceTabSegments() or getLevelSelectFilterSegments()
    local selectionValue = game.levelSelectMode == "marketplace" and (game.levelSelectMarketplaceTab or "top") or (game.levelSelectFilter or "all")

    graphics.setColor(PANEL_COLORS.background[1], PANEL_COLORS.background[2], PANEL_COLORS.background[3], PANEL_COLORS.background[4])
    graphics.rectangle("fill", 0, 0, game.viewport.w, game.viewport.h)

    drawLevelSelectChrome(game)
    drawLevelSelectTitleBar(game, selectedMap)

    drawButton(getLevelSelectBackRect(game), "Back", { 0.12, 0.15, 0.19, 0.98 }, { 0.3, 0.42, 0.54, 1 }, game.fonts.small)

    for _, cardRect in ipairs(cardRects) do
        drawLevelCard(game, cardRect)
    end

    if #maps == 0 then
        drawLevelSelectEmptyState(game, game.levelSelectMode == "marketplace" and "marketplace" or (game.levelSelectFilter or "all"))
    end

    uiControls.drawSegmentedToggle(
        selectionRect,
        selectionSegments,
        selectionValue,
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
        elseif buttonRect.id == "toggle_mode" then
            if game.levelSelectMode ~= "marketplace" and not game:isOnlineMapsAvailable() then
                fillColor = { 0.08, 0.1, 0.12, 0.98 }
                strokeColor = { 0.2, 0.24, 0.28, 1 }
                isDisabled = true
            else
                fillColor = { 0.12, 0.17, 0.2, 0.98 }
                strokeColor = { 0.56, 0.72, 0.98, 1 }
            end
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
        local statusColor = PANEL_COLORS.bodyText
        if actionStatus.status == "success" then
            statusColor = { 0.48, 0.92, 0.62, 1 }
        elseif actionStatus.status == "error" then
            statusColor = { 0.99, 0.78, 0.32, 1 }
        end

        love.graphics.setFont(game.fonts.small)
        graphics.setColor(statusColor[1], statusColor[2], statusColor[3], statusColor[4] or 1)
        graphics.printf(
            actionStatus.message,
            0,
            bottomBarRect.y - 26,
            game.viewport.w,
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
        graphics.printf(issue.map.name, overlay.panel.x + 24, overlay.panel.y + 74, overlay.panel.w - 48, "center")

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

    drawButton(getPlayBackRect(), "Main Menu", { 0.09, 0.11, 0.15, 0.98 }, { 0.3, 0.36, 0.42, 1 }, game.fonts.small)

    if game.playPhase == "prepare" then
        drawButton(getPlayStartRect(), "Start Run", { 0.12, 0.17, 0.2, 0.98 }, { 0.48, 0.92, 0.62, 1 }, game.fonts.body)
        love.graphics.setFont(game.fonts.small)
        graphics.setColor(0.84, 0.88, 0.92, 1)
        graphics.printf("Preparation Phase: set your routes, then start the clock.", 0, 34, game.viewport.w, "center")
    end

    graphics.setColor(0, 0, 0, 0.3)
    graphics.rectangle("fill", game.viewport.w - 286, game.viewport.h - 54, 250, 30, 15, 15)
    graphics.setColor(0.8, 0.84, 0.9, 0.82)
    graphics.printf(
        game.playPhase == "prepare"
            and "Press F2 for help, F3 for debug, M for menu, E for editor, or R to reset prep"
            or "Press F2 for help, F3 for debug, M for menu, E for editor, or R to restart",
        0,
        game.viewport.h - 42,
        game.viewport.w,
        "center"
    )

    drawPlayInfoOverlay(game)
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
    graphics.printf(onlineState.message or "Online sync pending.", panel.x + 38, panel.y + 158, panel.w - 76, "center")

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
    drawButton(buttons.leaderboard, "Leaderboard", { 0.1, 0.14, 0.18, 0.98 }, { 0.56, 0.72, 0.98, 1 }, game.fonts.small)
    drawButton(buttons.editor, "Open In Editor", { 0.1, 0.14, 0.18, 0.98 }, { 0.99, 0.78, 0.32, 1 }, game.fonts.small)
    drawButton(buttons.menu, "Main Menu", { 0.1, 0.14, 0.18, 0.98 }, { 0.3, 0.36, 0.42, 1 }, game.fonts.small)
end

return ui
