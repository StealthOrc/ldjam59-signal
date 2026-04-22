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

function mapEditor:beginRoute(x, y)
    local colorOption = COLOR_OPTIONS[((self.nextRouteId - 1) % #COLOR_OPTIONS) + 1]
    local startX, startY = self:clampPoint(x, y, false)
    local route = self:createRoute(
        {
            { x = startX, y = startY },
            { x = startX, y = startY },
        },
        colorOption.color,
        nil,
        nil,
        colorOption.id,
        { colorOption.id },
        { colorOption.id },
        nil,
        nil,
        { DEFAULT_ROAD_TYPE }
    )

    self.selectedRouteId = route.id
    self.selectedPointIndex = 2
    self.drag = {
        kind = "new_route",
        routeId = route.id,
        pointIndex = 2,
        startMouseX = x,
        startMouseY = y,
        moved = false,
        isMagnet = true,
        magnetKind = "end",
    }
    self:closeColorPicker()
    self:closeRouteTypePicker()
    self:rebuildIntersections()
end

function mapEditor:updateDraggedPoint(x, y)
    if not self.drag then
        return
    end

    if self.drag.kind == "intersection" then
        local movedDistance = distanceSquared(x, y, self.drag.startMouseX, self.drag.startMouseY)
        if movedDistance > DRAG_START_DISTANCE_SQUARED then
            self.drag.moved = true
        end

        if not self.drag.moved then
            return
        end

        if not self.drag.sharedPointId then
            local liveIntersection = self:getIntersectionById(self.drag.intersectionId)
            local preparedDrag = self:prepareIntersectionForDrag(liveIntersection or self.drag.intersectionSnapshot)
            if not preparedDrag then
                return
            end
            self.drag.sharedPointId = preparedDrag.sharedPointId
            self.drag.routeId = preparedDrag.routeId
            self.drag.pointIndex = preparedDrag.pointIndex
            self.drag.primaryRouteIds = copyArray(preparedDrag.routeIds or {})
            self.selectedRouteId = preparedDrag.routeId
            self.selectedPointIndex = preparedDrag.pointIndex
        end

        local clampedX, clampedY = self:clampPoint(x, y, false)
        self:pruneSharedPointFromRoutes(self.drag.sharedPointId, self.drag.primaryRouteIds)
        self:updateSharedPointGroup(self.drag.sharedPointId, clampedX, clampedY)
        self:closeColorPicker()
        self:closeRouteTypePicker()
        self.deferIntersectionMaterialization = true
        self:rebuildIntersections()
        self.deferIntersectionMaterialization = false
        return
    end

    local route = self:getSelectedRoute()
    if not route then
        return
    end

    local point = route.points[self.drag.pointIndex]
    if not point then
        return
    end

    local movedDistance = distanceSquared(x, y, self.drag.startMouseX, self.drag.startMouseY)
    if movedDistance > DRAG_START_DISTANCE_SQUARED then
        self.drag.moved = true
    end

    if not self.drag.moved then
        return
    end

    local clampedX, clampedY = self:clampPoint(x, y, self.drag.pointIndex == 1)
    if self:isModifierSnapActive() then
        clampedX, clampedY = self:snapPointToGrid(clampedX, clampedY)
        clampedX, clampedY = self:clampPoint(clampedX, clampedY, self.drag.pointIndex == 1)
    end
    if self.drag.isMagnet then
        local endpoint = self.drag.magnetKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route)
        if endpoint then
            endpoint.x = clampedX
            endpoint.y = clampedY
            self:updateRoutesForEndpoint(endpoint.id)
        end
    else
        point.x = clampedX
        point.y = clampedY
        if point.sharedPointId then
            self:updateSharedPointGroup(point.sharedPointId, clampedX, clampedY)
        end
    end
    self:closeColorPicker()
    self.deferIntersectionMaterialization = true
    self:rebuildIntersections()
    self.deferIntersectionMaterialization = false
end

function mapEditor:ensureRoutePointAtIntersection(route, intersectionPoint)
    if not route or not route.points or #route.points < 2 then
        return nil, nil, false
    end

    for pointIndex = 2, #route.points - 1 do
        local point = route.points[pointIndex]
        if distanceSquared(point.x, point.y, intersectionPoint.x, intersectionPoint.y) <= INTERSECTION_POINT_TOLERANCE_SQUARED then
            return pointIndex, point, false
        end
    end

    for segmentIndex = 1, #route.points - 1 do
        local pointA = route.points[segmentIndex]
        local pointB = route.points[segmentIndex + 1]
        local hitPoint = pointOnSegment(intersectionPoint, pointA, pointB, INTERSECTION_POINT_TOLERANCE_SQUARED)
        if hitPoint then
            if distanceSquared(hitPoint.x, hitPoint.y, pointA.x, pointA.y) <= INTERNAL_POINT_MATCH_DISTANCE_SQUARED and segmentIndex > 1 then
                return segmentIndex, pointA, false
            end
            if distanceSquared(hitPoint.x, hitPoint.y, pointB.x, pointB.y) <= INTERNAL_POINT_MATCH_DISTANCE_SQUARED
                and (segmentIndex + 1) < #route.points then
                return segmentIndex + 1, pointB, false
            end

            local insertIndex = segmentIndex + 1
            table.insert(route.points, insertIndex, hitPoint)
            self:splitRouteSegmentStyle(route, segmentIndex)
            return insertIndex, route.points[insertIndex], true
        end
    end

    return nil, nil, false
end

function mapEditor:prepareIntersectionForDrag(intersection)
    if not intersection then
        return nil
    end

    local members = {}
    local sharedPointId = nil

    for _, routeId in ipairs(intersection.routeIds or {}) do
        local route = self:getRouteById(routeId)
        local pointIndex, point = self:ensureRoutePointAtIntersection(route, intersection)
        if route and pointIndex and point then
            members[#members + 1] = {
                route = route,
                pointIndex = pointIndex,
                point = point,
            }
            if point.sharedPointId and not sharedPointId then
                sharedPointId = point.sharedPointId
            end
        end
    end

    if #members == 0 then
        return nil
    end

    if not sharedPointId then
        sharedPointId = self.nextSharedPointId
        self.nextSharedPointId = self.nextSharedPointId + 1
    end

    for _, member in ipairs(members) do
        if member.point.sharedPointId and member.point.sharedPointId ~= sharedPointId then
            self:reassignSharedPointGroup(member.point.sharedPointId, sharedPointId)
        end
        member.point.sharedPointId = sharedPointId
    end
    self:updateSharedPointGroup(sharedPointId, intersection.x, intersection.y)
    self:rebuildIntersections()

    return {
        sharedPointId = sharedPointId,
        routeId = members[1].route.id,
        pointIndex = members[1].pointIndex,
        routeIds = copyArray(intersection.routeIds or {}),
    }
end

function mapEditor:materializeIntersectionSharedPoints(intersection)
    if not intersection then
        return false
    end

    local members = {}
    local sharedPointId = nil
    local changed = false

    for _, routeId in ipairs(intersection.routeIds or {}) do
        local route = self:getRouteById(routeId)
        local pointIndex, point, inserted = self:ensureRoutePointAtIntersection(route, intersection)
        if route and pointIndex and point then
            members[#members + 1] = {
                route = route,
                pointIndex = pointIndex,
                point = point,
            }
            changed = changed or inserted

            if point.sharedPointId and not sharedPointId then
                sharedPointId = point.sharedPointId
            end
        end
    end

    if #members < 2 then
        return changed
    end

    if not sharedPointId then
        sharedPointId = self.nextSharedPointId
        self.nextSharedPointId = self.nextSharedPointId + 1
        changed = true
    end

    for _, member in ipairs(members) do
        if member.point.sharedPointId and member.point.sharedPointId ~= sharedPointId then
            self:reassignSharedPointGroup(member.point.sharedPointId, sharedPointId)
            changed = true
        end
        if member.point.sharedPointId ~= sharedPointId then
            changed = true
        end
        member.point.sharedPointId = sharedPointId
    end

    self:updateSharedPointGroup(sharedPointId, intersection.x, intersection.y)
    return changed
end

function mapEditor:isIntersectionOutputSelectorHit(intersection, x, y)
    if not intersection or #intersection.outputEndpointIds <= 1 then
        return false
    end
    return distanceSquared(x, y, intersection.x, intersection.y + INTERSECTION_SELECTOR_OFFSET_Y)
        <= INTERSECTION_SELECTOR_CLICK_RADIUS * INTERSECTION_SELECTOR_CLICK_RADIUS
end

function mapEditor:findIntersectionOutputSelectorHit(x, y)
    for _, intersection in ipairs(self.intersections) do
        if self:isIntersectionOutputSelectorHit(intersection, x, y) then
            return intersection
        end
    end

    return nil
end

function mapEditor:setIntersectionControlType(intersection, controlType)
    if not intersection or not controlType then
        return false
    end
    if intersection.unsupported then
        self:showStatus("Junctions currently support up to five inputs and five outputs.")
        return false
    end
    if intersection.controlType == controlType then
        return false
    end

    intersection.controlType = controlType
    if intersection.controlType == "relay" then
        self:syncIntersectionOutputToControl(intersection)
    elseif intersection.controlType == "crossbar" then
        self:syncIntersectionOutputToControl(intersection)
    end

    self:refreshValidation(self.currentMapName)
    self:showStatus("Intersection switched to " .. self:getControlName(intersection.controlType) .. ".")
    return true
end

function mapEditor:cycleIntersection(intersection)
    local currentIndex = 1
    for controlIndex, controlType in ipairs(CONTROL_ORDER) do
        if controlType == intersection.controlType then
            currentIndex = controlIndex
            break
        end
    end

    local nextIndex = currentIndex + 1
    if nextIndex > #CONTROL_ORDER then
        nextIndex = 1
    end

    self:setIntersectionControlType(intersection, CONTROL_ORDER[nextIndex])
end

function mapEditor:syncIntersectionOutputToControl(intersection)
    if not intersection then
        return
    end

    local outputCount = #(intersection.outputEndpointIds or {})
    if outputCount <= 0 then
        intersection.activeOutputIndex = 1
        return
    end

    if intersection.controlType == "relay" or intersection.controlType == "crossbar" then
        intersection.activeOutputIndex = self:getDirectionalIntersectionOutputIndex(intersection, intersection.controlType)
    else
        intersection.activeOutputIndex = clamp(intersection.activeOutputIndex or 1, 1, outputCount)
    end
end

function mapEditor:getIntersectionRouteOuterPoint(route, magnetKind)
    if not route or not route.points or #route.points <= 0 then
        return nil
    end

    if magnetKind == "end" then
        return route.points[#route.points]
    end

    return route.points[1]
end

function mapEditor:getIntersectionAngle(point, intersection)
    if not point or not intersection then
        return 0
    end

    local dx = (point.x or 0) - (intersection.x or 0)
    local dy = (point.y or 0) - (intersection.y or 0)
    if math.atan2 then
        return math.atan2(dy, dx)
    end

    if math.abs(dx) <= 0.0001 then
        return dy >= 0 and (math.pi * 0.5) or (-math.pi * 0.5)
    end

    local angle = math.atan(dy / dx)
    if dx < 0 then
        angle = angle + math.pi
    end
    if angle > math.pi then
        angle = angle - math.pi * 2
    end
    return angle
end

function mapEditor:buildIntersectionRouteEntries(intersection, routeIds, magnetKind)
    local entries = {}

    for index, routeId in ipairs(routeIds or {}) do
        local route = self:getRouteById(routeId)
        local outerPoint = self:getIntersectionRouteOuterPoint(route, magnetKind)
        entries[#entries + 1] = {
            index = index,
            routeId = routeId,
            outerPoint = outerPoint,
            angle = self:getIntersectionAngle(outerPoint, intersection),
        }
    end

    return entries
end

function mapEditor:sortIntersectionEntriesByPosition(entries)
    table.sort(entries, function(first, second)
        local firstPoint = first and first.outerPoint or nil
        local secondPoint = second and second.outerPoint or nil
        if not firstPoint or not secondPoint then
            return (first and first.index or 0) < (second and second.index or 0)
        end

        local xDiff = math.abs((firstPoint.x or 0) - (secondPoint.x or 0))
        if xDiff > 0.0001 then
            return (firstPoint.x or 0) < (secondPoint.x or 0)
        end

        local yDiff = math.abs((firstPoint.y or 0) - (secondPoint.y or 0))
        if yDiff > 0.0001 then
            return (firstPoint.y or 0) < (secondPoint.y or 0)
        end

        return (first.index or 0) < (second.index or 0)
    end)
end

function mapEditor:sortIntersectionEntriesByCycle(entries)
    table.sort(entries, function(first, second)
        local angleDiff = math.abs((first.angle or 0) - (second.angle or 0))
        if angleDiff > 0.0001 then
            return (first.angle or 0) < (second.angle or 0)
        end

        local firstPoint = first and first.outerPoint or nil
        local secondPoint = second and second.outerPoint or nil
        if not firstPoint or not secondPoint then
            return (first and first.index or 0) < (second and second.index or 0)
        end

        local xDiff = math.abs((firstPoint.x or 0) - (secondPoint.x or 0))
        if xDiff > 0.0001 then
            return (firstPoint.x or 0) < (secondPoint.x or 0)
        end

        return (first.index or 0) < (second.index or 0)
    end)
end

function mapEditor:getNextIntersectionInputIndex(intersection)
    local entries = self:buildIntersectionRouteEntries(intersection, intersection and intersection.inputRouteIds or {}, "start")
    self:sortIntersectionEntriesByCycle(entries)
    if #entries <= 1 then
        return 1
    end

    for orderIndex, entry in ipairs(entries) do
        if entry.index == (intersection.activeInputIndex or 1) then
            local nextEntry = entries[orderIndex + 1] or entries[1]
            return nextEntry.index
        end
    end

    return entries[1].index
end

function mapEditor:getDirectionalIntersectionOutputIndex(intersection, controlType)
    local inputEntries = self:buildIntersectionRouteEntries(intersection, intersection and intersection.inputRouteIds or {}, "start")
    local outputEntries = self:buildIntersectionRouteEntries(intersection, intersection and intersection.outputRouteIds or {}, "end")
    self:sortIntersectionEntriesByPosition(inputEntries)
    self:sortIntersectionEntriesByPosition(outputEntries)

    local inputRank = nil
    for rank, entry in ipairs(inputEntries) do
        if entry.index == (intersection.activeInputIndex or 1) then
            inputRank = rank
            break
        end
    end

    if not inputRank or #outputEntries <= 0 then
        return clamp(intersection.activeOutputIndex or 1, 1, math.max(1, #(intersection.outputEndpointIds or {})))
    end

    local targetRank = inputRank
    if controlType == "crossbar" then
        targetRank = #outputEntries - inputRank + 1
    end
    targetRank = clamp(targetRank, 1, #outputEntries)
    return outputEntries[targetRank].index
end

function mapEditor:cycleIntersectionInput(intersection)
    if not intersection then
        return false
    end
    if intersection.unsupported then
        self:showStatus("Junctions currently support up to five inputs and five outputs.")
        return false
    end

    local inputCount = #(intersection.inputRouteIds or {})
    if inputCount <= 1 then
        intersection.activeInputIndex = 1
        self:syncIntersectionOutputToControl(intersection)
        return false
    end

    if intersection.controlType == "relay" or intersection.controlType == "crossbar" then
        intersection.activeInputIndex = self:getNextIntersectionInputIndex(intersection)
    else
        intersection.activeInputIndex = (intersection.activeInputIndex or 1) + 1
        if intersection.activeInputIndex > inputCount then
            intersection.activeInputIndex = 1
        end
    end

    self:syncIntersectionOutputToControl(intersection)
    self:refreshValidation(self.currentMapName)
    self:showStatus("Junction start switched to " .. intersection.activeInputIndex .. ".")
    return true
end

function mapEditor:cycleIntersectionOutput(intersection, direction)
    if intersection.controlType == "relay" or intersection.controlType == "crossbar" then
        self:showStatus("This dial couples start and end together.")
        return
    end

    if (intersection.outputEndpointIds and #intersection.outputEndpointIds or 0) <= 1 then
        return
    end

    local outputCount = #intersection.outputEndpointIds
    intersection.activeOutputIndex = intersection.activeOutputIndex + direction
    if intersection.activeOutputIndex < 1 then
        intersection.activeOutputIndex = outputCount
    elseif intersection.activeOutputIndex > outputCount then
        intersection.activeOutputIndex = 1
    end

    self:refreshValidation(self.currentMapName)
    self:showStatus("Junction end switched to " .. intersection.activeOutputIndex .. ".")
end

function mapEditor:cycleIntersectionPassCount(intersection, direction)
    if intersection.controlType ~= "trip" then
        return false
    end

    local nextPassCount = (intersection.passCount or DEFAULT_CONTROL_CONFIGS.trip.passCount) + direction
    if nextPassCount < 1 then
        nextPassCount = MAX_TRIP_PASS_COUNT
    elseif nextPassCount > MAX_TRIP_PASS_COUNT then
        nextPassCount = 1
    end

    intersection.passCount = nextPassCount
    self:showStatus("Trip switch now waits for " .. nextPassCount .. " train(s).")
    self:refreshValidation(self.currentMapName)
    return true
end

function mapEditor:toggleMagnetColor(route, magnetKind, colorId)
    if magnetKind == "start" then
        self:showStatus("Starts use a single fixed color.")
        return
    end

    local endpoint = magnetKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route)
    if not endpoint then
        return
    end
    local lookup = endpoint.colors
    if lookup[colorId] then
        if countLookupEntries(lookup) <= 1 then
            self:showStatus("Each endpoint needs at least one allowed color.")
            return
        end
        lookup[colorId] = nil
    else
        lookup[colorId] = true
    end

    self:showStatus((magnetKind == "start" and "Start" or "End") .. " colors updated.")
end

function mapEditor:splitEndpointColor(route, magnetKind, colorId, startMouseX, startMouseY)
    if magnetKind ~= "end" then
        return false
    end

    local endpoint = magnetKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route)
    if not endpoint or not endpoint.colors[colorId] or countLookupEntries(endpoint.colors) <= 1 then
        self:showStatus("That color cannot be split from this endpoint.")
        return false
    end

    local matchingRoutes = {}
    for _, candidateRoute in ipairs(self.routes) do
        if candidateRoute.endEndpointId == endpoint.id and candidateRoute.colorId == colorId then
            matchingRoutes[#matchingRoutes + 1] = candidateRoute
        end
    end

    if #matchingRoutes == 0 then
        self:showStatus("That color is not present on this end.")
        return false
    end

    endpoint.colors[colorId] = nil
    local newEndpoint = self:createEndpoint(
        endpoint.kind,
        endpoint.x + (magnetKind == "start" and 38 or 48),
        endpoint.y + 18,
        { colorId }
    )

    for _, matchingRoute in ipairs(matchingRoutes) do
        if magnetKind == "start" then
            matchingRoute.startEndpointId = newEndpoint.id
        else
            matchingRoute.endEndpointId = newEndpoint.id
        end
        self:updateRouteEndpointPoint(matchingRoute, magnetKind)
    end

    local activeRoute = route.colorId == colorId and route or matchingRoutes[1]
    self.selectedRouteId = activeRoute.id
    self.selectedPointIndex = magnetKind == "start" and 1 or #activeRoute.points
    self.drag = {
        kind = "point",
        routeId = activeRoute.id,
        pointIndex = self.selectedPointIndex,
        startMouseX = startMouseX or newEndpoint.x,
        startMouseY = startMouseY or newEndpoint.y,
        moved = true,
        isMagnet = true,
        magnetKind = magnetKind,
    }
    self:closeColorPicker()
    self:rebuildIntersections()
    self:showStatus("Color split into a new " .. (endpoint.kind == "input" and "start" or "end") .. " endpoint.")
    return true
end

function mapEditor:splitSharedJunctionColor(intersection, colorId, startMouseX, startMouseY)
    local group = self:getSharedPointGroupForIntersection(intersection)
    if not group or not group.colorLookup[colorId] or #group.colorIds <= 1 then
        self:showStatus("That color cannot be split from this merger lane.")
        return false
    end

    local matchingMembers = {}
    for _, member in ipairs(group.members) do
        if member.route.colorId == colorId then
            matchingMembers[#matchingMembers + 1] = member
        end
    end

    if #matchingMembers == 0 then
        self:showStatus("That color is not present on this merger lane.")
        return false
    end

    local newSharedPointId = self.nextSharedPointId
    self.nextSharedPointId = self.nextSharedPointId + 1

    for _, member in ipairs(matchingMembers) do
        member.point.sharedPointId = newSharedPointId
    end

    local selectedMember = matchingMembers[1]
    self.selectedRouteId = selectedMember.route.id
    self.selectedPointIndex = selectedMember.pointIndex
    self.drag = {
        kind = "point",
        routeId = selectedMember.route.id,
        pointIndex = selectedMember.pointIndex,
        startMouseX = startMouseX or intersection.x,
        startMouseY = startMouseY or intersection.y,
        moved = true,
        isMagnet = false,
        magnetKind = nil,
        splitOriginSharedPointId = group.sharedPointId,
        pickupMode = true,
        awaitingPickupRelease = true,
    }
    self:closeColorPicker()
    self:showStatus("Drag to split that color out of the merger lane.")
    return true
end

function mapEditor:mergeEndpointInto(route, magnetKind, targetEndpoint)
    if magnetKind == "start" then
        return false
    end

    local currentEndpoint = magnetKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route)
    if not currentEndpoint or not targetEndpoint or currentEndpoint.id == targetEndpoint.id or currentEndpoint.kind ~= targetEndpoint.kind then
        return false
    end

    for colorId, enabled in pairs(currentEndpoint.colors or {}) do
        if enabled then
            targetEndpoint.colors[colorId] = true
        end
    end

    if magnetKind == "start" then
        route.startEndpointId = targetEndpoint.id
    else
        route.endEndpointId = targetEndpoint.id
    end
    self:updateRouteEndpointPoint(route, magnetKind)
    self:removeEndpointIfUnused(currentEndpoint.id)
    self:rebuildIntersections()
    self:showStatus(currentEndpoint.kind == "input" and "Starts merged." or "Ends merged.")
    return true
end

function mapEditor:getActiveTextFieldValue(kind, targetId, fieldName, fallback)
    local field = self.activeTextField
    if field
        and field.kind == kind
        and field.targetId == targetId
        and field.fieldName == fieldName then
        return field.buffer
    end
    return fallback
end

function mapEditor:openTextField(kind, targetId, fieldName, buffer, valueType)
    self.activeTextField = {
        kind = kind,
        targetId = targetId,
        fieldName = fieldName,
        buffer = buffer or "",
        valueType = valueType,
    }
end

function mapEditor:cancelTextField()
    self.activeTextField = nil
end

function mapEditor:commitTextField()
    local field = self.activeTextField
    if not field then
        return false
    end

    local target = nil
    if field.kind == "map" then
        target = self
    elseif field.kind == "train" then
        target = self:getTrainById(field.targetId)
    end

    if not target then
        self.activeTextField = nil
        return false
    end

    local rawValue = field.buffer or ""
    local trimmedValue = rawValue:gsub("^%s+", ""):gsub("%s+$", "")
    local changed = false

    if field.kind == "map" and field.fieldName == "gridStep" then
        local numericValue = tonumber(trimmedValue)
        self.activeTextField = nil
        if numericValue then
            self.gridStep = sanitizeGridStep(numericValue)
            self:notifyPreferencesChanged()
            self:showStatus(string.format("Grid step set to %d.", self.gridStep))
            return true
        end
        return false
    end

    if trimmedValue == "" then
        if field.valueType == "optional_float" then
            target[field.fieldName] = nil
            changed = true
        end
    else
        local numericValue = tonumber(trimmedValue)
        if numericValue then
            if field.valueType == "int" then
                numericValue = math.max(1, math.floor(numericValue))
            else
                numericValue = math.max(0, numericValue)
            end
            target[field.fieldName] = numericValue
            changed = true
        end
    end

    if field.kind == "train" and target.deadline ~= nil and target.deadline < target.spawnTime then
        target.deadline = target.spawnTime
    end

    self.activeTextField = nil

    if changed then
        self:refreshValidation()
        self:showStatus("Sequencer updated.")
    end

    return changed
end

function mapEditor:appendTextFieldInput(text)
    local field = self.activeTextField
    if not field then
        return
    end

    local filtered = {}
    for index = 1, #text do
        local character = text:sub(index, index)
        if character:match("%d") then
            filtered[#filtered + 1] = character
        elseif character == "." and field.valueType ~= "int" and not field.buffer:find("%.", 1, true) then
            filtered[#filtered + 1] = character
        end
    end

    if #filtered > 0 then
        field.buffer = field.buffer .. table.concat(filtered)
    end
end

function mapEditor:handleColorPickerClick(x, y, button)
    local layout = self:getColorPickerLayout()
    if not layout then
        return false
    end

    if layout.kind == "junction_radial" then
        local rawX = x
        local rawY = y
        x, y = self:screenToJunctionPickerSpace(x, y)
        local intersection = nil
        local route = nil
        if self.colorPicker.mode == "junction" then
            intersection = self:getIntersectionById(self.colorPicker.intersectionId)
            if not intersection then
                self:closeColorPicker()
                return true
            end
        elseif self.colorPicker.mode == "route_end" then
            route = self:getRouteById(self.colorPicker.routeId)
            if not route then
                self:closeColorPicker()
                return true
            end
        end

        local insideRoot = not layout.branch
            and distanceSquared(x, y, layout.root.x, layout.root.y) <= layout.root.radius * layout.root.radius
        local insideSubmenu = layout.submenu
            and distanceSquared(x, y, layout.submenu.x, layout.submenu.y) <= layout.submenu.radius * layout.submenu.radius

        if not insideRoot and not insideSubmenu then
            self:closeColorPicker()
            return false
        end

        if insideRoot and not layout.branch then
            local selectedBranch = self:getJunctionPickerRootHover(x, y)
            if selectedBranch == "disconnect" and #self:getColorPickerOptions() == 0 then
                selectedBranch = nil
            end
            if selectedBranch then
                self.colorPicker.branch = selectedBranch
                self.colorPicker.hoverBranch = nil
                self.colorPicker.hoverOptionIndex = nil
                self:restartJunctionPickerPopup(rawX, rawY)
            end
            return true
        end

        if layout.submenu then
            local hitEntry = self:getJunctionPickerOptionHit(layout.submenu, x, y)
            if hitEntry then
                if layout.submenu.branch == "disconnect" then
                    if self.colorPicker.mode == "junction" then
                        local mapX, mapY = self:screenToMap(rawX, rawY)
                        self:splitSharedJunctionColor(intersection, hitEntry.option.id, mapX, mapY)
                    elseif self.colorPicker.mode == "route_end" then
                        local mapX, mapY = self:screenToMap(rawX, rawY)
                        self:splitEndpointColor(route, "end", hitEntry.option.id, mapX, mapY)
                    end
                else
                    self:setIntersectionControlType(intersection, hitEntry.option.controlType)
                    self:closeColorPicker()
                end
                return true
            end
        end

        self:updateJunctionPickerHover(rawX, rawY)
        return true
    end

    if not pointInRect(x, y, layout.rect) then
        self:closeColorPicker()
        return false
    end

    for _, swatch in ipairs(layout.swatches) do
        if pointInRect(x, y, swatch.rect) then
            if self.colorPicker.mode == "sequencer" then
                local train = self:getTrainById(self.colorPicker.trainId)
                if train then
                    train[self.colorPicker.fieldName] = swatch.option.id
                    self:refreshValidation()
                    self:showStatus("Sequencer updated.")
                end
                self:closeColorPicker()
                return true
            end

            if self.colorPicker.mode == "junction" then
                local intersection = self:getIntersectionById(self.colorPicker.intersectionId)
                if not intersection then
                    self:closeColorPicker()
                    return true
                end

                local group = self:getSharedPointGroupForIntersection(intersection)
                if not group or not group.colorLookup[swatch.option.id] then
                    self:showStatus("Choose one of the colors already merged into this lane.")
                    return true
                end

                local mapX, mapY = self:screenToMap(x, y)
                self:splitSharedJunctionColor(intersection, swatch.option.id, mapX, mapY)
                return true
            end

            local route = self:getSelectedRoute()
            if not route or route.id ~= self.colorPicker.routeId then
                self:closeColorPicker()
                return true
            end

            local endpoint = self.colorPicker.magnetKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route)
            local lookup = endpoint and endpoint.colors or {}
            if not lookup[swatch.option.id] then
                self:showStatus("Choose one of the colors already merged into this endpoint.")
                return true
            end
            local mapX, mapY = self:screenToMap(x, y)
            self:splitEndpointColor(route, self.colorPicker.magnetKind, swatch.option.id, mapX, mapY)
            return true
        end
    end

    return true
end

function mapEditor:getTextFieldRect(x, y, width)
    return {
        x = x,
        y = y,
        w = width,
        h = 26,
    }
end

function mapEditor:getSequencerSummaryRects(rowRect)
    local x = rowRect.x + 8
    local y = rowRect.y + 8
    local gap = 4

    local startRect = { x = x, y = y, w = 34, h = 18 }
    local nameRect = { x = startRect.x + startRect.w + gap, y = y, w = 60, h = 18 }
    local lineRect = { x = nameRect.x + nameRect.w + gap, y = y, w = 16, h = 16 }
    local goalRect = { x = lineRect.x + lineRect.w + gap, y = y, w = 16, h = 16 }
    local wagonsRect = { x = goalRect.x + goalRect.w + gap, y = y, w = 30, h = 18 }
    local removeRect = { x = rowRect.x + rowRect.w - 20, y = rowRect.y + 8, w = 16, h = 16 }
    local deadlineRect = {
        x = wagonsRect.x + wagonsRect.w + gap,
        y = y,
        w = math.max(42, removeRect.x - gap - (wagonsRect.x + wagonsRect.w + gap)),
        h = 18,
    }

    return {
        start = startRect,
        name = nameRect,
        lineChip = lineRect,
        goalChip = goalRect,
        wagons = wagonsRect,
        deadline = deadlineRect,
        remove = removeRect,
    }
end

function mapEditor:getSequencerRowControlRects(rowRect)
    return {
        summary = self:getSequencerSummaryRects(rowRect),
    }
end

function mapEditor:handleSequencerClick(x, y, button)
    local layout = self:getSequencerLayout()
    local deadlineRect = layout.mapDeadlineRect

    if self.colorPicker then
        self:closeColorPicker()
    end

    if pointInRect(x, y, layout.backRect) then
        self:commitTextField()
        self.sidePanelMode = "default"
        self:showStatus("Returned to the map editor pane.")
        return true
    end

    if pointInRect(x, y, layout.addRect) then
        self:commitTextField()
        self:addTrain()
        return true
    end

    if pointInRect(x, y, deadlineRect) then
        self:commitTextField()
        self:openTextField("map", "map", "timeLimit", self.timeLimit and tostring(self.timeLimit) or "", "optional_float")
        return true
    end

    if layout.scrollbar and pointInRect(x, y, layout.scrollbar.thumb) then
        self:commitTextField()
        self.sequencerScrollDrag = {
            offsetY = y - layout.scrollbar.thumb.y,
            track = layout.scrollbar.track,
            thumbHeight = layout.scrollbar.thumb.h,
            maxScroll = layout.scrollbar.maxScroll,
        }
        return true
    end

    if layout.scrollbar and pointInRect(x, y, layout.scrollbar.track) then
        self:commitTextField()
        local thumbTravel = math.max(1, layout.scrollbar.track.h - layout.scrollbar.thumb.h)
        local targetY = clamp(y - layout.scrollbar.thumb.h * 0.5, layout.scrollbar.track.y, layout.scrollbar.track.y + thumbTravel)
        self.sequencerScroll = ((targetY - layout.scrollbar.track.y) / thumbTravel) * layout.scrollbar.maxScroll
        return true
    end

    for _, row in ipairs(layout.rows) do
        local train = row.entry.train
        local controls = self:getSequencerRowControlRects(row.rect)
        if pointInRect(x, y, controls.summary.remove) then
            self:commitTextField()
            self:removeTrainByIndex(row.entry.trainIndex)
            return true
        end

        if pointInRect(x, y, controls.summary.lineChip) then
            self:commitTextField()
            self:openSequencerColorPicker(train.id, "lineColor", controls.summary.lineChip.x, controls.summary.lineChip.y)
            return true
        end

        if pointInRect(x, y, controls.summary.goalChip) then
            self:commitTextField()
            self:openSequencerColorPicker(train.id, "trainColor", controls.summary.goalChip.x, controls.summary.goalChip.y)
            return true
        end

        if pointInRect(x, y, controls.summary.start) then
            self:commitTextField()
            self:openTextField("train", train.id, "spawnTime", tostring(train.spawnTime or 0), "float")
            return true
        end

        if pointInRect(x, y, controls.summary.wagons) then
            self:commitTextField()
            self:openTextField("train", train.id, "wagonCount", tostring(train.wagonCount or DEFAULT_TRAIN_WAGONS), "int")
            return true
        end

        if pointInRect(x, y, controls.summary.deadline) then
            self:commitTextField()
            self:openTextField("train", train.id, "deadline", train.deadline and tostring(train.deadline) or "", "optional_float")
            return true
        end
    end

    self:commitTextField()
    return pointInRect(x, y, self.sidePanel)
end

function mapEditor:splitRouteSegmentStyle(route, segmentIndex)
    local segmentRoadTypes = self:ensureRouteSegmentRoadTypes(route)
    local duplicatedRoadType = segmentRoadTypes[segmentIndex] or DEFAULT_ROAD_TYPE
    table.insert(segmentRoadTypes, segmentIndex + 1, duplicatedRoadType)
end

function mapEditor:mergeRouteSegmentStyle(route, selectedPointIndex)
    local segmentRoadTypes = self:ensureRouteSegmentRoadTypes(route)
    table.remove(segmentRoadTypes, selectedPointIndex)
end

function mapEditor:setRouteSegmentRoadType(route, segmentIndex, roadType)
    if not route or not segmentIndex then
        return
    end

    local normalizedRoadType = roadTypes.normalizeRoadType(roadType)
    local segmentRoadTypes = self:ensureRouteSegmentRoadTypes(route)
    if not segmentRoadTypes[segmentIndex] then
        return
    end

    segmentRoadTypes[segmentIndex] = normalizedRoadType
    self:refreshValidation()
    self:showStatus("Segment road type set to " .. roadTypes.getConfig(normalizedRoadType).label .. ".")
end

function mapEditor:handleRouteTypePickerClick(x, y)
    local layout = self:getRouteTypePickerLayout()
    if not layout then
        return false
    end

    if not pointInRect(x, y, layout.rect) then
        self:closeRouteTypePicker()
        return false
    end

    local route = self:getRouteById(self.routeTypePicker.routeId)
    if not route then
        self:closeRouteTypePicker()
        return true
    end

    for _, optionEntry in ipairs(layout.options) do
        if pointInRect(x, y, optionEntry.rect) then
            self:setRouteSegmentRoadType(route, self.routeTypePicker.segmentIndex, optionEntry.option.id)
            self:closeRouteTypePicker()
            return true
        end
    end

    return true
end

function mapEditor:handleDialogClick(x, y)
    if not self.dialog then
        return false
    end

    local rect = self:getDialogRect()
    if not pointInRect(x, y, rect) then
        self:closeDialog()
        return true
    end

    if self.dialog.type == "open" then
        local layout = self:getOpenDialogListLayout()
        if layout.scrollbar and pointInRect(x, y, layout.scrollbar.track) then
            local thumbTravel = math.max(1, layout.scrollbar.track.h - layout.scrollbar.thumb.h)
            local thumbY = clamp(y - layout.scrollbar.thumb.h * 0.5, layout.scrollbar.track.y, layout.scrollbar.track.y + thumbTravel)
            self.dialog.scroll = ((thumbY - layout.scrollbar.track.y) / thumbTravel) * layout.scrollbar.maxScroll
            self.dialog.scroll = math.floor(self.dialog.scroll + 0.5)
            return true
        end

        for _, row in ipairs(layout.rows) do
            if pointInRect(x, y, row.rect) then
                self:openDialogMap(row.map)
                self:closeDialog()
                return true
            end
        end
    elseif self.dialog.type == "confirm_reset" then
        local buttons = self:getConfirmResetDialogButtons()
        if pointInRect(x, y, buttons.confirm) then
            self:requestOpenBlankMap()
            return true
        end
        if pointInRect(x, y, buttons.cancel) then
            self:closeDialog()
            self:showStatus("Reset cancelled.")
            return true
        end
    end

    return true
end

function mapEditor:keypressed(key)
    if key == "escape" then
        if self.dialog then
            local dialogType = self.dialog.type
            self:closeDialog()
            self:showStatus(dialogType == "confirm_reset" and "Reset cancelled." or "Dialog closed.")
            return true
        end
        if self.activeTextField then
            self:cancelTextField()
            self:showStatus("Text edit cancelled.")
            return true
        end
        if self.colorPicker then
            self:closeColorPicker()
            self:showStatus("Color picker closed.")
            return true
        end
        if self.routeTypePicker then
            self:closeRouteTypePicker()
            self:showStatus("Road type picker closed.")
            return true
        end
        if self.sidePanelMode == "sequencer" then
            self.sidePanelMode = "default"
            self:showStatus("Returned to the map editor pane.")
            return true
        end
        return false
    end

    if self.dialog then
        if self.dialog.type == "save" then
            if key == "backspace" then
                if #self.dialog.input > 0 then
                    self.dialog.input = string.sub(self.dialog.input, 1, #self.dialog.input - 1)
                end
                return true
            end

            if key == "return" or key == "kpenter" then
                local ok, saveError = self:saveMap(self.dialog.input)
                if not ok then
                    self:showStatus(saveError)
                end
                return true
            end
        end

        if self.dialog.type == "open" then
            if key == "up" then
                self:scrollOpenDialog(-1)
                return true
            end
            if key == "down" then
                self:scrollOpenDialog(1)
                return true
            end
            if key == "pageup" then
                local layout = self:getOpenDialogListLayout()
                self:scrollOpenDialog(-layout.visibleRows)
                return true
            end
            if key == "pagedown" then
                local layout = self:getOpenDialogListLayout()
                self:scrollOpenDialog(layout.visibleRows)
                return true
            end
            if key == "home" then
                self.dialog.scroll = 0
                return true
            end
            if key == "end" then
                local layout = self:getOpenDialogListLayout()
                self.dialog.scroll = layout.maxScroll
                return true
            end
            if key == "return" or key == "kpenter" then
                local layout = self:getOpenDialogListLayout()
                if layout.rows[1] then
                    self:openDialogMap(layout.rows[1].map)
                    self:closeDialog()
                end
                return true
            end
        end

        if self.dialog.type == "confirm_reset" then
            if key == "return" or key == "kpenter" or key == "y" then
                self:requestOpenBlankMap()
                return true
            end
            if key == "n" then
                self:closeDialog()
                self:showStatus("Reset cancelled.")
                return true
            end
        end

        return true
    end

    if self.activeTextField then
        if key == "backspace" then
            if #self.activeTextField.buffer > 0 then
                self.activeTextField.buffer = string.sub(self.activeTextField.buffer, 1, #self.activeTextField.buffer - 1)
            end
            return true
        end

        if key == "return" or key == "kpenter" then
            self:commitTextField()
            return true
        end
    end

    if key == "delete" or key == "backspace" then
        self:deleteSelection()
        return true
    end

    if key == "g" then
        self.gridVisible = not self.gridVisible
        self:notifyPreferencesChanged()
        self:showStatus(self.gridVisible and "Grid shown." or "Grid hidden.")
        return true
    end

    if key == "f" then
        self:resetCameraToFit()
        self:showStatus("Camera reset to fit.")
        return true
    end

    if key == "s" then
        self:commitTextField()
        self:openSaveDialog()
        return true
    end

    if key == "o" then
        self:commitTextField()
        self:openOpenDialog()
        return true
    end

    if key == "p" then
        self:commitTextField()
        self:requestPlaytestFromSavedMap()
        return true
    end

    if key == "u" then
        self:commitTextField()
        self:requestUploadFromSavedMap()
        return true
    end

    if key == "c" then
        self:commitTextField()
        self.sidePanelMode = self.sidePanelMode == "sequencer" and "default" or "sequencer"
        self:showStatus(self.sidePanelMode == "sequencer" and "Sequencer opened." or "Returned to the map editor pane.")
        return true
    end

    if key == "r" then
        self:commitTextField()
        self:openResetDialog()
        return true
    end

    if key == "f3" then
        self.hitboxOverlayVisible = not self.hitboxOverlayVisible
        self:showStatus(self.hitboxOverlayVisible and "Hitbox overlay shown." or "Hitbox overlay hidden.")
        return true
    end

    return false
end

function mapEditor:textinput(text)
    if self.dialog and self.dialog.type == "save" then
        self.dialog.input = self.dialog.input .. text
    elseif self.activeTextField then
        self:appendTextFieldInput(text)
    end
end

function mapEditor:mousepressed(screenX, screenY, button)
    if button ~= 1 and button ~= 2 and button ~= 3 then
        return false
    end

    if self.dialog and self:handleDialogClick(screenX, screenY) then
        return true
    end

    if self.activeTextField and not pointInRect(screenX, screenY, self.sidePanel) then
        self:commitTextField()
    end

    if button == 1 and self.drag and self.drag.pickupMode then
        return true
    end

    if self.colorPicker and self:handleColorPickerClick(screenX, screenY, button) then
        return true
    end

    if self.routeTypePicker and self:handleRouteTypePickerClick(screenX, screenY) then
        return true
    end

    if pointInRect(screenX, screenY, self.sidePanel) then
        if self.sidePanelMode == "sequencer" then
            return self:handleSequencerClick(screenX, screenY, button)
        end

        if self:handleEditorDrawerClick(screenX, screenY) then
            return true
        end

        if self:handleValidationListClick(screenX, screenY) then
            return true
        end

        if pointInRect(screenX, screenY, self:getSaveButtonRect()) then
            self:openSaveDialog()
            return true
        end

        if pointInRect(screenX, screenY, self:getOpenButtonRect()) then
            self:openOpenDialog()
            return true
        end

        if pointInRect(screenX, screenY, self:getPlayTestButtonRect()) then
            self:requestPlaytestFromSavedMap()
            return true
        end

        if pointInRect(screenX, screenY, self:getUploadMapButtonRect()) then
            self:requestUploadFromSavedMap()
            return true
        end

        if pointInRect(screenX, screenY, self:getSequencerButtonRect()) then
            self.sidePanelMode = "sequencer"
            self:showStatus("Sequencer opened.")
            return true
        end

        if pointInRect(screenX, screenY, self:getResetButtonRect()) then
            self:openResetDialog()
            return true
        end

        if pointInRect(screenX, screenY, self:getHitboxToggleRect()) then
            self.hitboxOverlayVisible = not self.hitboxOverlayVisible
            self:showStatus(self.hitboxOverlayVisible and "Hitbox overlay shown." or "Hitbox overlay hidden.")
            return true
        end

        if pointInRect(screenX, screenY, self:getOpenUserMapsButtonRect()) then
            self:openUserMapsFolder()
            return true
        end

        return true
    end

    if button == 3 then
        self.panDrag = {
            startScreenX = screenX,
            startScreenY = screenY,
            startCameraX = self.camera.x,
            startCameraY = self.camera.y,
        }
        return true
    end

    local x, y = self:screenToMap(screenX, screenY)

    if button == 2 then
        local route, pointIndex, magnetKind = self:findPointHit(x, y)
        if route and magnetKind then
            self.selectedRouteId = route.id
            self.selectedPointIndex = pointIndex
            if magnetKind == "end" then
                self:openColorPicker(route, magnetKind)
                self:updateJunctionPickerHover(screenX, screenY)
                self:showStatus("End color menu opened.")
            else
                self:closeColorPicker()
            end
            return true
        end

        local outputSelectorIntersection = self:findIntersectionOutputSelectorHit(x, y)
        if outputSelectorIntersection then
            self:cycleIntersectionOutput(outputSelectorIntersection, -1)
            return true
        end

        local hitIntersection = self:findIntersectionHit(x, y)
        if hitIntersection then
            self:openJunctionPicker(hitIntersection, screenX, screenY)
            self:updateJunctionPickerHover(screenX, screenY)
            return true
        end

        local segmentHit = self:findSegmentHit(x, y)
        if segmentHit and segmentHit.route then
            self.selectedRouteId = segmentHit.route.id
            self.selectedPointIndex = nil
            self:openRouteTypePicker(segmentHit.route, segmentHit.segmentIndex, screenX, screenY)
            self:showStatus("Road type picker opened.")
            return true
        end

        return false
    end

    local route, pointIndex, magnetKind = self:findPointHit(x, y)
    if route then
        self.selectedRouteId = route.id
        self.selectedPointIndex = pointIndex
        self.drag = {
            kind = "point",
            routeId = route.id,
            pointIndex = pointIndex,
            startMouseX = x,
            startMouseY = y,
            moved = false,
            isMagnet = magnetKind ~= nil,
            magnetKind = magnetKind,
        }
        return true
    end

    local outputSelectorIntersection = self:findIntersectionOutputSelectorHit(x, y)
    if outputSelectorIntersection then
        self:cycleIntersectionOutput(outputSelectorIntersection, 1)
        return true
    end

    local hitIntersection = self:findIntersectionHit(x, y)
    if hitIntersection then
        self.drag = {
            kind = "intersection",
            intersectionId = hitIntersection.id,
            intersectionSnapshot = {
                id = hitIntersection.id,
                x = hitIntersection.x,
                y = hitIntersection.y,
                routeIds = copyArray(hitIntersection.routeIds),
            },
            sharedPointId = nil,
            routeId = nil,
            pointIndex = nil,
            startMouseX = x,
            startMouseY = y,
            moved = false,
            isMagnet = false,
            magnetKind = nil,
        }
        self:closeColorPicker()
        self:closeRouteTypePicker()
        return true
    end

    local segmentHit = self:findSegmentHit(x, y)
    if segmentHit then
        table.insert(segmentHit.route.points, segmentHit.insertIndex, segmentHit.point)
        self:splitRouteSegmentStyle(segmentHit.route, segmentHit.segmentIndex)
        self.selectedRouteId = segmentHit.route.id
        self.selectedPointIndex = segmentHit.insertIndex
        self.drag = {
            kind = "point",
            routeId = segmentHit.route.id,
            pointIndex = segmentHit.insertIndex,
            startMouseX = x,
            startMouseY = y,
            moved = true,
            isMagnet = false,
            magnetKind = nil,
        }
        self:closeColorPicker()
        self:closeRouteTypePicker()
        self:rebuildIntersections()
        self:showStatus("Bend point added.")
        return true
    end

    if pointInRect(x, y, self.canvas) then
        self:beginRoute(x, y)
        return true
    end

    self:closeColorPicker()
    self:closeRouteTypePicker()

    if pointInRect(x, y, self.canvas) then
        self:clearSelection()
        return true
    end

    return false
end

function mapEditor:isCameraScrollLocked()
    if self.colorPicker and self.colorPicker.mode == "junction" then
        return true
    end

    if self.drag and self.drag.kind == "intersection" then
        return true
    end

    return false
end

function mapEditor:wheelmoved(screenX, screenY, _, y)
    if self.dialog and self.dialog.type == "open" then
        if y > 0 then
            self:scrollOpenDialog(-1)
            return true
        end
        if y < 0 then
            self:scrollOpenDialog(1)
            return true
        end
        return false
    end

    if self:isCameraScrollLocked() then
        return true
    end

    if pointInRect(screenX, screenY, self.sidePanel) then
        if self.sidePanelMode == "default" then
            if y > 0 then
                return self:scrollValidationList(-40)
            end
            if y < 0 then
                return self:scrollValidationList(40)
            end
            return false
        end

        if self.sidePanelMode == "sequencer" then
            local layout = self:getSequencerLayout()
            if layout.maxScroll <= 0 then
                return false
            end

            if y > 0 then
                self.sequencerScroll = math.max(0, (self.sequencerScroll or 0) - 40)
            elseif y < 0 then
                self.sequencerScroll = math.min(layout.maxScroll, (self.sequencerScroll or 0) + 40)
            end
            return true
        end
    end

    self:zoomAroundScreenPoint(screenX, screenY, y)
    return true
end

function mapEditor:mousemoved(screenX, screenY, deltaX, deltaY)
    if self.validationScrollDrag then
        local drag = self.validationScrollDrag
        local thumbTravel = math.max(1, drag.track.h - drag.thumbHeight)
        local thumbY = clamp(screenY - drag.offsetY, drag.track.y, drag.track.y + thumbTravel)
        self.validationScroll = ((thumbY - drag.track.y) / thumbTravel) * drag.maxScroll
        return true
    end
    if self.sequencerScrollDrag then
        local drag = self.sequencerScrollDrag
        local thumbTravel = math.max(1, drag.track.h - drag.thumbHeight)
        local thumbY = clamp(screenY - drag.offsetY, drag.track.y, drag.track.y + thumbTravel)
        self.sequencerScroll = ((thumbY - drag.track.y) / thumbTravel) * drag.maxScroll
        return true
    end

    if self.panDrag and not love.mouse.isDown(3) then
        self.panDrag = nil
    end

    if not self.panDrag
        and love.mouse.isDown(3)
        and not pointInRect(screenX, screenY, self.sidePanel)
        and not self.dialog
        and not self.colorPicker
        and not self.routeTypePicker then
        self.panDrag = {
            startScreenX = screenX - (deltaX or 0),
            startScreenY = screenY - (deltaY or 0),
            startCameraX = self.camera.x,
            startCameraY = self.camera.y,
        }
    end

    if self.panDrag then
        self.camera.x = self.panDrag.startCameraX - ((screenX - self.panDrag.startScreenX) / self.camera.zoom)
        self.camera.y = self.panDrag.startCameraY - ((screenY - self.panDrag.startScreenY) / self.camera.zoom)
        self:clampCamera()
        return true
    end

    if self.colorPicker and (self.colorPicker.mode == "junction" or self.colorPicker.mode == "route_end") then
        self:updateJunctionPickerHover(screenX, screenY)
    end

    if not self.drag then
        return false
    end

    local x, y = self:screenToMap(screenX, screenY)
    self:updateDraggedPoint(x, y)
    return true
end

function mapEditor:mousereleased(screenX, screenY, button)
    if button == 3 and self.panDrag then
        self.panDrag = nil
        return true
    end

    if button ~= 1 then
        return false
    end

    if self.validationScrollDrag then
        self.validationScrollDrag = nil
        return true
    end

    if self.sequencerScrollDrag then
        self.sequencerScrollDrag = nil
        return true
    end

    if not self.drag then
        return false
    end

    if button == 1 and self.drag.pickupMode and self.drag.awaitingPickupRelease then
        self.drag.awaitingPickupRelease = false
        return true
    end

    local x, y = self:screenToMap(screenX, screenY)
    local route = self:getSelectedRoute()
    if self.drag.kind == "new_route" and route then
        local startPoint = route.points[1]
        local endPoint = route.points[#route.points]
        if distanceSquared(startPoint.x, startPoint.y, endPoint.x, endPoint.y) < 40 * 40 then
            for routeIndex, candidate in ipairs(self.routes) do
                if candidate.id == route.id then
                    table.remove(self.routes, routeIndex)
                    break
                end
            end
            self:clearSelection()
            self:showStatus("Route discarded because it was too short.")
        else
            self:showStatus("Route created. Drag any segment to add a bend point.")
        end
    elseif route and self.drag.kind == "point" and self.drag.isMagnet and self.drag.magnetKind == "end" then
        local currentEndpoint = self.drag.magnetKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route)
        local target = currentEndpoint and self:findEndpointAt(x, y, currentEndpoint.kind, currentEndpoint.id) or nil
        if target then
            self:mergeEndpointInto(route, self.drag.magnetKind, target)
        end
    elseif route and self.drag.kind == "point" and self.drag.moved then
        local targetRoute, targetPointIndex, targetPoint = self:findBendPointAt(x, y, route.id, self.drag.pointIndex)
        if targetRoute and targetPointIndex then
            local blockedByOriginalGroup = self.drag.splitOriginSharedPointId
                and targetPoint
                and targetPoint.sharedPointId == self.drag.splitOriginSharedPointId
            if not blockedByOriginalGroup then
                self:mergeBendPointInto(route, self.drag.pointIndex, targetRoute, targetPointIndex)
            end
        end
    end

    if self.drag.kind == "intersection" then
        local activeIntersection = self:getIntersectionById(self.drag.intersectionId)
        local wasMoved = self.drag.moved
        self.drag = nil

        if wasMoved then
            self:showStatus("Junction moved.")
            self:rebuildIntersections()
            return true
        end

        self:cycleIntersectionInput(activeIntersection)
        return true
    end

    self.drag = nil
    self:rebuildIntersections()
    return true
end

end
