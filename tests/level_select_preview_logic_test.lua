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

print("level select preview logic tests passed")
