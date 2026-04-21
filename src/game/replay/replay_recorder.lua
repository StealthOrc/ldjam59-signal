local replayRecorder = {}

local REPLAY_VERSION = 1
local TIME_PRECISION = 1000
local POSITION_PRECISION = 1
local CURSOR_SAMPLE_INTERVAL_SECONDS = 0.08
local CURSOR_SAMPLE_MIN_DISTANCE = 6
local CURSOR_SAMPLE_MIN_DISTANCE_SQUARED = CURSOR_SAMPLE_MIN_DISTANCE * CURSOR_SAMPLE_MIN_DISTANCE

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, entry in pairs(value) do
        copy[deepCopy(key)] = deepCopy(entry)
    end

    return copy
end

local function roundToPrecision(value, precision)
    local scaledValue = (value or 0) * precision
    if scaledValue >= 0 then
        return math.floor(scaledValue + 0.5) / precision
    end

    return math.ceil(scaledValue - 0.5) / precision
end

local function normalizeTime(value)
    return roundToPrecision(math.max(0, value or 0), TIME_PRECISION)
end

local function normalizePosition(value)
    return roundToPrecision(value or 0, POSITION_PRECISION)
end

local function distanceSquared(ax, ay, bx, by)
    local dx = (ax or 0) - (bx or 0)
    local dy = (ay or 0) - (by or 0)
    return dx * dx + dy * dy
end

local function normalizeInteraction(event, defaultTime)
    local resolvedTime = normalizeTime(event and event.time or defaultTime or 0)
    return {
        time = resolvedTime,
        target = event and event.target or "junction",
        junctionId = event and event.junctionId or "",
        button = tonumber(event and event.button) or 1,
        x = normalizePosition(event and event.x or 0),
        y = normalizePosition(event and event.y or 0),
    }
end

local function packInteraction(interaction)
    local packedInteraction = {
        target = interaction and interaction.target or "junction",
        junctionId = interaction and interaction.junctionId or "",
        button = tonumber(interaction and interaction.button) or 1,
    }

    if interaction and interaction.time ~= nil and interaction.x ~= nil and interaction.y ~= nil then
        packedInteraction.txy = {
            normalizeTime(interaction.time),
            normalizePosition(interaction.x),
            normalizePosition(interaction.y),
        }
    else
        packedInteraction.time = normalizeTime(interaction and interaction.time or 0)
        packedInteraction.x = normalizePosition(interaction and interaction.x or 0)
        packedInteraction.y = normalizePosition(interaction and interaction.y or 0)
    end

    return packedInteraction
end

local function packCursorSamples(cursorSamples)
    local packedSamples = {
        t = {},
        x = {},
        y = {},
    }

    for index, sample in ipairs(cursorSamples or {}) do
        packedSamples.t[index] = normalizeTime(sample and sample.time or 0)
        packedSamples.x[index] = normalizePosition(sample and sample.x or 0)
        packedSamples.y[index] = normalizePosition(sample and sample.y or 0)
    end

    return packedSamples
end

function replayRecorder.new(options)
    local resolvedOptions = options or {}
    local self = setmetatable({}, { __index = replayRecorder })

    self.version = REPLAY_VERSION
    self.mapUuid = resolvedOptions.mapUuid
    self.mapTitle = resolvedOptions.mapTitle
    self.mapUpdatedAt = resolvedOptions.mapUpdatedAt
    self.createdAt = resolvedOptions.createdAt
    self.initialJunctions = deepCopy(resolvedOptions.initialJunctions or {})
    self.preparationInteractions = {}
    self.cursorSamples = {}
    self.interactions = {}
    self.timelineEvents = {}
    self.duration = 0
    self.lastCursorSample = nil

    for _, preparationInteraction in ipairs(resolvedOptions.preparationInteractions or {}) do
        self.preparationInteractions[#self.preparationInteractions + 1] = normalizeInteraction(preparationInteraction, 0)
    end

    self:recordTimelineEvent({
        time = 0,
        kind = "start",
    })

    if #self.preparationInteractions > 0 then
        self:recordTimelineEvent({
            time = 0,
            kind = "preparation",
            interactionCount = #self.preparationInteractions,
        })
    end

    if resolvedOptions.initialCursor then
        self:recordCursor(
            0,
            resolvedOptions.initialCursor.x or 0,
            resolvedOptions.initialCursor.y or 0,
            true
        )
    end

    return self
end

function replayRecorder:recordCursor(time, x, y, forceSample)
    local sample = {
        time = normalizeTime(time),
        x = normalizePosition(x),
        y = normalizePosition(y),
    }
    local previousSample = self.lastCursorSample

    if not forceSample and previousSample then
        local elapsedSeconds = sample.time - previousSample.time
        local movedDistanceSquared = distanceSquared(sample.x, sample.y, previousSample.x, previousSample.y)
        if elapsedSeconds < CURSOR_SAMPLE_INTERVAL_SECONDS
            and movedDistanceSquared < CURSOR_SAMPLE_MIN_DISTANCE_SQUARED then
            return previousSample
        end
    end

    self.cursorSamples[#self.cursorSamples + 1] = sample
    self.lastCursorSample = sample
    self.duration = math.max(self.duration, sample.time)
    return sample
end

function replayRecorder:recordInteraction(event)
    local interaction = normalizeInteraction(event, 0)
    self.interactions[#self.interactions + 1] = interaction
    self:recordCursor(interaction.time, interaction.x, interaction.y, true)
    self:recordTimelineEvent({
        time = interaction.time,
        kind = "interaction",
        target = interaction.target,
        junctionId = interaction.junctionId,
        button = interaction.button,
    })
    return interaction
end

function replayRecorder:recordTimelineEvent(event)
    local resolvedEvent = {
        time = normalizeTime(event and event.time or 0),
        kind = event and event.kind or "unknown",
    }

    for key, value in pairs(event or {}) do
        if key ~= "time" and key ~= "kind" then
            resolvedEvent[key] = deepCopy(value)
        end
    end

    self.timelineEvents[#self.timelineEvents + 1] = resolvedEvent
    self.duration = math.max(self.duration, resolvedEvent.time)
    return resolvedEvent
end

function replayRecorder:setDuration(duration)
    self.duration = math.max(self.duration, normalizeTime(duration))
end

function replayRecorder:buildRecord(extraFields)
    local record = {
        version = self.version,
        mapUuid = self.mapUuid,
        mapTitle = self.mapTitle,
        mapUpdatedAt = self.mapUpdatedAt,
        createdAt = self.createdAt,
        duration = self.duration,
        initialJunctions = deepCopy(self.initialJunctions),
        preparationInteractions = {},
        cursorSamples = packCursorSamples(self.cursorSamples),
        interactions = {},
        timelineEvents = deepCopy(self.timelineEvents),
    }

    for index, interaction in ipairs(self.preparationInteractions) do
        record.preparationInteractions[index] = packInteraction(interaction)
    end

    for index, interaction in ipairs(self.interactions) do
        record.interactions[index] = packInteraction(interaction)
    end

    for key, value in pairs(extraFields or {}) do
        record[key] = deepCopy(value)
    end

    return record
end

return replayRecorder
