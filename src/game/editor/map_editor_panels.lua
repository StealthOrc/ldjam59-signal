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

function mapEditor:getSaveButtonRect()
    local fullWidth = self.sidePanel.w - PANEL_BUTTON_SIDE_MARGIN * 2
    local buttonWidth = (fullWidth - PANEL_BUTTON_GAP) * 0.5
    return {
        x = self.sidePanel.x + PANEL_BUTTON_SIDE_MARGIN,
        y = self.sidePanel.y + self.sidePanel.h - (PANEL_BUTTON_BOTTOM_MARGIN + PANEL_BUTTON_HEIGHT * 4 + PANEL_BUTTON_GAP * 3),
        w = buttonWidth,
        h = PANEL_BUTTON_HEIGHT,
    }
end

function mapEditor:getOpenButtonRect()
    local saveRect = self:getSaveButtonRect()
    return {
        x = saveRect.x + saveRect.w + PANEL_BUTTON_GAP,
        y = saveRect.y,
        w = saveRect.w,
        h = saveRect.h,
    }
end

function mapEditor:getPlayTestButtonRect()
    return {
        x = self.sidePanel.x + PANEL_BUTTON_SIDE_MARGIN,
        y = self.sidePanel.y + self.sidePanel.h - (PANEL_BUTTON_BOTTOM_MARGIN + PANEL_BUTTON_HEIGHT * 5 + PANEL_BUTTON_GAP * 4),
        w = (self.sidePanel.w - PANEL_BUTTON_SIDE_MARGIN * 2 - PANEL_BUTTON_GAP) * 0.5,
        h = PANEL_BUTTON_HEIGHT,
    }
end

function mapEditor:getUploadMapButtonRect()
    local playRect = self:getPlayTestButtonRect()
    return {
        x = playRect.x + playRect.w + PANEL_BUTTON_GAP,
        y = playRect.y,
        w = playRect.w,
        h = playRect.h,
    }
end

function mapEditor:getSequencerButtonRect()
    return {
        x = self.sidePanel.x + PANEL_BUTTON_SIDE_MARGIN,
        y = self.sidePanel.y + self.sidePanel.h - (PANEL_BUTTON_BOTTOM_MARGIN + PANEL_BUTTON_HEIGHT * 3 + PANEL_BUTTON_GAP * 2),
        w = self.sidePanel.w - PANEL_BUTTON_SIDE_MARGIN * 2,
        h = PANEL_BUTTON_HEIGHT,
    }
end

function mapEditor:getResetButtonRect()
    local fullWidth = self.sidePanel.w - PANEL_BUTTON_SIDE_MARGIN * 2
    local buttonWidth = (fullWidth - PANEL_BUTTON_GAP) * 0.5
    return {
        x = self.sidePanel.x + PANEL_BUTTON_SIDE_MARGIN,
        y = self.sidePanel.y + self.sidePanel.h - (PANEL_BUTTON_BOTTOM_MARGIN + PANEL_BUTTON_HEIGHT * 2 + PANEL_BUTTON_GAP),
        w = buttonWidth,
        h = PANEL_BUTTON_HEIGHT,
    }
end

function mapEditor:getHitboxToggleRect()
    local resetRect = self:getResetButtonRect()
    return {
        x = resetRect.x + resetRect.w + PANEL_BUTTON_GAP,
        y = resetRect.y,
        w = resetRect.w,
        h = resetRect.h,
    }
end

function mapEditor:getSequencerBackButtonRect()
    return self:getOpenUserMapsButtonRect()
end

function mapEditor:getOpenUserMapsButtonRect()
    return {
        x = self.sidePanel.x + PANEL_BUTTON_SIDE_MARGIN,
        y = self.sidePanel.y + self.sidePanel.h - (PANEL_BUTTON_BOTTOM_MARGIN + PANEL_BUTTON_HEIGHT),
        w = self.sidePanel.w - PANEL_BUTTON_SIDE_MARGIN * 2,
        h = PANEL_BUTTON_HEIGHT,
    }
end

function mapEditor:getSequencerAddButtonRect()
    return {
        x = self.sidePanel.x + 18,
        y = self.sidePanel.y + 126,
        w = self.sidePanel.w - 36,
        h = 34,
    }
end

