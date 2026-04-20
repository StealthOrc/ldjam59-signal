package.path = "./?.lua;./?/init.lua;" .. package.path

local localScoreStorage = require("src.game.local_score_storage")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %s but got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local scoreboard = {
    entries_by_map = {
        ["map-1"] = {
            map_uuid = "map-1",
            score = 42,
            recorded_at = 10,
        },
    },
}

local unchangedScoreboard, keptExistingBest = localScoreStorage.updateBestScore(scoreboard, {
    mapUuid = "map-1",
    finalScore = 41,
    recorded_at = 12,
})
assertEqual(keptExistingBest, false, "lower scores do not replace the local best")
assertEqual(
    unchangedScoreboard.entries_by_map["map-1"].score,
    42,
    "lower scores leave the stored local best untouched"
)

local improvedScoreboard, storedNewBest = localScoreStorage.updateBestScore(scoreboard, {
    mapUuid = "map-1",
    finalScore = 48,
    recorded_at = 14,
})
assertEqual(storedNewBest, true, "higher scores replace the local best")
assertEqual(
    improvedScoreboard.entries_by_map["map-1"].score,
    48,
    "higher scores overwrite the stored local best"
)
assertEqual(
    improvedScoreboard.entries_by_map["map-1"].recorded_at,
    14,
    "higher scores keep the record creation timestamp"
)

local originalOsTime = os.time
os.time = function()
    return 123456789
end

local fallbackTimestampScoreboard, storedFallbackTimestamp = localScoreStorage.updateBestScore({
    entries_by_map = {},
}, {
    mapUuid = "map-2",
    finalScore = 7,
})

os.time = originalOsTime

assertEqual(storedFallbackTimestamp, true, "new local bests still save when the run summary has no timestamp")
assertEqual(
    fallbackTimestampScoreboard.entries_by_map["map-2"].recorded_at,
    123456789,
    "missing local best timestamps fall back to the current save time"
)

print("local score storage tests passed")
