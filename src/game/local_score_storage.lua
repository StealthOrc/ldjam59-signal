local json = require("src.game.json")

local localScoreStorage = {}

local SCOREBOARD_FILE = "local_scoreboard.json"
local STORAGE_VERSION = 1

local function sanitizeEntry(mapUuid, entry)
    local resolvedMapUuid = tostring(mapUuid or entry and entry.map_uuid or "")
    if resolvedMapUuid == "" then
        return nil
    end

    return {
        map_uuid = resolvedMapUuid,
        score = tonumber(entry and entry.score or 0) or 0,
        updated_at = tonumber(entry and entry.updated_at or 0) or 0,
    }
end

local function sanitizeStore(store)
    local sanitized = {
        version = STORAGE_VERSION,
        entries_by_map = {},
    }
    local sourceEntries = type(store) == "table" and (store.entries_by_map or store.entriesByMap) or nil

    if type(sourceEntries) ~= "table" then
        return sanitized
    end

    for mapUuid, entry in pairs(sourceEntries) do
        local sanitizedEntry = sanitizeEntry(mapUuid, entry)
        if sanitizedEntry then
            sanitized.entries_by_map[sanitizedEntry.map_uuid] = sanitizedEntry
        end
    end

    return sanitized
end

local function readStoreFile()
    if not love.filesystem.getInfo(SCOREBOARD_FILE, "file") then
        return nil
    end

    local content = love.filesystem.read(SCOREBOARD_FILE)
    if not content then
        return nil
    end

    local decoded = json.decode(content)
    if type(decoded) ~= "table" then
        return nil
    end

    return decoded
end

function localScoreStorage.save(store)
    local sanitized = sanitizeStore(store)
    local encodedStore = json.encode(sanitized)
    local ok, writeError = love.filesystem.write(SCOREBOARD_FILE, encodedStore)
    if not ok then
        return nil, writeError or "The local scoreboard could not be saved."
    end

    return sanitized
end

function localScoreStorage.load()
    local loadedStore = readStoreFile()
    local sanitized = sanitizeStore(loadedStore)
    local needsSave = loadedStore == nil
        or loadedStore.version ~= sanitized.version
        or loadedStore.entries_by_map == nil
        or loadedStore.entriesByMap ~= nil

    if needsSave then
        local savedStore = localScoreStorage.save(sanitized)
        if savedStore then
            sanitized = savedStore
        end
    end

    return sanitized
end

function localScoreStorage.updateBestScore(store, summary)
    local sanitized = sanitizeStore(store)
    local mapUuid = tostring(summary and summary.mapUuid or "")
    if mapUuid == "" then
        return sanitized, false
    end

    local score = tonumber(summary and (summary.finalScore or summary.score) or 0) or 0
    local updatedAt = tonumber(summary and summary.updated_at or 0) or os.time() or 0
    local existingEntry = sanitized.entries_by_map[mapUuid]

    if existingEntry and score <= (tonumber(existingEntry.score) or 0) then
        return sanitized, false
    end

    sanitized.entries_by_map[mapUuid] = {
        map_uuid = mapUuid,
        score = score,
        updated_at = updatedAt,
    }
    return sanitized, true
end

return localScoreStorage
