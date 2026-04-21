local json = require("src.game.util.json")
local toml = require("src.game.util.toml")
local uuid = require("src.game.util.uuid")
local storagePaths = require("src.game.storage.storage_paths")

local replayStorage = {}

local REPLAY_DIRECTORY_NAME = "replays"
local REPLAY_FILE_EXTENSION = ".toml"

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

local function packInteraction(interaction)
    local packedInteraction = {
        target = interaction and interaction.target or "junction",
        junctionId = interaction and interaction.junctionId or "",
        button = tonumber(interaction and interaction.button) or 1,
    }

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

local function packInteractions(interactions)
    local packedInteractions = {}

    for index, interaction in ipairs(interactions or {}) do
        packedInteractions[index] = packInteraction(interaction)
    end

    return packedInteractions
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
    local payload = deepCopy(replayRecord or {})
    payload.cursorSamples = packCursorSamples(payload.cursorSamples)
    payload.interactions = packInteractions(payload.interactions)
    payload.preparationInteractions = packInteractions(payload.preparationInteractions)
    return payload
end

function replayStorage.toJsonPayload(replayRecord)
    local payload = deepCopy(replayRecord or {})
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

return replayStorage
