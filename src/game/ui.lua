local ui = {}

local function drawCenteredOverlay(game, title, body, footer, accentColor)
    local graphics = love.graphics
    local accent = accentColor or { 0.48, 0.92, 0.62 }

    graphics.setColor(0, 0, 0, 0.48)
    graphics.rectangle(
        "fill",
        game.viewport.w * 0.5 - 260,
        game.viewport.h * 0.5 - 110,
        520,
        220,
        18,
        18
    )

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf(title, 0, game.viewport.h * 0.5 - 70, game.viewport.w, "center")

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.84, 0.88, 0.92, 1)
    graphics.printf(body, game.viewport.w * 0.5 - 210, game.viewport.h * 0.5 - 8, 420, "center")

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(accent[1], accent[2], accent[3], 1)
    graphics.printf(footer, 0, game.viewport.h * 0.5 + 66, game.viewport.w, "center")
end

function ui.draw(game)
    local graphics = love.graphics

    graphics.setColor(0, 0, 0, 0.32)
    graphics.rectangle("fill", 22, 20, 540, 146, 18, 18)

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.print("Out of Signal", 40, 32)

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.84, 0.88, 0.92, 1)
    graphics.printf(
        "Click the crossing to flip the route. The chosen color moves immediately. Switch too early and the trains can crash.",
        40,
        76,
        500
    )

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.48, 0.92, 0.62, 1)
    graphics.print("Active route: " .. game.world:getActiveTrackLabel(), 40, 132)
    graphics.setColor(0.84, 0.88, 0.92, 0.95)
    graphics.print(
        string.format("Trains cleared: %d / 2   Controls: click crossing or use 1, 2, Space", game.world:countCompletedTrains()),
        190,
        132
    )

    graphics.setColor(0.8, 0.84, 0.9, 0.8)
    graphics.printf(
        "Route both trains through the merge. If they overlap after a risky switch, the run fails.",
        0,
        game.viewport.h - 44,
        game.viewport.w,
        "center"
    )

    if game.levelFailed then
        drawCenteredOverlay(
            game,
            "Signal Failure",
            "The trains collided because the crossing was switched too aggressively.",
            "Click, press Space, Enter, R, or gamepad A to restart",
            { 0.97, 0.36, 0.3 }
        )
    elseif game.levelComplete then
        drawCenteredOverlay(
            game,
            "Level Clear",
            "Both trains made it through the merge and cleared the bottom of the map.",
            "Click, press Space, Enter, R, or gamepad A to restart",
            { 0.48, 0.92, 0.62 }
        )
    end
end

return ui
