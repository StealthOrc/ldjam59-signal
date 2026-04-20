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

assert(type(ui.formatLeaderboardRecordedAt) == "function", "ui.formatLeaderboardRecordedAt should exist")
assertEqual(
    ui.formatLeaderboardRecordedAt(0),
    os.date("%Y-%m-%d %H:%M", 0),
    "leaderboard recorded timestamp formats unix seconds"
)

assert(type(ui.formatLeaderboardEntryTimestamp) == "function", "ui.formatLeaderboardEntryTimestamp should exist")
assertEqual(
    ui.formatLeaderboardEntryTimestamp("2026-04-20T13:45:59Z"),
    "2026-04-20 13:45",
    "leaderboard timestamp trims ISO timestamps to date and minute"
)
assertEqual(
    ui.formatLeaderboardEntryTimestamp(nil),
    "Unknown",
    "leaderboard timestamp falls back when no timestamp is available"
)

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

assert(type(ui.formatMarketplaceFavoriteLabel) == "function", "ui.formatMarketplaceFavoriteLabel should exist")
assertEqual(
    ui.formatMarketplaceFavoriteLabel(12),
    "12",
    "marketplace favorite label shows the current favorite count"
)
assertEqual(
    ui.formatMarketplaceFavoriteLabel(nil),
    "0",
    "marketplace favorite label falls back to zero without a count"
)

assert(type(ui.getPlayHoverInfoAt) == "function", "ui.getPlayHoverInfoAt should exist")
assert(type(ui.getPlayGuideActionAt) == "function", "ui.getPlayGuideActionAt should exist")
assert(type(ui.getLevelSelectBadges) == "function", "ui.getLevelSelectBadges should exist")
assert(type(ui.getLevelSelectHoverInfoAt) == "function", "ui.getLevelSelectHoverInfoAt should exist")

love.graphics = love.graphics or {}
love.graphics.setFont = function()
end

local function makeFont(widthPerCharacter, height)
    return {
        getWidth = function(_, text)
            return #tostring(text or "") * widthPerCharacter
        end,
        getHeight = function()
            return height
        end,
        getWrap = function(_, text, width)
            local safeWidth = math.max(widthPerCharacter, width or widthPerCharacter)
            local maxCharactersPerLine = math.max(1, math.floor(safeWidth / widthPerCharacter))
            local textLength = #tostring(text or "")
            local lineCount = math.max(1, math.ceil(textLength / maxCharactersPerLine))
            local wrapped = {}
            for index = 1, lineCount do
                wrapped[index] = ""
            end
            return safeWidth, wrapped
        end,
    }
end

local startEdge = {
    id = "start_edge",
    path = {
        points = {
            { x = 420, y = 200 },
            { x = 480, y = 200 },
        },
        segments = {
            {
                a = { x = 420, y = 200 },
                b = { x = 480, y = 200 },
                startDistance = 0,
                length = 60,
            },
        },
    },
    sourceType = "start",
}

local exitEdge = {
    id = "exit_edge",
    path = {
        points = {
            { x = 840, y = 220 },
            { x = 900, y = 220 },
        },
        segments = {
            {
                a = { x = 840, y = 220 },
                b = { x = 900, y = 220 },
                startDistance = 0,
                length = 60,
            },
        },
    },
    targetType = "exit",
}

local speedEdge = {
    id = "speed_edge",
    path = {
        points = {
            { x = 720, y = 410 },
            { x = 920, y = 410 },
        },
        segments = {
            {
                a = { x = 720, y = 410 },
                b = { x = 920, y = 410 },
                startDistance = 0,
                length = 200,
            },
        },
    },
    styleSections = {
        {
            roadType = "fast",
            startDistance = 0,
            endDistance = 200,
        },
    },
}

local testTrain = {
    spawnTime = 12,
    deadline = 25,
    wagonCount = 4,
    goalColor = "blue",
    trainColor = "blue",
    color = { 0.33, 0.8, 0.98 },
}

