local ui = {}

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

local function drawButton(rect, label, fillColor, strokeColor, font)
    local graphics = love.graphics
    graphics.setColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 1)
    graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 16, 16)
    graphics.setLineWidth(1.5)
    graphics.setColor(strokeColor[1], strokeColor[2], strokeColor[3], strokeColor[4] or 1)
    graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 16, 16)
    love.graphics.setFont(font)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf(label, rect.x, rect.y + rect.h * 0.5 - 9, rect.w, "center")
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

local function getMenuButtons(game)
    local centerX = game.viewport.w * 0.5 - 160
    return {
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
end

local function getLevelSelectBackRect()
    return {
        x = 32,
        y = 28,
        w = 116,
        h = 38,
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
    local sections = {
        {
            title = "Controls",
            lines = {
                "Left click a junction to activate its control.",
                "Left click the selector below a junction to cycle outputs forward.",
                "Right click the selector below a junction to cycle outputs backward.",
                "M opens the menu. E opens the editor. R restarts the run.",
                "F2 closes this help panel. F3 opens the debug panel.",
            },
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
    local sections = {
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
    local queueGroups = {}
    local orderedGroups = {}

    for _, junction in ipairs(worldState.junctionOrder or {}) do
        sections[1].lines[#sections[1].lines + 1] = string.format("%s | %s", junction.label, getJunctionRouteText(junction))
        sections[1].lines[#sections[1].lines + 1] = getJunctionStateText(junction)
    end

    for _, train in ipairs(worldState.trains or {}) do
        local startEdgeId = train.startEdgeId or train.edgeId
        local startEdge = worldState.edges[startEdgeId]
        if not queueGroups[startEdgeId] then
            queueGroups[startEdgeId] = {
                label = startEdge and startEdge.label or startEdgeId,
                trains = {},
            }
            orderedGroups[#orderedGroups + 1] = queueGroups[startEdgeId]
        end
        queueGroups[startEdgeId].trains[#queueGroups[startEdgeId].trains + 1] = train
    end

    table.sort(orderedGroups, function(firstGroup, secondGroup)
        return firstGroup.label < secondGroup.label
    end)

    for _, group in ipairs(orderedGroups) do
        table.sort(group.trains, function(firstTrain, secondTrain)
            return (firstTrain.startProgress or 0) > (secondTrain.startProgress or 0)
        end)

        sections[2].lines[#sections[2].lines + 1] = string.format("%s queue", group.label)
        for index, train in ipairs(group.trains) do
            sections[2].lines[#sections[2].lines + 1] = string.format(
                "%d. %s | start %.0f | %.2fx | %s",
                index,
                train.id,
                train.startProgress or 0,
                train.speedScale or 1,
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

local function filterMapsBySource(game, source)
    local maps = {}
    for _, descriptor in ipairs(game.availableMaps or {}) do
        if descriptor.source == source then
            maps[#maps + 1] = descriptor
        end
    end
    return maps
end

local function getBuiltinEntryRects(game)
    local rects = {}
    local startY = 128
    local builtinMaps = filterMapsBySource(game, "builtin")

    for index, descriptor in ipairs(builtinMaps) do
        rects[#rects + 1] = {
            kind = "map",
            map = descriptor,
            x = 40,
            y = startY + (index - 1) * 94,
            w = 540,
            h = 78,
            editRect = {
                x = 450,
                y = startY + (index - 1) * 94 + 20,
                w = 104,
                h = 36,
            },
        }
    end

    return rects
end

local function getUserEntryRects(game)
    local rects = {}
    local startY = 128
    local userMaps = filterMapsBySource(game, "user")

    for index, descriptor in ipairs(userMaps) do
        rects[#rects + 1] = {
            kind = "map",
            map = descriptor,
            x = 700,
            y = startY + (index - 1) * 94,
            w = 540,
            h = 78,
            editRect = {
                x = 1110,
                y = startY + (index - 1) * 94 + 20,
                w = 104,
                h = 36,
            },
        }
    end

    return rects
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

local function drawPlayOverlayPanel(game, title, lines, accentColor)
    local graphics = love.graphics
    local panelX = 24
    local panelY = 76
    local panelW = 460
    local panelH = 212
    local lineHeight = 24
    local textX = panelX + 20
    local textY = panelY + 54
    local textW = panelW - 40
    local accent = accentColor or { 0.48, 0.92, 0.62 }

    graphics.setColor(0, 0, 0, 0.58)
    graphics.rectangle("fill", panelX, panelY, panelW, panelH, 18, 18)
    graphics.setColor(accent[1], accent[2], accent[3], 1)
    graphics.setLineWidth(2)
    graphics.rectangle("line", panelX, panelY, panelW, panelH, 18, 18)

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.print(title, textX, panelY + 18)

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.84, 0.88, 0.92, 1)
    for lineIndex, line in ipairs(lines) do
        graphics.printf(line, textX, textY + (lineIndex - 1) * lineHeight, textW)
    end
end

function ui.getMenuActionAt(game, x, y)
    for _, rect in ipairs(getMenuButtons(game)) do
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

    local backRect = getLevelSelectBackRect()
    if pointInRect(x, y, backRect) then
        return { kind = "back" }
    end

    for _, rect in ipairs(getBuiltinEntryRects(game)) do
        if pointInRect(x, y, rect.editRect) then
            return { kind = "edit_map", map = rect.map }
        end
        if pointInRect(x, y, rect) then
            return { kind = "open_map", map = rect.map }
        end
    end

    for _, rect in ipairs(getUserEntryRects(game)) do
        if pointInRect(x, y, rect.editRect) then
            return { kind = "edit_map", map = rect.map }
        end
        if pointInRect(x, y, rect) then
            return { kind = "open_map", map = rect.map }
        end
    end

    return nil
end

function ui.getPlayBackHit(game, x, y)
    return pointInRect(x, y, {
        x = 1114,
        y = 28,
        w = 134,
        h = 38,
    })
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

    for _, rect in ipairs(getMenuButtons(game)) do
        drawButton(rect, rect.label, { 0.09, 0.11, 0.15, 0.98 }, { 0.48, 0.92, 0.62, 1 }, game.fonts.body)
    end

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.72, 0.78, 0.84, 1)
    graphics.printf("Enter opens level select. E opens the editor directly. Esc quits.", 0, 620, game.viewport.w, "center")
end

function ui.drawLevelSelect(game)
    local graphics = love.graphics

    graphics.setColor(0.05, 0.07, 0.1, 1)
    graphics.rectangle("fill", 0, 0, game.viewport.w, game.viewport.h)

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.print("Level Select", 40, 28)

    drawButton(getLevelSelectBackRect(), "Back", { 0.09, 0.11, 0.15, 0.98 }, { 0.3, 0.36, 0.42, 1 }, game.fonts.small)

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.48, 0.92, 0.62, 1)
    graphics.print("Tutorial Maps", 40, 90)
    graphics.print("Saved Maps", 700, 90)

    local builtinRects = getBuiltinEntryRects(game)
    if #builtinRects == 0 then
        graphics.setColor(0.09, 0.11, 0.15, 0.98)
        graphics.rectangle("fill", 40, 128, 540, 120, 16, 16)
        graphics.setColor(0.26, 0.34, 0.42, 1)
        graphics.rectangle("line", 40, 128, 540, 120, 16, 16)
        love.graphics.setFont(game.fonts.body)
        graphics.setColor(0.84, 0.88, 0.92, 1)
        graphics.printf("No built-in tutorial maps were found.", 70, 166, 480, "center")
    else
        for _, rect in ipairs(builtinRects) do
            graphics.setColor(0.09, 0.11, 0.15, 0.98)
            graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 16, 16)
            graphics.setColor(0.26, 0.34, 0.42, 1)
            graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 16, 16)

            love.graphics.setFont(game.fonts.body)
            graphics.setColor(0.97, 0.98, 1, 1)
            graphics.print(rect.map.name, rect.x + 18, rect.y + 14)

            love.graphics.setFont(game.fonts.small)
            graphics.setColor(0.82, 0.86, 0.9, 1)
            graphics.print("Click to play", rect.x + 18, rect.y + 46)

            drawButton(rect.editRect, "Edit", { 0.1, 0.14, 0.18, 0.98 }, { 0.99, 0.78, 0.32, 1 }, game.fonts.small)
        end
    end

    local userRects = getUserEntryRects(game)
    if #userRects == 0 then
        graphics.setColor(0.09, 0.11, 0.15, 0.98)
        graphics.rectangle("fill", 700, 128, 540, 120, 16, 16)
        graphics.setColor(0.26, 0.34, 0.42, 1)
        graphics.rectangle("line", 700, 128, 540, 120, 16, 16)
        love.graphics.setFont(game.fonts.body)
        graphics.setColor(0.84, 0.88, 0.92, 1)
        graphics.printf("No saved maps yet. Open the editor from the main menu and save one there.", 730, 166, 480, "center")
    else
        for _, rect in ipairs(userRects) do
            graphics.setColor(0.09, 0.11, 0.15, 0.98)
            graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 16, 16)
            graphics.setColor(0.26, 0.34, 0.42, 1)
            graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 16, 16)

            love.graphics.setFont(game.fonts.body)
            graphics.setColor(0.97, 0.98, 1, 1)
            graphics.print(rect.map.name, rect.x + 18, rect.y + 14)

            love.graphics.setFont(game.fonts.small)
            graphics.setColor(0.82, 0.86, 0.9, 1)
            graphics.print("Click to play", rect.x + 18, rect.y + 46)

            drawButton(rect.editRect, "Edit", { 0.1, 0.14, 0.18, 0.98 }, { 0.99, 0.78, 0.32, 1 }, game.fonts.small)
        end
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
    local level = game.world:getLevel()
    local runSummary = game.world:getRunSummary()
    local gameTitleText = "Out of Signal"
    local levelTitleText = level.title or ""
    local titleFont = game.fonts.title
    local levelFont = game.fonts.body
    local timerFont = game.fonts.small
    local timerText = game.world.timeRemaining and string.format("Time left: %.1fs", game.world.timeRemaining) or nil
    local titleRowWidth = titleFont:getWidth(gameTitleText)
    local levelRowWidth = 0
    local timerRowWidth = timerText and timerFont:getWidth(timerText) or 0
    local titleRowHeight = math.max(titleFont:getHeight(), levelFont:getHeight())
    local headerHeight = titleRowHeight + PLAY_HEADER.paddingY * 2

    if levelTitleText ~= "" then
        levelRowWidth = PLAY_HEADER.titleGap + levelFont:getWidth(levelTitleText)
    end

    if timerText then
        headerHeight = headerHeight + PLAY_HEADER.rowGap + timerFont:getHeight()
    end

    local playHeaderRect = {
        x = PLAY_HEADER.x,
        y = PLAY_HEADER.y,
        w = math.max(titleRowWidth + levelRowWidth, timerRowWidth) + PLAY_HEADER.paddingX * 2,
        h = headerHeight,
    }
    local titleRowY = playHeaderRect.y + PLAY_HEADER.paddingY
    local textX = playHeaderRect.x + PLAY_HEADER.paddingX

    graphics.setColor(0, 0, 0, 0.34)
    graphics.rectangle("fill", playHeaderRect.x, playHeaderRect.y, playHeaderRect.w, playHeaderRect.h, PLAY_HEADER.radius, PLAY_HEADER.radius)

    love.graphics.setFont(titleFont)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.print(gameTitleText, textX, titleRowY)

    if levelTitleText ~= "" then
        love.graphics.setFont(levelFont)
        graphics.setColor(0.84, 0.88, 0.92, 1)
        graphics.print(
            levelTitleText,
            textX + titleRowWidth + PLAY_HEADER.titleGap,
            titleRowY + math.floor((titleRowHeight - levelFont:getHeight()) * 0.5 + 0.5)
        )
    end

    if timerText then
        love.graphics.setFont(timerFont)
        graphics.setColor(0.99, 0.83, 0.44, 1)
        graphics.print(timerText, textX, titleRowY + titleRowHeight + PLAY_HEADER.rowGap)
    end

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.48, 0.92, 0.62, 1)
    graphics.print(game.world:getActiveRouteSummary(), 42, 152)

    local trainsText = string.format("Trains cleared: %d / %d", game.world:countCompletedTrains(), #game.world.trains)
    graphics.setColor(0.84, 0.88, 0.92, 0.95)
    graphics.print(trainsText, 42, 174)
    graphics.print(string.format("Interactions: %d", runSummary.interactionCount or 0), 42, 196)
    graphics.print(string.format("Score: %s", formatScore(runSummary.finalScore or 0)), 220, 196)

    local nextTrain = game.world:getNextQueuedTrain()
    if nextTrain then
        graphics.setColor(0.72, 0.78, 0.84, 1)
        graphics.print(string.format("Next spawn: %s at %.1fs", game.world:getTrainSummary(nextTrain), nextTrain.spawnTime or 0), 42, 220)
    end

    local nextDeadline = game.world:getNearestPendingDeadline()
    if nextDeadline then
        graphics.setColor(0.99, 0.78, 0.32, 1)
        graphics.print(string.format("Nearest deadline: %s by %.1fs", game.world:getTrainSummary(nextDeadline), nextDeadline.deadline), 360, 220)
    end

    drawButton(
        { x = 1114, y = 28, w = 134, h = 38 },
        "Main Menu",
        { 0.09, 0.11, 0.15, 0.98 },
        { 0.3, 0.36, 0.42, 1 },
        game.fonts.small
    )

    graphics.setColor(0, 0, 0, 0.3)
    graphics.rectangle("fill", game.viewport.w - 286, game.viewport.h - 54, 250, 30, 15, 15)
    graphics.setColor(0.8, 0.84, 0.9, 0.82)
    graphics.printf("Press F2 for help, F3 for debug, M for menu, E for editor, or R to restart", 0, game.viewport.h - 42, game.viewport.w, "center")

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
