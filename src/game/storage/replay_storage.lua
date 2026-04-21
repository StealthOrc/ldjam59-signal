local json = require("src.game.util.json")
local toml = require("src.game.util.toml")
local uuid = require("src.game.util.uuid")
local storagePaths = require("src.game.storage.storage_paths")

local replayStorage = {}

local REPLAY_DIRECTORY_NAME = "replays"
local REPLAY_FILE_EXTENSION = ".toml"
local REPLAY_FILE_MISSING_ERROR = "Replay file missing."

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

local function packCursorSamples(cursorSamples)
    if type(cursorSamples) ~= "table" then
        return cursorSamples
    end
    if type(cursorSamples.t) == "table" and type(cursorSamples.x) == "table" and type(cursorSamples.y) == "table" then
        return deepCopy(cursorSamples)
    end

    local packedSamples = {
        t = {},
        x = {},
        y = {},
    }

    for index, sample in ipairs(cursorSamples) do
        packedSamples.t[index] = tonumber(sample and sample.time) or 0
        packedSamples.x[index] = tonumber(sample and sample.x) or 0
        packedSamples.y[index] = tonumber(sample and sample.y) or 0
    end

    return packedSamples
end

local function isPackedReplayRecord(replayRecord)
    return type(replayRecord) == "table" and type(replayRecord.idPool) == "table"
end

local function createIdPool()
    return {
        values = {},
        indexByValue = {},
    }
end

local function internId(idPool, value)
    if type(value) ~= "string" or value == "" then
        return nil
    end

    local existingIndex = idPool.indexByValue[value]
    if existingIndex then
        return existingIndex
    end

    local nextIndex = #idPool.values + 1
    idPool.values[nextIndex] = value
    idPool.indexByValue[value] = nextIndex
    return nextIndex
end

local function assignIdRef(target, key, refKey, idPool, source)
    local refValue = internId(idPool, source and source[key] or nil)
    if refValue then
        target[refKey] = refValue
    end
end

local function packInteraction(interaction, idPool)
    local packedInteraction = {
        button = tonumber(interaction and interaction.button) or 1,
    }

    assignIdRef(packedInteraction, "target", "targetRef", idPool, interaction)
    assignIdRef(packedInteraction, "junctionId", "junctionRef", idPool, interaction)

    if type(interaction and interaction.txy) == "table" then
        packedInteraction.txy = deepCopy(interaction.txy)
        return packedInteraction
    end

    packedInteraction.txy = {
        tonumber(interaction and interaction.time) or 0,
        tonumber(interaction and interaction.x) or 0,
        tonumber(interaction and interaction.y) or 0,
    }
    return packedInteraction
end

local function packInteractions(interactions, idPool)
    local packedInteractions = {}

    for index, interaction in ipairs(interactions or {}) do
        packedInteractions[index] = packInteraction(interaction, idPool)
    end

    return packedInteractions
end

local function packInitialJunctionStates(junctionStates, idPool)
    local packedStates = {}

    for index, junctionState in ipairs(junctionStates or {}) do
        packedStates[index] = {
            activeInputIndex = tonumber(junctionState and junctionState.activeInputIndex) or 1,
            activeOutputIndex = tonumber(junctionState and junctionState.activeOutputIndex) or 1,
        }
        assignIdRef(packedStates[index], "id", "junctionRef", idPool, junctionState)
    end

    return packedStates
end

local function packTimelineEvent(event, idPool)
    local packedEvent = {}

    for key, value in pairs(event or {}) do
        if key == "kind" then
            assignIdRef(packedEvent, key, "kindRef", idPool, event)
        elseif key == "junctionId" then
            assignIdRef(packedEvent, key, "junctionRef", idPool, event)
        elseif key == "trainId" then
            assignIdRef(packedEvent, key, "trainRef", idPool, event)
        elseif key == "edgeId" then
            assignIdRef(packedEvent, key, "edgeRef", idPool, event)
        elseif key == "reason" then
            assignIdRef(packedEvent, key, "reasonRef", idPool, event)
        elseif key == "endReason" then
            assignIdRef(packedEvent, key, "endReasonRef", idPool, event)
        elseif key == "target" then
            assignIdRef(packedEvent, key, "targetRef", idPool, event)
        else
            packedEvent[key] = deepCopy(value)
        end
    end

    return packedEvent
