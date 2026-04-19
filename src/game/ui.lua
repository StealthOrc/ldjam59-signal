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

local PLAY_OVERLAY = {
    margin = 24,
    width = 420,
    padding = 18,
    radius = 18,
    lineGap = 6,
    sectionGap = 14,
}

local PLAY_HEADER = {
    x = 22,
    y = 20,
    paddingX = 18,
    paddingY = 12,
    titleGap = 14,
    rowGap = 8,
    radius = 18,
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

local function drawButton(rect, label, fillColor, strokeColor, font)
    local graphics = love.graphics
    graphics.setColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 1)
    graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 16, 16)
    graphics.setColor(strokeColor[1], strokeColor[2], strokeColor[3], strokeColor[4] or 1)
    graphics.setLineWidth(2)
    graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 16, 16)
    love.graphics.setFont(font)
    graphics.setColor(0.97, 0.98, 1, 1)
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
        { id = "user", label = "User" },
    }
end

local function getLevelSelectMaps(game)
    local maps = {}
    local filterId = game.levelSelectFilter or "all"

    for _, mapKind in ipairs({ "tutorial", "campaign", "user" }) do
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

local function appendUniqueControl(controls, seen, controlType)
    if controlType and not seen[controlType] then
        seen[controlType] = true
        controls[#controls + 1] = controlType
    end
end

local function getMapControlTypes(descriptor)
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

local function getBadgeWidths(game, descriptor, maxWidth)
    local controls = getMapControlTypes(descriptor)
    local font = game.fonts.small
    local widths = {}
    local totalWidth = 0

    for index, controlType in ipairs(controls) do
        local label = CONTROL_SHORT_LABELS[controlType] or controlType
        local badgeWidth = font:getWidth(label) + 22
        local nextWidth = totalWidth + badgeWidth
        if index > 1 then
            nextWidth = nextWidth + 6
        end
        if nextWidth > maxWidth then
            break
        end
        widths[#widths + 1] = {
            controlType = controlType,
            label = label,
            width = badgeWidth,
        }
        totalWidth = nextWidth
    end

    return widths, totalWidth
end

local function getLevelSelectBackRect()
    return {
        x = 24,
        y = math.floor((LEVEL_SELECT.chromeH - 40) * 0.5 + 0.5),
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

local function getLevelSelectFilterRect(game)
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

local function getLevelSelectActionRects(game)
    local startWidth = 170
    local editWidth = 148
    local gap = 18
    local totalWidth = startWidth + editWidth + gap
    local startX = math.floor(game.viewport.w * 0.5 - totalWidth * 0.5 + 0.5)
    local buttonY = LEVEL_SELECT.bottomBarY + math.floor((LEVEL_SELECT.bottomBarH - 42) * 0.5 + 0.5)

    return {
        start = {
            x = startX,
            y = buttonY,
            w = startWidth,
            h = 42,
        },
        edit = {
            x = startX + startWidth + gap,
            y = buttonY,
            w = editWidth,
            h = 42,
        },
    }
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
            local badgeWidths, badgeTotalWidth = getBadgeWidths(game, descriptor, width - 36)
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
        widths, totalWidth = getBadgeWidths(game, descriptor, maxWidth)
    end

    local badgeX = x + math.floor((maxWidth - totalWidth) * 0.5 + 0.5)
    for _, badge in ipairs(widths) do
        local color = PREVIEW_COLORS.control[badge.controlType] or PREVIEW_COLORS.control.direct
        graphics.setColor(color[1], color[2], color[3], 0.96)
        graphics.rectangle("fill", badgeX, y, badge.width, 22, 11, 11)
        graphics.setColor(0.06, 0.08, 0.1, 0.4)
        graphics.rectangle("line", badgeX, y, badge.width, 22, 11, 11)
        graphics.setColor(0.08, 0.1, 0.14, 1)
        graphics.printf(badge.label, badgeX, y + 3, badge.width, "center")
        badgeX = badgeX + badge.width + 6
    end
end

local function drawLevelSelectChrome(game)
    local graphics = love.graphics
    graphics.setColor(0.08, 0.12, 0.18, 0.82)
    graphics.circle("fill", 164, 188, 168)
    graphics.circle("fill", 1082, 274, 214)
    graphics.circle("fill", 1014, 628, 178)

    graphics.setColor(0.18, 0.26, 0.34, 0.5)
    graphics.setLineWidth(2)
    graphics.setLineWidth(1)

    drawMetalPanel({ x = 2, y = 2, w = game.viewport.w - 4, h = LEVEL_SELECT.chromeH }, 0.98)
    drawMetalPanel({ x = 2, y = LEVEL_SELECT.bottomBarY, w = game.viewport.w - 4, h = LEVEL_SELECT.bottomBarH }, 0.98)
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

    if not selectedMap then
        return
    end

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(PANEL_COLORS.titleText[1], PANEL_COLORS.titleText[2], PANEL_COLORS.titleText[3], PANEL_COLORS.titleText[4])
    graphics.printf(getMapDisplayName(selectedMap), barRect.x + 30, barRect.y + 8, barRect.w - 60, "center")

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(PANEL_COLORS.bodyText[1], PANEL_COLORS.bodyText[2], PANEL_COLORS.bodyText[3], PANEL_COLORS.bodyText[4])
    graphics.printf(getMapKindLabel(selectedMap), barRect.x + 30, barRect.y + 48, barRect.w - 60, "center")
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

    drawMapPreview(descriptor, rect.previewRect)

    local badgeY = rect.badgeRow and rect.badgeRow.y or (rect.y + rect.h - 40)
    drawControlBadges(game, descriptor, rect.x + 18, badgeY, rect.w - 36, rect.badgeRow)
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
    if filterId == "user" then
        graphics.printf("Open the editor and save a map to have it show up here.", panel.x + 34, panel.y + 78, panel.w - 68, "center")
    else
        graphics.printf("Switch filters or pick All to browse the full level list.", panel.x + 34, panel.y + 78, panel.w - 68, "center")
    end
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
    local centerX = game.viewport.w * 0.5 - 160
    local buttons = {
        { id = "play", x = centerX, y = 280, w = 320, h = 56 },
        { id = "editor", x = centerX, y = 352, w = 320, h = 56 },
        { id = "quit", x = centerX, y = 424, w = 320, h = 56 },
    }

    for _, rect in ipairs(buttons) do
        if pointInRect(x, y, rect) then
            return rect.id
        end
    end

    return nil
end

function ui.getLevelSelectHit(game, x, y)
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

    if pointInRect(x, y, getLevelSelectBackRect()) then
        return { kind = "back" }
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
    local actionRects = getLevelSelectActionRects(game)

    if selectedMap and pointInRect(x, y, actionRects.start) then
        return { kind = "open_map", map = selectedMap }
    end
    if selectedMap and pointInRect(x, y, actionRects.edit) then
        return { kind = "edit_map", map = selectedMap }
    end

    for _, rect in ipairs(cardRects) do
        if pointInRect(x, y, rect) then
            if rect.selected then
                return { kind = "open_map", map = rect.map }
            end
            return { kind = "select_map", map = rect.map }
        end
    end

    return nil
end

function ui.getLevelSelectFilterHoverId(game, x, y)
    if game.levelSelectIssue then
        return nil
    end

    local filterRect = getLevelSelectFilterRect(game)
    if not pointInRect(x, y, filterRect) then
        return nil
    end

    local filterSegments = getLevelSelectFilterSegments()
    for index, segment in ipairs(filterSegments) do
        if pointInRect(x, y, uiControls.segmentRect(filterRect, index, #filterSegments)) then
            return segment.id
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

local function getInputLiveCardRect(game, edge)
    local anchorX, anchorY, dirX, dirY = getTrackOuterAnchor(edge, false)
    return getAnchoredPanelRect(game, anchorX, anchorY, dirX, dirY, 244, 82, 12)
end

local function getOutputBadgeRect(game, edge)
    local anchorX, anchorY, dirX, dirY = getTrackOuterAnchor(edge, true)
    return getAnchoredPanelRect(game, anchorX, anchorY, dirX, dirY, 132, 62, 12)
end

local PREP_TRAIN_ROW_SPACING = 8
local PREP_TRAIN_ARROW_LENGTH = 19

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
        local centerY = rowRect.y + rowRect.h * 0.5
        local startText = formatSecondsLabel(train.spawnTime or 0)
        local deadlineText = train.deadline ~= nil and formatSecondsLabel(train.deadline) or nil

        graphics.setColor(0.06, 0.08, 0.1, 0.96)
        graphics.rectangle("fill", rowRect.x, rowRect.y, rowRect.w, rowRect.h, 10, 10)
        graphics.setColor(0.24, 0.32, 0.4, 1)
        graphics.setLineWidth(1.1)
        graphics.rectangle("line", rowRect.x, rowRect.y, rowRect.w, rowRect.h, 10, 10)

        love.graphics.setFont(game.fonts.small)
        local startWidth = game.fonts.small:getWidth(startText)
        local deadlineWidth = deadlineText and game.fonts.small:getWidth(deadlineText) or 0
        local contentStartX = rowRect.x + PREP_TRAIN_ROW_SPACING

        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.print(startText, contentStartX, rowRect.y + 9)

        local nextX = contentStartX + startWidth + PREP_TRAIN_ROW_SPACING
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
        rowY = rowY + rowHeight + rowGap
    end
end

local function drawInputLiveCard(game, edge, train)
    local graphics = love.graphics
    local rect = getInputLiveCardRect(game, edge)
    local remainingSeconds = math.max(0, (train.spawnTime or 0) - (game.world.elapsedTime or 0))

    drawMetalPanel(rect, 0.96)

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf(edge.label or edge.id, rect.x + 12, rect.y + 10, rect.w - 24, "left")

    graphics.setColor(0.84, 0.88, 0.92, 1)
    graphics.printf(tostring(train.id or "--"), rect.x + 12, rect.y + 31, rect.w - 24, "left")
    graphics.printf(
        string.format("Line %s -> Goal %s", getColorLabel(train.lineColor), getColorLabel(train.goalColor or train.trainColor)),
        rect.x + 12,
        rect.y + 49,
        rect.w - 24,
        "left"
    )
    graphics.setColor(0.99, 0.78, 0.32, 1)
    graphics.printf(
        string.format("Arrives in %ss | Deadline %s", formatTimeValue(remainingSeconds), formatTimeValue(train.deadline)),
        rect.x + 12,
        rect.y + 65,
        rect.w - 24,
        "left"
    )
end

local function drawOutputBadge(game, badge)
    local graphics = love.graphics
    local rect = getOutputBadgeRect(game, badge.edge)

    drawMetalPanel(rect, 0.96)

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf(badge.edge.label or badge.edge.id, rect.x + 10, rect.y + 10, rect.w - 20, "center")

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.48, 0.92, 0.62, 1)
    graphics.printf(
        string.format("%d / %d", badge.deliveredCount or 0, badge.expectedCount or 0),
        rect.x,
        rect.y + 28,
        rect.w,
        "center"
    )
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
    local panelX = game.viewport.w * 0.5 - 250
    local buttonY = game.viewport.h - 72
    return {
        replay = { x = panelX, y = buttonY, w = 150, h = 42 },
        editor = { x = panelX + 175, y = buttonY, w = 150, h = 42 },
        menu = { x = panelX + 350, y = buttonY, w = 150, h = 42 },
    }
end

function ui.getResultsHit(game, x, y)
    local buttons = getResultsButtonRects(game)
    if pointInRect(x, y, buttons.replay) then
        return "replay"
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
    local centerX = game.viewport.w * 0.5 - 160
    local buttons = {
        {
            id = "play",
            x = centerX,
            y = 280,
            w = 320,
            h = 56,
            label = "Level Select",
        },
        {
            id = "editor",
            x = centerX,
            y = 352,
            w = 320,
            h = 56,
            label = "Map Editor",
        },
        {
            id = "quit",
            x = centerX,
            y = 424,
            w = 320,
            h = 56,
            label = "Quit",
        },
    }

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
        "Route trains through lever-controlled merges, or build your own maps and save them for later.",
        game.viewport.w * 0.5 - 280,
        188,
        560,
        "center"
    )

    for _, rect in ipairs(buttons) do
        drawButton(rect, rect.label, { 0.09, 0.11, 0.15, 0.98 }, { 0.48, 0.92, 0.62, 1 }, game.fonts.body)
    end

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.72, 0.78, 0.84, 1)
    graphics.printf("Enter opens level select. E opens the editor directly. Esc quits.", 0, 620, game.viewport.w, "center")
end

function ui.drawLevelSelect(game)
    local graphics = love.graphics
    local maps = getLevelSelectMaps(game)
    local selectedIndex = getSelectedMapIndex(game, maps)
    local selectedMap = selectedIndex and maps[selectedIndex] or nil
    local cardRects = buildLevelSelectCardRects(game)
    local actionRects = getLevelSelectActionRects(game)
    local filterRect = getLevelSelectFilterRect(game)
    local filterSegments = getLevelSelectFilterSegments()

    graphics.setColor(PANEL_COLORS.background[1], PANEL_COLORS.background[2], PANEL_COLORS.background[3], PANEL_COLORS.background[4])
    graphics.rectangle("fill", 0, 0, game.viewport.w, game.viewport.h)

    drawLevelSelectChrome(game)
    drawLevelSelectTitleBar(game, selectedMap)

    drawButton(getLevelSelectBackRect(), "Back", { 0.12, 0.15, 0.19, 0.98 }, { 0.3, 0.42, 0.54, 1 }, game.fonts.small)

    for _, cardRect in ipairs(cardRects) do
        drawLevelCard(game, cardRect)
    end

    if #maps == 0 then
        drawLevelSelectEmptyState(game, game.levelSelectFilter or "all")
    end

    uiControls.drawSegmentedToggle(
        filterRect,
        filterSegments,
        game.levelSelectFilter or "all",
        game.levelSelectFilterHoverId,
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

    if selectedMap then
        drawButton(actionRects.start, "Start", { 0.12, 0.17, 0.2, 0.98 }, { 0.48, 0.92, 0.62, 1 }, game.fonts.body)
        drawButton(actionRects.edit, "Edit", { 0.12, 0.17, 0.2, 0.98 }, { 0.99, 0.78, 0.32, 1 }, game.fonts.body)
    else
        drawButton(actionRects.start, "Start", { 0.1, 0.12, 0.15, 0.98 }, { 0.24, 0.3, 0.36, 1 }, game.fonts.body)
        drawButton(actionRects.edit, "Edit", { 0.1, 0.12, 0.15, 0.98 }, { 0.24, 0.3, 0.36, 1 }, game.fonts.body)
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
    local inputGroups = game.world:getInputEdgeGroups()
    local outputGroups = game.world:getOutputBadgeGroups()

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
    local breakdownX = panel.x + 58
    local valueX = panel.x + panel.w - 58
    local lineY = panel.y + 192
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
        string.format("Driven distance: %.1fm", summary.actualDrivenDistance or 0),
        string.format("Minimum distance: %.1fm", summary.minimumRequiredDistance or 0),
        string.format("Extra distance: %.1fm", summary.extraDistance or 0),
    }

    for _, stat in ipairs(stats) do
        graphics.setColor(0.72, 0.78, 0.84, 1)
        graphics.print(stat, breakdownX, lineY)
        lineY = lineY + 26
    end

    drawButton(buttons.replay, "Replay", { 0.1, 0.14, 0.18, 0.98 }, { 0.48, 0.92, 0.62, 1 }, game.fonts.small)
    drawButton(buttons.editor, "Open In Editor", { 0.1, 0.14, 0.18, 0.98 }, { 0.99, 0.78, 0.32, 1 }, game.fonts.small)
    drawButton(buttons.menu, "Main Menu", { 0.1, 0.14, 0.18, 0.98 }, { 0.3, 0.36, 0.42, 1 }, game.fonts.small)
end

return ui
