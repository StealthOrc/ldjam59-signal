package.path = "./?.lua;./?/init.lua;" .. package.path

local installRemoteServices = require("src.game.app.game_remote_services")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %q but got %q", label, expected, actual), 2)
    end
end

local Game = {}

installRemoteServices(Game, {
    LEADERBOARD_SCOPE_MAP = "map",
    LEADERBOARD_SCOPE_GLOBAL = "global",
    LEADERBOARD_REFRESH_LABEL_LOCAL_ONLY = "Local Only",
    LEVEL_SELECT_PREVIEW_MESSAGE_NO_LOCAL_BEST = "No local personal best yet.",
    LEVEL_SELECT_PREVIEW_TITLE_PERSONAL_BEST = "Personal Best",
    getProfilePlayerUuid = function(profile)
        return type(profile) == "table" and tostring(profile.player_uuid or "") or ""
    end,
    normalizeLeaderboardEntry = function(entry, fallbackMapUuid, fallbackRank)
        if type(entry) ~= "table" then
            return nil
        end

        return {
            playerDisplayName = entry.display_name or "Unknown",
            playerUuid = entry.player_uuid or "",
            score = tonumber(entry.score or 0) or 0,
            rank = tonumber(entry.rank) or fallbackRank or 0,
            mapUuid = entry.map_uuid or fallbackMapUuid,
            replayUuid = entry.replay_uuid or "",
            replayFilePath = entry.replay_file_path or "",
        }
    end,
})

local game = setmetatable({
    profile = {
        playerDisplayName = "Patrick",
        player_uuid = "player-self",
    },
    localScoreboard = {
        entries_by_map = {
            ["map-1"] = {
                map_uuid = "map-1",
                score = 11,
                recorded_at = 100,
            },
        },
    },
    localReplayIndex = {
        replays = {
            {
                replayUuid = "replay-1",
                mapUuid = "map-1",
                mapHash = "hash-1",
                replayFilePath = "cache/replay-1.json",
                score = 15,
                recordedAt = 90,
                duration = 7,
            },
        },
    },
    getMapNameByUuid = function(_, mapUuid)
        return mapUuid == "map-1" and "Map One" or "Unknown"
    end,
}, { __index = Game })

local replayPreview = game:getLocalLevelSelectPreviewDisplayState("map-1", "hash-1")
assertEqual(#replayPreview.topEntries, 1, "preview exposes one replay-backed entry")
assertEqual(replayPreview.topEntries[1].score, 15, "preview prefers the local replay score for the selected revision")
assertEqual(replayPreview.topEntries[1].replayUuid, "replay-1", "preview forwards the replay UUID")
assertEqual(replayPreview.topEntries[1].replayFilePath, "cache/replay-1.json", "preview forwards the replay file path")

local scoreOnlyPreview = game:getLocalLevelSelectPreviewDisplayState("map-1", "other-hash")
assertEqual(#scoreOnlyPreview.topEntries, 1, "preview falls back to the local score when no revision replay exists")
assertEqual(scoreOnlyPreview.topEntries[1].score, 11, "preview keeps the offline best score as the fallback")
assertEqual(scoreOnlyPreview.topEntries[1].replayUuid, "", "fallback score entry stays non replayable")

print("local level select preview replay tests passed")
