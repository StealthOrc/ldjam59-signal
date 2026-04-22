local world = {}
world.__index = world
local COLOR_OPTIONS = {
    { id = "blue", color = { 0.33, 0.8, 0.98 } },
    { id = "yellow", color = { 0.98, 0.82, 0.34 } },
    { id = "mint", color = { 0.4, 0.92, 0.76 } },
    { id = "rose", color = { 0.98, 0.48, 0.62 } },
    { id = "orange", color = { 0.98, 0.7, 0.28 } },
    { id = "violet", color = { 0.82, 0.56, 0.98 } },
}

local RELAY_FLASH_DURATION = 0.28
local TRIP_FLASH_DURATION = 0.28
local CROSSBAR_FLASH_DURATION = 0.28
local SPRING_RELEASE_DURATION = 0.42
local ICON_PRESS_STIFFNESS = 118
local ICON_PRESS_DAMPING = 15
local ICON_PRESS_IMPULSE = 15
local roadTypes = require("src.game.data.road_types")
local trackSceneRenderer = require("src.game.rendering.track_scene_renderer")
local ROAD_PATTERN_OUTLINE = { 0.04, 0.05, 0.07, 0.98 }
local ROAD_PATTERN_FILL = { 0.97, 0.98, 1.0, 0.94 }
local TRACK_STRIPE_LENGTH = 14

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function segmentLength(a, b)
    local dx = b.x - a.x
    local dy = b.y - a.y
    return math.sqrt(dx * dx + dy * dy)
end

local function normalize(dx, dy)
    local length = math.sqrt(dx * dx + dy * dy)
    if length <= 0.0001 then
        return 0, 1
    end
    return dx / length, dy / length
end

