local ui = {}
local uiControls = require("src.game.ui.ui_controls")
local roadTypes = require("src.game.data.road_types")
local trackSceneRenderer = require("src.game.rendering.track_scene_renderer")
local levelSelectSelection = require("src.game.ui.level_select_selection")

local LEVEL_SELECT = {
    titleBarY = 28,
    titleBarH = 74,
    carouselCenterY = 300,
    cardBaseW = 292,
    cardBaseH = 286,
    sideLift = 46,
    filterW = 536,
    filterH = 42,
    selectorGap = 10,
    searchGap = 16,
    bottomSelectorGap = 12,
    bottomBarY = 626,
    bottomBarH = 92,
    statusCard = {
        topGap = 12,
        minW = 180,
        maxW = 620,
        paddingX = 18,
        paddingY = 10,
        titleGap = 4,
        cornerRadius = 14,
    },
    uploadDialog = {
        panelW = 620,
        panelH = 360,
        valueH = 58,
        buttonW = 176,
        buttonH = 42,
        buttonGap = 18,
    },
}

local LEVEL_SELECT_ACTION_LAYOUT = {
    buttonH = 42,
    buttonGap = 18,
    startW = 170,
    editW = 148,
    toggleW = 188,
    uploadW = 170,
    downloadW = 170,
    refreshW = 148,
}

local MARKETPLACE_LAYOUT = {
    searchW = 460,
    searchH = 42,
    browseResultLimit = 10,
    searchResultLimit = 5,
    cardIndicatorInset = 14,
    cardIndicatorH = 28,
    cardIndicatorRadius = 14,
    favoriteButtonH = 30,
    favoriteButtonCornerRadius = 12,
    favoriteButtonHeartRadius = 5,
    favoriteButtonHeartInsetX = 18,
    favoriteButtonHeartInsetY = 9,
    favoriteButtonInset = 14,
    favoriteButtonMinH = 24,
    favoriteButtonMinW = 68,
    favoriteButtonOutlineWidth = 2,
    favoriteButtonTextInset = 34,
    favoriteButtonW = 86,
    favoriteLift = 14,
    favoriteSpacing = 10,
    favoritePlusOneBaseOffset = 12,
    favoritePlusOneRise = 18,
    titleMetaTop = 48,
}
local MARKETPLACE_REMOTE_SOURCE = "remote"
local MARKETPLACE_REMOTE_CATEGORY_USERS = "users"

local MARKETPLACE_FAVORITE_COLORS = {
    likedFill = { 0.42, 0.16, 0.22, 0.98 },
    likedLine = { 0.98, 0.48, 0.62, 1 },
    likedText = { 1, 0.94, 0.97, 1 },
    unlikedFill = { 0.1, 0.14, 0.19, 0.96 },
    unlikedLine = { 0.56, 0.72, 0.98, 1 },
    unlikedText = { 0.94, 0.96, 1, 1 },
}

local PREVIEW_COLORS = {
    background = { 0.06, 0.09, 0.12, 1 },
    frame = { 0.24, 0.32, 0.4, 1 },
    railBed = { 0.16, 0.2, 0.24, 1 },
    mutedTrack = { 0.26, 0.3, 0.36, 0.96 },
    label = { 0.84, 0.88, 0.92, 1 },
    control = {
        direct = { 0.34, 0.84, 0.98, 1 },
        delayed = { 0.99, 0.78, 0.32, 1 },
        pump = { 0.93, 0.22, 0.84, 1 },
        spring = { 0.4, 0.96, 0.74, 1 },
        relay = { 0.56, 0.72, 0.98, 1 },
        trip = { 0.98, 0.6, 0.28, 1 },
        crossbar = { 0.92, 0.38, 0.68, 1 },
    },
}

local CONTROL_SHORT_LABELS = {
    direct = "Direct",
    delayed = "Delay",
    pump = "Charge",
    spring = "Spring",
    relay = "Relay",
    trip = "Trip",
    crossbar = "Cross",
}

