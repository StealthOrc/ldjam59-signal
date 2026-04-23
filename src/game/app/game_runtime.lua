local input = require("src.game.ui.shortcut_input")
local mapEditor = require("src.game.editor.map_editor")
local mapStorage = require("src.game.storage.map_storage")
local localScoreStorage = require("src.game.storage.local_score_storage")
local mapReplayIndexStorage = require("src.game.storage.map_replay_index_storage")
local profileStorage = require("src.game.storage.profile_storage")
local leaderboardClient = require("src.game.network.leaderboard_client")
local requestInspector = require("src.game.network.request_inspector")
local leaderboardPreviewCache = require("src.game.storage.leaderboard_preview_cache")
local replayStorage = require("src.game.storage.replay_storage")
local replayRecorder = require("src.game.replay.replay_recorder")
local replayRuntime = require("src.game.replay.replay_runtime")
local levelSelectPreviewLogic = require("src.game.ui.level_select_preview_logic")
local levelSelectSelection = require("src.game.ui.level_select_selection")
local marketplaceFavoriteLogic = require("src.game.network.marketplace_favorite_logic")
local refreshIndicatorLogic = require("src.game.ui.refresh_indicator_logic")
local world = require("src.game.gameplay.railway_world")
local ui = require("src.game.ui.game_screens")
local json = require("src.game.util.json")
local pixelPerfectText = require("src.game.rendering.pixel_perfect_text")

