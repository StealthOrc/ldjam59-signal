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

function mapEditor:findIntersectionHit(x, y)
    for _, intersection in ipairs(self.intersections) do
        local radius = self:getIntersectionHitRadius(intersection)
        if distanceSquared(x, y, intersection.x, intersection.y) <= radius * radius then
            return intersection
        end
    end

    return nil
end

function mapEditor:getMagnetHitRadius()
    return MAGNET_HIT_RADIUS
end

function mapEditor:findPointHit(x, y)
    for routeIndex = #self.routes, 1, -1 do
        local route = self.routes[routeIndex]
        for pointIndex = #route.points, 1, -1 do
            local point = route.points[pointIndex]
            local isMagnet = pointIndex == 1 or pointIndex == #route.points
            local isSharedJunctionPoint = not isMagnet and point.sharedPointId and self:getSharedPointGroupForPoint(route, pointIndex)
            if not isSharedJunctionPoint then
                local magnetKind = nil
                if pointIndex == 1 then
                    magnetKind = "start"
                elseif pointIndex == #route.points then
                    magnetKind = "end"
                end

                local hit = false
                if isMagnet then
                    local radius = self:getMagnetHitRadius()
                    hit = distanceSquared(x, y, point.x, point.y) <= radius * radius
                else
                    local radius = self:getPointHitRadius()
                    hit = distanceSquared(x, y, point.x, point.y) <= radius * radius
                end

                if hit then
                    return route, pointIndex, magnetKind
                end
            end
        end
    end

    return nil, nil, nil
end

function mapEditor:findBendPointAt(x, y, excludeRouteId, excludePointIndex)
    local radius = MERGE_SNAP_RADIUS / math.max(self.camera.zoom, 0.0001)
    local radiusSquared = radius * radius
    for routeIndex = #self.routes, 1, -1 do
        local route = self.routes[routeIndex]
        for pointIndex = #route.points - 1, 2, -1 do
            local point = route.points[pointIndex]
            local isSharedJunctionPoint = point.sharedPointId and self:getSharedPointGroupForPoint(route, pointIndex)
            if not (route.id == excludeRouteId and pointIndex == excludePointIndex)
                and not isSharedJunctionPoint
                and distanceSquared(x, y, point.x, point.y) <= radiusSquared then
                return route, pointIndex, point
            end
        end
    end

    return nil, nil, nil
end

function mapEditor:getIntersectionById(intersectionId)
    for _, intersection in ipairs(self.intersections) do
        if intersection.id == intersectionId then
            return intersection
        end
    end
    return nil
end

