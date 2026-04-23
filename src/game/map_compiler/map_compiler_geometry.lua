return function(mapCompiler, shared)
    local moduleEnvironment = setmetatable({ mapCompiler = mapCompiler }, {
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

local GEOMETRY_EPSILON = 0.0000001
local COLLINEAR_POINT_TOLERANCE = 0.000001

function distanceSquared(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by
    return dx * dx + dy * dy
end

function segmentLength(a, b)
    local dx = b.x - a.x
    local dy = b.y - a.y
    return math.sqrt(dx * dx + dy * dy)
end

function copyPoint(point)
    return { x = point.x, y = point.y }
end

function copyColor(color)
    return { color[1], color[2], color[3] }
end

function getColor(colorId)
    return copyColor(COLOR_LOOKUP[colorId] or COLOR_LOOKUP.blue)
end

function formatColorLabel(colorId)
    local text = tostring(colorId or "route")
    return (text:gsub("^%l", string.upper))
end

function getRouteDisplayName(route)
    if route and route.color then
        return string.format("%s route", formatColorLabel(route.color))
    end
    return tostring(route and (route.label or route.id) or "Route")
end

function darkerColor(color)
    return {
        color[1] * 0.42,
        color[2] * 0.42,
        color[3] * 0.42,
    }
end

function copyControlConfig(controlType)
    local config = DEFAULT_CONTROL_CONFIGS[controlType] or DEFAULT_CONTROL_CONFIGS.direct
    local copy = {}

    for key, value in pairs(config) do
        copy[key] = value
    end

    copy.type = controlType or "direct"
    return copy
end

function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, child in pairs(value) do
        copy[key] = deepCopy(child)
    end
    return copy
end

function closestPointOnSegment(px, py, a, b)
    local abX = b.x - a.x
    local abY = b.y - a.y
    local lengthSquared = abX * abX + abY * abY

    if lengthSquared <= GEOMETRY_EPSILON then
        return a.x, a.y, 0, distanceSquared(px, py, a.x, a.y)
    end

    local t = ((px - a.x) * abX + (py - a.y) * abY) / lengthSquared
    if t < 0 then
        t = 0
    elseif t > 1 then
        t = 1
    end

    local x = a.x + abX * t
    local y = a.y + abY * t
    return x, y, t, distanceSquared(px, py, x, y)
end

function interpolatePoint(a, b, t)
    return {
        x = a.x + (b.x - a.x) * t,
        y = a.y + (b.y - a.y) * t,
    }
end

function pointOnSegment(point, a, b, toleranceSquared)
    local closestX, closestY, _, distance = closestPointOnSegment(point.x, point.y, a, b)
    if distance <= (toleranceSquared or 0.000004) then
        return { x = closestX, y = closestY }
    end
    return nil
end

function splitRouteAtPoint(routePoints, junctionPoint)
    local prefix = { copyPoint(routePoints[1]) }

    for pointIndex = 1, #routePoints - 1 do
        local a = routePoints[pointIndex]
        local b = routePoints[pointIndex + 1]
        local hitPoint = pointOnSegment(junctionPoint, a, b)

        if hitPoint then
            if distanceSquared(prefix[#prefix].x, prefix[#prefix].y, hitPoint.x, hitPoint.y) > GEOMETRY_EPSILON then
                prefix[#prefix + 1] = hitPoint
            end
            return prefix
        end

        prefix[#prefix + 1] = copyPoint(b)
    end

    return nil
end

function splitRouteSuffixAtPoint(routePoints, junctionPoint)
    for pointIndex = 1, #routePoints - 1 do
        local a = routePoints[pointIndex]
        local b = routePoints[pointIndex + 1]
        local hitPoint = pointOnSegment(junctionPoint, a, b)

        if hitPoint then
            local suffix = { hitPoint }
            if distanceSquared(hitPoint.x, hitPoint.y, b.x, b.y) > GEOMETRY_EPSILON then
                suffix[#suffix + 1] = copyPoint(b)
            end
            for suffixIndex = pointIndex + 2, #routePoints do
                suffix[#suffix + 1] = copyPoint(routePoints[suffixIndex])
            end
            return suffix
        end
    end

    return nil
end

function findDistanceAlongRoute(routePoints, point)
    local totalDistance = 0

    for pointIndex = 1, #routePoints - 1 do
        local a = routePoints[pointIndex]
        local b = routePoints[pointIndex + 1]
        local hitPoint = pointOnSegment(point, a, b)

        if hitPoint then
            return totalDistance + segmentLength(a, hitPoint), hitPoint
        end

        totalDistance = totalDistance + segmentLength(a, b)
    end

    return nil, nil
end

function extractRouteSegment(routePoints, startDistance, endDistance)
    local segmentPoints = {}
    local totalDistance = 0

    local function isRedundantInteriorPoint(previousPoint, point, nextPoint)
        if not previousPoint or not point or not nextPoint then
            return false
        end

        local previousToNextX = nextPoint.x - previousPoint.x
        local previousToNextY = nextPoint.y - previousPoint.y
        local previousToNextLengthSquared = previousToNextX * previousToNextX + previousToNextY * previousToNextY
        if previousToNextLengthSquared <= GEOMETRY_EPSILON then
            return false
        end

        local previousToPointX = point.x - previousPoint.x
        local previousToPointY = point.y - previousPoint.y
        local dot = previousToPointX * previousToNextX + previousToPointY * previousToNextY
        if dot <= GEOMETRY_EPSILON or dot >= previousToNextLengthSquared - GEOMETRY_EPSILON then
            return false
        end

        local cross = previousToPointX * previousToNextY - previousToPointY * previousToNextX
        local distanceFromLineSquared = (cross * cross) / previousToNextLengthSquared
        return distanceFromLineSquared <= COLLINEAR_POINT_TOLERANCE * COLLINEAR_POINT_TOLERANCE
    end

    local function simplifySegmentPoints(points)
        if #points <= 2 then
            return points
        end

        local simplifiedPoints = { points[1] }
        for pointIndex = 2, #points - 1 do
            local previousPoint = simplifiedPoints[#simplifiedPoints]
            local point = points[pointIndex]
            local nextPoint = points[pointIndex + 1]

            if distanceSquared(previousPoint.x, previousPoint.y, point.x, point.y) > GEOMETRY_EPSILON
                and not isRedundantInteriorPoint(previousPoint, point, nextPoint) then
                simplifiedPoints[#simplifiedPoints + 1] = point
            end
        end

        local finalPoint = points[#points]
        if distanceSquared(
                simplifiedPoints[#simplifiedPoints].x,
                simplifiedPoints[#simplifiedPoints].y,
                finalPoint.x,
                finalPoint.y
            ) > GEOMETRY_EPSILON then
            simplifiedPoints[#simplifiedPoints + 1] = finalPoint
        end

        return simplifiedPoints
    end

    for pointIndex = 1, #routePoints - 1 do
        local a = routePoints[pointIndex]
        local b = routePoints[pointIndex + 1]
        local length = segmentLength(a, b)
        local segmentStart = totalDistance
        local segmentEnd = totalDistance + length

        if endDistance < segmentStart - GEOMETRY_EPSILON then
            break
        end

        if startDistance <= segmentEnd + GEOMETRY_EPSILON
            and endDistance >= segmentStart - GEOMETRY_EPSILON
            and length > GEOMETRY_EPSILON then
            local localStart = math.max(0, startDistance - segmentStart)
            local localEnd = math.min(length, endDistance - segmentStart)
            local startPoint = interpolatePoint(a, b, localStart / length)
            local endPoint = interpolatePoint(a, b, localEnd / length)

            if #segmentPoints == 0
                or distanceSquared(
                    segmentPoints[#segmentPoints].x,
                    segmentPoints[#segmentPoints].y,
                    startPoint.x,
                    startPoint.y
                ) > GEOMETRY_EPSILON then
                segmentPoints[#segmentPoints + 1] = startPoint
            end

            if distanceSquared(
                    segmentPoints[#segmentPoints].x,
                    segmentPoints[#segmentPoints].y,
                    endPoint.x,
                    endPoint.y
                ) > GEOMETRY_EPSILON then
                segmentPoints[#segmentPoints + 1] = endPoint
            end
        end

        totalDistance = segmentEnd
    end

    return simplifySegmentPoints(segmentPoints)
end

function getEndpointById(editorData, endpointId)
    for _, endpoint in ipairs(editorData.endpoints or {}) do
        if endpoint.id == endpointId then
            return endpoint
        end
    end
    return nil
end

function getRouteById(editorData, routeId)
    for _, route in ipairs(editorData.routes or {}) do
        if route.id == routeId then
            return route
        end
    end
    return nil
end

function getRouteSegmentRoadTypes(route)
    local routePoints = (route and route.points) or {}
    local segmentCount = math.max(0, #routePoints - 1)
    local fallbackRoadType = roadTypes.normalizeRoadType(route and route.roadType)
    local segmentRoadTypes = {}

    for segmentIndex = 1, segmentCount do
        local roadTypeId = route
            and route.segmentRoadTypes
            and route.segmentRoadTypes[segmentIndex]
            or fallbackRoadType
        segmentRoadTypes[segmentIndex] = roadTypes.normalizeRoadType(roadTypeId)
    end

    return segmentRoadTypes
end

function buildRouteStyleSections(route, startDistance, endDistance)
    local styleSections = {}
    local routePoints = route.points or {}
    local segmentRoadTypes = getRouteSegmentRoadTypes(route)
    local traversedDistance = 0
    local epsilon = 0.0000001
    local totalSectionLength = math.max(endDistance - startDistance, epsilon)

    for pointIndex = 1, #routePoints - 1 do
        local pointA = routePoints[pointIndex]
        local pointB = routePoints[pointIndex + 1]
        local length = segmentLength(pointA, pointB)
        local segmentStartDistance = traversedDistance
        local segmentEndDistance = traversedDistance + length
        local overlapStartDistance = math.max(startDistance, segmentStartDistance)
        local overlapEndDistance = math.min(endDistance, segmentEndDistance)

        if overlapEndDistance - overlapStartDistance > epsilon then
            local roadTypeId = segmentRoadTypes[pointIndex]
            local previousSection = styleSections[#styleSections]
            local localStartRatio = (overlapStartDistance - startDistance) / totalSectionLength
            local localEndRatio = (overlapEndDistance - startDistance) / totalSectionLength

            if previousSection
                and previousSection.roadType == roadTypeId
                and math.abs(previousSection.endRatio - localStartRatio) <= epsilon then
                previousSection.endRatio = localEndRatio
            else
                styleSections[#styleSections + 1] = {
                    roadType = roadTypeId,
                    speedScale = roadTypes.getConfig(roadTypeId).speedScale,
                    startRatio = localStartRatio,
                    endRatio = localEndRatio,
                }
            end
        end

        traversedDistance = segmentEndDistance
    end

    return styleSections
end

function sortRouteIdsByMagnet(editorData, routeIds, magnetKind)
    table.sort(routeIds, function(firstRouteId, secondRouteId)
        local firstRoute = getRouteById(editorData, firstRouteId)
        local secondRoute = getRouteById(editorData, secondRouteId)
        if not firstRoute or not secondRoute then
            return tostring(firstRouteId) < tostring(secondRouteId)
        end

        local firstEndpoint = getEndpointById(editorData, magnetKind == "start" and firstRoute.startEndpointId or firstRoute.endEndpointId)
        local secondEndpoint = getEndpointById(editorData, magnetKind == "start" and secondRoute.startEndpointId or secondRoute.endEndpointId)
        if not firstEndpoint or not secondEndpoint then
            return tostring(firstRouteId) < tostring(secondRouteId)
        end

        if magnetKind == "start" then
            if math.abs(firstEndpoint.x - secondEndpoint.x) > 0.0001 then
                return firstEndpoint.x < secondEndpoint.x
            end
            return firstEndpoint.y < secondEndpoint.y
        end

        if math.abs(firstEndpoint.y - secondEndpoint.y) > 0.0001 then
            return firstEndpoint.y < secondEndpoint.y
        end
        return firstEndpoint.x < secondEndpoint.x
    end)
end

function buildOutputRoutesByEndpoint(editorData, junctionData)
    local routesByEndpoint = {}

    for _, routeId in ipairs(junctionData.routes or {}) do
        local route = getRouteById(editorData, routeId)
        if route and route.endEndpointId then
            routesByEndpoint[route.endEndpointId] = routesByEndpoint[route.endEndpointId] or {}
            routesByEndpoint[route.endEndpointId][#routesByEndpoint[route.endEndpointId] + 1] = route
        end
    end

    return routesByEndpoint
end

function sortEdgesByStart(edges)
    table.sort(edges, function(a, b)
        local firstPoint = (a.points or {})[1] or { x = 0, y = 0 }
        local secondPoint = (b.points or {})[1] or { x = 0, y = 0 }
        if math.abs(firstPoint.x - secondPoint.x) > 0.0001 then
            return firstPoint.x < secondPoint.x
        end
        if math.abs(firstPoint.y - secondPoint.y) > 0.0001 then
            return firstPoint.y < secondPoint.y
        end
        return (a.id or "") < (b.id or "")
    end)
end

function sortEdgesByEnd(edges)
    table.sort(edges, function(a, b)
        local firstPoints = a.points or {}
        local secondPoints = b.points or {}
        local firstPoint = firstPoints[#firstPoints] or { x = 0, y = 0 }
        local secondPoint = secondPoints[#secondPoints] or { x = 0, y = 0 }
        if math.abs(firstPoint.y - secondPoint.y) > 0.0001 then
            return firstPoint.y < secondPoint.y
        end
        if math.abs(firstPoint.x - secondPoint.x) > 0.0001 then
            return firstPoint.x < secondPoint.x
        end
        return (a.id or "") < (b.id or "")
    end)
end

function containsValue(list, expected)
    for _, value in ipairs(list or {}) do
        if value == expected then
            return true
        end
    end
    return false
end

function endpointHasColor(editorData, endpointKind, colorId)
    for _, endpoint in ipairs(editorData and editorData.endpoints or {}) do
        if endpoint.kind == endpointKind and containsValue(endpoint.colors or {}, colorId) then
            return true, endpoint
        end
    end
    return false, nil
end

function getSortedLookupKeys(lookup)
    local keys = {}
    for key, enabled in pairs(lookup or {}) do
        if enabled then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    return keys
end

function buildLegacyAuthoredTrains(startEdgeRecords)
    local trains = {}

    for _, startEdge in pairs(startEdgeRecords) do
        local colorIds = getSortedLookupKeys(startEdge.colors)
        for colorIndex, colorId in ipairs(colorIds) do
            trains[#trains + 1] = {
                id = string.format("%s_train_%s_%d", startEdge.edgeId, colorId, colorIndex),
                lineColor = colorId,
                trainColor = colorId,
                spawnTime = (LEGACY_TRAIN_OFFSET + (colorIndex - 1) * LEGACY_TRAIN_SPACING) / LEGACY_TRAIN_SPEED,
                wagonCount = DEFAULT_WAGON_COUNT,
                deadline = nil,
            }
        end
    end

    table.sort(trains, function(a, b)
        if math.abs((a.spawnTime or 0) - (b.spawnTime or 0)) > 0.0001 then
            return (a.spawnTime or 0) < (b.spawnTime or 0)
        end
        if a.trainColor ~= b.trainColor then
            return tostring(a.trainColor) < tostring(b.trainColor)
        end
        return tostring(a.id) < tostring(b.id)
    end)

    return trains
end

function edgeSupportsGoalColor(edge, goalColor)
    if containsValue(edge and edge.colors or {}, goalColor) then
        return true
    end

    if edge and edge.adoptInputColor and containsValue(edge.inputColors or {}, goalColor) then
        return true
    end

    return false
end

function addOutputColors(outputColorLookup, edge, sourceEndpoint, targetEndpoint)
    for _, colorId in ipairs(targetEndpoint and (targetEndpoint.colors or {}) or edge and edge.colors or {}) do
        outputColorLookup[colorId] = true
    end

    if edge and edge.adoptInputColor then
        for _, colorId in ipairs(sourceEndpoint and (sourceEndpoint.colors or {}) or edge.inputColors or {}) do
            outputColorLookup[colorId] = true
        end
    end
end

function canReachGoalColor(startEdgeId, goalColor, edgeById, junctionLookup)
    if not startEdgeId or not goalColor then
        return false
    end

    local queue = { startEdgeId }
    local visited = {}
    local index = 1

    while index <= #queue do
        local edgeId = queue[index]
        index = index + 1

        if not visited[edgeId] then
            visited[edgeId] = true
            local edge = edgeById[edgeId]

            if edge then
                if edge.targetType == "exit" and edgeSupportsGoalColor(edge, goalColor) then
                    return true
                end

                if edge.targetType == "junction" then
                    local junction = junctionLookup[edge.targetId]
                    for _, nextEdgeId in ipairs(junction and junction.outputEdgeIds or {}) do
                        if not visited[nextEdgeId] then
                            queue[#queue + 1] = nextEdgeId
                        end
                    end
                end
            end
        end
    end

    return false
end

end
