local mapPresentation = {}

local GRAPH_REVEAL_DURATION = 3.5
local TITLE_ENTER_DURATION = 0.55
local TITLE_HOLD_DURATION = 2.0
local TITLE_EXIT_DURATION = 0.55
local TITLE_LINE_DELAY = 0.18
local TITLE_TRAVEL_DISTANCE = 420
local TRACK_REVEAL_PIXELS_PER_SECOND = 560
local TRACK_REVEAL_MIN_DURATION = 0.16
local JUNCTION_RING_DURATION = 0.18
local JUNCTION_ICON_DURATION = 0.32
local JUNCTION_SELECTOR_DELAY = 0.08
local JUNCTION_SELECTOR_DURATION = 0.30
local TRACK_STATE_BLEND_DURATION = 0.42
local SIGNAL_POP_DURATION = 0.42
local UI_REVEAL_DELAY = 0.08
local UI_REVEAL_DURATION = 0.52
local UI_CARD_STAGGER = 0.07
local UI_TEXT_FADE_DELAY = 0.1
local UI_TEXT_FADE_DURATION = 0.32
local CLUSTER_MEMBER_STAGGER = 0.08

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function maxValue(a, b)
    if a > b then
        return a
    end
    return b
end

local function compareStrings(a, b)
    return tostring(a or "") < tostring(b or "")
end

local function shallowCopyArray(values)
    local copy = {}
    for index, value in ipairs(values or {}) do
        copy[index] = value
    end
    return copy
end

local function sortStrings(values)
    table.sort(values, compareStrings)
    return values
end

local function getDescriptorMapKind(descriptor)
    local resolvedDescriptor = type(descriptor) == "table" and descriptor or {}
    if resolvedDescriptor.source == "user" and resolvedDescriptor.isRemoteImport then
        return "downloaded"
    end
    if resolvedDescriptor.mapKind then
        return resolvedDescriptor.mapKind
    end
    if resolvedDescriptor.source == "user" or resolvedDescriptor.source == "remote" then
        return "user"
    end
    return "campaign"
end

local function getCreatorDisplayName(descriptor, profile)
    local resolvedDescriptor = type(descriptor) == "table" and descriptor or {}
    local candidates = {
        resolvedDescriptor.creatorDisplayName,
        resolvedDescriptor.creator_display_name,
        resolvedDescriptor.remoteSource and resolvedDescriptor.remoteSource.creatorDisplayName or nil,
        resolvedDescriptor.remoteSourceEntry and resolvedDescriptor.remoteSourceEntry.creator_display_name or nil,
        profile and profile.playerDisplayName or nil,
    }

    for _, candidate in ipairs(candidates) do
        local name = trim(candidate)
        if name ~= "" then
            return name
        end
    end

    return ""
end

local function getMapTitle(world, descriptor)
    local level = type(world) == "table" and type(world.getLevel) == "function" and world:getLevel() or nil
    local candidates = {
        level and level.title or nil,
        descriptor and descriptor.displayName or nil,
        descriptor and descriptor.name or nil,
    }

    for _, candidate in ipairs(candidates) do
        local title = trim(candidate)
        if title ~= "" then
            return title
        end
    end

    return "Untitled Map"
end

function mapPresentation.resolveSubtitle(descriptor, profile)
    local mapKind = getDescriptorMapKind(descriptor)
    if mapKind == "tutorial" then
        return "Guidebook Map"
    end
    if mapKind == "campaign" then
        return "Campaign Map"
    end

    local creatorDisplayName = getCreatorDisplayName(descriptor, profile)
    if creatorDisplayName ~= "" then
        return "by " .. creatorDisplayName
    end

    if mapKind == "downloaded" then
        return "Downloaded Map"
    end

    return "User Map"
end

local function getRenderedEdgeLength(world, edge)
    if type(world) == "table" and type(world.getRenderedTrackWindow) == "function" then
        local startDistance, endDistance = world:getRenderedTrackWindow(edge)
        return math.max(0, (endDistance or 0) - (startDistance or 0))
    end

    return math.max(0, edge and edge.path and edge.path.length or 0)
end

local function getTrackRevealDuration(world, edge)
    local visibleLength = getRenderedEdgeLength(world, edge)
    return math.max(TRACK_REVEAL_MIN_DURATION, visibleLength / TRACK_REVEAL_PIXELS_PER_SECOND)
