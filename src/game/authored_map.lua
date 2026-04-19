local authoredMap = {}
local DEFAULT_WAGON_COUNT = 4
local LEGACY_TRAIN_SPACING = 110
local LEGACY_TRAIN_OFFSET = 70
local LEGACY_TRAIN_SPEED = 168
local roadTypes = require("src.game.road_types")

local COLOR_LOOKUP = {
    blue = { 0.33, 0.80, 0.98 },
    yellow = { 0.98, 0.82, 0.34 },
    mint = { 0.40, 0.92, 0.76 },
    rose = { 0.98, 0.48, 0.62 },
    orange = { 0.98, 0.70, 0.28 },
    violet = { 0.82, 0.56, 0.98 },
}

local DEFAULT_CONTROL_CONFIGS = {
    direct = {
        label = "Direct Lever",
    },
    delayed = {
        label = "Delayed Button",
        delay = 2.25,
    },
    pump = {
        label = "Charge Lever",
        target = 7,
        decayDelay = 0.55,
        decayInterval = 0.2,
    },
    spring = {
        label = "Spring Switch",
        holdTime = 1.6,
    },
    relay = {
        label = "Relay Dial",
    },
    trip = {
        label = "Trip Switch",
        passCount = 1,
    },
    crossbar = {
        label = "Crossbar Dial",
    },
}

