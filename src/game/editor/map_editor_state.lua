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

function mapEditor.new(viewportW, viewportH, level, options)
    local self = setmetatable({}, mapEditor)
    local editorOptions = options or {}
    local editorPreferences = editorOptions.editorPreferences or {}

    self.viewport = { w = viewportW, h = viewportH }
    self.mapSize = sanitizeMapSize(nil, DEFAULT_NEW_MAP_WIDTH, DEFAULT_NEW_MAP_HEIGHT)
    self.endpoints = {}
    self.routes = {}
    self.nextEndpointId = 1
    self.nextRouteId = 1
    self.nextSharedPointId = 1
    self.selectedRouteId = nil
    self.selectedPointIndex = nil
    self.drag = nil
    self.colorPicker = nil
    self.routeTypePicker = nil
    self.dialog = nil
    self.currentMapName = nil
    self.editingMapUuid = nil
    self.sourceInfo = nil
    self.lastSavedDescriptor = nil
    self.pendingPlaytestDescriptor = nil
    self.pendingUploadDescriptor = nil
    self.pendingOpenBlankMap = false
    self.loadedMapPayload = nil
    self.savedStateSnapshotJson = nil
    self.savedMapUploadAvailable = false
    self.savedMapUploadPending = false
    self.lastValidationError = nil
    self.validationErrors = {}
    self.previewWorld = nil
    self.validationEntries = {}
    self.hoveredValidationIndex = nil
    self.statusText = nil
    self.statusTimer = 0
    self.intersections = {}
    self.importedJunctionState = {}
    self.trains = {}
    self.nextTrainId = 1
    self.timeLimit = nil
    self.sidePanelMode = "default"
    self.sequencerScroll = 0
    self.activeTextField = nil
    self.sequencerScrollDrag = nil
    self.camera = {
        x = self.mapSize.w * 0.5,
        y = self.mapSize.h * 0.5,
        zoom = 1,
    }
    self.panDrag = nil
    self.onPreferencesChanged = editorOptions.onPreferencesChanged
    self.gridVisible = editorPreferences.gridVisible ~= false
    self.gridStep = sanitizeGridStep(editorPreferences.gridStep)
    self.gridSnapEnabled = editorPreferences.gridSnapEnabled == true
    self.editorChargeImage = nil
    self.editorCrossImage = nil
    self.editorDirectImage = nil
    self.editorRelayImage = nil
    self.editorSpringImage = nil
    self.editorTripImage = nil
    self.editorJunctionIconsLoaded = false
    self.validationScroll = 0
    self.validationScrollDrag = nil
    self.validationColorDisplayMode = "swatch"
    self.hitboxOverlayVisible = false

    self:updateLayout()
    self:resetCameraToFit()
    self:resetFromMap(level and { level = level, name = level.title } or nil, nil)

    return self
end

function mapEditor:updateLayout()
    self.margin = PANEL_OVERLAY_MARGIN
    self.panelWidth = 320
    self.canvas = {
        x = 0,
        y = 0,
        w = self.mapSize.w,
        h = self.mapSize.h,
    }
    self.spawnBandHeight = 58
    self.spawnY = self.canvas.y + 22
    self.sidePanel = {
        x = self.viewport.w - self.panelWidth - self.margin,
        y = self.margin,
        w = self.panelWidth,
        h = self.viewport.h - self.margin * 2,
    }
end

function mapEditor:ensureEditorJunctionIcons()
    if self.editorJunctionIconsLoaded then
        return
    end

    self.editorJunctionIconsLoaded = true
    self.editorChargeImage = loadOptionalImage("assets/Charge.png")
    self.editorCrossImage = loadOptionalImage("assets/cross.png")
    self.editorDirectImage = loadOptionalImage("assets/direct.png")
    self.editorRelayImage = loadOptionalImage("assets/relay.png")
    self.editorSpringImage = loadOptionalImage("assets/spring.png")
    self.editorTripImage = loadOptionalImage("assets/trip.png")
end

function mapEditor:clearSelection()
    self.selectedRouteId = nil
    self.selectedPointIndex = nil
end

function mapEditor:notifyPreferencesChanged()
    if self.onPreferencesChanged then
        self.onPreferencesChanged({
            gridVisible = self.gridVisible ~= false,
            gridStep = sanitizeGridStep(self.gridStep),
            gridSnapEnabled = self.gridSnapEnabled == true,
        })
    end
end

function mapEditor:getCameraViewportRect()
    local width = self.sidePanel and (self.sidePanel.x - self.margin) or self.viewport.w
    return {
        x = 0,
        y = 0,
        w = math.max(1, width),
        h = self.viewport.h,
    }
end

function mapEditor:getCameraViewportCenter()
    local rect = self:getCameraViewportRect()
    return rect.x + rect.w * 0.5, rect.y + rect.h * 0.5
end

function mapEditor:getCameraViewHalfExtents(zoom)
    local resolvedZoom = zoom or self.camera.zoom or 1
    local rect = self:getCameraViewportRect()
    return rect.w * 0.5 / resolvedZoom, rect.h * 0.5 / resolvedZoom
end

function mapEditor:clampCamera()
    local halfW, halfH = self:getCameraViewHalfExtents()
    local minX = halfW
    local maxX = self.mapSize.w - halfW
    local minY = halfH
    local maxY = self.mapSize.h - halfH
    self.camera.x = clampRectValue(self.camera.x, minX, maxX)
    self.camera.y = clampRectValue(self.camera.y, minY, maxY)
end