local LEVEL_SELECT_BADGE_DEFINITIONS = {
    direct = {
        label = "Direct",
        tooltipTitle = "Direct Junction",
        tooltipText = "This map contains a direct junction.",
    },
    delayed = {
        label = "Delay",
        tooltipTitle = "Delay Junction",
        tooltipText = "This map contains a delay junction.",
    },
    pump = {
        label = "Charge",
        tooltipTitle = "Charge Junction",
        tooltipText = "This map contains a charge junction.",
    },
    spring = {
        label = "Spring",
        tooltipTitle = "Spring Junction",
        tooltipText = "This map contains a spring junction.",
    },
    relay = {
        label = "Relay",
        tooltipTitle = "Relay Junction",
        tooltipText = "This map contains a relay junction.",
    },
    trip = {
        label = "Trip",
        tooltipTitle = "Trip Junction",
        tooltipText = "This map contains a trip junction.",
    },
    crossbar = {
        label = "Cross",
        tooltipTitle = "Crossbar Junction",
        tooltipText = "This map contains a crossbar junction.",
    },
    deadline = {
        label = "Deadline",
        tooltipTitle = "Map Deadline",
        tooltipText = "This map has an overall deadline.",
        fillColor = { 0.98, 0.66, 0.28, 0.98 },
        lineColor = { 0.99, 0.86, 0.44, 1 },
        textColor = { 0.2, 0.12, 0.02, 1 },
    },
    express = {
        label = "Express",
        tooltipTitle = "Express Train",
        tooltipText = "This map contains at least one train with a deadline.",
        fillColor = { 0.38, 0.94, 0.86, 0.98 },
        lineColor = { 0.74, 0.99, 0.95, 1 },
        textColor = { 0.05, 0.16, 0.14, 1 },
    },
}

local PANEL_COLORS = {
    background = { 0.05, 0.07, 0.09, 1 },
    panelFill = { 0.09, 0.11, 0.15, 0.98 },
    panelLine = { 0.25, 0.34, 0.42, 1 },
    panelInnerLine = { 0.44, 0.62, 0.78, 0.38 },
    titleText = { 0.97, 0.98, 1, 1 },
    bodyText = { 0.84, 0.88, 0.92, 1 },
    mutedText = { 0.68, 0.74, 0.8, 1 },
}

local getLevelSelectActionButtons
local getMapControlTypes
local buildMarketplaceDisplayEntries
local getLevelSelectFilterRect
local getMarketplaceEntryForDescriptor
local getMarketplaceIndicatorColors

local PLAY_OVERLAY = {
    margin = 24,
    width = 420,
    padding = 18,
    radius = 18,
    lineGap = 6,
    sectionGap = 14,
}
local PLAY_TOOLTIP_LAYOUT = {
    width = 340,
    gap = 16,
    paddingX = 16,
    paddingY = 14,
    cornerRadius = 14,
    dividerGap = 8,
}
local PLAY_GUIDE_LAYOUT = {
    width = 430,
    margin = 24,
    minTop = 88,
    focusPadding = 12,
    focusRadius = 22,
    gap = 22,
    paddingX = 18,
    paddingY = 18,
    buttonGap = 14,
    buttonH = 38,
    buttonSkipW = 118,
    buttonNextW = 132,
}

local MENU_LAYOUT = {
    buttonWidth = 320,
    buttonHeight = 56,
    buttonGap = 16,
    firstButtonY = 248,
}

local PROFILE_MODE_SETUP_LAYOUT = {
    panelW = 640,
    panelH = 360,
    buttonW = 220,
    buttonH = 72,
    buttonGap = 28,
    buttonY = 246,
}
local PROFILE_MODE_TOOLTIP_LAYOUT = {
    maxWidth = 268,
    paddingX = 14,
    paddingY = 12,
    cornerRadius = 12,
    gap = 10,
}

local LEADERBOARD_LOADING = {
    spinnerRadius = 18,
    spinnerThickness = 4,
    spinnerArcLength = math.pi * 1.35,
    spinnerSpeed = 3.2,
    emptyStateYOffset = 180,
    emptySpinnerYOffset = 34,
    emptyTextYOffset = 68,
}
local LEADERBOARD_SCORE_DECIMAL_PLACES = 3
local LEVEL_SELECT_LEADERBOARD_PLAYER_NAME_MAX_CHARACTERS = 14
local LEADERBOARD_REFRESH_INDICATOR_RIGHT_PADDING = 28
local LEADERBOARD_REFRESH_INDICATOR_BOTTOM_PADDING = 18
local REFRESH_LOADING_ANIMATION_STEP_SECONDS = 0.4
local REFRESH_LOADING_ANIMATION_FRAME_COUNT = 3

local LEADERBOARD_LAYOUT = {
    panelX = 36,
    panelY = 100,
    panelMargin = 72,
    contentPadding = 28,
    titlePadding = 24,
    headerY = 116,
    rowYOffset = 28,
    rowHeight = 34,
    rowGap = 8,
    rowRadius = 10,
    rankWidth = 40,
    mapGap = 28,
    mapMinWidth = 176,
    playerXOffset = 52,
    playerRightPadding = 36,
    scoreWidth = 120,
    maxVisibleRows = 12,
    recordWidth = 152,
    recordGap = 18,
    recordRightPadding = 16,
    rowBottomPadding = 56,
    rowPrimaryTextOffsetY = 2,
    tooltipWidth = 360,
    tooltipHeight = 62,
    tooltipOffsetY = 18,
    filterBadgeY = 74,
    filterBadgeHeight = 28,
    filterBadgePaddingX = 16,
    filterBadgeMaxWidth = 460,
}

