local toml = require("src.game.util.toml")
local storagePaths = require("src.game.storage.storage_paths")

local leaderboardPreviewCache = {}

local CACHE_FILE = storagePaths.getCacheFilePath("online_leaderboard_cache.toml")

local function sanitizePreviewEntry(mapUuid, entry)
    if type(entry) ~= "table" then
        return nil
    end

    local resolvedMapUuid = tostring(entry.map_uuid or mapUuid or "")
    local resolvedMapHash = tostring(entry.map_hash or "")
    if resolvedMapUuid == "" then
        return nil
    end

    return {
        map_uuid = resolvedMapUuid,
        map_hash = resolvedMapHash,
        top_entries = type(entry.top_entries) == "table" and entry.top_entries or {},
        player_entry = type(entry.player_entry) == "table" and entry.player_entry or nil,
        target_rank = tonumber(entry.target_rank) or nil,
        fetched_at = tonumber(entry.fetched_at) or 0,
    }
end

local function sanitizeCache(cache)
    local sanitized = {}

    if type(cache) ~= "table" then
        return sanitized
    end

    for mapUuid, entry in pairs(cache) do
        local sanitizedEntry = sanitizePreviewEntry(mapUuid, entry)
        if sanitizedEntry then
            sanitized[sanitizedEntry.map_uuid] = sanitizedEntry
        end
    end

    return sanitized
end

local function readCacheFile()
    if not love.filesystem.getInfo(CACHE_FILE, "file") then
        return {}
    end

    local decoded = toml.parseFile(CACHE_FILE)
    if type(decoded) ~= "table" then
        return {}
    end

    return sanitizeCache(decoded)
end

function leaderboardPreviewCache.load()
    return readCacheFile()
end

function leaderboardPreviewCache.save(cache)
    storagePaths.ensureCacheDirectory()
    local encodedCache = toml.stringify(sanitizeCache(cache))
    return love.filesystem.write(CACHE_FILE, encodedCache)
end

return leaderboardPreviewCache
