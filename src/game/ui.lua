local ui = {}

local function splitWords(text)
    local words = {}
    for word in (text or ""):gmatch("%S+") do
        words[#words + 1] = word
    end
    return words
end

local function wrapText(font, text, scale, maxWidth)
    local lines = {}
    local words = splitWords(text)

    if #words == 0 then
        return { "" }
    end

    local current = words[1]
    for index = 2, #words do
        local candidate = current .. " " .. words[index]
        if font:measureRun(candidate, scale) <= maxWidth then
            current = candidate
        else
            lines[#lines + 1] = current
            current = words[index]
        end
    end

    lines[#lines + 1] = current
    return lines
end

local function drawRun(font, text, x, y, scale, color)
    font:drawRun(text, x, y, scale, color)
end

local function drawAligned(font, text, x, y, width, align, scale, color)
    local drawX = x
    local textWidth = font:measureRun(text, scale)

    if align == "center" then
        drawX = x + (width - textWidth) * 0.5
    elseif align == "right" then
        drawX = x + width - textWidth
    end

    font:drawRun(text, drawX, y, scale, color)
end

local function drawWrapped(font, text, x, y, width, align, scale, color, lineGap)
    local lines = wrapText(font, text, scale, width)
    local lineHeight = font.characterHeight * font:scaleFor(scale) + (lineGap or 0)

    for index, line in ipairs(lines) do
        drawAligned(font, line, x, y + (index - 1) * lineHeight, width, align, scale, color)
    end

    return #lines * lineHeight
end

local function drawFuelBar(game)
    local graphics = love.graphics
    local font = game.uiFont
    local x = 28
    local y = 26
    local width = 260
    local height = 20
    local ratio = game.car.fuel / game.tuning.fuelCapacity
    local fuelColor = { 0.94, 0.65, 0.18 }

    if game:isLowFuel() then
        fuelColor = { 0.89, 0.16, 0.14 }
    end

    graphics.setColor(0, 0, 0, 0.35)
    graphics.rectangle("fill", x - 10, y - 10, width + 20, 64, 12, 12)

    drawRun(font, "Fuel", x, y, 1, { 0.9, 0.92, 0.95, 1 })

    graphics.setColor(0.16, 0.17, 0.2)
    graphics.rectangle("fill", x, y + 20, width, height, 8, 8)

    graphics.setColor(fuelColor)
    graphics.rectangle("fill", x, y + 20, width * ratio, height, 8, 8)

    graphics.setColor(0.96, 0.97, 0.98, 0.7)
    graphics.rectangle("line", x, y + 20, width, height, 8, 8)

    if game.activeSignalTower then
        drawRun(font, string.format("Signal +%.0f fuel/s", game.activeSignalTower.fuelPerSecond), x + 112, y, 1, { 0.52, 0.95, 0.85, 1 })
    end
end

local function drawStats(game)
    local graphics = love.graphics
    local font = game.uiFont
    local width = game.viewport.w
    local distanceMeters = game:unitsToMeters(game.runDistance)
    local bestMeters = game:unitsToMeters(game.bestDistance)
    local speedKmh = game:speedUnitsToKmh(game.car.speed)

    graphics.setColor(0, 0, 0, 0.35)
    graphics.rectangle("fill", width - 250, 16, 226, 102, 12, 12)

    drawRun(font, string.format("Distance  %.0f m", distanceMeters), width - 236, 30, 1, { 0.92, 0.93, 0.95, 1 })
    drawRun(font, string.format("Best      %.0f m", bestMeters), width - 236, 54, 1, { 0.92, 0.93, 0.95, 1 })
    drawRun(font, string.format("Speed     %.0f km/h", speedKmh), width - 236, 78, 1, { 0.92, 0.93, 0.95, 1 })
end

local function drawCenterOverlay(title, subtitle, footer, viewport)
    local graphics = love.graphics
    local font = viewport.font
    local centerX = viewport.w * 0.5
    local centerY = viewport.h * 0.5

    graphics.setColor(0, 0, 0, 0.44)
    graphics.rectangle("fill", centerX - 260, centerY - 104, 520, 208, 18, 18)

    drawAligned(font, title, centerX - 220, centerY - 58, 440, "center", 2, { 0.95, 0.97, 0.99, 1 })
    drawWrapped(font, subtitle, centerX - 220, centerY - 6, 440, "center", 1, { 0.86, 0.88, 0.92, 1 }, 6)
    drawAligned(font, footer, centerX - 220, centerY + 58, 440, "center", 1, { 0.96, 0.67, 0.22, 1 })
end

function ui.draw(game)
    local graphics = love.graphics
    local font = game.uiFont

    drawFuelBar(game)
    drawStats(game)

    drawRun(font, "WASD to drive, Space to handbrake, Left stick + A on controller", 28, game.viewport.h - 34, 1, { 0.85, 0.87, 0.91, 0.85 })

    if game.state == "title" then
        drawCenterOverlay(
            "Northbound Drift Run",
            "Stay inside the corridor, slide the rear out, and stretch every tank as far north as you can.",
            "Press any key or controller button to start",
            { w = game.viewport.w, h = game.viewport.h, font = font }
        )
    elseif game.state == "coasting" then
        graphics.setColor(0, 0, 0, 0.34)
        graphics.rectangle("fill", game.viewport.w * 0.5 - 160, 20, 320, 44, 12, 12)
        drawAligned(font, "Fuel empty - coast it out", game.viewport.w * 0.5 - 150, 33, 300, "center", 1, { 0.95, 0.73, 0.2, 1 })
    elseif game.state == "finished" then
        drawCenterOverlay(
            "Out of motion",
            string.format(
                "You coasted %.0f meters north. Best this session: %.0f meters.",
                game:unitsToMeters(game.runDistance),
                game:unitsToMeters(game.bestDistance)
            ),
            "Press any key or controller button to run again",
            { w = game.viewport.w, h = game.viewport.h, font = font }
        )
    end
end

return ui
