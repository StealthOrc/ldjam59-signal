package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}
love.graphics = love.graphics or {}
love.filesystem = love.filesystem or {}

love.filesystem.getInfo = function()
    return false
end

local replayRecorder = require("src.game.replay.replay_recorder")
local replayRuntime = require("src.game.replay.replay_runtime")
local replayStorage = require("src.game.storage.replay_storage")
local world = require("src.game.gameplay.railway_world")

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

local sourceWorld = world.new(1200, 800, {
    junctions = {
        {
            id = "main",
            label = "Main Junction",
            control = { type = "direct" },
            activeInputIndex = 1,
            activeOutputIndex = 1,
            inputs = {
                {
                    id = "main_input_a",
                    color = { 0.33, 0.8, 0.98 },
                    colors = { "blue" },
                    inputPoints = {
                        { x = 0.15, y = 0.15 },
                        { x = 0.38, y = 0.34 },
                        { x = 0.5, y = 0.5 },
                    },
                },
                {
                    id = "main_input_b",
                    color = { 0.98, 0.7, 0.28 },
                    colors = { "orange" },
                    inputPoints = {
                        { x = 0.85, y = 0.15 },
                        { x = 0.62, y = 0.34 },
                        { x = 0.5, y = 0.5 },
                    },
                },
            },
            outputs = {
                {
                    id = "main_output",
                    color = { 0.4, 0.92, 0.76 },
                    colors = { "blue", "orange" },
                    outputPoints = {
                        { x = 0.5, y = 0.5 },
                        { x = 0.5, y = 0.85 },
                    },
                },
            },
        },
    },
    trains = {},
})

local junction = sourceWorld.junctions.main
local recorder = replayRecorder.new({
    mapUuid = "map-a",
    mapTitle = "Replay Test",
    mapHash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    mapUpdatedAt = "2026-04-21T10:00:00Z",
    initialJunctions = sourceWorld:getReplayJunctionStates(),
    initialCursor = {
        x = 100,
        y = 120,
    },
})

recorder:recordInteraction({
    time = 0.25,
    junctionId = junction.id,
    target = "junction",
    button = 1,
    x = junction.mergePoint.x,
    y = junction.mergePoint.y,
})
recorder:setDuration(1)

local replayRecord = recorder:buildRecord()
local serializedReplayRecord = replayStorage.toSerializableRecord(replayRecord)
assertEqual(replayRecord.mapHash, "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef", "replay recorder stores the map hash")
assertEqual(replayRecord.mapUpdatedAt, "2026-04-21T10:00:00Z", "replay recorder stores the map update timestamp")
assertEqual(replayRecord.cursorSamples.t[1], 0, "replay recorder stores compact cursor sample times")
assertEqual(replayRecord.cursorSamples.x[2], junction.mergePoint.x, "replay recorder stores compact cursor sample x positions")
assertEqual(replayRecord.cursorSamples.y[2], junction.mergePoint.y, "replay recorder stores compact cursor sample y positions")
assertEqual(replayRecord.interactions[1].txy[1], 0.25, "replay recorder stores compact interaction times")
assertEqual(replayRecord.interactions[1].txy[2], junction.mergePoint.x, "replay recorder stores compact interaction x positions")
assertEqual(replayRecord.interactions[1].txy[3], junction.mergePoint.y, "replay recorder stores compact interaction y positions")
assertEqual(serializedReplayRecord.interactions[1].junctionRef, 1, "replay storage converts repeated ids into shared refs")

local runtime = replayRuntime.new(sourceWorld:getLevel(), serializedReplayRecord, 1200, 800)
assertEqual(runtime.playbackWorld.junctions.main.activeInputIndex, 1, "replay starts from the prepared junction state")

runtime:seek(0.3)
assertEqual(runtime.playbackWorld.junctions.main.activeInputIndex, 2, "replay applies recorded junction interactions")

runtime:seek(0.1)
assertEqual(runtime.playbackWorld.junctions.main.activeInputIndex, 1, "replay can seek backward by rebuilding state")

local interpolatedCursor = runtime:getCursorAtTime(0.125)
assertTrue(interpolatedCursor ~= nil, "replay exposes interpolated cursor positions")
assertTrue(interpolatedCursor.x > 100, "replay interpolates cursor x between samples")
assertTrue(interpolatedCursor.y > 120, "replay interpolates cursor y between samples")

runtime:seek(0.3)
local recentInteraction = runtime:getRecentInteraction()
assertEqual(recentInteraction.junctionId, "main", "replay exposes the most recent click pulse")

print("replay runtime tests passed")
