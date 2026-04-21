return function(mapEditor, shared)
    local moduleEnvironment = setmetatable({ mapEditor = mapEditor }, {
        __index = function(_, key)
            local sharedValue = shared[key]
            if sharedValue ~= nil then
                return sharedValue
            end

            return _G[key]
        end,
        __newindex = shared,
    })

    setfenv(1, moduleEnvironment)

function mapEditor:drawMagnet(route, point, magnetKind, selected)
    local graphics = love.graphics
    local endpoint = magnetKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route)
    local selectedColors = magnetKind == "end" and getEndpointColorIds(endpoint) or {}
    local endpointColorOption = (#selectedColors == 1) and getColorOptionById(selectedColors[1]) or nil
    local width = magnetKind == "start" and 58 or 46
    local height = 24

    graphics.setColor(0.08, 0.1, 0.14, 1)
    graphics.rectangle("fill", point.x - width * 0.5 - 3, point.y - height * 0.5 - 3, width + 6, height + 6, 9, 9)
    if magnetKind == "end" and endpointColorOption then
        graphics.setColor(endpointColorOption.color[1], endpointColorOption.color[2], endpointColorOption.color[3], 1)
    else
        graphics.setColor(route.color[1], route.color[2], route.color[3], 1)
    end
    graphics.rectangle("fill", point.x - width * 0.5, point.y - height * 0.5, width, height, 9, 9)

    graphics.setColor(0.05, 0.06, 0.08, 1)
    graphics.printf(
        magnetKind == "start" and "START" or "END",
        point.x - width * 0.5,
        point.y - 7,
        width,
        "center"
    )

    if magnetKind == "end" and #selectedColors > 1 then
        for index, colorId in ipairs(selectedColors) do
            local option = getColorOptionById(colorId)
            if option then
                local dotX = point.x - (#selectedColors - 1) * 6 + (index - 1) * 12
                local dotY = point.y + height * 0.5 + 9
                graphics.setColor(0.08, 0.1, 0.14, 1)
                graphics.circle("fill", dotX, dotY, 5)
                graphics.setColor(option.color[1], option.color[2], option.color[3], 1)
                graphics.circle("fill", dotX, dotY, 3.5)
            end
        end
    end

    if selected then
        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.setLineWidth(2)
        graphics.rectangle("line", point.x - width * 0.5 - 8, point.y - height * 0.5 - 8, width + 16, height + 16, 12, 12)
    end
end

function mapEditor:drawRoutePatternStroke(pointA, pointB, roadTypeId, alpha)
    local roadTypeConfig = roadTypes.getConfig(roadTypeId)
    if roadTypeConfig.pattern == "plain" then
        return
    end

    local graphics = love.graphics
    local length = segmentLength(pointA, pointB)
    if length <= 0.001 then
        return
    end

    local angle = angleBetweenPoints(pointA, pointB)
    local directionX = math.cos(angle)
    local directionY = math.sin(angle)
    local normalX = -directionY
    local normalY = directionX
    local markerSpacing = roadTypeConfig.markerSpacing
    local markerSize = roadTypeConfig.markerSize
    local markerDistance = markerSpacing * 0.5
    local outlineWidth = roadTypeConfig.markerWidth + 2
    local fillWidth = roadTypeConfig.markerWidth

    local function drawPatternSegment(startX, startY, endX, endY)
        graphics.setColor(ROAD_PATTERN_OUTLINE[1], ROAD_PATTERN_OUTLINE[2], ROAD_PATTERN_OUTLINE[3], alpha)
        graphics.setLineWidth(outlineWidth)
        graphics.line(startX, startY, endX, endY)
        graphics.setColor(ROAD_PATTERN_FILL[1], ROAD_PATTERN_FILL[2], ROAD_PATTERN_FILL[3], alpha)
        graphics.setLineWidth(fillWidth)
        graphics.line(startX, startY, endX, endY)
    end

    while markerDistance < length do
        local markerX = pointA.x + directionX * markerDistance
        local markerY = pointA.y + directionY * markerDistance

        if roadTypeConfig.pattern == "chevron" then
            local tipX = markerX + directionX * markerSize
            local tipY = markerY + directionY * markerSize
            local leftX = markerX - normalX * markerSize * 0.7
            local leftY = markerY - normalY * markerSize * 0.7
            local rightX = markerX + normalX * markerSize * 0.7
            local rightY = markerY + normalY * markerSize * 0.7
            drawPatternSegment(leftX, leftY, tipX, tipY)
            drawPatternSegment(rightX, rightY, tipX, tipY)
        elseif roadTypeConfig.pattern == "crossbar" then
            local startX = markerX - normalX * markerSize
            local startY = markerY - normalY * markerSize
            local endX = markerX + normalX * markerSize
            local endY = markerY + normalY * markerSize
            drawPatternSegment(startX, startY, endX, endY)
        end

        markerDistance = markerDistance + markerSpacing
    end
end

function mapEditor:drawRouteRoadTypeMarkers(route, selectedRouteId)
    local alpha = selectedRouteId == route.id and 0.98 or 0.86
    local segmentRoadTypes = self:ensureRouteSegmentRoadTypes(route)

    for segmentIndex = 1, #route.points - 1 do
        self:drawRoutePatternStroke(
            route.points[segmentIndex],
            route.points[segmentIndex + 1],
            segmentRoadTypes[segmentIndex],
            alpha
        )
    end
end

function mapEditor:buildRouteSegmentGroups(selectedRouteId)
    local grouped = {}

    for _, route in ipairs(self.routes) do
        for pointIndex = 1, #route.points - 1 do
            local a = route.points[pointIndex]
            local b = route.points[pointIndex + 1]
            local key = buildSegmentGroupKey(a, b)
            local group = grouped[key]

            if not group then
                group = {
                    a = copyPoint(a),
                    b = copyPoint(b),
                    routeIds = {},
                    routeLookup = {},
                    colorIds = {},
                    colorLookup = {},
                    selected = false,
                }
                grouped[key] = group
            end

            if not group.routeLookup[route.id] then
                group.routeLookup[route.id] = true
                group.routeIds[#group.routeIds + 1] = route.id
            end
            if not group.colorLookup[route.colorId] then
                group.colorLookup[route.colorId] = true
                group.colorIds[#group.colorIds + 1] = route.colorId
            end
            if route.id == selectedRouteId then
                group.selected = true
            end
        end
    end

    local groups = {}
    for _, group in pairs(grouped) do
        groups[#groups + 1] = group
    end

    table.sort(groups, function(first, second)
        if #first.colorIds ~= #second.colorIds then
            return #first.colorIds < #second.colorIds
        end
        if math.abs(first.a.y - second.a.y) > 0.5 then
            return first.a.y < second.a.y
        end
        if math.abs(first.a.x - second.a.x) > 0.5 then
            return first.a.x < second.a.x
        end
        return (#first.routeIds) < (#second.routeIds)
    end)

    return groups
end

function mapEditor:drawRoute(route, selectedRouteId)
    local graphics = love.graphics
    local points = {}
    self:ensureRouteSegmentRoadTypes(route)

    for _, point in ipairs(route.points) do
        points[#points + 1] = point.x
        points[#points + 1] = point.y
    end

    graphics.setLineStyle("smooth")
    graphics.setLineJoin("none")
    graphics.setColor(0.11, 0.14, 0.18, 1)
    graphics.setLineWidth(selectedRouteId == route.id and 16 or 13)
    graphics.line(points)

    graphics.setColor(route.color[1], route.color[2], route.color[3], selectedRouteId == route.id and 1 or 0.86)
    graphics.setLineWidth(selectedRouteId == route.id and 8 or 6)
    graphics.line(points)

    self:drawRouteRoadTypeMarkers(route, selectedRouteId)

    for pointIndex, point in ipairs(route.points) do
        local selected = selectedRouteId == route.id and pointIndex == self.selectedPointIndex
        if pointIndex == 1 then
            self:drawMagnet(route, point, "start", selected)
        elseif pointIndex == #route.points then
            self:drawMagnet(route, point, "end", selected)
        else
            graphics.setColor(0.08, 0.1, 0.14, 1)
            graphics.circle("fill", point.x, point.y, 11)
            graphics.setColor(route.color[1], route.color[2], route.color[3], 1)
            graphics.circle("fill", point.x, point.y, 8)
            if selected then
                graphics.setColor(0.97, 0.98, 1, 1)
                graphics.setLineWidth(2)
                graphics.circle("line", point.x, point.y, 16)
            end
        end
    end
end

function mapEditor:drawRouteSegmentGroup(group)
    local graphics = love.graphics
    local a = group.a
    local b = group.b
    local dx = b.x - a.x
    local dy = b.y - a.y
    local length = math.sqrt(dx * dx + dy * dy)
    local outerWidth = group.selected and 28 or 24
    local innerWidth = group.selected and 18 or 14

    graphics.setLineStyle("rough")
    graphics.setLineJoin("bevel")
    graphics.setColor(0.11, 0.14, 0.18, 1)
    graphics.setLineWidth(outerWidth)
    graphics.line(a.x, a.y, b.x, b.y)

    if #group.colorIds <= 1 or length <= 0.0001 then
        local option = getColorOptionById(group.colorIds[1] or COLOR_OPTIONS[1].id)
        local color = option and option.color or COLOR_OPTIONS[1].color
        graphics.setColor(color[1], color[2], color[3], group.selected and 1 or 0.86)
        graphics.setLineWidth(innerWidth)
        graphics.line(a.x, a.y, b.x, b.y)
        return
    end

    local unitX = dx / length
    local unitY = dy / length
    local stripeCount = math.max(1, #group.colorIds)
    local stripeLength = math.max(8, SHARED_LANE_STRIPE_LENGTH - stripeCount)

    graphics.setLineWidth(innerWidth)
    for stripeIndex = 0, math.ceil(length / stripeLength) - 1 do
        local stripeStart = stripeIndex * stripeLength
        local stripeEnd = math.min(length, stripeStart + stripeLength)
        local colorId = group.colorIds[(stripeIndex % #group.colorIds) + 1]
        local option = getColorOptionById(colorId)
        local color = option and option.color or COLOR_OPTIONS[1].color
        graphics.setColor(color[1], color[2], color[3], group.selected and 1 or 0.92)
        graphics.line(
            a.x + unitX * stripeStart,
            a.y + unitY * stripeStart,
            a.x + unitX * stripeEnd,
            a.y + unitY * stripeEnd
        )
    end
end

function mapEditor:drawRouteHandles(route, selectedRouteId)
    local graphics = love.graphics

    for pointIndex, point in ipairs(route.points) do
        local selected = selectedRouteId == route.id and pointIndex == self.selectedPointIndex
        if pointIndex == 1 then
            self:drawMagnet(route, point, "start", selected)
        elseif pointIndex == #route.points then
            self:drawMagnet(route, point, "end", selected)
        else
            local isSharedJunctionPoint = point.sharedPointId and self:getSharedPointGroupForPoint(route, pointIndex)
            if not isSharedJunctionPoint then
                graphics.setColor(0.08, 0.1, 0.14, 1)
                graphics.circle("fill", point.x, point.y, 11)
                graphics.setColor(route.color[1], route.color[2], route.color[3], 1)
                graphics.circle("fill", point.x, point.y, 8)
                if selected then
                    graphics.setColor(0.97, 0.98, 1, 1)
                    graphics.setLineWidth(2)
                    graphics.circle("line", point.x, point.y, 16)
                end
            end
        end
    end
end

function mapEditor:drawIntersection(intersection)
    if not intersection.unsupported then
        return
    end

    local graphics = love.graphics
    local radius = 16 / math.max(self.camera.zoom, 0.0001)

    graphics.setColor(0.78, 0.22, 0.18, 0.92)
    graphics.circle("fill", intersection.x, intersection.y, radius)
    graphics.setColor(0.98, 0.96, 0.96, 1)
    graphics.setLineWidth(3 / math.max(self.camera.zoom, 0.0001))
    graphics.line(intersection.x - radius * 0.45, intersection.y - radius * 0.45, intersection.x + radius * 0.45, intersection.y + radius * 0.45)
    graphics.line(intersection.x - radius * 0.45, intersection.y + radius * 0.45, intersection.x + radius * 0.45, intersection.y - radius * 0.45)
end

function mapEditor:drawPanelButton(rect, label, accentColor, isDisabled)
    local graphics = love.graphics
    local font = graphics.getFont()
    if isDisabled then
        graphics.setColor(0.08, 0.1, 0.13, 0.72)
    else
        graphics.setColor(0.1, 0.12, 0.16, 0.96)
    end
    graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 12, 12)
    graphics.setLineWidth(1.5)
    if isDisabled then
        graphics.setColor(0.34, 0.38, 0.42, 0.85)
    else
        graphics.setColor(accentColor[1], accentColor[2], accentColor[3], 1)
    end
    graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 12, 12)
    if isDisabled then
        graphics.setColor(0.6, 0.64, 0.68, 0.9)
    else
        graphics.setColor(0.97, 0.98, 1, 1)
    end
    graphics.printf(label, rect.x, rect.y + math.floor((rect.h - font:getHeight()) * 0.5), rect.w, "center")
end

function mapEditor:drawHitboxToggle(game)
    local graphics = love.graphics
    local rect = self:getHitboxToggleRect()
    local accentColor = self.hitboxOverlayVisible and { 0.48, 0.92, 0.62 } or { 0.36, 0.42, 0.5 }
    self:drawPanelButton(rect, "Hitboxes (F3)", accentColor)
end

function mapEditor:drawGrid()
    if not self.gridVisible then
        return
    end

    local graphics = love.graphics
    local step = sanitizeGridStep(self.gridStep)
    local halfW, halfH = self:getCameraViewHalfExtents()
    local startX = math.max(0, math.floor((self.camera.x - halfW) / step) * step)
    local endX = math.min(self.mapSize.w, math.ceil((self.camera.x + halfW) / step) * step)
    local startY = math.max(0, math.floor((self.camera.y - halfH) / step) * step)
    local endY = math.min(self.mapSize.h, math.ceil((self.camera.y + halfH) / step) * step)
    local majorStep = step * 4

    graphics.setLineWidth(1 / math.max(self.camera.zoom, 0.0001))
    for gridX = startX, endX, step do
        local isMajor = (gridX % majorStep) == 0
        graphics.setColor(0.62, 0.72, 0.82, isMajor and GRID_MAJOR_ALPHA or GRID_MINOR_ALPHA)
        graphics.line(gridX, 0, gridX, self.mapSize.h)
    end

    for gridY = startY, endY, step do
        local isMajor = (gridY % majorStep) == 0
        graphics.setColor(0.62, 0.72, 0.82, isMajor and GRID_MAJOR_ALPHA or GRID_MINOR_ALPHA)
        graphics.line(0, gridY, self.mapSize.w, gridY)
    end
end

function mapEditor:drawWrappedList(font, items, x, y, width, limitY, color, numberColor)
    local graphics = love.graphics
    local currentY = y
    local renderedCount = 0

    love.graphics.setFont(font)
    for index, item in ipairs(items or {}) do
        local bullet = string.format("%d. ", index)
        local lineHeight = font:getHeight()
        local lineCount = getWrappedLineCount(font, item, math.max(20, width - 22))
        local itemHeight = math.max(lineHeight, lineCount * lineHeight)

        if currentY + itemHeight > limitY then
            break
        end

        graphics.setColor(numberColor[1], numberColor[2], numberColor[3], numberColor[4] or 1)
        graphics.print(bullet, x, currentY)
        graphics.setColor(color[1], color[2], color[3], color[4] or 1)
        graphics.printf(item, x + 22, currentY, width - 22)
        currentY = currentY + itemHeight + 10
        renderedCount = renderedCount + 1
    end

    return currentY, renderedCount
end

function mapEditor:drawStatusToast(game)
    if not self.statusText or self.statusTimer <= 0 then
        return
    end

    local graphics = love.graphics
    local fadeAlpha = 1
    if self.statusTimer < STATUS_TOAST_FADE_TIME then
        fadeAlpha = self.statusTimer / STATUS_TOAST_FADE_TIME
    end

    local font = game.fonts.small
    local maxWidth = math.max(220, math.min(420, self:getCameraViewportRect().w - STATUS_TOAST_MARGIN * 2))
    local textWidth = maxWidth - 24
    local textHeight = getWrappedLineCount(font, self.statusText, textWidth) * font:getHeight()
    local toastRect = {
        x = STATUS_TOAST_MARGIN,
        y = self.viewport.h - STATUS_TOAST_MARGIN - textHeight - 20,
        w = maxWidth,
        h = textHeight + 20,
    }

    love.graphics.setFont(font)
    graphics.setColor(0.08, 0.1, 0.14, 0.96 * fadeAlpha)
    graphics.rectangle("fill", toastRect.x, toastRect.y, toastRect.w, toastRect.h, 12, 12)
    graphics.setColor(0.48, 0.92, 0.62, 0.95 * fadeAlpha)
    graphics.rectangle("line", toastRect.x, toastRect.y, toastRect.w, toastRect.h, 12, 12)
    graphics.setColor(0.48, 0.92, 0.62, 0.9 * fadeAlpha)
    graphics.rectangle("fill", toastRect.x, toastRect.y, 4, toastRect.h, 12, 12)
    graphics.setColor(0.92, 0.96, 1, fadeAlpha)
    graphics.printf(self.statusText, toastRect.x + 14, toastRect.y + 10, textWidth)
end

function mapEditor:drawEditorStaticJunctionIcon(image, centerX, centerY, size, scaleMultiplier, alpha)
    if not image then
        return false
    end

    local imageWidth, imageHeight = image:getDimensions()
    local scale = math.min((size * scaleMultiplier) / imageWidth, (size * scaleMultiplier) / imageHeight)
    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(
        image,
        centerX,
        centerY,
        0,
        scale,
        scale,
        imageWidth * 0.5,
        imageHeight * 0.5
    )
    return true
end

function mapEditor:drawEditorHourglassIcon(centerX, centerY, size, color)
    local graphics = love.graphics
    local halfWidth = size * 0.34
    local halfHeight = size * 0.46
    local neckWidth = size * 0.08

    graphics.push()
    graphics.translate(centerX, centerY)
    graphics.setColor(color[1], color[2], color[3], 1)
    graphics.polygon(
        "fill",
        -halfWidth, -halfHeight,
        halfWidth, -halfHeight,
        neckWidth, 0,
        -neckWidth, 0
    )
    graphics.polygon(
        "fill",
        -neckWidth, 0,
        neckWidth, 0,
        halfWidth, halfHeight,
        -halfWidth, halfHeight
    )
    graphics.setLineWidth(2)
    graphics.setColor(0.05, 0.06, 0.08, 0.96)
    graphics.line(-halfWidth, -halfHeight, halfWidth, -halfHeight)
    graphics.line(-halfWidth, halfHeight, halfWidth, halfHeight)
    graphics.line(-halfWidth, -halfHeight, -neckWidth, 0, -halfWidth, halfHeight)
    graphics.line(halfWidth, -halfHeight, neckWidth, 0, halfWidth, halfHeight)
    graphics.pop()
end

function mapEditor:drawEditorControlIcon(controlType, centerX, centerY, size)
    self:ensureEditorJunctionIcons()

    if controlType == "direct" then
        if self:drawEditorStaticJunctionIcon(self.editorDirectImage, centerX, centerY, size, 1.4, 0.98) then
            return
        end
    elseif controlType == "delayed" then
        self:drawEditorHourglassIcon(centerX, centerY, size, { 0.05, 0.06, 0.08 })
        return
    elseif controlType == "pump" then
        if self:drawEditorStaticJunctionIcon(self.editorChargeImage, centerX, centerY, size, 1.32, 0.98) then
            return
        end
    elseif controlType == "spring" then
        if self:drawEditorStaticJunctionIcon(self.editorSpringImage, centerX, centerY, size, 1.18, 0.98) then
            return
        end
    elseif controlType == "relay" then
        if self:drawEditorStaticJunctionIcon(self.editorRelayImage, centerX, centerY, size, 1.42, 0.98) then
            return
        end
    elseif controlType == "trip" then
        if self:drawEditorStaticJunctionIcon(self.editorTripImage, centerX, centerY, size, 1.36, 0.98) then
            return
        end
    elseif controlType == "crossbar" then
        if self:drawEditorStaticJunctionIcon(self.editorCrossImage, centerX, centerY, size, 1.4, 0.98) then
            return
        end
    end

    love.graphics.setColor(0.05, 0.06, 0.08, 1)
    love.graphics.printf(
        self:getControlLabel(controlType),
        centerX - size,
        centerY - 8,
        size * 2,
        "center"
    )
end

function mapEditor:drawJunctionMenuRoot(layout, intersection, colorOptions)
    local graphics = love.graphics
    local root = layout.root
    local leftColor = #colorOptions > 0 and { 0.82, 0.86, 0.9, 0.92 } or { 0.24, 0.28, 0.32, 0.82 }
    local isRouteEnd = self.colorPicker and self.colorPicker.mode == "route_end"
    local rightColor = isRouteEnd
        and { 0.36, 0.42, 0.5, 0.92 }
        or (CONTROL_FILL_COLORS[intersection.controlType] or CONTROL_FILL_COLORS.direct)
    local hoverBranch = layout.hoverBranch

    graphics.setColor(0.05, 0.06, 0.08, 0.94)
    graphics.circle("fill", root.x, root.y, root.radius + 6)

    graphics.setColor(leftColor[1], leftColor[2], leftColor[3], hoverBranch == "disconnect" and 0.32 or 0.18)
    graphics.arc("fill", "pie", root.x, root.y, root.radius, math.pi * 0.5, math.pi * 1.5)
    graphics.setColor(rightColor[1], rightColor[2], rightColor[3], hoverBranch == "junctions" and 0.38 or 0.22)
    graphics.arc("fill", "pie", root.x, root.y, root.radius, -math.pi * 0.5, math.pi * 0.5)

    graphics.setColor(0.97, 0.98, 1, 0.86)
    graphics.setLineWidth(2)
    graphics.circle("line", root.x, root.y, root.radius)
    graphics.line(root.x, root.y - root.radius + 4, root.x, root.y + root.radius - 4)

    local colorCount = math.min(3, #colorOptions)
    for colorIndex = 1, colorCount do
        local option = colorOptions[colorIndex]
        local dotY = root.y + (colorIndex - (colorCount + 1) * 0.5) * (JUNCTION_MENU_SWATCH_RADIUS * 2 + 4)
        graphics.setColor(0.05, 0.06, 0.08, 1)
        graphics.circle("fill", root.x - root.radius * 0.36, dotY, JUNCTION_MENU_SWATCH_RADIUS + 3)
        graphics.setColor(option.color[1], option.color[2], option.color[3], 1)
        graphics.circle("fill", root.x - root.radius * 0.36, dotY, JUNCTION_MENU_SWATCH_RADIUS)
    end

    if isRouteEnd then
        graphics.setColor(0.05, 0.06, 0.08, 1)
        graphics.printf(
            "END",
            root.x + 4,
            root.y - 9,
            root.radius - 8,
            "center"
        )
    else
        self:drawEditorControlIcon(intersection.controlType, root.x + root.radius * 0.5, root.y, JUNCTION_MENU_ICON_SIZE)
    end
end

function mapEditor:drawJunctionMenuSubmenu(layout, intersection)
    local graphics = love.graphics
    local submenu = layout.submenu
    if not submenu then
        return
    end

    graphics.setColor(0.05, 0.06, 0.08, 0.94)
    graphics.circle("fill", submenu.x, submenu.y, submenu.radius + 6)
    graphics.setColor(0.97, 0.98, 1, 0.86)
    graphics.setLineWidth(2)
    graphics.circle("line", submenu.x, submenu.y, submenu.radius)

    if #submenu.entries == 0 then
        return
    end

    for _, entry in ipairs(submenu.entries) do
        local isHovered = self.colorPicker.hoverOptionIndex == entry.index
        local color = nil
        local iconSize = submenu.branch == "junctions" and JUNCTION_MENU_TYPE_ICON_SIZE or JUNCTION_MENU_ICON_SIZE
        if submenu.branch == "disconnect" then
            color = entry.option.color
        else
            color = CONTROL_FILL_COLORS[entry.option.controlType] or CONTROL_FILL_COLORS.direct
        end

        graphics.setColor(color[1], color[2], color[3], isHovered and 0.44 or 0.26)
        graphics.arc("fill", "pie", submenu.x, submenu.y, submenu.outerRadius, entry.startAngle, entry.endAngle)
        graphics.setColor(0.05, 0.06, 0.08, 1)
        graphics.arc("line", "open", submenu.x, submenu.y, submenu.outerRadius, entry.startAngle, entry.endAngle)

        if submenu.branch == "disconnect" then
            graphics.setColor(0.05, 0.06, 0.08, 1)
            graphics.circle("fill", entry.centerX, entry.centerY, JUNCTION_MENU_SWATCH_RADIUS + 3)
            graphics.setColor(color[1], color[2], color[3], 1)
            graphics.circle("fill", entry.centerX, entry.centerY, JUNCTION_MENU_SWATCH_RADIUS)
        else
            self:drawEditorControlIcon(entry.option.controlType, entry.centerX, entry.centerY, iconSize)
            if entry.option.controlType == intersection.controlType then
                graphics.setColor(0.97, 0.98, 1, 1)
                graphics.setLineWidth(2)
                graphics.circle("line", entry.centerX, entry.centerY, iconSize + 6)
            end
        end
    end
end

function mapEditor:drawScrollableWrappedList(font, items, listRect, scrollOffset, color, numberColor)
    local graphics = love.graphics
    local currentY = listRect.y - (scrollOffset or 0)

    love.graphics.setFont(font)
    love.graphics.setScissor(listRect.x, listRect.y, listRect.w, listRect.h)
    for index, item in ipairs(items or {}) do
        local bullet = string.format("%d. ", index)
        local lineHeight = font:getHeight()
        local lineCount = getWrappedLineCount(font, item, math.max(20, listRect.w - 22))
        local itemHeight = math.max(lineHeight, lineCount * lineHeight)
        local itemBottom = currentY + itemHeight

        if itemBottom >= listRect.y and currentY <= listRect.y + listRect.h then
            graphics.setColor(numberColor[1], numberColor[2], numberColor[3], numberColor[4] or 1)
            graphics.print(bullet, listRect.x, currentY)
            graphics.setColor(color[1], color[2], color[3], color[4] or 1)
            graphics.printf(item, listRect.x + 22, currentY, listRect.w - 22)
        end

        currentY = currentY + itemHeight + 10
    end
    love.graphics.setScissor()
end

function mapEditor:drawValidationMarkers()
    local graphics = love.graphics
    local cameraViewport = self:getCameraViewportRect()

    for index, entry in ipairs(self:getValidationEntries()) do
        local diagnostic = type(entry) == "table" and entry.diagnostic or nil
        if diagnostic and diagnostic.x and diagnostic.y then
            local x, y = self:mapToScreen(diagnostic.x, diagnostic.y)
            local isHovered = self.hoveredValidationIndex == index
            local size = isHovered and 13 or 9

            if pointInRect(x, y, cameraViewport) then
                graphics.setLineWidth(isHovered and 5 or 4)
                graphics.setColor(0.96, 0.22, 0.22, isHovered and 1 or 0.92)
                graphics.line(x - size, y - size, x + size, y + size)
                graphics.line(x - size, y + size, x + size, y - size)

                if isHovered then
                    graphics.setColor(1, 0.9, 0.35, 0.95)
                    graphics.circle("line", x, y, size + 7)
                end
            end
        end
    end
end

function mapEditor:drawHitboxOverlay(game)
    if not self.hitboxOverlayVisible then
        return
    end

    local graphics = love.graphics
    local font = game.fonts.small
    local zoom = math.max(self.camera.zoom, HITBOX_OVERLAY_EPSILON)
    local inverseZoom = 1 / zoom

    love.graphics.setFont(font)

    for _, entry in ipairs(self:getHitboxOverlayEntries()) do
        local color = entry.color

        graphics.setColor(color[1], color[2], color[3], HITBOX_OVERLAY_FILL_ALPHA)
        if entry.kind == "polygon" then
            graphics.polygon("fill", entry.points)
        elseif entry.kind == "circle" then
            graphics.circle("fill", entry.x, entry.y, entry.radius)
        else
            graphics.rectangle(
                "fill",
                entry.rect.x,
                entry.rect.y,
                entry.rect.w,
                entry.rect.h,
                HITBOX_OVERLAY_RECT_CORNER_RADIUS,
                HITBOX_OVERLAY_RECT_CORNER_RADIUS
            )
        end

        graphics.setColor(color[1], color[2], color[3], HITBOX_OVERLAY_OUTLINE_ALPHA)
        graphics.setLineWidth(HITBOX_OVERLAY_STROKE_WIDTH * inverseZoom)
        if entry.kind == "polygon" then
            graphics.polygon("line", entry.points)
        elseif entry.kind == "circle" then
            graphics.circle("line", entry.x, entry.y, entry.radius)
        else
            graphics.rectangle(
                "line",
                entry.rect.x,
                entry.rect.y,
                entry.rect.w,
                entry.rect.h,
                HITBOX_OVERLAY_RECT_CORNER_RADIUS,
                HITBOX_OVERLAY_RECT_CORNER_RADIUS
            )
        end

        local labelWidth = font:getWidth(entry.label) + HITBOX_OVERLAY_LABEL_PADDING_X * 2
        local labelHeight = font:getHeight() + HITBOX_OVERLAY_LABEL_PADDING_Y * 2

        graphics.push()
        graphics.translate(entry.labelX, entry.labelY)
        graphics.scale(inverseZoom, inverseZoom)
        graphics.setColor(0.05, 0.06, 0.08, HITBOX_OVERLAY_LABEL_BACKGROUND_ALPHA)
        graphics.rectangle(
            "fill",
            -labelWidth * 0.5,
            -HITBOX_OVERLAY_LABEL_OFFSET_Y - labelHeight,
            labelWidth,
            labelHeight,
            HITBOX_OVERLAY_LABEL_CORNER_RADIUS,
            HITBOX_OVERLAY_LABEL_CORNER_RADIUS
        )
        graphics.setColor(color[1], color[2], color[3], HITBOX_OVERLAY_OUTLINE_ALPHA)
        graphics.rectangle(
            "line",
            -labelWidth * 0.5,
            -HITBOX_OVERLAY_LABEL_OFFSET_Y - labelHeight,
            labelWidth,
            labelHeight,
            HITBOX_OVERLAY_LABEL_CORNER_RADIUS,
            HITBOX_OVERLAY_LABEL_CORNER_RADIUS
        )
        graphics.setColor(0.97, 0.98, 1, HITBOX_OVERLAY_LABEL_TEXT_ALPHA)
        graphics.print(
            entry.label,
            -labelWidth * 0.5 + HITBOX_OVERLAY_LABEL_PADDING_X,
            -HITBOX_OVERLAY_LABEL_OFFSET_Y - labelHeight + HITBOX_OVERLAY_LABEL_PADDING_Y
        )
        graphics.pop()
    end
end

function mapEditor:drawColorPicker(game)
    local layout = self:getColorPickerLayout()
    if not layout then
        return
    end

    local graphics = love.graphics
    local lookup = self:getColorPickerSelectionLookup()

    if layout.kind == "junction_radial" then
        local intersection = nil
        if self.colorPicker.mode == "junction" then
            intersection = self:getIntersectionById(self.colorPicker.intersectionId)
            if not intersection then
                return
            end
        elseif self.colorPicker.mode ~= "route_end" then
            return
        end

        local colorOptions = self:getColorPickerOptions()
        local popupScale = self:getJunctionPickerPopupScale()
        local originX, originY = self:getJunctionPickerPopupOrigin()

        graphics.push()
        graphics.translate(originX, originY)
        graphics.scale(popupScale, popupScale)
        graphics.translate(-originX, -originY)
        if layout.branch then
            self:drawJunctionMenuSubmenu(layout, intersection)
        else
            self:drawJunctionMenuRoot(layout, intersection, colorOptions)
        end
        graphics.pop()
        return
    end

    graphics.setColor(0.08, 0.1, 0.14, 0.98)
    graphics.rectangle("fill", layout.rect.x, layout.rect.y, layout.rect.w, layout.rect.h, 16, 16)
    graphics.setColor(0.24, 0.32, 0.4, 1)
    graphics.setLineWidth(1.2)
    graphics.rectangle("line", layout.rect.x, layout.rect.y, layout.rect.w, layout.rect.h, 16, 16)

    for _, swatch in ipairs(layout.swatches) do
        local rect = swatch.rect
        local option = swatch.option
        local selected = lookup[option.id]

        graphics.setColor(0.05, 0.06, 0.08, 1)
        graphics.rectangle("fill", rect.x - 3, rect.y - 3, rect.w + 6, rect.h + 6, 10, 10)
        graphics.setColor(option.color[1], option.color[2], option.color[3], 1)
        graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)

        if selected then
            graphics.setColor(0.97, 0.98, 1, 1)
            graphics.setLineWidth(2)
            graphics.rectangle("line", rect.x - 3, rect.y - 3, rect.w + 6, rect.h + 6, 10, 10)
        end
    end
end

function mapEditor:drawRoadTypePreview(option, rect, alpha)
    local graphics = love.graphics
    local centerY = rect.y + rect.h * 0.5
    local startX = rect.x + 10
    local endX = rect.x + rect.w - 10

    graphics.setColor(0.1, 0.12, 0.16, alpha)
    graphics.setLineWidth(10)
    graphics.line(startX, centerY, endX, centerY)
    graphics.setColor(0.84, 0.88, 0.92, alpha)
    graphics.setLineWidth(4)
    graphics.line(startX, centerY, endX, centerY)

    if option.pattern == "chevron" then
        self:drawRoutePatternStroke(
            { x = rect.x + 18, y = centerY },
            { x = rect.x + rect.w - 18, y = centerY },
            option.id,
            alpha
        )
    elseif option.pattern == "crossbar" then
        self:drawRoutePatternStroke(
            { x = rect.x + 18, y = centerY },
            { x = rect.x + rect.w - 18, y = centerY },
            option.id,
            alpha
        )
    end
end

function mapEditor:drawRouteTypePicker(game)
    local layout = self:getRouteTypePickerLayout()
    if not layout then
        return
    end

    local route = self:getRouteById(self.routeTypePicker.routeId)
    if not route then
        return
    end

    local graphics = love.graphics
    local selectedRoadType = self:getRouteSegmentRoadType(route, self.routeTypePicker.segmentIndex)

    graphics.setColor(0.08, 0.1, 0.14, 0.98)
    graphics.rectangle("fill", layout.rect.x, layout.rect.y, layout.rect.w, layout.rect.h, 16, 16)
    graphics.setColor(0.24, 0.32, 0.4, 1)
    graphics.rectangle("line", layout.rect.x, layout.rect.y, layout.rect.w, layout.rect.h, 16, 16)

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf(
        "Road Type For Segment " .. tostring(self.routeTypePicker.segmentIndex),
        layout.rect.x + 14,
        layout.rect.y + 14,
        layout.rect.w - 28,
        "center"
    )

    for _, optionEntry in ipairs(layout.options) do
        local option = optionEntry.option
        local rect = optionEntry.rect
        local isSelected = option.id == selectedRoadType

        graphics.setColor(0.05, 0.06, 0.08, 1)
        graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 12, 12)
        graphics.setColor(0.58, 0.64, 0.7, 1)
        graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 12, 12)

        self:drawRoadTypePreview(option, {
            x = rect.x + 10,
            y = rect.y + 8,
            w = 48,
            h = rect.h - 16,
        }, 1)

        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.print(option.label, rect.x + 68, rect.y + 8)
        graphics.setColor(0.72, 0.78, 0.84, 1)
        graphics.print(string.format("%d%% speed", math.floor(option.speedScale * 100 + 0.5)), rect.x + 68, rect.y + 22)

        if isSelected then
            graphics.setColor(0.97, 0.98, 1, 1)
            graphics.setLineWidth(2)
            graphics.rectangle("line", rect.x - 2, rect.y - 2, rect.w + 4, rect.h + 4, 14, 14)
        end
    end
end

function mapEditor:drawDialog(game)
    if not self.dialog then
        return
    end

    local graphics = love.graphics
    local rect = self:getDialogRect()

    graphics.setColor(0, 0, 0, 0.48)
    graphics.rectangle("fill", 0, 0, self.viewport.w, self.viewport.h)

    graphics.setColor(0.09, 0.11, 0.15, 0.98)
    graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 18, 18)
    graphics.setColor(0.24, 0.32, 0.4, 1)
    graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 18, 18)

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)

    if self.dialog.type == "save" then
        graphics.printf("Save Map", rect.x, rect.y + 20, rect.w, "center")
        love.graphics.setFont(game.fonts.body)
        graphics.setColor(0.84, 0.88, 0.92, 1)
        graphics.printf("Give this map a name and press Enter to save it.", rect.x + 24, rect.y + 88, rect.w - 48, "center")
        graphics.setColor(0.05, 0.06, 0.08, 1)
        graphics.rectangle("fill", rect.x + 34, rect.y + 150, rect.w - 68, 52, 14, 14)
        graphics.setColor(0.48, 0.92, 0.62, 1)
        graphics.rectangle("line", rect.x + 34, rect.y + 150, rect.w - 68, 52, 14, 14)
        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.printf(self.dialog.input ~= "" and self.dialog.input or "Type a map name...", rect.x + 48, rect.y + 166, rect.w - 96, "left")
        love.graphics.setFont(game.fonts.small)
        graphics.setColor(0.72, 0.78, 0.84, 1)
        graphics.printf("Esc closes this dialog. S opens save. O opens load.", rect.x + 24, rect.y + 236, rect.w - 48, "center")
        return
    end

    if self.dialog.type == "confirm_reset" then
        graphics.printf("Reset Map", rect.x, rect.y + 20, rect.w, "center")
        love.graphics.setFont(game.fonts.body)
        graphics.setColor(0.84, 0.88, 0.92, 1)
        graphics.printf(
            "Discard the current map without saving and open a new blank map?\nAny unsaved changes will be lost.",
            rect.x + 32,
            rect.y + 102,
            rect.w - 64,
            "center"
        )
        local buttons = self:getConfirmResetDialogButtons()
        love.graphics.setFont(game.fonts.small)
        self:drawPanelButton(buttons.confirm, "Open Blank Map", { 0.99, 0.78, 0.32 })
        self:drawPanelButton(buttons.cancel, "Cancel", { 0.33, 0.8, 0.98 })
        graphics.setColor(0.72, 0.78, 0.84, 1)
        graphics.printf("Enter confirms. Esc or N cancels.", rect.x + 24, rect.y + rect.h - 126, rect.w - 48, "center")
        return
    end

    graphics.printf("Open Map", rect.x, rect.y + 20, rect.w, "center")
    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.84, 0.88, 0.92, 1)
    local layout = self:getOpenDialogListLayout()
    if layout.totalMaps == 0 then
        graphics.printf("No maps were found yet.", rect.x + 24, rect.y + 142, rect.w - 48, "center")
        return
    end

    love.graphics.setScissor(layout.listRect.x, layout.listRect.y, layout.listRect.w, layout.listRect.h)
    for _, row in ipairs(layout.rows) do
        local savedMap = row.map
        local itemRect = row.rect
        graphics.setColor(0.05, 0.06, 0.08, 1)
        graphics.rectangle("fill", itemRect.x, itemRect.y, itemRect.w, itemRect.h, 12, 12)
        graphics.setColor(0.3, 0.36, 0.42, 1)
        graphics.rectangle("line", itemRect.x, itemRect.y, itemRect.w, itemRect.h, 12, 12)
        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.print(savedMap.name, itemRect.x + 14, itemRect.y + 12)
        graphics.setColor(0.72, 0.78, 0.84, 1)
        graphics.printf(savedMap.source == "builtin" and "Tutorial" or "User Save", itemRect.x, itemRect.y + 12, itemRect.w - 12, "right")
    end
    love.graphics.setScissor()

    if layout.scrollbar then
        graphics.setColor(0.1, 0.12, 0.16, 1)
        graphics.rectangle("fill", layout.scrollbar.track.x, layout.scrollbar.track.y, layout.scrollbar.track.w, layout.scrollbar.track.h, 4, 4)
        graphics.setColor(0.34, 0.44, 0.54, 1)
        graphics.rectangle("fill", layout.scrollbar.thumb.x, layout.scrollbar.thumb.y, layout.scrollbar.thumb.w, layout.scrollbar.thumb.h, 4, 4)
    end

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.72, 0.78, 0.84, 1)
    local rangeText = string.format("Showing %d-%d of %d", layout.firstVisibleIndex, layout.lastVisibleIndex, layout.totalMaps)
    graphics.printf(rangeText, rect.x + 24, rect.y + rect.h - 52, rect.w - 48, "left")
end

function mapEditor:drawTextField(label, rect, valueText, accentColor, active)
    local graphics = love.graphics
    local color = accentColor or { 0.48, 0.92, 0.62 }

    graphics.setColor(0.72, 0.78, 0.84, 1)
    graphics.printf(label, rect.x - 4, rect.y - 17, rect.w + 8, "center")

    graphics.setColor(0.06, 0.08, 0.1, 1)
    graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)
    graphics.setLineWidth(active and 2 or 1.2)
    graphics.setColor(color[1], color[2], color[3], 1)
    graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 8, 8)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf(valueText, rect.x + 6, rect.y + 5, rect.w - 12, "left")
