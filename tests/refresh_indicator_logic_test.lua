package.path = "./?.lua;./?/init.lua;" .. package.path

local refreshIndicatorLogic = require("src.game.ui.refresh_indicator_logic")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %s but got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

assertEqual(
    refreshIndicatorLogic.getDisplayNextRefreshAt(100, 180, 60),
    160,
    "display refresh time stays tied to the visible data timestamp"
)

assertEqual(
    refreshIndicatorLogic.getDisplayNextRefreshAt(nil, 180, 60),
    180,
    "display refresh time falls back to the scheduled retry when no visible data timestamp exists"
)

assertEqual(
    refreshIndicatorLogic.getDisplayNextRefreshAtForVisibleData(false, 100, 180, 60),
    180,
    "empty visible previews use the scheduled retry instead of an expired cache timestamp"
)

assertEqual(
    refreshIndicatorLogic.getDisplayNextRefreshAtForVisibleData(false, 100, nil, 60),
    160,
    "empty visible previews still use the cache expiry when no separate retry has been scheduled"
)

assertEqual(
    refreshIndicatorLogic.getDisplayNextRefreshAtForVisibleData(true, 100, 180, 60),
    160,
    "visible leaderboard data still uses the timestamp of the shown cache entry"
)

print("refresh indicator logic tests passed")
