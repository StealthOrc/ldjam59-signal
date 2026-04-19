package.path = "./?.lua;./?/init.lua;" .. package.path

local refreshIndicatorLogic = require("src.game.refresh_indicator_logic")

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

print("refresh indicator logic tests passed")