end

function mapEditor:drawColorChip(label, rect, colorId, accentColor)
    local graphics = love.graphics
    local color = accentColor or getColorById(colorId)
    local labelWidth = love.graphics.getFont():getWidth(label)

    graphics.setColor(0.72, 0.78, 0.84, 1)
    graphics.print(label, rect.x - labelWidth - 6, rect.y - 1)

    graphics.setColor(0.06, 0.08, 0.1, 1)
    graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 5, 5)
    graphics.setColor(color[1], color[2], color[3], 1)
    graphics.rectangle("fill", rect.x + 2, rect.y + 2, rect.w - 4, rect.h - 4, 4, 4)
    graphics.setLineWidth(1.1)
    graphics.setColor(0.24, 0.32, 0.4, 1)
    graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 5, 5)
end

function mapEditor:drawSequencerSummaryChip(rect, colorId)
    local graphics = love.graphics
    local color = getColorById(colorId)

    graphics.setColor(0.06, 0.08, 0.1, 1)
    graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 4, 4)
    graphics.setColor(color[1], color[2], color[3], 1)
    graphics.rectangle("fill", rect.x + 2, rect.y + 2, rect.w - 4, rect.h - 4, 3, 3)
    graphics.setLineWidth(1)
    graphics.setColor(0.24, 0.32, 0.4, 1)
    graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 4, 4)