end

local function angleBetweenPoints(a, b)
    local dx = (b and b.x or 0) - (a and a.x or 0)
    local dy = (b and b.y or 0) - (a and a.y or 0)

    if math.atan2 then
        return math.atan2(dy, dx)
    end

    if math.abs(dx) <= 0.0001 then
        return dy >= 0 and math.pi * 0.5 or -math.pi * 0.5
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

local function getJunctionEntryAngle(edge)
    local points = edge and edge.path and edge.path.points or nil
    if not points or #points < 2 then
        return -math.pi * 0.5
    end

    return angleBetweenPoints(points[#points], points[#points - 1])
end

local function buildJunctionSchedule(arrivalTime, entryEdge)
    local resolvedArrival = math.max(0, arrivalTime or 0)
    local ringStartTime = resolvedArrival
    local ringEndTime = ringStartTime + JUNCTION_RING_DURATION
    local iconStartTime = ringEndTime
    local iconEndTime = iconStartTime + JUNCTION_ICON_DURATION
    local selectorStartTime = iconEndTime + JUNCTION_SELECTOR_DELAY
    local selectorEndTime = selectorStartTime + JUNCTION_SELECTOR_DURATION

    return {
        arrivalTime = resolvedArrival,
        ringStartTime = ringStartTime,
        ringEndTime = ringEndTime,
        iconStartTime = iconStartTime,
        iconEndTime = iconEndTime,
        selectorStartTime = selectorStartTime,
        selectorEndTime = selectorEndTime,
        entryAngle = entryEdge and getJunctionEntryAngle(entryEdge) or (-math.pi * 0.5),
    }
end

local function buildGraphContext(world)
    local context = {
        edges = {},
        edgeById = {},
        incomingByTargetId = {},
        outgoingBySourceId = {},
        baseDurationByEdgeId = {},
        junctionIds = {},
    }

    for edgeId, edge in pairs(type(world) == "table" and world.edges or {}) do
        if type(edge) == "table" then
            local resolvedId = edge.id or edgeId
            edge.id = resolvedId
            context.edges[#context.edges + 1] = edge
            context.edgeById[resolvedId] = edge
            context.baseDurationByEdgeId[resolvedId] = getTrackRevealDuration(world, edge)

            if edge.sourceType == "junction" and edge.sourceId then
                context.outgoingBySourceId[edge.sourceId] = context.outgoingBySourceId[edge.sourceId] or {}
                context.outgoingBySourceId[edge.sourceId][#context.outgoingBySourceId[edge.sourceId] + 1] = edge
                context.junctionIds[edge.sourceId] = true
            end
            if edge.targetType == "junction" and edge.targetId then
                context.incomingByTargetId[edge.targetId] = context.incomingByTargetId[edge.targetId] or {}
                context.incomingByTargetId[edge.targetId][#context.incomingByTargetId[edge.targetId] + 1] = edge
                context.junctionIds[edge.targetId] = true
            end
        end
    end

    table.sort(context.edges, function(a, b)
        return compareStrings(a.id, b.id)
    end)

    for junctionId, edges in pairs(context.incomingByTargetId) do
        table.sort(edges, function(a, b)
            return compareStrings(a.id, b.id)
        end)
        context.incomingByTargetId[junctionId] = edges
    end

    for junctionId, edges in pairs(context.outgoingBySourceId) do
        table.sort(edges, function(a, b)
            return compareStrings(a.id, b.id)
        end)
        context.outgoingBySourceId[junctionId] = edges
    end

    return context
end

local function scaleSchedules(edgeSchedulesById, junctionSchedulesById, graphCompleteTime)
    if graphCompleteTime <= 0.0001 then
        return edgeSchedulesById, junctionSchedulesById, GRAPH_REVEAL_DURATION
    end

    local timeScale = GRAPH_REVEAL_DURATION / graphCompleteTime

    for _, schedule in pairs(edgeSchedulesById or {}) do
        schedule.startTime = schedule.startTime * timeScale
        schedule.endTime = schedule.endTime * timeScale
        schedule.duration = schedule.duration * timeScale
    end

    for _, schedule in pairs(junctionSchedulesById or {}) do
        schedule.arrivalTime = schedule.arrivalTime * timeScale
        schedule.ringStartTime = schedule.ringStartTime * timeScale
        schedule.ringEndTime = schedule.ringEndTime * timeScale
        schedule.iconStartTime = schedule.iconStartTime * timeScale
        schedule.iconEndTime = schedule.iconEndTime * timeScale
        schedule.selectorStartTime = schedule.selectorStartTime * timeScale
        schedule.selectorEndTime = schedule.selectorEndTime * timeScale
    end

    return edgeSchedulesById, junctionSchedulesById, GRAPH_REVEAL_DURATION
end

local function buildSccInfo(context)
    local sortedJunctionIds = {}
    for junctionId in pairs(context.junctionIds or {}) do
        sortedJunctionIds[#sortedJunctionIds + 1] = junctionId
    end
    sortStrings(sortedJunctionIds)

    local adjacencyByJunctionId = {}
    for _, junctionId in ipairs(sortedJunctionIds) do
        adjacencyByJunctionId[junctionId] = {}
    end

    for _, edge in ipairs(context.edges) do
        if edge.sourceType == "junction" and edge.targetType == "junction" and edge.sourceId and edge.targetId then
            adjacencyByJunctionId[edge.sourceId] = adjacencyByJunctionId[edge.sourceId] or {}
            adjacencyByJunctionId[edge.sourceId][#adjacencyByJunctionId[edge.sourceId] + 1] = edge.targetId
        end
    end

    for junctionId, targets in pairs(adjacencyByJunctionId) do
        table.sort(targets, compareStrings)
        adjacencyByJunctionId[junctionId] = targets
    end

    local indexByJunctionId = {}
    local lowlinkByJunctionId = {}
    local onStackByJunctionId = {}
    local stack = {}
    local nextIndex = 1
    local componentByJunctionId = {}
    local componentsById = {}
    local componentId = 0

    local function visit(junctionId)
        indexByJunctionId[junctionId] = nextIndex
        lowlinkByJunctionId[junctionId] = nextIndex
        nextIndex = nextIndex + 1
        stack[#stack + 1] = junctionId
        onStackByJunctionId[junctionId] = true

        for _, targetId in ipairs(adjacencyByJunctionId[junctionId] or {}) do
            if not indexByJunctionId[targetId] then
                visit(targetId)
                lowlinkByJunctionId[junctionId] = math.min(lowlinkByJunctionId[junctionId], lowlinkByJunctionId[targetId])
            elseif onStackByJunctionId[targetId] then
                lowlinkByJunctionId[junctionId] = math.min(lowlinkByJunctionId[junctionId], indexByJunctionId[targetId])
            end
        end

        if lowlinkByJunctionId[junctionId] == indexByJunctionId[junctionId] then
            componentId = componentId + 1
            local members = {}
            while true do
                local memberId = stack[#stack]
                stack[#stack] = nil
                onStackByJunctionId[memberId] = nil
                componentByJunctionId[memberId] = componentId
                members[#members + 1] = memberId
                if memberId == junctionId then
                    break
                end
            end
            sortStrings(members)
            componentsById[componentId] = {
                id = componentId,
                junctionIds = members,
            }
        end
    end

    for _, junctionId in ipairs(sortedJunctionIds) do
        if not indexByJunctionId[junctionId] then
            visit(junctionId)
        end
    end

    local componentSizeById = {}
    for id, component in pairs(componentsById) do
        componentSizeById[id] = #(component.junctionIds or {})
    end

    return {
        componentByJunctionId = componentByJunctionId,
        componentsById = componentsById,
        componentSizeById = componentSizeById,
    }
end

local function buildClusteredCycleSchedule(context)
    local edgeSchedulesById = {}
    local junctionSchedulesById = {}
    local graphCompleteTime = 0
    local sccInfo = buildSccInfo(context)
    local componentInfoById = {}

    for componentId, component in pairs(sccInfo.componentsById or {}) do
        componentInfoById[componentId] = {
            id = componentId,
            junctionIds = shallowCopyArray(component.junctionIds or {}),
            internalEdges = {},
            externalIncomingEdges = {},
            externalOutgoingEdges = {},
        }
    end

    for _, edge in ipairs(context.edges) do
        local sourceComponentId = edge.sourceType == "junction" and sccInfo.componentByJunctionId[edge.sourceId] or nil
        local targetComponentId = edge.targetType == "junction" and sccInfo.componentByJunctionId[edge.targetId] or nil

        if sourceComponentId and targetComponentId and sourceComponentId == targetComponentId then
            componentInfoById[sourceComponentId].internalEdges[#componentInfoById[sourceComponentId].internalEdges + 1] = edge
        elseif targetComponentId then
            componentInfoById[targetComponentId].externalIncomingEdges[#componentInfoById[targetComponentId].externalIncomingEdges + 1] = edge
        end

        if sourceComponentId and (not targetComponentId or targetComponentId ~= sourceComponentId) then
            componentInfoById[sourceComponentId].externalOutgoingEdges[#componentInfoById[sourceComponentId].externalOutgoingEdges + 1] = edge
        end
    end

    for _, componentInfo in pairs(componentInfoById) do
        table.sort(componentInfo.internalEdges, function(a, b)
            return compareStrings(a.id, b.id)
        end)
        table.sort(componentInfo.externalIncomingEdges, function(a, b)
            return compareStrings(a.id, b.id)
        end)
        table.sort(componentInfo.externalOutgoingEdges, function(a, b)
            return compareStrings(a.id, b.id)
        end)
        table.sort(componentInfo.junctionIds, compareStrings)
    end

    local componentScheduleById = {}
    local visitingComponents = {}

    local computeComponentSchedule

    local function getExternalEdgeStartTime(edge)
        if edge.sourceType == "junction" and edge.sourceId then
            local sourceComponentId = sccInfo.componentByJunctionId[edge.sourceId]
            local sourceComponentSchedule = sourceComponentId and computeComponentSchedule(sourceComponentId) or nil
            return sourceComponentSchedule and sourceComponentSchedule.completeTime or 0
        end
        return 0
    end

    computeComponentSchedule = function(componentId)
        if componentScheduleById[componentId] then
            return componentScheduleById[componentId]
        end
        if visitingComponents[componentId] then
            return {
                arrivalTime = 0,
                completeTime = JUNCTION_ICON_DURATION,
                junctionSchedulesById = {},
            }
        end

        visitingComponents[componentId] = true
        local componentInfo = componentInfoById[componentId]
        local arrivalTime = 0
        local entryEdgesByJunctionId = {}

        for _, edge in ipairs(componentInfo.externalIncomingEdges or {}) do
            local endTime = getExternalEdgeStartTime(edge) + (context.baseDurationByEdgeId[edge.id] or 0)
            arrivalTime = maxValue(arrivalTime, endTime)
            if edge.targetId then
                entryEdgesByJunctionId[edge.targetId] = entryEdgesByJunctionId[edge.targetId] or {}
                entryEdgesByJunctionId[edge.targetId][#entryEdgesByJunctionId[edge.targetId] + 1] = edge
            end
        end

        local localSchedulesByJunctionId = {}
        local internalArrivalByJunctionId = {}
        local queue = {}

        local function scheduleLocalJunction(junctionId, junctionArrivalTime, entryEdge)
            local existing = localSchedulesByJunctionId[junctionId]
            if existing and existing.arrivalTime <= junctionArrivalTime + 0.0001 then
                return false
            end

            local schedule = buildJunctionSchedule(junctionArrivalTime, entryEdge)
            localSchedulesByJunctionId[junctionId] = schedule
            queue[#queue + 1] = {
                junctionId = junctionId,
                ringEndTime = schedule.ringEndTime,
            }
            return true
        end

        local seeded = false
        for _, junctionId in ipairs(componentInfo.junctionIds or {}) do
            local entryEdges = entryEdgesByJunctionId[junctionId]
            if entryEdges and #entryEdges > 0 then
                scheduleLocalJunction(junctionId, arrivalTime, entryEdges[1])
                seeded = true
            end
        end

        if not seeded and componentInfo.junctionIds[1] then
            scheduleLocalJunction(componentInfo.junctionIds[1], arrivalTime, nil)
        end

        while #queue > 0 do
            local bestIndex = 1
            local bestRingEnd = queue[1].ringEndTime
            for index = 2, #queue do
                if queue[index].ringEndTime < bestRingEnd - 0.0001 then
                    bestIndex = index
                    bestRingEnd = queue[index].ringEndTime
                end
            end
            local queued = queue[bestIndex]
            table.remove(queue, bestIndex)

            local sourceJunctionId = queued.junctionId
            for _, edge in ipairs(context.outgoingBySourceId[sourceJunctionId] or {}) do
                local targetComponentId = edge.targetType == "junction" and sccInfo.componentByJunctionId[edge.targetId] or nil
                if targetComponentId == componentId then
                    local edgeEndTime = queued.ringEndTime + (context.baseDurationByEdgeId[edge.id] or 0)
                    local currentArrivalTime = internalArrivalByJunctionId[edge.targetId]
                    if currentArrivalTime == nil or edgeEndTime < currentArrivalTime - 0.0001 then
                        internalArrivalByJunctionId[edge.targetId] = edgeEndTime
                        scheduleLocalJunction(edge.targetId, edgeEndTime, edge)
                    end
                end
            end
        end

        local completeTime = arrivalTime
        for _, junctionId in ipairs(componentInfo.junctionIds or {}) do
            local schedule = localSchedulesByJunctionId[junctionId]
            if not schedule then
                schedule = buildJunctionSchedule(arrivalTime, nil)
                localSchedulesByJunctionId[junctionId] = schedule
            end

            if (sccInfo.componentSizeById[componentId] or 0) > 1 then
                local memberIndex = 0
                for index, memberId in ipairs(componentInfo.junctionIds or {}) do
                    if memberId == junctionId then
                        memberIndex = index - 1
                        break
                    end
                end
                schedule.arrivalTime = schedule.arrivalTime + (memberIndex * CLUSTER_MEMBER_STAGGER)
                schedule.ringStartTime = schedule.arrivalTime
                schedule.ringEndTime = schedule.ringStartTime + JUNCTION_RING_DURATION
                schedule.iconStartTime = schedule.ringEndTime
                schedule.iconEndTime = schedule.iconStartTime + JUNCTION_ICON_DURATION
            end

            completeTime = maxValue(completeTime, schedule.selectorEndTime)
        end

        local schedule = {
            arrivalTime = arrivalTime,
            completeTime = completeTime,
            junctionSchedulesById = localSchedulesByJunctionId,
        }
        componentScheduleById[componentId] = schedule
        visitingComponents[componentId] = nil
        return schedule
    end

    for componentId in pairs(componentInfoById) do
        local componentSchedule = computeComponentSchedule(componentId)
        for junctionId, schedule in pairs(componentSchedule.junctionSchedulesById or {}) do
            junctionSchedulesById[junctionId] = schedule
            graphCompleteTime = maxValue(graphCompleteTime, schedule.selectorEndTime)
        end
        graphCompleteTime = maxValue(graphCompleteTime, componentSchedule.completeTime or 0)
    end

    for _, edge in ipairs(context.edges) do
        local sourceComponentId = edge.sourceType == "junction" and sccInfo.componentByJunctionId[edge.sourceId] or nil
        local targetComponentId = edge.targetType == "junction" and sccInfo.componentByJunctionId[edge.targetId] or nil
        local startTime = 0
        local endTime = 0

        if sourceComponentId and targetComponentId and sourceComponentId == targetComponentId then
            local sourceSchedule = junctionSchedulesById[edge.sourceId]
            local targetSchedule = junctionSchedulesById[edge.targetId]
            startTime = sourceSchedule and sourceSchedule.ringEndTime or 0
            endTime = targetSchedule and targetSchedule.arrivalTime or (startTime + (context.baseDurationByEdgeId[edge.id] or 0))
        elseif targetComponentId then
            startTime = getExternalEdgeStartTime(edge)
            local targetComponentSchedule = computeComponentSchedule(targetComponentId)
            endTime = targetComponentSchedule and targetComponentSchedule.arrivalTime or (startTime + (context.baseDurationByEdgeId[edge.id] or 0))
        elseif sourceComponentId then
            local sourceComponentSchedule = computeComponentSchedule(sourceComponentId)
            startTime = sourceComponentSchedule and sourceComponentSchedule.completeTime or 0
            endTime = startTime + (context.baseDurationByEdgeId[edge.id] or 0)
        else
            startTime = 0
            endTime = startTime + (context.baseDurationByEdgeId[edge.id] or 0)
        end

        edgeSchedulesById[edge.id] = {
            startTime = startTime,
            endTime = endTime,
            duration = math.max(0, endTime - startTime),
        }
        graphCompleteTime = maxValue(graphCompleteTime, endTime)
    end

    return edgeSchedulesById, junctionSchedulesById, graphCompleteTime
end

local function buildPresentationSchedule(world)
    local context = buildGraphContext(world)
    local edgeSchedulesById, junctionSchedulesById, graphCompleteTime = buildClusteredCycleSchedule(context)
    return scaleSchedules(edgeSchedulesById, junctionSchedulesById, graphCompleteTime)
end

function mapPresentation.buildState(world, descriptor, profile)
    if type(world) ~= "table" then
        return nil
    end

    local edgeSchedulesById, junctionSchedulesById, graphCompleteTime = buildPresentationSchedule(world)
    local title = getMapTitle(world, descriptor)
    local subtitle = mapPresentation.resolveSubtitle(descriptor, profile)
    local inputGroupCount = type(world.getInputEdgeGroups) == "function" and #(world:getInputEdgeGroups() or {}) or 0
    local outputGroupCount = type(world.getOutputBadgeGroups) == "function" and #(world:getOutputBadgeGroups() or {}) or 0
    local maxCardDelay = math.max(inputGroupCount - 1, outputGroupCount - 1, 0) * UI_CARD_STAGGER
    local titleEndTime = TITLE_ENTER_DURATION + TITLE_HOLD_DURATION + TITLE_EXIT_DURATION
    if subtitle ~= "" then
        titleEndTime = titleEndTime + TITLE_LINE_DELAY
    end

    local uiRevealStartTime = graphCompleteTime + UI_REVEAL_DELAY
    local trackStateBlendEndTime = graphCompleteTime + TRACK_STATE_BLEND_DURATION
    local signalPopEndTime = graphCompleteTime + SIGNAL_POP_DURATION
    local finishTime = math.max(
        titleEndTime,
        uiRevealStartTime + UI_REVEAL_DURATION + maxCardDelay,
        trackStateBlendEndTime,
        signalPopEndTime
    )
    local allEdgeIds = {}
    for edgeId in pairs(edgeSchedulesById) do
        allEdgeIds[edgeId] = true
    end

    return {
        elapsed = 0,
        finishTime = finishTime,
        title = title,
        subtitle = subtitle,
        titleSequence = {
            enterDuration = TITLE_ENTER_DURATION,
            holdDuration = TITLE_HOLD_DURATION,
            exitDuration = TITLE_EXIT_DURATION,
            lineDelay = TITLE_LINE_DELAY,
            travelDistance = TITLE_TRAVEL_DISTANCE,
            endTime = titleEndTime,
        },
        uiReveal = {
            startTime = uiRevealStartTime,
            duration = UI_REVEAL_DURATION,
            cardStagger = UI_CARD_STAGGER,
            textFadeDelay = UI_TEXT_FADE_DELAY,
            textFadeDuration = UI_TEXT_FADE_DURATION,
            maxCardDelay = maxCardDelay,
        },
        graphCompleteTime = graphCompleteTime,
        trackStateBlend = {
            startTime = graphCompleteTime,
            duration = TRACK_STATE_BLEND_DURATION,
            endTime = trackStateBlendEndTime,
        },
        signalPop = {
            startTime = graphCompleteTime,
            duration = SIGNAL_POP_DURATION,
            endTime = signalPopEndTime,
        },
        edgeScheduleById = edgeSchedulesById,
        junctionScheduleById = junctionSchedulesById,
        allEdgeIds = allEdgeIds,
        titleOnly = false,
    }
end

function mapPresentation.isBlocking(state)
    return type(state) == "table" and state.titleOnly ~= true
end

function mapPresentation.skip(state)
    if type(state) ~= "table" then
        return nil
    end

    local titleEndTime = state.titleSequence and state.titleSequence.endTime or 0
    if (state.elapsed or 0) >= titleEndTime - 0.0001 then
        return nil
    end

    state.titleOnly = true
    return state
end

function mapPresentation.update(state, dt)
    if type(state) ~= "table" then
        return true
    end

    local maxElapsed = state.finishTime or 0
    if state.titleOnly == true then
        maxElapsed = state.titleSequence and state.titleSequence.endTime or maxElapsed
    end

    state.elapsed = clamp((state.elapsed or 0) + math.max(0, dt or 0), 0, maxElapsed)
    return state.elapsed >= maxElapsed - 0.0001
end

return mapPresentation