local Game = {}
Game.__index = Game
local ONLINE_CONFIG_LOG_PREFIX = "[Leaderboard]"
local LEADERBOARD_CACHE_DURATION_SECONDS = 60
local LEADERBOARD_FETCH_TIMEOUT_SECONDS = 5
local LEADERBOARD_ENTRY_LIMIT = 50
local LEADERBOARD_THREAD_FILE = "src/game/network/leaderboard_fetch_thread.lua"
local LEADERBOARD_REQUEST_CHANNEL_NAME = "signal_leaderboard_request"
local LEADERBOARD_RESPONSE_CHANNEL_NAME = "signal_leaderboard_response"
local NETWORK_REQUEST_DEBUG_CHANNEL_NAME = "signal_network_request_debug"
local LEADERBOARD_SCOPE_GLOBAL = "global"
local LEADERBOARD_SCOPE_MAP_PREFIX = "map:"
local LEADERBOARD_STATUS_IDLE = "idle"
local LEADERBOARD_STATUS_LOADING = "loading"
local LEADERBOARD_STATUS_READY = "ready"
local LEADERBOARD_STATUS_ERROR = "error"
local LEADERBOARD_STATUS_DISABLED = "disabled"
local LEADERBOARD_SCOPE_MAP = "map"
local LEADERBOARD_MESSAGE_LOADING = "Loading leaderboard..."
local LEADERBOARD_MESSAGE_EMPTY = "No entries were found for this leaderboard yet."
local LEADERBOARD_MESSAGE_FETCH_FAILED = "The leaderboard could not be loaded."
local LEADERBOARD_MESSAGE_NO_DATA = "No data right now."
local LEADERBOARD_MESSAGE_UNAVAILABLE = "Leaderboard unavailable."
local LEADERBOARD_MAP_NAME_UNKNOWN = "Unknown Map"
local LEVEL_SELECT_PREVIEW_ENTRY_LIMIT = 5
local LEVEL_SELECT_PREVIEW_CACHE_DURATION_SECONDS = 60
local LEVEL_SELECT_PREVIEW_FETCH_TIMEOUT_SECONDS = 5
local LEVEL_SELECT_PREVIEW_STATUS_IDLE = "idle"
local LEVEL_SELECT_PREVIEW_STATUS_LOADING = "loading"
local LEVEL_SELECT_PREVIEW_STATUS_READY = "ready"
local LEVEL_SELECT_PREVIEW_STATUS_ERROR = "error"
local LEVEL_SELECT_PREVIEW_MESSAGE_LOADING = "Loading leaderboard..."
local LEVEL_SELECT_PREVIEW_MESSAGE_EMPTY = "No scores yet."
local LEVEL_SELECT_PREVIEW_MESSAGE_NO_LOCAL_DATA = "No local leaderboard data."
local LEVEL_SELECT_PREVIEW_DISPLAY_SWAP_DELAY_FRAMES = 1
local LEVEL_SELECT_MODE_LIBRARY = "library"
local LEVEL_SELECT_MODE_MARKETPLACE = "marketplace"
local LEVEL_SELECT_MARKETPLACE_TAB_TOP = "top"
local LEVEL_SELECT_MARKETPLACE_TAB_RANDOM = "random"
local LEVEL_SELECT_MARKETPLACE_TAB_SEARCH = "search"
local LEVEL_SELECT_MARKETPLACE_SEARCH_MAX_LENGTH = 40
local LEVEL_SELECT_MARKETPLACE_TAB_ORDER = {
    LEVEL_SELECT_MARKETPLACE_TAB_TOP,
    LEVEL_SELECT_MARKETPLACE_TAB_RANDOM,
    LEVEL_SELECT_MARKETPLACE_TAB_SEARCH,
}
local LEVEL_SELECT_MARKETPLACE_SOURCE_FAVORITES = "favorites"
local LEVEL_SELECT_MARKETPLACE_SOURCE_SEARCH = "search"
local LEVEL_SELECT_MARKETPLACE_SCOPE_FAVORITES = "favorites"
local LEVEL_SELECT_MARKETPLACE_SCOPE_SEARCH_PREFIX = "search:"
local LEVEL_SELECT_MARKETPLACE_REMOTE_LIMIT = 10
local LEVEL_SELECT_MARKETPLACE_FETCH_TIMEOUT_SECONDS = 5
local LEVEL_SELECT_MARKETPLACE_CACHE_DURATION_SECONDS = 60
local LEVEL_SELECT_MARKETPLACE_STATUS_IDLE = "idle"
local LEVEL_SELECT_MARKETPLACE_STATUS_LOADING = "loading"
local LEVEL_SELECT_MARKETPLACE_STATUS_READY = "ready"
local LEVEL_SELECT_MARKETPLACE_STATUS_ERROR = "error"
local LEVEL_SELECT_MARKETPLACE_STATUS_DISABLED = "disabled"
local LEVEL_SELECT_MARKETPLACE_MESSAGE_LOADING = "Loading online maps..."
local LEVEL_SELECT_MARKETPLACE_MESSAGE_EMPTY_SEARCH = "Type a map name, UUID, code, or creator to search."
local LEVEL_SELECT_MARKETPLACE_MESSAGE_FETCH_FAILED = "The online maps could not be loaded."
local ONLINE_WRITE_TIMEOUT_SECONDS = 5
local MARKETPLACE_FAVORITE_ANIMATION_DURATION_SECONDS = 0.55
local MARKETPLACE_FAVORITE_OPTIMISTIC_DELTA = 1
local LEVEL_SELECT_ACTION_STATUS_INFO = "info"
local LEVEL_SELECT_ACTION_STATUS_SUCCESS = "success"
local LEVEL_SELECT_ACTION_STATUS_ERROR = "error"
local PLAY_MODE_ONLINE = "online"
local PLAY_MODE_OFFLINE = "offline"
local MAP_CATEGORY_ONLINE = PLAY_MODE_ONLINE
local PROFILE_NAME_MAX_LENGTH = 24
local PLAY_GUIDE_SHRINK_DURATION = 0.12
local PLAY_GUIDE_MOVE_DURATION = 0.2
local PLAY_GUIDE_GROW_DURATION = 0.16
local SIMPLE_BEGINNING_GUIDE_MAP_UUID = "3206710d-793f-474e-957a-fdb721926f52"
local TWO_CROSSINGS_GUIDE_MAP_UUID = "16b6e4e1-cafc-4f02-8285-11dc7e2f5d75"
local SIMPLE_BEGINNING_GUIDE_STEPS = {
    {
        target = "junction",
        placement = "right",
        text = "Hey, seems like it's your first time around here. I'll show you around.",
    },
    {
        target = "junction",
        placement = "right",
        text = "Alright, we have a lot of business here and a lot of trains coming in. It's your first workday, so I'll show you right away how to route our trains correctly. Are you ready?",
    },
    {
        target = "junction_with_selector",
        placement = "right",
        text = "You see this little switchy thing right next to me?",
    },
    {
        target = "junction_with_selector",
        placement = "below",
        allowHoverTooltip = true,
        allowJunctionClick = true,
        focusIncomingTracks = true,
        text = "This is a junction. In this case, a direct junction. If you want to know what a direct junction is, you can just hover over it. You can also click it to switch it. Maybe you should try that right now.",
    },
    {
        target = "first_input_card",
        placement = "below",
        allowHoverTooltip = true,
        text = "Now that we know how to route our trains, we need to know where trains come from and where they need to go, right? Here, look. This is the train table for this line. It shows the start time, where this train needs to go, and how many wagons it has. You can figure the details out by hovering over it.",
    },
    {
        target = "first_output_badge",
        placement = "above",
        allowHoverTooltip = true,
        text = "Here you can see how many trains we expect here. In this case, we're expecting blue and yellow trains for this exit, so don't mind the colors too much.",
    },
    {
        target = "start_run_button",
        placement = "below",
        text = "I think you're ready. If you want to inspect a few things, feel free to do so. Otherthan that you're ready to do the job alone now! Click the Start Run Button or press Spacebar.",
    },
}
local TWO_CROSSINGS_GUIDE_STEPS = {
    {
        target = "screen_center",
        placement = "center",
        text = "Oh, hey, it's you again. This one has one more little trick up its sleeve. I'll just tell you about it, and then I'll be out. I'll be away. All right? Pinky promise.",
    },
    {
        target = "junction_with_selector",
        junctionId = "junction_route_1_route_2_1",
        placement = "top_right",
        allowHoverTooltip = true,
        allowControlClick = true,
        focusSelectorOnly = true,
        anchorTarget = "junction",
        hideSkip = true,
        nextLabel = "Understood",
        text = "All right, you already know about junctions, but we haven't seen real crossings yet, have we? You can click this little thingy, and this will then determine the outgoing lines. And no, scratch that. The main thingy changes the incoming lines, and this little thingy changes the active outgoing line. Hover over it and try it yourself. That's it for me. I'm out.",
    },
}
local PLAY_GUIDE_STEPS_BY_MAP_UUID = {
    [SIMPLE_BEGINNING_GUIDE_MAP_UUID] = SIMPLE_BEGINNING_GUIDE_STEPS,
    [TWO_CROSSINGS_GUIDE_MAP_UUID] = TWO_CROSSINGS_GUIDE_STEPS,
}
local LEADERBOARD_REFRESH_LABEL_LOCAL_ONLY = "Local Only"
local LEADERBOARD_MESSAGE_NO_LOCAL_SCORES = "No local personal scores yet."
local LEVEL_SELECT_PREVIEW_MESSAGE_NO_LOCAL_BEST = "No local personal best yet."
local LEVEL_SELECT_PREVIEW_TITLE_PERSONAL_BEST = "Personal Best"
local LEADERBOARD_TITLE_ONLINE = "Online Leaderboard"
local LEADERBOARD_TITLE_PERSONAL = "Personal Scores"
local LEADERBOARD_TITLE_MAP = "Map Leaderboard"
local LEADERBOARD_TITLE_MAP_PERSONAL = "Personal Best"
local RESULTS_MESSAGE_LOCAL_BEST_SAVED = "Saved a new local personal best."
local RESULTS_MESSAGE_LOCAL_BEST_KEPT = "Your local personal best stays higher."
local RESULTS_MESSAGE_LOCAL_SAVE_FAILED = "The local personal score could not be saved."
local LEVEL_SELECT_UPLOAD_ENV_REQUIRED_MESSAGE = "Create a local .env or build.env file with API_KEY and API_BASE_URL before uploading maps."
local NETWORK_REQUEST_LOG_MAX_ENTRIES = 40