function mapEditor:getSharedPointGroupForIntersection(intersection)
    if not intersection then
        return nil
    end

    local groups = {}
    for _, routeId in ipairs(intersection.routeIds or {}) do
        local route = self:getRouteById(routeId)
        if route then
            for pointIndex = 2, #route.points - 1 do
                local point = route.points[pointIndex]
                if point.sharedPointId and distanceSquared(point.x, point.y, intersection.x, intersection.y) <= INTERSECTION_SHARED_POINT_DISTANCE_SQUARED then
                    local group = groups[point.sharedPointId]
                    if not group then
                        group = {
                            sharedPointId = point.sharedPointId,
                            members = {},
                            colorLookup = {},
                            colorIds = {},
                        }
                        groups[point.sharedPointId] = group
                    end
                    group.members[#group.members + 1] = {
                        route = route,
                        pointIndex = pointIndex,
                        point = point,
                    }
                    if not group.colorLookup[route.colorId] then
                        group.colorLookup[route.colorId] = true
                        group.colorIds[#group.colorIds + 1] = route.colorId
                    end
                end
            end
        end
    end

    local bestGroup = nil
    for _, group in pairs(groups) do
        if not bestGroup
            or #group.members > #bestGroup.members
            or (#group.members == #bestGroup.members and #group.colorIds > #bestGroup.colorIds) then
            bestGroup = group
        end
    end

    return bestGroup
end

function mapEditor:getSharedPointGroupForPoint(route, pointIndex)
    local point = route and route.points and route.points[pointIndex] or nil
    if not point or not point.sharedPointId or pointIndex <= 1 or pointIndex >= #route.points then
        return nil
    end

    for _, intersection in ipairs(self.intersections) do
        if distanceSquared(point.x, point.y, intersection.x, intersection.y) <= INTERSECTION_SHARED_POINT_DISTANCE_SQUARED then
            local group = self:getSharedPointGroupForIntersection(intersection)
            if group and group.sharedPointId == point.sharedPointId then
                return group, intersection
            end
        end
    end

    return nil
end

function mapEditor:ensureSharedPointId(point)
    if not point.sharedPointId then
        point.sharedPointId = self.nextSharedPointId
        self.nextSharedPointId = self.nextSharedPointId + 1
    end
    return point.sharedPointId
end

function mapEditor:reassignSharedPointGroup(fromSharedPointId, toSharedPointId)
    if not fromSharedPointId or not toSharedPointId or fromSharedPointId == toSharedPointId then
        return
    end

    for _, route in ipairs(self.routes) do
        for _, point in ipairs(route.points) do
            if point.sharedPointId == fromSharedPointId then
                point.sharedPointId = toSharedPointId
            end
        end
    end
end

function mapEditor:updateSharedPointGroup(sharedPointId, x, y)
    if not sharedPointId then
        return
    end

    for _, route in ipairs(self.routes) do
        for _, point in ipairs(route.points) do
            if point.sharedPointId == sharedPointId then
                point.x = x
                point.y = y
            end
        end
    end

    self:collapseRoutesForSharedPoint(sharedPointId)
end

function mapEditor:pruneSharedPointFromRoutes(sharedPointId, preservedRouteIds)
    if not sharedPointId then
        return
    end

    local preservedLookup = {}
    for _, routeId in ipairs(preservedRouteIds or {}) do
        preservedLookup[routeId] = true
    end

    for _, route in ipairs(self.routes) do
        if not preservedLookup[route.id] then
            for pointIndex = #route.points - 1, 2, -1 do
                local point = route.points[pointIndex]
                if point.sharedPointId == sharedPointId then
                    table.remove(route.points, pointIndex)
                    self:mergeRouteSegmentStyle(route, pointIndex)
                end
            end
        end
    end
end

function mapEditor:collapseRoutesForSharedPoint(sharedPointId)
    if not sharedPointId then
        return
    end

    for _, route in ipairs(self.routes) do
        local pointIndex = 2
        while pointIndex <= #route.points - 1 do
            local point = route.points[pointIndex]
            local previousPoint = route.points[pointIndex - 1]

            if point.sharedPointId == sharedPointId
                and previousPoint
                and distanceSquared(point.x, point.y, previousPoint.x, previousPoint.y) <= INTERNAL_POINT_MATCH_DISTANCE_SQUARED then
                table.remove(route.points, pointIndex)
                self:mergeRouteSegmentStyle(route, pointIndex)
            else
                pointIndex = pointIndex + 1
            end
        end
    end
end

function mapEditor:restoreSharedPointsForRoutes(routeIds)
    local pointGroups = {}

    for _, routeId in ipairs(routeIds or {}) do
        local route = self:getRouteById(routeId)
        if route then
            for pointIndex = 2, #route.points - 1 do
                local point = route.points[pointIndex]
                local matchedGroup = nil

                for _, group in ipairs(pointGroups) do
                    if distanceSquared(point.x, point.y, group.x, group.y) <= 4 then
                        matchedGroup = group
                        break
                    end
                end

                if not matchedGroup then
                    matchedGroup = {
                        x = point.x,
                        y = point.y,
                        members = {},
                    }
                    pointGroups[#pointGroups + 1] = matchedGroup
                end

                matchedGroup.members[#matchedGroup.members + 1] = point
            end
        end
    end

    for _, group in ipairs(pointGroups) do
        if #group.members > 1 then
            local sharedPointId = nil

            for _, point in ipairs(group.members) do
                if point.sharedPointId then
                    sharedPointId = point.sharedPointId
                    break
                end
            end

            if not sharedPointId then
                sharedPointId = self.nextSharedPointId
                self.nextSharedPointId = self.nextSharedPointId + 1
            end

            for _, point in ipairs(group.members) do
                point.sharedPointId = sharedPointId
            end
        end
    end
end

function mapEditor:mergeBendPointInto(route, pointIndex, targetRoute, targetPointIndex)
    local point = route and route.points and route.points[pointIndex] or nil
    local targetPoint = targetRoute and targetRoute.points and targetRoute.points[targetPointIndex] or nil
    if not point or not targetPoint then
        return false
    end

    point.x = targetPoint.x
    point.y = targetPoint.y

    local targetSharedPointId = self:ensureSharedPointId(targetPoint)
    if point.sharedPointId and point.sharedPointId ~= targetSharedPointId then
        self:reassignSharedPointGroup(point.sharedPointId, targetSharedPointId)
    end
    point.sharedPointId = targetSharedPointId
    self:updateSharedPointGroup(targetSharedPointId, targetPoint.x, targetPoint.y)
    self:rebuildIntersections()
    self:showStatus("Bend points merged into a shared junction.")
    return true
end

function mapEditor:findEndpointAt(x, y, kind, excludeEndpointId)
    local radius = MERGE_SNAP_RADIUS / math.max(self.camera.zoom, 0.0001)
    for _, endpoint in ipairs(self.endpoints) do
        if endpoint.kind == kind and endpoint.id ~= excludeEndpointId then
            if distanceSquared(x, y, endpoint.x, endpoint.y) <= radius * radius then
                return endpoint
            end
        end
    end
    return nil
end

function mapEditor:findSegmentHit(x, y)
    local bestHit = nil
    local bestDistance = SEGMENT_HIT_RADIUS * SEGMENT_HIT_RADIUS

    for routeIndex = #self.routes, 1, -1 do
        local route = self.routes[routeIndex]
        for pointIndex = 1, #route.points - 1 do
            local a = route.points[pointIndex]
            local b = route.points[pointIndex + 1]
            local metrics = self:getSegmentHitMetrics(route, pointIndex)
            local closestX, closestY, t, distance = closestPointOnSegment(x, y, a, b)
            local projectionDistance = metrics.length * t

            if distance < bestDistance
                and distance <= metrics.halfWidth * metrics.halfWidth
                and projectionDistance > metrics.startInset
                and projectionDistance < metrics.length - metrics.endInset then
                bestDistance = distance
                bestHit = {
                    route = route,
                    segmentIndex = pointIndex,
                    insertIndex = pointIndex + 1,
                    point = { x = closestX, y = closestY },
                }
            end
        end
    end

    return bestHit
end

function mapEditor:getPointHitRadius()
    return POINT_HIT_RADIUS
end

function mapEditor:getIntersectionHitRadius(intersection)
    local baseRadius = intersection and intersection.unsupported and INTERSECTION_UNSUPPORTED_HIT_RADIUS or INTERSECTION_HIT_RADIUS
    if not (intersection and intersection.unsupported) and self.previewWorld and self.previewWorld.crossingRadius then
        baseRadius = math.max(INTERSECTION_HIT_RADIUS, self.previewWorld.crossingRadius - 4)
    end
    return baseRadius
end

function mapEditor:getOutputSelectorHitRect(intersection)
    return {
        x = intersection.x - INTERSECTION_SELECTOR_CLICK_RADIUS,
        y = intersection.y + INTERSECTION_SELECTOR_OFFSET_Y - INTERSECTION_SELECTOR_CLICK_RADIUS,
        w = INTERSECTION_SELECTOR_CLICK_RADIUS * 2,
        h = INTERSECTION_SELECTOR_CLICK_RADIUS * 2,
    }
end

function mapEditor:getRouteDebugName(route)
    local routeName = tostring(route and (route.label or route.id) or "")
    if routeName == "" then
        return "route"
    end
    return routeName
end

function mapEditor:getHitboxOverlayColor(index)
    local option = COLOR_OPTIONS[((index - 1) % #COLOR_OPTIONS) + 1]
    return option and option.color or COLOR_OPTIONS[1].color
end

function mapEditor:buildSegmentHitboxPolygon(route, segmentIndex)
    local pointA = route.points[segmentIndex]
    local pointB = route.points[segmentIndex + 1]
    local dx = pointB.x - pointA.x
    local dy = pointB.y - pointA.y
    local metrics = self:getSegmentHitMetrics(route, segmentIndex)
    local length = metrics.length

    if length <= HITBOX_OVERLAY_EPSILON or metrics.startInset + metrics.endInset >= length - HITBOX_OVERLAY_EPSILON then
        return nil
    end

    local startRatio = metrics.startInset / length
    local endRatio = (length - metrics.endInset) / length
    local startX = lerp(pointA.x, pointB.x, startRatio)
    local startY = lerp(pointA.y, pointB.y, startRatio)
    local endX = lerp(pointA.x, pointB.x, endRatio)
    local endY = lerp(pointA.y, pointB.y, endRatio)
    local normalX = -dy / length
    local normalY = dx / length
    local halfWidth = metrics.halfWidth

    return {
        points = {
            startX + normalX * halfWidth, startY + normalY * halfWidth,
            endX + normalX * halfWidth, endY + normalY * halfWidth,
            endX - normalX * halfWidth, endY - normalY * halfWidth,
            startX - normalX * halfWidth, startY - normalY * halfWidth,
        },
        labelX = (startX + endX) * 0.5,
        labelY = (startY + endY) * 0.5,
    }
end

function mapEditor:getSegmentEndpointInset(route, pointIndex)
    local point = route and route.points and route.points[pointIndex] or nil
    if not point then
        return 0
    end

    if pointIndex == 1 or pointIndex == #route.points then
        return self:getMagnetHitRadius()
    end

    if point.sharedPointId then
        local _, intersection = self:getSharedPointGroupForPoint(route, pointIndex)
        if intersection then
            return self:getIntersectionHitRadius(intersection)
        end
    end

    return self:getPointHitRadius()
end

function mapEditor:getSegmentHitMetrics(route, segmentIndex)
    local pointA = route.points[segmentIndex]
    local pointB = route.points[segmentIndex + 1]
    local dx = pointB.x - pointA.x
    local dy = pointB.y - pointA.y
    local length = math.sqrt(dx * dx + dy * dy)
    local halfWidth = math.min(SEGMENT_HIT_RADIUS, math.max(SEGMENT_HIT_MIN_HALF_WIDTH, length * SEGMENT_HIT_HALF_WIDTH_RATIO))
    local defaultInset = math.max(SEGMENT_HIT_MIN_INSET, math.min(SEGMENT_HIT_RADIUS, length * SEGMENT_HIT_INSET_RATIO))
    local startInset = math.max(defaultInset, self:getSegmentEndpointInset(route, segmentIndex))
    local endInset = math.max(defaultInset, self:getSegmentEndpointInset(route, segmentIndex + 1))
    local maxInsetSum = math.max(length - HITBOX_OVERLAY_EPSILON, 0)

    if startInset + endInset > maxInsetSum and maxInsetSum > 0 then
        local scale = maxInsetSum / (startInset + endInset)
        startInset = startInset * scale
        endInset = endInset * scale
    end

    return {
        length = length,
        halfWidth = halfWidth,
        startInset = startInset,
        endInset = endInset,
    }
end

function mapEditor:getHitboxOverlayEntries()
    local entries = {}

    for routeIndex = #self.routes, 1, -1 do
        local route = self.routes[routeIndex]
        local routeName = self:getRouteDebugName(route)

        for pointIndex = #route.points, 1, -1 do
            local point = route.points[pointIndex]
            local isMagnet = pointIndex == 1 or pointIndex == #route.points
            local isSharedJunctionPoint = not isMagnet and point.sharedPointId and self:getSharedPointGroupForPoint(route, pointIndex)

            if not isSharedJunctionPoint then
                local label = nil
                local entry = nil

                if pointIndex == 1 then
                    local radius = self:getMagnetHitRadius()
                    entry = {
                        kind = "circle",
                        x = point.x,
                        y = point.y,
                        radius = radius,
                    }
                    label = string.format("%s start", routeName)
                elseif pointIndex == #route.points then
                    local radius = self:getMagnetHitRadius()
                    entry = {
                        kind = "circle",
                        x = point.x,
                        y = point.y,
                        radius = radius,
                    }
                    label = string.format("%s end", routeName)
                else
                    local radius = self:getPointHitRadius()
                    entry = {
                        kind = "rect",
                        rect = {
                            x = point.x - radius,
                            y = point.y - radius,
                            w = radius * 2,
                            h = radius * 2,
                        },
                    }
                    label = string.format("%s bend %d", routeName, pointIndex)
                end

                entry.label = label
                entry.labelX = point.x
                entry.labelY = point.y
                entries[#entries + 1] = entry
            end
        end
    end

    for _, intersection in ipairs(self.intersections) do
        if self:isIntersectionOutputSelectorHit(intersection, intersection.x, intersection.y + INTERSECTION_SELECTOR_OFFSET_Y) then
            local rect = self:getOutputSelectorHitRect(intersection)
            entries[#entries + 1] = {
                kind = "rect",
                rect = rect,
                label = string.format("%s output", tostring(intersection.routeKey or intersection.id or "junction")),
                labelX = rect.x + rect.w * 0.5,
                labelY = rect.y + rect.h * 0.5,
            }
        end
    end

    for _, intersection in ipairs(self.intersections) do
        local radius = self:getIntersectionHitRadius(intersection)
        entries[#entries + 1] = {
            kind = "circle",
            x = intersection.x,
            y = intersection.y,
            radius = radius,
            label = string.format("%s %s", tostring(intersection.routeKey or intersection.id or "junction"), intersection.controlType or "junction"),
            labelX = intersection.x,
            labelY = intersection.y,
        }
    end

    for routeIndex = #self.routes, 1, -1 do
        local route = self.routes[routeIndex]
        local routeName = self:getRouteDebugName(route)

        for segmentIndex = 1, #route.points - 1 do
            local polygon = self:buildSegmentHitboxPolygon(route, segmentIndex)
            if polygon then
                entries[#entries + 1] = {
                    kind = "polygon",
                    points = polygon.points,
                    label = string.format("%s segment %d", routeName, segmentIndex),
                    labelX = polygon.labelX,
                    labelY = polygon.labelY,
                }
            end
        end
    end

    local totalEntries = #entries
    for index, entry in ipairs(entries) do
        entry.zIndex = totalEntries - index + 1
        entry.color = self:getHitboxOverlayColor(index)
        entry.label = string.format("Z%d %s", entry.zIndex, entry.label)
    end

    return entries
end

function mapEditor:deleteSelection()
    local selectedRoute = self:getSelectedRoute()
    if not selectedRoute then
        return
    end

    self:closeColorPicker()
    self:closeRouteTypePicker()

    if self.selectedPointIndex and self.selectedPointIndex > 1 and self.selectedPointIndex < #selectedRoute.points then
        self:mergeRouteSegmentStyle(selectedRoute, self.selectedPointIndex)
        table.remove(selectedRoute.points, self.selectedPointIndex)
        self.selectedPointIndex = nil
        self:rebuildIntersections()
        self:showStatus("Bend point removed.")
        return
    end

    for routeIndex, route in ipairs(self.routes) do
        if route.id == selectedRoute.id then
            table.remove(self.routes, routeIndex)
            break
        end
    end

    self:clearSelection()
    self:rebuildIntersections()
    self:showStatus("Route removed.")
end

function mapEditor:getIntersectionControlType(intersection, previousMatches)
    local bestDistanceSquared = nil
    local bestControlType = nil

    for _, imported in ipairs(self.importedJunctionState[intersection.routeKey] or {}) do
        local candidateDistanceSquared = distanceSquared(imported.x, imported.y, intersection.x, intersection.y)
        if candidateDistanceSquared <= INTERSECTION_STATE_MATCH_DISTANCE_SQUARED
            and (not bestDistanceSquared or candidateDistanceSquared < bestDistanceSquared) then
            bestDistanceSquared = candidateDistanceSquared
            bestControlType = imported.controlType
        end
    end

    for _, previous in ipairs(previousMatches) do
        if previous.routeKey == intersection.routeKey then
            local candidateDistanceSquared = distanceSquared(previous.x, previous.y, intersection.x, intersection.y)
            if candidateDistanceSquared <= INTERSECTION_STATE_MATCH_DISTANCE_SQUARED
                and (not bestDistanceSquared or candidateDistanceSquared < bestDistanceSquared) then
                bestDistanceSquared = candidateDistanceSquared
                bestControlType = previous.controlType
            end
        end
    end

    if bestControlType then
        return bestControlType
    end

    return DEFAULT_CONTROL
end

function mapEditor:getJunctionState(intersection, previousMatches)
    local bestDistanceSquared = nil
    local bestMatch = nil

    for _, imported in ipairs(self.importedJunctionState[intersection.routeKey] or {}) do
        local candidateDistanceSquared = distanceSquared(imported.x, imported.y, intersection.x, intersection.y)
        if candidateDistanceSquared <= INTERSECTION_STATE_MATCH_DISTANCE_SQUARED
            and (not bestDistanceSquared or candidateDistanceSquared < bestDistanceSquared) then
            bestDistanceSquared = candidateDistanceSquared
            bestMatch = imported
        end
    end

    for _, previous in ipairs(previousMatches) do
        if previous.routeKey == intersection.routeKey then
            local candidateDistanceSquared = distanceSquared(previous.x, previous.y, intersection.x, intersection.y)
            if candidateDistanceSquared <= INTERSECTION_STATE_MATCH_DISTANCE_SQUARED
                and (not bestDistanceSquared or candidateDistanceSquared < bestDistanceSquared) then
                bestDistanceSquared = candidateDistanceSquared
                bestMatch = previous
            end
        end
    end

    if bestMatch then
        return bestMatch
    end

    return nil
end

function mapEditor:getRoutesPassingThroughPoint(routeIds, point, toleranceSquared)
    local matchedRouteIds = {}
    local distanceScore = 0

    for _, routeId in ipairs(routeIds or {}) do
        local route = self:getRouteById(routeId)
        local bestDistanceSquared = nil

        if route and route.points and #route.points >= 2 then
            for pointIndex = 1, #route.points - 1 do
                local a = route.points[pointIndex]
                local b = route.points[pointIndex + 1]
                local _, _, _, segmentDistanceSquared = closestPointOnSegment(point.x, point.y, a, b)
                if not bestDistanceSquared or segmentDistanceSquared < bestDistanceSquared then
                    bestDistanceSquared = segmentDistanceSquared
                end
            end
        end

        if bestDistanceSquared and bestDistanceSquared <= (toleranceSquared or 4) then
            matchedRouteIds[#matchedRouteIds + 1] = routeId
            distanceScore = distanceScore + bestDistanceSquared
        end
    end

    local routeKey, sortedRouteIds = buildRouteKey(matchedRouteIds)
    return sortedRouteIds, routeKey, distanceScore
end

function mapEditor:resolveGroupedIntersections(groupedIntersection)
    local resolved = {}
    local candidatesByRouteKey = {}
    local clusterRadiusSquared = STRICT_INTERSECTION_CLUSTER_RADIUS * STRICT_INTERSECTION_CLUSTER_RADIUS

    for _, hit in ipairs(groupedIntersection.hits or {}) do
        local routeIds, routeKey, distanceScore = self:getRoutesPassingThroughPoint(
            groupedIntersection.routeIds,
            hit,
            4
        )

        if #routeIds >= 2 then
            candidatesByRouteKey[routeKey] = candidatesByRouteKey[routeKey] or {}

            local targetCluster = nil
            for _, cluster in ipairs(candidatesByRouteKey[routeKey]) do
                if distanceSquared(cluster.x, cluster.y, hit.x, hit.y) <= clusterRadiusSquared then
                    targetCluster = cluster
                    break
                end
            end

            if not targetCluster then
                targetCluster = {
                    x = hit.x,
                    y = hit.y,
                    routeIds = routeIds,
                    candidates = {},
                }
                candidatesByRouteKey[routeKey][#candidatesByRouteKey[routeKey] + 1] = targetCluster
            end

            targetCluster.candidates[#targetCluster.candidates + 1] = {
                x = hit.x,
                y = hit.y,
                distanceScore = distanceScore,
            }
        end
    end

    for routeKey, clusters in pairs(candidatesByRouteKey) do
        for _, cluster in ipairs(clusters) do
            local bestCandidate = chooseBestCandidatePoint(cluster.candidates)
            if bestCandidate then
                resolved[#resolved + 1] = {
                    id = buildIntersectionId(routeKey, bestCandidate),
                    x = bestCandidate.x,
                    y = bestCandidate.y,
                    routeIds = cluster.routeIds,
                }
            end
        end
    end

    return resolved
end

function mapEditor:sortEndpointIdsByPosition(endpointIds, kind)
    table.sort(endpointIds, function(firstId, secondId)
        local first = self:getEndpointById(firstId)
        local second = self:getEndpointById(secondId)
        if not first or not second then
            return tostring(firstId) < tostring(secondId)
        end

        if kind == "input" then
            if math.abs(first.x - second.x) > 1 then
                return first.x < second.x
            end
            return first.y < second.y
        end

        if math.abs(first.y - second.y) > 1 then
            return first.y < second.y
        end
        return first.x < second.x
    end)
end

function mapEditor:sortRouteIdsByMagnet(routeIds, magnetKind)
    table.sort(routeIds, function(firstRouteId, secondRouteId)
        local firstRoute = self:getRouteById(firstRouteId)
        local secondRoute = self:getRouteById(secondRouteId)
        if not firstRoute or not secondRoute then
            return tostring(firstRouteId) < tostring(secondRouteId)
        end

        local firstEndpoint = magnetKind == "start"
            and self:getRouteStartEndpoint(firstRoute)
            or self:getRouteEndEndpoint(firstRoute)
        local secondEndpoint = magnetKind == "start"
            and self:getRouteStartEndpoint(secondRoute)
            or self:getRouteEndEndpoint(secondRoute)

        if not firstEndpoint or not secondEndpoint then
            return tostring(firstRouteId) < tostring(secondRouteId)
        end

        if magnetKind == "start" then
            if math.abs(firstEndpoint.x - secondEndpoint.x) > 1 then
                return firstEndpoint.x < secondEndpoint.x
            end
            if math.abs(firstEndpoint.y - secondEndpoint.y) > 1 then
                return firstEndpoint.y < secondEndpoint.y
            end
        else
            if math.abs(firstEndpoint.y - secondEndpoint.y) > 1 then
                return firstEndpoint.y < secondEndpoint.y
            end
            if math.abs(firstEndpoint.x - secondEndpoint.x) > 1 then
                return firstEndpoint.x < secondEndpoint.x
            end
        end

        return tostring(firstRouteId) < tostring(secondRouteId)
    end)
end

function mapEditor:isSharedEndpointIntersection(groupedIntersection)
    local sharedStartEndpointId = nil
    local sharedEndEndpointId = nil
    local allAtSharedStart = true
    local allAtSharedEnd = true
    local toleranceSquared = 12 * 12

    for _, routeId in ipairs(groupedIntersection.routeIds or {}) do
        local route = self:getRouteById(routeId)
        if not route or not route.points or #route.points < 2 then
            return false
        end

        local startPoint = route.points[1]
        local endPoint = route.points[#route.points]
        local touchesStart = distanceSquared(startPoint.x, startPoint.y, groupedIntersection.x, groupedIntersection.y) <= toleranceSquared
        local touchesEnd = distanceSquared(endPoint.x, endPoint.y, groupedIntersection.x, groupedIntersection.y) <= toleranceSquared

        if not touchesStart then
            allAtSharedStart = false
        elseif sharedStartEndpointId and sharedStartEndpointId ~= route.startEndpointId then
            allAtSharedStart = false
        else
            sharedStartEndpointId = route.startEndpointId
        end

        if not touchesEnd then
            allAtSharedEnd = false
        elseif sharedEndEndpointId and sharedEndEndpointId ~= route.endEndpointId then
            allAtSharedEnd = false
        else
            sharedEndEndpointId = route.endEndpointId
        end
    end

    return (allAtSharedStart and sharedStartEndpointId ~= nil)
        or (allAtSharedEnd and sharedEndEndpointId ~= nil)
end

function mapEditor:rebuildIntersections(passIndex)
    passIndex = passIndex or 1
    local previousIntersections = self.intersections or {}
    local grouped = {}

    for firstIndex = 1, #self.routes - 1 do
        local firstRoute = self.routes[firstIndex]
        for secondIndex = firstIndex + 1, #self.routes do
            local secondRoute = self.routes[secondIndex]
            for firstSegmentIndex = 1, #firstRoute.points - 1 do
                local a = firstRoute.points[firstSegmentIndex]
                local b = firstRoute.points[firstSegmentIndex + 1]
                for secondSegmentIndex = 1, #secondRoute.points - 1 do
                    local c = secondRoute.points[secondSegmentIndex]
                    local d = secondRoute.points[secondSegmentIndex + 1]
                    local hit = segmentIntersection(a, b, c, d)

                    if hit then
                        local groupX = math.floor(hit.x / INTERSECTION_GROUP_BUCKET + 0.5) * INTERSECTION_GROUP_BUCKET
                        local groupY = math.floor(hit.y / INTERSECTION_GROUP_BUCKET + 0.5) * INTERSECTION_GROUP_BUCKET
                        local groupKey = groupX .. ":" .. groupY
                        local entry = grouped[groupKey]

                        if not entry then
                            entry = {
                                x = hit.x,
                                y = hit.y,
                                routeIds = {},
                                routeLookup = {},
                                hits = {},
                            }
                            grouped[groupKey] = entry
                        else
                            entry.x = (entry.x + hit.x) * 0.5
                            entry.y = (entry.y + hit.y) * 0.5
                        end

                        entry.hits[#entry.hits + 1] = { x = hit.x, y = hit.y }

                        if not entry.routeLookup[firstRoute.id] then
                            entry.routeLookup[firstRoute.id] = true
                            entry.routeIds[#entry.routeIds + 1] = firstRoute.id
                        end
                        if not entry.routeLookup[secondRoute.id] then
                            entry.routeLookup[secondRoute.id] = true
                            entry.routeIds[#entry.routeIds + 1] = secondRoute.id
                        end
                    end
                end
            end
        end
    end

    self.intersections = {}

    for _, groupedIntersection in pairs(grouped) do
        table.sort(groupedIntersection.routeIds)
        for _, strictIntersection in ipairs(self:resolveGroupedIntersections(groupedIntersection)) do
            if self:isSharedEndpointIntersection(strictIntersection) then
                goto continue_strict_intersection
            end

            local routeKey = table.concat(strictIntersection.routeIds, "|")
            local inputEndpointIds = {}
            local outputEndpointIds = {}
            local inputLookup = {}
            local outputLookup = {}
            local inputRouteIds = {}
            local outputRouteIds = {}

            for _, routeId in ipairs(strictIntersection.routeIds) do
                local route = self:getRouteById(routeId)
                if route then
                    inputRouteIds[#inputRouteIds + 1] = route.id
                    outputRouteIds[#outputRouteIds + 1] = route.id
                    if not inputLookup[route.startEndpointId] then
                        inputLookup[route.startEndpointId] = true
                        inputEndpointIds[#inputEndpointIds + 1] = route.startEndpointId
                    end
                    if not outputLookup[route.endEndpointId] then
                        outputLookup[route.endEndpointId] = true
                        outputEndpointIds[#outputEndpointIds + 1] = route.endEndpointId
                    end
                end
            end

            self:sortEndpointIdsByPosition(inputEndpointIds, "input")
            self:sortEndpointIdsByPosition(outputEndpointIds, "output")
            self:sortRouteIdsByMagnet(inputRouteIds, "start")
            self:sortRouteIdsByMagnet(outputRouteIds, "end")

            local intersection = {
                id = strictIntersection.id,
                x = strictIntersection.x,
                y = strictIntersection.y,
                routeIds = strictIntersection.routeIds,
                routeKey = routeKey,
                inputEndpointIds = inputEndpointIds,
                outputEndpointIds = outputEndpointIds,
                inputRouteIds = inputRouteIds,
                outputRouteIds = outputRouteIds,
            }
            local state = self:getJunctionState(intersection, previousIntersections)
            intersection.controlType = self:getIntersectionControlType(intersection, previousIntersections)
            intersection.passCount = math.max(1, math.min(MAX_TRIP_PASS_COUNT, (state and state.passCount) or DEFAULT_CONTROL_CONFIGS.trip.passCount))
            intersection.activeInputIndex = math.min((state and state.activeInputIndex) or 1, math.max(1, #inputRouteIds))
            intersection.activeOutputIndex = math.min((state and state.activeOutputIndex) or 1, math.max(1, #outputEndpointIds))
            self.intersections[#self.intersections + 1] = intersection

            ::continue_strict_intersection::
        end
    end

    table.sort(self.intersections, function(a, b)
        if math.abs(a.y - b.y) > 1 then
            return a.y < b.y
        end
        return a.x < b.x
    end)

    if not self.deferIntersectionMaterialization and passIndex < MAX_INTERSECTION_MATERIALIZE_PASSES then
        local changed = false

        for _, intersection in ipairs(self.intersections) do
            changed = self:materializeIntersectionSharedPoints(intersection) or changed
        end

        if changed then
            return self:rebuildIntersections(passIndex + 1)
        end
    end

    self:refreshValidation()
end

end
