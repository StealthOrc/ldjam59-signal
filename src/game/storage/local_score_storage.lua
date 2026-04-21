local toml = require("src.game.util.toml")
local storagePaths = require("src.game.storage.storage_paths")

local localScoreStorage = {}

local SCOREBOARD_FILE = storagePaths.getCacheFilePath("offline_leaderboard_cache.toml")
local STORAGE_VERSION = 3

local function sanitizeEntry(mapUuid, entry)
    if type(entry) ~= "table" then
        return nil
    end

    local resolvedMapUuid = tostring(entry.map_uuid or mapUuid or "")
    if resolvedMapUuid == "" then
        return nil
    end

    return {
        map_uuid = resolvedMapUuid,
        score = tonumber(entry.score or 0) or 0,
        recorded_at = tonumber(entry.recorded_at or 0) or 0,
    }
end

local function sanitizeStore(store)
    local sanitized = {
        version = STORAGE_VERSION,
        entries_by_map = {},
    }
    local sourceEntries = type(store) == "table" and store.entries_by_map or nil

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

    local decoded = toml.parseFile(SCOREBOARD_FILE)
    if type(decoded) ~= "table" then
        return nil
    end

    return decoded
end

function localScoreStorage.save(store)
    storagePaths.ensureCacheDirectory()
    local sanitized = sanitizeStore(store)
    local encodedStore = toml.stringify(sanitized)
    local ok, writeError = love.filesystem.write(SCOREBOARD_FILE, encodedStore)
    if not ok then
        return nil, writeError or "The local scoreboard could not be saved."
    end

    return sanitized
end

function localScoreStorage.load()
    local loadedStore = readStoreFile()
    local sanitized = sanitizeStore(loadedStore)

    if loadedStore == nil then
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
    local recordedAt = tonumber(summary and summary.recorded_at)
    if not recordedAt or recordedAt <= 0 then
        recordedAt = os.time() or 0
    end
    local existingEntry = sanitized.entries_by_map[mapUuid]

    if existingEntry and score <= (tonumber(existingEntry.score) or 0) then
        return sanitized, false
    end

    sanitized.entries_by_map[mapUuid] = {
        map_uuid = mapUuid,
        score = score,
        recorded_at = recordedAt,
    }
    return sanitized, true
end

return localScoreStorage
