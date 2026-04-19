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
            updated_at = 10,
        },
    },
}

local unchangedScoreboard, keptExistingBest = localScoreStorage.updateBestScore(scoreboard, {
    mapUuid = "map-1",
    finalScore = 41,
    updated_at = 12,
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
    updated_at = 14,
})
assertEqual(storedNewBest, true, "higher scores replace the local best")
assertEqual(
    improvedScoreboard.entries_by_map["map-1"].score,
    48,
    "higher scores overwrite the stored local best"
)
assertEqual(
    improvedScoreboard.entries_by_map["map-1"].updated_at,
    14,
    "higher scores keep the newest timestamp"
)

print("local score storage tests passed")
