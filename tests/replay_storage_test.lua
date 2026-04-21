package.path = "./?.lua;./?/init.lua;" .. package.path

local writtenFiles = {}
local directories = {}

love = {
    filesystem = {
        getInfo = function(path, expectedType)
            if directories[path] and expectedType == "directory" then
                return { type = "directory" }
            end
            if writtenFiles[path] and (expectedType == nil or expectedType == "file") then
                return { type = "file" }
            end
            return nil
        end,
        createDirectory = function(path)
            directories[path] = true
            return true
        end,
        write = function(path, content)
            writtenFiles[path] = content
            return true
        end,
        read = function(path)
            return writtenFiles[path]
        end,
    },
}

local json = require("src.game.util.json")
local toml = require("src.game.util.toml")
local replayStorage = require("src.game.storage.replay_storage")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %s but got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local function assertTrue(value, label)
    if not value then
        error(label, 2)
    end
end

local savedReplay = replayStorage.save({
    mapUuid = "map-1",
    mapHash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    mapUpdatedAt = "2026-04-21T11:45:00Z",
    duration = 12.5,
    cursorSamples = {
        t = { 0, 1.25 },
        x = { 10, 320 },
        y = { 20, 240 },
    },
    initialJunctions = {
        {
            id = "junction-a",
            activeInputIndex = 2,
            activeOutputIndex = 1,
        },
    },
    interactions = {
        {
            time = 1.25,
            junctionId = "junction-a",
            target = "junction",
            button = 1,
            x = 320,
            y = 240,
        },
    },
    timelineEvents = {
        {
            time = 12.5,
            kind = "run_end",
            endReason = "level_clear",
        },
    },
})

assertTrue(savedReplay ~= nil, "replay storage saves a replay payload")
assertTrue(savedReplay.localFilePath:find("cache/replays/", 1, true) ~= nil, "replay storage writes into the cache replay directory")

local savedToml = writtenFiles[savedReplay.localFilePath]
local parsedReplay, parseError = toml.parse(savedToml)
assertEqual(parseError, nil, "saved replay TOML parses cleanly")
assertEqual(parsedReplay.mapUuid, "map-1", "saved replay TOML keeps the map uuid")
assertEqual(parsedReplay.mapHash, "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef", "saved replay TOML keeps the map hash")
assertEqual(parsedReplay.mapUpdatedAt, "2026-04-21T11:45:00Z", "saved replay TOML keeps the map update timestamp")
assertEqual(parsedReplay.idPool[1], "junction-a", "saved replay TOML keeps the shared id pool")
assertEqual(parsedReplay.cursorSamples.t[2], 1.25, "saved replay TOML keeps compact cursor sample times")
assertEqual(parsedReplay.cursorSamples.x[2], 320, "saved replay TOML keeps compact cursor sample x positions")
assertEqual(parsedReplay.cursorSamples.y[2], 240, "saved replay TOML keeps compact cursor sample y positions")
assertEqual(parsedReplay.interactions[1].junctionRef, 1, "saved replay TOML stores recorded interaction junction ids as shared refs")
assertEqual(parsedReplay.interactions[1].txy[1], 1.25, "saved replay TOML keeps compact interaction times")
assertEqual(parsedReplay.interactions[1].txy[2], 320, "saved replay TOML keeps compact interaction x positions")
assertEqual(parsedReplay.interactions[1].txy[3], 240, "saved replay TOML keeps compact interaction y positions")

local jsonPayload = replayStorage.toJsonPayload(savedReplay)
assertEqual(jsonPayload.localFilePath, nil, "json replay payload omits the local file path")
assertEqual(jsonPayload.mapHash, "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef", "json replay payload keeps the map hash")
assertEqual(jsonPayload.interactions[1].junctionRef, 1, "json replay payload keeps shared id refs")

local decodedJson, jsonError = json.decode(replayStorage.toJsonString(savedReplay))
assertEqual(jsonError, nil, "saved replay JSON decodes cleanly")
assertEqual(decodedJson.mapHash, "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef", "saved replay JSON keeps the map hash")
assertEqual(decodedJson.mapUpdatedAt, "2026-04-21T11:45:00Z", "saved replay JSON keeps the map update timestamp")
assertEqual(decodedJson.timelineEvents[1].endReasonRef, 4, "saved replay JSON keeps pooled timeline ids")
assertEqual(decodedJson.interactions[1].txy[2], 320, "saved replay JSON keeps compact interaction tuples")

local loadedReplay, loadError = replayStorage.load(savedReplay.localFilePath)
assertEqual(loadError, nil, "saved replay loads again from storage")
assertEqual(loadedReplay.mapUuid, savedReplay.mapUuid, "loaded replay keeps the map uuid")
assertEqual(loadedReplay.localFilePath, savedReplay.localFilePath, "loaded replay exposes its local file path")

print("replay storage tests passed")