end

local function packTimelineEvents(events, idPool)
    local packedEvents = {}

    for index, event in ipairs(events or {}) do
        packedEvents[index] = packTimelineEvent(event, idPool)
    end

    return packedEvents
end

local function ensureReplayDirectory()
    local cacheDirectory = storagePaths.ensureCacheDirectory()
    local replayDirectory = cacheDirectory .. "/" .. REPLAY_DIRECTORY_NAME

    if love and love.filesystem and not love.filesystem.getInfo(replayDirectory, "directory") then
        love.filesystem.createDirectory(replayDirectory)
    end

    return replayDirectory
end

local function writeReplayFile(path, payload)
    local encodedPayload = toml.stringify(payload)

    if love and love.filesystem and love.filesystem.write then
        return love.filesystem.write(path, encodedPayload)
    end

    local handle = io.open(path, "wb")
    if not handle then
        return nil, "Unable to write replay file."
    end

    local ok, writeError = handle:write(encodedPayload)
    handle:close()
    if ok == nil then
        return nil, writeError
    end

    return true
end

function replayStorage.toSerializableRecord(replayRecord)
    if isPackedReplayRecord(replayRecord) then
        return deepCopy(replayRecord)
    end

    local payload = deepCopy(replayRecord or {})
    local idPool = createIdPool()

    payload.cursorSamples = packCursorSamples(payload.cursorSamples)
    payload.initialJunctions = packInitialJunctionStates(payload.initialJunctions, idPool)
    payload.interactions = packInteractions(payload.interactions, idPool)
    payload.preparationInteractions = packInteractions(payload.preparationInteractions, idPool)
    payload.timelineEvents = packTimelineEvents(payload.timelineEvents, idPool)
    if #idPool.values > 0 then
        payload.idPool = idPool.values
    else
        payload.idPool = nil
    end
    return payload
end

function replayStorage.toJsonPayload(replayRecord)
    local payload = replayStorage.toSerializableRecord(replayRecord)
    payload.localFilePath = nil
    return payload
end

function replayStorage.toJsonString(replayRecord)
    return json.encode(replayStorage.toJsonPayload(replayRecord))
end

function replayStorage.save(replayRecord)
    local payload = replayStorage.toSerializableRecord(replayRecord)
    payload.replayId = payload.replayId or uuid.generateV4()

    local replayDirectory = ensureReplayDirectory()
    local fileName = payload.replayId .. REPLAY_FILE_EXTENSION
    local path = replayDirectory .. "/" .. fileName
    local ok, writeError = writeReplayFile(path, payload)
    if not ok then
        return nil, writeError
    end

    payload.localFilePath = path
    return payload
end

function replayStorage.load(replayFilePath)
    local resolvedPath = tostring(replayFilePath or "")
    if resolvedPath == "" then
        return nil, REPLAY_FILE_MISSING_ERROR
    end

    local payload, loadError = toml.parseFile(resolvedPath)
    if type(payload) ~= "table" then
        return nil, loadError or "Unable to load replay file."
    end

    payload.localFilePath = resolvedPath
    return payload
end

function replayStorage.delete(replayFilePath)
    local resolvedPath = tostring(replayFilePath or "")
    if resolvedPath == "" then
        return false, REPLAY_FILE_MISSING_ERROR
    end

    if love and love.filesystem and love.filesystem.remove then
        local ok, removeError = love.filesystem.remove(resolvedPath)
        if ok then
            return true
        end
        return nil, removeError or "Unable to remove replay file."
    end

    local ok, removeError = os.remove(resolvedPath)
    if ok then
        return true
    end

    return nil, removeError or "Unable to remove replay file."
end

return replayStorage
