package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}

local ui = require("src.game.ui")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %q but got %q", label, expected, actual), 2)
    end
end

assert(type(ui.formatLeaderboardScore) == "function", "ui.formatLeaderboardScore should exist")
assertEqual(ui.formatLeaderboardScore(70.3), "70.300", "leaderboard score keeps trailing zeroes")
assertEqual(ui.formatLeaderboardScore(70.013), "70.013", "leaderboard score keeps thousandths")
assertEqual(ui.formatLeaderboardScore(70), "70.000", "leaderboard score shows three decimals for integers")

assert(type(ui.formatLevelSelectLeaderboardPlayerName) == "function", "ui.formatLevelSelectLeaderboardPlayerName should exist")
assertEqual(
    ui.formatLevelSelectLeaderboardPlayerName("ABCDEFGHIJKLMN"),
    "ABCDEFGHIJKLMN",
    "level select leaderboard keeps fourteen character names"
)
assertEqual(
    ui.formatLevelSelectLeaderboardPlayerName("ABCDEFGHIJKLMNO"),
    "ABCDEFGHIJKLMN",
    "level select leaderboard truncates names above fourteen characters"
)

assert(type(ui.formatLeaderboardRefreshLabel) == "function", "ui.formatLeaderboardRefreshLabel should exist")
assertEqual(
    ui.formatLeaderboardRefreshLabel(nil, 100),
    "Refresh in 0s",
    "leaderboard refresh label falls back to zero seconds without a cooldown"
)
assertEqual(
    ui.formatLeaderboardRefreshLabel(109, 100, true, 0),
    "Refreshing.",
    "leaderboard refresh label starts animated loading state with one dot"
)
assertEqual(
    ui.formatLeaderboardRefreshLabel(109, 100, true, 0.4),
    "Refreshing..",
    "leaderboard refresh label advances animated loading state to two dots"
)
assertEqual(
    ui.formatLeaderboardRefreshLabel(109, 100, true, 0.8),
    "Refreshing...",
    "leaderboard refresh label advances animated loading state to three dots"
)
assertEqual(
    ui.formatLeaderboardRefreshLabel(142, 100),
    "Refresh in 42s",
    "leaderboard refresh label shows seconds remaining"
)
assertEqual(
    ui.formatLeaderboardRefreshLabel(100, 100),
    "Refresh in 0s",
    "leaderboard refresh label clamps to zero when cooldown expires"
)

assert(type(ui.formatLevelSelectLeaderboardRefreshLabel) == "function", "ui.formatLevelSelectLeaderboardRefreshLabel should exist")
assertEqual(
    ui.formatLevelSelectLeaderboardRefreshLabel(170, 100),
    "Refresh in 70s",
    "level select leaderboard refresh label shows seconds remaining"
)
assertEqual(
    ui.formatLevelSelectLeaderboardRefreshLabel(109, 100, true, 0.8),
    "Refreshing...",
    "level select leaderboard refresh label shows animated loading state while a fetch is active"
)
assertEqual(
    ui.formatLevelSelectLeaderboardRefreshLabel(nil, 100),
    "Refresh in 0s",
    "level select leaderboard refresh label clamps to zero without a cooldown"
)

assert(type(ui.getLevelSelectLeaderboardVisibleEntries) == "function", "ui.getLevelSelectLeaderboardVisibleEntries should exist")

local visibleTopEntriesOnly, visiblePinnedEntryOnly = ui.getLevelSelectLeaderboardVisibleEntries(
    { { rank = 1 }, { rank = 2 }, { rank = 3 }, { rank = 4 }, { rank = 5 }, { rank = 6 } },
    nil,
    5
)
assertEqual(#visibleTopEntriesOnly, 5, "level select leaderboard shows at most five top rows without a pinned player")
assertEqual(visiblePinnedEntryOnly, nil, "level select leaderboard keeps pinned player empty when none exists")

local pinnedPlayerEntry = { rank = 12 }
local visibleTopEntriesWithPinned, visiblePinnedEntryWithPinned = ui.getLevelSelectLeaderboardVisibleEntries(
    { { rank = 1 }, { rank = 2 }, { rank = 3 }, { rank = 4 }, { rank = 5 } },
    pinnedPlayerEntry,
    5
)
assertEqual(#visibleTopEntriesWithPinned, 4, "level select leaderboard reserves one slot for the pinned player")
assertEqual(visiblePinnedEntryWithPinned, pinnedPlayerEntry, "level select leaderboard keeps the pinned player visible")

assert(type(ui.getLevelSelectLeaderboardPinnedRowY) == "function", "ui.getLevelSelectLeaderboardPinnedRowY should exist")
assertEqual(
    ui.getLevelSelectLeaderboardPinnedRowY({ y = 100 }, 0),
    156,
    "level select leaderboard places a pinned row in the first slot when no top rows exist"
)
assertEqual(
    ui.getLevelSelectLeaderboardPinnedRowY({ y = 100 }, 4),
    282,
    "level select leaderboard places a pinned row directly below the visible entries"
)

print("ui formatting tests passed")
