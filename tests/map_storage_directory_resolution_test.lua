package.path = "./?.lua;./?/init.lua;" .. package.path

local toml = require("src.game.util.toml")

package.loaded["src.game.data.authored_map"] = {
    buildPlayableLevel = function()
        return nil, nil, {}
    end,
}

package.loaded["src.game.util.uuid"] = {
    generateV4 = function()
        return "generated-map-uuid"
    end,
}

local files = {
    ["maps/user/shared.toml"] = toml.stringify({
        name = "User Copy",
        mapUuid = "user-map",
        version = 1,
    }),
    ["maps/downloaded/shared.toml"] = toml.stringify({
        name = "Downloaded Copy",
        mapUuid = "downloaded-map",
        version = 1,
        remoteSource = {
            source = "marketplace",
        },
    }),
}

love = love or {}
love.filesystem = love.filesystem or {}

love.filesystem.getInfo = function(path, infoType)
    if infoType == "directory" then
        if path == "maps" or path == "maps/user" or path == "maps/downloaded" then
            return { type = "directory" }
        end
        return false
    end

    if files[path] ~= nil then
        return { type = "file" }
    end

    return false
end

love.filesystem.getDirectoryItems = function(path)
    if path == "maps/user" or path == "maps/downloaded" then
        return { "shared.toml" }
    end
    return {}
end

love.filesystem.read = function(path)
    return files[path]
end

love.filesystem.write = function(path, content)
    files[path] = content
    return true
end

love.filesystem.createDirectory = function()
    return true
end

local mapStorage = require("src.game.storage.map_storage")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %s but got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local maps = mapStorage.listMaps()
local userDescriptor
local downloadedDescriptor

for _, descriptor in ipairs(maps) do
    if descriptor.mapUuid == "user-map" then
        userDescriptor = descriptor
    elseif descriptor.mapUuid == "downloaded-map" then
        downloadedDescriptor = descriptor
    end
end

assertEqual(type(userDescriptor), "table", "user map descriptor exists")
assertEqual(type(downloadedDescriptor), "table", "downloaded map descriptor exists")
assertEqual(userDescriptor.storageDirectory, "maps/user", "user map keeps its own storage directory")
assertEqual(downloadedDescriptor.storageDirectory, "maps/downloaded", "downloaded map keeps its own storage directory")
assertEqual(userDescriptor.id, "user:shared.toml", "user map id stays in the user namespace")
assertEqual(downloadedDescriptor.id, "downloaded:shared.toml", "downloaded map id uses the downloaded namespace")

local loadedUserMap = mapStorage.loadMap(userDescriptor)
local loadedDownloadedMap = mapStorage.loadMap(downloadedDescriptor)

assertEqual(loadedUserMap.mapUuid, "user-map", "user descriptor loads the user file")
assertEqual(loadedDownloadedMap.mapUuid, "downloaded-map", "downloaded descriptor loads the downloaded file")

print("map storage directory resolution tests passed")