local function getNowSeconds()
    if love and love.timer and love.timer.getTime then
        return love.timer.getTime()
    end

    return os.clock()
end

local function getNowUnixSeconds()
    if os and os.time then
        return os.time()
    end

    return math.floor(getNowSeconds())
end

local function drainChannel(channel)
    if not channel then
        return
    end

    while channel:pop() ~= nil do
    end
end

local function findLevelSelectIndex(game, maps)
    local selectedIndex = levelSelectSelection.findIndex(maps, game.levelSelectSelectedId, game.levelSelectSelectedMapUuid)
    if selectedIndex then
        game.levelSelectSelectedId = maps[selectedIndex].id
        game.levelSelectSelectedMapUuid = maps[selectedIndex].mapUuid
    else
        game.levelSelectSelectedId = nil
        game.levelSelectSelectedMapUuid = nil
    end

    return selectedIndex
end

local function closestWrappedIndex(currentValue, targetIndex, count)
    if not currentValue or not targetIndex or count <= 0 then
        return targetIndex
    end

    local cycle = math.floor((currentValue - 1) / count)
    local bestValue = targetIndex + (cycle * count)
    local bestDistance = math.abs(bestValue - currentValue)

    for _, offset in ipairs({ -count, count }) do
        local candidate = bestValue + offset
        local candidateDistance = math.abs(candidate - currentValue)
        if candidateDistance < bestDistance then
            bestValue = candidate
            bestDistance = candidateDistance
        end
    end

    return bestValue
end

local function normalizeWrappedIndex(index, count)
    if not index or count <= 0 then
        return index
    end

    return ((index - 1) % count) + 1
end

local function trim(value)
    return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function trimLastUtf8Character(value)
    return (value or ""):gsub("[%z\1-\127\194-\244][\128-\191]*$", "")
end

local function getProfilePlayerUuid(profile)
    if type(profile) ~= "table" then
        return ""
    end

    return tostring(profile.player_uuid or "")
end

local function getProfilePlayMode(profile)
    if type(profile) ~= "table" then
        return ""
    end

    return tostring(profile.playMode or "")
end

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, entry in pairs(value) do
        copy[deepCopy(key)] = deepCopy(entry)
    end

    return copy
end

local function normalizeLeaderboardEntry(entry, fallbackMapUuid, fallbackRank)
    if type(entry) ~= "table" then
        return nil
    end

    return {
        playerDisplayName = entry.display_name or entry.player_display_name or "Unknown",
        playerUuid = entry.player_uuid or "",
        mapCount = tonumber(entry.map_count) or 0,
        score = tonumber(entry.score or 0) or 0,
        rank = tonumber(entry.rank) or fallbackRank or 0,
        mapUuid = entry.map_uuid or entry.last_map_uuid or fallbackMapUuid,
        recordedAt = entry.recorded_at or entry.updated_at,
        createdAt = entry.created_at,
        updatedAt = entry.updated_at,
        replayUuid = entry.replay_uuid or entry.replayUuid or "",
        durationSeconds = tonumber(entry.duration_seconds or entry.durationSeconds or 0) or 0,
        hasReplay = tostring(entry.replay_uuid or entry.replayUuid or "") ~= "",
    }
