package.path = "./?.lua;./?/init.lua;" .. package.path

local installScreenFlow = require("src.game.app.game_screen_flow")
local mapReplayIndexStorage = require("src.game.storage.map_replay_index_storage")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %q but got %q", label, expected, actual), 2)
    end
end

local function assertTrue(value, label)
    if not value then
        error(label, 2)
    end
end

local loadedReplayPath = nil
local openReplayCalled = false

local Game = {}

installScreenFlow(Game, {
    mapReplayIndexStorage = mapReplayIndexStorage,
    replayStorage = {
        load = function(replayFilePath)
            loadedReplayPath = replayFilePath
            return {
                mapUuid = "map-1",
                mapHash = "hash-1",
            }
        end,
    },
    mapStorage = {
        loadMap = function()
            return {
                level = {
                    id = "level-1",
                },
            }
        end,
    },
    deepCopy = function(value)
        return value
    end,
    LEVEL_SELECT_ACTION_STATUS_ERROR = "error",
    LEVEL_SELECT_ACTION_STATUS_INFO = "info",
})

local game = setmetatable({
    localReplayIndex = {
        replays = {
            {
                replayUuid = "replay-1",
                mapUuid = "map-1",
                mapHash = "hash-1",
                replayFilePath = "cache/replay-1.json",
                score = 10,
                recordedAt = 100,
            },
        },
    },
    setLevelSelectActionState = function(self, status, message)
        self.lastLevelSelectAction = {
            status = status,
            message = message,
        }
    end,
    closeLevelSelectReplayOverlay = function()
    end,
    openReplay = function()
        openReplayCalled = true
        return true
    end,
}, { __index = Game })

local opened = game:openLevelSelectReplayEntry({
    mapUuid = "map-1",
    mapHash = "hash-1",
    displayName = "Map One",
}, {
    replayUuid = "replay-1",
})

assertTrue(opened, "opening a replay entry should succeed")
assertEqual(loadedReplayPath, "cache/replay-1.json", "replay entry lookup resolves the local replay file")
assertEqual(game.replayRecord.mapUuid, "map-1", "opening the replay stores the loaded replay record")
assertEqual(game.replayLevelSource.id, "level-1", "opening the replay stores the replay level source")
assertTrue(openReplayCalled, "opening a replay entry delegates to the replay screen")

print("level select replay entry tests passed")