function mapEditor:resetCameraToFit()
    local cameraViewport = self:getCameraViewportRect()
    local fitZoom = math.min(
        (cameraViewport.w - CAMERA_PADDING * 2) / math.max(1, self.mapSize.w),
        (cameraViewport.h - CAMERA_PADDING * 2) / math.max(1, self.mapSize.h)
    )

    self.camera.zoom = clamp(fitZoom, CAMERA_MIN_ZOOM, CAMERA_MAX_ZOOM)
    self.camera.x = self.mapSize.w * 0.5
    self.camera.y = self.mapSize.h * 0.5
    self:clampCamera()
end

function mapEditor:screenToMap(screenX, screenY)
    local centerX, centerY = self:getCameraViewportCenter()
    return (screenX - centerX) / self.camera.zoom + self.camera.x,
        (screenY - centerY) / self.camera.zoom + self.camera.y
end

function mapEditor:mapToScreen(mapX, mapY)
    local centerX, centerY = self:getCameraViewportCenter()
    return (mapX - self.camera.x) * self.camera.zoom + centerX,
        (mapY - self.camera.y) * self.camera.zoom + centerY
end

function mapEditor:isEndpointRebuildModifierActive()
    return love.keyboard.isDown("lctrl", "rctrl")
end

function mapEditor:isGridSnapEnabled()
    return self.gridSnapEnabled == true
end

function mapEditor:snapPointToGrid(x, y)
    local step = sanitizeGridStep(self.gridStep)
    return math.floor((x / step) + 0.5) * step,
        math.floor((y / step) + 0.5) * step
end

function mapEditor:zoomAroundScreenPoint(screenX, screenY, deltaY)
    if deltaY == 0 then
        return
    end

    local anchorMapX, anchorMapY = self:screenToMap(screenX, screenY)
    local zoomFactor = deltaY > 0 and 1.12 or (1 / 1.12)
    self.camera.zoom = clamp(self.camera.zoom * zoomFactor, CAMERA_MIN_ZOOM, CAMERA_MAX_ZOOM)
    local centerX, centerY = self:getCameraViewportCenter()

    self.camera.x = anchorMapX - ((screenX - centerX) / self.camera.zoom)
    self.camera.y = anchorMapY - ((screenY - centerY) / self.camera.zoom)
    self:clampCamera()
end

function mapEditor:generateTrainId()
    local trainId = "train_" .. self.nextTrainId
    self.nextTrainId = self.nextTrainId + 1
    return trainId
end

function mapEditor:createTrainDefinition(definition)
    local trainId = definition and definition.id or self:generateTrainId()
    local train = {
        id = trainId,
        lineColor = (definition and definition.lineColor) or COLOR_OPTIONS[1].id,
        trainColor = (definition and definition.trainColor) or ((definition and definition.lineColor) or COLOR_OPTIONS[1].id),
        spawnTime = math.max(0, roundStep((definition and definition.spawnTime) or 0, 0.5)),
        wagonCount = math.max(1, math.floor((definition and definition.wagonCount) or DEFAULT_TRAIN_WAGONS)),
        deadline = definition and definition.deadline or nil,
        collapsed = definition and definition.collapsed == true or false,
    }

    if definition and definition.deadline ~= nil then
        train.deadline = math.max(0, roundStep(definition.deadline, 0.5))
    end

    return train
end