end

function mapEditor:drawSequencerSummaryValue(rect, valueText, align)
    local graphics = love.graphics
    graphics.setColor(0.84, 0.88, 0.92, 1)
    graphics.printf(valueText or "", rect.x, rect.y + 1, rect.w, align or "center")
end

function mapEditor:drawSequencerInlineField(rect, valueText, accentColor, active)
    local graphics = love.graphics
    local color = accentColor or { 0.48, 0.92, 0.62 }

    graphics.setColor(0.06, 0.08, 0.1, 1)
    graphics.rectangle("fill", rect.x, rect.y - 1, rect.w, rect.h + 2, 6, 6)
    graphics.setLineWidth(active and 1.8 or 1)
    graphics.setColor(color[1], color[2], color[3], 1)
    graphics.rectangle("line", rect.x, rect.y - 1, rect.w, rect.h + 2, 6, 6)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf(valueText or "", rect.x + 4, rect.y + 1, rect.w - 8, "center")
end

function mapEditor:drawSequencer(game)
    local graphics = love.graphics
    local layout = self:getSequencerLayout()
    local mapDeadlineText = self:getActiveTextFieldValue("map", "map", "timeLimit", self.timeLimit and tostring(self.timeLimit) or "")

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.print("Train Sequencer", layout.panelX, self.sidePanel.y + 20)

    love.graphics.setFont(game.fonts.small)
    self:drawTextField(
        "Map Deadline",
        layout.mapDeadlineRect,
        mapDeadlineText ~= "" and mapDeadlineText or "",
        { 0.99, 0.78, 0.32 },
        self.activeTextField and self.activeTextField.kind == "map"
    )
    self:drawPanelButton(layout.addRect, "Add Train", { 0.48, 0.92, 0.62 })

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.68, 0.74, 0.8, 1)
    local header = self:getSequencerSummaryRects(layout.listHeaderRect)
    graphics.printf("Start", header.start.x - 2, layout.listHeaderRect.y, header.start.w + 4, "center")
    graphics.printf("Name", header.name.x - 2, layout.listHeaderRect.y, header.name.w + 4, "center")
    graphics.printf("Line", header.lineChip.x - 6, layout.listHeaderRect.y, header.lineChip.w + 12, "center")
    graphics.printf("Goal", header.goalChip.x - 6, layout.listHeaderRect.y, header.goalChip.w + 12, "center")
    graphics.printf("Wagons", header.wagons.x - 4, layout.listHeaderRect.y, header.wagons.w + 8, "center")
    graphics.printf("Deadline", header.deadline.x - 4, layout.listHeaderRect.y, header.deadline.w + 8, "center")

    love.graphics.setScissor(layout.listRect.x, layout.listRect.y, layout.listRect.w, layout.listRect.h)
    for _, row in ipairs(layout.rows) do
        local entry = row.entry
        local train = entry.train
        local controls = self:getSequencerRowControlRects(row.rect)
        local startText = self:getActiveTextFieldValue("train", train.id, "spawnTime", tostring(train.spawnTime or 0))
        local wagonsText = self:getActiveTextFieldValue("train", train.id, "wagonCount", tostring(train.wagonCount or DEFAULT_TRAIN_WAGONS))
        local deadlineText = self:getActiveTextFieldValue("train", train.id, "deadline", train.deadline and tostring(train.deadline) or "--")

        graphics.setColor(0.06, 0.08, 0.1, 1)
        graphics.rectangle("fill", row.rect.x, row.rect.y, row.rect.w, row.rect.h, 12, 12)
        graphics.setLineWidth(1.1)
        graphics.setColor(0.24, 0.32, 0.4, 1)
        graphics.rectangle("line", row.rect.x, row.rect.y, row.rect.w, row.rect.h, 12, 12)

        love.graphics.setFont(game.fonts.small)
        self:drawSequencerInlineField(
            controls.summary.start,
            startText,
            { 0.33, 0.8, 0.98 },
            self.activeTextField and self.activeTextField.kind == "train" and self.activeTextField.targetId == train.id and self.activeTextField.fieldName == "spawnTime"
        )
        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.printf(entry.castName, controls.summary.name.x, controls.summary.name.y + 1, controls.summary.name.w, "left")
        self:drawSequencerSummaryChip(controls.summary.lineChip, train.lineColor)
        self:drawSequencerSummaryChip(controls.summary.goalChip, train.trainColor)
        self:drawSequencerInlineField(
            controls.summary.wagons,
            wagonsText,
            { 0.48, 0.92, 0.62 },
            self.activeTextField and self.activeTextField.kind == "train" and self.activeTextField.targetId == train.id and self.activeTextField.fieldName == "wagonCount"
        )
        self:drawSequencerInlineField(
            controls.summary.deadline,
            deadlineText,
            { 0.99, 0.78, 0.32 },
            self.activeTextField and self.activeTextField.kind == "train" and self.activeTextField.targetId == train.id and self.activeTextField.fieldName == "deadline"
        )

        graphics.setLineWidth(1.1)
        graphics.setColor(0.99, 0.78, 0.32, 1)
        graphics.rectangle("line", controls.summary.remove.x, controls.summary.remove.y, controls.summary.remove.w, controls.summary.remove.h, 5, 5)
        graphics.printf("X", controls.summary.remove.x, controls.summary.remove.y + 1, controls.summary.remove.w, "center")
    end
    love.graphics.setScissor()

    if #layout.rows == 0 then
        love.graphics.setFont(game.fonts.small)
        graphics.setColor(0.84, 0.88, 0.92, 1)
        graphics.printf("No trains are authored yet. Add one to start sequencing this map.", layout.panelX, layout.listRect.y + 24, layout.panelWidth, "center")
    end

    if layout.scrollbar then
        graphics.setColor(0.1, 0.12, 0.16, 1)
        graphics.rectangle("fill", layout.scrollbar.track.x, layout.scrollbar.track.y, layout.scrollbar.track.w, layout.scrollbar.track.h, 4, 4)
        graphics.setColor(0.24, 0.32, 0.4, 1)
        graphics.rectangle("line", layout.scrollbar.track.x, layout.scrollbar.track.y, layout.scrollbar.track.w, layout.scrollbar.track.h, 4, 4)
        graphics.setColor(0.33, 0.8, 0.98, 1)
        graphics.rectangle("fill", layout.scrollbar.thumb.x, layout.scrollbar.thumb.y, layout.scrollbar.thumb.w, layout.scrollbar.thumb.h, 4, 4)
    end

    self:drawPanelButton(layout.backRect, "Back", { 0.99, 0.78, 0.32 })