local testWorld = {
    junctionOrder = {
        {
            mergePoint = { x = 600, y = 300 },
            crossingRadius = 20,
            control = { type = "delayed", delay = 2.25 },
            activeOutputIndex = 2,
            outputs = {
                { label = "South Exit" },
                { label = "West Exit" },
            },
        },
    },
    edges = {
        start_edge = startEdge,
        exit_edge = exitEdge,
        speed_edge = speedEdge,
    },
}

function testWorld:getInputEdgeGroups()
    return {
        {
            edge = startEdge,
            trains = { testTrain },
        },
    }
end

function testWorld:getOutputBadgeGroups()
    return {
        {
            edge = exitEdge,
            deliveredCount = 1,
            expectedCount = 3,
            acceptedColors = { "blue" },
        },
    }
end

function testWorld:isCrossingHit(junction, x, y)
    local dx = x - junction.mergePoint.x
    local dy = y - junction.mergePoint.y
    return (dx * dx) + (dy * dy) <= junction.crossingRadius * junction.crossingRadius
end

function testWorld:isOutputSelectorHit(_, x, y)
    return x == 600 and y == 320
end

local hoverGame = {
    playPhase = "prepare",
    viewport = { w = 1280, h = 720 },
    fonts = {
        body = makeFont(9, 18),
        small = makeFont(7, 14),
    },
    world = testWorld,
}

local startHover = ui.getPlayHoverInfoAt(hoverGame, 200, 195)
assertEqual(startHover.title, "Start Time", "play hover identifies train start times")
assertEqual(startHover.preferBelow, true, "train start hover prefers showing the tooltip below the row")
assertEqual(startHover.y, 217, "train start hover anchors below the row instead of from its top edge")

local deadlineHover = ui.getPlayHoverInfoAt(hoverGame, 255, 195)
assertEqual(deadlineHover.title, "Deadline", "play hover identifies train deadlines")
assertEqual(deadlineHover.preferBelow, true, "train deadline hover prefers showing the tooltip below the row")
assertEqual(deadlineHover.y, 217, "train deadline hover anchors below the row instead of from its top edge")

local wagonHover = ui.getPlayHoverInfoAt(hoverGame, 325, 195)
assertEqual(wagonHover.title, "Wagons & Color", "play hover identifies wagon previews")
assertEqual(wagonHover.preferBelow, true, "wagon hover prefers showing the tooltip below the row")
assertEqual(wagonHover.y, 217, "wagon hover anchors below the row instead of from its top edge")

local badgeHover = ui.getPlayHoverInfoAt(hoverGame, 830, 220)
assertEqual(badgeHover.title, "Expected Trains", "play hover identifies exit badges")

local junctionHover = ui.getPlayHoverInfoAt(hoverGame, 600, 300)
assertEqual(junctionHover.title, "Delay Junction", "play hover identifies junction controls")

local selectorHover = ui.getPlayHoverInfoAt(hoverGame, 600, 320)
assertEqual(selectorHover.title, "Output Selector", "play hover identifies outgoing selector controls")
assertEqual(selectorHover.text:find("West Exit", 1, true) ~= nil, true, "selector hover includes the active output label")

local speedHover = ui.getPlayHoverInfoAt(hoverGame, 810, 414)
assertEqual(speedHover.title, "Fast Section", "play hover identifies speed-modified track sections")

hoverGame.playPhase = "play"
assertEqual(ui.getPlayHoverInfoAt(hoverGame, 600, 300), nil, "play hover disables itself outside preparation")
hoverGame.playPhase = "prepare"
hoverGame.playGuide = {
    stepIndex = 1,
    steps = {
        {
            target = "junction",
            placement = "right",
            text = "Guide test copy.",
        },
    },
}

local foundGuideNext = false
local foundGuideSkip = false
for y = 80, hoverGame.viewport.h - 20, 4 do
    for x = 20, hoverGame.viewport.w - 20, 4 do
        local action = ui.getPlayGuideActionAt(hoverGame, x, y)
        if action == "next" then
            foundGuideNext = true
        elseif action == "skip" then
            foundGuideSkip = true
        end
    end
end

