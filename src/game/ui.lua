local ui = {}

local LEVEL_SELECT = {
    chromeH = 72,
    titleBarY = 120,
    titleBarH = 56,
    carouselCenterY = 372,
    cardBaseW = 284,
    cardBaseH = 342,
    cardSpacing = 270,
    sideLift = 54,
    thumbY = 564,
    thumbW = 42,
    thumbH = 28,
    thumbGap = 8,
    bottomBarY = 616,
    bottomBarH = 86,
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

local function drawMetalPanel(rect, innerAlpha)
    local graphics = love.graphics
    local alpha = innerAlpha or 0.98

    graphics.setColor(0.82, 0.84, 0.86, alpha)
    graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 20, 20)

    graphics.setColor(0.95, 0.95, 0.96, alpha)
    graphics.rectangle("fill", rect.x + 5, rect.y + 5, rect.w - 10, rect.h * 0.32, 16, 16)

    graphics.setColor(0.68, 0.7, 0.73, alpha)
    graphics.rectangle("fill", rect.x + 5, rect.y + rect.h * 0.5, rect.w - 10, rect.h * 0.45, 16, 16)

    graphics.setColor(0.18, 0.19, 0.2, 1)
    graphics.setLineWidth(3)
    graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 20, 20)
    graphics.rectangle("line", rect.x + 4, rect.y + 4, rect.w - 8, rect.h - 8, 17, 17)
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

