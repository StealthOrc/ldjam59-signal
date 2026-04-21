local world = require("src.game.gameplay.railway_world")

local replayRuntime = {}

local REPLAY_SIMULATION_STEP_SECONDS = 1 / 120
local TIME_EPSILON_SECONDS = 0.0005
local CLICK_PULSE_DURATION_SECONDS = 0.25

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function computeReplayDuration(record)
    local duration = math.max(0, tonumber(record and record.duration) or 0)
    local cursorSamples = record and record.cursorSamples or {}

    if type(cursorSamples.t) == "table" then
        for _, sampleTime in ipairs(cursorSamples.t) do
            duration = math.max(duration, tonumber(sampleTime) or 0)
        end
    else
        for _, sample in ipairs(cursorSamples) do
            duration = math.max(duration, tonumber(sample.time) or 0)
        end
    end

    for _, interaction in ipairs(record and record.interactions or {}) do
        local packedTime = interaction and interaction.txy and interaction.txy[1] or nil
        duration = math.max(duration, tonumber(packedTime ~= nil and packedTime or interaction.time) or 0)
    end

    for _, event in ipairs(record and record.timelineEvents or {}) do
        duration = math.max(duration, tonumber(event.time) or 0)
    end

    return duration
end

local function normalizeCursorSamples(cursorSamples)
    local normalizedSamples = {}
    if type(cursorSamples) ~= "table" then
        return normalizedSamples
    end

    if type(cursorSamples.t) == "table" then
        local sampleCount = math.min(#(cursorSamples.t or {}), #(cursorSamples.x or {}), #(cursorSamples.y or {}))
        for index = 1, sampleCount do
            normalizedSamples[index] = {
                time = tonumber(cursorSamples.t[index]) or 0,
                x = tonumber(cursorSamples.x[index]) or 0,
                y = tonumber(cursorSamples.y[index]) or 0,
            }
        end
        return normalizedSamples
    end

    for index, sample in ipairs(cursorSamples) do
        normalizedSamples[index] = {
            time = tonumber(sample.time) or 0,
            x = tonumber(sample.x) or 0,
            y = tonumber(sample.y) or 0,
        }
    end

    return normalizedSamples
end

local function resolveId(idPool, literalValue, refValue, fallbackValue)
    if type(literalValue) == "string" and literalValue ~= "" then
        return literalValue
    end

    local resolvedRef = tonumber(refValue)
    if resolvedRef and type(idPool) == "table" and type(idPool[resolvedRef]) == "string" then
        return idPool[resolvedRef]
    end

    return fallbackValue
end

local function normalizeInteraction(interaction, idPool)
    local packedTime = interaction and interaction.txy and interaction.txy[1] or nil
    local packedX = interaction and interaction.txy and interaction.txy[2] or nil
    local packedY = interaction and interaction.txy and interaction.txy[3] or nil

    return {
        time = tonumber(packedTime ~= nil and packedTime or (interaction and interaction.time)) or 0,
        x = tonumber(packedX ~= nil and packedX or (interaction and interaction.x)) or 0,
        y = tonumber(packedY ~= nil and packedY or (interaction and interaction.y)) or 0,
        target = resolveId(idPool, interaction and interaction.target, interaction and interaction.targetRef, "junction"),
        junctionId = resolveId(idPool, interaction and interaction.junctionId, interaction and interaction.junctionRef, ""),
        button = tonumber(interaction and interaction.button) or 1,
    }
end

local function normalizeInteractions(interactions, idPool)
    local normalizedInteractions = {}

    for index, interaction in ipairs(interactions or {}) do
        normalizedInteractions[index] = normalizeInteraction(interaction, idPool)
    end

    return normalizedInteractions
end

local function normalizeInitialJunctions(junctionStates, idPool)
    local normalizedStates = {}

    for index, junctionState in ipairs(junctionStates or {}) do
        normalizedStates[index] = {
            id = resolveId(idPool, junctionState and junctionState.id, junctionState and junctionState.junctionRef, ""),
            activeInputIndex = tonumber(junctionState and junctionState.activeInputIndex) or 1,
            activeOutputIndex = tonumber(junctionState and junctionState.activeOutputIndex) or 1,
        }
    end

    return normalizedStates
end

local function normalizeTimelineEvents(events, idPool)
    local normalizedEvents = {}

    for index, event in ipairs(events or {}) do
        local normalizedEvent = {}

        for key, value in pairs(event or {}) do
            if key ~= "kindRef"
                and key ~= "junctionRef"
                and key ~= "trainRef"
                and key ~= "edgeRef"
                and key ~= "reasonRef"
                and key ~= "endReasonRef"
                and key ~= "targetRef" then
                normalizedEvent[key] = value
            end
        end

        normalizedEvent.kind = resolveId(idPool, event and event.kind, event and event.kindRef, "unknown")
        normalizedEvent.junctionId = resolveId(idPool, event and event.junctionId, event and event.junctionRef, nil)
        normalizedEvent.trainId = resolveId(idPool, event and event.trainId, event and event.trainRef, nil)
        normalizedEvent.edgeId = resolveId(idPool, event and event.edgeId, event and event.edgeRef, nil)
        normalizedEvent.reason = resolveId(idPool, event and event.reason, event and event.reasonRef, nil)
        normalizedEvent.endReason = resolveId(idPool, event and event.endReason, event and event.endReasonRef, nil)
        normalizedEvent.target = resolveId(idPool, event and event.target, event and event.targetRef, nil)
        normalizedEvents[index] = normalizedEvent
    end

    return normalizedEvents
end

local function normalizeRecord(record)
    local resolvedRecord = record or {}
    local idPool = resolvedRecord.idPool or {}

    return {
        version = resolvedRecord.version,
        replayId = resolvedRecord.replayId,
        mapUuid = resolvedRecord.mapUuid,
        mapTitle = resolvedRecord.mapTitle,
        mapHash = resolvedRecord.mapHash,
        mapUpdatedAt = resolvedRecord.mapUpdatedAt,
        createdAt = resolvedRecord.createdAt,
        duration = resolvedRecord.duration,
        endReason = resolvedRecord.endReason,
        cursorSamples = normalizeCursorSamples(resolvedRecord.cursorSamples),
        initialJunctions = normalizeInitialJunctions(resolvedRecord.initialJunctions, idPool),
        preparationInteractions = normalizeInteractions(resolvedRecord.preparationInteractions, idPool),
        interactions = normalizeInteractions(resolvedRecord.interactions, idPool),
        timelineEvents = normalizeTimelineEvents(resolvedRecord.timelineEvents, idPool),
    }
end

local function advanceWorld(playbackWorld, duration)
    local remainingDuration = math.max(0, duration or 0)

    while remainingDuration > TIME_EPSILON_SECONDS do
        local stepDuration = math.min(remainingDuration, REPLAY_SIMULATION_STEP_SECONDS)
        playbackWorld:update(stepDuration)
        remainingDuration = remainingDuration - stepDuration
    end
end

function replayRuntime.new(levelSource, replayRecord, viewportW, viewportH)
    local self = setmetatable({}, { __index = replayRuntime })
    self.levelSource = levelSource or {}
    self.record = normalizeRecord(replayRecord)
    self.cursorSamples = self.record.cursorSamples or {}
    self.interactions = self.record.interactions or {}
    self.viewport = {
        w = viewportW or 1280,
        h = viewportH or 720,
    }
    self.duration = computeReplayDuration(self.record)
    self.currentTime = 0
    self.isPlaying = false
    self.nextInteractionIndex = 1
    self.playbackWorld = nil
    self:resetPlaybackWorld()
    return self
end

function replayRuntime:resetPlaybackWorld()
    self.playbackWorld = world.new(self.viewport.w, self.viewport.h, self.levelSource)
    if self.playbackWorld.setReplayListener then
        self.playbackWorld:setReplayListener(nil)
    end
    if self.playbackWorld.applyReplayJunctionStates then
        self.playbackWorld:applyReplayJunctionStates(self.record.initialJunctions or {})
    end
    self.currentTime = 0
    self.nextInteractionIndex = 1
end

function replayRuntime:advanceTo(targetTime)
    local clampedTargetTime = clamp(targetTime or 0, 0, self.duration)
    local interactions = self.interactions or {}

    while self.nextInteractionIndex <= #interactions do
        local interaction = interactions[self.nextInteractionIndex]
        local interactionTime = tonumber(interaction.time) or 0
        if interactionTime > clampedTargetTime + TIME_EPSILON_SECONDS then
            break
        end

        advanceWorld(self.playbackWorld, interactionTime - self.currentTime)
        self.currentTime = interactionTime
        if self.playbackWorld.applyReplayInteraction then
            self.playbackWorld:applyReplayInteraction(interaction)
        end
        self.nextInteractionIndex = self.nextInteractionIndex + 1
    end

    advanceWorld(self.playbackWorld, clampedTargetTime - self.currentTime)
    self.currentTime = clampedTargetTime
end

function replayRuntime:seek(targetTime)
    local clampedTargetTime = clamp(targetTime or 0, 0, self.duration)
    if clampedTargetTime + TIME_EPSILON_SECONDS < self.currentTime then
        self:resetPlaybackWorld()
    end

    self:advanceTo(clampedTargetTime)
    return self.currentTime
end

function replayRuntime:update(dt)
    if not self.isPlaying then
        return
    end

    local targetTime = self.currentTime + math.max(0, dt or 0)
    if targetTime >= self.duration - TIME_EPSILON_SECONDS then
        self:seek(self.duration)
        self.isPlaying = false
        return
    end

    self:seek(targetTime)
end

function replayRuntime:setPlaying(isPlaying)
    if self.duration <= 0 then
        self.isPlaying = false
        return
    end

    if self.currentTime >= self.duration - TIME_EPSILON_SECONDS and isPlaying then
        self:seek(0)
    end

    self.isPlaying = isPlaying == true
end

function replayRuntime:togglePlaying()
    self:setPlaying(not self.isPlaying)
end

function replayRuntime:getCursorAtTime(time)
    local cursorSamples = self.cursorSamples or {}
    if #cursorSamples == 0 then
        return nil
    end

    local clampedTime = clamp(time or self.currentTime, 0, self.duration)
    local previousSample = cursorSamples[1]
    local nextSample = nil

    for _, sample in ipairs(cursorSamples) do
        if (tonumber(sample.time) or 0) <= clampedTime + TIME_EPSILON_SECONDS then
            previousSample = sample
        else
            nextSample = sample
            break
        end
    end

    if not nextSample then
        return {
            x = previousSample.x,
            y = previousSample.y,
            time = previousSample.time,
        }
    end

    local previousTime = tonumber(previousSample.time) or 0
    local nextTime = tonumber(nextSample.time) or previousTime
    if nextTime <= previousTime + TIME_EPSILON_SECONDS then
        return {
            x = previousSample.x,
            y = previousSample.y,
            time = previousSample.time,
        }
    end

    local ratio = clamp((clampedTime - previousTime) / (nextTime - previousTime), 0, 1)
    return {
        x = previousSample.x + ((nextSample.x - previousSample.x) * ratio),
        y = previousSample.y + ((nextSample.y - previousSample.y) * ratio),
        time = clampedTime,
    }
end

function replayRuntime:getCursor()
    return self:getCursorAtTime(self.currentTime)
end

function replayRuntime:getRecentInteraction()
    local interactions = self.interactions or {}

    for index = #interactions, 1, -1 do
        local interaction = interactions[index]
        local interactionTime = tonumber(interaction.time) or 0
        if interactionTime <= self.currentTime + TIME_EPSILON_SECONDS then
            if self.currentTime - interactionTime <= CLICK_PULSE_DURATION_SECONDS then
                return interaction
            end

            break
        end
    end

    return nil
end

return replayRuntime
