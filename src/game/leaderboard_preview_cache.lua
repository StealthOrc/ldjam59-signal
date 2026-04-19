local json = require("src.game.json")

local leaderboardPreviewCache = {}

local CACHE_FILE = "leaderboard_preview_cache.json"

local function readCacheFile()
    if not love.filesystem.getInfo(CACHE_FILE, "file") then
        return {}
    end

    local content, readError = love.filesystem.read(CACHE_FILE)
    if not content then
        return {}
    end

    local decoded = json.decode(content)
    if type(decoded) ~= "table" then
        return {}
    end

    return decoded
end

function leaderboardPreviewCache.load()
    return readCacheFile()
end

function leaderboardPreviewCache.save(cache)
    local encodedCache = json.encode(cache or {})
    return love.filesystem.write(CACHE_FILE, encodedCache)
end

return leaderboardPreviewCache
