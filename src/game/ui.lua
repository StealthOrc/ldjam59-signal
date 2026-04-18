local ui = {}

local function drawFuelBar(game)
    local graphics = love.graphics
    local x = 28
    local y = 26
    local width = 260
    local height = 20
    local ratio = game.car.fuel / game.tuning.fuelCapacity

    graphics.setColor(0, 0, 0, 0.35)
    graphics.rectangle("fill", x - 10, y - 10, width + 20, 64, 12, 12)

    graphics.setColor(0.9, 0.92, 0.95)
    graphics.print("Fuel", x, y - 2)

    graphics.setColor(0.16, 0.17, 0.2)
    graphics.rectangle("fill", x, y + 20, width, height, 8, 8)

    graphics.setColor(0.94, 0.65, 0.18)
    graphics.rectangle("fill", x, y + 20, width * ratio, height, 8, 8)

    graphics.setColor(0.96, 0.97, 0.98, 0.7)
    graphics.rectangle("line", x, y + 20, width, height, 8, 8)
end

local function drawStats(game)
    local graphics = love.graphics
    local width = game.viewport.w
    local speedKph = game.car.speed * 0.22

    graphics.setColor(0, 0, 0, 0.35)
    graphics.rectangle("fill", width - 250, 16, 226, 102, 12, 12)

    graphics.setColor(0.92, 0.93, 0.95)
    graphics.printf(string.format("Distance  %.0f m", game.runDistance), width - 236, 30, 200, "left")
    graphics.printf(string.format("Best      %.0f m", game.bestDistance), width - 236, 54, 200, "left")
    graphics.printf(string.format("Speed     %.0f", speedKph), width - 236, 78, 200, "left")
end

local function drawCenterOverlay(title, subtitle, footer, viewport)
    local graphics = love.graphics
    local centerX = viewport.w * 0.5
    local centerY = viewport.h * 0.5

    graphics.setColor(0, 0, 0, 0.44)
    graphics.rectangle("fill", centerX - 260, centerY - 104, 520, 208, 18, 18)

    graphics.setColor(0.95, 0.97, 0.99)
    graphics.printf(title, centerX - 220, centerY - 58, 440, "center")

    graphics.setColor(0.86, 0.88, 0.92)
    graphics.printf(subtitle, centerX - 220, centerY - 8, 440, "center")

    graphics.setColor(0.96, 0.67, 0.22)
    graphics.printf(footer, centerX - 220, centerY + 54, 440, "center")
end

function ui.draw(game)
    local graphics = love.graphics

    drawFuelBar(game)
    drawStats(game)

    graphics.setColor(0.85, 0.87, 0.91, 0.85)
    graphics.print("WASD to drive, Space to handbrake, Left stick + A on controller", 28, game.viewport.h - 34)

    if game.state == "title" then
        drawCenterOverlay(
            "Northbound Drift Run",
            "Stay inside the corridor, slide the rear out, and stretch every tank as far north as you can.",
            "Press any key or controller button to start",
            game.viewport
        )
    elseif game.state == "coasting" then
        graphics.setColor(0, 0, 0, 0.34)
        graphics.rectangle("fill", game.viewport.w * 0.5 - 160, 20, 320, 44, 12, 12)
        graphics.setColor(0.95, 0.73, 0.2)
        graphics.printf("Fuel empty - coast it out", game.viewport.w * 0.5 - 150, 33, 300, "center")
    elseif game.state == "finished" then
        drawCenterOverlay(
            "Out of motion",
            string.format("You coasted %.0f meters north. Best this session: %.0f meters.", game.runDistance, game.bestDistance),
            "Press any key or controller button to run again",
            game.viewport
        )
    end
end

return ui
