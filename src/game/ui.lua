local ui = {}

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

function ui.getPlayBackHit(_, x, y)
    return pointInRect(x, y, {
        x = 1114,
        y = 28,
        w = 134,
        h = 38,
    })
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
    local trainsText = string.format("Trains %d / %d", game.world:countCompletedTrains(), #game.world.trains)
    local timeText = game.world.timeRemaining and string.format("Time %.1fs", game.world.timeRemaining) or nil

    graphics.setColor(0, 0, 0, 0.34)
    graphics.rectangle("fill", 22, 20, 360, 52, 18, 18)

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.print(level.title, 40, 30)

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.84, 0.88, 0.92, 0.95)
    graphics.print(trainsText, 410, 34)
    if timeText then
        graphics.setColor(0.99, 0.83, 0.44, 1)
        graphics.print(timeText, 520, 34)
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
    graphics.printf("F2 info   F3 help", game.viewport.w - 274, game.viewport.h - 47, 226, "center")

    if game.showPlayInfoOverlay then
        drawPlayOverlayPanel(
            game,
            "Run Info",
            {
                level.description or "",
                "Route: " .. game.world:getActiveRouteSummary(),
                trainsText .. (timeText and ("   " .. timeText) or ""),
                "Press F2 again to close this panel.",
            },
            { 0.48, 0.92, 0.62 }
        )
    elseif game.showPlayHelpOverlay then
        drawPlayOverlayPanel(
            game,
            "Help",
            {
                level.hint or "",
                level.footer or "",
                "Click a junction center to switch inputs.",
                "Use the lower selector to switch outputs.",
                "Press M for menu, E for editor, and R to restart.",
                "Press F3 again to close this panel.",
            },
            { 0.99, 0.78, 0.32 }
        )
    end

    if game.failureReason == "collision" then
        drawCenteredOverlay(
            game,
            "Signal Failure",
            "Two trains overlapped because the routes were switched unsafely.",
            "Click, press Enter, Space, or R to retry this map",
            { 0.97, 0.36, 0.3 }
        )
    elseif game.failureReason == "timeout" then
        drawCenteredOverlay(
            game,
            "Too Late",
            "The timer expired before every train cleared its exit.",
            "Retry the map and arm route changes earlier",
            { 0.99, 0.83, 0.44 }
        )
    elseif game.levelComplete then
        drawCenteredOverlay(
            game,
            "Level Clear",
            "All trains cleared their exits.",
            "Click, press Enter, Space, or R to replay. Press M for the main menu.",
            { 0.48, 0.92, 0.62 }
        )
    end
end

return ui