end

function mapEditor:drawDefaultSidePanel(game)
    local graphics = love.graphics
    local drawerLayout = self:getEditorDrawerLayout()
    local validationLayout = self:getValidationListLayout(game.fonts.small)
    local panelX = validationLayout.panelX
    local panelWidth = validationLayout.panelWidth
    local validationEntries = self:getValidationEntries()

    love.graphics.setFont(game.fonts.small)
    uiControls.drawSegmentedToggle(
        drawerLayout.mapSizeRect,
        MAP_SIZE_PRESETS,
        self:getMapSizePreset().id,
        nil,
        game.fonts.small,
        {
            backgroundColor = { 0.08, 0.1, 0.14, 0.98 },
            activeFillColor = { 0.98, 0.88, 0.34, 0.96 },
            outlineColor = { 0.28, 0.4, 0.52, 1 },
            innerOutlineColor = { 0.46, 0.66, 0.82, 0.45 },
        }
    )
    self:drawPanelButton(
        drawerLayout.gridToggleRect,
        self.gridVisible and "Hide Grid (G)" or "Show Grid (G)",
        { 0.99, 0.78, 0.32 }
    )
    self:drawTextField(
        "Grid Step",
        drawerLayout.gridStepRect,
        self:getActiveTextFieldValue("map", "editor", "gridStep", tostring(self.gridStep)),
        { 0.33, 0.8, 0.98 },
        self.activeTextField and self.activeTextField.kind == "map" and self.activeTextField.fieldName == "gridStep"
    )

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.print("Map Issues", panelX, validationLayout.issuesTitleY)

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.99, 0.78, 0.32, 1)
    graphics.printf(validationLayout.resolveText, panelX, validationLayout.resolveTextY, panelWidth)

    graphics.setColor(0.1, 0.12, 0.16, 1)
    graphics.rectangle(
        "fill",
        validationLayout.listRect.x,
        validationLayout.listRect.y,
        validationLayout.listRect.w,
        validationLayout.listRect.h,
        12,
        12
    )
    graphics.setColor(0.24, 0.32, 0.4, 1)
    graphics.rectangle(
        "line",
        validationLayout.listRect.x,
        validationLayout.listRect.y,
        validationLayout.listRect.w,
        validationLayout.listRect.h,
        12,
        12
    )

    if #validationEntries == 0 then
        graphics.setColor(0.62, 0.67, 0.73, 1)
        graphics.printf(
            "No issues found. You're good to go and good to publish this map.",
            validationLayout.listRect.x + 12,
            validationLayout.listRect.y + 12,
            validationLayout.listRect.w - 24
        )
    else
        local visibleRows = self:getVisibleValidationRows(game.fonts.small, validationLayout)

        graphics.setScissor(
            validationLayout.listRect.x,
            validationLayout.listRect.y,
            validationLayout.listRect.w,
            validationLayout.listRect.h
        )
        love.graphics.setFont(game.fonts.small)
        for _, row in ipairs(visibleRows) do
            if row.index == self.hoveredValidationIndex then
                graphics.setColor(0.18, 0.22, 0.27, 0.95)
                graphics.rectangle("fill", row.rect.x - 6, row.rect.y - 4, row.rect.w + 8, row.rect.h + 8, 8, 8)
            end

            local bulletX = row.rect.x + row.indentOffset + 12
            local textX = bulletX + row.numberWidth
            graphics.setColor(0.99, 0.78, 0.32, 1)
            graphics.print(row.numberLabel .. " ", bulletX, row.rect.y)
            drawValidationMessage(
                game.fonts.small,
                row.message,
                textX,
                row.rect.y,
                math.max(20, row.textWidth - 12),
                { 0.84, 0.88, 0.92, 1 },
                getValidationColorDisplayMode(self)
            )
        end
        graphics.setLineWidth(1)
        graphics.setScissor()

        if validationLayout.scrollbar then
            graphics.setColor(0.1, 0.12, 0.16, 1)
            graphics.rectangle(
                "fill",
                validationLayout.scrollbar.track.x,
                validationLayout.scrollbar.track.y,
                validationLayout.scrollbar.track.w,
                validationLayout.scrollbar.track.h,
                4,
                4
            )
            graphics.setColor(0.24, 0.32, 0.4, 1)
            graphics.rectangle(
                "line",
                validationLayout.scrollbar.track.x,
                validationLayout.scrollbar.track.y,
                validationLayout.scrollbar.track.w,
                validationLayout.scrollbar.track.h,
                4,
                4
            )
            graphics.setColor(0.99, 0.78, 0.32, 1)
            graphics.rectangle(
                "fill",
                validationLayout.scrollbar.thumb.x,
                validationLayout.scrollbar.thumb.y,
                validationLayout.scrollbar.thumb.w,
                validationLayout.scrollbar.thumb.h,
                4,
                4
            )
        end
    end

    love.graphics.setFont(game.fonts.small)
    self:drawPanelButton(self:getPlayTestButtonRect(), "Play Map (P)", { 0.64, 0.86, 0.98 }, not self:canPlaySavedMap())
    self:drawPanelButton(self:getUploadMapButtonRect(), "Upload Map (U)", { 0.99, 0.78, 0.32 }, not self:canUploadSavedMap())
    self:drawPanelButton(self:getSaveButtonRect(), "Save Map (S)", { 0.48, 0.92, 0.62 })
    self:drawPanelButton(self:getOpenButtonRect(), "Open Map (O)", { 0.33, 0.8, 0.98 })
    self:drawPanelButton(self:getSequencerButtonRect(), "Train Sequencer (C)", { 0.48, 0.92, 0.62 })
    self:drawPanelButton(self:getResetButtonRect(), "Reset (R)", { 0.99, 0.78, 0.32 })
    self:drawHitboxToggle(game)
    self:drawPanelButton(self:getOpenUserMapsButtonRect(), "Open User Maps Folder", { 0.98, 0.82, 0.34 })