end

local function normalizeLeaderboardEntries(payload)
    local normalized = {}

    if type(payload) ~= "table" then
        return normalized
    end

    local sourceEntries = payload.entries or payload
    local fallbackMapUuid = payload.map_uuid
    if type(sourceEntries) ~= "table" then
        return normalized
    end

    for index, entry in ipairs(sourceEntries) do
        local normalizedEntry = normalizeLeaderboardEntry(entry, fallbackMapUuid, index)
        if normalizedEntry then
            normalized[#normalized + 1] = normalizedEntry
        end
    end

    return normalized
end

local function getLeaderboardScopeKey(mapUuid)
    if mapUuid and mapUuid ~= "" then
        return LEADERBOARD_SCOPE_MAP_PREFIX .. mapUuid
    end

    return LEADERBOARD_SCOPE_GLOBAL
end

local function describeConfigSource(onlineConfig, key)
    local sourceByKey = onlineConfig and onlineConfig.sourceByKey or {}
    return sourceByKey[key] or "missing"
end

local function logOnlineConfig(onlineConfig)
    local config = onlineConfig or {}
    local statusText = config.isConfigured and "ready" or "incomplete"
    local apiKeySource = describeConfigSource(config, "API_KEY")
    local apiBaseUrlSource = describeConfigSource(config, "API_BASE_URL")

    print(string.format(
        "%s startup status=%s apiKeySource=%s apiBaseUrlSource=%s",
        ONLINE_CONFIG_LOG_PREFIX,
        statusText,
        apiKeySource,
        apiBaseUrlSource
    ))

    for _, errorMessage in ipairs(config.errors or {}) do
        print(string.format("%s config error: %s", ONLINE_CONFIG_LOG_PREFIX, errorMessage))
    end
end

local function getLeaderboardUnavailableMessage()
    return LEADERBOARD_MESSAGE_UNAVAILABLE
end

local function normalizeLeaderboardErrorMessage(message)
    local text = tostring(message or "")
    if text:find("API_KEY", 1, true) or text:find("API_BASE_URL", 1, true) or text:find(".env", 1, true) then
        return getLeaderboardUnavailableMessage()
    end

    return text ~= "" and text or LEADERBOARD_MESSAGE_FETCH_FAILED
end

function Game.new()
    local self = setmetatable({}, Game)
    local profile = profileStorage.load()

    self.viewport = {
        w = 1280,
        h = 720,
    }
    self.window = {
        w = love.graphics.getWidth(),
        h = love.graphics.getHeight(),
    }

    self.fonts = {
        title = love.graphics.newFont(34),
        body = love.graphics.newFont(18),
        small = love.graphics.newFont(14),
    }
    self.pixelPerfectText = pixelPerfectText.new(love.graphics)
    self.pixelPerfectText:registerFont(self.fonts.title, { size = 34 })
    self.pixelPerfectText:registerFont(self.fonts.body, { size = 18 })
    self.pixelPerfectText:registerFont(self.fonts.small, { size = 14 })
    self.pixelPerfectText:install()

    self.profile = profile
    self.localScoreboard = localScoreStorage.load()
    self.localReplayIndex = mapReplayIndexStorage.load()
    self.onlineConfig = leaderboardClient.getConfig()
    logOnlineConfig(self.onlineConfig)
    self.screen = "profile_setup"
    if trim(profile.playerDisplayName) ~= "" then
        if getProfilePlayMode(profile) == PLAY_MODE_ONLINE or getProfilePlayMode(profile) == PLAY_MODE_OFFLINE then
            self.screen = "menu"
        else
            self.screen = "profile_mode_setup"
        end
    end
    self.levelComplete = false
    self.failureReason = nil
    self.world = nil
    self.editor = mapEditor.new(self.viewport.w, self.viewport.h, nil, {
        editorPreferences = self.profile.editor,
        onPreferencesChanged = function(editorPreferences)
            self.profile.editor = deepCopy(editorPreferences)
            profileStorage.save(self.profile or {})
        end,
    })
    self.availableMaps = {}
    self.mapNameByUuid = {}
    self.currentMapDescriptor = nil
    self.currentRunOrigin = nil
    self.levelSelectIssue = nil
    self.levelSelectSelectedId = nil
    self.levelSelectSelectedMapUuid = nil
    self.levelSelectFilter = "campaign"
    self.levelSelectHoverId = nil
    self.levelSelectHoverInfo = nil
    self.levelSelectVisualIndex = nil
    self.levelSelectTargetVisualIndex = nil
    self.levelSelectScroll = 0
    self.levelSelectPendingScrollDirections = {}
    self.levelSelectMode = LEVEL_SELECT_MODE_LIBRARY
    self.levelSelectMarketplaceTab = LEVEL_SELECT_MARKETPLACE_TAB_TOP
    self.levelSelectMarketplaceSearchQuery = ""
    self.levelSelectActionState = nil
    self.levelSelectUploadDialog = nil
    self.levelSelectReplayOverlay = nil
    self.levelSelectLeaderboardFlipMapUuid = nil
    self.levelSelectPreviewCacheByMap = leaderboardPreviewCache.load()
    self.levelSelectPreviewNextFetchAtByMap = {}
    self.levelSelectPreviewState = {
        mapUuid = nil,
        status = LEVEL_SELECT_PREVIEW_STATUS_IDLE,
        message = nil,
        forceImmediateFetch = false,
        showCachedWhileLoading = false,
        hasResolvedInitialRemoteAttempt = false,
        clearVisibleEntries = false,
        pendingPayload = nil,
        pendingFetchedAt = nil,
        pendingDelayFrames = 0,
    }
    self.levelSelectPreviewRequestSequence = 0
    self.activeLevelSelectPreviewRequestId = nil
    self.activeLevelSelectPreviewRequestStartedAt = nil
    self.activeLevelSelectPreviewRequestMapUuid = nil
    self.activeLevelSelectPreviewRequestMapHash = nil
    self.activeLevelSelectPreviewRequestCacheKey = nil
    self.marketplaceCacheByScope = {}
    self.marketplaceNextFetchAtByScope = {}
    self.marketplaceStateByScope = {}
    self.marketplaceRequestSequence = 0
    self.activeMarketplaceRequestId = nil
    self.activeMarketplaceRequestStartedAt = nil
    self.activeMarketplaceRequestScopeKey = nil
    self.remoteWriteRequestSequence = 0
    self.activeFavoriteMapRequestId = nil
    self.activeFavoriteMapRequestStartedAt = nil
    self.activeFavoriteMapMapUuid = nil
    self.activeFavoriteMapPreviousState = nil
    self.pendingFavoriteMapDesiredState = nil
    self.marketplaceFavoriteAnimationByMap = {}
    self.activeUploadMapRequestId = nil
    self.activeUploadMapRequestStartedAt = nil
    self.activeUploadMapDescriptor = nil
    self.activeUploadMapOrigin = nil
    self.activeScoreSubmitRequestId = nil
    self.activeScoreSubmitRequestStartedAt = nil
    self.activeScoreSubmitRequestKind = nil
    self.activeScoreSubmitRequestSummary = nil
    self.activeScoreSubmitRequestOnlineConfig = nil
    self.activeScoreSubmitFallbackAttempted = false
    self.activeReplayDownloadRequestId = nil
    self.activeReplayDownloadRequestStartedAt = nil
    self.activeReplayDownloadMapDescriptor = nil
    self.activeReplayDownloadEntry = nil
    self.activeReplayDownloadRequestMapUuid = nil
    self.activeReplayDownloadRequestMapHash = nil
    self.resultsSummary = nil
    self.resultsOnlineState = nil
    self.profileSetupNameBuffer = profile.playerDisplayName or ""
    self.profileSetupError = nil
    self.profileModeSelection = getProfilePlayMode(profile) ~= "" and getProfilePlayMode(profile) or PLAY_MODE_OFFLINE
    self.profileModeHoverId = nil
    self.profileModeSetupError = nil
    if getProfilePlayMode(self.profile) == PLAY_MODE_ONLINE and not self.onlineConfig.isConfigured then
        self.profile.playMode = PLAY_MODE_OFFLINE
        self.profileModeSelection = PLAY_MODE_OFFLINE
        local _, saveError = self:saveProfile()
        if saveError then
            print(string.format("%s failed to save offline fallback: %s", ONLINE_CONFIG_LOG_PREFIX, saveError))
        end
    end
    self.playOverlayMode = nil
    self.networkRequestOverlayVisible = false
    self.networkRequestLogEntries = {}
    self.networkRequestLogEntryById = {}
    self.networkRequestSelectedLogEntryId = nil
    self.networkRequestOverlayListScroll = 0
    self.networkRequestOverlayDetailScroll = 0
    self.networkRequestOverlayCopyStatus = nil
    self.playGuide = nil
    self.playGuideTransition = nil
    self.pendingReplayPreparationInteractions = {}
    self.replayRecorder = nil
    self.replayRecord = nil
    self.replayRuntime = nil
    self.replayLevelSource = nil
    self.replayHoverInfo = nil
    self.replayDragActive = false
    self.replayDragTime = nil
    self.mouseViewportX = self.viewport.w * 0.5
    self.mouseViewportY = self.viewport.h * 0.5
    self.leaderboardState = {
        status = LEADERBOARD_STATUS_IDLE,
        message = nil,
        entries = {},
        totalEntries = 0,
        fetchedAt = nil,
    }
    self.leaderboardReturnScreen = "menu"
    self.leaderboardMapUuid = nil
    self.leaderboardTitle = self:getLeaderboardTitle(nil)
    self.leaderboardHoverInfo = nil
    self.leaderboardCacheByScope = {}
    self.leaderboardNextFetchAtByScope = {}
    self.leaderboardRequestSequence = 0
    self.activeLeaderboardRequestId = nil
    self.activeLeaderboardRequestStartedAt = nil
    self.activeLeaderboardRequestScopeKey = nil
    self.leaderboardWorkerThread = nil
    self.leaderboardRequestChannel = love.thread.getChannel(LEADERBOARD_REQUEST_CHANNEL_NAME)
    self.leaderboardResponseChannel = love.thread.getChannel(LEADERBOARD_RESPONSE_CHANNEL_NAME)
    self.networkRequestDebugChannel = love.thread.getChannel(NETWORK_REQUEST_DEBUG_CHANNEL_NAME)
    drainChannel(self.leaderboardRequestChannel)
    drainChannel(self.leaderboardResponseChannel)
    drainChannel(self.networkRequestDebugChannel)
    self.playPhase = nil
    self.playHoverInfo = nil
    self.resultsHoverInfo = nil

    self:updateRenderTransform()
    self:refreshMaps()

    return self
end


local shared = {
    input = input,
    mapEditor = mapEditor,
    mapStorage = mapStorage,
    localScoreStorage = localScoreStorage,
    mapReplayIndexStorage = mapReplayIndexStorage,
    profileStorage = profileStorage,
    leaderboardClient = leaderboardClient,
    requestInspector = requestInspector,
    leaderboardPreviewCache = leaderboardPreviewCache,
    replayStorage = replayStorage,
    replayRecorder = replayRecorder,
    replayRuntime = replayRuntime,
    levelSelectPreviewLogic = levelSelectPreviewLogic,
    levelSelectSelection = levelSelectSelection,
    marketplaceFavoriteLogic = marketplaceFavoriteLogic,
    refreshIndicatorLogic = refreshIndicatorLogic,
    world = world,
    ui = ui,
    json = json,
    ONLINE_CONFIG_LOG_PREFIX = ONLINE_CONFIG_LOG_PREFIX,
    LEADERBOARD_CACHE_DURATION_SECONDS = LEADERBOARD_CACHE_DURATION_SECONDS,
    LEADERBOARD_FETCH_TIMEOUT_SECONDS = LEADERBOARD_FETCH_TIMEOUT_SECONDS,
    LEADERBOARD_ENTRY_LIMIT = LEADERBOARD_ENTRY_LIMIT,
    LEADERBOARD_THREAD_FILE = LEADERBOARD_THREAD_FILE,
    LEADERBOARD_REQUEST_CHANNEL_NAME = LEADERBOARD_REQUEST_CHANNEL_NAME,
    LEADERBOARD_RESPONSE_CHANNEL_NAME = LEADERBOARD_RESPONSE_CHANNEL_NAME,
    NETWORK_REQUEST_DEBUG_CHANNEL_NAME = NETWORK_REQUEST_DEBUG_CHANNEL_NAME,
    LEADERBOARD_SCOPE_GLOBAL = LEADERBOARD_SCOPE_GLOBAL,
    LEADERBOARD_SCOPE_MAP_PREFIX = LEADERBOARD_SCOPE_MAP_PREFIX,
    LEADERBOARD_STATUS_IDLE = LEADERBOARD_STATUS_IDLE,
    LEADERBOARD_STATUS_LOADING = LEADERBOARD_STATUS_LOADING,
    LEADERBOARD_STATUS_READY = LEADERBOARD_STATUS_READY,
    LEADERBOARD_STATUS_ERROR = LEADERBOARD_STATUS_ERROR,
    LEADERBOARD_STATUS_DISABLED = LEADERBOARD_STATUS_DISABLED,
    LEADERBOARD_SCOPE_MAP = LEADERBOARD_SCOPE_MAP,
    LEADERBOARD_MESSAGE_LOADING = LEADERBOARD_MESSAGE_LOADING,
    LEADERBOARD_MESSAGE_EMPTY = LEADERBOARD_MESSAGE_EMPTY,
    LEADERBOARD_MESSAGE_FETCH_FAILED = LEADERBOARD_MESSAGE_FETCH_FAILED,
    LEADERBOARD_MESSAGE_NO_DATA = LEADERBOARD_MESSAGE_NO_DATA,
    LEADERBOARD_MESSAGE_UNAVAILABLE = LEADERBOARD_MESSAGE_UNAVAILABLE,
    LEADERBOARD_MAP_NAME_UNKNOWN = LEADERBOARD_MAP_NAME_UNKNOWN,
    LEVEL_SELECT_PREVIEW_ENTRY_LIMIT = LEVEL_SELECT_PREVIEW_ENTRY_LIMIT,
    LEVEL_SELECT_PREVIEW_CACHE_DURATION_SECONDS = LEVEL_SELECT_PREVIEW_CACHE_DURATION_SECONDS,
    LEVEL_SELECT_PREVIEW_FETCH_TIMEOUT_SECONDS = LEVEL_SELECT_PREVIEW_FETCH_TIMEOUT_SECONDS,
    LEVEL_SELECT_PREVIEW_STATUS_IDLE = LEVEL_SELECT_PREVIEW_STATUS_IDLE,
    LEVEL_SELECT_PREVIEW_STATUS_LOADING = LEVEL_SELECT_PREVIEW_STATUS_LOADING,
    LEVEL_SELECT_PREVIEW_STATUS_READY = LEVEL_SELECT_PREVIEW_STATUS_READY,
    LEVEL_SELECT_PREVIEW_STATUS_ERROR = LEVEL_SELECT_PREVIEW_STATUS_ERROR,
    LEVEL_SELECT_PREVIEW_MESSAGE_LOADING = LEVEL_SELECT_PREVIEW_MESSAGE_LOADING,
    LEVEL_SELECT_PREVIEW_MESSAGE_EMPTY = LEVEL_SELECT_PREVIEW_MESSAGE_EMPTY,
    LEVEL_SELECT_PREVIEW_MESSAGE_NO_LOCAL_DATA = LEVEL_SELECT_PREVIEW_MESSAGE_NO_LOCAL_DATA,
    LEVEL_SELECT_PREVIEW_DISPLAY_SWAP_DELAY_FRAMES = LEVEL_SELECT_PREVIEW_DISPLAY_SWAP_DELAY_FRAMES,
    LEVEL_SELECT_MODE_LIBRARY = LEVEL_SELECT_MODE_LIBRARY,
    LEVEL_SELECT_MODE_MARKETPLACE = LEVEL_SELECT_MODE_MARKETPLACE,
    LEVEL_SELECT_MARKETPLACE_TAB_TOP = LEVEL_SELECT_MARKETPLACE_TAB_TOP,
    LEVEL_SELECT_MARKETPLACE_TAB_RANDOM = LEVEL_SELECT_MARKETPLACE_TAB_RANDOM,
    LEVEL_SELECT_MARKETPLACE_TAB_SEARCH = LEVEL_SELECT_MARKETPLACE_TAB_SEARCH,
    LEVEL_SELECT_MARKETPLACE_SEARCH_MAX_LENGTH = LEVEL_SELECT_MARKETPLACE_SEARCH_MAX_LENGTH,
    LEVEL_SELECT_MARKETPLACE_TAB_ORDER = LEVEL_SELECT_MARKETPLACE_TAB_ORDER,
    LEVEL_SELECT_MARKETPLACE_SOURCE_FAVORITES = LEVEL_SELECT_MARKETPLACE_SOURCE_FAVORITES,
    LEVEL_SELECT_MARKETPLACE_SOURCE_SEARCH = LEVEL_SELECT_MARKETPLACE_SOURCE_SEARCH,
    LEVEL_SELECT_MARKETPLACE_SCOPE_FAVORITES = LEVEL_SELECT_MARKETPLACE_SCOPE_FAVORITES,
    LEVEL_SELECT_MARKETPLACE_SCOPE_SEARCH_PREFIX = LEVEL_SELECT_MARKETPLACE_SCOPE_SEARCH_PREFIX,
    LEVEL_SELECT_MARKETPLACE_REMOTE_LIMIT = LEVEL_SELECT_MARKETPLACE_REMOTE_LIMIT,
    LEVEL_SELECT_MARKETPLACE_FETCH_TIMEOUT_SECONDS = LEVEL_SELECT_MARKETPLACE_FETCH_TIMEOUT_SECONDS,
    LEVEL_SELECT_MARKETPLACE_CACHE_DURATION_SECONDS = LEVEL_SELECT_MARKETPLACE_CACHE_DURATION_SECONDS,
    LEVEL_SELECT_MARKETPLACE_STATUS_IDLE = LEVEL_SELECT_MARKETPLACE_STATUS_IDLE,
    LEVEL_SELECT_MARKETPLACE_STATUS_LOADING = LEVEL_SELECT_MARKETPLACE_STATUS_LOADING,
    LEVEL_SELECT_MARKETPLACE_STATUS_READY = LEVEL_SELECT_MARKETPLACE_STATUS_READY,
    LEVEL_SELECT_MARKETPLACE_STATUS_ERROR = LEVEL_SELECT_MARKETPLACE_STATUS_ERROR,
    LEVEL_SELECT_MARKETPLACE_STATUS_DISABLED = LEVEL_SELECT_MARKETPLACE_STATUS_DISABLED,
    LEVEL_SELECT_MARKETPLACE_MESSAGE_LOADING = LEVEL_SELECT_MARKETPLACE_MESSAGE_LOADING,
    LEVEL_SELECT_MARKETPLACE_MESSAGE_EMPTY_SEARCH = LEVEL_SELECT_MARKETPLACE_MESSAGE_EMPTY_SEARCH,
    LEVEL_SELECT_MARKETPLACE_MESSAGE_FETCH_FAILED = LEVEL_SELECT_MARKETPLACE_MESSAGE_FETCH_FAILED,
    ONLINE_WRITE_TIMEOUT_SECONDS = ONLINE_WRITE_TIMEOUT_SECONDS,
    MARKETPLACE_FAVORITE_ANIMATION_DURATION_SECONDS = MARKETPLACE_FAVORITE_ANIMATION_DURATION_SECONDS,
    MARKETPLACE_FAVORITE_OPTIMISTIC_DELTA = MARKETPLACE_FAVORITE_OPTIMISTIC_DELTA,
    LEVEL_SELECT_ACTION_STATUS_INFO = LEVEL_SELECT_ACTION_STATUS_INFO,
    LEVEL_SELECT_ACTION_STATUS_SUCCESS = LEVEL_SELECT_ACTION_STATUS_SUCCESS,
    LEVEL_SELECT_ACTION_STATUS_ERROR = LEVEL_SELECT_ACTION_STATUS_ERROR,
    PLAY_MODE_ONLINE = PLAY_MODE_ONLINE,
    PLAY_MODE_OFFLINE = PLAY_MODE_OFFLINE,
    MAP_CATEGORY_ONLINE = MAP_CATEGORY_ONLINE,
    PROFILE_NAME_MAX_LENGTH = PROFILE_NAME_MAX_LENGTH,
    PLAY_GUIDE_SHRINK_DURATION = PLAY_GUIDE_SHRINK_DURATION,
    PLAY_GUIDE_MOVE_DURATION = PLAY_GUIDE_MOVE_DURATION,
    PLAY_GUIDE_GROW_DURATION = PLAY_GUIDE_GROW_DURATION,
    SIMPLE_BEGINNING_GUIDE_MAP_UUID = SIMPLE_BEGINNING_GUIDE_MAP_UUID,
    TWO_CROSSINGS_GUIDE_MAP_UUID = TWO_CROSSINGS_GUIDE_MAP_UUID,
    SIMPLE_BEGINNING_GUIDE_STEPS = SIMPLE_BEGINNING_GUIDE_STEPS,
    TWO_CROSSINGS_GUIDE_STEPS = TWO_CROSSINGS_GUIDE_STEPS,
    PLAY_GUIDE_STEPS_BY_MAP_UUID = PLAY_GUIDE_STEPS_BY_MAP_UUID,
    LEADERBOARD_REFRESH_LABEL_LOCAL_ONLY = LEADERBOARD_REFRESH_LABEL_LOCAL_ONLY,
    LEADERBOARD_MESSAGE_NO_LOCAL_SCORES = LEADERBOARD_MESSAGE_NO_LOCAL_SCORES,
    LEVEL_SELECT_PREVIEW_MESSAGE_NO_LOCAL_BEST = LEVEL_SELECT_PREVIEW_MESSAGE_NO_LOCAL_BEST,
    LEVEL_SELECT_PREVIEW_TITLE_PERSONAL_BEST = LEVEL_SELECT_PREVIEW_TITLE_PERSONAL_BEST,
    LEADERBOARD_TITLE_ONLINE = LEADERBOARD_TITLE_ONLINE,
    LEADERBOARD_TITLE_PERSONAL = LEADERBOARD_TITLE_PERSONAL,
    LEADERBOARD_TITLE_MAP = LEADERBOARD_TITLE_MAP,
    LEADERBOARD_TITLE_MAP_PERSONAL = LEADERBOARD_TITLE_MAP_PERSONAL,
    RESULTS_MESSAGE_LOCAL_BEST_SAVED = RESULTS_MESSAGE_LOCAL_BEST_SAVED,
    RESULTS_MESSAGE_LOCAL_BEST_KEPT = RESULTS_MESSAGE_LOCAL_BEST_KEPT,
    RESULTS_MESSAGE_LOCAL_SAVE_FAILED = RESULTS_MESSAGE_LOCAL_SAVE_FAILED,
    LEVEL_SELECT_UPLOAD_ENV_REQUIRED_MESSAGE = LEVEL_SELECT_UPLOAD_ENV_REQUIRED_MESSAGE,
    NETWORK_REQUEST_LOG_MAX_ENTRIES = NETWORK_REQUEST_LOG_MAX_ENTRIES,
    getNowSeconds = getNowSeconds,
    getNowUnixSeconds = getNowUnixSeconds,
    drainChannel = drainChannel,
    findLevelSelectIndex = findLevelSelectIndex,
    closestWrappedIndex = closestWrappedIndex,
    normalizeWrappedIndex = normalizeWrappedIndex,
    trim = trim,
    trimLastUtf8Character = trimLastUtf8Character,
    getProfilePlayerUuid = getProfilePlayerUuid,
    getProfilePlayMode = getProfilePlayMode,
    deepCopy = deepCopy,
    normalizeLeaderboardEntry = normalizeLeaderboardEntry,
    normalizeLeaderboardEntries = normalizeLeaderboardEntries,
    getLeaderboardScopeKey = getLeaderboardScopeKey,
    describeConfigSource = describeConfigSource,
    logOnlineConfig = logOnlineConfig,
    getLeaderboardUnavailableMessage = getLeaderboardUnavailableMessage,
    normalizeLeaderboardErrorMessage = normalizeLeaderboardErrorMessage,
    buildLevelSelectPreviewCacheEntry = buildLevelSelectPreviewCacheEntry,
}

require("src.game.app.game_remote_services")(Game, shared)
require("src.game.app.game_profile_and_results")(Game, shared)
require("src.game.app.game_screen_flow")(Game, shared)
require("src.game.app.game_runtime_handlers")(Game, shared)

return Game
