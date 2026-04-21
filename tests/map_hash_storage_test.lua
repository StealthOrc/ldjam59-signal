package.path = "./?.lua;./?/init.lua;" .. package.path

local toml = require("src.game.util.toml")

local storedFiles = {}

package.loaded["src.game.map_compiler.map_compiler"] = {
    buildPlayableLevel = function()
        return nil, nil, {}
    end,
}

package.loaded["src.game.util.uuid"] = {
    generateV4 = function()
        return "generated-map-uuid"
    end,
}

love = love or {}
love.data = {
    hash = function(_, value)
        return "digest:" .. tostring(value or "")
    end,
    encode = function(_, _, value)
        return "encoded:" .. tostring(value or "")
    end,
}

love.filesystem = {
    createDirectory = function()
        return true
    end,
    getInfo = function(path, infoType)
        if infoType == "directory" then
            if path == "maps" or path == "maps/user" then
                return { type = "directory" }
            end
            return false
        end

        if storedFiles[path] ~= nil then
            return { type = "file" }
        end

        return false
    end,
    getDirectoryItems = function()
        return {}
    end,
    read = function(path)
        return storedFiles[path]
    end,
    write = function(path, content)
        storedFiles[path] = content
        return true
    end,
}

package.loaded["src.game.storage.map_storage"] = nil
local mapStorage = require("src.game.storage.map_storage")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %s but got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local savedDescriptor, saveError = mapStorage.saveMap("Hash Test", {
    mapUuid = "map-hash-uuid",
    name = "Hash Test",
    level = {
        title = "Hash Test",
        nodes = {},
    },
    mapHash = "should-not-persist",
})

if not savedDescriptor then
    error(saveError or "saveMap should succeed", 2)
end

local savedPayload = toml.parse(storedFiles["maps/user/hash_test.toml"])
assertEqual(savedPayload.mapHash, nil, "saveMap should not persist mapHash into the TOML payload")

local loadedMap = mapStorage.loadMap(savedDescriptor)
assertEqual(
    loadedMap.mapHash,
    "encoded:digest:{\"id\":\"map-hash-uuid\",\"mapUuid\":\"map-hash-uuid\",\"nodes\":[],\"title\":\"Hash Test\"}",
    "loadMap computes a stable hash from the playable level"
)

print("map hash storage tests passed")
