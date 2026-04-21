local storagePaths = {}

local CACHE_DIRECTORY = "cache"
local TEMP_DIRECTORY = "temp"

local function ensureDirectory(path)
    if not love.filesystem.getInfo(path, "directory") then
        love.filesystem.createDirectory(path)
    end
end

function storagePaths.getCacheDirectory()
    return CACHE_DIRECTORY
end

function storagePaths.getTempDirectory()
    return TEMP_DIRECTORY
end

function storagePaths.ensureCacheDirectory()
    ensureDirectory(CACHE_DIRECTORY)
    return CACHE_DIRECTORY
end

function storagePaths.ensureTempDirectory()
    ensureDirectory(TEMP_DIRECTORY)
    return TEMP_DIRECTORY
end

function storagePaths.getCacheFilePath(fileName)
    return CACHE_DIRECTORY .. "/" .. tostring(fileName or "")
end

function storagePaths.getTempFilePath(fileName)
    return TEMP_DIRECTORY .. "/" .. tostring(fileName or "")
end

return storagePaths
