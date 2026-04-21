package.path = "./?.lua;./?/init.lua;" .. package.path

local mapReplayIndexStorage = require("src.game.storage.map_replay_index_storage")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %s but got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local replayStore = {
    replays = {
        {
            replayUuid = "other-replay-1",
            mapUuid = "map-1",
            mapHash = "hash-2",
            score = 77,
            recordedAt = 1,
            replayFilePath = "cache/replays/other-replay-1.toml",
        },
    },
}

local highestScore = 100
local lowestKeptScore = 96
local expectedLowestRetainedScoreAfterHigherReplay = 97
for index = 1, 5 do
    replayStore.replays[#replayStore.replays + 1] = {
        replayUuid = "replay-" .. index,
        mapUuid = "map-1",
        mapHash = "hash-1",
        score = highestScore - (index - 1),
        recordedAt = index,
        replayFilePath = "cache/replays/replay-" .. index .. ".toml",
    }
end

local updatedStore, updateOutcome = mapReplayIndexStorage.updateReplayIndex(replayStore, {
    replayId = "replay-11",
    mapUuid = "map-1",
    mapHash = "hash-1",
    localFilePath = "cache/replays/replay-11.toml",
    duration = 12.5,
}, {
    finalScore = 98,
    recorded_at = 11,
})

assertEqual(type(updatedStore), "table", "higher-score replay updates the replay store")
assertEqual(updateOutcome.keptReplay, true, "higher-score replay stays in the kept top 5")
assertEqual(#updateOutcome.prunedEntries, 1, "higher-score replay prunes exactly one stored replay")
assertEqual(updateOutcome.prunedEntries[1].score, lowestKeptScore, "higher-score replay prunes the worst kept replay")

local worseStore, worseOutcome = mapReplayIndexStorage.updateReplayIndex(updatedStore, {
    replayId = "replay-12",
    mapUuid = "map-1",
    mapHash = "hash-1",
    localFilePath = "cache/replays/replay-12.toml",
    duration = 14,
}, {
    finalScore = 1,
    recorded_at = 12,
})

assertEqual(type(worseStore), "table", "lower-score replay still returns an updated store")
assertEqual(worseOutcome.keptReplay, false, "lower-score replay is not kept in the top 5")
assertEqual(#worseOutcome.prunedEntries, 1, "lower-score replay is immediately pruned")
assertEqual(worseOutcome.prunedEntries[1].replayUuid, "replay-12", "lower-score replay prunes itself")

local matchingEntries = mapReplayIndexStorage.listReplaysForMapRevision(worseStore, "map-1", "hash-1")
assertEqual(#matchingEntries, 5, "replay revision query returns only kept entries")
assertEqual(matchingEntries[1].score, highestScore, "replay revision query keeps entries sorted from best to worst")
assertEqual(
    matchingEntries[#matchingEntries].score,
    expectedLowestRetainedScoreAfterHigherReplay,
    "replay revision query excludes the pruned worst score"
)

local missingEntries = mapReplayIndexStorage.listReplaysForMapRevision(worseStore, "map-1", "different-hash")
assertEqual(#missingEntries, 0, "replay revision query filters by exact map hash")

local otherRevisionEntries = mapReplayIndexStorage.listReplaysForMapRevision(worseStore, "map-1", "hash-2")
assertEqual(#otherRevisionEntries, 1, "replay pruning only affects the matching map revision bucket")
assertEqual(otherRevisionEntries[1].replayUuid, "other-replay-1", "other map revision entries stay untouched")

print("map replay index storage tests passed")