function mapEditor:getSequencerLayout()
    local panelX = self.sidePanel.x + 18
    local panelWidth = self.sidePanel.w - 36
    local backRect = self:getSequencerBackButtonRect()
    local sortedEntries = self:getSortedTrainEntries()
    local listHeaderRect = {
        x = panelX,
        y = self.sidePanel.y + 170,
        w = panelWidth,
        h = 18,
    }
    local listRect = {
        x = panelX,
        y = self.sidePanel.y + 192,
        w = panelWidth,
        h = backRect.y - (self.sidePanel.y + 192) - 12,
    }
    local totalContentHeight = 0
    for _, entry in ipairs(sortedEntries) do
        totalContentHeight = totalContentHeight + self:getTrainRowHeight(entry.train) + 8
    end
    if totalContentHeight > 0 then
        totalContentHeight = totalContentHeight - 8
    end
    local maxScroll = math.max(0, totalContentHeight - listRect.h)
    self.sequencerScroll = clamp(self.sequencerScroll or 0, 0, maxScroll)

    local scrollbar = nil
    local contentWidth = panelWidth
    if maxScroll > 0 then
        local track = {
            x = panelX + panelWidth - 8,
            y = listRect.y,
            w = 8,
            h = listRect.h,
        }
        local thumbHeight = math.max(28, track.h * (listRect.h / math.max(totalContentHeight, listRect.h)))
        local thumbY = track.y + (track.h - thumbHeight) * ((self.sequencerScroll or 0) / maxScroll)
        scrollbar = {
            track = track,
            thumb = {
                x = track.x,
                y = thumbY,
                w = track.w,
                h = thumbHeight,
            },
            maxScroll = maxScroll,
        }
        contentWidth = panelWidth - 16
    end

    self:clampSequencerScroll()

    local rows = {}
    local currentY = listRect.y - (self.sequencerScroll or 0)
    for _, entry in ipairs(sortedEntries) do
        local rowHeight = self:getTrainRowHeight(entry.train)
        local rowRect = {
            x = panelX,
            y = currentY,
            w = contentWidth,
            h = rowHeight,
        }
        if rowRect.y + rowRect.h >= listRect.y and rowRect.y <= listRect.y + listRect.h then
            rows[#rows + 1] = {
                entry = entry,
                rect = rowRect,
            }
        end
        currentY = currentY + rowHeight + 8
    end

    return {
        panelX = panelX,
        panelWidth = panelWidth,
        sortedEntries = sortedEntries,
        mapDeadlineRect = {
            x = panelX,
            y = self.sidePanel.y + 74,
            w = panelWidth,
            h = 32,
        },
        addRect = self:getSequencerAddButtonRect(),
        listHeaderRect = listHeaderRect,
        listRect = listRect,
        totalContentHeight = totalContentHeight,
        maxScroll = maxScroll,
        scrollbar = scrollbar,
        rows = rows,
        backRect = backRect,
    }
end

function mapEditor:getEditorDrawerLayout()
    local panelX = self.sidePanel.x + 18
    local panelWidth = self.sidePanel.w - 36
    local rowGap = 12
    local halfWidth = (panelWidth - PANEL_BUTTON_GAP) * 0.5
    local controlsTop = self.sidePanel.y + 92
    local mapSizeRect = {
        x = panelX,
        y = controlsTop,
        w = panelWidth,
        h = 34,
    }
    local gridToggleRect = {
        x = panelX,
        y = mapSizeRect.y + mapSizeRect.h + rowGap,
        w = halfWidth,
        h = 32,
    }
    local snapToggleRect = {
        x = gridToggleRect.x + gridToggleRect.w + PANEL_BUTTON_GAP,
        y = gridToggleRect.y,
        w = halfWidth,
        h = gridToggleRect.h,
    }
    local gridStepRect = self:getTextFieldRect(panelX, gridToggleRect.y + gridToggleRect.h + rowGap + 6, panelWidth)
    local controlsBottomY = gridStepRect.y + gridStepRect.h

    return {
        mapSizeRect = mapSizeRect,
        gridToggleRect = gridToggleRect,
        snapToggleRect = snapToggleRect,
        gridStepRect = gridStepRect,
        controlsTop = controlsTop,
        controlsBottomY = controlsBottomY,
    }
end

function mapEditor:getMapSizePreset()
    for _, preset in ipairs(MAP_SIZE_PRESETS) do
        if preset.w == self.mapSize.w then
            return preset
        end
    end
    return MAP_SIZE_PRESETS[1]
end