local LEVEL_SELECT_LEADERBOARD_CARD = {
    inset = 18,
    titleTop = 20,
    maxRows = 5,
    rowTop = 56,
    rowHeight = 24,
    rowGap = 6,
    rowRadius = 10,
    rowPaddingX = 10,
    rankWidth = 32,
    scoreWidth = 76,
    pinnedGap = 12,
    statusPaddingX = 20,
    statusWidthMargin = 40,
    refreshPaddingRight = 8,
    refreshPaddingBottom = 2,
}


local shared = {
    uiControls = uiControls,
    roadTypes = roadTypes,
    trackSceneRenderer = trackSceneRenderer,
    levelSelectSelection = levelSelectSelection,
    LEVEL_SELECT = LEVEL_SELECT,
    LEVEL_SELECT_ACTION_LAYOUT = LEVEL_SELECT_ACTION_LAYOUT,
    MARKETPLACE_LAYOUT = MARKETPLACE_LAYOUT,
    MARKETPLACE_REMOTE_SOURCE = MARKETPLACE_REMOTE_SOURCE,
    MARKETPLACE_REMOTE_CATEGORY_USERS = MARKETPLACE_REMOTE_CATEGORY_USERS,
    MARKETPLACE_FAVORITE_COLORS = MARKETPLACE_FAVORITE_COLORS,
    PREVIEW_COLORS = PREVIEW_COLORS,
    CONTROL_SHORT_LABELS = CONTROL_SHORT_LABELS,
    LEVEL_SELECT_BADGE_DEFINITIONS = LEVEL_SELECT_BADGE_DEFINITIONS,
    PANEL_COLORS = PANEL_COLORS,
    getLevelSelectActionButtons = getLevelSelectActionButtons,
    getMapControlTypes = getMapControlTypes,
    buildMarketplaceDisplayEntries = buildMarketplaceDisplayEntries,
    getLevelSelectFilterRect = getLevelSelectFilterRect,
    getMarketplaceEntryForDescriptor = getMarketplaceEntryForDescriptor,
    getMarketplaceIndicatorColors = getMarketplaceIndicatorColors,
    PLAY_OVERLAY = PLAY_OVERLAY,
    PLAY_TOOLTIP_LAYOUT = PLAY_TOOLTIP_LAYOUT,
    PLAY_GUIDE_LAYOUT = PLAY_GUIDE_LAYOUT,
    MENU_LAYOUT = MENU_LAYOUT,
    PROFILE_MODE_SETUP_LAYOUT = PROFILE_MODE_SETUP_LAYOUT,
    PROFILE_MODE_TOOLTIP_LAYOUT = PROFILE_MODE_TOOLTIP_LAYOUT,
    LEADERBOARD_LOADING = LEADERBOARD_LOADING,
    LEADERBOARD_SCORE_DECIMAL_PLACES = LEADERBOARD_SCORE_DECIMAL_PLACES,
    LEVEL_SELECT_LEADERBOARD_PLAYER_NAME_MAX_CHARACTERS = LEVEL_SELECT_LEADERBOARD_PLAYER_NAME_MAX_CHARACTERS,
    LEADERBOARD_REFRESH_INDICATOR_RIGHT_PADDING = LEADERBOARD_REFRESH_INDICATOR_RIGHT_PADDING,
    LEADERBOARD_REFRESH_INDICATOR_BOTTOM_PADDING = LEADERBOARD_REFRESH_INDICATOR_BOTTOM_PADDING,
    REFRESH_LOADING_ANIMATION_STEP_SECONDS = REFRESH_LOADING_ANIMATION_STEP_SECONDS,
    REFRESH_LOADING_ANIMATION_FRAME_COUNT = REFRESH_LOADING_ANIMATION_FRAME_COUNT,
    LEADERBOARD_LAYOUT = LEADERBOARD_LAYOUT,
    LEVEL_SELECT_LEADERBOARD_CARD = LEVEL_SELECT_LEADERBOARD_CARD,
}

require("src.game.ui.screen_common_helpers")(ui, shared)
require("src.game.ui.screen_level_select")(ui, shared)
require("src.game.ui.screen_level_select_draw")(ui, shared)
require("src.game.ui.screen_play_and_results")(ui, shared)
require("src.game.ui.screen_drawers")(ui, shared)

return ui