local function distanceSquared(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by
    return dx * dx + dy * dy
end

local function segmentLength(a, b)
    local dx = b.x - a.x
    local dy = b.y - a.y
    return math.sqrt(dx * dx + dy * dy)
end

local function copyPoint(point)
    return { x = point.x, y = point.y }
end

local function copyColor(color)
    return { color[1], color[2], color[3] }
end

local function getColor(colorId)
    return copyColor(COLOR_LOOKUP[colorId] or COLOR_LOOKUP.blue)
end

local function darkerColor(color)
    return {
        color[1] * 0.42,
        color[2] * 0.42,
        color[3] * 0.42,
    }
end

local function copyControlConfig(controlType)
    local config = DEFAULT_CONTROL_CONFIGS[controlType] or DEFAULT_CONTROL_CONFIGS.direct
    local copy = {}

    for key, value in pairs(config) do
        copy[key] = value
    end

    copy.type = controlType or "direct"
    return copy
end

local function closestPointOnSegment(px, py, a, b)
    local abX = b.x - a.x
    local abY = b.y - a.y
    local lengthSquared = abX * abX + abY * abY

    if lengthSquared <= 0.0000001 then
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

local function interpolatePoint(a, b, t)
    return {
        x = a.x + (b.x - a.x) * t,
        y = a.y + (b.y - a.y) * t,
    }
end

local function pointOnSegment(point, a, b, toleranceSquared)
    local closestX, closestY, _, distance = closestPointOnSegment(point.x, point.y, a, b)
    if distance <= (toleranceSquared or 0.000004) then
        return { x = closestX, y = closestY }
    end
    return nil
end

local function splitRouteAtPoint(routePoints, junctionPoint)
    local prefix = { copyPoint(routePoints[1]) }

    for pointIndex = 1, #routePoints - 1 do
        local a = routePoints[pointIndex]
        local b = routePoints[pointIndex + 1]
        local hitPoint = pointOnSegment(junctionPoint, a, b)

        if hitPoint then
            if distanceSquared(prefix[#prefix].x, prefix[#prefix].y, hitPoint.x, hitPoint.y) > 0.0000001 then
                prefix[#prefix + 1] = hitPoint
            end
            return prefix
        end

        prefix[#prefix + 1] = copyPoint(b)
    end

    return nil
end

local function splitRouteSuffixAtPoint(routePoints, junctionPoint)
    for pointIndex = 1, #routePoints - 1 do
        local a = routePoints[pointIndex]
        local b = routePoints[pointIndex + 1]
        local hitPoint = pointOnSegment(junctionPoint, a, b)

        if hitPoint then
            local suffix = { hitPoint }
            if distanceSquared(hitPoint.x, hitPoint.y, b.x, b.y) > 0.0000001 then
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

local function findDistanceAlongRoute(routePoints, point)
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

local function extractRouteSegment(routePoints, startDistance, endDistance)
    local segmentPoints = {}
    local totalDistance = 0
    local epsilon = 0.0000001

    for pointIndex = 1, #routePoints - 1 do
        local a = routePoints[pointIndex]
        local b = routePoints[pointIndex + 1]
        local length = segmentLength(a, b)
        local segmentStart = totalDistance
        local segmentEnd = totalDistance + length

        if endDistance < segmentStart - epsilon then
            break
        end

        if startDistance <= segmentEnd + epsilon and endDistance >= segmentStart - epsilon and length > epsilon then
            local localStart = math.max(0, startDistance - segmentStart)
            local localEnd = math.min(length, endDistance - segmentStart)
            local startPoint = interpolatePoint(a, b, localStart / length)
            local endPoint = interpolatePoint(a, b, localEnd / length)

            if #segmentPoints == 0
                or distanceSquared(segmentPoints[#segmentPoints].x, segmentPoints[#segmentPoints].y, startPoint.x, startPoint.y) > epsilon then
                segmentPoints[#segmentPoints + 1] = startPoint
            end

            if distanceSquared(segmentPoints[#segmentPoints].x, segmentPoints[#segmentPoints].y, endPoint.x, endPoint.y) > epsilon then
                segmentPoints[#segmentPoints + 1] = endPoint
            end
        end

        totalDistance = segmentEnd
    end

    return segmentPoints
end

local function pointsRoughlyMatch(firstPoints, secondPoints, tolerance)
    if #firstPoints ~= #secondPoints then
        return false
    end

    local toleranceSquared = (tolerance or 0.001) * (tolerance or 0.001)
    for index = 1, #firstPoints do
        if distanceSquared(firstPoints[index].x, firstPoints[index].y, secondPoints[index].x, secondPoints[index].y) > toleranceSquared then
            return false
        end
    end

    return true
end

local function getEndpointById(editorData, endpointId)
    for _, endpoint in ipairs(editorData.endpoints or {}) do
        if endpoint.id == endpointId then
            return endpoint
        end
    end
    return nil
end

local function getRouteById(editorData, routeId)
    for _, route in ipairs(editorData.routes or {}) do
        if route.id == routeId then
            return route
        end
    end
    return nil
end

local function getRouteSegmentRoadTypes(route)
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

local function buildRouteStyleSections(route, startDistance, endDistance)
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

local function styleSectionsRoughlyMatch(firstSections, secondSections, tolerance)
    if #firstSections ~= #secondSections then
        return false
    end

    local epsilon = tolerance or 0.001
    for sectionIndex = 1, #firstSections do
        local firstSection = firstSections[sectionIndex]
        local secondSection = secondSections[sectionIndex]
        if firstSection.roadType ~= secondSection.roadType then
            return false
        end
        if math.abs(firstSection.startRatio - secondSection.startRatio) > epsilon then
            return false
        end
        if math.abs(firstSection.endRatio - secondSection.endRatio) > epsilon then
            return false
        end
    end

    return true
end

local function sortRouteIdsByMagnet(editorData, routeIds, magnetKind)
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

local function buildOutputRoutesByEndpoint(editorData, junctionData)
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

local function roundPointKey(point)
    return string.format("%.4f:%.4f", point.x, point.y)
end

local function buildEdgeKey(edge)
    local parts = {
        edge.sourceType or "unknown",
        edge.sourceId or "none",
        edge.targetType or "unknown",
        edge.targetId or "none",
    }

    for _, point in ipairs(edge.points or {}) do
        parts[#parts + 1] = roundPointKey(point)
    end

    return table.concat(parts, "|")
end

local function sortEdgesByStart(edges)
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

local function sortEdgesByEnd(edges)
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

local function containsValue(list, expected)
    for _, value in ipairs(list or {}) do
        if value == expected then
            return true
        end
    end
    return false
end

local function getSortedLookupKeys(lookup)
    local keys = {}
    for key, enabled in pairs(lookup or {}) do
        if enabled then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    return keys
end

local function buildLegacyAuthoredTrains(startEdgeRecords)
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

local function edgeSupportsGoalColor(edge, goalColor)
    return containsValue(edge and edge.colors or {}, goalColor)
end

local function canReachGoalColor(startEdgeId, goalColor, edgeById, junctionLookup)
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

function authoredMap.validateEditorMap(mapName, editorData)
    local errors = {}

    if not editorData or #(editorData.junctions or {}) == 0 then
        errors[#errors + 1] = "Add at least one lever intersection before starting this map."
        return nil, errors, errors[1]
    end

    local junctionLookup = {}
    local orderedJunctions = {}
    local routeJunctions = {}

    for junctionIndex, junctionData in ipairs(editorData.junctions or {}) do
        local junctionId = junctionData.id or ("saved_junction_" .. junctionIndex)
        local junction = {
            id = junctionId,
            x = junctionData.x,
            y = junctionData.y,
            activeInputIndex = junctionData.activeInputIndex or 1,
            activeOutputIndex = junctionData.activeOutputIndex or 1,
            control = copyControlConfig(junctionData.control or "direct"),
            inputEdgeIds = {},
            outputEdgeIds = {},
        }

        if junctionData.passCount then
            junction.control.passCount = junctionData.passCount
        end

        junctionLookup[junctionId] = junction
        orderedJunctions[#orderedJunctions + 1] = junction

        for _, routeId in ipairs(junctionData.routes or {}) do
            routeJunctions[routeId] = routeJunctions[routeId] or {}
            routeJunctions[routeId][#routeJunctions[routeId] + 1] = {
                junctionId = junctionId,
                point = { x = junctionData.x, y = junctionData.y },
            }
        end
    end

    local edgeLookup = {}
    local startEdgeRecords = {}
    local lineColorToEdgeId = {}
    local outputColorLookup = {}
    local duplicateInputColorErrors = {}

    for _, route in ipairs(editorData.routes or {}) do
        local routeHits = routeJunctions[route.id] or {}
        if #routeHits == 0 then
            errors[#errors + 1] = string.format("Route '%s' is not attached to a playable junction.", route.label or route.id)
            goto continue_route
        end

        for _, hit in ipairs(routeHits) do
            local distanceAlongRoute, snappedPoint = findDistanceAlongRoute(route.points or {}, hit.point)
            if not distanceAlongRoute then
                errors[#errors + 1] = string.format("Route '%s' did not actually reach a detected junction.", route.label or route.id)
                goto continue_route
            end
            hit.distance = distanceAlongRoute
            hit.point = snappedPoint
        end

        table.sort(routeHits, function(first, second)
            return first.distance < second.distance
        end)

        local routeTotalLength = 0
        for pointIndex = 1, #(route.points or {}) - 1 do
            routeTotalLength = routeTotalLength + segmentLength(route.points[pointIndex], route.points[pointIndex + 1])
        end

        local nodes = {
            {
                kind = "start",
                id = route.startEndpointId,
                point = copyPoint((route.points or {})[1]),
                distance = 0,
            },
        }

        for _, hit in ipairs(routeHits) do
            nodes[#nodes + 1] = {
                kind = "junction",
                id = hit.junctionId,
                point = copyPoint(hit.point),
                distance = hit.distance,
            }
        end

        nodes[#nodes + 1] = {
            kind = "exit",
            id = route.endEndpointId,
            point = copyPoint((route.points or {})[#(route.points or {})]),
            distance = routeTotalLength,
        }

        for nodeIndex = 1, #nodes - 1 do
            local sourceNode = nodes[nodeIndex]
            local targetNode = nodes[nodeIndex + 1]
            local points = extractRouteSegment(route.points or {}, sourceNode.distance, targetNode.distance)

            if #points < 2 then
                errors[#errors + 1] = string.format("Route '%s' contains a zero-length segment near a junction.", route.label or route.id)
                goto continue_route
            end

            local targetEndpoint = targetNode.kind == "exit" and getEndpointById(editorData, targetNode.id) or nil
            local sourceEndpoint = sourceNode.kind == "start" and getEndpointById(editorData, sourceNode.id) or nil
            local styleSections = buildRouteStyleSections(route, sourceNode.distance, targetNode.distance)
            local primaryRoadType = styleSections[1] and styleSections[1].roadType or roadTypes.DEFAULT_ID
            local edge = {
                id = string.format("%s_segment_%d", route.id, nodeIndex),
                label = string.format("%s Segment %d", route.label or route.id, nodeIndex),
                routeId = route.id,
                roadType = primaryRoadType,
                speedScale = roadTypes.getConfig(primaryRoadType).speedScale,
                styleSections = styleSections,
                points = points,
                color = getColor(route.color),
                darkColor = darkerColor(getColor(route.color)),
                colors = targetEndpoint and (targetEndpoint.colors or {}) or sourceEndpoint and (sourceEndpoint.colors or {}) or {},
                adoptInputColor = targetEndpoint and #(targetEndpoint.colors or {}) > 1 or false,
                sourceType = sourceNode.kind,
                sourceId = sourceNode.id,
                targetType = targetNode.kind,
                targetId = targetNode.id,
            }

            local edgeKey = buildEdgeKey(edge)
            local existingEdge = edgeLookup[edgeKey]
            if existingEdge then
                if not pointsRoughlyMatch(existingEdge.points, edge.points) then
                    errors[#errors + 1] = "Merged tracks must share the same path between their nodes."
                    goto continue_route
                end
                if not styleSectionsRoughlyMatch(existingEdge.styleSections or {}, edge.styleSections or {}) then
                    errors[#errors + 1] = "Merged tracks must use the same road style profile."
                    goto continue_route
                end
                edge = existingEdge
            else
                edgeLookup[edgeKey] = edge
            end

            if sourceNode.kind == "junction" then
                local sourceJunction = junctionLookup[sourceNode.id]
                sourceJunction.outputEdgeIds[#sourceJunction.outputEdgeIds + 1] = edge.id
            end
            if targetNode.kind == "junction" then
                local targetJunction = junctionLookup[targetNode.id]
                targetJunction.inputEdgeIds[#targetJunction.inputEdgeIds + 1] = edge.id
            end
            if sourceNode.kind == "start" and targetNode.kind == "junction" then
                startEdgeRecords[edge.id] = startEdgeRecords[edge.id] or {
                    edgeId = edge.id,
                    colors = {},
                }
                for _, colorId in ipairs(sourceEndpoint and (sourceEndpoint.colors or {}) or {}) do
                    startEdgeRecords[edge.id].colors[colorId] = true
                    if lineColorToEdgeId[colorId] and lineColorToEdgeId[colorId] ~= edge.id then
                        if not duplicateInputColorErrors[colorId] then
                            duplicateInputColorErrors[colorId] = true
                            errors[#errors + 1] = string.format("Input color '%s' is used on more than one source line.", colorId)
                        end
                    else
                        lineColorToEdgeId[colorId] = edge.id
                    end
                end
            elseif targetNode.kind == "exit" then
                for _, colorId in ipairs(targetEndpoint and (targetEndpoint.colors or {}) or {}) do
                    outputColorLookup[colorId] = true
                end
            end
        end

        ::continue_route::
    end

    local edges = {}
    for _, edge in pairs(edgeLookup) do
        edges[#edges + 1] = edge
    end
    table.sort(edges, function(a, b)
        return a.id < b.id
    end)

    local edgeById = {}
    for _, edge in ipairs(edges) do
        edgeById[edge.id] = edge
    end

    for _, junction in ipairs(orderedJunctions) do
        local inputEdges = {}
        local outputEdges = {}
        local uniqueInputLookup = {}
        local uniqueOutputLookup = {}

        for _, edgeId in ipairs(junction.inputEdgeIds) do
            if not uniqueInputLookup[edgeId] then
                uniqueInputLookup[edgeId] = true
                inputEdges[#inputEdges + 1] = edgeById[edgeId]
            end
        end
        for _, edgeId in ipairs(junction.outputEdgeIds) do
            if not uniqueOutputLookup[edgeId] then
                uniqueOutputLookup[edgeId] = true
                outputEdges[#outputEdges + 1] = edgeById[edgeId]
            end
        end

        sortEdgesByStart(inputEdges)
        sortEdgesByEnd(outputEdges)

        if #inputEdges > 5 or #outputEdges > 5 then
            errors[#errors + 1] = "A junction exceeds the current limit of five inputs or five outputs."
        end

        if #inputEdges == 0 or #outputEdges == 0 then
            errors[#errors + 1] = "A playable junction needs at least one input and one output."
        end

        junction.inputEdgeIds = {}
        junction.outputEdgeIds = {}
        for _, edge in ipairs(inputEdges) do
            junction.inputEdgeIds[#junction.inputEdgeIds + 1] = edge.id
        end
        for _, edge in ipairs(outputEdges) do
            junction.outputEdgeIds[#junction.outputEdgeIds + 1] = edge.id
        end
        junction.activeInputIndex = math.min(junction.activeInputIndex, math.max(1, #junction.inputEdgeIds))
        junction.activeOutputIndex = math.min(junction.activeOutputIndex, math.max(1, #junction.outputEdgeIds))
    end

    local authoredTrains = editorData.trains
    if not authoredTrains or #authoredTrains == 0 then
        authoredTrains = buildLegacyAuthoredTrains(startEdgeRecords)
    end

    local trains = {}
    local timeLimit = editorData.timeLimit
    for trainIndex, trainData in ipairs(authoredTrains or {}) do
        local lineColor = trainData.lineColor
        local trainColor = trainData.trainColor
        local spawnTime = tonumber(trainData.spawnTime or 0) or 0
        local wagonCount = math.floor(tonumber(trainData.wagonCount or DEFAULT_WAGON_COUNT) or DEFAULT_WAGON_COUNT)
        local deadline = trainData.deadline ~= nil and (tonumber(trainData.deadline) or 0) or nil

        if spawnTime < 0 then
            errors[#errors + 1] = string.format("Train %d has a negative spawn time.", trainIndex)
        end
        if wagonCount < 1 then
            errors[#errors + 1] = string.format("Train %d needs at least one wagon.", trainIndex)
        end
        if deadline ~= nil and deadline < spawnTime then
            errors[#errors + 1] = string.format("Train %d has a deadline earlier than its spawn time.", trainIndex)
        end
        if timeLimit ~= nil and deadline ~= nil and deadline > timeLimit then
            errors[#errors + 1] = string.format("Train %d has a deadline after the map deadline.", trainIndex)
        end
        if not lineColorToEdgeId[lineColor] then
            errors[#errors + 1] = string.format("Train %d uses source color '%s', but no matching input line exists.", trainIndex, tostring(lineColor))
        end
        if not outputColorLookup[trainColor] then
            errors[#errors + 1] = string.format("Train %d targets color '%s', but no matching output exists.", trainIndex, tostring(trainColor))
        end
        if lineColorToEdgeId[lineColor]
            and outputColorLookup[trainColor]
            and not canReachGoalColor(lineColorToEdgeId[lineColor], trainColor, edgeById, junctionLookup) then
            errors[#errors + 1] = string.format(
                "Train %d cannot reach goal color '%s' from source line '%s'.",
                trainIndex,
                tostring(trainColor),
                tostring(lineColor)
            )
        end

        trains[#trains + 1] = {
            id = trainData.id or string.format("train_%d", trainIndex),
            edgeId = lineColorToEdgeId[lineColor],
            lineColor = lineColor,
            trainColor = trainColor,
            goalColor = trainColor,
            spawnTime = spawnTime,
            wagonCount = wagonCount,
            deadline = deadline,
            color = getColor(trainColor),
        }
    end

    if #errors > 0 then
        return nil, errors, table.concat(errors, " ")
    end

    return {
        title = mapName,
        description = "Custom map loaded from the editor.",
        hint = "Click the junction center to switch inputs. Use the bottom selector to switch outputs.",
        footer = "Sequence trains from the editor pane and clear every goal on time.",
        timeLimit = timeLimit,
        junctions = orderedJunctions,
        edges = edges,
        trains = trains,
    }, {}, nil
end

function authoredMap.buildPlayableLevel(mapName, editorData)
    local level, errors, errorText = authoredMap.validateEditorMap(mapName, editorData)
    return level, errorText, errors
end

return authoredMap