function mapEditor:getSortedTrainEntries()
    local entries = {}

    for trainIndex, train in ipairs(self.trains) do
        entries[#entries + 1] = {
            train = train,
            trainIndex = trainIndex,
        }
    end

    table.sort(entries, function(a, b)
        if math.abs((a.train.spawnTime or 0) - (b.train.spawnTime or 0)) > 0.0001 then
            return (a.train.spawnTime or 0) < (b.train.spawnTime or 0)
        end
        local firstColorIndex = getColorOrderIndex(a.train.trainColor)
        local secondColorIndex = getColorOrderIndex(b.train.trainColor)
        if firstColorIndex ~= secondColorIndex then
            return firstColorIndex < secondColorIndex
        end
        return tostring(a.train.id) < tostring(b.train.id)
    end)

    for entryIndex, entry in ipairs(entries) do
        entry.castName = SAO_CAST[((entryIndex - 1) % #SAO_CAST) + 1]
    end

    return entries
end

function mapEditor:getAvailableLineColorIds()
    local lookup = {}
    local colors = {}

    for _, endpoint in ipairs(self.endpoints) do
        if endpoint.kind == "input" then
            for _, colorId in ipairs(getEndpointColorIds(endpoint)) do
                if not lookup[colorId] then
                    lookup[colorId] = true
                    colors[#colors + 1] = colorId
                end
            end
        end
    end

    for _, train in ipairs(self.trains) do
        if train.lineColor and not lookup[train.lineColor] then
            lookup[train.lineColor] = true
            colors[#colors + 1] = train.lineColor
        end
    end

    table.sort(colors, function(a, b)
        return getColorOrderIndex(a) < getColorOrderIndex(b)
    end)

    if #colors == 0 then
        colors[1] = COLOR_OPTIONS[1].id
    end

    return colors
end

function mapEditor:cycleColorValue(currentColor, availableColors, direction)
    local options = availableColors or {}
    if #options == 0 then
        return currentColor
    end

    local currentIndex = 1
    for colorIndex, colorId in ipairs(options) do
        if colorId == currentColor then
            currentIndex = colorIndex
            break
        end
    end

    local nextIndex = currentIndex + direction
    if nextIndex < 1 then
        nextIndex = #options
    elseif nextIndex > #options then
        nextIndex = 1
    end
    return options[nextIndex]
end

function mapEditor:clampSequencerScroll()
    local entries = self:getSortedTrainEntries()
    local backRect = self:getSequencerBackButtonRect()
    local listHeight = backRect.y - (self.sidePanel.y + 192) - 12
    local totalHeight = 0
    for _, entry in ipairs(entries) do
        totalHeight = totalHeight + self:getTrainRowHeight(entry.train) + 8
    end
    if totalHeight > 0 then
        totalHeight = totalHeight - 8
    end
    self.sequencerScroll = clamp(self.sequencerScroll or 0, 0, math.max(0, totalHeight - listHeight))
end

function mapEditor:getValidationEntries()
    if self.validationEntries and #self.validationEntries > 0 then
        return self.validationEntries
    end

    local fallbackEntries = {}
    for _, message in ipairs(self.validationErrors or {}) do
        if message ~= EMPTY_MAP_VALIDATION_TEXT then
            fallbackEntries[#fallbackEntries + 1] = { message = message }
        end
    end
    return fallbackEntries
end

function mapEditor:getTrainValidationLookup()
    local lookup = {}

    for _, entry in ipairs(self:getSortedTrainEntries()) do
        lookup[tostring(entry.train.id)] = {
            castName = entry.castName,
            lineColor = entry.train.lineColor,
            trainColor = entry.train.trainColor,
        }
    end

    return lookup
end

function mapEditor:buildValidationEntry(message, diagnostic, trainLookup)
    local entry = {
        message = message,
        diagnostic = diagnostic,
        indentLevel = diagnostic and diagnostic.parentDiagnosticIndex and 1 or 0,
        parentEntryIndex = diagnostic and diagnostic.parentDiagnosticIndex or nil,
    }

    if diagnostic and diagnostic.kind and diagnostic.kind:match("^train_") then
        local trainInfo = trainLookup and trainLookup[tostring(diagnostic.trainId)] or nil
        entry.message = tostring(message or ""):gsub(
            "^Train%s+%d+",
            buildTrainValidationLabel(trainInfo, diagnostic),
            1
        )
    end

    return entry
end

function mapEditor:groupValidationEntriesByHierarchy()
    local orderedEntries = {}
    local childrenByParent = {}
    local entryBySourceIndex = {}
    local visited = {}

    for _, entry in ipairs(self.validationEntries or {}) do
        entryBySourceIndex[entry.sourceIndex] = entry
        if entry.parentEntryIndex then
            childrenByParent[entry.parentEntryIndex] = childrenByParent[entry.parentEntryIndex] or {}
            childrenByParent[entry.parentEntryIndex][#childrenByParent[entry.parentEntryIndex] + 1] = entry
        end
    end

    local function appendEntry(entry)
        if not entry or visited[entry] then
            return
        end

        visited[entry] = true
        orderedEntries[#orderedEntries + 1] = entry

        for _, child in ipairs(childrenByParent[entry.sourceIndex] or {}) do
            appendEntry(child)
        end
    end

    for _, entry in ipairs(self.validationEntries or {}) do
        if not entry.parentEntryIndex or not entryBySourceIndex[entry.parentEntryIndex] then
            appendEntry(entry)
        end
    end

    for _, entry in ipairs(self.validationEntries or {}) do
        appendEntry(entry)
    end

    local orderedIndexBySourceIndex = {}
    for orderedIndex, entry in ipairs(orderedEntries) do
        orderedIndexBySourceIndex[entry.sourceIndex] = orderedIndex
    end

    for _, entry in ipairs(orderedEntries) do
        if entry.parentEntryIndex then
            entry.parentEntryIndex = orderedIndexBySourceIndex[entry.parentEntryIndex]
        end
    end

    self.validationEntries = orderedEntries
end

function mapEditor:refreshValidationEntryNumbering()
    local topLevelCount = 0
    local childCounts = {}

    for index, entry in ipairs(self.validationEntries or {}) do
        local parentIndex = entry.parentEntryIndex
        local parentEntry = parentIndex and self.validationEntries[parentIndex] or nil

        if parentEntry then
            childCounts[parentIndex] = (childCounts[parentIndex] or 0) + 1
            entry.displayNumber = string.format("%s.%d", parentEntry.displayNumber or tostring(parentIndex), childCounts[parentIndex])
            entry.numberLabel = entry.displayNumber
            entry.indentLevel = 1
        else
            topLevelCount = topLevelCount + 1
            entry.displayNumber = tostring(topLevelCount)
            entry.numberLabel = entry.displayNumber .. "."
            entry.indentLevel = 0
        end

        self.validationEntries[index] = entry
    end
end

function mapEditor:getValidationListLayout(font)
    font = font or love.graphics.getFont()

    local drawerLayout = self:getEditorDrawerLayout()
    local panelX = self.sidePanel.x + 18
    local panelWidth = self.sidePanel.w - 36
    local panelBottom = self:getPlayTestButtonRect().y - 16
    local issuesTitleY = drawerLayout.controlsBottomY + 22
    local resolveText = "Resolve these before the run can start:"
    local resolveTextHeight = getWrappedLineCount(font, resolveText, panelWidth) * font:getHeight()
    local listTop = issuesTitleY + 26 + resolveTextHeight + 10
    local listBottom = panelBottom - 12

    local listHeight = math.max(72, listBottom - listTop)
    local listRect = {
        x = panelX,
        y = listTop,
        w = panelWidth,
        h = listHeight,
    }

    local entries = self:getValidationEntries()
    local displayMode = getValidationColorDisplayMode(self)
    local totalContentHeight = 0
    for index, entry in ipairs(entries) do
        local item = getValidationEntryMessage(entry)
        local indentOffset = math.max(0, (entry.indentLevel or 0) * VALIDATION_CHILD_INDENT)
        local numberWidth = font:getWidth((entry.numberLabel or (tostring(index) .. ".")) .. " ")
        local lineHeight = font:getHeight()
        local itemHeight = measureValidationMessage(font, item, listRect.w - numberWidth - indentOffset, displayMode)
        totalContentHeight = totalContentHeight + itemHeight
        if index < #entries then
            totalContentHeight = totalContentHeight + 10
        end
    end

    local maxScroll = math.max(0, totalContentHeight - listRect.h)
    self.validationScroll = clamp(self.validationScroll or 0, 0, maxScroll)

    local scrollbar = nil
    local contentWidth = listRect.w
    if maxScroll > 0 then
        local track = {
            x = panelX + panelWidth - 8,
            y = listRect.y,
            w = 8,
            h = listRect.h,
        }
        local thumbHeight = math.max(28, track.h * (listRect.h / math.max(totalContentHeight, listRect.h)))
        local thumbY = track.y + (track.h - thumbHeight) * ((self.validationScroll or 0) / maxScroll)
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

    return {
        panelX = panelX,
        panelWidth = panelWidth,
        panelBottom = panelBottom,
        issuesTitleY = issuesTitleY,
        resolveText = resolveText,
        resolveTextY = issuesTitleY + 26,
        resolveTextHeight = resolveTextHeight,
        listRect = listRect,
        totalContentHeight = totalContentHeight,
        maxScroll = maxScroll,
        scrollbar = scrollbar,
        contentWidth = contentWidth,
    }
end

function mapEditor:getVisibleValidationRows(font, layout)
    local entries = self:getValidationEntries()
    local displayMode = getValidationColorDisplayMode(self)
    local rows = {}
    local currentY = layout.listRect.y - (self.validationScroll or 0)

    for index, entry in ipairs(entries) do
        local message = getValidationEntryMessage(entry)
        local indentOffset = math.max(0, (entry.indentLevel or 0) * VALIDATION_CHILD_INDENT)
        local lineHeight = font:getHeight()
        local numberLabel = entry.numberLabel or (tostring(index) .. ".")
        local numberWidth = font:getWidth(numberLabel .. " ")
        local textWidth = math.max(20, (layout.contentWidth or layout.listRect.w) - numberWidth - indentOffset)
        local itemHeight = measureValidationMessage(font, message, textWidth, displayMode)
        local itemBottom = currentY + itemHeight

        if itemBottom >= layout.listRect.y and currentY <= layout.listRect.y + layout.listRect.h then
            rows[#rows + 1] = {
                index = index,
                entry = entry,
                message = message,
                rect = {
                    x = layout.listRect.x,
                    y = currentY,
                    w = layout.contentWidth or layout.listRect.w,
                    h = itemHeight,
                },
                indentOffset = indentOffset,
                textWidth = textWidth,
                numberLabel = numberLabel,
                numberWidth = numberWidth,
            }
        end

        currentY = currentY + itemHeight + 10
    end

    return rows
end

function mapEditor:addTrain()
    local lineColors = self:getAvailableLineColorIds()
    local spawnTime = 0
    for _, train in ipairs(self.trains) do
        spawnTime = math.max(spawnTime, (train.spawnTime or 0) + 0.5)
    end
    self.trains[#self.trains + 1] = self:createTrainDefinition({
        lineColor = lineColors[1],
        trainColor = lineColors[1],
        spawnTime = spawnTime,
        wagonCount = DEFAULT_TRAIN_WAGONS,
    })
    self:clampSequencerScroll()
    self:refreshValidation()
    self:showStatus("Train added to the sequencer.")
end

function mapEditor:getTrainRowHeight(_)
    return 38
end

function mapEditor:removeTrainByIndex(trainIndex)
    if not self.trains[trainIndex] then
        return
    end
    table.remove(self.trains, trainIndex)
    self:clampSequencerScroll()
    self:refreshValidation()
    self:showStatus("Train removed from the sequencer.")
end

function mapEditor:getTrainById(trainId)
    for _, train in ipairs(self.trains) do
        if train.id == trainId then
            return train
        end
    end
    return nil
end

function mapEditor:getSelectedRoute()
    if not self.selectedRouteId then
        return nil
    end

    for _, route in ipairs(self.routes) do
        if route.id == self.selectedRouteId then
            return route
        end
    end

    return nil
end

function mapEditor:getRouteSegmentCount(route)
    if not route or not route.points then
        return 0
    end

    return math.max(0, #route.points - 1)
end

function mapEditor:ensureRouteSegmentRoadTypes(route)
    if not route then
        return {}
    end

    local segmentCount = self:getRouteSegmentCount(route)
    local segmentRoadTypes = route.segmentRoadTypes or {}
    local normalizedRoadTypes = {}
    local fallbackRoadType = roadTypes.normalizeRoadType(route.roadType)

    for segmentIndex = 1, segmentCount do
        normalizedRoadTypes[segmentIndex] = roadTypes.normalizeRoadType(segmentRoadTypes[segmentIndex] or fallbackRoadType)
    end

    route.segmentRoadTypes = normalizedRoadTypes
    route.roadType = nil
    return route.segmentRoadTypes
end

function mapEditor:getRouteSegmentRoadType(route, segmentIndex)
    local segmentRoadTypes = self:ensureRouteSegmentRoadTypes(route)
    return segmentRoadTypes[segmentIndex] or DEFAULT_ROAD_TYPE
end

function mapEditor:summarizeRouteRoadTypes(route)
    local counts = {}
    local summaryParts = {}

    for _, roadTypeId in ipairs(self:ensureRouteSegmentRoadTypes(route)) do
        counts[roadTypeId] = (counts[roadTypeId] or 0) + 1
    end

    for _, option in ipairs(ROAD_TYPE_OPTIONS) do
        local count = counts[option.id] or 0
        if count > 0 then
            summaryParts[#summaryParts + 1] = string.format("%d %s", count, option.label:lower())
        end
    end

    if #summaryParts == 0 then
        return "No road segments."
    end

    return table.concat(summaryParts, ", ")
end

function mapEditor:createEndpoint(kind, x, y, colors, id)
    local endpointId = id or (kind .. "_endpoint_" .. self.nextEndpointId)
    local fallbackColorId = COLOR_OPTIONS[((self.nextEndpointId - 1) % #COLOR_OPTIONS) + 1].id
    local endpoint = {
        id = endpointId,
        kind = kind,
        x = x,
        y = y,
        colors = normalizeEndpointColors(kind, colors, fallbackColorId),
    }
    self.endpoints[#self.endpoints + 1] = endpoint
    self.nextEndpointId = self.nextEndpointId + 1
    return endpoint
end

function mapEditor:getEndpointById(endpointId)
    for _, endpoint in ipairs(self.endpoints) do
        if endpoint.id == endpointId then
            return endpoint
        end
    end
    return nil
end

function mapEditor:getRouteStartEndpoint(route)
    return self:getEndpointById(route.startEndpointId)
end

function mapEditor:getRouteEndEndpoint(route)
    return self:getEndpointById(route.endEndpointId)
end

function mapEditor:getEndpointRouteCount(endpointId)
    local count = 0
    for _, route in ipairs(self.routes) do
        if route.startEndpointId == endpointId or route.endEndpointId == endpointId then
            count = count + 1
        end
    end
    return count
end

function mapEditor:removeEndpointIfUnused(endpointId)
    if self:getEndpointRouteCount(endpointId) > 0 then
        return
    end

    for endpointIndex, endpoint in ipairs(self.endpoints) do
        if endpoint.id == endpointId then
            table.remove(self.endpoints, endpointIndex)
            return
        end
    end
end

function mapEditor:updateRouteEndpointPoint(route, endpointKind)
    local endpoint = endpointKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route)
    if not endpoint then
        return
    end

    if endpointKind == "start" then
        route.points[1].x = endpoint.x
        route.points[1].y = endpoint.y
    else
        route.points[#route.points].x = endpoint.x
        route.points[#route.points].y = endpoint.y
    end
end

function mapEditor:updateRoutesForEndpoint(endpointId)
    for _, route in ipairs(self.routes) do
        if route.startEndpointId == endpointId then
            self:updateRouteEndpointPoint(route, "start")
        end
        if route.endEndpointId == endpointId then
            self:updateRouteEndpointPoint(route, "end")
        end
    end
end

function mapEditor:getControlName(controlType)
    return CONTROL_NAMES[controlType] or CONTROL_NAMES[DEFAULT_CONTROL]
end

function mapEditor:getControlLabel(controlType)
    return CONTROL_LABELS[controlType] or CONTROL_LABELS[DEFAULT_CONTROL]
end

function mapEditor:showStatus(text)
    self.statusText = text
    self.statusTimer = 2.8
end

function mapEditor:updatePreviewWorld(previewLevel)
    local level = previewLevel or {
        title = self.currentMapName or "Untitled",
        edges = {},
        junctions = {},
        trains = {},
    }
    self.previewWorld = world.new(self.mapSize.w, self.mapSize.h, level)
end

function mapEditor:setValidationResults(buildError, buildErrors, buildDiagnostics)
    self.lastValidationError = buildError
    self.validationErrors = buildErrors or {}
    self.validationEntries = {}
    local trainLookup = self:getTrainValidationLookup()

    for index, message in ipairs(self.validationErrors) do
        if message ~= EMPTY_MAP_VALIDATION_TEXT then
            local diagnostic = buildDiagnostics and buildDiagnostics[index] or nil
            local entry = self:buildValidationEntry(message, diagnostic, trainLookup)
            entry.sourceIndex = index
            self.validationEntries[#self.validationEntries + 1] = entry
        end
    end
    self:groupValidationEntriesByHierarchy()
    self:refreshValidationEntryNumbering()

    self.hoveredValidationIndex = nil
end

function mapEditor:refreshValidation(mapName)
    local level, previewLevel, buildError, buildErrors, buildDiagnostics = mapCompiler.buildEditorPreviewBundle(
        mapName or self.currentMapName or "Untitled",
        self:getExportData(),
        self.editingMapUuid
    )
    self:updatePreviewWorld(previewLevel)
    self:setValidationResults(buildError, buildErrors, buildDiagnostics)
    return level, buildError, self.validationErrors
end

function mapEditor:getSavedMapDescriptor()
    if not isLocalSavedMapDescriptor(self.lastSavedDescriptor) then
        return nil
    end

    return self.lastSavedDescriptor
end

function mapEditor:buildDirtyStateSnapshot()
    return {
        name = self.currentMapName,
        mapUuid = self.editingMapUuid,
        editor = self:getExportData(),
    }
end

function mapEditor:updateSavedStateSnapshot()
    self.savedStateSnapshotJson = json.encode(self:buildDirtyStateSnapshot())
end

function mapEditor:hasUnsavedChanges()
    local savedSnapshotJson = self.savedStateSnapshotJson
    if not savedSnapshotJson then
        savedSnapshotJson = json.encode({
            editor = buildBlankEditorData(),
        })
    end

    return json.encode(self:buildDirtyStateSnapshot()) ~= savedSnapshotJson
end

function mapEditor:canPlaySavedMap()
    return self:getSavedMapDescriptor() ~= nil and not self:hasUnsavedChanges()
end

function mapEditor:setSavedMapUploadState(isAvailable, isPending)
    self.savedMapUploadAvailable = isAvailable == true
    self.savedMapUploadPending = isPending == true
end

function mapEditor:canUploadSavedMap()
    return self:getSavedMapDescriptor() ~= nil
        and not self:hasUnsavedChanges()
        and self.savedMapUploadAvailable == true
        and self.savedMapUploadPending ~= true
end

function mapEditor:requestPlaytestFromSavedMap()
    if self:getSavedMapDescriptor() == nil then
        self:showStatus("Save a playable map first, then test it from here.")
        return false
    end

    if self:hasUnsavedChanges() then
        self:showStatus("Save the map again before starting the saved version.")
        return false
    end

    self.pendingPlaytestDescriptor = self:getSavedMapDescriptor()
    self:showStatus("Starting test run from the saved map...")
    return true
end

function mapEditor:consumePlaytestRequest()
    local descriptor = self.pendingPlaytestDescriptor
    self.pendingPlaytestDescriptor = nil
    return descriptor
end

function mapEditor:requestUploadFromSavedMap()
    if self:getSavedMapDescriptor() == nil then
        self:showStatus("Save a playable local map before uploading it.")
        return false
    end

    if self:hasUnsavedChanges() then
        self:showStatus("Save the map again before uploading it.")
        return false
    end

    if self.savedMapUploadPending == true then
        self:showStatus("This map is already uploading.")
        return false
    end

    if self.savedMapUploadAvailable ~= true then
        self:showStatus(UPLOAD_UNAVAILABLE_MESSAGE)
        return false
    end

    self.pendingUploadDescriptor = self:getSavedMapDescriptor()
    self:showStatus("Uploading the saved map...")
    return true
end

function mapEditor:consumeUploadRequest()
    local descriptor = self.pendingUploadDescriptor
    self.pendingUploadDescriptor = nil
    return descriptor
end

function mapEditor:requestOpenBlankMap()
    self.pendingOpenBlankMap = true
    self:closeDialog()
    return true
end

function mapEditor:consumeOpenBlankMapRequest()
    local isPending = self.pendingOpenBlankMap
    self.pendingOpenBlankMap = false
    return isPending
end

function mapEditor:createRoute(points, color, id, label, colorId, startColors, endColors, startEndpointId, endEndpointId, segmentRoadTypes)
    local routeId = id or ("route_" .. self.nextRouteId)
    local resolvedColorId = colorId or nearestColorId(color)
    local resolvedColor = normalizeColor(color or getColorById(resolvedColorId))
    local startPoint = points[1]
    local endPoint = points[#points]
    local startEndpoint = startEndpointId and self:getEndpointById(startEndpointId)
        or self:createEndpoint("input", startPoint.x, startPoint.y, startColors or { resolvedColorId }, startEndpointId)
    local endEndpoint = endEndpointId and self:getEndpointById(endEndpointId)
        or self:createEndpoint("output", endPoint.x, endPoint.y, endColors or { resolvedColorId }, endEndpointId)
    local route = {
        id = routeId,
        label = label or routeId,
        colorId = resolvedColorId,
        color = resolvedColor,
        darkColor = darkerColor(resolvedColor),
        startEndpointId = startEndpoint.id,
        endEndpointId = endEndpoint.id,
        points = {},
        segmentRoadTypes = {},
    }

    for _, point in ipairs(points) do
        route.points[#route.points + 1] = copyPoint(point)
    end

    self.routes[#self.routes + 1] = route
    self.nextRouteId = self.nextRouteId + 1
    route.segmentRoadTypes = buildDefaultSegmentRoadTypes(#route.points, DEFAULT_ROAD_TYPE)
    if type(segmentRoadTypes) == "table" then
        for segmentIndex = 1, #route.segmentRoadTypes do
            route.segmentRoadTypes[segmentIndex] = roadTypes.normalizeRoadType(segmentRoadTypes[segmentIndex])
        end
    end
    self:updateRouteEndpointPoint(route, "start")
    self:updateRouteEndpointPoint(route, "end")
    return route
end

function mapEditor:getRouteById(routeId)
    for _, route in ipairs(self.routes) do
        if route.id == routeId then
            return route
        end
    end
    return nil
end

function mapEditor:getControlConfig(controlType)
    local config = DEFAULT_CONTROL_CONFIGS[controlType] or DEFAULT_CONTROL_CONFIGS.direct
    local copy = {}
    for key, value in pairs(config) do
        copy[key] = value
    end
    copy.type = controlType
    return copy
end

function mapEditor:splitRouteAtIntersection(route, intersectionPoint)
    local prefix = {}
    prefix[#prefix + 1] = copyPoint(route.points[1])

    for pointIndex = 1, #route.points - 1 do
        local a = route.points[pointIndex]
        local b = route.points[pointIndex + 1]
        local hitPoint = pointOnSegment(intersectionPoint, a, b, 9)

        if hitPoint then
            if distanceSquared(prefix[#prefix].x, prefix[#prefix].y, hitPoint.x, hitPoint.y) > 1 then
                prefix[#prefix + 1] = hitPoint
            end
            return prefix
        end

        prefix[#prefix + 1] = copyPoint(b)
    end

    return nil
end

function mapEditor:splitRouteSuffixAtIntersection(route, intersectionPoint)
    for pointIndex = 1, #route.points - 1 do
        local a = route.points[pointIndex]
        local b = route.points[pointIndex + 1]
        local hitPoint = pointOnSegment(intersectionPoint, a, b, 9)

        if hitPoint then
            local suffix = { hitPoint }
            if distanceSquared(hitPoint.x, hitPoint.y, b.x, b.y) > 1 then
                suffix[#suffix + 1] = copyPoint(b)
            end
            for suffixIndex = pointIndex + 2, #route.points do
                suffix[#suffix + 1] = copyPoint(route.points[suffixIndex])
            end
            return suffix
        end
    end

    return nil
end

function mapEditor:normalizePoints(points)
    local normalized = {}
    for _, point in ipairs(points) do
        normalized[#normalized + 1] = {
            x = point.x / self.mapSize.w,
            y = point.y / self.mapSize.h,
        }
    end
    return normalized
end

function pointsRoughlyMatch(firstPoints, secondPoints, tolerance)
    if #firstPoints ~= #secondPoints then
        return false
    end

    tolerance = tolerance or 6
    local toleranceSquared = tolerance * tolerance

    for index = 1, #firstPoints do
        if distanceSquared(firstPoints[index].x, firstPoints[index].y, secondPoints[index].x, secondPoints[index].y) > toleranceSquared then
            return false
        end
    end

    return true
end

function mapEditor:buildOutputRoutesByEndpoint(intersection)
    local routesByEndpoint = {}

    for _, routeId in ipairs(intersection.routeIds or {}) do
        local route = self:getRouteById(routeId)
        if route and route.endEndpointId then
            routesByEndpoint[route.endEndpointId] = routesByEndpoint[route.endEndpointId] or {}
            routesByEndpoint[route.endEndpointId][#routesByEndpoint[route.endEndpointId] + 1] = route
        end
    end

    return routesByEndpoint
end

function mapEditor:buildPlayableLevel(mapName)
    return self:refreshValidation(mapName)
end

function mapEditor:saveMap(name)
    local trimmedName = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if trimmedName == "" then
        return false, "Give the map a name before saving it."
    end

    local level, buildError, buildErrors = self:buildPlayableLevel(trimmedName)
    if not level then
        buildError = buildError or "This map cannot be played yet, but the editor layout can still be saved."
    end

    local payload = {
        version = 1,
        name = trimmedName,
        mapUuid = self.editingMapUuid or uuid.generateV4(),
        savedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        editor = self:getExportData(),
    }
    if level then
        payload.level = level
    end
    local wasBuiltinTemplate = self.sourceInfo and self.sourceInfo.source == "builtin"
    local record, saveError = mapStorage.saveMap(trimmedName, payload)
    if not record then
        return false, saveError or "The map could not be written to disk."
    end

    self.currentMapName = trimmedName
    self.editingMapUuid = payload.mapUuid
    self.sourceInfo = record
    self.lastSavedDescriptor = record.hasLevel and record or nil
    self.loadedMapPayload = payload
    self.pendingUploadDescriptor = nil
    self.hoveredValidationIndex = nil
    self:updateSavedStateSnapshot()
    self:closeDialog()
    if level then
        self:showStatus((wasBuiltinTemplate and "Saved copy: " or "Saved map: ") .. trimmedName .. " to " .. mapStorage.getSaveDirectory() .. ".")
    else
        self:showStatus("Saved map: " .. trimmedName .. ". Remaining issues: " .. buildError)
    end
    return true
end

function mapEditor:resetFromMap(mapData, sourceInfo)
    self.loadedMapPayload = mapData
    self.sourceInfo = sourceInfo
    self.editingMapUuid = mapData and mapData.mapUuid or nil
    self.lastSavedDescriptor = sourceInfo and sourceInfo.hasLevel and sourceInfo or nil
    self.pendingPlaytestDescriptor = nil
    self.pendingUploadDescriptor = nil

    if not mapData then
        self.level = nil
        self.mapSize = sanitizeMapSize(nil, DEFAULT_NEW_MAP_WIDTH, DEFAULT_NEW_MAP_HEIGHT)
        self.currentMapName = nil
        self.editingMapUuid = nil
        self.endpoints = {}
        self.routes = {}
        self.trains = {}
        self.timeLimit = nil
        self.nextEndpointId = 1
        self.nextRouteId = 1
        self.nextSharedPointId = 1
        self.nextTrainId = 1
        self.importedJunctionState = {}
        self.drag = nil
        self.sidePanelMode = "default"
        self.sequencerScroll = 0
        self.activeTextField = nil
        self.sequencerScrollDrag = nil
        self.validationScroll = 0
        self.validationScrollDrag = nil
        self.validationEntries = {}
        self.hoveredValidationIndex = nil
        self:closeColorPicker()
        self:closeRouteTypePicker()
        self:clearSelection()
        self:updateLayout()
        self:resetCameraToFit()
        self:rebuildIntersections()
        self:updateSavedStateSnapshot()
        return
    end

    if mapData.editor then
        if sourceInfo and sourceInfo.source == "builtin" then
            self.editingMapUuid = nil
        end
        self:loadEditorData(mapData.editor, mapData.name, sourceInfo, mapData.level)
        return
    end

    self:resetFromLevel(mapData.level)
    self.sourceInfo = sourceInfo
    self.loadedMapPayload = mapData
    self:updateSavedStateSnapshot()
end

function mapEditor:resetFromLevel(level)
    self.level = level
    self.mapSize = sanitizeMapSize(nil, LEGACY_MAP_WIDTH, LEGACY_MAP_HEIGHT)
    self.currentMapName = level and level.title or nil
    self.endpoints = {}
    self.routes = {}
    self.trains = self:synthesizeTrainsFromLevel(level)
    self.timeLimit = level and level.timeLimit or nil
    self.nextEndpointId = 1
    self.nextRouteId = 1
    self.nextSharedPointId = 1
    self.nextTrainId = 1
    self.importedJunctionState = {}
    self.drag = nil
    self.sidePanelMode = "default"
    self.sequencerScroll = 0
    self.activeTextField = nil
    self.sequencerScrollDrag = nil
    self.validationScroll = 0
    self.validationScrollDrag = nil
    self.validationEntries = {}
    self.hoveredValidationIndex = nil
    self:closeColorPicker()
    self:closeRouteTypePicker()
    self:clearSelection()
    self:updateLayout()
    self:resetCameraToFit()

    for _, train in ipairs(self.trains) do
        local numericId = tonumber((train.id or ""):match("train_(%d+)$"))
        if numericId and numericId >= self.nextTrainId then
            self.nextTrainId = numericId + 1
        end
    end

    if not level then
        self:rebuildIntersections()
        return
    end

    for _, junctionDefinition in ipairs(level.junctions or {}) do
        local mergeX
        local mergeY
        local exitY
        local branchRoutes = {}

        for _, branchDefinition in ipairs(junctionDefinition.branches or {}) do
            local branchColorId = nearestColorId(branchDefinition.color)
            local points

            if branchDefinition.branchPoints and branchDefinition.sharedPoints then
                points = {}
                for _, point in ipairs(branchDefinition.branchPoints) do
                    points[#points + 1] = {
                        x = point.x * self.mapSize.w,
                        y = point.y * self.mapSize.h,
                    }
                end
                for pointIndex = 2, #branchDefinition.sharedPoints do
                    local point = branchDefinition.sharedPoints[pointIndex]
                    points[#points + 1] = {
                        x = point.x * self.mapSize.w,
                        y = point.y * self.mapSize.h,
                    }
                end
                mergeX = points[#branchDefinition.branchPoints].x
                mergeY = points[#branchDefinition.branchPoints].y
                exitY = points[#points].y
            else
                mergeX = self.canvas.x + self.canvas.w * junctionDefinition.mergeX
                mergeY = self.canvas.y + self.canvas.h * junctionDefinition.mergeY
                exitY = self.canvas.y + self.canvas.h * clamp(junctionDefinition.exitY or 1.0, 0, 1)
                local bendY = mergeY - self.canvas.h * 0.22
                local startX = self.canvas.x + self.canvas.w * branchDefinition.startX
                points = {
                    { x = startX, y = self.spawnY },
                    { x = startX, y = bendY },
                    { x = mergeX, y = mergeY },
                    { x = mergeX, y = exitY },
                }
            end

            local route = self:createRoute(
                points,
                branchDefinition.color,
                nil,
                branchDefinition.label or branchDefinition.id,
                branchColorId,
                { branchColorId },
                { branchColorId }
            )
            branchRoutes[#branchRoutes + 1] = route
        end

        if #branchRoutes == 2 then
            local key = routePairKey(branchRoutes[1].id, branchRoutes[2].id)
            self.importedJunctionState[key] = self.importedJunctionState[key] or {}
            self.importedJunctionState[key][#self.importedJunctionState[key] + 1] = {
                x = mergeX,
                y = mergeY,
                controlType = ((junctionDefinition.control or {}).type) or DEFAULT_CONTROL,
                activeInputIndex = junctionDefinition.activeBranch or 1,
                activeOutputIndex = 1,
            }
        end

        local routeIds = {}
        for _, route in ipairs(branchRoutes) do
            routeIds[#routeIds + 1] = route.id
        end
        self:restoreSharedPointsForRoutes(routeIds)
    end

    self:rebuildIntersections()
end

function mapEditor:resize(viewportW, viewportH)
    self.viewport.w = viewportW
    self.viewport.h = viewportH
    self:updateLayout()
    self:clampCamera()
    self:rebuildIntersections()
end

function mapEditor:resizeMapTo(width)
    local nextMapSize = sanitizeMapSize({
        w = width,
        h = math.floor((tonumber(width) or self.mapSize.w) * 9 / 16 + 0.5),
    }, self.mapSize.w, self.mapSize.h)

    if nextMapSize.w == self.mapSize.w and nextMapSize.h == self.mapSize.h then
        return false
    end

    local scaleX = nextMapSize.w / self.mapSize.w
    local scaleY = nextMapSize.h / self.mapSize.h

    for _, endpoint in ipairs(self.endpoints) do
        endpoint.x = endpoint.x * scaleX
        endpoint.y = endpoint.y * scaleY
    end

    for _, route in ipairs(self.routes) do
        for _, point in ipairs(route.points or {}) do
            point.x = point.x * scaleX
            point.y = point.y * scaleY
        end
    end

    for _, intersection in ipairs(self.intersections) do
        intersection.x = intersection.x * scaleX
        intersection.y = intersection.y * scaleY
    end

    for _, state in pairs(self.importedJunctionState or {}) do
        state.x = (state.x or 0) * scaleX
        state.y = (state.y or 0) * scaleY
    end

    self.mapSize = nextMapSize
    self:updateLayout()
    self:resetCameraToFit()
    self:rebuildIntersections()
    self:showStatus(string.format("Map size set to %dx%d.", self.mapSize.w, self.mapSize.h))
    return true
end

function mapEditor:update(dt)
    if self.statusTimer > 0 then
        self.statusTimer = math.max(0, self.statusTimer - dt)
        if self.statusTimer <= 0 then
            self.statusText = nil
        end
    end

    if self.colorPicker and self.colorPicker.mode == "junction" and self.colorPicker.popupTimer ~= nil then
        self.colorPicker.popupTimer = math.min(JUNCTION_MENU_POP_DURATION, self.colorPicker.popupTimer + dt)
    end
end

end