assert(foundGuideNext, "play guide next button should be detectable")
assert(foundGuideSkip, "play guide skip button should be detectable")
hoverGame.playGuide = nil

local levelSelectDescriptor = {
    previewLevel = {
        timeLimit = 45,
        junctions = {
            { control = { type = "direct" } },
            { control = { type = "delayed" } },
            { control = { type = "trip" } },
        },
        trains = {
            { deadline = nil },
            { deadline = 18 },
        },
    },
}

local levelSelectBadges = ui.getLevelSelectBadges(levelSelectDescriptor)
local badgeLabels = {}
local badgeByLabel = {}
for _, badge in ipairs(levelSelectBadges) do
    badgeLabels[#badgeLabels + 1] = badge.label
    badgeByLabel[badge.label] = badge
end

assertEqual(
    table.concat(badgeLabels, ","),
    "Direct,Delay,Trip,Deadline,Express",
    "level select badges include renamed delay plus deadline and express"
)
assertEqual(
    badgeByLabel.Direct.tooltipText,
    "This map contains a direct junction.",
    "direct badge tooltip explains the direct junction"
)
assertEqual(
    badgeByLabel.Delay.tooltipText,
    "This map contains a delay junction.",
    "delay badge tooltip explains the delay junction"
)

local levelSelectGame = {
    viewport = { w = 1280, h = 720 },
    fonts = {
        title = makeFont(12, 24),
        body = makeFont(9, 18),
        small = makeFont(7, 14),
    },
    levelSelectMode = "library",
    levelSelectFilter = "all",
    levelSelectSelectedId = "builtin:badge_test.lua",
    levelSelectSelectedMapUuid = "badge-test",
    levelSelectVisualIndex = 1,
    levelSelectTargetVisualIndex = 1,
    levelSelectIssue = nil,
    availableMaps = {
        {
            id = "builtin:badge_test.lua",
            mapUuid = "badge-test",
            source = "builtin",
            mapKind = "tutorial",
            name = "Badge Test",
            displayName = "Badge Test",
            previewLevel = levelSelectDescriptor.previewLevel,
        },
    },
}

local marketplaceDescriptorGame = {
    levelSelectMode = "marketplace",
    levelSelectMarketplaceTab = "top",
    levelSelectMarketplaceSearchQuery = "",
    getMarketplaceFavoriteAnimation = function()
        return nil
    end,
    getMarketplaceEntries = function()
        return {
            {
                map_uuid = "shared-market-map",
                internal_identifier = "A1B2",
                creator_uuid = "creator-1",
                creator_display_name = "Creator",
                map_name = "Shared Map",
                map_category = "users",
                liked_by_player = false,
                favorite_count = 2,
                map = {
                    junctions = {},
                    trains = {},
                },
            },
            {
                map_uuid = "shared-market-map",
                internal_identifier = "C3D4",
                creator_uuid = "creator-1",
                creator_display_name = "Creator",
                map_name = "Shared Map Variant",
                map_category = "users",
                liked_by_player = true,
                favorite_count = 5,
                map = {
                    junctions = {},
                    trains = {},
                },
            },
        }
    end,
}

local marketplaceDescriptors = ui.getLevelSelectMapDescriptors(marketplaceDescriptorGame)
assertEqual(#marketplaceDescriptors, 2, "marketplace descriptors include both entries even when they share a map UUID")
assert(
    marketplaceDescriptors[1].id ~= marketplaceDescriptors[2].id,
    "marketplace descriptors keep unique ids when entries share a map UUID"
)

local delayBadgeHover = nil
for y = 360, 390 do
    for x = 500, 780 do
        local hoverInfo = ui.getLevelSelectHoverInfoAt(levelSelectGame, x, y)
        if hoverInfo and hoverInfo.title == "Delay Junction" then
            delayBadgeHover = hoverInfo
            break
        end
    end
    if delayBadgeHover then
        break
    end
end

assert(delayBadgeHover ~= nil, "level select hover should detect delay badge tooltips")
assertEqual(
    delayBadgeHover.text,
    "This map contains a delay junction.",
    "level select hover uses the badge tooltip copy"
)

print("ui formatting tests passed")
