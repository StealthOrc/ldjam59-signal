local ui = {}

local function pointInRect(x, y, rect)
    return x >= rect.x
        and x <= rect.x + rect.w
        and y >= rect.y
        and y <= rect.y + rect.h
end

local function getLevelTabRects(game)
    local tabWidth = 124
    local tabHeight = 32
    local gap = 10
    local levelCount = game.world:getLevelCount()
    local totalWidth = tabWidth * levelCount + gap * (levelCount - 1)
    local startX = game.viewport.w - totalWidth - 22
    local y = 20
    local rects = {}

    for levelIndex = 1, levelCount do
        rects[#rects + 1] = {
            id = levelIndex,
            x = startX + (levelIndex - 1) * (tabWidth + gap),
            y = y,
            w = tabWidth,
            h = tabHeight,
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

function ui.getLevelTabAt(game, x, y)
    for _, rect in ipairs(getLevelTabRects(game)) do
        if pointInRect(x, y, rect) then
            return rect.id
        end
    end

    return nil
end

function ui.draw(game)
    local graphics = love.graphics
    local level = game.world:getLevel()

    graphics.setColor(0, 0, 0, 0.34)
    graphics.rectangle("fill", 22, 20, 620, 170, 18, 18)

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.print("Out of Signal", 40, 32)

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.84, 0.88, 0.92, 1)
    graphics.print(level.title, 42, 80)
    graphics.printf(level.description, 42, 108, 570)

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.48, 0.92, 0.62, 1)
    graphics.print(game.world:getActiveRouteSummary(), 42, 152)

    local trainsText = string.format("Trains cleared: %d / %d", game.world:countCompletedTrains(), #game.world.trains)
    graphics.setColor(0.84, 0.88, 0.92, 0.95)
    graphics.print(trainsText, 42, 172)

    if game.world.timeRemaining then
        graphics.setColor(0.99, 0.83, 0.44, 1)
        graphics.print(string.format("Time left: %.1fs", game.world.timeRemaining), 220, 172)
    end

    local tabRects = getLevelTabRects(game)
    love.graphics.setFont(game.fonts.small)
    for _, rect in ipairs(tabRects) do
        local selected = rect.id == game.levelIndex

        if selected then
            graphics.setColor(0.2, 0.28, 0.34, 0.98)
        else
            graphics.setColor(0.08, 0.1, 0.12, 0.94)
        end
        graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 12, 12)

        if selected then
            graphics.setColor(0.48, 0.92, 0.62, 1)
        else
            graphics.setColor(0.3, 0.36, 0.42, 1)
        end
        graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 12, 12)

        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.printf("F" .. rect.id .. "  Map " .. rect.id, rect.x, rect.y + 8, rect.w, "center")
    end

    graphics.setColor(0.8, 0.84, 0.9, 0.82)
    graphics.printf(level.hint, 0, game.viewport.h - 66, game.viewport.w, "center")
    graphics.printf(level.footer, 0, game.viewport.h - 42, game.viewport.w, "center")

    if game.failureReason == "collision" then
        drawCenteredOverlay(
            game,
            "Signal Failure",
            "Two trains overlapped because the routes were switched unsafely.",
            "Click, press Enter, Space, or R to retry the current map",
            { 0.97, 0.36, 0.3 }
        )
    elseif game.failureReason == "timeout" then
        drawCenteredOverlay(
            game,
            "Too Late",
            "The timer expired before every train cleared its exit.",
            "Retry the map and use the delayed button earlier",
            { 0.99, 0.83, 0.44 }
        )
    elseif game.levelComplete then
        drawCenteredOverlay(
            game,
            "Level Clear",
            "All trains cleared their exits.",
            "Click a map tab to continue, or press R to replay this one",
            { 0.48, 0.92, 0.62 }
        )
    end
end

return ui