local function filterMapsBySource(game, source)
    local maps = {}
    for _, descriptor in ipairs(game.availableMaps or {}) do
        if descriptor.source == source then
            maps[#maps + 1] = descriptor
        end
    end
    return maps
end

local function getLevelSelectMaps(game)
    local maps = {}

    for _, descriptor in ipairs(filterMapsBySource(game, "builtin")) do
        maps[#maps + 1] = descriptor
    end

    for _, descriptor in ipairs(filterMapsBySource(game, "user")) do
        maps[#maps + 1] = descriptor
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

local function getLevelSelectBackRect()
    return {
        x = 20,
        y = 16,
        w = 120,
        h = 40,
    }
end

local function getLevelSelectActionRects()
    return {
        start = {
            x = 882,
            y = 636,
            w = 160,
            h = 42,
        },
        edit = {
            x = 1054,
            y = 636,
            w = 160,
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
    if absDistance == 0 then
        return 1
    end
    if absDistance == 1 then
        return 0.82
    end
    if absDistance == 2 then
        return 0.66
    end
    return 0.5
end

local function buildLevelSelectCardRects(game)
    local maps = getLevelSelectMaps(game)
    local selectedIndex = getSelectedMapIndex(game, maps)
    local rects = {}

    if not selectedIndex then
        return rects, maps, nil
    end

    local centerX = game.viewport.w * 0.5
    for index, descriptor in ipairs(maps) do
        local distance = index - selectedIndex
        if math.abs(distance) <= 3 then
            local scale = getCardScale(distance)
            local width = math.floor(LEVEL_SELECT.cardBaseW * scale + 0.5)
            local height = math.floor(LEVEL_SELECT.cardBaseH * scale + 0.5)
            local centerOffset = distance * LEVEL_SELECT.cardSpacing
            local x = math.floor(centerX + centerOffset - width * 0.5 + 0.5)
            local y = math.floor(LEVEL_SELECT.carouselCenterY - height * 0.5 + (1 - scale) * LEVEL_SELECT.sideLift + 0.5)
            rects[#rects + 1] = {
                map = descriptor,
                index = index,
                selected = distance == 0,
                distance = distance,
                scale = scale,
                x = x,
                y = y,
                w = width,
                h = height,
                previewRect = {
                    x = x + math.floor(width * 0.11),
                    y = y + math.floor(height * 0.14),
                    w = math.floor(width * 0.78),
                    h = math.floor(height * 0.64),
                },
            }
        end
    end

    table.sort(rects, function(a, b)
        if a.selected ~= b.selected then
            return not a.selected
        end
        return math.abs(a.distance) < math.abs(b.distance)
    end)

    return rects, maps, selectedIndex
end

local function buildThumbnailRects(game, maps, selectedIndex)
    local rects = {}
    local totalWidth = #maps * LEVEL_SELECT.thumbW + math.max(0, #maps - 1) * LEVEL_SELECT.thumbGap
    local startX = math.floor(game.viewport.w * 0.5 - totalWidth * 0.5 + 0.5)

    for index, descriptor in ipairs(maps) do
        rects[#rects + 1] = {
            map = descriptor,
            selected = index == selectedIndex,
            x = startX + (index - 1) * (LEVEL_SELECT.thumbW + LEVEL_SELECT.thumbGap),
            y = LEVEL_SELECT.thumbY,
            w = LEVEL_SELECT.thumbW,
            h = LEVEL_SELECT.thumbH,
        }
    end

    return rects
end

local function drawControlBadges(game, descriptor, x, y, maxWidth)
    local graphics = love.graphics
    local controls = getMapControlTypes(descriptor)
    local badgeX = x

    love.graphics.setFont(game.fonts.small)

    for _, controlType in ipairs(controls) do
        local label = CONTROL_SHORT_LABELS[controlType] or controlType
        local badgeWidth = game.fonts.small:getWidth(label) + 20
        if badgeX + badgeWidth > x + maxWidth then
            break
        end

        local color = PREVIEW_COLORS.control[controlType] or PREVIEW_COLORS.control.direct
        graphics.setColor(color[1], color[2], color[3], 0.18)
        graphics.rectangle("fill", badgeX, y, badgeWidth, 20, 10, 10)
        graphics.setColor(color[1], color[2], color[3], 1)
        graphics.rectangle("line", badgeX, y, badgeWidth, 20, 10, 10)
        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.printf(label, badgeX, y + 2, badgeWidth, "center")
        badgeX = badgeX + badgeWidth + 6
    end
end

local function drawLevelSelectChrome(game)
    drawMetalPanel({ x = 2, y = 2, w = game.viewport.w - 4, h = LEVEL_SELECT.chromeH }, 0.98)
    drawMetalPanel({ x = 2, y = LEVEL_SELECT.bottomBarY, w = game.viewport.w - 4, h = LEVEL_SELECT.bottomBarH }, 0.98)

    local graphics = love.graphics
    graphics.setColor(0.26, 0.28, 0.3, 1)
    for column = 0, 35 do
        local x = column * 36 + 4
        graphics.rectangle("fill", x, 0, 18, 12)
        graphics.rectangle("fill", x + 18, 12, 18, 12)
    end
end

local function drawLevelSelectTitleBar(game, selectedMap)
    local graphics = love.graphics
    local barRect = {
        x = 118,
        y = LEVEL_SELECT.titleBarY,
        w = 1044,
        h = LEVEL_SELECT.titleBarH,
    }

    graphics.setColor(0.36, 0.4, 0.38, 1)
    graphics.rectangle("fill", barRect.x, barRect.y, barRect.w, barRect.h, 12, 12)
    graphics.setColor(0.16, 0.17, 0.18, 1)
    graphics.rectangle("line", barRect.x, barRect.y, barRect.w, barRect.h, 12, 12)
    graphics.rectangle("line", barRect.x + 4, barRect.y + 4, barRect.w - 8, barRect.h - 8, 10, 10)

    if not selectedMap then
        return
    end

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf(selectedMap.name, barRect.x + 30, barRect.y + 10, barRect.w - 60, "center")
end

local function drawLevelCard(game, rect)
    local graphics = love.graphics
    local descriptor = rect.map
    local selected = rect.selected
    local cardFill = selected and { 0.74, 0.76, 0.79, 1 } or { 0.66, 0.68, 0.72, 0.92 }
    local trim = selected and { 0.18, 0.86, 0.98, 1 } or { 0.16, 0.17, 0.18, 0.95 }
    local footerH = math.max(34, math.floor(rect.h * 0.16))

    graphics.setColor(0.09, 0.1, 0.11, 0.26)
    graphics.rectangle("fill", rect.x + 6, rect.y + rect.h - 8, rect.w, 16, 10, 10)

    graphics.setColor(cardFill[1], cardFill[2], cardFill[3], cardFill[4])
    graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 18, 18)
    graphics.setColor(trim[1], trim[2], trim[3], trim[4])
    graphics.setLineWidth(selected and 4 or 3)
    graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 18, 18)
    graphics.rectangle("line", rect.x + 4, rect.y + 4, rect.w - 8, rect.h - 8, 14, 14)

    if selected then
        graphics.setColor(0.1, 0.92, 1, 0.22)
        graphics.rectangle("line", rect.x - 6, rect.y - 6, rect.w + 12, rect.h + 12, 22, 22)
    end

    drawMapPreview(descriptor, rect.previewRect)

    graphics.setColor(0.03, 0.04, 0.05, 0.98)
    graphics.rectangle("fill", rect.x, rect.y + rect.h - footerH, rect.w, footerH, 0, 0, 18, 18)

    love.graphics.setFont(selected and game.fonts.body or game.fonts.small)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf(
        descriptor.source == "builtin" and descriptor.name or descriptor.name,
        rect.x + 12,
        rect.y + rect.h - footerH + (selected and 6 or 8),
        rect.w - 24,
        "center"
    )

    if selected then
        drawControlBadges(game, descriptor, rect.x + 18, rect.y + rect.h - footerH - 28, rect.w - 36)
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

    local maps = getLevelSelectMaps(game)
    local selectedIndex = getSelectedMapIndex(game, maps)
    local selectedMap = selectedIndex and maps[selectedIndex] or nil
    local actionRects = getLevelSelectActionRects()

    if selectedMap and pointInRect(x, y, actionRects.start) then
        return { kind = "open_map", map = selectedMap }
    end
    if selectedMap and pointInRect(x, y, actionRects.edit) then
        return { kind = "edit_map", map = selectedMap }
    end

    local cardRects = buildLevelSelectCardRects(game)
    for _, rect in ipairs(cardRects) do
        if pointInRect(x, y, rect) then
            if rect.selected then
                return { kind = "open_map", map = rect.map }
            end
            return { kind = "select_map", map = rect.map }
        end
    end

    local thumbRects = buildThumbnailRects(game, maps, selectedIndex or 0)
    for _, rect in ipairs(thumbRects) do
        if pointInRect(x, y, rect) then
            if rect.selected then
                return { kind = "open_map", map = rect.map }
            end
            return { kind = "select_map", map = rect.map }
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
    local thumbRects = buildThumbnailRects(game, maps, selectedIndex or 0)
    local actionRects = getLevelSelectActionRects()

    graphics.setColor(0.97, 0.97, 0.98, 1)
    graphics.rectangle("fill", 0, 0, game.viewport.w, game.viewport.h)

    graphics.setColor(0.98, 0.92, 0.92, 0.55)
    graphics.setLineWidth(10)
    graphics.line(60, 140, 1220, 620)
    graphics.setColor(0.94, 0.86, 0.62, 0.52)
    graphics.line(180, 90, 1040, 680)
    graphics.setColor(0.66, 0.8, 0.96, 0.5)
    graphics.line(940, 100, 240, 680)
    graphics.setColor(0.68, 0.9, 0.68, 0.45)
    graphics.line(1180, 120, 1010, 320)

    drawLevelSelectChrome(game)
    drawLevelSelectTitleBar(game, selectedMap)
    drawButton(getLevelSelectBackRect(), "Back", { 0.15, 0.18, 0.22, 0.98 }, { 0.15, 0.15, 0.15, 1 }, game.fonts.small)

    for drawIndex = #cardRects, 1, -1 do
        drawLevelCard(game, cardRects[drawIndex])
    end

    for _, thumb in ipairs(thumbRects) do
        graphics.setColor(thumb.selected and 0.18 or 0.08, thumb.selected and 0.86 or 0.12, thumb.selected and 0.98 or 0.14, thumb.selected and 0.22 or 0.08)
        graphics.rectangle("fill", thumb.x - 4, thumb.y - 4, thumb.w + 8, thumb.h + 8, 10, 10)
        drawMapPreview(thumb.map, thumb)
        if thumb.selected then
            graphics.setColor(0.18, 0.86, 0.98, 1)
            graphics.rectangle("line", thumb.x - 4, thumb.y - 4, thumb.w + 8, thumb.h + 8, 10, 10)
        end
    end

    drawButton(actionRects.start, "Start", { 0.16, 0.18, 0.21, 0.98 }, { 0.48, 0.92, 0.62, 1 }, game.fonts.body)
    drawButton(actionRects.edit, "Edit", { 0.16, 0.18, 0.21, 0.98 }, { 0.99, 0.78, 0.32, 1 }, game.fonts.body)

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.12, 0.13, 0.14, 1)
    graphics.printf("Left and right browse  |  mouse wheel scrolls horizontally  |  Enter starts  |  E edits", 0, 690, game.viewport.w, "center")

    if selectedMap then
        love.graphics.setFont(game.fonts.small)
        graphics.setColor(0.18, 0.19, 0.2, 1)
        graphics.printf(
            (selectedMap.source == "builtin" and "Tutorial" or "Saved Map") .. "  |  " .. (selectedMap.previewDescription or "Ready to play"),
            160,
            92,
            960,
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

    drawButton(
        { x = 1114, y = 28, w = 134, h = 38 },
        "Main Menu",
        { 0.09, 0.11, 0.15, 0.98 },
        { 0.3, 0.36, 0.42, 1 },
        game.fonts.small
    )

    graphics.setColor(0.8, 0.84, 0.9, 0.82)
    graphics.printf(level.hint, 0, game.viewport.h - 66, game.viewport.w, "center")
    graphics.printf(level.footer, 0, game.viewport.h - 42, game.viewport.w, "center")
    graphics.printf("Press M for the main menu, E for the editor, or R to restart", 0, game.viewport.h - 90, game.viewport.w, "center")

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
