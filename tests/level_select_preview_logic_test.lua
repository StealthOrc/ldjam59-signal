package.path = "./?.lua;./?/init.lua;" .. package.path

local previewLogic = require("src.game.level_select_preview_logic")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %s but got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local freshCacheOpenState = previewLogic.buildOpenStateOptions(true)
assertEqual(
    freshCacheOpenState.status,
    "ready",
    "opening level select leaderboard with fresh cache stays on the cached data"
)
assertEqual(
    freshCacheOpenState.forceImmediateFetch,
    false,
    "opening level select leaderboard with fresh cache does not force an immediate remote fetch"
)

local staleCacheOpenState = previewLogic.buildOpenStateOptions(false)
assertEqual(
    staleCacheOpenState.status,
    "loading",
    "opening level select leaderboard without fresh cache starts a remote first load"
)
assertEqual(
    staleCacheOpenState.forceImmediateFetch,
    true,
    "opening level select leaderboard without fresh cache forces an immediate remote fetch"
)

assertEqual(
    previewLogic.shouldStartFetch(
        { mapUuid = "map-1", forceImmediateFetch = true },
        "map-1",
        false,
        true,
        false
    ),
    true,
    "forced remote fetch still starts immediately when the state requests it"
)

assertEqual(
    previewLogic.shouldShowCachedEntries(
        { mapUuid = "map-1", status = "loading", showCachedWhileLoading = false },
        "map-1",
        true
    ),
    false,
    "initial remote first load hides cached leaderboard entries"
)

assertEqual(
    previewLogic.shouldShowCachedEntries(
        { mapUuid = "map-1", status = "loading", showCachedWhileLoading = true },
        "map-1",
        true
    ),
    true,
    "background refresh keeps cached leaderboard entries visible"
)

assertEqual(
    previewLogic.shouldShowCachedEntries(
        { mapUuid = "map-1", status = "loading", showCachedWhileLoading = false, clearVisibleEntries = true },
        "map-1",
        true
    ),
    false,
    "remote swap clears cached leaderboard entries before new data is shown"
)

local preservedPayload = previewLogic.getPayloadToPersistAfterFetch(
    {
        top_entries = {},
        player_entry = nil,
        target_rank = nil,
    },
    {
        top_entries = {
            { rank = 1, player_uuid = "player-1" },
        },
        player_entry = { rank = 4, player_uuid = "player-self" },
        target_rank = 4,
    }
)
assertEqual(#(preservedPayload.top_entries or {}), 1, "empty responses keep cached top entries for persistence")
assertEqual(preservedPayload.player_entry.rank, 4, "empty responses keep the cached player entry for persistence")
assertEqual(preservedPayload.target_rank, 4, "empty responses keep the cached target rank for persistence")

local emptyPayload = previewLogic.getPayloadToPersistAfterFetch(
    {
        top_entries = {},
        player_entry = nil,
        target_rank = nil,
    },
    nil
)
assertEqual(#(emptyPayload.top_entries or {}), 0, "empty responses without cache stay empty")

local remotePayload = previewLogic.getPayloadToPersistAfterFetch(
    {
        top_entries = {
            { rank = 1, player_uuid = "player-2" },
        },
        player_entry = nil,
        target_rank = 1,
    },
    {
        top_entries = {
            { rank = 1, player_uuid = "player-1" },
        },
        player_entry = { rank = 4, player_uuid = "player-self" },
        target_rank = 4,
    }
)
assertEqual(remotePayload.top_entries[1].player_uuid, "player-2", "non-empty remote responses replace cached top entries")
assertEqual(remotePayload.target_rank, 1, "non-empty remote responses keep their own target rank")

print("level select preview logic tests passed")
