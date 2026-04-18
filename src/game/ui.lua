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
    local gearLabel = game.car.isShifting and string.format("G%d -> %d", game.car.currentGear, game.car.targetGear)
        or string.format("G%d", game.car.currentGear)

    graphics.setColor(0, 0, 0, 0.35)
    graphics.rectangle("fill", width - 262, 16, 238, 138, 12, 12)

    drawRun(font, string.format("Distance  %.0f m", distanceMeters), width - 246, 28, 1, { 0.92, 0.93, 0.95, 1 })
    drawRun(font, string.format("Best      %.0f m", bestMeters), width - 246, 50, 1, { 0.92, 0.93, 0.95, 1 })
    drawRun(font, string.format("Speed     %.0f km/h", speedKmh), width - 246, 72, 1, { 0.92, 0.93, 0.95, 1 })
    drawRun(font, string.format("Gear      %s", gearLabel), width - 246, 94, 1, { 0.88, 0.91, 0.99, 1 })
    drawRun(font, string.format("Coins     %d", game.progression.coins), width - 246, 116, 1, { 0.98, 0.88, 0.42, 1 })
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

local function drawShiftPulse(game)
    local graphics = love.graphics
    local font = game.uiFont
    local alpha = game.car.shiftFlashTimer / math.max(game.tuning.shiftFlashDuration, 0.01)

    if alpha <= 0 then
        return
    end

    graphics.setColor(0, 0, 0, 0.18 + alpha * 0.22)
    graphics.rectangle("fill", game.viewport.w * 0.5 - 92, 22, 184, 34, 10, 10)
    drawAligned(
        font,
        string.format("SHIFT %d", game.car.currentGear),
        game.viewport.w * 0.5 - 82,
        31,
        164,
        "center",
        1,
        { 0.98, 0.8, 0.3, 0.45 + alpha * 0.55 }
    )
end

local function drawShop(game)
    local graphics = love.graphics
    local font = game.uiFont
    local centerX = game.viewport.w * 0.5
    local centerY = game.viewport.h * 0.5
    local cardHeight = 56
    local cardSpacing = 64

    graphics.setColor(0, 0, 0, 0.5)
    graphics.rectangle("fill", centerX - 360, centerY - 286, 720, 572, 18, 18)

    drawAligned(font, "Workshop", centerX - 312, centerY - 248, 624, "center", 2, { 0.95, 0.97, 0.99, 1 })
    drawRun(font, string.format("Coins on hand  %d", game.progression.coins), centerX - 312, centerY - 204, 1, { 0.98, 0.88, 0.42, 1 })
    drawRun(font, string.format("Last run reward  +%d", game.lastRunCoinsEarned), centerX - 312, centerY - 182, 1, { 0.72, 0.95, 0.76, 1 })
    drawRun(font, string.format("Top speed  %d km/h", game.tuning.maxForwardSpeedKmh), centerX + 84, centerY - 204, 1, { 0.88, 0.91, 0.99, 1 })
    drawRun(font, string.format("Gearbox  %d-speed", game.tuning.gearCount), centerX + 84, centerY - 182, 1, { 0.88, 0.91, 0.99, 1 })

    local cardTop = centerY - 138
    for index, item in ipairs(game.shopItems) do
        local y = cardTop + (index - 1) * cardSpacing
        local selected = index == game.selectedShopIndex
        local unlocked = item.kind == "unlock" and game:hasUpgrade(item.id)
        local affordable = game.progression.coins >= item.cost
        local cardColor = selected and { 0.14, 0.18, 0.24, 0.96 } or { 0.09, 0.11, 0.14, 0.9 }
        local statusText
        local statusColor

        graphics.setColor(cardColor)
        graphics.rectangle("fill", centerX - 312, y, 624, cardHeight, 12, 12)

        if selected then
            graphics.setColor(0.87, 0.69, 0.24, 0.95)
            graphics.rectangle("line", centerX - 312, y, 624, cardHeight, 12, 12)
        end

        drawRun(font, item.title, centerX - 288, y + 10, 1, { 0.95, 0.97, 0.99, 1 })
        if item.kind == "dump" then
            drawRun(
                font,
                string.format("%s Bonus +%d km/h.", item.description, game:getMaxSpeedBonusKmh()),
                centerX - 288,
                y + 30,
                1,
                { 0.82, 0.86, 0.9, 1 }
            )
        else
            drawRun(font, item.description, centerX - 288, y + 30, 1, { 0.82, 0.86, 0.9, 1 })
        end

        if unlocked then
            statusText = "Purchased"
            statusColor = { 0.6, 0.95, 0.68, 1 }
        elseif item.kind == "dump" then
            if affordable then
                local holdText = game.shopHoldActive and " Holding..." or ""
                statusText = string.format("Spend  1 coin = +1 km/h%s", holdText)
                statusColor = { 0.98, 0.88, 0.42, 1 }
            else
                statusText = "Need  1 coin"
                statusColor = { 0.9, 0.44, 0.38, 1 }
            end
        elseif affordable then
            statusText = string.format("Buy  %d coins", item.cost)
            statusColor = { 0.98, 0.88, 0.42, 1 }
        else
            statusText = string.format("Need  %d coins", item.cost)
            statusColor = { 0.9, 0.44, 0.38, 1 }
        end

        drawRun(font, statusText, centerX + 118, y + 10, 1, statusColor)
    end

    drawRun(font, "Up / Down or D-pad selects", centerX - 312, centerY + 222, 1, { 0.85, 0.87, 0.91, 0.95 })
    drawRun(font, "Space / A buys, hold on Long Gears to dump faster", centerX - 10, centerY + 222, 1, { 0.85, 0.87, 0.91, 0.95 })
    drawRun(font, "Enter / Start begins next run", centerX - 312, centerY + 244, 1, { 0.85, 0.87, 0.91, 0.95 })
end

function ui.draw(game)
    local graphics = love.graphics
    local font = game.uiFont

    drawFuelBar(game)
    drawStats(game)
    drawShiftPulse(game)

    drawRun(font, "WASD to drive, Space to handbrake, Left stick + RT/LT + X on controller", 28, game.viewport.h - 34, 1, { 0.85, 0.87, 0.91, 0.85 })

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
                "You coasted %.0f meters north and earned %d coins. Best this session: %.0f meters.",
                game:unitsToMeters(game.runDistance),
                game.lastRunCoinsEarned,
                game:unitsToMeters(game.bestDistance)
            ),
            "Press any key or controller button to open the workshop",
            { w = game.viewport.w, h = game.viewport.h, font = font }
        )
    elseif game.state == "shop" then
        drawShop(game)
    end
end

return ui