local function distanceSquared(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by
    return dx * dx + dy * dy
end

local function dot(ax, ay, bx, by)
    return ax * bx + ay * by
end

local function getEdgeDirectionNearJunction(edge, mergePoint, startsAtJunction)
    local points = edge and edge.path and edge.path.points or nil
    if not points or #points <= 0 or not mergePoint then
        return nil, nil
    end

    local anchorIndex = startsAtJunction and 1 or #points
    local step = startsAtJunction and 1 or -1
    local anchor = points[anchorIndex]
    local baseX = anchor and anchor.x or mergePoint.x
    local baseY = anchor and anchor.y or mergePoint.y

    for index = anchorIndex + step, startsAtJunction and #points or 1, step do
        local point = points[index]
        if point then
            local dx = point.x - baseX
            local dy = point.y - baseY
            local lengthSquared = dx * dx + dy * dy
            if lengthSquared > 0.0001 then
                return normalize(dx, dy)
            end
        end
    end

    return nil, nil
end

local function getEdgeOuterPoint(edge, mergePoint)
    local points = edge and edge.path and edge.path.points or nil
    if not points or #points <= 0 then
        return nil
    end

    local bestPoint = nil
    local bestDistance = -1
    local baseX = mergePoint and mergePoint.x or 0
    local baseY = mergePoint and mergePoint.y or 0

    for _, point in ipairs(points) do
        local distance = distanceSquared(point.x, point.y, baseX, baseY)
        if distance > bestDistance + 0.0001 then
            bestDistance = distance
            bestPoint = point
        end
    end

    return bestPoint
end

local function getRelayFallbackOutputIndex(junction, inputIndex)
    return clamp(inputIndex, 1, math.max(1, #(junction and junction.outputs or {})))
end

local function getCrossbarFallbackOutputIndex(junction, inputIndex)
    local outputCount = math.max(1, #(junction and junction.outputs or {}))
    return clamp(outputCount - inputIndex + 1, 1, outputCount)
end

local function compareEdgeOuterPoint(a, b)
    if not a and not b then
        return false
    end
    if not a then
        return false
    end
    if not b then
        return true
    end

    local xDiff = math.abs((a.outerPoint.x or 0) - (b.outerPoint.x or 0))
    if xDiff > 0.0001 then
        return (a.outerPoint.x or 0) < (b.outerPoint.x or 0)
    end

    local yDiff = math.abs((a.outerPoint.y or 0) - (b.outerPoint.y or 0))
    if yDiff > 0.0001 then
        return (a.outerPoint.y or 0) < (b.outerPoint.y or 0)
    end

    return (a.index or 0) < (b.index or 0)
end

local function buildSortedEntries(edges, mergePoint)
    local entries = {}

    for index, edge in ipairs(edges or {}) do
        entries[#entries + 1] = {
            index = index,
            edge = edge,
            outerPoint = getEdgeOuterPoint(edge, mergePoint),
        }
    end

    table.sort(entries, compareEdgeOuterPoint)
    return entries
end

local function angleFromMerge(point, mergePoint)
    if not point or not mergePoint then
        return 0
    end

    local dx = (point.x or 0) - mergePoint.x
    local dy = (point.y or 0) - mergePoint.y
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

local function compareEdgeCycleOrder(a, b)
    if not a and not b then
        return false
    end
    if not a then
        return false
    end
    if not b then
        return true
    end

    local angleDiff = math.abs((a.angle or 0) - (b.angle or 0))
    if angleDiff > 0.0001 then
        return (a.angle or 0) < (b.angle or 0)
    end

    return compareEdgeOuterPoint(a, b)
end

local function buildCycleEntries(edges, mergePoint)
    local entries = {}

    for index, edge in ipairs(edges or {}) do
        local outerPoint = getEdgeOuterPoint(edge, mergePoint)
        entries[#entries + 1] = {
            index = index,
            edge = edge,
            outerPoint = outerPoint,
            angle = angleFromMerge(outerPoint, mergePoint),
        }
    end

    table.sort(entries, compareEdgeCycleOrder)
    return entries
end

local function getNextCycledInputIndex(junction)
    local cycleEntries = buildCycleEntries(junction and junction.inputs or {}, junction and junction.mergePoint or nil)
    if #cycleEntries <= 1 then
        return 1
    end

    for orderIndex, entry in ipairs(cycleEntries) do
        if entry.index == junction.activeInputIndex then
            local nextEntry = cycleEntries[orderIndex + 1] or cycleEntries[1]
            return nextEntry.index
        end
    end

    return cycleEntries[1].index
end

local function getDirectionalOutputIndex(junction, inputIndex, controlType)
    local outputs = junction and junction.outputs or {}
    local inputs = junction and junction.inputs or {}
    local inputEdge = inputs[inputIndex]
    if not inputEdge or #outputs <= 0 then
        return 1
    end

    local sortedInputs = buildSortedEntries(inputs, junction.mergePoint)
    local sortedOutputs = buildSortedEntries(outputs, junction.mergePoint)
    local inputRank = nil
    for rank, entry in ipairs(sortedInputs) do
        if entry.index == inputIndex then
            inputRank = rank
            break
        end
    end

    if inputRank and #sortedOutputs > 0 then
        local targetRank = inputRank
        if controlType == "crossbar" then
            targetRank = #sortedOutputs - inputRank + 1
        end
        targetRank = clamp(targetRank, 1, #sortedOutputs)
        return sortedOutputs[targetRank].index
    end

    local inputDirX, inputDirY = getEdgeDirectionNearJunction(inputEdge, junction.mergePoint, false)
    if not inputDirX or not inputDirY then
        if controlType == "crossbar" then
            return getCrossbarFallbackOutputIndex(junction, inputIndex)
        end
        return getRelayFallbackOutputIndex(junction, inputIndex)
    end

    local targetX = inputDirX
    local targetY = -inputDirY
    if controlType == "crossbar" then
        targetX = -inputDirX
        targetY = -inputDirY
    end

    local inputOuterPoint = getEdgeOuterPoint(inputEdge, junction.mergePoint)
    local targetPointX = nil
    local targetPointY = nil
    if inputOuterPoint then
        targetPointX = inputOuterPoint.x
        targetPointY = (junction.mergePoint.y * 2) - inputOuterPoint.y
        if controlType == "crossbar" then
            targetPointX = (junction.mergePoint.x * 2) - inputOuterPoint.x
        end
    end

    local bestIndex = nil
    local bestDistance = math.huge
    local bestScore = -math.huge
    for outputIndex, outputEdge in ipairs(outputs) do
        local outputDirX, outputDirY = getEdgeDirectionNearJunction(outputEdge, junction.mergePoint, true)
        if outputDirX and outputDirY then
            local score = dot(targetX, targetY, outputDirX, outputDirY)
            local distance = math.huge
            local outputOuterPoint = getEdgeOuterPoint(outputEdge, junction.mergePoint)
            if targetPointX and targetPointY and outputOuterPoint then
                distance = distanceSquared(outputOuterPoint.x, outputOuterPoint.y, targetPointX, targetPointY)
            end

            if distance + 0.0001 < bestDistance
                or (math.abs(distance - bestDistance) <= 0.0001 and score > bestScore + 0.0001) then
                bestDistance = distance
                bestScore = score
                bestIndex = outputIndex
            end
        end
    end

    if bestIndex then
        return bestIndex
    end

    if controlType == "crossbar" then
        return getCrossbarFallbackOutputIndex(junction, inputIndex)
    end
    return getRelayFallbackOutputIndex(junction, inputIndex)
end

local function carriagesOverlap(firstCar, secondCar, carriageLength, carriageHeight)
    local halfLength = (carriageLength or 0) * 0.5
    local halfHeight = (carriageHeight or 0) * 0.5
    local firstForwardX = math.cos(firstCar.angle or 0)
    local firstForwardY = math.sin(firstCar.angle or 0)
    local firstSideX = -firstForwardY
    local firstSideY = firstForwardX
    local secondForwardX = math.cos(secondCar.angle or 0)
    local secondForwardY = math.sin(secondCar.angle or 0)
    local secondSideX = -secondForwardY
    local secondSideY = secondForwardX
    local offsetX = (secondCar.x or 0) - (firstCar.x or 0)
    local offsetY = (secondCar.y or 0) - (firstCar.y or 0)
    local axes = {
        { x = firstForwardX, y = firstForwardY },
        { x = firstSideX, y = firstSideY },
        { x = secondForwardX, y = secondForwardY },
        { x = secondSideX, y = secondSideY },
    }

    for _, axis in ipairs(axes) do
        local centerDistance = math.abs(dot(offsetX, offsetY, axis.x, axis.y))
        local firstExtent = halfLength * math.abs(dot(firstForwardX, firstForwardY, axis.x, axis.y))
            + halfHeight * math.abs(dot(firstSideX, firstSideY, axis.x, axis.y))
        local secondExtent = halfLength * math.abs(dot(secondForwardX, secondForwardY, axis.x, axis.y))
            + halfHeight * math.abs(dot(secondSideX, secondSideY, axis.x, axis.y))

        if centerDistance > firstExtent + secondExtent then
            return false
        end
    end

    return true
end

local function copyPoint(point)
    return { x = point.x, y = point.y }
end

local function copyColor(color)
    if not color then
        return { 0.8, 0.8, 0.8 }
    end

    return { color[1], color[2], color[3] }
end

local function darkerColor(color)
    return {
        color[1] * 0.42,
        color[2] * 0.42,
        color[3] * 0.42,
    }
end

local function nearestColorId(color)
    if not color then
        return COLOR_OPTIONS[1].id
    end

    local bestId = COLOR_OPTIONS[1].id
    local bestDistance = math.huge
    for _, option in ipairs(COLOR_OPTIONS) do
        local dx = (color[1] or 0) - option.color[1]
        local dy = (color[2] or 0) - option.color[2]
        local dz = (color[3] or 0) - option.color[3]
        local distance = dx * dx + dy * dy + dz * dz
        if distance < bestDistance then
            bestDistance = distance
            bestId = option.id
        end
    end
    return bestId
end

local function getColorById(colorId)
    for _, option in ipairs(COLOR_OPTIONS) do
        if option.id == colorId then
            return copyColor(option.color)
        end
    end
    return copyColor(COLOR_OPTIONS[1].color)
end

local function buildTrackStripeColors(colorIds, isActive)
    if #(colorIds or {}) <= 1 then
        return nil
    end

    local brightness = isActive and 1 or 0.58
    local colors = {}
    for _, colorId in ipairs(colorIds or {}) do
        local color = getColorById(colorId)
        colors[#colors + 1] = {
            color[1] * brightness,
            color[2] * brightness,
            color[3] * brightness,
        }
    end

    return colors
end

local function containsColorId(colors, colorId)
    for _, candidate in ipairs(colors or {}) do
        if candidate == colorId then
            return true
        end
    end
    return false
end

local function formatColorLabel(colorId)
    if not colorId then
        return "Unknown"
    end
    return colorId:sub(1, 1):upper() .. colorId:sub(2)
end

local function getRoadTypeScale(roadType, explicitScale)
    if explicitScale then
        return explicitScale
    end

    return roadTypes.getConfig(roadType).speedScale
end

local function normalizeStyleSections(styleSections, totalLength, fallbackRoadType, fallbackSpeedScale)
    local normalizedSections = {}
    local clampedLength = math.max(0, totalLength or 0)

    for _, section in ipairs(styleSections or {}) do
        local roadTypeId = roadTypes.normalizeRoadType(section.roadType or fallbackRoadType)
        local startDistance = section.startRatio and (section.startRatio * clampedLength) or section.startDistance or 0
        local endDistance = section.endRatio and (section.endRatio * clampedLength) or section.endDistance or clampedLength
        startDistance = clamp(startDistance, 0, clampedLength)
        endDistance = clamp(endDistance, 0, clampedLength)

        if endDistance > startDistance + 0.0001 then
            normalizedSections[#normalizedSections + 1] = {
                roadType = roadTypeId,
                speedScale = getRoadTypeScale(roadTypeId, section.speedScale),
                startDistance = startDistance,
                endDistance = endDistance,
            }
        end
    end

    if #normalizedSections == 0 then
        local roadTypeId = roadTypes.normalizeRoadType(fallbackRoadType)
        normalizedSections[1] = {
            roadType = roadTypeId,
            speedScale = getRoadTypeScale(roadTypeId, fallbackSpeedScale),
            startDistance = 0,
            endDistance = clampedLength,
        }
    end

    return normalizedSections
end

local function appendUnique(list, lookup, value)
    if value and not lookup[value] then
        lookup[value] = true
        list[#list + 1] = value
    end
end

local function compareScheduledTrains(firstTrain, secondTrain)
    local firstSpawn = firstTrain.spawnTime or 0
    local secondSpawn = secondTrain.spawnTime or 0
    if math.abs(firstSpawn - secondSpawn) > 0.0001 then
        return firstSpawn < secondSpawn
    end

    return tostring(firstTrain.id or "") < tostring(secondTrain.id or "")
end

local function compareEdgesBySource(firstEdge, secondEdge)
    local firstPoint = firstEdge and firstEdge.path and firstEdge.path.points and firstEdge.path.points[1] or { x = 0, y = 0 }
    local secondPoint = secondEdge and secondEdge.path and secondEdge.path.points and secondEdge.path.points[1] or { x = 0, y = 0 }

    if math.abs(firstPoint.x - secondPoint.x) > 0.0001 then
        return firstPoint.x < secondPoint.x
    end
    if math.abs(firstPoint.y - secondPoint.y) > 0.0001 then
        return firstPoint.y < secondPoint.y
    end

    return tostring(firstEdge and firstEdge.id or "") < tostring(secondEdge and secondEdge.id or "")
end

local function compareEdgesByTarget(firstEdge, secondEdge)
    local firstPoints = firstEdge and firstEdge.path and firstEdge.path.points or {}
    local secondPoints = secondEdge and secondEdge.path and secondEdge.path.points or {}
    local firstPoint = firstPoints[#firstPoints] or { x = 0, y = 0 }
    local secondPoint = secondPoints[#secondPoints] or { x = 0, y = 0 }

    if math.abs(firstPoint.y - secondPoint.y) > 0.0001 then
        return firstPoint.y < secondPoint.y
    end
    if math.abs(firstPoint.x - secondPoint.x) > 0.0001 then
        return firstPoint.x < secondPoint.x
    end

    return tostring(firstEdge and firstEdge.id or "") < tostring(secondEdge and secondEdge.id or "")
end

local function denormalizePoints(points, viewportW, viewportH)
    local denormalized = {}

    for _, point in ipairs(points or {}) do
        denormalized[#denormalized + 1] = {
            x = viewportW * point.x,
            y = viewportH * point.y,
        }
    end

    return denormalized
end

local function buildPolyline(points)
    local segments = {}
    local totalLength = 0

    for index = 1, #points - 1 do
        local startPoint = points[index]
        local endPoint = points[index + 1]
        local length = segmentLength(startPoint, endPoint)
        segments[#segments + 1] = {
            a = startPoint,
            b = endPoint,
            startDistance = totalLength,
            length = length,
        }
        totalLength = totalLength + length
    end

    return {
        points = points,
        segments = segments,
        length = totalLength,
    }
end

local function angleBetweenPoints(a, b)
    local dx = b.x - a.x
    local dy = b.y - a.y

    if math.atan2 then
        return math.atan2(dy, dx)
    end

    if dx == 0 then
        if dy >= 0 then
            return math.pi * 0.5
        end
        return -math.pi * 0.5
    end

    local angle = math.atan(dy / dx)
    if dx < 0 then
        angle = angle + math.pi
    end
    return angle
end

local function pointOnPath(path, distance)
    local segments = path.segments
    local first = segments[1]
    local last = segments[#segments]

    if not first then
        local point = path.points[1] or { x = 0, y = 0 }
        return point.x, point.y, 0
    end

    if distance <= 0 then
        local dirX, dirY = normalize(first.b.x - first.a.x, first.b.y - first.a.y)
        return first.a.x + dirX * distance, first.a.y + dirY * distance, angleBetweenPoints(first.a, first.b)
    end

    if distance >= path.length then
        local overflow = distance - path.length
        local dirX, dirY = normalize(last.b.x - last.a.x, last.b.y - last.a.y)
        return last.b.x + dirX * overflow, last.b.y + dirY * overflow, angleBetweenPoints(last.a, last.b)
    end

    for _, segment in ipairs(segments) do
        local endDistance = segment.startDistance + segment.length
        if distance <= endDistance then
            local t = (distance - segment.startDistance) / segment.length
            local x = lerp(segment.a.x, segment.b.x, t)
            local y = lerp(segment.a.y, segment.b.y, t)
            return x, y, angleBetweenPoints(segment.a, segment.b)
        end
    end

    return last.b.x, last.b.y, angleBetweenPoints(last.a, last.b)
end

local function flattenPoints(points)
    local flattened = {}
    for _, point in ipairs(points or {}) do
        flattened[#flattened + 1] = point.x
        flattened[#flattened + 1] = point.y
    end
    return flattened
end

local function combinePointLists(firstPoints, secondPoints)
    local combined = {}

    for _, point in ipairs(firstPoints or {}) do
        combined[#combined + 1] = copyPoint(point)
    end

    for pointIndex, point in ipairs(secondPoints or {}) do
        if pointIndex > 1 or #combined == 0 then
            combined[#combined + 1] = copyPoint(point)
        end
    end

    return combined
end

local function roundScoreValue(value)
    return math.floor((value or 0) + 0.5)
end

local function getTailClearanceDistance(wagonCount, carriageLength, carriageGap)
    return math.max(0, ((wagonCount or 1) - 1) * ((carriageLength or 0) + (carriageGap or 0)))
end

local function pointOnCircle(centerX, centerY, angle, radius)
    return {
        x = centerX + math.cos(angle) * radius,
        y = centerY + math.sin(angle) * radius,
    }
end

local function appendPoint(points, x, y)
    local lastPoint = points[#points]
    if lastPoint and math.abs(lastPoint.x - x) <= 0.001 and math.abs(lastPoint.y - y) <= 0.001 then
        return
    end

    points[#points + 1] = {
        x = x,
        y = y,
    }
end

local function buildPathSlice(path, startDistance, endDistance)
    local points = {}
    local clampedStart = clamp(startDistance or 0, 0, path.length)
    local clampedEnd = clamp(endDistance or path.length, 0, path.length)

    if clampedEnd <= clampedStart then
        local x, y = pointOnPath(path, clampedStart)
        appendPoint(points, x, y)
        return points
    end

    local startX, startY = pointOnPath(path, clampedStart)
    local endX, endY = pointOnPath(path, clampedEnd)
    appendPoint(points, startX, startY)

    for _, segment in ipairs(path.segments) do
        local segmentEndDistance = segment.startDistance + segment.length
        if segmentEndDistance > clampedStart and segmentEndDistance < clampedEnd then
            appendPoint(points, segment.b.x, segment.b.y)
        end
    end

    appendPoint(points, endX, endY)
    return points
end

local function buildCubicCurvePoints(startPoint, controlPointA, controlPointB, endPoint, stepCount)
    local points = {}

    for stepIndex = 0, stepCount do
        local t = stepIndex / stepCount
        local oneMinusT = 1 - t
        local x = oneMinusT ^ 3 * startPoint.x
            + 3 * oneMinusT ^ 2 * t * controlPointA.x
            + 3 * oneMinusT * t ^ 2 * controlPointB.x
            + t ^ 3 * endPoint.x
        local y = oneMinusT ^ 3 * startPoint.y
            + 3 * oneMinusT ^ 2 * t * controlPointA.y
            + 3 * oneMinusT * t ^ 2 * controlPointB.y
            + t ^ 3 * endPoint.y

        points[#points + 1] = { x = x, y = y }
    end

    return points
end

function world.new(viewportW, viewportH, levelSource)
    local self = setmetatable({}, world)

    self.viewport = { w = viewportW, h = viewportH }
    self.trackWidth = 14
    self.sharedWidth = 18
    self.trainSpeed = 168
    self.trainAcceleration = 260
    self.carriageLength = 34
    self.carriageHeight = 18
    self.carriageGap = 12
    self.carriageCount = 4
    self.exitFadeDuration = 0.25
    self.crossingRadius = 40
    self.junctionTrackClearance = self.crossingRadius + 4
    self.collisionPoint = nil
    self.failureReason = nil
    self.timeRemaining = nil
    self.elapsedTime = 0
    self.failureTrain = nil
    self.interactionCount = 0
    self.replayListener = nil
    self.chargeImage = nil
    self.crossImage = nil
    self.directImage = nil
    self.relayImage = nil
    self.springImage = nil
    self.tripImage = nil

    local function loadOptionalImage(path)
        if not (love and love.graphics and love.filesystem and love.filesystem.getInfo(path, "file")) then
            return nil
        end

        local ok, image = pcall(love.graphics.newImage, path)
        if ok and image then
            image:setFilter("linear", "linear")
            return image
        end

        return nil
    end

    self.chargeImage = loadOptionalImage("assets/Charge.png")
    self.crossImage = loadOptionalImage("assets/cross.png")
    self.directImage = loadOptionalImage("assets/direct.png")
    self.relayImage = loadOptionalImage("assets/relay.png")
    self.springImage = loadOptionalImage("assets/spring.png")
    self.tripImage = loadOptionalImage("assets/trip.png")

    self.level = self:normalizeLevel(levelSource or {})

    self.junctions = {}
    self.junctionOrder = {}
    self.trains = {}

    self:initializeLevel()

    return self
end

function world:getLevelCount()
    return 0
end

function world:getLevel()
    return self.level
end

function world:getScoringConstants()
    return {
        onTimeClear = 10,
        lateClear = 5,
        secondsPenalty = 0.25,
        interactionPenalty = 1,
        extraDistancePenalty = 1,
    }
end

function world:normalizeLevel(sourceLevel)
    local normalized = {
        id = sourceLevel.id,
        mapUuid = sourceLevel.mapUuid or sourceLevel.id,
        title = sourceLevel.title,
        description = sourceLevel.description,
        hint = sourceLevel.hint,
        footer = sourceLevel.footer,
        timeLimit = sourceLevel.timeLimit,
        junctions = {},
        edges = {},
        trains = {},
    }

    if sourceLevel.edges then
        for _, edgeDefinition in ipairs(sourceLevel.edges or {}) do
            local color = edgeDefinition.color and copyColor(edgeDefinition.color) or { 0.8, 0.8, 0.8 }
            normalized.edges[#normalized.edges + 1] = {
                id = edgeDefinition.id,
                label = edgeDefinition.label,
                colors = edgeDefinition.colors or {},
                color = color,
                darkColor = edgeDefinition.darkColor and copyColor(edgeDefinition.darkColor) or darkerColor(color),
                -- Authored map routes already carry their accepted endpoint colors, so
                -- older saved maps should not inherit the active input color visually.
                adoptInputColor = edgeDefinition.adoptInputColor == true and edgeDefinition.routeId == nil,
                roadType = roadTypes.normalizeRoadType(edgeDefinition.roadType),
                speedScale = getRoadTypeScale(edgeDefinition.roadType, edgeDefinition.speedScale),
                styleSections = edgeDefinition.styleSections or {},
                points = edgeDefinition.points or {},
                sourceType = edgeDefinition.sourceType,
                sourceId = edgeDefinition.sourceId,
                targetType = edgeDefinition.targetType,
                targetId = edgeDefinition.targetId,
            }
        end

        for _, junctionDefinition in ipairs(sourceLevel.junctions or {}) do
            normalized.junctions[#normalized.junctions + 1] = {
                id = junctionDefinition.id,
                label = junctionDefinition.label,
                activeInputIndex = junctionDefinition.activeInputIndex or 1,
                activeOutputIndex = junctionDefinition.activeOutputIndex or 1,
                control = junctionDefinition.control,
                inputEdgeIds = junctionDefinition.inputEdgeIds or {},
                outputEdgeIds = junctionDefinition.outputEdgeIds or {},
            }
        end

        for _, trainDefinition in ipairs(sourceLevel.trains or {}) do
            local speedScale = trainDefinition.speedScale or 1
            local progress = trainDefinition.progress or 0
            local spawnTime = trainDefinition.spawnTime
            local startProgress = progress

            if spawnTime == nil then
                if progress < 0 then
                    spawnTime = math.abs(progress) / math.max(1, self.trainSpeed * speedScale)
                    startProgress = 0
                else
                    spawnTime = 0
                end
            end

            local trainColor = trainDefinition.trainColor
                or trainDefinition.goalColor
                or nearestColorId(trainDefinition.color)
            normalized.trains[#normalized.trains + 1] = {
                id = trainDefinition.id,
                edgeId = trainDefinition.edgeId,
                lineColor = trainDefinition.lineColor,
                progress = startProgress,
                spawnTime = spawnTime,
                speedScale = trainDefinition.speedScale or 1,
                wagonCount = trainDefinition.wagonCount or self.carriageCount,
                deadline = trainDefinition.deadline,
                goalColor = trainDefinition.goalColor or trainColor,
                trainColor = trainColor,
                color = trainDefinition.color and copyColor(trainDefinition.color) or getColorById(trainColor),
            }
        end

        return normalized
    end

    for _, junctionDefinition in ipairs(sourceLevel.junctions or {}) do
        local definition = junctionDefinition
        if not (definition.inputs and definition.outputs) then
            local mergeX = definition.mergeX or 0.5
            local mergeY = definition.mergeY or 0.5
            local exitY = definition.exitY or 1.25
            local startY = -120 / self.viewport.h
            local bendY = mergeY - 0.22
            local inputs = {}
            local outputs = {}

            for branchIndex, branch in ipairs(definition.branches or {}) do
                local color = copyColor(branch.color)
                inputs[#inputs + 1] = {
                    id = branch.id or ("input_" .. branchIndex),
                    label = branch.label or ("Input " .. branchIndex),
                    color = color,
                    darkColor = copyColor(branch.darkColor or darkerColor(color)),
                    colors = { branch.id or ("input_" .. branchIndex) },
                    inputPoints = branch.branchPoints or {
                        { x = branch.startX or 0.5, y = startY },
                        { x = branch.startX or 0.5, y = bendY },
                        { x = mergeX, y = mergeY },
                    },
                }
            end

            local firstBranch = (definition.branches or {})[1] or {}
            local outputColor = copyColor(firstBranch.color)
            outputs[1] = {
                id = firstBranch.id and (firstBranch.id .. "_output") or ((definition.id or "junction") .. "_output"),
                label = "Output 1",
                color = outputColor,
                darkColor = copyColor(firstBranch.darkColor or darkerColor(outputColor)),
                colors = {},
                adoptInputColor = true,
                outputPoints = firstBranch.sharedPoints or {
                    { x = mergeX, y = mergeY },
                    { x = mergeX, y = exitY },
                },
            }

            definition = {
                id = definition.id,
                label = definition.label,
                activeInputIndex = definition.activeBranch or 1,
                activeOutputIndex = 1,
                control = definition.control,
                inputs = inputs,
                outputs = outputs,
            }
        end

        local normalizedJunction = {
            id = definition.id,
            label = definition.label,
            activeInputIndex = definition.activeInputIndex or 1,
            activeOutputIndex = definition.activeOutputIndex or 1,
            control = definition.control,
            inputEdgeIds = {},
            outputEdgeIds = {},
        }

        for inputIndex, inputDefinition in ipairs(definition.inputs or {}) do
            local inputColor = copyColor(inputDefinition.color)
            local edgeId = string.format("%s_input_%d", definition.id or "junction", inputIndex)
            normalized.edges[#normalized.edges + 1] = {
                id = edgeId,
                label = inputDefinition.label or ("Input " .. inputIndex),
                colors = inputDefinition.colors or {},
                color = inputColor,
                darkColor = copyColor(inputDefinition.darkColor or darkerColor(inputColor)),
                adoptInputColor = false,
                roadType = roadTypes.DEFAULT_ID,
                speedScale = roadTypes.getConfig(roadTypes.DEFAULT_ID).speedScale,
                styleSections = {},
                points = inputDefinition.inputPoints or {},
                sourceType = "start",
                sourceId = edgeId .. "_start",
                targetType = "junction",
                targetId = definition.id,
            }
            normalizedJunction.inputEdgeIds[#normalizedJunction.inputEdgeIds + 1] = edgeId
        end

        for outputIndex, outputDefinition in ipairs(definition.outputs or {}) do
            local outputColor = copyColor(outputDefinition.color)
            local edgeId = string.format("%s_output_%d", definition.id or "junction", outputIndex)
            normalized.edges[#normalized.edges + 1] = {
                id = edgeId,
                label = outputDefinition.label or ("Output " .. outputIndex),
                colors = outputDefinition.colors or {},
                color = outputColor,
                darkColor = copyColor(outputDefinition.darkColor or darkerColor(outputColor)),
                adoptInputColor = outputDefinition.adoptInputColor == true,
                roadType = roadTypes.DEFAULT_ID,
                speedScale = roadTypes.getConfig(roadTypes.DEFAULT_ID).speedScale,
                styleSections = {},
                points = outputDefinition.outputPoints or {},
                sourceType = "junction",
                sourceId = definition.id,
                targetType = "exit",
                targetId = outputDefinition.id or edgeId .. "_exit",
            }
            normalizedJunction.outputEdgeIds[#normalizedJunction.outputEdgeIds + 1] = edgeId
        end

        normalized.junctions[#normalized.junctions + 1] = normalizedJunction
    end

    for _, trainDefinition in ipairs(sourceLevel.trains or {}) do
        local junctionId = trainDefinition.junctionId
        local inputIndex = trainDefinition.inputIndex or trainDefinition.branchIndex or 1
        local speedScale = trainDefinition.speedScale or 1
        local progress = trainDefinition.progress or 0
        local spawnTime = trainDefinition.spawnTime
        local startProgress = progress
        if spawnTime == nil then
            if progress < 0 then
                spawnTime = math.abs(progress) / math.max(1, self.trainSpeed * speedScale)
                startProgress = 0
            else
                spawnTime = 0
            end
        end
        local trainColor = trainDefinition.trainColor
            or trainDefinition.goalColor
            or nearestColorId(trainDefinition.color)
        normalized.trains[#normalized.trains + 1] = {
            id = trainDefinition.id,
            edgeId = string.format("%s_input_%d", junctionId or "junction", inputIndex),
            lineColor = trainDefinition.lineColor,
            progress = startProgress,
            spawnTime = spawnTime,
            speedScale = speedScale,
            wagonCount = trainDefinition.wagonCount or self.carriageCount,
            deadline = trainDefinition.deadline,
            goalColor = trainDefinition.goalColor or trainColor,
            trainColor = trainColor,
            color = trainDefinition.color and copyColor(trainDefinition.color) or getColorById(trainColor),
        }
    end

    return normalized
end

function world:buildEdge(edgeDefinition)
    local color = copyColor(edgeDefinition.color)
    local path = buildPolyline(denormalizePoints(edgeDefinition.points or {}, self.viewport.w, self.viewport.h))
    local signalDistance = math.max(path.length - (self.crossingRadius + 10), 0)
    local stopDistance = math.max(signalDistance - (self.carriageLength + 12), 0)
    local stopX, stopY = pointOnPath(path, stopDistance)
    local signalX, signalY = pointOnPath(path, signalDistance)
    local roadTypeId = roadTypes.normalizeRoadType(edgeDefinition.roadType)
    local speedScale = getRoadTypeScale(roadTypeId, edgeDefinition.speedScale)
    local styleSections = normalizeStyleSections(edgeDefinition.styleSections, path.length, roadTypeId, speedScale)

    return {
        id = edgeDefinition.id,
        label = edgeDefinition.label,
        colors = edgeDefinition.colors or {},
        color = color,
        darkColor = copyColor(edgeDefinition.darkColor or darkerColor(color)),
        adoptInputColor = edgeDefinition.adoptInputColor == true,
        roadType = roadTypeId,
        speedScale = speedScale,
        styleSections = styleSections,
        sourceType = edgeDefinition.sourceType,
        sourceId = edgeDefinition.sourceId,
        targetType = edgeDefinition.targetType,
        targetId = edgeDefinition.targetId,
        path = path,
        signalPoint = { x = signalX, y = signalY },
        stopDistance = stopDistance,
        stopPoint = { x = stopX, y = stopY },
    }
end

function world:buildJunction(definition, existing)
    local controlDefinition = definition.control or { type = "direct" }
    local inputs = {}
    local outputs = {}

    for _, edgeId in ipairs(definition.inputEdgeIds or {}) do
        local edge = self.edges[edgeId]
        if edge then
            inputs[#inputs + 1] = edge
        end
    end

    for _, edgeId in ipairs(definition.outputEdgeIds or {}) do
        local edge = self.edges[edgeId]
        if edge then
            outputs[#outputs + 1] = edge
        end
    end

    local mergePoint = { x = self.viewport.w * 0.5, y = self.viewport.h * 0.5 }
    if #inputs > 0 and #inputs[1].path.points > 0 then
        local lastPoint = inputs[1].path.points[#inputs[1].path.points]
        mergePoint = copyPoint(lastPoint)
    elseif #outputs > 0 and #outputs[1].path.points > 0 then
        mergePoint = copyPoint(outputs[1].path.points[1])
    end

    local junction = {
        id = definition.id,
        label = controlDefinition.label or definition.label or "Control",
        mergePoint = mergePoint,
        crossingRadius = self.crossingRadius,
        activeInputIndex = clamp(existing and existing.activeInputIndex or definition.activeInputIndex or 1, 1, math.max(1, #inputs)),
        activeOutputIndex = clamp(existing and existing.activeOutputIndex or definition.activeOutputIndex or 1, 1, math.max(1, #outputs)),
        selectorPress = existing and existing.selectorPress or 0,
        selectorPressVelocity = existing and existing.selectorPressVelocity or 0,
        control = {
            type = controlDefinition.type or "direct",
            delay = controlDefinition.delay or 0,
            target = controlDefinition.target or 0,
            holdTime = controlDefinition.holdTime or 0,
            passCount = math.max(1, controlDefinition.passCount or 1),
            decayDelay = controlDefinition.decayDelay or 0,
            decayInterval = controlDefinition.decayInterval or 0,
            armed = existing and existing.control.armed or false,
            remainingDelay = existing and existing.control.remainingDelay or 0,
            remainingHold = existing and existing.control.remainingHold or 0,
            returnInputIndex = existing and existing.control.returnInputIndex or 1,
            releaseTimer = existing and existing.control.releaseTimer or 0,
            remainingTrips = existing and existing.control.remainingTrips or 0,
            pendingResetTrainId = existing and existing.control.pendingResetTrainId or nil,
            pendingResetEdgeId = existing and existing.control.pendingResetEdgeId or nil,
            pumpCount = existing and existing.control.pumpCount or 0,
            decayHold = existing and existing.control.decayHold or 0,
            decayTimer = existing and existing.control.decayTimer or 0,
            flashTimer = existing and existing.control.flashTimer or 0,
            iconPress = existing and existing.control.iconPress or 0,
            iconPressVelocity = existing and existing.control.iconPressVelocity or 0,
        },
        inputs = inputs,
        outputs = outputs,
    }

    if junction.control.type == "relay" and #junction.outputs > 0 then
        self:syncRelayOutput(junction)
    elseif junction.control.type == "crossbar" and #junction.outputs > 0 then
        self:syncCrossbarOutput(junction)
    end

    return junction
end

function world:registerInteraction()
    self.interactionCount = (self.interactionCount or 0) + 1
end

function world:setReplayListener(listener)
    self.replayListener = listener
end

function world:emitReplayEvent(event)
    local listener = self.replayListener
    if listener and listener.recordTimelineEvent then
        listener:recordTimelineEvent(event)
    end
end

function world:getReplayJunctionStates()
    local junctionStates = {}

    for _, junction in ipairs(self.junctionOrder or {}) do
        junctionStates[#junctionStates + 1] = {
            id = junction.id,
            activeInputIndex = junction.activeInputIndex or 1,
            activeOutputIndex = junction.activeOutputIndex or 1,
        }
    end

    return junctionStates
end

function world:applyReplayJunctionStates(junctionStates)
    local stateById = {}

    for _, junctionState in ipairs(junctionStates or {}) do
        stateById[junctionState.id] = junctionState
    end

    for _, junction in ipairs(self.junctionOrder or {}) do
        local state = stateById[junction.id]
        if state then
            junction.activeInputIndex = clamp(
                tonumber(state.activeInputIndex) or junction.activeInputIndex or 1,
                1,
                math.max(1, #junction.inputs)
            )
            junction.activeOutputIndex = clamp(
                tonumber(state.activeOutputIndex) or junction.activeOutputIndex or 1,
                1,
                math.max(1, #junction.outputs)
            )
        end
    end
end

function world:triggerPressAnimation(stateTable, valueKey, velocityKey, strength, baseLift)
    if not stateTable then
        return
    end

    local impulse = (strength or 1) * ICON_PRESS_IMPULSE
    stateTable[valueKey] = math.min(1.2, (stateTable[valueKey] or 0) + (baseLift or 0.08))
    stateTable[velocityKey] = (stateTable[velocityKey] or 0) + impulse
end

function world:pressJunctionIcon(junction, strength)
    if not (junction and junction.control) then
        return
    end

    self:triggerPressAnimation(junction.control, "iconPress", "iconPressVelocity", strength, 0.1)
end

function world:pressOutputSelector(junction, strength)
    if not junction then
        return
    end

    self:triggerPressAnimation(junction, "selectorPress", "selectorPressVelocity", strength, 0.08)
end

function world:updatePressAnimation(stateTable, valueKey, velocityKey, dt)
    if not stateTable then
        return
    end

    local press = stateTable[valueKey] or 0
    local velocity = stateTable[velocityKey] or 0

    if math.abs(press) < 0.0005 and math.abs(velocity) < 0.005 then
        stateTable[valueKey] = 0
        stateTable[velocityKey] = 0
        return
    end

    local acceleration = -ICON_PRESS_STIFFNESS * press - ICON_PRESS_DAMPING * velocity
    velocity = velocity + acceleration * dt
    press = press + velocity * dt

    stateTable[valueKey] = press
    stateTable[velocityKey] = velocity
end

function world:updateJunctionIconAnimation(control, dt)
    self:updatePressAnimation(control, "iconPress", "iconPressVelocity", dt)
end

local function getControlIconScale(control)
    local press = clamp(control and control.iconPress or 0, -0.4, 1.2)
    return 1 - press * 0.25
end

local function getSelectorIconScale(junction)
    local press = clamp(junction and junction.selectorPress or 0, -0.4, 1.2)
    return 1 - press * 0.25
end

function world:doesEdgeAcceptGoalColor(inputEdge, outputEdge, goalColor)
    if containsColorId(outputEdge and outputEdge.colors, goalColor) then
        return true
    end

    if outputEdge and outputEdge.adoptInputColor and containsColorId(inputEdge and inputEdge.colors, goalColor) then
        return true
    end

    return outputEdge and nearestColorId(outputEdge.color) == goalColor or false
end

function world:getReachableOutputEdgesForInput(junction, inputEdgeId)
    if not junction or not inputEdgeId or #((junction and junction.outputs) or {}) <= 0 then
        return {}
    end

    local inputIndex = nil
    for candidateIndex, inputEdge in ipairs(junction.inputs or {}) do
        if inputEdge.id == inputEdgeId then
            inputIndex = candidateIndex
            break
        end
    end

    if not inputIndex then
        return {}
    end

    local controlType = junction.control and junction.control.type or "direct"
    if controlType == "relay" then
        local relayOutput = junction.outputs[getDirectionalOutputIndex(junction, inputIndex, "relay")]
        return relayOutput and { relayOutput } or {}
    end

    if controlType == "crossbar" then
        local crossbarOutput = junction.outputs[getDirectionalOutputIndex(junction, inputIndex, "crossbar")]
        return crossbarOutput and { crossbarOutput } or {}
    end

    return junction.outputs
end

function world:buildMinimumDistanceLookup()
    self.minimumDistanceByTrainId = {}

    for _, train in ipairs(self.trains) do
        local startEdge = self.edges[train.startEdgeId]
        local goalColor = train.goalColor
        local bestDistance = nil

        if startEdge then
            local queue = {
                {
                    edgeId = startEdge.id,
                    distance = startEdge.path.length,
                },
            }
            local bestByEdge = {
                [startEdge.id] = startEdge.path.length,
            }
            local queueIndex = 1

            while queueIndex <= #queue do
                local current = queue[queueIndex]
                queueIndex = queueIndex + 1

                if bestDistance and current.distance >= bestDistance then
                    goto continue_distance_search
                end

                local currentEdge = self.edges[current.edgeId]
                if not currentEdge then
                    goto continue_distance_search
                end

                if currentEdge.targetType == "exit" then
                    if containsColorId(currentEdge.colors, goalColor) or nearestColorId(currentEdge.color) == goalColor then
                        if not bestDistance or current.distance < bestDistance then
                            bestDistance = current.distance
                        end
                    end
                    goto continue_distance_search
                end

                if currentEdge.targetType ~= "junction" then
                    goto continue_distance_search
                end

                local junction = self.junctions[currentEdge.targetId]
                for _, outputEdge in ipairs(self:getReachableOutputEdgesForInput(junction, currentEdge.id)) do
                    if self:doesEdgeAcceptGoalColor(currentEdge, outputEdge, goalColor) then
                        local nextDistance = current.distance + outputEdge.path.length
                        if outputEdge.targetType == "exit" then
                            if not bestDistance or nextDistance < bestDistance then
                                bestDistance = nextDistance
                            end
                        elseif nextDistance < (bestByEdge[outputEdge.id] or math.huge) then
                            bestByEdge[outputEdge.id] = nextDistance
                            queue[#queue + 1] = {
                                edgeId = outputEdge.id,
                                distance = nextDistance,
                            }
                        end
                    end
                end

                ::continue_distance_search::
            end
        end

        if not bestDistance then
            bestDistance = 0
        end

        train.minimumDistance = bestDistance
        self.minimumDistanceByTrainId[train.id or tostring(#self.minimumDistanceByTrainId + 1)] = bestDistance
    end
end

function world:initializeLevel()
    self.junctions = {}
    self.junctionOrder = {}
    self.edges = {}
    self.trains = {}

    for _, edgeDefinition in ipairs(self.level.edges or {}) do
        self.edges[edgeDefinition.id] = self:buildEdge(edgeDefinition)
    end

    for _, junctionDefinition in ipairs(self.level.junctions or {}) do
        local junction = self:buildJunction(junctionDefinition, nil)
        self.junctions[junction.id] = junction
        self.junctionOrder[#self.junctionOrder + 1] = junction
    end

    for _, trainDefinition in ipairs(self.level.trains or {}) do
        local edge = self.edges[trainDefinition.edgeId]
        if edge then
            local baseColor = trainDefinition.color or edge.color
            local spawned = (trainDefinition.spawnTime or 0) <= 0
            self.trains[#self.trains + 1] = {
                id = trainDefinition.id,
                edgeId = trainDefinition.edgeId,
                startEdgeId = trainDefinition.edgeId,
                lineColor = trainDefinition.lineColor,
                occupiedEdgeIds = spawned and { trainDefinition.edgeId } or {},
                headDistance = spawned and (trainDefinition.progress or 0) or 0,
                spawnProgress = trainDefinition.progress or 0,
                speed = self.trainSpeed * (trainDefinition.speedScale or 1),
                currentSpeed = 0,
                color = copyColor(baseColor),
                darkColor = darkerColor(baseColor),
                goalColor = trainDefinition.goalColor or trainDefinition.trainColor or nearestColorId(baseColor),
                trainColor = trainDefinition.trainColor or trainDefinition.goalColor or nearestColorId(baseColor),
                wagonCount = trainDefinition.wagonCount or self.carriageCount,
                spawnTime = trainDefinition.spawnTime or 0,
                deadline = trainDefinition.deadline,
                spawned = spawned,
                completed = false,
                completedAt = nil,
                clearedAt = nil,
                clearingExitEdgeId = nil,
                deliveredCorrectly = false,
                deliveredLate = false,
                failedWrongDestination = false,
                exiting = false,
                exitFadeRemaining = 0,
                actualDistance = 0,
                minimumDistance = 0,
            }
        end
    end

    self:buildMinimumDistanceLookup()

    self.elapsedTime = 0
    self.timeRemaining = self.level.timeLimit
    self.collisionPoint = nil
    self.failureReason = nil
    self.failureTrain = nil
    self.interactionCount = 0
end

function world:getOccupiedEdges(train)
    local occupiedEdges = {}
    for _, edgeId in ipairs(train.occupiedEdgeIds or {}) do
        local edge = self.edges[edgeId]
        if edge then
            occupiedEdges[#occupiedEdges + 1] = edge
        end
    end
    return occupiedEdges
end

function world:spawnTrain(train)
    if train.spawned or train.completed or not self.edges[train.startEdgeId] then
        return
    end

    train.spawned = true
    train.edgeId = train.startEdgeId
    train.occupiedEdgeIds = { train.startEdgeId }
    train.headDistance = train.spawnProgress or 0
    train.currentSpeed = 0
    train.exiting = false
    train.exitFadeRemaining = 0
    train.clearedAt = nil
    train.clearingExitEdgeId = nil
    self:emitReplayEvent({
        time = self.elapsedTime,
        kind = "train_spawn",
        trainId = train.id,
        edgeId = train.startEdgeId,
    })
end

function world:isTrainCleared(train)
    return train.completed
end

function world:beginTrainExit(train)
    if not train or train.completed or train.exiting then
        return
    end

    local occupiedEdges = self:getOccupiedEdges(train)
    local currentEdge = occupiedEdges[#occupiedEdges]
    if currentEdge and currentEdge.targetType == "exit" then
        train.exiting = true
        train.clearingExitEdgeId = train.clearingExitEdgeId or currentEdge.id
        self:emitReplayEvent({
            time = self.elapsedTime,
            kind = "train_exit",
            trainId = train.id,
            edgeId = train.clearingExitEdgeId,
        })
    end
end

function world:completeTrain(train)
    if train.completed then
        return
    end

    train.completed = true
    train.exiting = false
    train.exitFadeRemaining = 0
    train.currentSpeed = 0
    train.completedAt = train.clearedAt or self.elapsedTime
    train.deliveredCorrectly = not train.failedWrongDestination
    train.deliveredLate = train.deliveredCorrectly and train.deadline ~= nil and train.completedAt > train.deadline
    self:emitReplayEvent({
        time = train.completedAt,
        kind = "train_complete",
        trainId = train.id,
        edgeId = train.clearingExitEdgeId,
        deliveredCorrectly = train.deliveredCorrectly,
        deliveredLate = train.deliveredLate,
    })
end

function world:updateTrainExit(train, dt)
    return
end

function world:doesOutputAcceptTrain(train, junction, outputEdge)
    if containsColorId(outputEdge.colors, train.goalColor) then
        return true
    end

    if outputEdge.adoptInputColor then
        local activeInput = junction.inputs[junction.activeInputIndex]
        if activeInput and containsColorId(activeInput.colors, train.goalColor) then
            return true
        end
    end

    return containsColorId({ nearestColorId(outputEdge.color) }, train.goalColor)
end

function world:getCurrentEdge(train)
    local occupiedEdges = self:getOccupiedEdges(train)
    return occupiedEdges[#occupiedEdges], occupiedEdges
end

function world:getHeadLocalProgress(train, occupiedEdges)
    local edges = occupiedEdges or self:getOccupiedEdges(train)
    local offset = train.headDistance or 0

    for edgeIndex = 1, #edges - 1 do
        offset = offset - edges[edgeIndex].path.length
    end

    return offset
end

function world:trimTrainOccupiedEdges(train, occupiedEdges)
    local edges = occupiedEdges or self:getOccupiedEdges(train)
    local tailDistance = (train.headDistance or 0) - ((train.wagonCount or self.carriageCount) - 1) * (self.carriageLength + self.carriageGap)

    while #edges > 1 and tailDistance > edges[1].path.length do
        tailDistance = tailDistance - edges[1].path.length
        train.headDistance = train.headDistance - edges[1].path.length
        table.remove(edges, 1)
        table.remove(train.occupiedEdgeIds, 1)
    end
end

function world:getDistanceOnOccupiedEdges(occupiedEdges)
    local total = 0
    for _, edge in ipairs(occupiedEdges or {}) do
        total = total + edge.path.length
    end
    return total
end

function world:trainOccupiesEdge(train, edgeId)
    for _, occupiedEdgeId in ipairs(train.occupiedEdgeIds or {}) do
        if occupiedEdgeId == edgeId then
            return true
        end
    end

    return false
end

function world:pointOnOccupiedEdges(occupiedEdges, distance)
    local offset = distance
    local firstEdge = occupiedEdges[1]
    if not firstEdge then
        return 0, 0, 0
    end

    if offset <= 0 then
        return pointOnPath(firstEdge.path, offset)
    end

    for _, edge in ipairs(occupiedEdges) do
        if offset <= edge.path.length then
            return pointOnPath(edge.path, offset)
        end
        offset = offset - edge.path.length
    end

    local lastEdge = occupiedEdges[#occupiedEdges]
    return pointOnPath(lastEdge.path, lastEdge.path.length + offset)
end

function world:getTrainExitState(train, occupiedEdges)
    local edges = occupiedEdges or self:getOccupiedEdges(train)
    local exitEdge = edges[#edges]
    if not exitEdge or exitEdge.targetType ~= "exit" then
        return nil, nil, nil
    end

    local occupiedLength = self:getDistanceOnOccupiedEdges(edges)
    local fadeDistance = math.max(self.carriageLength, (train.speed or self.trainSpeed) * self.exitFadeDuration)
    return exitEdge, occupiedLength, fadeDistance
end

function world:hasTrainFullyClearedExit(train, occupiedEdges)
    local _, occupiedLength = self:getTrainExitState(train, occupiedEdges)
    if not occupiedLength then
        return false
    end

    local carriageSpacing = self.carriageLength + self.carriageGap
    local tailOffset = ((train.wagonCount or self.carriageCount) - 1) * carriageSpacing
    local tailRearDistance = (train.headDistance or 0) - tailOffset - self.carriageLength * 0.5
    return tailRearDistance >= occupiedLength
end

function world:resize(viewportW, viewportH)
    self.viewport.w = viewportW
    self.viewport.h = viewportH
    self.crossingRadius = math.max(34, math.min(viewportW, viewportH) * 0.045)
    self.level = self:normalizeLevel(self.level)
    self:initializeLevel()
end

function world:cycleInput(junction)
    if #junction.inputs <= 1 then
        junction.activeInputIndex = 1
        return false
    end

    local controlType = junction.control and junction.control.type or "direct"
    if controlType == "relay" or controlType == "crossbar" then
        junction.activeInputIndex = getNextCycledInputIndex(junction)
        return true
    end

    junction.activeInputIndex = junction.activeInputIndex + 1
    if junction.activeInputIndex > #junction.inputs then
        junction.activeInputIndex = 1
    end
    return true
end

function world:cycleOutput(junction, direction)
    if #junction.outputs <= 1 then
        junction.activeOutputIndex = 1
        return false
    end

    junction.activeOutputIndex = junction.activeOutputIndex + direction
    if junction.activeOutputIndex < 1 then
        junction.activeOutputIndex = #junction.outputs
    elseif junction.activeOutputIndex > #junction.outputs then
        junction.activeOutputIndex = 1
    end
    return true
end

function world:syncRelayOutput(junction)
    if #junction.outputs <= 0 then
        return
    end

    junction.activeOutputIndex = getDirectionalOutputIndex(junction, junction.activeInputIndex, "relay")
end

function world:syncCrossbarOutput(junction)
    if #junction.outputs <= 0 then
        return
    end

    junction.activeOutputIndex = getDirectionalOutputIndex(junction, junction.activeInputIndex, "crossbar")
end

local function isPlayPhaseOnlyControl(controlType)
    return controlType == "delayed"
        or controlType == "pump"
        or controlType == "spring"
        or controlType == "trip"
end

function world:canActivateControl(junction, isPreparationPhase)
    local control = junction.control

    if isPreparationPhase and isPlayPhaseOnlyControl(control.type) then
        return false
    end

    if (control.type == "delayed" or control.type == "spring") and control.armed then
        return false
    end

    return true
end

function world:activatePreparationControl(junction)
    if not junction then
        return false
    end

    local changed = self:cycleInput(junction)
    local controlType = junction.control and junction.control.type or "direct"

    if controlType == "relay" then
        self:syncRelayOutput(junction)
    elseif controlType == "crossbar" then
        self:syncCrossbarOutput(junction)
    end

    if changed then
        self:emitReplayEvent({
            time = self.elapsedTime,
            kind = "junction_state",
            junctionId = junction.id,
            reason = "preparation",
            activeInputIndex = junction.activeInputIndex,
            activeOutputIndex = junction.activeOutputIndex,
        })
    end

    return changed
end

function world:activateControl(junction)
    local control = junction.control

    if control.type == "direct" then
        local changed = self:cycleInput(junction)
        if changed then
            self:emitReplayEvent({
                time = self.elapsedTime,
                kind = "junction_state",
                junctionId = junction.id,
                reason = "direct",
                activeInputIndex = junction.activeInputIndex,
                activeOutputIndex = junction.activeOutputIndex,
            })
        end
        return changed
    end

    if control.type == "delayed" then
        control.armed = true
        control.remainingDelay = control.delay
        return true
    end

    if control.type == "pump" then
        local previousPumpCount = control.pumpCount
        control.pumpCount = math.min(control.target, control.pumpCount + 1)
        control.decayHold = control.decayDelay
        control.decayTimer = control.decayInterval

        if control.pumpCount >= control.target then
            self:cycleInput(junction)
            control.pumpCount = 0
            control.decayHold = 0
            control.decayTimer = 0
            self:emitReplayEvent({
                time = self.elapsedTime,
                kind = "junction_state",
                junctionId = junction.id,
                reason = "pump",
                activeInputIndex = junction.activeInputIndex,
                activeOutputIndex = junction.activeOutputIndex,
            })
        end

        return control.pumpCount ~= previousPumpCount or control.target > 0
    end

    if control.type == "spring" then
        control.returnInputIndex = junction.activeInputIndex
        self:cycleInput(junction)
        control.remainingHold = control.holdTime
        control.releaseTimer = 0
        control.armed = true
        self:emitReplayEvent({
            time = self.elapsedTime,
            kind = "junction_state",
            junctionId = junction.id,
            reason = "spring_forward",
            activeInputIndex = junction.activeInputIndex,
            activeOutputIndex = junction.activeOutputIndex,
        })
        return true
    end

    if control.type == "relay" then
        self:cycleInput(junction)
        self:syncRelayOutput(junction)
        control.flashTimer = RELAY_FLASH_DURATION
        self:emitReplayEvent({
            time = self.elapsedTime,
            kind = "junction_state",
            junctionId = junction.id,
            reason = "relay",
            activeInputIndex = junction.activeInputIndex,
            activeOutputIndex = junction.activeOutputIndex,
        })
        return true
    end

    if control.type == "trip" then
        if control.remainingTrips > 0 or control.pendingResetTrainId then
            return false
        end

        control.returnInputIndex = junction.activeInputIndex
        self:cycleInput(junction)
        control.armed = true
        control.remainingTrips = control.passCount
        control.pendingResetTrainId = nil
        control.pendingResetEdgeId = nil
        control.flashTimer = TRIP_FLASH_DURATION
        self:emitReplayEvent({
            time = self.elapsedTime,
            kind = "junction_state",
            junctionId = junction.id,
            reason = "trip_forward",
            activeInputIndex = junction.activeInputIndex,
            activeOutputIndex = junction.activeOutputIndex,
        })
        return true
    end

    if control.type == "crossbar" then
        self:cycleInput(junction)
        self:syncCrossbarOutput(junction)
        control.flashTimer = CROSSBAR_FLASH_DURATION
        self:emitReplayEvent({
            time = self.elapsedTime,
            kind = "junction_state",
            junctionId = junction.id,
            reason = "crossbar",
            activeInputIndex = junction.activeInputIndex,
            activeOutputIndex = junction.activeOutputIndex,
        })
        return true
    end

    return false
end

function world:isCrossingHit(junction, x, y)
    return distanceSquared(x, y, junction.mergePoint.x, junction.mergePoint.y)
        <= junction.crossingRadius * junction.crossingRadius
end

function world:isOutputSelectorHit(junction, x, y)
    local selectorX, selectorY, selectorRadius = trackSceneRenderer.getOutputSelectorLayout(junction)
    if not selectorX then
        return false
    end

    return distanceSquared(x, y, selectorX, selectorY) <= selectorRadius * selectorRadius
end

function world:handleClick(x, y, button, isPreparationPhase)
    for _, junction in ipairs(self.junctionOrder) do
        if self:isOutputSelectorHit(junction, x, y) then
            local changed
            if button == 2 then
                changed = self:cycleOutput(junction, -1)
            else
                changed = self:cycleOutput(junction, 1)
            end
            if changed then
                if not isPreparationPhase then
                    self:pressOutputSelector(junction, 1)
                    self:registerInteraction()
                end
            end
            return true, {
                changed = changed == true,
                junctionId = junction.id,
                target = "selector",
                button = button,
                x = x,
                y = y,
            }
        end

        if button == 1 and self:isCrossingHit(junction, x, y) then
            local changed = false
            if isPreparationPhase then
                changed = self:activatePreparationControl(junction)
            elseif self:canActivateControl(junction, false) then
                changed = self:activateControl(junction)
            end

            if changed then
                if not isPreparationPhase then
                    self:pressJunctionIcon(junction, 1)
                    self:registerInteraction()
                end
            end
            return true, {
                changed = changed == true,
                junctionId = junction.id,
                target = "junction",
                button = button,
                x = x,
                y = y,
            }
        end
    end

    return false, nil
end

function world:applyReplayInteraction(interaction)
    if type(interaction) ~= "table" then
        return false
    end

    local junction = self.junctions[interaction.junctionId]
    if not junction then
        return false
    end

    if interaction.target == "selector" then
        local direction = tonumber(interaction.button) == 2 and -1 or 1
        local changed = self:cycleOutput(junction, direction)
        if changed then
            self:pressOutputSelector(junction, 1)
            self:registerInteraction()
        end
        return changed
    end

    if not self:canActivateControl(junction, false) then
        return false
    end

    local changed = self:activateControl(junction)
    if changed then
        self:pressJunctionIcon(junction, 1)
        self:registerInteraction()
    end
    return changed
end

function world:updateControlState(junction, dt)
    local control = junction.control
    self:updateJunctionIconAnimation(control, dt)
    self:updatePressAnimation(junction, "selectorPress", "selectorPressVelocity", dt)

    if control.type == "delayed" and control.armed then
        control.remainingDelay = math.max(0, control.remainingDelay - dt)
        if control.remainingDelay <= 0 then
            control.armed = false
            self:cycleInput(junction)
            self:emitReplayEvent({
                time = self.elapsedTime,
                kind = "junction_state",
                junctionId = junction.id,
                reason = "delayed_release",
                activeInputIndex = junction.activeInputIndex,
                activeOutputIndex = junction.activeOutputIndex,
            })
        end
        return
    end

    if control.type == "pump" and control.pumpCount > 0 then
        if control.decayHold > 0 then
            control.decayHold = math.max(0, control.decayHold - dt)
            return
        end

        control.decayTimer = control.decayTimer - dt
        while control.decayTimer <= 0 and control.pumpCount > 0 do
            control.pumpCount = control.pumpCount - 1
            control.decayTimer = control.decayTimer + control.decayInterval
        end
        return
    end

    if control.type == "spring" then
        if control.armed then
            control.remainingHold = math.max(0, control.remainingHold - dt)
            if control.remainingHold <= 0 then
                control.armed = false
                control.releaseTimer = SPRING_RELEASE_DURATION
                junction.activeInputIndex = clamp(control.returnInputIndex, 1, math.max(1, #junction.inputs))
                self:emitReplayEvent({
                    time = self.elapsedTime,
                    kind = "junction_state",
                    junctionId = junction.id,
                    reason = "spring_return",
                    activeInputIndex = junction.activeInputIndex,
                    activeOutputIndex = junction.activeOutputIndex,
                })
            end
            return
        end

        if control.releaseTimer > 0 then
            control.releaseTimer = math.max(0, control.releaseTimer - dt)
        end
        return
    end

    if control.type == "relay" and control.flashTimer > 0 then
        control.flashTimer = math.max(0, control.flashTimer - dt)
        return
    end

    if control.type == "trip" then
        if control.flashTimer > 0 then
            control.flashTimer = math.max(0, control.flashTimer - dt)
        end

        if control.pendingResetTrainId and control.pendingResetEdgeId then
            local resetReady = true

            for _, train in ipairs(self.trains or {}) do
                if train.id == control.pendingResetTrainId then
                    resetReady = train.completed or not self:trainOccupiesEdge(train, control.pendingResetEdgeId)
                    break
                end
            end

            if resetReady then
                control.pendingResetTrainId = nil
                control.pendingResetEdgeId = nil
                control.remainingTrips = math.max(0, control.remainingTrips - 1)
                if control.remainingTrips <= 0 then
                    control.armed = false
                    junction.activeInputIndex = clamp(control.returnInputIndex, 1, math.max(1, #junction.inputs))
                    self:emitReplayEvent({
                        time = self.elapsedTime,
                        kind = "junction_state",
                        junctionId = junction.id,
                        reason = "trip_return",
                        activeInputIndex = junction.activeInputIndex,
                        activeOutputIndex = junction.activeOutputIndex,
                    })
                end
            end
        end

        return
    end

    if control.type == "crossbar" and control.flashTimer > 0 then
        control.flashTimer = math.max(0, control.flashTimer - dt)
    end
end

function world:getDesiredLeadDistance(train)
    local currentEdge = self.edges[train.edgeId]
    if not currentEdge or self:isTrainCleared(train) or currentEdge.targetType ~= "junction" then
        return nil
    end

    local junction = self.junctions[currentEdge.targetId]
    if not junction then
        return nil
    end

    local localProgress = self:getHeadLocalProgress(train)
    if localProgress >= currentEdge.path.length then
        return nil
    end

    local activeInput = junction.inputs[junction.activeInputIndex]
    if not activeInput or activeInput.id ~= currentEdge.id then
        return currentEdge.stopDistance
    end

    return nil
end

function world:getEdgeSpeedScaleAtDistance(edge, distance)
    local clampedDistance = clamp(distance or 0, 0, edge.path.length)

    for _, section in ipairs(edge.styleSections or {}) do
        if clampedDistance >= section.startDistance and clampedDistance <= section.endDistance then
            return section.speedScale
        end
    end

    return edge.speedScale or 1
end

function world:advanceTrainToNextEdge(train, junction, overflow)
    local outputEdge = junction.outputs[clamp(junction.activeOutputIndex, 1, math.max(1, #junction.outputs))]
    if not outputEdge then
        self:completeTrain(train)
        return false
    end

    if not self:doesOutputAcceptTrain(train, junction, outputEdge) then
        train.failedWrongDestination = true
    end

    local sourceEdgeId = train.edgeId

    train.edgeId = outputEdge.id
    train.occupiedEdgeIds[#train.occupiedEdgeIds + 1] = outputEdge.id
    self:trimTrainOccupiedEdges(train)
    if outputEdge.targetType == "exit" then
        train.clearingExitEdgeId = outputEdge.id
    end

    if junction.control.type == "trip" and junction.control.remainingTrips > 0 and not junction.control.pendingResetTrainId then
        junction.control.pendingResetTrainId = train.id
        junction.control.pendingResetEdgeId = sourceEdgeId
    end

    return true
end

function world:updateTrain(train, dt)
    if self:isTrainCleared(train) or not train.spawned then
        return
    end

    local currentEdge = self.edges[train.edgeId]
    if not currentEdge then
        train.completed = true
        return
    end

    local localProgress = self:getHeadLocalProgress(train)
    local desiredStopDistance = self:getDesiredLeadDistance(train)
    local targetSpeed = train.speed * self:getEdgeSpeedScaleAtDistance(currentEdge, localProgress)

    if desiredStopDistance then
        local brakingWindow = 110
        local remainingDistance = desiredStopDistance - localProgress

        if remainingDistance <= 0 then
            targetSpeed = 0
            local previousLength = self:getDistanceOnOccupiedEdges(self:getOccupiedEdges(train)) - currentEdge.path.length
            train.headDistance = previousLength + desiredStopDistance
            localProgress = desiredStopDistance
        else
            targetSpeed = train.speed * self:getEdgeSpeedScaleAtDistance(currentEdge, localProgress) * clamp(remainingDistance / brakingWindow, 0, 1)
        end
    end

    if train.currentSpeed < targetSpeed then
        train.currentSpeed = math.min(targetSpeed, train.currentSpeed + self.trainAcceleration * dt)
    else
        train.currentSpeed = math.max(targetSpeed, train.currentSpeed - self.trainAcceleration * 1.2 * dt)
    end

    local nextProgress = localProgress + train.currentSpeed * dt
    if desiredStopDistance and nextProgress > desiredStopDistance then
        nextProgress = desiredStopDistance
        train.currentSpeed = 0
    end
    local countedCurrentProgress = localProgress
    local countedNextProgress = nextProgress
    if currentEdge.targetType == "exit" then
        countedCurrentProgress = math.min(localProgress, currentEdge.path.length)
        countedNextProgress = math.min(nextProgress, currentEdge.path.length)
    end
    local movedDistance = math.max(0, countedNextProgress - countedCurrentProgress)
    train.actualDistance = (train.actualDistance or 0) + movedDistance

    local previousLength = self:getDistanceOnOccupiedEdges(self:getOccupiedEdges(train)) - currentEdge.path.length
    train.headDistance = previousLength + nextProgress
    self:trimTrainOccupiedEdges(train)

    while not self:isTrainCleared(train) do
        currentEdge = self.edges[train.edgeId]
        if not currentEdge then
            train.completed = true
            break
        end

        local localHead = self:getHeadLocalProgress(train)
        if localHead < currentEdge.path.length then
            break
        end

        local overflow = localHead - currentEdge.path.length
        if currentEdge.targetType == "junction" then
            local junction = self.junctions[currentEdge.targetId]
            local activeInput = junction and junction.inputs[junction.activeInputIndex] or nil
            if not junction or not activeInput or activeInput.id ~= currentEdge.id then
                if overflow > 0 then
                    train.actualDistance = math.max(0, (train.actualDistance or 0) - overflow)
                end
                local edgePrefix = self:getDistanceOnOccupiedEdges(self:getOccupiedEdges(train)) - currentEdge.path.length
                train.headDistance = edgePrefix + currentEdge.path.length
                train.currentSpeed = 0
                break
            end
            if not self:advanceTrainToNextEdge(train, junction, overflow) then
                break
            end
        elseif currentEdge.targetType == "exit" then
            self:beginTrainExit(train)
            if self:hasTrainFullyClearedExit(train, self:getOccupiedEdges(train)) then
                train.clearedAt = self.elapsedTime
                self:completeTrain(train)
            end
            break
        else
            break
        end
    end
end

function world:getTrainCarriagePositions(train)
    local positions = {}
    local carriageSpacing = self.carriageLength + self.carriageGap
    local occupiedEdges = self:getOccupiedEdges(train)
    local _, occupiedLength, fadeDistance = self:getTrainExitState(train, occupiedEdges)

    if (train.completed and not train.exiting) or not train.spawned or #occupiedEdges == 0 then
        return positions
    end

    for carriageIndex = 1, (train.wagonCount or self.carriageCount) do
        local carriageDistance = (train.headDistance or 0) - (carriageIndex - 1) * carriageSpacing
        local x, y, angle = self:pointOnOccupiedEdges(occupiedEdges, carriageDistance)
        local alpha = 1
        local collidable = true

        if occupiedLength then
            local frontDistance = carriageDistance + self.carriageLength * 0.5
            if frontDistance >= occupiedLength then
                collidable = false
                alpha = clamp(1 - ((frontDistance - occupiedLength) / math.max(fadeDistance or self.carriageLength, 0.0001)), 0, 1)
            end
        end

        if alpha > 0 then
            positions[#positions + 1] = {
                x = x,
                y = y,
                angle = angle,
                alpha = alpha,
                collidable = collidable,
            }
        end
    end

    return positions
end

function world:updateCollisionState()
    self.collisionPoint = nil

    for firstIndex = 1, #self.trains - 1 do
        local firstTrain = self.trains[firstIndex]
        if firstTrain.spawned and not firstTrain.completed then
            local firstCars = self:getTrainCarriagePositions(firstTrain)

            for secondIndex = firstIndex + 1, #self.trains do
                local secondTrain = self.trains[secondIndex]
                if secondTrain.spawned and not secondTrain.completed then
                    local secondCars = self:getTrainCarriagePositions(secondTrain)

                    for _, firstCar in ipairs(firstCars) do
                        for _, secondCar in ipairs(secondCars) do
                            if firstCar.collidable and secondCar.collidable
                                and carriagesOverlap(firstCar, secondCar, self.carriageLength, self.carriageHeight) then
                                self.failureReason = "collision"
                                self.collisionPoint = {
                                    x = (firstCar.x + secondCar.x) * 0.5,
                                    y = (firstCar.y + secondCar.y) * 0.5,
                                }
                                return
                            end
                        end
                    end
                end
            end
        end
    end
end

function world:updateDeadlineState()
    for _, train in ipairs(self.trains) do
        if not self:isTrainCleared(train) and train.deadline and self.elapsedTime > train.deadline then
            self.failureTrain = train
        end
    end
end

function world:update(dt)
    if self.failureReason or self:isLevelComplete() then
        return
    end

    local previousElapsed = self.elapsedTime
    self.elapsedTime = self.elapsedTime + dt
    if self.level.timeLimit then
        self.timeRemaining = math.max(0, self.level.timeLimit - self.elapsedTime)
    end

    for _, junction in ipairs(self.junctionOrder) do
        self:updateControlState(junction, dt)
    end

    for _, train in ipairs(self.trains) do
        local trainDt = dt
        if not train.spawned and not self:isTrainCleared(train) then
            if self.elapsedTime >= (train.spawnTime or 0) then
                self:spawnTrain(train)
                trainDt = self.elapsedTime - math.max(previousElapsed, train.spawnTime or 0)
            else
                trainDt = nil
            end
        end

        if trainDt and trainDt > 0 then
            self:updateTrain(train, trainDt)
        end

        self:updateTrainExit(train, dt)
    end

    self:updateCollisionState()

    if not self.failureReason and self.timeRemaining and self.timeRemaining <= 0 and not self:isLevelComplete() then
        self.failureReason = "timeout"
    end
end

function world:getFailureReason()
    return self.failureReason
end

function world:getFailureTrain()
    return self.failureTrain
end

function world:isLevelComplete()
    for _, train in ipairs(self.trains) do
        if not train.completed then
            return false
        end
    end
    return true
end

function world:countCompletedTrains()
    local completedCount = 0
    for _, train in ipairs(self.trains) do
        if self:isTrainCleared(train) then
            completedCount = completedCount + 1
        end
    end
    return completedCount
end

function world:getRunEndReason()
    if self.failureReason then
        return self.failureReason
    end
    if self:isLevelComplete() then
        return "level_clear"
    end
    return nil
end

function world:getRunSummary()
    local scoring = self:getScoringConstants()
    local onTimePointCap = #self.trains * scoring.onTimeClear
    local summary = {
        endReason = self:getRunEndReason(),
        mapUuid = self.level and (self.level.mapUuid or self.level.id) or nil,
        mapTitle = self.level and self.level.title or nil,
        totalTrainCount = #self.trains,
        correctOnTimeCount = 0,
        correctLateCount = 0,
        wrongDestinationCount = 0,
        elapsedSeconds = self.elapsedTime or 0,
        interactionCount = self.interactionCount or 0,
        actualDrivenDistance = 0,
        minimumRequiredDistance = 0,
        extraDistance = 0,
        scoreBreakdown = {
            onTimeClears = 0,
            lateClears = 0,
            timePenalty = 0,
            interactionPenalty = 0,
            extraDistancePenalty = 0,
        },
        finalScore = 0,
        maxPossibleScore = onTimePointCap,
        onTimePointCap = onTimePointCap,
        onTimePointLossBreakdown = {
            lateClears = 0,
            wrongDestinations = 0,
            unfinished = 0,
        },
    }

    for _, train in ipairs(self.trains) do
        summary.actualDrivenDistance = summary.actualDrivenDistance + (train.actualDistance or 0)

        if train.completed and train.deliveredCorrectly then
            local minimumDistance = train.minimumDistance or 0
            local extraDistance = math.max(0, (train.actualDistance or 0) - minimumDistance)
            summary.minimumRequiredDistance = summary.minimumRequiredDistance + minimumDistance
            summary.extraDistance = summary.extraDistance + extraDistance

            if train.deliveredLate then
                summary.correctLateCount = summary.correctLateCount + 1
                summary.scoreBreakdown.lateClears = summary.scoreBreakdown.lateClears + scoring.lateClear
            else
                summary.correctOnTimeCount = summary.correctOnTimeCount + 1
                summary.scoreBreakdown.onTimeClears = summary.scoreBreakdown.onTimeClears + scoring.onTimeClear
            end
        elseif train.completed and train.failedWrongDestination then
            summary.wrongDestinationCount = summary.wrongDestinationCount + 1
        end
    end

    summary.onTimePointLossBreakdown.lateClears = summary.correctLateCount * (scoring.onTimeClear - scoring.lateClear)
    summary.onTimePointLossBreakdown.wrongDestinations = summary.wrongDestinationCount * scoring.onTimeClear
    summary.onTimePointLossBreakdown.unfinished = math.max(
        0,
        summary.onTimePointCap
            - summary.scoreBreakdown.onTimeClears
            - summary.onTimePointLossBreakdown.lateClears
            - summary.onTimePointLossBreakdown.wrongDestinations
    )

    summary.scoreBreakdown.timePenalty = summary.elapsedSeconds * scoring.secondsPenalty
    summary.scoreBreakdown.interactionPenalty = roundScoreValue(summary.interactionCount * scoring.interactionPenalty)
    summary.scoreBreakdown.extraDistancePenalty = roundScoreValue(summary.extraDistance * scoring.extraDistancePenalty)

    summary.finalScore = summary.scoreBreakdown.onTimeClears
        + summary.scoreBreakdown.lateClears
        - summary.scoreBreakdown.timePenalty
        - summary.scoreBreakdown.interactionPenalty
        - summary.scoreBreakdown.extraDistancePenalty

    return summary
end

function world:getCurrentScore()
    return self:getRunSummary().finalScore
end

function world:getInputEdgeGroups()
    local orderedGroups = {}
    local startEdges = {}

    for _, edge in pairs(self.edges or {}) do
        if edge and edge.sourceType == "start" then
            startEdges[#startEdges + 1] = edge
        end
    end

    table.sort(startEdges, compareEdgesBySource)

    for _, startEdge in ipairs(startEdges) do
        orderedGroups[#orderedGroups + 1] = {
            edge = startEdge,
            trains = {},
        }
    end

    local groupsByEdgeId = {}
    for _, group in ipairs(orderedGroups) do
        groupsByEdgeId[group.edge.id] = group
    end

    for _, train in ipairs(self.trains or {}) do
        local inputEdgeId = train.startEdgeId or train.edgeId
        local group = groupsByEdgeId[inputEdgeId]
        if group then
            group.trains[#group.trains + 1] = train
        end
    end

    for _, group in ipairs(orderedGroups) do
        table.sort(group.trains, compareScheduledTrains)
    end

    return orderedGroups
end

function world:getNextPendingTrainForInputEdge(edgeId)
    local nextTrain = nil

    for _, train in ipairs(self.trains or {}) do
        local inputEdgeId = train.startEdgeId or train.edgeId
        if inputEdgeId == edgeId and not train.spawned and not self:isTrainCleared(train) then
            if not nextTrain or compareScheduledTrains(train, nextTrain) then
                nextTrain = train
            end
        end
    end

    return nextTrain
end

function world:getOutputAcceptedGoalColors(outputEdge)
    local colors = {}
    local lookup = {}

    for _, colorId in ipairs(outputEdge and outputEdge.colors or {}) do
        appendUnique(colors, lookup, colorId)
    end

    if outputEdge and outputEdge.adoptInputColor then
        local sourceJunction = self.junctions[outputEdge.sourceId]
        for _, inputEdge in ipairs(sourceJunction and sourceJunction.inputs or {}) do
            for _, colorId in ipairs(inputEdge.colors or {}) do
                appendUnique(colors, lookup, colorId)
            end
        end
    end

    if #colors == 0 and outputEdge then
        appendUnique(colors, lookup, nearestColorId(outputEdge.color))
    end

    return colors
end

function world:getOutputBadgeGroups()
    local groupedByExitId = {}
    local orderedGroups = {}
    local exitEdges = {}

    for _, edge in pairs(self.edges or {}) do
        if edge and edge.targetType == "exit" then
            exitEdges[#exitEdges + 1] = edge
        end
    end

    table.sort(exitEdges, compareEdgesByTarget)

    local groupByEdgeId = {}
    for _, outputEdge in ipairs(exitEdges) do
        local exitId = outputEdge.targetId or outputEdge.id
        local group = groupedByExitId[exitId]

        if not group then
            group = {
                edge = outputEdge,
                edges = {},
                expectedCount = 0,
                deliveredCount = 0,
                acceptedColors = {},
                acceptedLookup = {},
            }
            groupedByExitId[exitId] = group
            orderedGroups[#orderedGroups + 1] = group
        end

        group.edges[#group.edges + 1] = outputEdge
        groupByEdgeId[outputEdge.id] = group

        for _, colorId in ipairs(self:getOutputAcceptedGoalColors(outputEdge)) do
            appendUnique(group.acceptedColors, group.acceptedLookup, colorId)
        end
    end

    for _, train in ipairs(self.trains or {}) do
        local goalColor = train.goalColor or train.trainColor
        for _, group in ipairs(orderedGroups) do
            if group.acceptedLookup[goalColor] then
                group.expectedCount = group.expectedCount + 1
            end
        end

        local deliveredGroup = groupByEdgeId[train.clearingExitEdgeId]
        if deliveredGroup and self:isTrainCleared(train) then
            deliveredGroup.deliveredCount = deliveredGroup.deliveredCount + 1
        end
    end

    for _, group in ipairs(orderedGroups) do
        group.acceptedLookup = nil
        group.edges = nil
    end

    return orderedGroups
end

function world:getNextQueuedTrain()
    local bestTrain = nil
    for _, train in ipairs(self.trains) do
        if not train.spawned and not self:isTrainCleared(train) then
            if not bestTrain or (train.spawnTime or 0) < (bestTrain.spawnTime or 0) then
                bestTrain = train
            end
        end
    end
    return bestTrain
end

function world:getNearestPendingDeadline()
    local bestTrain = nil
    for _, train in ipairs(self.trains) do
        if not self:isTrainCleared(train) and train.deadline then
            if not bestTrain or train.deadline < bestTrain.deadline then
                bestTrain = train
            end
        end
    end
    return bestTrain
end

function world:getTrainSummary(train)
    if not train then
        return nil
    end
    return string.format("%s train", formatColorLabel(train.goalColor or train.trainColor))
end

function world:getActiveRouteSummary()
    local segments = {}

    for _, junction in ipairs(self.junctionOrder) do
        local activeInput = junction.inputs[junction.activeInputIndex]
        local activeOutput = junction.outputs[junction.activeOutputIndex]
        segments[#segments + 1] = string.format(
            "%s: %s -> %s",
            junction.label,
            activeInput and activeInput.label or ("Input " .. tostring(junction.activeInputIndex)),
            activeOutput and activeOutput.label or ("Output " .. tostring(junction.activeOutputIndex))
        )
    end

    return table.concat(segments, "  |  ")
end

function world:getHighlightedEdgeIds()
    local highlightedEdgeIds = {}

    for _, junction in ipairs(self.junctionOrder) do
        local activeInput = junction.inputs[junction.activeInputIndex]
        local activeOutput = junction.outputs[junction.activeOutputIndex]

        if activeInput then
            highlightedEdgeIds[activeInput.id] = true
        end

        if activeOutput then
            highlightedEdgeIds[activeOutput.id] = true
        end
    end

    return highlightedEdgeIds
end


local shared = {
    roadTypes = roadTypes,
    trackSceneRenderer = trackSceneRenderer,
    COLOR_OPTIONS = COLOR_OPTIONS,
    RELAY_FLASH_DURATION = RELAY_FLASH_DURATION,
    TRIP_FLASH_DURATION = TRIP_FLASH_DURATION,
    CROSSBAR_FLASH_DURATION = CROSSBAR_FLASH_DURATION,
    SPRING_RELEASE_DURATION = SPRING_RELEASE_DURATION,
    ICON_PRESS_STIFFNESS = ICON_PRESS_STIFFNESS,
    ICON_PRESS_DAMPING = ICON_PRESS_DAMPING,
    ICON_PRESS_IMPULSE = ICON_PRESS_IMPULSE,
    ROAD_PATTERN_OUTLINE = ROAD_PATTERN_OUTLINE,
    ROAD_PATTERN_FILL = ROAD_PATTERN_FILL,
    TRACK_STRIPE_LENGTH = TRACK_STRIPE_LENGTH,
    clamp = clamp,
    lerp = lerp,
    segmentLength = segmentLength,
    normalize = normalize,
    distanceSquared = distanceSquared,
    dot = dot,
    carriagesOverlap = carriagesOverlap,
    copyPoint = copyPoint,
    copyColor = copyColor,
    darkerColor = darkerColor,
    nearestColorId = nearestColorId,
    getColorById = getColorById,
    buildTrackStripeColors = buildTrackStripeColors,
    containsColorId = containsColorId,
    formatColorLabel = formatColorLabel,
    getRoadTypeScale = getRoadTypeScale,
    normalizeStyleSections = normalizeStyleSections,
    appendUnique = appendUnique,
    compareScheduledTrains = compareScheduledTrains,
    compareEdgesBySource = compareEdgesBySource,
    compareEdgesByTarget = compareEdgesByTarget,
    denormalizePoints = denormalizePoints,
    buildPolyline = buildPolyline,
    angleBetweenPoints = angleBetweenPoints,
    pointOnPath = pointOnPath,
    flattenPoints = flattenPoints,
    combinePointLists = combinePointLists,
    roundScoreValue = roundScoreValue,
    getTailClearanceDistance = getTailClearanceDistance,
    pointOnCircle = pointOnCircle,
    appendPoint = appendPoint,
    buildPathSlice = buildPathSlice,
    buildCubicCurvePoints = buildCubicCurvePoints,
    getControlIconScale = getControlIconScale,
    getSelectorIconScale = getSelectorIconScale,
    isPlayPhaseOnlyControl = isPlayPhaseOnlyControl,
    getTimerRatio = getTimerRatio,
    drawTimerPie = drawTimerPie,
    drawStripedSector = drawStripedSector,
    drawStripedCircleOutline = drawStripedCircleOutline,
    getJunctionInputStyle = getJunctionInputStyle,
    drawJunctionTimerPie = drawJunctionTimerPie,
    drawHourglassIcon = drawHourglassIcon,
    drawSpringIcon = drawSpringIcon,
    drawRelayIcon = drawRelayIcon,
    drawStaticJunctionIcon = drawStaticJunctionIcon,
    withIconScale = withIconScale,
    getControlBubbleLayout = getControlBubbleLayout,
    drawControlBubble = drawControlBubble,
    drawJunctionCircle = drawJunctionCircle,
}

require("src.game.gameplay.railway_world_rendering")(world, shared)

return world