function mapEditor:handleEditorDrawerClick(x, y)
    local layout = self:getEditorDrawerLayout()
    if pointInRect(x, y, layout.mapSizeRect) then
        for presetIndex, preset in ipairs(MAP_SIZE_PRESETS) do
            if pointInRect(x, y, uiControls.segmentRect(layout.mapSizeRect, presetIndex, #MAP_SIZE_PRESETS)) then
                self:commitTextField()
                self:resizeMapTo(preset.w)
                return true
            end
        end
    end

    if pointInRect(x, y, layout.gridToggleRect) then
        self.gridVisible = not self.gridVisible
        self:notifyPreferencesChanged()
        self:showStatus(self.gridVisible and "Grid shown." or "Grid hidden.")
        return true
    end

    if pointInRect(x, y, layout.snapToggleRect) then
        self.gridSnapEnabled = not self.gridSnapEnabled
        self:notifyPreferencesChanged()
        self:showStatus(self.gridSnapEnabled and "Grid snap enabled." or "Grid snap disabled.")
        return true
    end

    if pointInRect(x, y, layout.gridStepRect) then
        self:openTextField("map", "editor", "gridStep", tostring(self.gridStep), "int")
        return true
    end

    return false
end

function mapEditor:clampPoint(x, y, isStartPoint)
    local clampedX = clamp(x, self.canvas.x + 14, self.canvas.x + self.canvas.w - 14)
    local minY = self.canvas.y + 14
    local maxY = self.canvas.y + self.canvas.h - 14
    local clampedY = clamp(y, minY, maxY)

    return clampedX, clampedY
end

function mapEditor:closeColorPicker()
    self.colorPicker = nil
end

function mapEditor:closeRouteTypePicker()
    self.routeTypePicker = nil
end

function easeOutBack(t)
    local overshoot = 1.15
    local shifted = t - 1
    return 1 + (overshoot + 1) * shifted * shifted * shifted + overshoot * shifted * shifted
end

function mapEditor:restartJunctionPickerPopup(originX, originY)
    if not self.colorPicker or self.colorPicker.mode ~= "junction" then
        return
    end

    self.colorPicker.popupOriginX = originX or self.colorPicker.anchorX
    self.colorPicker.popupOriginY = originY or self.colorPicker.anchorY
    self.colorPicker.popupTimer = 0
end

function mapEditor:getJunctionPickerPopupScale()
    if not self.colorPicker or self.colorPicker.mode ~= "junction" then
        return 1
    end

    local timer = self.colorPicker.popupTimer
    if timer == nil then
        return 1
    end

    local progress = clamp(timer / JUNCTION_MENU_POP_DURATION, 0, 1)
    return math.max(0.06, easeOutBack(progress))
end

function mapEditor:getJunctionPickerPopupOrigin()
    if not self.colorPicker or self.colorPicker.mode ~= "junction" then
        return 0, 0
    end

    return self.colorPicker.popupOriginX or self.colorPicker.anchorX, self.colorPicker.popupOriginY or self.colorPicker.anchorY
end

function mapEditor:screenToJunctionPickerSpace(x, y)
    local scale = self:getJunctionPickerPopupScale()
    if scale == 1 then
        return x, y
    end

    local originX, originY = self:getJunctionPickerPopupOrigin()
    return originX + (x - originX) / scale, originY + (y - originY) / scale
end

function mapEditor:openColorPicker(route, magnetKind)
    if magnetKind ~= "end" then
        return
    end

    local point = magnetKind == "start" and route.points[1] or route.points[#route.points]
    local anchorX, anchorY = self:mapToScreen(point.x, point.y)
    self.colorPicker = {
        mode = "route_end",
        routeId = route.id,
        magnetKind = magnetKind,
        anchorX = anchorX,
        anchorY = anchorY,
        hoverBranch = nil,
        branch = "disconnect",
        hoverOptionIndex = nil,
    }
    self:closeRouteTypePicker()
end

function mapEditor:openRouteTypePicker(route, segmentIndex, anchorX, anchorY)
    self.routeTypePicker = {
        routeId = route.id,
        segmentIndex = segmentIndex,
        anchorX = anchorX,
        anchorY = anchorY,
    }
    self:closeColorPicker()
end

function mapEditor:openJunctionPicker(intersection, clickX, clickY)
    self:prepareIntersectionForDrag(intersection)

    local anchorX, anchorY = self:mapToScreen(intersection.x, intersection.y)
    local liveIntersection = self:getIntersectionById(intersection.id) or intersection
    self.colorPicker = {
        mode = "junction",
        intersectionId = liveIntersection.id,
        anchorX = anchorX,
        anchorY = anchorY,
        hoverBranch = nil,
        branch = nil,
        hoverOptionIndex = nil,
    }
    self:restartJunctionPickerPopup(clickX, clickY)
    self:closeRouteTypePicker()
end

function mapEditor:openSequencerColorPicker(trainId, fieldName, anchorX, anchorY)
    self.colorPicker = {
        mode = "sequencer",
        trainId = trainId,
        fieldName = fieldName,
        anchorX = anchorX,
        anchorY = anchorY,
    }
end

function mapEditor:getColorPickerOptions()
    if not self.colorPicker then
        return {}
    end

    if self.colorPicker.mode == "sequencer" then
        return COLOR_OPTIONS
    end

    local lookup = {}
    if self.colorPicker.mode == "route" or self.colorPicker.mode == "route_end" then
        local route = self:getRouteById(self.colorPicker.routeId)
        local endpoint = route and route.id == self.colorPicker.routeId
            and (self.colorPicker.magnetKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route))
            or nil
        lookup = endpoint and endpoint.colors or {}
    elseif self.colorPicker.mode == "junction" then
        local intersection = self:getIntersectionById(self.colorPicker.intersectionId)
        local group = intersection and self:getSharedPointGroupForIntersection(intersection) or nil
        lookup = group and group.colorLookup or {}
    end

    local options = {}
    for _, option in ipairs(COLOR_OPTIONS) do
        if lookup[option.id] then
            options[#options + 1] = option
        end
    end
    return options
end

function mapEditor:getColorPickerSelectionLookup()
    local lookup = {}
    if not self.colorPicker then
        return lookup
    end

    if self.colorPicker.mode == "route" or self.colorPicker.mode == "route_end" then
        local route = self:getRouteById(self.colorPicker.routeId)
        if not route or route.id ~= self.colorPicker.routeId then
            return lookup
        end
        local endpoint = self.colorPicker.magnetKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route)
        return endpoint and endpoint.colors or {}
    elseif self.colorPicker.mode == "junction" then
        local intersection = self:getIntersectionById(self.colorPicker.intersectionId)
        local group = intersection and self:getSharedPointGroupForIntersection(intersection) or nil
        return group and group.colorLookup or lookup
    elseif self.colorPicker.mode == "sequencer" then
        local train = self:getTrainById(self.colorPicker.trainId)
        if not train then
            return lookup
        end
        lookup[train[self.colorPicker.fieldName]] = true
        return lookup
    end

    return lookup
end

function mapEditor:getJunctionPickerRootHover(x, y)
    if not self.colorPicker or (self.colorPicker.mode ~= "junction" and self.colorPicker.mode ~= "route_end") then
        return nil
    end

    local dx = x - self.colorPicker.anchorX
    local dy = y - self.colorPicker.anchorY
    if math.abs(dx) < math.abs(dy) * JUNCTION_MENU_BRANCH_RATIO then
        return nil
    end

    if dx < 0 then
        return "disconnect"
    end
    if dx > 0 and self.colorPicker.mode == "junction" then
        return "junctions"
    end
    return nil
end

function mapEditor:buildJunctionPickerEntries(branch, centerX, centerY, innerRadius, outerRadius)
    local entries = {}
    local options = {}

    if branch == "disconnect" then
        options = self:getColorPickerOptions()
    elseif branch == "junctions" then
        for _, controlType in ipairs(CONTROL_ORDER) do
            options[#options + 1] = {
                id = controlType,
                controlType = controlType,
            }
        end
    end

    if #options == 0 then
        return entries
    end

    local step = (math.pi * 2) / #options
    local startAngle = -math.pi * 0.5 - step * 0.5
    local iconRadius = (innerRadius + outerRadius) * 0.5

    for optionIndex, option in ipairs(options) do
        local segmentStart = startAngle + (optionIndex - 1) * step
        local segmentMiddle = segmentStart + step * 0.5
        entries[#entries + 1] = {
            option = option,
            index = optionIndex,
            startAngle = segmentStart,
            endAngle = segmentStart + step,
            centerX = centerX + math.cos(segmentMiddle) * iconRadius,
            centerY = centerY + math.sin(segmentMiddle) * iconRadius,
        }
    end

    return entries
end

function mapEditor:getJunctionPickerLayout()
    if not self.colorPicker or (self.colorPicker.mode ~= "junction" and self.colorPicker.mode ~= "route_end") then
        return nil
    end

    local branch = self.colorPicker.branch
    local rootCenterX = self.colorPicker.anchorX
    local rootCenterY = self.colorPicker.anchorY
    local submenu = nil

    if branch then
        local outerRadius = branch == "junctions" and JUNCTION_MENU_TYPE_OUTER_RADIUS or JUNCTION_MENU_COLOR_OUTER_RADIUS
        local submenuCenterX = clamp(
            rootCenterX,
            self.canvas.x + outerRadius + JUNCTION_MENU_EDGE_MARGIN,
            self.viewport.w - outerRadius - JUNCTION_MENU_EDGE_MARGIN
        )
        local submenuCenterY = clamp(
            rootCenterY,
            self.canvas.y + outerRadius + JUNCTION_MENU_EDGE_MARGIN,
            self.viewport.h - outerRadius - JUNCTION_MENU_EDGE_MARGIN
        )
        submenu = {
            branch = branch,
            x = submenuCenterX,
            y = submenuCenterY,
            radius = outerRadius,
            innerRadius = JUNCTION_MENU_RING_INNER_RADIUS,
            outerRadius = outerRadius,
            entries = self:buildJunctionPickerEntries(
                branch,
                submenuCenterX,
                submenuCenterY,
                JUNCTION_MENU_RING_INNER_RADIUS,
                outerRadius
            ),
        }
    end

    return {
        kind = "junction_radial",
        root = {
            x = rootCenterX,
            y = rootCenterY,
            radius = JUNCTION_MENU_ROOT_RADIUS,
        },
        branch = branch,
        hoverBranch = self.colorPicker.hoverBranch,
        submenu = submenu,
    }
end

function mapEditor:getJunctionPickerOptionHit(submenu, x, y)
    if not submenu then
        return nil
    end
    if #submenu.entries == 0 then
        return nil
    end

    local distance = math.sqrt(distanceSquared(x, y, submenu.x, submenu.y))
    if distance > submenu.outerRadius then
        return nil
    end

    local fullTurn = math.pi * 2
    local step = fullTurn / #submenu.entries
    -- The top wedge is centered on the zero-angle seam, so shift by half a step
    -- before quantizing to keep hover and click boundaries aligned with the arcs.
    local baseAngle = normalizeAngle(angleBetweenCoordinates(submenu.x, submenu.y, x, y) + math.pi * 0.5 + step * 0.5)
    local entryIndex = math.floor(baseAngle / step) + 1
    return submenu.entries[entryIndex]
end

function mapEditor:updateJunctionPickerHover(x, y)
    if not self.colorPicker or (self.colorPicker.mode ~= "junction" and self.colorPicker.mode ~= "route_end") then
        return false
    end

    x, y = self:screenToJunctionPickerSpace(x, y)

    local rootDistance = math.sqrt(distanceSquared(x, y, self.colorPicker.anchorX, self.colorPicker.anchorY))
    local hoverBranch = rootDistance <= JUNCTION_MENU_ROOT_RADIUS and self:getJunctionPickerRootHover(x, y) or nil

    self.colorPicker.hoverBranch = hoverBranch
    self.colorPicker.hoverOptionIndex = nil

    local layout = self:getJunctionPickerLayout()
    if layout and layout.submenu then
        local hitEntry = self:getJunctionPickerOptionHit(layout.submenu, x, y)
        self.colorPicker.hoverOptionIndex = hitEntry and hitEntry.index or nil
    end

    return true
end

function mapEditor:getColorPickerLayout()
    if not self.colorPicker then
        return nil
    end

    local options = self:getColorPickerOptions()
    if self.colorPicker.mode ~= "junction" and self.colorPicker.mode ~= "route_end" and #options == 0 then
        return nil
    end

    if self.colorPicker.mode == "junction" or self.colorPicker.mode == "route_end" then
        return self:getJunctionPickerLayout()
    end

    local columns = math.min(3, math.max(1, #options))
    local swatchSize = 34
    local gap = 10
    local rows = math.ceil(#options / columns)
    local rect = {
        w = 32 + columns * swatchSize + math.max(0, columns - 1) * gap,
        h = 32 + rows * swatchSize + math.max(0, rows - 1) * gap,
    }
    rect.x = clamp(
        self.colorPicker.anchorX + 18,
        self.canvas.x + 8,
        self.viewport.w - rect.w - 8
    )
    rect.y = clamp(
        self.colorPicker.anchorY - rect.h * 0.5,
        self.canvas.y + 8,
        self.viewport.h - rect.h - 8
    )

    local swatches = {}
    local startX = rect.x + 16
    local startY = rect.y + 16

    for index, option in ipairs(options) do
        local column = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        swatches[#swatches + 1] = {
            option = option,
            rect = {
                x = startX + column * (swatchSize + gap),
                y = startY + row * (swatchSize + gap),
                w = swatchSize,
                h = swatchSize,
            },
        }
    end

    return {
        rect = rect,
        swatches = swatches,
    }
end

function mapEditor:getRouteTypePickerLayout()
    if not self.routeTypePicker then
        return nil
    end

    local optionCount = #ROAD_TYPE_OPTIONS
    local optionHeight = 42
    local optionGap = 10
    local rect = {
        w = 236,
        h = 66 + optionCount * optionHeight + math.max(0, optionCount - 1) * optionGap,
    }
    rect.x = clamp(
        self.routeTypePicker.anchorX + 18,
        self.canvas.x + 8,
        self.viewport.w - rect.w - 8
    )
    rect.y = clamp(
        self.routeTypePicker.anchorY - rect.h * 0.5,
        self.canvas.y + 8,
        self.viewport.h - rect.h - 8
    )

    local optionRects = {}
    local currentY = rect.y + 46

    for _, option in ipairs(ROAD_TYPE_OPTIONS) do
        optionRects[#optionRects + 1] = {
            option = option,
            rect = {
                x = rect.x + 14,
                y = currentY,
                w = rect.w - 28,
                h = optionHeight,
            },
        }
        currentY = currentY + optionHeight + optionGap
    end

    return {
        rect = rect,
        options = optionRects,
    }
end

function mapEditor:closeDialog()
    self.dialog = nil
end

function mapEditor:openSaveDialog()
    local defaultName = self.currentMapName or ""
    if self.sourceInfo and self.sourceInfo.source == "builtin" and defaultName ~= "" and not defaultName:match(" Copy$") then
        defaultName = defaultName .. " Copy"
    end
    self.dialog = {
        type = "save",
        input = defaultName,
    }
end

function mapEditor:openOpenDialog()
    self.dialog = {
        type = "open",
        maps = mapStorage.listMaps(),
        scroll = 0,
    }
end

function mapEditor:openResetDialog()
    self.dialog = {
        type = "confirm_reset",
    }
end

function mapEditor:getDialogRect()
    return {
        x = self.viewport.w * 0.5 - 260,
        y = self.viewport.h * 0.5 - 180,
        w = 520,
        h = 360,
    }
end

function mapEditor:getConfirmResetDialogButtons()
    local rect = self:getDialogRect()
    local buttonWidth = 180
    local buttonHeight = 42
    local gap = 18
    local totalWidth = buttonWidth * 2 + gap
    local startX = rect.x + (rect.w - totalWidth) * 0.5
    local y = rect.y + rect.h - 84

    return {
        confirm = {
            x = startX,
            y = y,
            w = buttonWidth,
            h = buttonHeight,
        },
        cancel = {
            x = startX + buttonWidth + gap,
            y = y,
            w = buttonWidth,
            h = buttonHeight,
        },
    }
end

function mapEditor:getOpenDialogListLayout()
    local rect = self:getDialogRect()
    local maps = (self.dialog and self.dialog.maps) or {}
    local listRect = {
        x = rect.x + 24,
        y = rect.y + 78,
        w = rect.w - 48,
        h = rect.h - 142,
    }
    local rowStride = 54
    local rowHeight = 44
    local visibleRows = math.max(1, math.floor(listRect.h / rowStride))
    local maxScroll = math.max(0, #maps - visibleRows)
    local scroll = clamp((self.dialog and self.dialog.scroll) or 0, 0, maxScroll)

    if self.dialog then
        self.dialog.scroll = scroll
    end

    local contentWidth = listRect.w
    local scrollbar = nil
    if maxScroll > 0 then
        local track = {
            x = listRect.x + listRect.w - 8,
            y = listRect.y,
            w = 8,
            h = listRect.h,
        }
        local thumbHeight = math.max(26, track.h * (visibleRows / #maps))
        local thumbY = track.y + ((track.h - thumbHeight) * (scroll / maxScroll))
        scrollbar = {
            track = track,
            thumb = {
                x = track.x,
                y = thumbY,
                w = track.w,
                h = thumbHeight,
            },
            maxScroll = maxScroll,
        }
        contentWidth = listRect.w - 14
    end

    local rows = {}
    for slot = 1, visibleRows do
        local mapIndex = scroll + slot
        local savedMap = maps[mapIndex]
        if not savedMap then
            break
        end

        rows[#rows + 1] = {
            index = mapIndex,
            map = savedMap,
            rect = {
                x = listRect.x,
                y = listRect.y + (slot - 1) * rowStride,
                w = contentWidth,
                h = rowHeight,
            },
        }
    end

    return {
        listRect = listRect,
        rows = rows,
        totalMaps = #maps,
        visibleRows = visibleRows,
        maxScroll = maxScroll,
        firstVisibleIndex = (#rows > 0) and rows[1].index or 0,
        lastVisibleIndex = (#rows > 0) and rows[#rows].index or 0,
        scrollbar = scrollbar,
    }
end

function mapEditor:scrollOpenDialog(delta)
    if not self.dialog or self.dialog.type ~= "open" then
        return false
    end

    local layout = self:getOpenDialogListLayout()
    if layout.maxScroll <= 0 then
        return false
    end

    self.dialog.scroll = clamp((self.dialog.scroll or 0) + delta, 0, layout.maxScroll)
    return true
end

function mapEditor:scrollValidationList(delta)
    local layout = self:getValidationListLayout()
    if layout.maxScroll <= 0 then
        return false
    end

    self.validationScroll = clamp((self.validationScroll or 0) + delta, 0, layout.maxScroll)
    return true
end

function mapEditor:updateHoveredValidationEntry(font)
    self.hoveredValidationIndex = nil

    if self.sidePanelMode ~= "default" then
        return
    end

    if not (love and love.mouse and love.mouse.getPosition) then
        return
    end

    local mouseX, mouseY = love.mouse.getPosition()
    local layout = self:getValidationListLayout(font)
    if not pointInRect(mouseX, mouseY, layout.listRect) then
        return
    end

    for _, row in ipairs(self:getVisibleValidationRows(font, layout)) do
        if pointInRect(mouseX, mouseY, row.rect) then
            self.hoveredValidationIndex = row.index
            return
        end
    end
end

function mapEditor:handleValidationListClick(x, y)
    if self.sidePanelMode ~= "default" or #self:getValidationEntries() == 0 then
        return false
    end

    local layout = self:getValidationListLayout()
    if layout.scrollbar and pointInRect(x, y, layout.scrollbar.thumb) then
        self.validationScrollDrag = {
            offsetY = y - layout.scrollbar.thumb.y,
            track = layout.scrollbar.track,
            thumbHeight = layout.scrollbar.thumb.h,
            maxScroll = layout.scrollbar.maxScroll,
        }
        return true
    end

    if layout.scrollbar and pointInRect(x, y, layout.scrollbar.track) then
        local thumbTravel = math.max(1, layout.scrollbar.track.h - layout.scrollbar.thumb.h)
        local targetY = clamp(y - layout.scrollbar.thumb.h * 0.5, layout.scrollbar.track.y, layout.scrollbar.track.y + thumbTravel)
        self.validationScroll = ((targetY - layout.scrollbar.track.y) / thumbTravel) * layout.scrollbar.maxScroll
        return true
    end

    return pointInRect(x, y, layout.listRect)
end

function mapEditor:openDialogMap(savedMap)
    local loadedMap, loadError = mapStorage.loadMap(savedMap)
    if not loadedMap or not loadedMap.editor then
        self:showStatus(loadError or "That map could not be opened.")
        return false
    end

    self:resetFromMap(loadedMap, savedMap)
    return true
end

function mapEditor:openUserMapsFolder()
    local saveDirectory = mapStorage.getSaveDirectory()
    if not (love and love.system and love.system.openURL) then
        self:showStatus("Opening the user maps folder is not supported here.")
        return false
    end

    local ok, result = pcall(love.system.openURL, buildFileUrl(saveDirectory))
    if not ok or result == false then
        self:showStatus("The user maps folder could not be opened.")
        return false
    end

    self:showStatus("Opened the user maps folder.")
    return true
end

end