end

function mapEditor:draw(game)
    local graphics = love.graphics
    local cameraCenterX, cameraCenterY = self:getCameraViewportCenter()

    self:updateHoveredValidationEntry(game.fonts.small)

    graphics.setColor(0.05, 0.07, 0.09, 1)
    graphics.rectangle("fill", 0, 0, self.viewport.w, self.viewport.h)

    graphics.push()
    graphics.translate(cameraCenterX, cameraCenterY)
    graphics.scale(self.camera.zoom, self.camera.zoom)
    graphics.translate(-self.camera.x, -self.camera.y)

    graphics.setColor(0.07, 0.09, 0.12, 1)
    graphics.rectangle("fill", self.canvas.x, self.canvas.y, self.canvas.w, self.canvas.h, 18, 18)
    self:drawGrid()

    if self.previewWorld then
        trackSceneRenderer.drawScene(self.previewWorld, {
            drawTrains = false,
            drawCollision = false,
        })
    end

    graphics.setColor(0.25, 0.34, 0.42, 1)
    graphics.setLineWidth(2 / math.max(self.camera.zoom, 0.0001))
    graphics.rectangle("line", self.canvas.x, self.canvas.y, self.canvas.w, self.canvas.h, 18, 18)

    for _, intersection in ipairs(self.intersections) do
        self:drawIntersection(intersection)
    end

    for _, route in ipairs(self.routes) do
        self:drawRouteHandles(route, self.selectedRouteId)
    end

    self:drawHitboxOverlay(game)

    graphics.pop()

    graphics.setColor(0.09, 0.11, 0.15, 0.98)
    graphics.rectangle("fill", self.sidePanel.x, self.sidePanel.y, self.sidePanel.w, self.sidePanel.h, 18, 18)
    graphics.setColor(0.22, 0.28, 0.34, 1)
    graphics.rectangle("line", self.sidePanel.x, self.sidePanel.y, self.sidePanel.w, self.sidePanel.h, 18, 18)

    if self.sidePanelMode == "sequencer" then
        self:drawSequencer(game)
    else
        love.graphics.setFont(game.fonts.title)
        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.print("Map Editor", self.sidePanel.x + 18, self.sidePanel.y + 20)
        self:drawDefaultSidePanel(game)
    end

    self:drawColorPicker(game)
    self:drawRouteTypePicker(game)
    self:drawStatusToast(game)
    self:drawValidationMarkers()

    self:drawDialog(game)
end

end
