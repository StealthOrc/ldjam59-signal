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
local TRACK_STATE_BLEND_DURATION = 0.42
local SIGNAL_POP_DURATION = 0.42
local UI_REVEAL_DELAY = 0.08
local UI_REVEAL_DURATION = 0.52
local UI_CARD_STAGGER = 0.07
local UI_TEXT_FADE_DELAY = 0.1
local UI_TEXT_FADE_DURATION = 0.32

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

local function popNextQueuedEdge(queue)
    if #queue == 0 then
        return nil
    end

    local bestIndex = 1
    local bestTime = queue[1].startTime
    for index = 2, #queue do
        if queue[index].startTime < bestTime then
            bestIndex = index
            bestTime = queue[index].startTime
        end
    end

    local entry = queue[bestIndex]
    table.remove(queue, bestIndex)
    return entry
end

local function queueEdgeIfEarlier(queue, edgeSchedulesById, world, edge, startTime)
    if not edge or not edge.id then
        return false
    end

    local duration = getTrackRevealDuration(world, edge)
    local existingSchedule = edgeSchedulesById[edge.id]
    if existingSchedule and existingSchedule.startTime <= startTime + 0.0001 then
        return false
    end

    edgeSchedulesById[edge.id] = {
        startTime = startTime,
        endTime = startTime + duration,
        duration = duration,
    }
    queue[#queue + 1] = {
        edgeId = edge.id,
        startTime = startTime,
    }
    return true
end

local function buildPresentationSchedule(world)
    local edges = {}
    local edgeById = {}
    local outgoingBySourceId = {}

    for edgeId, edge in pairs(type(world) == "table" and world.edges or {}) do
        if type(edge) == "table" then
            local resolvedId = edge.id or edgeId
            edge.id = resolvedId
            edges[#edges + 1] = edge
            edgeById[resolvedId] = edge
            if edge.sourceType == "junction" and edge.sourceId then
                outgoingBySourceId[edge.sourceId] = outgoingBySourceId[edge.sourceId] or {}
                outgoingBySourceId[edge.sourceId][#outgoingBySourceId[edge.sourceId] + 1] = edge
            end
        end
    end

    local queue = {}
    local edgeSchedulesById = {}
    local junctionSchedulesById = {}
    local graphCompleteTime = 0

    for _, edge in ipairs(edges) do
        if edge.sourceType == "start" then
            queueEdgeIfEarlier(queue, edgeSchedulesById, world, edge, 0)
        end
    end

    if #queue == 0 then
        for _, edge in ipairs(edges) do
            queueEdgeIfEarlier(queue, edgeSchedulesById, world, edge, 0)
        end
    end

    while true do
        local queuedEdge = popNextQueuedEdge(queue)
        if not queuedEdge then
            break
        end

        local edgeSchedule = edgeSchedulesById[queuedEdge.edgeId]
        if edgeSchedule and math.abs(edgeSchedule.startTime - queuedEdge.startTime) <= 0.0001 then
            local edge = edgeById[queuedEdge.edgeId]
            graphCompleteTime = maxValue(graphCompleteTime, edgeSchedule.endTime)

            if edge and edge.targetType == "junction" and edge.targetId then
                local arrivalTime = edgeSchedule.endTime
                local existingJunctionSchedule = junctionSchedulesById[edge.targetId]
                if not existingJunctionSchedule or arrivalTime < existingJunctionSchedule.arrivalTime - 0.0001 then
                    local ringStartTime = arrivalTime
                    local ringEndTime = ringStartTime + JUNCTION_RING_DURATION
                    local iconStartTime = ringEndTime
                    local iconEndTime = iconStartTime + JUNCTION_ICON_DURATION
                    junctionSchedulesById[edge.targetId] = {
                        arrivalTime = arrivalTime,
                        ringStartTime = ringStartTime,
                        ringEndTime = ringEndTime,
                        iconStartTime = iconStartTime,
                        iconEndTime = iconEndTime,
                        entryAngle = getJunctionEntryAngle(edge),
                    }
                    graphCompleteTime = maxValue(graphCompleteTime, iconEndTime)

                    for _, outgoingEdge in ipairs(outgoingBySourceId[edge.targetId] or {}) do
                        queueEdgeIfEarlier(queue, edgeSchedulesById, world, outgoingEdge, iconEndTime)
                    end
                end
            end
        end
    end

    local scheduledFallbackEdge = false
    for _, edge in ipairs(edges) do
        if not edgeSchedulesById[edge.id] then
            local fallbackStartTime = 0
            local sourceJunctionSchedule = edge.sourceId and junctionSchedulesById[edge.sourceId] or nil
            if sourceJunctionSchedule then
                fallbackStartTime = sourceJunctionSchedule.iconEndTime
            end
            scheduledFallbackEdge = queueEdgeIfEarlier(queue, edgeSchedulesById, world, edge, fallbackStartTime) or scheduledFallbackEdge
        end
    end

    if scheduledFallbackEdge then
        while true do
            local queuedEdge = popNextQueuedEdge(queue)
            if not queuedEdge then
                break
            end

            local edgeSchedule = edgeSchedulesById[queuedEdge.edgeId]
            if edgeSchedule then
                graphCompleteTime = maxValue(graphCompleteTime, edgeSchedule.endTime)
            end
        end
    end

    if graphCompleteTime > 0.0001 then
        local timeScale = GRAPH_REVEAL_DURATION / graphCompleteTime

        for _, schedule in pairs(edgeSchedulesById) do
            schedule.startTime = schedule.startTime * timeScale
            schedule.endTime = schedule.endTime * timeScale
            schedule.duration = schedule.duration * timeScale
        end

        for _, schedule in pairs(junctionSchedulesById) do
            schedule.arrivalTime = schedule.arrivalTime * timeScale
            schedule.ringStartTime = schedule.ringStartTime * timeScale
            schedule.ringEndTime = schedule.ringEndTime * timeScale
            schedule.iconStartTime = schedule.iconStartTime * timeScale
            schedule.iconEndTime = schedule.iconEndTime * timeScale
        end
    end

    return edgeSchedulesById, junctionSchedulesById, GRAPH_REVEAL_DURATION
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
