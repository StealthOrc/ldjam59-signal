local input = require("src.game.input")
local mapEditor = require("src.game.map_editor")
local mapStorage = require("src.game.map_storage")
local localScoreStorage = require("src.game.local_score_storage")
local profileStorage = require("src.game.profile_storage")
local leaderboardClient = require("src.game.leaderboard_client")
local leaderboardPreviewCache = require("src.game.leaderboard_preview_cache")
local levelSelectPreviewLogic = require("src.game.level_select_preview_logic")
local levelSelectSelection = require("src.game.level_select_selection")
local marketplaceFavoriteLogic = require("src.game.marketplace_favorite_logic")
local refreshIndicatorLogic = require("src.game.refresh_indicator_logic")
local world = require("src.game.world")
local ui = require("src.game.ui")
local json = require("src.game.json")

local Game = {}
Game.__index = Game
local ONLINE_CONFIG_LOG_PREFIX = "[Leaderboard]"
local LEADERBOARD_CACHE_DURATION_SECONDS = 60
local LEADERBOARD_FETCH_TIMEOUT_SECONDS = 5
local LEADERBOARD_ENTRY_LIMIT = 50
local LEADERBOARD_THREAD_FILE = "src/game/leaderboard_fetch_thread.lua"
local LEADERBOARD_REQUEST_CHANNEL_NAME = "signal_leaderboard_request"
local LEADERBOARD_RESPONSE_CHANNEL_NAME = "signal_leaderboard_response"
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
        playerDisplayName = entry.display_name or "Unknown",
        playerUuid = entry.player_uuid or "",
        mapCount = tonumber(entry.map_count) or 0,
        score = tonumber(entry.score or 0) or 0,
        rank = tonumber(entry.rank) or fallbackRank or 0,
        mapUuid = entry.map_uuid or entry.last_map_uuid or fallbackMapUuid,
        recordedAt = entry.recorded_at or entry.updated_at,
        updatedAt = entry.updated_at,
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

    self.profile = profile
    self.localScoreboard = localScoreStorage.load()
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
    self.activeScoreSubmitRequestId = nil
    self.activeScoreSubmitRequestStartedAt = nil
    self.resultsSummary = nil
    self.resultsOnlineState = nil
    self.profileSetupNameBuffer = profile.playerDisplayName or ""
    self.profileSetupError = nil
    self.profileModeSelection = getProfilePlayMode(profile) ~= "" and getProfilePlayMode(profile) or PLAY_MODE_OFFLINE
    self.profileModeHoverId = nil
    self.profileModeSetupError = nil
    self.playOverlayMode = nil
    self.playGuide = nil
    self.playGuideTransition = nil
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
    drainChannel(self.leaderboardRequestChannel)
    drainChannel(self.leaderboardResponseChannel)
    self.playPhase = nil
    self.playHoverInfo = nil
    self.resultsHoverInfo = nil

    self:updateRenderTransform()
    self:refreshMaps()

    return self
end

function Game:reloadOnlineConfig()
    local loadedConfig = leaderboardClient.getConfig()
    if loadedConfig.isConfigured or not (self.onlineConfig and self.onlineConfig.isConfigured) then
        self.onlineConfig = loadedConfig
    end
    return self.onlineConfig
end

function Game:getLeaderboardCacheEntry(scopeKey)
    local resolvedScopeKey = scopeKey or getLeaderboardScopeKey(self.leaderboardMapUuid)
    return self.leaderboardCacheByScope[resolvedScopeKey] or {
        payload = nil,
        fetchedAt = nil,
    }
end

function Game:setLeaderboardCacheEntry(scopeKey, payload, fetchedAt)
    self.leaderboardCacheByScope[scopeKey] = {
        payload = payload,
        fetchedAt = fetchedAt,
    }
end

function Game:getFilteredLeaderboardEntries(payload)
    local normalizedEntries = normalizeLeaderboardEntries(payload)

    for _, entry in ipairs(normalizedEntries) do
        entry.mapName = self:getMapNameByUuid(entry.mapUuid)
    end

    return normalizedEntries
end

function Game:buildLeaderboardState(status, message, rawEntries, fetchedAt)
    local filteredEntries = self:getFilteredLeaderboardEntries(rawEntries)
    local resolvedMessage = message
    local scopeKey = getLeaderboardScopeKey(self.leaderboardMapUuid)

    if status == LEADERBOARD_STATUS_READY and #filteredEntries == 0 then
        resolvedMessage = LEADERBOARD_MESSAGE_EMPTY
    end

    return {
        status = status,
        message = resolvedMessage,
        entries = filteredEntries,
        totalEntries = #filteredEntries,
        fetchedAt = fetchedAt,
        nextRefreshAt = refreshIndicatorLogic.getDisplayNextRefreshAt(
            fetchedAt,
            self.leaderboardNextFetchAtByScope[scopeKey],
            LEADERBOARD_CACHE_DURATION_SECONDS
        ),
        scope = type(rawEntries) == "table" and rawEntries.scope or (self.leaderboardMapUuid and LEADERBOARD_SCOPE_MAP or LEADERBOARD_SCOPE_GLOBAL),
        refreshLabel = type(rawEntries) == "table" and rawEntries.refreshLabel or nil,
    }
end

function Game:isLeaderboardCacheFresh()
    local cacheEntry = self:getLeaderboardCacheEntry()
    if not cacheEntry.payload or not cacheEntry.fetchedAt then
        return false
    end

    return (getNowSeconds() - cacheEntry.fetchedAt) < LEADERBOARD_CACHE_DURATION_SECONDS
end

function Game:isLeaderboardFetchAllowed()
    return getNowSeconds() >= (self.leaderboardNextFetchAtByScope[getLeaderboardScopeKey(self.leaderboardMapUuid)] or 0)
end

function Game:getActiveOnlineConfig()
    if not self:isOnlineMode() then
        return {
            isConfigured = false,
            errors = { "Offline mode is enabled." },
        }
    end

    local resolvedConfig = self:reloadOnlineConfig()
    if resolvedConfig and resolvedConfig.isConfigured then
        return resolvedConfig
    end

    if self.onlineConfig and self.onlineConfig.isConfigured then
        return self.onlineConfig
    end

    return resolvedConfig
end

function Game:isPlayModeConfigured()
    local playMode = getProfilePlayMode(self.profile)
    return playMode == PLAY_MODE_ONLINE or playMode == PLAY_MODE_OFFLINE
end

function Game:isOfflineMode()
    return getProfilePlayMode(self.profile) == PLAY_MODE_OFFLINE
end

function Game:isOnlineMode()
    return getProfilePlayMode(self.profile) == PLAY_MODE_ONLINE
end

function Game:getLeaderboardButtonLabel()
    if self:isOfflineMode() then
        return "Personal Scores"
    end

    return LEADERBOARD_TITLE_ONLINE
end

function Game:getLeaderboardTitle(mapUuid)
    if mapUuid and mapUuid ~= "" then
        if self:isOfflineMode() then
            return LEADERBOARD_TITLE_MAP_PERSONAL
        end

        return LEADERBOARD_TITLE_MAP
    end

    if self:isOfflineMode() then
        return LEADERBOARD_TITLE_PERSONAL
    end

    return LEADERBOARD_TITLE_ONLINE
end

function Game:getPlayModeButtonLabel()
    if self:isOfflineMode() then
        return "Mode: Offline"
    end

    return "Mode: Online"
end

function Game:getLocalScoreEntry(mapUuid)
    local resolvedMapUuid = tostring(mapUuid or "")
    if resolvedMapUuid == "" then
        return nil
    end

    local scoreboard = self.localScoreboard or {}
    local entriesByMap = scoreboard.entries_by_map or {}
    local entry = entriesByMap[resolvedMapUuid]

    if type(entry) ~= "table" then
        return nil
    end

    return entry
end

function Game:buildLocalLeaderboardEntry(mapUuid, scoreEntry, rank)
    if not mapUuid or mapUuid == "" or type(scoreEntry) ~= "table" then
        return nil
    end

    return {
        display_name = self.profile.playerDisplayName or "Unknown",
        player_uuid = getProfilePlayerUuid(self.profile),
        score = tonumber(scoreEntry.score or 0) or 0,
        rank = rank or 1,
        map_uuid = mapUuid,
        recorded_at = tonumber(scoreEntry.recorded_at or 0) or 0,
    }
end

function Game:buildLocalLeaderboardPayload(mapUuid)
    local latestRecordedAt = nil
    local payload = {
        entries = {},
        map_uuid = mapUuid,
        scope = mapUuid and LEADERBOARD_SCOPE_MAP or LEADERBOARD_SCOPE_GLOBAL,
        refreshLabel = LEADERBOARD_REFRESH_LABEL_LOCAL_ONLY,
    }

    if mapUuid and mapUuid ~= "" then
        local scoreEntry = self:getLocalScoreEntry(mapUuid)
        if not scoreEntry then
            return payload, nil
        end

        local localEntry = self:buildLocalLeaderboardEntry(mapUuid, scoreEntry, 1)
        payload.entries[1] = localEntry
        return payload, tonumber(scoreEntry.recorded_at or 0) or 0
    end

    local entriesByMap = self.localScoreboard and self.localScoreboard.entries_by_map or {}
    for entryMapUuid, scoreEntry in pairs(entriesByMap or {}) do
        local localEntry = self:buildLocalLeaderboardEntry(entryMapUuid, scoreEntry)
        if localEntry then
            payload.entries[#payload.entries + 1] = localEntry
            local recordedAt = tonumber(scoreEntry.recorded_at or 0) or 0
            if latestRecordedAt == nil or recordedAt > latestRecordedAt then
                latestRecordedAt = recordedAt
            end
        end
    end

    table.sort(payload.entries, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end

        local aRecordedAt = tonumber(a.recorded_at or 0) or 0
        local bRecordedAt = tonumber(b.recorded_at or 0) or 0
        if aRecordedAt ~= bRecordedAt then
            return aRecordedAt > bRecordedAt
        end

        return tostring(a.map_uuid or "") < tostring(b.map_uuid or "")
    end)

    for index, entry in ipairs(payload.entries) do
        entry.rank = index
    end

    return payload, latestRecordedAt
end

function Game:getLocalLevelSelectPreviewDisplayState(mapUuid)
    local localScoreEntry = self:getLocalScoreEntry(mapUuid)
    if not localScoreEntry then
        return {
            topEntries = {},
            pinnedPlayerEntry = nil,
            hasCache = false,
            showCachedEntries = true,
            isLoading = false,
            nextRefreshAt = nil,
            message = LEVEL_SELECT_PREVIEW_MESSAGE_NO_LOCAL_BEST,
            refreshLabel = LEADERBOARD_REFRESH_LABEL_LOCAL_ONLY,
            title = LEVEL_SELECT_PREVIEW_TITLE_PERSONAL_BEST,
        }
    end

    local localEntry = normalizeLeaderboardEntry(
        self:buildLocalLeaderboardEntry(mapUuid, localScoreEntry, 1),
        mapUuid,
        1
    )
    if localEntry then
        localEntry.mapName = self:getMapNameByUuid(localEntry.mapUuid)
    end

    return {
        topEntries = localEntry and { localEntry } or {},
        pinnedPlayerEntry = nil,
        hasCache = localEntry ~= nil,
        showCachedEntries = true,
        isLoading = false,
        nextRefreshAt = nil,
        message = localEntry and nil or LEVEL_SELECT_PREVIEW_MESSAGE_NO_LOCAL_BEST,
        refreshLabel = LEADERBOARD_REFRESH_LABEL_LOCAL_ONLY,
        title = LEVEL_SELECT_PREVIEW_TITLE_PERSONAL_BEST,
    }
end

function Game:updateLocalScoreboard(summary)
    local updatedScoreboard, isNewBest = localScoreStorage.updateBestScore(self.localScoreboard or {}, summary or {})
    self.localScoreboard = updatedScoreboard

    if not isNewBest then
        return true, false
    end

    local savedScoreboard, saveError = localScoreStorage.save(updatedScoreboard)
    if not savedScoreboard then
        return false, true, saveError
    end

    self.localScoreboard = savedScoreboard
    return true, true
end

function Game:clearOnlineRequestState()
    self.activeLeaderboardRequestId = nil
    self.activeLeaderboardRequestStartedAt = nil
    self.activeLeaderboardRequestScopeKey = nil
    self.activeLevelSelectPreviewRequestId = nil
    self.activeLevelSelectPreviewRequestStartedAt = nil
    self.activeLevelSelectPreviewRequestMapUuid = nil
    self.activeMarketplaceRequestId = nil
    self.activeMarketplaceRequestStartedAt = nil
    self.activeMarketplaceRequestScopeKey = nil
    self.activeFavoriteMapRequestId = nil
    self.activeFavoriteMapRequestStartedAt = nil
    self.activeFavoriteMapMapUuid = nil
    self.activeUploadMapRequestId = nil
    self.activeUploadMapRequestStartedAt = nil
    self.activeUploadMapDescriptor = nil
    self.activeScoreSubmitRequestId = nil
    self.activeScoreSubmitRequestStartedAt = nil
end

function Game:setPlayMode(playMode)
    if playMode ~= PLAY_MODE_ONLINE and playMode ~= PLAY_MODE_OFFLINE then
        return false, "Select online or offline mode before continuing."
    end

    local previousPlayMode = self.profile.playMode
    self.profile.playMode = playMode
    local ok, saveError = self:saveProfile()
    if not ok then
        self.profile.playMode = previousPlayMode
        return false, saveError or "The play mode could not be saved."
    end

    self.profileModeSelection = playMode
    self.profileModeSetupError = nil
    self:clearOnlineRequestState()
    self:clearLevelSelectLeaderboardFlip()
    if self:isOfflineMode() then
        self.levelSelectMode = LEVEL_SELECT_MODE_LIBRARY
    end
    return true
end

function Game:togglePlayMode()
    local nextPlayMode = self:isOfflineMode() and PLAY_MODE_ONLINE or PLAY_MODE_OFFLINE
    return self:setPlayMode(nextPlayMode)
end

function Game:setLevelSelectActionState(status, message, title)
    if not status or not message or message == "" then
        self.levelSelectActionState = nil
        return
    end

    self.levelSelectActionState = {
        status = status,
        message = message,
        title = title,
    }
end

function Game:clearLevelSelectActionState()
    self.levelSelectActionState = nil
end

function Game:openLevelSelectUploadDialog(payload, mapDescriptor)
    local resolvedPayload = type(payload) == "table" and payload or {}
    local resolvedMap = type(mapDescriptor) == "table" and mapDescriptor or {}
    local internalIdentifier = tostring(resolvedPayload.internal_identifier or resolvedPayload.internalIdentifier or "")
    local mapUuid = tostring(resolvedPayload.map_uuid or resolvedPayload.mapUuid or resolvedMap.mapUuid or "")
    local mapName = tostring(resolvedPayload.map_name or resolvedMap.displayName or resolvedMap.name or "")
    local mapId = internalIdentifier ~= "" and internalIdentifier or mapUuid

    self.levelSelectUploadDialog = {
        mapName = mapName,
        mapId = mapId,
        internalIdentifier = internalIdentifier,
        mapUuid = mapUuid,
        copyStatus = nil,
    }
end

function Game:closeLevelSelectUploadDialog()
    self.levelSelectUploadDialog = nil
end

function Game:copyLevelSelectUploadDialogId()
    local dialog = self.levelSelectUploadDialog
    if type(dialog) ~= "table" then
        return false, "No upload dialog is open."
    end

    local mapId = tostring(dialog.mapId or "")
    if mapId == "" then
        dialog.copyStatus = {
            status = LEVEL_SELECT_ACTION_STATUS_ERROR,
            message = "No map ID was returned for this upload.",
        }
        self.levelSelectUploadDialog = dialog
        return false, dialog.copyStatus.message
    end

    if not (love and love.system and love.system.setClipboardText) then
        dialog.copyStatus = {
            status = LEVEL_SELECT_ACTION_STATUS_ERROR,
            message = "Clipboard copy is not available here.",
        }
        self.levelSelectUploadDialog = dialog
        return false, dialog.copyStatus.message
    end

    local ok, copyError = pcall(love.system.setClipboardText, mapId)
    if not ok then
        dialog.copyStatus = {
            status = LEVEL_SELECT_ACTION_STATUS_ERROR,
            message = tostring(copyError or "The map ID could not be copied."),
        }
        self.levelSelectUploadDialog = dialog
        return false, dialog.copyStatus.message
    end

    dialog.copyStatus = {
        status = LEVEL_SELECT_ACTION_STATUS_SUCCESS,
        message = "Map ID copied to clipboard.",
    }
    self.levelSelectUploadDialog = dialog
    return true
end

function Game:getMarketplaceScopeDetails(tabId, query)
    local resolvedTabId = tabId or self.levelSelectMarketplaceTab or LEVEL_SELECT_MARKETPLACE_TAB_TOP
    local normalizedQuery = trim(query or self.levelSelectMarketplaceSearchQuery or "")

    if resolvedTabId == LEVEL_SELECT_MARKETPLACE_TAB_SEARCH then
        if normalizedQuery == "" then
            return {
                fetchMode = LEVEL_SELECT_MARKETPLACE_SOURCE_SEARCH,
                scopeKey = LEVEL_SELECT_MARKETPLACE_SCOPE_SEARCH_PREFIX,
                query = "",
                needsRequest = false,
            }
        end

        return {
            fetchMode = LEVEL_SELECT_MARKETPLACE_SOURCE_SEARCH,
            scopeKey = LEVEL_SELECT_MARKETPLACE_SCOPE_SEARCH_PREFIX .. string.lower(normalizedQuery),
            query = normalizedQuery,
            needsRequest = true,
        }
    end

    return {
        fetchMode = LEVEL_SELECT_MARKETPLACE_SOURCE_FAVORITES,
        scopeKey = LEVEL_SELECT_MARKETPLACE_SCOPE_FAVORITES,
        query = nil,
        needsRequest = true,
    }
end

function Game:getMarketplaceCacheEntry(scopeKey)
    local resolvedScopeKey = scopeKey or self:getMarketplaceScopeDetails().scopeKey
    return self.marketplaceCacheByScope[resolvedScopeKey] or {
        payload = nil,
        fetchedAt = nil,
    }
end

function Game:setMarketplaceCacheEntry(scopeKey, payload, fetchedAt)
    self.marketplaceCacheByScope[scopeKey] = {
        payload = payload,
        fetchedAt = fetchedAt,
    }
end

function Game:setMarketplaceState(scopeKey, status, message)
    self.marketplaceStateByScope[scopeKey] = {
        status = status or LEVEL_SELECT_MARKETPLACE_STATUS_IDLE,
        message = message,
    }
end

function Game:getMarketplaceViewState()
    local scopeDetails = self:getMarketplaceScopeDetails()
    local scopeKey = scopeDetails.scopeKey
    local state = self.marketplaceStateByScope[scopeKey]
    if state then
        return state
    end

    if scopeDetails.fetchMode == LEVEL_SELECT_MARKETPLACE_SOURCE_SEARCH and not scopeDetails.needsRequest then
        return {
            status = LEVEL_SELECT_MARKETPLACE_STATUS_IDLE,
            message = LEVEL_SELECT_MARKETPLACE_MESSAGE_EMPTY_SEARCH,
        }
    end

    return {
        status = LEVEL_SELECT_MARKETPLACE_STATUS_IDLE,
        message = nil,
    }
end

function Game:getMarketplaceEntries()
    local scopeDetails = self:getMarketplaceScopeDetails()
    if scopeDetails.fetchMode == LEVEL_SELECT_MARKETPLACE_SOURCE_SEARCH and not scopeDetails.needsRequest then
        return {}
    end

    local cacheEntry = self:getMarketplaceCacheEntry(scopeDetails.scopeKey)
    local payload = cacheEntry.payload
    if type(payload) ~= "table" or type(payload.entries) ~= "table" then
        return {}
    end

    return payload.entries
end

function Game:isMarketplaceCacheFresh(scopeKey)
    local cacheEntry = self:getMarketplaceCacheEntry(scopeKey)
    if not cacheEntry.payload or not cacheEntry.fetchedAt then
        return false
    end

    return (getNowSeconds() - cacheEntry.fetchedAt) < LEVEL_SELECT_MARKETPLACE_CACHE_DURATION_SECONDS
end

function Game:isMarketplaceFetchAllowed(scopeKey)
    return getNowSeconds() >= (self.marketplaceNextFetchAtByScope[scopeKey] or 0)
end

function Game:setLevelSelectPreviewState(mapUuid, status, message, options)
    local resolvedOptions = options or {}
    self.levelSelectPreviewState = {
        mapUuid = mapUuid,
        status = status or LEVEL_SELECT_PREVIEW_STATUS_IDLE,
        message = message,
        forceImmediateFetch = resolvedOptions.forceImmediateFetch or false,
        showCachedWhileLoading = resolvedOptions.showCachedWhileLoading or false,
        hasResolvedInitialRemoteAttempt = resolvedOptions.hasResolvedInitialRemoteAttempt or false,
        clearVisibleEntries = resolvedOptions.clearVisibleEntries or false,
        pendingPayload = resolvedOptions.pendingPayload,
        pendingFetchedAt = resolvedOptions.pendingFetchedAt,
        pendingDelayFrames = resolvedOptions.pendingDelayFrames or 0,
    }
end

local function buildLevelSelectPreviewCacheEntry(mapUuid, payload, fetchedAt)
    return {
        map_uuid = mapUuid,
        top_entries = type(payload.top_entries) == "table" and payload.top_entries or {},
        player_entry = type(payload.player_entry) == "table" and payload.player_entry or nil,
        target_rank = tonumber(payload.target_rank) or nil,
        fetched_at = fetchedAt,
    }
end

local function levelSelectPreviewPayloadHasData(payload)
    if type(payload) ~= "table" then
        return false
    end

    return #(payload.top_entries or {}) > 0 or type(payload.player_entry) == "table"
end

function Game:getLevelSelectPreviewCacheEntry(mapUuid)
    if not mapUuid or mapUuid == "" then
        return nil
    end

    local entry = self.levelSelectPreviewCacheByMap[mapUuid]
    if type(entry) ~= "table" then
        return nil
    end

    return entry
end

function Game:setLevelSelectPreviewCacheEntry(mapUuid, entry)
    if not mapUuid or mapUuid == "" then
        return
    end

    if type(entry) == "table" then
        self.levelSelectPreviewCacheByMap[mapUuid] = entry
    else
        self.levelSelectPreviewCacheByMap[mapUuid] = nil
    end

    leaderboardPreviewCache.save(self.levelSelectPreviewCacheByMap)
end

function Game:isLevelSelectPreviewCacheFresh(mapUuid)
    local cacheEntry = self:getLevelSelectPreviewCacheEntry(mapUuid)
    local fetchedAt = cacheEntry and tonumber(cacheEntry.fetched_at) or nil
    if not fetchedAt then
        return false
    end

    return (getNowUnixSeconds() - fetchedAt) < LEVEL_SELECT_PREVIEW_CACHE_DURATION_SECONDS
end

function Game:isLevelSelectPreviewFetchAllowed(mapUuid)
    if not mapUuid or mapUuid == "" then
        return false
    end

    return getNowUnixSeconds() >= (self.levelSelectPreviewNextFetchAtByMap[mapUuid] or 0)
end

function Game:getActiveLevelSelectPreviewMapUuid()
    if self.screen ~= "level_select" then
        return nil
    end

    local selectedMap = self:getSelectedLevelMap()
    local mapUuid = selectedMap and selectedMap.mapUuid or nil
    if mapUuid and mapUuid ~= "" and self.levelSelectLeaderboardFlipMapUuid == mapUuid then
        return mapUuid
    end

    return nil
end

function Game:clearLevelSelectLeaderboardFlip()
    self.levelSelectLeaderboardFlipMapUuid = nil
    self:setLevelSelectPreviewState(nil, LEVEL_SELECT_PREVIEW_STATUS_IDLE, nil)
end

function Game:getLevelSelectPreviewDisplayState(mapUuid)
    if self:isOfflineMode() then
        return self:getLocalLevelSelectPreviewDisplayState(mapUuid)
    end

    local cacheEntry = self:getLevelSelectPreviewCacheEntry(mapUuid)
    local previewState = self.levelSelectPreviewState or {}
    local shouldShowCachedEntries = levelSelectPreviewLogic.shouldShowCachedEntries(previewState, mapUuid, cacheEntry ~= nil)
    local topEntries = normalizeLeaderboardEntries({
        entries = shouldShowCachedEntries and cacheEntry and cacheEntry.top_entries or {},
        map_uuid = mapUuid,
    })
    local playerEntry = normalizeLeaderboardEntry(
        shouldShowCachedEntries and cacheEntry and cacheEntry.player_entry or nil,
        mapUuid
    )

    for _, entry in ipairs(topEntries) do
        entry.mapName = self:getMapNameByUuid(entry.mapUuid)
    end
    if playerEntry then
        playerEntry.mapName = self:getMapNameByUuid(playerEntry.mapUuid)
    end

    local pinnedPlayerEntry = nil
    if playerEntry then
        local isAlreadyVisible = false
        for _, entry in ipairs(topEntries) do
            if entry.playerUuid == playerEntry.playerUuid then
                isAlreadyVisible = true
                break
            end
        end

        if not isAlreadyVisible then
            pinnedPlayerEntry = playerEntry
        end
    end

    local hasCache = cacheEntry ~= nil
    local hasVisibleEntries = #topEntries > 0 or pinnedPlayerEntry ~= nil
    local isLoading = self.activeLevelSelectPreviewRequestId ~= nil and self.activeLevelSelectPreviewRequestMapUuid == mapUuid
    local shouldShowSpinner = isLoading or (previewState.mapUuid == mapUuid and previewState.status == LEVEL_SELECT_PREVIEW_STATUS_LOADING)
    local message = nil

    if shouldShowSpinner and not shouldShowCachedEntries then
        message = LEVEL_SELECT_PREVIEW_MESSAGE_LOADING
    elseif shouldShowCachedEntries and hasCache and not hasVisibleEntries and not playerEntry then
        message = LEVEL_SELECT_PREVIEW_MESSAGE_EMPTY
    elseif previewState.mapUuid == mapUuid and previewState.status == LEVEL_SELECT_PREVIEW_STATUS_ERROR and not shouldShowCachedEntries then
        message = previewState.message or LEVEL_SELECT_PREVIEW_MESSAGE_NO_LOCAL_DATA
    end

    return {
        topEntries = topEntries,
        pinnedPlayerEntry = pinnedPlayerEntry,
        hasCache = hasCache,
        showCachedEntries = shouldShowCachedEntries,
        isLoading = shouldShowSpinner,
        nextRefreshAt = refreshIndicatorLogic.getDisplayNextRefreshAtForVisibleData(
            hasVisibleEntries,
            shouldShowCachedEntries and tonumber(cacheEntry and cacheEntry.fetched_at) or nil,
            self.levelSelectPreviewNextFetchAtByMap[mapUuid],
            LEVEL_SELECT_PREVIEW_CACHE_DURATION_SECONDS
        ),
        message = message,
        refreshLabel = nil,
        title = "Leaderboard",
    }
end

function Game:updateLevelSelectPreviewCacheFromSubmit(response)
    if type(response) ~= "table" then
        return
    end

    local mapUuid = tostring(response.map_uuid or (self.resultsSummary and self.resultsSummary.mapUuid) or "")
    if mapUuid == "" then
        return
    end

    local submittedEntry = {
        display_name = response.display_name or self.profile.playerDisplayName or "Unknown",
        map_uuid = mapUuid,
        player_uuid = response.player_uuid or getProfilePlayerUuid(self.profile),
        rank = tonumber(response.rank) or nil,
        score = tonumber(response.score or 0) or 0,
        updated_at = response.updated_at,
    }

    local cacheEntry = self:getLevelSelectPreviewCacheEntry(mapUuid) or {
        map_uuid = mapUuid,
        top_entries = {},
        player_entry = nil,
        target_rank = nil,
        fetched_at = getNowUnixSeconds(),
    }

    local topEntries = {}
    for _, entry in ipairs(cacheEntry.top_entries or {}) do
        if type(entry) == "table" and tostring(entry.player_uuid or "") ~= submittedEntry.player_uuid then
            topEntries[#topEntries + 1] = entry
        end
    end

    if submittedEntry.rank and submittedEntry.rank <= LEVEL_SELECT_PREVIEW_ENTRY_LIMIT then
        topEntries[#topEntries + 1] = submittedEntry
        table.sort(topEntries, function(a, b)
            local aRank = tonumber(a.rank) or math.huge
            local bRank = tonumber(b.rank) or math.huge
            if aRank ~= bRank then
                return aRank < bRank
            end

            return tostring(a.player_uuid or "") < tostring(b.player_uuid or "")
        end)

        while #topEntries > LEVEL_SELECT_PREVIEW_ENTRY_LIMIT do
            table.remove(topEntries)
        end
    end

    cacheEntry.top_entries = topEntries
    cacheEntry.player_entry = submittedEntry
    cacheEntry.target_rank = submittedEntry.rank
    cacheEntry.fetched_at = getNowUnixSeconds()
    self:setLevelSelectPreviewCacheEntry(mapUuid, cacheEntry)
end

function Game:ensureLeaderboardWorker()
    local existingThread = self.leaderboardWorkerThread
    if existingThread and existingThread:isRunning() and not existingThread:getError() then
        return true
    end

    self.leaderboardWorkerThread = love.thread.newThread(LEADERBOARD_THREAD_FILE)
    self.leaderboardWorkerThread:start()
    return true
end

function Game:beginLeaderboardFetch(onlineConfig)
    if self.activeLeaderboardRequestId ~= nil then
        return
    end

    self:ensureLeaderboardWorker()
    local requestScopeKey = getLeaderboardScopeKey(self.leaderboardMapUuid)
    local cacheEntry = self:getLeaderboardCacheEntry(requestScopeKey)

    self.leaderboardState = self:buildLeaderboardState(
        LEADERBOARD_STATUS_LOADING,
        LEADERBOARD_MESSAGE_LOADING,
        cacheEntry.payload,
        cacheEntry.fetchedAt
    )

    self.leaderboardRequestSequence = self.leaderboardRequestSequence + 1
    self.activeLeaderboardRequestId = self.leaderboardRequestSequence
    self.activeLeaderboardRequestStartedAt = getNowSeconds()
    self.activeLeaderboardRequestScopeKey = requestScopeKey
    self.leaderboardRequestChannel:push(json.encode({
        kind = "fetch",
        requestId = self.activeLeaderboardRequestId,
        config = {
            apiKey = onlineConfig.apiKey,
            apiBaseUrl = onlineConfig.apiBaseUrl,
            limit = LEADERBOARD_ENTRY_LIMIT,
            mapUuid = self.leaderboardMapUuid,
        },
    }))
end

function Game:beginLevelSelectPreviewFetch(onlineConfig, mapUuid)
    if self.activeLevelSelectPreviewRequestId ~= nil or not mapUuid or mapUuid == "" then
        return
    end

    self:ensureLeaderboardWorker()
    local cacheEntry = self:getLevelSelectPreviewCacheEntry(mapUuid)
    local previewState = self.levelSelectPreviewState or {}
    local showCachedWhileLoading = previewState.mapUuid == mapUuid
        and previewState.hasResolvedInitialRemoteAttempt
        and cacheEntry ~= nil
    self.levelSelectPreviewRequestSequence = self.levelSelectPreviewRequestSequence + 1
    self.activeLevelSelectPreviewRequestId = self.levelSelectPreviewRequestSequence
    self.activeLevelSelectPreviewRequestStartedAt = getNowSeconds()
    self.activeLevelSelectPreviewRequestMapUuid = mapUuid
    self:setLevelSelectPreviewState(mapUuid, LEVEL_SELECT_PREVIEW_STATUS_LOADING, nil, {
        forceImmediateFetch = false,
        showCachedWhileLoading = showCachedWhileLoading,
        hasResolvedInitialRemoteAttempt = previewState.mapUuid == mapUuid and previewState.hasResolvedInitialRemoteAttempt or false,
    })
    self.leaderboardRequestChannel:push(json.encode({
        kind = "preview",
        requestId = self.activeLevelSelectPreviewRequestId,
        config = {
            apiKey = onlineConfig.apiKey,
            apiBaseUrl = onlineConfig.apiBaseUrl,
            limit = LEVEL_SELECT_PREVIEW_ENTRY_LIMIT,
            mapUuid = mapUuid,
            player_uuid = getProfilePlayerUuid(self.profile),
        },
    }))
end

function Game:applyLeaderboardFetchResult(response)
    local requestScopeKey = self.activeLeaderboardRequestScopeKey or getLeaderboardScopeKey(self.leaderboardMapUuid)
    local cacheEntry = self:getLeaderboardCacheEntry(requestScopeKey)
    if response.ok and type(response.payload) == "table" then
        local fetchedAt = getNowSeconds()
        self:setLeaderboardCacheEntry(requestScopeKey, response.payload, fetchedAt)
        self.leaderboardNextFetchAtByScope[requestScopeKey] = fetchedAt + LEADERBOARD_CACHE_DURATION_SECONDS
        if requestScopeKey == getLeaderboardScopeKey(self.leaderboardMapUuid) then
            self.leaderboardState = self:buildLeaderboardState(LEADERBOARD_STATUS_READY, nil, response.payload, fetchedAt)
        end
        return
    end

    self.leaderboardNextFetchAtByScope[requestScopeKey] = getNowSeconds() + LEADERBOARD_CACHE_DURATION_SECONDS
    local fetchMessage = normalizeLeaderboardErrorMessage(response.error)
    if requestScopeKey == getLeaderboardScopeKey(self.leaderboardMapUuid) then
        self.leaderboardState = self:buildLeaderboardState(
            LEADERBOARD_STATUS_ERROR,
            fetchMessage,
            cacheEntry.payload,
            cacheEntry.fetchedAt
        )
    end
end

function Game:applyLevelSelectPreviewFetchResult(response, mapUuid)
    if not mapUuid or mapUuid == "" then
        return
    end

    local cacheEntry = self:getLevelSelectPreviewCacheEntry(mapUuid)
    local previewState = self.levelSelectPreviewState or {}
    if response.ok and type(response.payload) == "table" then
        local fetchedAt = getNowUnixSeconds()
        local payloadToPersist = levelSelectPreviewLogic.getPayloadToPersistAfterFetch(response.payload, cacheEntry)
        self.levelSelectPreviewNextFetchAtByMap[mapUuid] = fetchedAt + LEVEL_SELECT_PREVIEW_CACHE_DURATION_SECONDS
        if not levelSelectPreviewPayloadHasData(response.payload) and cacheEntry ~= nil then
            self:setLevelSelectPreviewCacheEntry(mapUuid, buildLevelSelectPreviewCacheEntry(mapUuid, payloadToPersist, fetchedAt))
            self:setLevelSelectPreviewState(mapUuid, LEVEL_SELECT_PREVIEW_STATUS_READY, nil, {
                hasResolvedInitialRemoteAttempt = true,
            })
            return
        end

        if previewState.mapUuid == mapUuid and previewState.showCachedWhileLoading and cacheEntry ~= nil then
            self:setLevelSelectPreviewState(mapUuid, LEVEL_SELECT_PREVIEW_STATUS_LOADING, nil, {
                hasResolvedInitialRemoteAttempt = true,
                clearVisibleEntries = true,
                pendingPayload = response.payload,
                pendingFetchedAt = fetchedAt,
                pendingDelayFrames = LEVEL_SELECT_PREVIEW_DISPLAY_SWAP_DELAY_FRAMES,
            })
            return
        end

        self:setLevelSelectPreviewCacheEntry(mapUuid, buildLevelSelectPreviewCacheEntry(mapUuid, payloadToPersist, fetchedAt))
        self:setLevelSelectPreviewState(mapUuid, LEVEL_SELECT_PREVIEW_STATUS_READY, nil, {
            hasResolvedInitialRemoteAttempt = true,
        })
        return
    end

    self.levelSelectPreviewNextFetchAtByMap[mapUuid] = getNowUnixSeconds() + LEVEL_SELECT_PREVIEW_CACHE_DURATION_SECONDS
    if cacheEntry then
        self:setLevelSelectPreviewState(mapUuid, LEVEL_SELECT_PREVIEW_STATUS_READY, nil, {
            hasResolvedInitialRemoteAttempt = true,
        })
        return
    end

    self:setLevelSelectPreviewState(mapUuid, LEVEL_SELECT_PREVIEW_STATUS_ERROR, LEVEL_SELECT_PREVIEW_MESSAGE_NO_LOCAL_DATA, {
        hasResolvedInitialRemoteAttempt = true,
    })
end

function Game:beginMarketplaceFetch(onlineConfig, scopeDetails)
    if self.activeMarketplaceRequestId ~= nil or not scopeDetails or not scopeDetails.needsRequest then
        return
    end

    self:ensureLeaderboardWorker()
    local scopeKey = scopeDetails.scopeKey
    self.marketplaceRequestSequence = self.marketplaceRequestSequence + 1
    self.activeMarketplaceRequestId = self.marketplaceRequestSequence
    self.activeMarketplaceRequestStartedAt = getNowSeconds()
    self.activeMarketplaceRequestScopeKey = scopeKey
    self:setMarketplaceState(scopeKey, LEVEL_SELECT_MARKETPLACE_STATUS_LOADING, LEVEL_SELECT_MARKETPLACE_MESSAGE_LOADING)
    self.leaderboardRequestChannel:push(json.encode({
        kind = "marketplace",
        requestId = self.activeMarketplaceRequestId,
        config = {
            apiKey = onlineConfig.apiKey,
            apiBaseUrl = onlineConfig.apiBaseUrl,
            mode = scopeDetails.fetchMode,
            player_uuid = getProfilePlayerUuid(self.profile),
            query = scopeDetails.query,
            limit = LEVEL_SELECT_MARKETPLACE_REMOTE_LIMIT,
        },
    }))
end

function Game:beginFavoriteMapRequest(onlineConfig, mapUuid, likedByPlayer)
    if self.activeFavoriteMapRequestId ~= nil then
        return false
    end

    self:ensureLeaderboardWorker()
    self.remoteWriteRequestSequence = self.remoteWriteRequestSequence + 1
    self.activeFavoriteMapRequestId = self.remoteWriteRequestSequence
    self.activeFavoriteMapRequestStartedAt = getNowSeconds()
    self.activeFavoriteMapMapUuid = mapUuid
    self.leaderboardRequestChannel:push(json.encode({
        kind = "favorite_map",
        requestId = self.activeFavoriteMapRequestId,
        config = {
            apiKey = onlineConfig.apiKey,
            apiBaseUrl = onlineConfig.apiBaseUrl,
            hmacSecret = onlineConfig.hmacSecret,
            mapUuid = mapUuid,
            mode = "favorite_map",
            liked = likedByPlayer == true,
            player_uuid = getProfilePlayerUuid(self.profile),
        },
    }))
    return true
end

function Game:beginUploadMapRequest(onlineConfig, mapData, selectedMap)
    if self.activeUploadMapRequestId ~= nil then
        return false
    end

    self:ensureLeaderboardWorker()
    self.remoteWriteRequestSequence = self.remoteWriteRequestSequence + 1
    self.activeUploadMapRequestId = self.remoteWriteRequestSequence
    self.activeUploadMapRequestStartedAt = getNowSeconds()
    self.activeUploadMapDescriptor = selectedMap and {
        mapUuid = selectedMap.mapUuid,
        displayName = selectedMap.displayName,
        name = selectedMap.name,
    } or nil
    self.leaderboardRequestChannel:push(json.encode({
        kind = "upload_map",
        requestId = self.activeUploadMapRequestId,
        config = {
            apiKey = onlineConfig.apiKey,
            apiBaseUrl = onlineConfig.apiBaseUrl,
            creator_uuid = getProfilePlayerUuid(self.profile),
            hmacSecret = onlineConfig.hmacSecret,
            map = deepCopy(mapData.level),
            mapCategory = MAP_CATEGORY_ONLINE,
            mapName = mapData.name or selectedMap.displayName or selectedMap.name,
            playerDisplayName = self.profile and self.profile.playerDisplayName or "",
            mapUuid = mapData.mapUuid or selectedMap.mapUuid,
            mode = "upload_map",
        },
    }))
    return true
end

function Game:beginScoreSubmitRequest(onlineConfig, summary)
    if self.activeScoreSubmitRequestId ~= nil then
        return false
    end

    self:ensureLeaderboardWorker()
    self.remoteWriteRequestSequence = self.remoteWriteRequestSequence + 1
    self.activeScoreSubmitRequestId = self.remoteWriteRequestSequence
    self.activeScoreSubmitRequestStartedAt = getNowSeconds()
    self.leaderboardRequestChannel:push(json.encode({
        kind = "score_submit",
        requestId = self.activeScoreSubmitRequestId,
        config = {
            apiKey = onlineConfig.apiKey,
            apiBaseUrl = onlineConfig.apiBaseUrl,
            hmacSecret = onlineConfig.hmacSecret,
            mapUuid = summary.mapUuid,
            mode = "score_submit",
            playerDisplayName = self.profile.playerDisplayName,
            player_uuid = getProfilePlayerUuid(self.profile),
            score = summary.finalScore or 0,
        },
    }))
    return true
end

function Game:applyMarketplaceFetchResult(response, scopeKey)
    if not scopeKey or scopeKey == "" then
        return
    end

    if response.ok and type(response.payload) == "table" then
        local fetchedAt = getNowSeconds()
        self:setMarketplaceCacheEntry(scopeKey, response.payload, fetchedAt)
        self.marketplaceNextFetchAtByScope[scopeKey] = fetchedAt + LEVEL_SELECT_MARKETPLACE_CACHE_DURATION_SECONDS
        self:setMarketplaceState(scopeKey, LEVEL_SELECT_MARKETPLACE_STATUS_READY, nil)
        return
    end

    self.marketplaceNextFetchAtByScope[scopeKey] = getNowSeconds() + LEVEL_SELECT_MARKETPLACE_CACHE_DURATION_SECONDS
    self:setMarketplaceState(
        scopeKey,
        LEVEL_SELECT_MARKETPLACE_STATUS_ERROR,
        response.error or LEVEL_SELECT_MARKETPLACE_MESSAGE_FETCH_FAILED
    )
end

function Game:applyPendingLevelSelectPreviewSwap()
    local previewState = self.levelSelectPreviewState or {}
    if not previewState.pendingPayload or not previewState.mapUuid or previewState.mapUuid == "" then
        return false
    end

    if (previewState.pendingDelayFrames or 0) > 0 then
        previewState.pendingDelayFrames = previewState.pendingDelayFrames - 1
        if previewState.pendingDelayFrames > 0 then
            self.levelSelectPreviewState = previewState
            return false
        end
    end

    local mapUuid = previewState.mapUuid
    local fetchedAt = tonumber(previewState.pendingFetchedAt) or getNowUnixSeconds()
    self:setLevelSelectPreviewCacheEntry(mapUuid, buildLevelSelectPreviewCacheEntry(mapUuid, previewState.pendingPayload, fetchedAt))
    self:setLevelSelectPreviewState(mapUuid, LEVEL_SELECT_PREVIEW_STATUS_READY, nil, {
        hasResolvedInitialRemoteAttempt = true,
    })
    return true
end

function Game:updateLeaderboardFetchState()
    self:applyPendingLevelSelectPreviewSwap()

    local requestScopeKey = self.activeLeaderboardRequestScopeKey or getLeaderboardScopeKey(self.leaderboardMapUuid)
    local cacheEntry = self:getLeaderboardCacheEntry(requestScopeKey)
    local activePreviewMapUuid = self.activeLevelSelectPreviewRequestMapUuid
    local previewCacheEntry = self:getLevelSelectPreviewCacheEntry(activePreviewMapUuid)
    local marketplaceScopeKey = self.activeMarketplaceRequestScopeKey
    local activeFavoriteMapUuid = self.activeFavoriteMapMapUuid

    if self.leaderboardWorkerThread and (
        self.activeLeaderboardRequestId ~= nil
        or self.activeLevelSelectPreviewRequestId ~= nil
        or self.activeMarketplaceRequestId ~= nil
        or self.activeFavoriteMapRequestId ~= nil
        or self.activeUploadMapRequestId ~= nil
        or self.activeScoreSubmitRequestId ~= nil
    ) then
        local threadError = self.leaderboardWorkerThread:getError()
        if threadError then
            if self.activeLeaderboardRequestId ~= nil then
                self.activeLeaderboardRequestId = nil
                self.activeLeaderboardRequestStartedAt = nil
                self.leaderboardNextFetchAtByScope[requestScopeKey] = getNowSeconds() + LEADERBOARD_CACHE_DURATION_SECONDS
                if requestScopeKey == getLeaderboardScopeKey(self.leaderboardMapUuid) then
                    self.leaderboardState = self:buildLeaderboardState(
                        LEADERBOARD_STATUS_ERROR,
                        threadError,
                        cacheEntry.payload,
                        cacheEntry.fetchedAt
                    )
                end
                self.activeLeaderboardRequestScopeKey = nil
            end

            if self.activeLevelSelectPreviewRequestId ~= nil then
                self.activeLevelSelectPreviewRequestId = nil
                self.activeLevelSelectPreviewRequestStartedAt = nil
                if activePreviewMapUuid and activePreviewMapUuid ~= "" then
                    self.levelSelectPreviewNextFetchAtByMap[activePreviewMapUuid] = getNowUnixSeconds() + LEVEL_SELECT_PREVIEW_CACHE_DURATION_SECONDS
                    if previewCacheEntry then
                        self:setLevelSelectPreviewState(activePreviewMapUuid, LEVEL_SELECT_PREVIEW_STATUS_READY, nil, {
                            hasResolvedInitialRemoteAttempt = true,
                        })
                    else
                        self:setLevelSelectPreviewState(activePreviewMapUuid, LEVEL_SELECT_PREVIEW_STATUS_ERROR, LEVEL_SELECT_PREVIEW_MESSAGE_NO_LOCAL_DATA, {
                            hasResolvedInitialRemoteAttempt = true,
                        })
                    end
                end
                self.activeLevelSelectPreviewRequestMapUuid = nil
            end

            if self.activeMarketplaceRequestId ~= nil then
                self.activeMarketplaceRequestId = nil
                self.activeMarketplaceRequestStartedAt = nil
                if marketplaceScopeKey and marketplaceScopeKey ~= "" then
                    self.marketplaceNextFetchAtByScope[marketplaceScopeKey] = getNowSeconds() + LEVEL_SELECT_MARKETPLACE_CACHE_DURATION_SECONDS
                    self:setMarketplaceState(marketplaceScopeKey, LEVEL_SELECT_MARKETPLACE_STATUS_ERROR, threadError)
                end
                self.activeMarketplaceRequestScopeKey = nil
            end

            if self.activeFavoriteMapRequestId ~= nil then
                self:failMarketplaceFavoriteRequest(threadError)
            end

            if self.activeUploadMapRequestId ~= nil then
                self.activeUploadMapRequestId = nil
                self.activeUploadMapRequestStartedAt = nil
                self.activeUploadMapDescriptor = nil
                self:setLevelSelectActionState(LEVEL_SELECT_ACTION_STATUS_ERROR, threadError, "Upload failed")
            end

            if self.activeScoreSubmitRequestId ~= nil then
                self.activeScoreSubmitRequestId = nil
                self.activeScoreSubmitRequestStartedAt = nil
                self.resultsOnlineState = {
                    status = "error",
                    message = threadError,
                }
            end

            self.leaderboardWorkerThread = nil
            return
        end
    end

    if self.activeLeaderboardRequestId ~= nil and self.activeLeaderboardRequestStartedAt ~= nil then
        local elapsedSeconds = getNowSeconds() - self.activeLeaderboardRequestStartedAt
        if elapsedSeconds >= LEADERBOARD_FETCH_TIMEOUT_SECONDS then
            self.activeLeaderboardRequestId = nil
            self.activeLeaderboardRequestStartedAt = nil
            self.leaderboardNextFetchAtByScope[requestScopeKey] = getNowSeconds() + LEADERBOARD_CACHE_DURATION_SECONDS
            local hasCachedEntries = cacheEntry.payload ~= nil
            if requestScopeKey == getLeaderboardScopeKey(self.leaderboardMapUuid) then
                self.leaderboardState = self:buildLeaderboardState(
                    hasCachedEntries and LEADERBOARD_STATUS_READY or LEADERBOARD_STATUS_ERROR,
                    hasCachedEntries and nil or LEADERBOARD_MESSAGE_NO_DATA,
                    cacheEntry.payload,
                    cacheEntry.fetchedAt
                )
            end
            self.activeLeaderboardRequestScopeKey = nil
            return
        end
    end

    if self.activeLevelSelectPreviewRequestId ~= nil and self.activeLevelSelectPreviewRequestStartedAt ~= nil then
        local elapsedSeconds = getNowSeconds() - self.activeLevelSelectPreviewRequestStartedAt
        if elapsedSeconds >= LEVEL_SELECT_PREVIEW_FETCH_TIMEOUT_SECONDS then
            local previewMapUuid = self.activeLevelSelectPreviewRequestMapUuid
            self.activeLevelSelectPreviewRequestId = nil
            self.activeLevelSelectPreviewRequestStartedAt = nil
            if previewMapUuid and previewMapUuid ~= "" then
                self.levelSelectPreviewNextFetchAtByMap[previewMapUuid] = getNowUnixSeconds() + LEVEL_SELECT_PREVIEW_CACHE_DURATION_SECONDS
                if self:getLevelSelectPreviewCacheEntry(previewMapUuid) then
                    self:setLevelSelectPreviewState(previewMapUuid, LEVEL_SELECT_PREVIEW_STATUS_READY, nil, {
                        hasResolvedInitialRemoteAttempt = true,
                    })
                else
                    self:setLevelSelectPreviewState(previewMapUuid, LEVEL_SELECT_PREVIEW_STATUS_ERROR, LEVEL_SELECT_PREVIEW_MESSAGE_NO_LOCAL_DATA, {
                        hasResolvedInitialRemoteAttempt = true,
                    })
                end
            end
            self.activeLevelSelectPreviewRequestMapUuid = nil
        end
    end

    if self.activeMarketplaceRequestId ~= nil and self.activeMarketplaceRequestStartedAt ~= nil then
        local elapsedSeconds = getNowSeconds() - self.activeMarketplaceRequestStartedAt
        if elapsedSeconds >= LEVEL_SELECT_MARKETPLACE_FETCH_TIMEOUT_SECONDS then
            local timedOutScopeKey = self.activeMarketplaceRequestScopeKey
            self.activeMarketplaceRequestId = nil
            self.activeMarketplaceRequestStartedAt = nil
            if timedOutScopeKey and timedOutScopeKey ~= "" then
                self.marketplaceNextFetchAtByScope[timedOutScopeKey] = getNowSeconds() + LEVEL_SELECT_MARKETPLACE_CACHE_DURATION_SECONDS
                self:setMarketplaceState(timedOutScopeKey, LEVEL_SELECT_MARKETPLACE_STATUS_ERROR, LEVEL_SELECT_MARKETPLACE_MESSAGE_FETCH_FAILED)
            end
            self.activeMarketplaceRequestScopeKey = nil
        end
    end

    if self.activeFavoriteMapRequestId ~= nil and self.activeFavoriteMapRequestStartedAt ~= nil then
        local elapsedSeconds = getNowSeconds() - self.activeFavoriteMapRequestStartedAt
        if elapsedSeconds >= ONLINE_WRITE_TIMEOUT_SECONDS then
            self:failMarketplaceFavoriteRequest("The like request timed out.")
        end
    end

    if self.activeUploadMapRequestId ~= nil and self.activeUploadMapRequestStartedAt ~= nil then
        local elapsedSeconds = getNowSeconds() - self.activeUploadMapRequestStartedAt
        if elapsedSeconds >= ONLINE_WRITE_TIMEOUT_SECONDS then
            self.activeUploadMapRequestId = nil
            self.activeUploadMapRequestStartedAt = nil
            self.activeUploadMapDescriptor = nil
            self:setLevelSelectActionState(LEVEL_SELECT_ACTION_STATUS_ERROR, "The map upload timed out.", "Upload failed")
        end
    end

    if self.activeScoreSubmitRequestId ~= nil and self.activeScoreSubmitRequestStartedAt ~= nil then
        local elapsedSeconds = getNowSeconds() - self.activeScoreSubmitRequestStartedAt
        if elapsedSeconds >= ONLINE_WRITE_TIMEOUT_SECONDS then
            self.activeScoreSubmitRequestId = nil
            self.activeScoreSubmitRequestStartedAt = nil
            self.resultsOnlineState = {
                status = "error",
                message = "The score upload timed out.",
            }
        end
    end

    while true do
        local encodedResponse = self.leaderboardResponseChannel:pop()
        if not encodedResponse then
            break
        end

        local decodedResponse = json.decode(encodedResponse)
        if type(decodedResponse) == "table" and decodedResponse.kind == "fetch" and decodedResponse.requestId == self.activeLeaderboardRequestId then
            self.activeLeaderboardRequestId = nil
            self.activeLeaderboardRequestStartedAt = nil
            self:applyLeaderboardFetchResult(decodedResponse)
            self.activeLeaderboardRequestScopeKey = nil
        elseif type(decodedResponse) == "table" and decodedResponse.kind == "preview" and decodedResponse.requestId == self.activeLevelSelectPreviewRequestId then
            local previewMapUuid = self.activeLevelSelectPreviewRequestMapUuid
            self.activeLevelSelectPreviewRequestId = nil
            self.activeLevelSelectPreviewRequestStartedAt = nil
            self.activeLevelSelectPreviewRequestMapUuid = nil
            self:applyLevelSelectPreviewFetchResult(decodedResponse, previewMapUuid)
        elseif type(decodedResponse) == "table" and decodedResponse.kind == "marketplace" and decodedResponse.requestId == self.activeMarketplaceRequestId then
            local responseScopeKey = self.activeMarketplaceRequestScopeKey
            self.activeMarketplaceRequestId = nil
            self.activeMarketplaceRequestStartedAt = nil
            self.activeMarketplaceRequestScopeKey = nil
            self:applyMarketplaceFetchResult(decodedResponse, responseScopeKey)
        elseif type(decodedResponse) == "table" and decodedResponse.kind == "favorite_map" and decodedResponse.requestId == self.activeFavoriteMapRequestId then
            local mapUuid = self.activeFavoriteMapMapUuid
            local previousState = self.activeFavoriteMapPreviousState
            self.activeFavoriteMapRequestId = nil
            self.activeFavoriteMapRequestStartedAt = nil
            self.activeFavoriteMapMapUuid = nil
            self.activeFavoriteMapPreviousState = nil
            if decodedResponse.ok and type(decodedResponse.payload) == "table" then
                local responseMapUuid = tostring(decodedResponse.payload.map_uuid or mapUuid or "")
                local favoriteCount = tonumber(decodedResponse.payload.favorite_count)
                local targetLikedByPlayer = marketplaceFavoriteLogic.getTargetLikedByPlayer(previousState)
                local likedByPlayer = marketplaceFavoriteLogic.resolveLikedByPlayer(decodedResponse.payload, targetLikedByPlayer)
                local wasAccepted = marketplaceFavoriteLogic.wasMutationAccepted(decodedResponse.payload, targetLikedByPlayer)
                local wasAlreadyFavorited = marketplaceFavoriteLogic.wasAlreadyFavorited(decodedResponse.payload, targetLikedByPlayer)
                local wasAlreadyRemoved = marketplaceFavoriteLogic.wasAlreadyRemoved(decodedResponse.payload, targetLikedByPlayer)
                if favoriteCount == nil then
                    local resolvedPreviousFavoriteCount = previousState and tonumber(previousState.favoriteCount) or 0
                    favoriteCount = targetLikedByPlayer
                        and math.max(0, resolvedPreviousFavoriteCount + MARKETPLACE_FAVORITE_OPTIMISTIC_DELTA)
                        or math.max(0, resolvedPreviousFavoriteCount - MARKETPLACE_FAVORITE_OPTIMISTIC_DELTA)
                end
                self:updateMarketplaceFavoriteState(responseMapUuid, favoriteCount, likedByPlayer)
                if wasAccepted then
                    local actionMessage = targetLikedByPlayer
                        and string.format("Map liked. It now has %d vote(s).", favoriteCount)
                        or string.format("Like removed. It now has %d vote(s).", favoriteCount)
                    self:setLevelSelectActionState(
                        LEVEL_SELECT_ACTION_STATUS_SUCCESS,
                        actionMessage
                    )
                else
                    local shouldRestorePreviousState = likedByPlayer ~= targetLikedByPlayer
                    if shouldRestorePreviousState then
                        self:restoreMarketplaceFavoriteState(previousState)
                    end
                    if wasAlreadyFavorited or wasAlreadyRemoved then
                        self:setLevelSelectActionState(
                            LEVEL_SELECT_ACTION_STATUS_INFO,
                            wasAlreadyFavorited and "The map was already liked." or "The like was already removed."
                        )
                    else
                        self:setLevelSelectActionState(
                            LEVEL_SELECT_ACTION_STATUS_ERROR,
                            "The like request could not be completed.",
                            "Like failed"
                        )
                    end
                end
                if self:processQueuedMarketplaceFavoriteState(responseMapUuid) then
                    return
                end
            else
                self:restoreMarketplaceFavoriteState(previousState)
                self.pendingFavoriteMapDesiredState = nil
                self:setLevelSelectActionState(
                    LEVEL_SELECT_ACTION_STATUS_ERROR,
                    decodedResponse.error or "The like request failed.",
                    "Like failed"
                )
            end
        elseif type(decodedResponse) == "table" and decodedResponse.kind == "upload_map" and decodedResponse.requestId == self.activeUploadMapRequestId then
            local uploadedMapDescriptor = self.activeUploadMapDescriptor
            self.activeUploadMapRequestId = nil
            self.activeUploadMapRequestStartedAt = nil
            self.activeUploadMapDescriptor = nil
            if decodedResponse.ok and type(decodedResponse.payload) == "table" then
                self:clearLevelSelectActionState()
                self:openLevelSelectUploadDialog(decodedResponse.payload, uploadedMapDescriptor)
            else
                local statusCode = tonumber(decodedResponse.status)
                local failureMessage = decodedResponse.error or "The map upload failed."
                if statusCode then
                    failureMessage = string.format("Map upload failed (HTTP %d): %s", statusCode, tostring(failureMessage))
                end
                self:setLevelSelectActionState(
                    LEVEL_SELECT_ACTION_STATUS_ERROR,
                    failureMessage,
                    "Upload failed"
                )
            end
        elseif type(decodedResponse) == "table" and decodedResponse.kind == "score_submit" and decodedResponse.requestId == self.activeScoreSubmitRequestId then
            self.activeScoreSubmitRequestId = nil
            self.activeScoreSubmitRequestStartedAt = nil
            if decodedResponse.ok and type(decodedResponse.payload) == "table" then
                self.resultsOnlineState = {
                    status = decodedResponse.status == 202 and "kept" or "submitted",
                    message = decodedResponse.status == 202
                        and "Score was valid, but your online best for this map is already higher."
                        or "Score uploaded successfully.",
                }
                self:updateLevelSelectPreviewCacheFromSubmit(decodedResponse.payload)
            else
                self.resultsOnlineState = {
                    status = "error",
                    message = decodedResponse.error or "The score upload failed.",
                }
            end
        end
    end

    if self:isOnlineMode()
        and self.screen == "leaderboard"
        and self.activeLeaderboardRequestId == nil
        and not self:isLeaderboardCacheFresh()
        and self:isLeaderboardFetchAllowed()
    then
        local onlineConfig = self:getActiveOnlineConfig()
        if not onlineConfig.isConfigured then
            self.leaderboardState = self:buildLeaderboardState(
                LEADERBOARD_STATUS_DISABLED,
                getLeaderboardUnavailableMessage(),
                cacheEntry.payload,
                cacheEntry.fetchedAt
            )
            return
        end

        self:beginLeaderboardFetch(onlineConfig)
    end

    local previewMapUuid = self:getActiveLevelSelectPreviewMapUuid()
    if levelSelectPreviewLogic.shouldStartFetch(
        self.levelSelectPreviewState,
        previewMapUuid,
        self.activeLevelSelectPreviewRequestId ~= nil,
        previewMapUuid and self:isLevelSelectPreviewCacheFresh(previewMapUuid) or false,
        previewMapUuid and self:isLevelSelectPreviewFetchAllowed(previewMapUuid) or false
    ) then
        if self:isOnlineMode() then
            local onlineConfig = self:getActiveOnlineConfig()
            if onlineConfig.isConfigured then
                self:beginLevelSelectPreviewFetch(onlineConfig, previewMapUuid)
            elseif self:getLevelSelectPreviewCacheEntry(previewMapUuid) then
                self:setLevelSelectPreviewState(previewMapUuid, LEVEL_SELECT_PREVIEW_STATUS_READY, nil, {
                    hasResolvedInitialRemoteAttempt = true,
                })
            else
                self:setLevelSelectPreviewState(previewMapUuid, LEVEL_SELECT_PREVIEW_STATUS_ERROR, LEVEL_SELECT_PREVIEW_MESSAGE_NO_LOCAL_DATA, {
                    hasResolvedInitialRemoteAttempt = true,
                })
            end
        end
    end

    if self:isOnlineMode() and self.screen == "level_select" and self:isLevelSelectMarketplaceMode() then
        local scopeDetails = self:getMarketplaceScopeDetails()
        local scopeKey = scopeDetails.scopeKey
        local onlineConfig = self:getActiveOnlineConfig()

        if not scopeDetails.needsRequest then
            self:setMarketplaceState(scopeKey, LEVEL_SELECT_MARKETPLACE_STATUS_IDLE, LEVEL_SELECT_MARKETPLACE_MESSAGE_EMPTY_SEARCH)
            return
        end

        if not onlineConfig.isConfigured then
            self:setMarketplaceState(
                scopeKey,
                LEVEL_SELECT_MARKETPLACE_STATUS_DISABLED,
                table.concat(onlineConfig.errors or { "The online marketplace is not configured." }, " ")
            )
            return
        end

        if self.activeMarketplaceRequestId == nil
            and not self:isMarketplaceCacheFresh(scopeKey)
            and self:isMarketplaceFetchAllowed(scopeKey)
        then
            self:beginMarketplaceFetch(onlineConfig, scopeDetails)
        elseif self:isMarketplaceCacheFresh(scopeKey) then
            self:setMarketplaceState(scopeKey, LEVEL_SELECT_MARKETPLACE_STATUS_READY, nil)
        end
    end
end

function Game:isProfileComplete()
    return trim(self.profile and self.profile.playerDisplayName or "") ~= ""
end

function Game:isDebugModeEnabled()
    return self.profile and self.profile.debugMode == true
end

function Game:saveProfile()
    local savedProfile, saveError = profileStorage.save(self.profile or {})
    if savedProfile then
        self.profile = savedProfile
        return true
    end
    return false, saveError
end

function Game:hasDismissedMapGuide(mapUuid)
    return self.profile
        and self.profile.tutorials
        and self.profile.tutorials.dismissedMapGuides
        and self.profile.tutorials.dismissedMapGuides[mapUuid] == true
        or false
end

function Game:buildPlayGuideState(level)
    local mapUuid = type(level) == "table" and tostring(level.mapUuid or "") or ""
    local guideSteps = PLAY_GUIDE_STEPS_BY_MAP_UUID[mapUuid]
    if not guideSteps or self:hasDismissedMapGuide(mapUuid) then
        return nil
    end

    return {
        mapUuid = mapUuid,
        stepIndex = 1,
        steps = guideSteps,
    }
end

function Game:finalizeDismissPlayGuide()
    if not self.playGuide or not self.playGuide.mapUuid then
        self.playGuide = nil
        self.playGuideTransition = nil
        return false
    end

    self.profile.tutorials = self.profile.tutorials or {}
    self.profile.tutorials.dismissedMapGuides = self.profile.tutorials.dismissedMapGuides or {}
    self.profile.tutorials.dismissedMapGuides[self.playGuide.mapUuid] = true
    self:saveProfile()
    self.playGuide = nil
    self.playGuideTransition = nil
    self.playHoverInfo = nil
    return true
end

function Game:isPlayGuideAnimating()
    return self.playGuideTransition ~= nil
end

function Game:beginPlayGuideTransition(kind, toStepIndex)
    if not self.playGuide or self:isPlayGuideAnimating() then
        return false
    end

    self.playGuideTransition = {
        kind = kind,
        phase = "shrink",
        phaseProgress = 0,
        fromStepIndex = self.playGuide.stepIndex or 1,
        toStepIndex = toStepIndex,
    }
    self.playHoverInfo = nil
    return true
end

function Game:dismissPlayGuide()
    return self:beginPlayGuideTransition("dismiss", nil)
end

function Game:skipPlayGuide()
    return self:dismissPlayGuide()
end

function Game:advancePlayGuide()
    if not self.playGuide or self:isPlayGuideAnimating() then
        return false
    end

    if self.playGuide.stepIndex >= #(self.playGuide.steps or {}) then
        return self:dismissPlayGuide()
    end

    return self:beginPlayGuideTransition("advance", self.playGuide.stepIndex + 1)
end

function Game:updatePlayGuideTransition(dt)
    if not self.playGuideTransition then
        return
    end

    local transition = self.playGuideTransition
    local duration = PLAY_GUIDE_SHRINK_DURATION

    if transition.phase == "move" then
        duration = PLAY_GUIDE_MOVE_DURATION
    elseif transition.phase == "grow" then
        duration = PLAY_GUIDE_GROW_DURATION
    end

    transition.phaseProgress = math.min(1, (transition.phaseProgress or 0) + dt / duration)
    if transition.phaseProgress < 1 then
        return
    end

    if transition.kind == "dismiss" then
        self:finalizeDismissPlayGuide()
        return
    end

    if transition.phase == "shrink" then
        transition.phase = "move"
        transition.phaseProgress = 0
        return
    end

    if transition.phase == "move" then
        transition.phase = "grow"
        transition.phaseProgress = 0
        return
    end

    if self.playGuide then
        self.playGuide.stepIndex = transition.toStepIndex or self.playGuide.stepIndex
    end
    self.playGuideTransition = nil
end

function Game:getGuideTargetJunction(step)
    if not self.world or type(step) ~= "table" then
        return nil
    end

    local junctionOrder = self.world.junctionOrder or {}
    if #junctionOrder == 0 then
        return nil
    end

    local targetJunctionId = tostring(step.junctionId or "")
    if targetJunctionId ~= "" then
        for _, junction in ipairs(junctionOrder) do
            if tostring(junction.id or "") == targetJunctionId then
                return junction
            end
        end
    end

    local targetIndex = tonumber(step.junctionIndex)
    if targetIndex then
        targetIndex = math.max(1, math.min(#junctionOrder, math.floor(targetIndex)))
        return junctionOrder[targetIndex]
    end

    return junctionOrder[1]
end

function Game:canInteractWithGuideControlDuringGuide(x, y)
    if not self.playGuide or not self.world or self:isPlayGuideAnimating() then
        return false
    end

    local step = self.playGuide.steps and self.playGuide.steps[self.playGuide.stepIndex] or nil
    if not step or (step.allowJunctionClick ~= true and step.allowControlClick ~= true) then
        return false
    end

    local junction = self:getGuideTargetJunction(step)
    if not junction then
        return false
    end

    if self.world:isCrossingHit(junction, x, y) then
        return true
    end

    if step.allowControlClick == true and self.world:isOutputSelectorHit(junction, x, y) then
        return true
    end

    return false
end

function Game:canInteractWithJunctionDuringGuide(x, y)
    return self:canInteractWithGuideControlDuringGuide(x, y)
end

function Game:toggleDebugMode()
    self.profile.debugMode = not self:isDebugModeEnabled()
    local ok = self:saveProfile()
    if not ok then
        self.profile.debugMode = not self.profile.debugMode
    end
end

function Game:appendProfileNameInput(text)
    local cleanText = text:gsub("[%c\r\n\t]", "")
    if cleanText == "" then
        return
    end

    local nextValue = self.profileSetupNameBuffer .. cleanText
    if #nextValue <= PROFILE_NAME_MAX_LENGTH then
        self.profileSetupNameBuffer = nextValue
        self.profileSetupError = nil
    end
end

function Game:backspaceProfileName()
    self.profileSetupNameBuffer = trimLastUtf8Character(self.profileSetupNameBuffer)
    self.profileSetupError = nil
end

function Game:confirmProfileSetup()
    local trimmedName = trim(self.profileSetupNameBuffer)
    if trimmedName == "" then
        self.profileSetupError = "Enter a username before continuing."
        return false, self.profileSetupError
    end

    self.profile.playerDisplayName = trimmedName
    self.profileSetupNameBuffer = trimmedName
    local ok, saveError = self:saveProfile()
    if not ok then
        self.profileSetupError = saveError or "The profile could not be saved."
        return false, self.profileSetupError
    end

    self.profileSetupError = nil
    self.profileModeSetupError = nil
    self.screen = "profile_mode_setup"
    return true
end

function Game:cycleProfileModeSelection(direction)
    if direction == nil or direction == 0 then
        return
    end

    if self.profileModeSelection == PLAY_MODE_OFFLINE then
        self.profileModeSelection = PLAY_MODE_ONLINE
    else
        self.profileModeSelection = PLAY_MODE_OFFLINE
    end
    self.profileModeSetupError = nil
end

function Game:confirmProfileModeSelection()
    local ok, saveError = self:setPlayMode(self.profileModeSelection)
    if not ok then
        self.profileModeSetupError = saveError or "The play mode could not be saved."
        return false, self.profileModeSetupError
    end

    self:openMenu()
    return true
end

function Game:submitResultsScore()
    self.resultsOnlineState = nil

    if not self.levelComplete then
        self.resultsOnlineState = {
            status = "skipped",
            message = "Scores are uploaded only after a successful level clear.",
        }
        return
    end

    local localScoreSaved, isNewLocalBest, localSaveError = self:updateLocalScoreboard(self.resultsSummary or {})
    if not localScoreSaved then
        self.resultsOnlineState = {
            status = "error",
            message = localSaveError or RESULTS_MESSAGE_LOCAL_SAVE_FAILED,
        }
        return
    end

    if self:isOfflineMode() then
        self.resultsOnlineState = {
            status = isNewLocalBest and "submitted" or "kept",
            message = isNewLocalBest and RESULTS_MESSAGE_LOCAL_BEST_SAVED or RESULTS_MESSAGE_LOCAL_BEST_KEPT,
        }
        return
    end

    local onlineConfig = self:reloadOnlineConfig()
    if not onlineConfig.isConfigured then
        self.resultsOnlineState = {
            status = "disabled",
            message = "Saved locally. " .. getLeaderboardUnavailableMessage(),
        }
        return
    end

    if self:isDebugModeEnabled() then
        self.resultsOnlineState = {
            status = "skipped",
            message = "Saved locally. Debug mode is enabled, so the online score upload was skipped.",
        }
        return
    end

    local summary = self.resultsSummary or {}
    self.resultsOnlineState = {
        status = "pending",
        message = "Uploading score...",
    }
    self:beginScoreSubmitRequest(onlineConfig, summary)
end

function Game:canUploadMapDescriptor(mapDescriptor)
    return mapDescriptor ~= nil
        and mapDescriptor.source == "user"
        and mapDescriptor.isRemoteImport ~= true
end

function Game:getUploadConfig()
    if not self:isOnlineMode() then
        return {
            isConfigured = false,
            errors = { "Offline mode is enabled." },
        }
    end

    local uploadConfig = leaderboardClient.getConfig()
    if uploadConfig.isConfigured and uploadConfig.hasLocalRequiredConfig then
        return uploadConfig
    end

    local errors = {}
    for _, errorMessage in ipairs(uploadConfig.errors or {}) do
        errors[#errors + 1] = errorMessage
    end

    if not uploadConfig.hasLocalConfigFile then
        errors[#errors + 1] = LEVEL_SELECT_UPLOAD_ENV_REQUIRED_MESSAGE
    elseif not uploadConfig.hasLocalRequiredConfig then
        errors[#errors + 1] = LEVEL_SELECT_UPLOAD_ENV_REQUIRED_MESSAGE
    end

    uploadConfig.isConfigured = false
    uploadConfig.errors = errors
    return uploadConfig
end

function Game:isUploadSelectedMapAvailable(mapDescriptor)
    return self:isOnlineMode()
        and self.levelSelectMode == LEVEL_SELECT_MODE_LIBRARY
        and self.levelSelectFilter == "user"
        and self:getUploadConfig().isConfigured
        and self:canUploadMapDescriptor(mapDescriptor or self:getSelectedLevelMap())
end

function Game:canCloneMapDescriptor(mapDescriptor)
    return mapDescriptor ~= nil
        and mapDescriptor.source == "user"
        and mapDescriptor.isRemoteImport == true
end

function Game:cloneMapForEditing(mapDescriptor)
    local selectedMap = mapDescriptor or self:getSelectedLevelMap()
    if not self:canCloneMapDescriptor(selectedMap) then
        self:setLevelSelectActionState(
            LEVEL_SELECT_ACTION_STATUS_ERROR,
            "Only downloaded maps can be cloned.",
            "Clone unavailable"
        )
        return nil
    end

    local mapData, loadError = mapStorage.loadMap(selectedMap)
    if not mapData then
        self:setLevelSelectActionState(
            LEVEL_SELECT_ACTION_STATUS_ERROR,
            loadError or "The selected map could not be cloned.",
            "Clone failed"
        )
        return nil
    end

    local clonedPayload = deepCopy(mapData)
    clonedPayload.remoteSource = nil
    clonedPayload.mapUuid = nil
    clonedPayload.savedAt = nil
    if type(clonedPayload.level) == "table" then
        clonedPayload.level.id = nil
        clonedPayload.level.mapUuid = nil
    end

    local clonedDescriptor, cloneError = mapStorage.importMap(
        tostring(clonedPayload.name or selectedMap.displayName or selectedMap.name or "Untitled Map"),
        clonedPayload
    )
    if not clonedDescriptor then
        self:setLevelSelectActionState(
            LEVEL_SELECT_ACTION_STATUS_ERROR,
            cloneError or "The selected map could not be cloned.",
            "Clone failed"
        )
        return nil
    end

    self:refreshMaps()
    self:setLevelSelectSelection(clonedDescriptor)
    self:setLevelSelectFilter("user")
    self:setLevelSelectActionState(
        LEVEL_SELECT_ACTION_STATUS_SUCCESS,
        "A local editable copy is ready in your user maps.",
        "Map cloned"
    )

    return clonedDescriptor
end

function Game:uploadSelectedMap()
    local selectedMap = self:getSelectedLevelMap()
    if not self:canUploadMapDescriptor(selectedMap) then
        self:setLevelSelectActionState(
            LEVEL_SELECT_ACTION_STATUS_ERROR,
            "Only your own local user maps can be uploaded.",
            "Upload unavailable"
        )
        return
    end

    local onlineConfig = self:getUploadConfig()
    if not onlineConfig.isConfigured then
        self:setLevelSelectActionState(
            LEVEL_SELECT_ACTION_STATUS_ERROR,
            table.concat(onlineConfig.errors or { "The online marketplace is not configured." }, " "),
            "Upload unavailable"
        )
        return
    end

    local mapData, loadError = mapStorage.loadMap(selectedMap)
    if not mapData or type(mapData.level) ~= "table" then
        self:setLevelSelectActionState(
            LEVEL_SELECT_ACTION_STATUS_ERROR,
            loadError or "The selected map could not be uploaded.",
            "Upload failed"
        )
        return
    end

    self:closeLevelSelectUploadDialog()
    self:setLevelSelectActionState(
        LEVEL_SELECT_ACTION_STATUS_INFO,
        "Sending your map to the online library.",
        "Uploading map"
    )
    self:beginUploadMapRequest(onlineConfig, mapData, selectedMap)
end

function Game:downloadMarketplaceMap(mapDescriptor)
    local selectedMap = mapDescriptor or self:getSelectedLevelMap()
    local sourceEntry = selectedMap and selectedMap.remoteSourceEntry or nil
    if type(sourceEntry) ~= "table" or type(sourceEntry.map) ~= "table" then
        self:setLevelSelectActionState(
            LEVEL_SELECT_ACTION_STATUS_ERROR,
            "The selected online map could not be downloaded.",
            "Download failed"
        )
        return
    end

    local importedPayload = {
        version = 1,
        mapUuid = tostring(sourceEntry.map_uuid or selectedMap.mapUuid or ""),
        name = tostring(sourceEntry.map_name or selectedMap.displayName or selectedMap.name or "Untitled Map"),
        previewDescription = selectedMap.previewDescription,
        level = deepCopy(sourceEntry.map),
        remoteSource = {
            creatorUuid = tostring(sourceEntry.creator_uuid or ""),
            creatorDisplayName = tostring(sourceEntry.creator_display_name or ""),
            favoriteCount = tonumber(sourceEntry.favorite_count or 0) or 0,
            internalIdentifier = tostring(sourceEntry.internal_identifier or ""),
            likedByPlayer = sourceEntry.liked_by_player == true,
            mapCategory = tostring(sourceEntry.map_category or ""),
        },
    }

    if type(importedPayload.level) == "table" then
        importedPayload.level.id = importedPayload.mapUuid
        importedPayload.level.mapUuid = importedPayload.mapUuid
        importedPayload.level.title = importedPayload.level.title or importedPayload.name
    end

    local importedDescriptor, importError = mapStorage.importMap(importedPayload.name, importedPayload)
    if not importedDescriptor then
        self:setLevelSelectActionState(
            LEVEL_SELECT_ACTION_STATUS_ERROR,
            importError or "The selected online map could not be saved locally.",
            "Download failed"
        )
        return
    end

    self:refreshMaps()
    self:setLevelSelectActionState(
        LEVEL_SELECT_ACTION_STATUS_SUCCESS,
        "Saved to your local maps and ready to play or edit.",
        "Map downloaded"
    )
end

function Game:updateMarketplaceFavoriteState(mapUuid, favoriteCount, likedByPlayer)
    local resolvedMapUuid = tostring(mapUuid or "")
    if resolvedMapUuid == "" then
        return
    end

    local resolvedFavoriteCount = tonumber(favoriteCount or 0) or 0
    local resolvedLikedByPlayer = likedByPlayer == true
    for _, cacheEntry in pairs(self.marketplaceCacheByScope) do
        local payload = type(cacheEntry) == "table" and cacheEntry.payload or nil
        local entries = type(payload) == "table" and payload.entries or nil
        if type(entries) == "table" then
            for _, entry in ipairs(entries) do
                if tostring(entry.map_uuid or "") == resolvedMapUuid then
                    entry.favorite_count = resolvedFavoriteCount
                    entry.liked_by_player = resolvedLikedByPlayer
                end
            end
        end
    end
end

function Game:getMarketplaceFavoriteAnimation(mapUuid)
    local resolvedMapUuid = tostring(mapUuid or "")
    if resolvedMapUuid == "" then
        return nil
    end

    local animationState = self.marketplaceFavoriteAnimationByMap[resolvedMapUuid]
    if type(animationState) ~= "table" then
        return nil
    end

    local elapsedSeconds = getNowSeconds() - (tonumber(animationState.startedAt) or 0)
    local progress = elapsedSeconds / MARKETPLACE_FAVORITE_ANIMATION_DURATION_SECONDS
    if progress >= 1 then
        self.marketplaceFavoriteAnimationByMap[resolvedMapUuid] = nil
        return nil
    end

    if progress < 0 then
        progress = 0
    end

    return {
        delta = tonumber(animationState.delta or 0) or 0,
        progress = progress,
    }
end

function Game:startMarketplaceFavoriteAnimation(mapUuid, delta)
    local resolvedMapUuid = tostring(mapUuid or "")
    if resolvedMapUuid == "" then
        return
    end

    self.marketplaceFavoriteAnimationByMap[resolvedMapUuid] = {
        delta = tonumber(delta or 0) or 0,
        startedAt = getNowSeconds(),
    }
end

function Game:applyOptimisticMarketplaceFavorite(mapUuid, favoriteCount, likedByPlayer)
    self:updateMarketplaceFavoriteState(mapUuid, favoriteCount, likedByPlayer == true)
    local animationDelta = likedByPlayer == true
        and MARKETPLACE_FAVORITE_OPTIMISTIC_DELTA
        or -MARKETPLACE_FAVORITE_OPTIMISTIC_DELTA
    self:startMarketplaceFavoriteAnimation(mapUuid, animationDelta)
end

function Game:restoreMarketplaceFavoriteState(snapshot)
    if type(snapshot) ~= "table" then
        return
    end

    self:updateMarketplaceFavoriteState(snapshot.mapUuid, snapshot.favoriteCount, snapshot.likedByPlayer)
    self.marketplaceFavoriteAnimationByMap[tostring(snapshot.mapUuid or "")] = nil
end

function Game:getMarketplaceFavoriteState(mapUuid)
    local resolvedMapUuid = tostring(mapUuid or "")
    if resolvedMapUuid == "" then
        return nil
    end

    for _, cacheEntry in pairs(self.marketplaceCacheByScope) do
        local payload = type(cacheEntry) == "table" and cacheEntry.payload or nil
        local entries = type(payload) == "table" and payload.entries or nil
        if type(entries) == "table" then
            for _, entry in ipairs(entries) do
                if tostring(entry.map_uuid or "") == resolvedMapUuid then
                    return {
                        favoriteCount = tonumber(entry.favorite_count or 0) or 0,
                        likedByPlayer = entry.liked_by_player == true,
                        mapUuid = resolvedMapUuid,
                    }
                end
            end
        end
    end

    return nil
end

function Game:queueMarketplaceFavoriteState(mapUuid, likedByPlayer)
    local resolvedMapUuid = tostring(mapUuid or "")
    if resolvedMapUuid == "" then
        self.pendingFavoriteMapDesiredState = nil
        return
    end

    self.pendingFavoriteMapDesiredState = {
        mapUuid = resolvedMapUuid,
        likedByPlayer = likedByPlayer == true,
    }
end

function Game:processQueuedMarketplaceFavoriteState(mapUuid)
    local pendingState = self.pendingFavoriteMapDesiredState
    if type(pendingState) ~= "table" then
        return false
    end

    local resolvedMapUuid = tostring(mapUuid or "")
    if resolvedMapUuid == "" or tostring(pendingState.mapUuid or "") ~= resolvedMapUuid then
        return false
    end

    local currentState = self:getMarketplaceFavoriteState(resolvedMapUuid)
    if type(currentState) ~= "table" then
        self.pendingFavoriteMapDesiredState = nil
        return false
    end

    if currentState.likedByPlayer == (pendingState.likedByPlayer == true) then
        self.pendingFavoriteMapDesiredState = nil
        return false
    end

    local onlineConfig = self:getActiveOnlineConfig()
    if not onlineConfig.isConfigured then
        self.pendingFavoriteMapDesiredState = nil
        self:setLevelSelectActionState(
            LEVEL_SELECT_ACTION_STATUS_ERROR,
            table.concat(onlineConfig.errors or { "The online marketplace is not configured." }, " "),
            "Like failed"
        )
        return false
    end

    self.pendingFavoriteMapDesiredState = nil
    self.activeFavoriteMapPreviousState = currentState
    local optimisticFavoriteCount = pendingState.likedByPlayer
        and math.max(0, currentState.favoriteCount + MARKETPLACE_FAVORITE_OPTIMISTIC_DELTA)
        or math.max(0, currentState.favoriteCount - MARKETPLACE_FAVORITE_OPTIMISTIC_DELTA)
    self:applyOptimisticMarketplaceFavorite(resolvedMapUuid, optimisticFavoriteCount, pendingState.likedByPlayer)
    return self:beginFavoriteMapRequest(onlineConfig, resolvedMapUuid, pendingState.likedByPlayer)
end

function Game:failMarketplaceFavoriteRequest(message)
    local previousState = self.activeFavoriteMapPreviousState
    self.activeFavoriteMapRequestId = nil
    self.activeFavoriteMapRequestStartedAt = nil
    self.activeFavoriteMapMapUuid = nil
    self.activeFavoriteMapPreviousState = nil
    self.pendingFavoriteMapDesiredState = nil
    self:restoreMarketplaceFavoriteState(previousState)
    self:setLevelSelectActionState(
        LEVEL_SELECT_ACTION_STATUS_ERROR,
        message or "The like request failed.",
        "Like failed"
    )
end

function Game:favoriteMarketplaceMap(mapDescriptor)
    local selectedMap = mapDescriptor or self:getSelectedLevelMap()
    local sourceEntry = selectedMap and selectedMap.remoteSourceEntry or nil
    if type(sourceEntry) ~= "table" then
        self:setLevelSelectActionState(
            LEVEL_SELECT_ACTION_STATUS_ERROR,
            "The selected online map could not be liked.",
            "Like failed"
        )
        return
    end

    local mapUuid = tostring(sourceEntry.map_uuid or selectedMap.mapUuid or "")
    if mapUuid == "" then
        self:setLevelSelectActionState(
            LEVEL_SELECT_ACTION_STATUS_ERROR,
            "The selected online map is missing its map UUID.",
            "Like failed"
        )
        return
    end

    local onlineConfig = self:getActiveOnlineConfig()
    if not onlineConfig.isConfigured then
        self:setLevelSelectActionState(
            LEVEL_SELECT_ACTION_STATUS_ERROR,
            table.concat(onlineConfig.errors or { "The online marketplace is not configured." }, " "),
            "Like failed"
        )
        return
    end

    if self.activeFavoriteMapRequestId ~= nil then
        if self.activeFavoriteMapMapUuid ~= mapUuid then
            return
        end

        local desiredLikedByPlayer = not (sourceEntry.liked_by_player == true)
        local currentFavoriteCount = tonumber(sourceEntry.favorite_count or 0) or 0
        local optimisticFavoriteCount = desiredLikedByPlayer
            and math.max(0, currentFavoriteCount + MARKETPLACE_FAVORITE_OPTIMISTIC_DELTA)
            or math.max(0, currentFavoriteCount - MARKETPLACE_FAVORITE_OPTIMISTIC_DELTA)
        self:queueMarketplaceFavoriteState(mapUuid, desiredLikedByPlayer)
        self:applyOptimisticMarketplaceFavorite(mapUuid, optimisticFavoriteCount, desiredLikedByPlayer)
        return
    end

    local wasLikedByPlayer = sourceEntry.liked_by_player == true
    local previousFavoriteCount = tonumber(sourceEntry.favorite_count or 0) or 0
    local optimisticFavoriteCount = wasLikedByPlayer
        and math.max(0, previousFavoriteCount - MARKETPLACE_FAVORITE_OPTIMISTIC_DELTA)
        or math.max(0, previousFavoriteCount + MARKETPLACE_FAVORITE_OPTIMISTIC_DELTA)
    self.activeFavoriteMapPreviousState = {
        mapUuid = mapUuid,
        favoriteCount = previousFavoriteCount,
        likedByPlayer = wasLikedByPlayer,
    }
    self.pendingFavoriteMapDesiredState = nil
    self:applyOptimisticMarketplaceFavorite(mapUuid, optimisticFavoriteCount, not wasLikedByPlayer)
    self:beginFavoriteMapRequest(onlineConfig, mapUuid, not wasLikedByPlayer)
end

function Game:refreshMarketplaceData()
    local scopeDetails = self:getMarketplaceScopeDetails()
    local scopeKey = scopeDetails.scopeKey
    self.marketplaceCacheByScope[scopeKey] = nil
    self.marketplaceNextFetchAtByScope[scopeKey] = 0

    if not scopeDetails.needsRequest then
        self:setMarketplaceState(scopeKey, LEVEL_SELECT_MARKETPLACE_STATUS_IDLE, LEVEL_SELECT_MARKETPLACE_MESSAGE_EMPTY_SEARCH)
        self:setLevelSelectActionState(LEVEL_SELECT_ACTION_STATUS_INFO, LEVEL_SELECT_MARKETPLACE_MESSAGE_EMPTY_SEARCH)
        return
    end

    local onlineConfig = self:getActiveOnlineConfig()
    if not onlineConfig.isConfigured then
        self:setMarketplaceState(
            scopeKey,
            LEVEL_SELECT_MARKETPLACE_STATUS_DISABLED,
            table.concat(onlineConfig.errors or { "The online marketplace is not configured." }, " ")
        )
        self:setLevelSelectActionState(
            LEVEL_SELECT_ACTION_STATUS_ERROR,
            table.concat(onlineConfig.errors or { "The online marketplace is not configured." }, " ")
        )
        return
    end

    if self.activeMarketplaceRequestId == nil then
        self:beginMarketplaceFetch(onlineConfig, scopeDetails)
    end
    self:setLevelSelectActionState(LEVEL_SELECT_ACTION_STATUS_INFO, LEVEL_SELECT_MARKETPLACE_MESSAGE_LOADING)
end

function Game:refreshLeaderboard()
    if self:isOfflineMode() then
        local payload, fetchedAt = self:buildLocalLeaderboardPayload(self.leaderboardMapUuid)
        self.leaderboardState = self:buildLeaderboardState(LEADERBOARD_STATUS_READY, nil, payload, fetchedAt)
        if self.leaderboardState.totalEntries == 0 then
            self.leaderboardState.message = self.leaderboardMapUuid and LEVEL_SELECT_PREVIEW_MESSAGE_NO_LOCAL_BEST or LEADERBOARD_MESSAGE_NO_LOCAL_SCORES
        end
        return
    end

    local onlineConfig = self:getActiveOnlineConfig()
    local cacheEntry = self:getLeaderboardCacheEntry()
    if not onlineConfig.isConfigured then
        self.leaderboardState = self:buildLeaderboardState(
            LEADERBOARD_STATUS_DISABLED,
            getLeaderboardUnavailableMessage(),
            cacheEntry.payload,
            cacheEntry.fetchedAt
        )
        return
    end

    if self:isLeaderboardCacheFresh() then
        self.leaderboardState = self:buildLeaderboardState(
            LEADERBOARD_STATUS_READY,
            nil,
            cacheEntry.payload,
            cacheEntry.fetchedAt
        )
        return
    end

    if not self:isLeaderboardFetchAllowed() then
        local fallbackMessage = cacheEntry.payload and nil or LEADERBOARD_MESSAGE_NO_DATA
        self.leaderboardState = self:buildLeaderboardState(
            cacheEntry.payload and LEADERBOARD_STATUS_READY or LEADERBOARD_STATUS_ERROR,
            fallbackMessage,
            cacheEntry.payload,
            cacheEntry.fetchedAt
        )
        return
    end

    self:beginLeaderboardFetch(onlineConfig)
end

function Game:openLeaderboard(options)
    local openOptions = options or {}
    self.screen = "leaderboard"
    self.leaderboardReturnScreen = openOptions.returnScreen or "menu"
    self.leaderboardMapUuid = openOptions.mapUuid
    self.leaderboardTitle = openOptions.title or self:getLeaderboardTitle(self.leaderboardMapUuid)
    self.leaderboardHoverInfo = nil
    self:refreshLeaderboard()
end

function Game:openLeaderboardForMap(mapUuid, mapName)
    if not mapUuid or mapUuid == "" then
        return
    end

    self.leaderboardMapUuid = mapUuid
    self.leaderboardTitle = self:getLeaderboardTitle(mapUuid)
    self.leaderboardHoverInfo = nil
    self:refreshLeaderboard()
end

function Game:getLeaderboardCycleMapUuids()
    local mapUuids = {}

    for _, descriptor in ipairs(self.availableMaps or {}) do
        if descriptor.mapUuid and descriptor.mapUuid ~= "" then
            mapUuids[#mapUuids + 1] = descriptor.mapUuid
        end
    end

    return mapUuids
end

function Game:cycleLeaderboardMapFilter()
    local mapUuids = self:getLeaderboardCycleMapUuids()
    if #mapUuids == 0 then
        self:clearLeaderboardMapFilter()
        return
    end

    local nextMapUuid = mapUuids[1]
    if self.leaderboardMapUuid and self.leaderboardMapUuid ~= "" then
        for index, mapUuid in ipairs(mapUuids) do
            if mapUuid == self.leaderboardMapUuid then
                nextMapUuid = mapUuids[index + 1]
                break
            end
        end
    end

    if not nextMapUuid then
        self:clearLeaderboardMapFilter()
        return
    end

    self:openLeaderboardForMap(nextMapUuid)
end

function Game:clearLeaderboardMapFilter()
    self.leaderboardMapUuid = nil
    self.leaderboardTitle = self:getLeaderboardTitle(nil)
    self.leaderboardHoverInfo = nil
    self:refreshLeaderboard()
end

function Game:returnFromLeaderboard()
    if self.leaderboardReturnScreen == "results" and self.resultsSummary then
        self.screen = "results"
        return
    end

    self:openMenu()
end

function Game:updateRenderTransform()
    self.renderScale = math.min(self.window.w / self.viewport.w, self.window.h / self.viewport.h)
    self.renderOffsetX = math.floor((self.window.w - self.viewport.w * self.renderScale) * 0.5 + 0.5)
    self.renderOffsetY = math.floor((self.window.h - self.viewport.h * self.renderScale) * 0.5 + 0.5)
end

function Game:toViewportPosition(screenX, screenY)
    return (screenX - self.renderOffsetX) / self.renderScale,
        (screenY - self.renderOffsetY) / self.renderScale
end

function Game:refreshMaps()
    self.availableMaps = mapStorage.listMaps()
    self.mapNameByUuid = {}

    for _, descriptor in ipairs(self.availableMaps) do
        if descriptor.mapUuid and descriptor.mapUuid ~= "" then
            self.mapNameByUuid[descriptor.mapUuid] = descriptor.displayName or descriptor.name or LEADERBOARD_MAP_NAME_UNKNOWN
        end
    end
end

function Game:getMapNameByUuid(mapUuid)
    if not mapUuid or mapUuid == "" then
        return LEADERBOARD_MAP_NAME_UNKNOWN
    end

    return self.mapNameByUuid[mapUuid] or LEADERBOARD_MAP_NAME_UNKNOWN
end

function Game:getLevelSelectMaps()
    return ui.getLevelSelectMapDescriptors(self)
end

function Game:getSelectedLevelMap()
    local maps = self:getLevelSelectMaps()
    local selectedIndex = levelSelectSelection.findIndex(maps, self.levelSelectSelectedId, self.levelSelectSelectedMapUuid)
    local selectedMap = selectedIndex and maps[selectedIndex] or nil

    if selectedMap then
        self.levelSelectSelectedId = selectedMap.id
        self.levelSelectSelectedMapUuid = selectedMap.mapUuid
    else
        self.levelSelectSelectedId = nil
        self.levelSelectSelectedMapUuid = nil
    end

    return selectedMap
end

function Game:isLevelSelectMarketplaceMode()
    return self.levelSelectMode == LEVEL_SELECT_MODE_MARKETPLACE
end

function Game:isOnlineMapsAvailable()
    if not self:isOnlineMode() then
        return false
    end

    local onlineConfig = self:getActiveOnlineConfig()
    return onlineConfig and onlineConfig.isConfigured == true
end

function Game:isLevelSelectMarketplaceSearchActive()
    return self:isLevelSelectMarketplaceMode()
        and self.levelSelectMarketplaceTab == LEVEL_SELECT_MARKETPLACE_TAB_SEARCH
end

function Game:setLevelSelectSelection(mapDescriptor)
    self.levelSelectSelectedId = mapDescriptor and mapDescriptor.id or nil
    self.levelSelectSelectedMapUuid = mapDescriptor and mapDescriptor.mapUuid or nil
    self.levelSelectScroll = 0
    self.levelSelectPendingScrollDirections = {}

    local maps = self:getLevelSelectMaps()
    local targetIndex = findLevelSelectIndex(self, maps)
    if targetIndex then
        if self.levelSelectVisualIndex then
            self.levelSelectTargetVisualIndex = closestWrappedIndex(self.levelSelectVisualIndex, targetIndex, #maps)
        else
            self.levelSelectTargetVisualIndex = targetIndex
        end
    else
        self.levelSelectTargetVisualIndex = nil
    end

    self:clearLevelSelectActionState()
    self:clearLevelSelectLeaderboardFlip()
end

function Game:resetLevelSelectVisualIndex()
    local maps = self:getLevelSelectMaps()
    local targetIndex = findLevelSelectIndex(self, maps)
    self.levelSelectVisualIndex = targetIndex
    self.levelSelectTargetVisualIndex = targetIndex
    self.levelSelectPendingScrollDirections = {}
end

function Game:setLevelSelectFilter(filterId)
    self.levelSelectFilter = filterId or "campaign"
    self:clearLevelSelectActionState()
    self:getSelectedLevelMap()
    self:resetLevelSelectVisualIndex()
    self.levelSelectScroll = 0
    self:clearLevelSelectLeaderboardFlip()
end

function Game:setLevelSelectMode(mode)
    local resolvedMode = mode == LEVEL_SELECT_MODE_MARKETPLACE
        and LEVEL_SELECT_MODE_MARKETPLACE
        or LEVEL_SELECT_MODE_LIBRARY
    if resolvedMode == LEVEL_SELECT_MODE_MARKETPLACE and not self:isOnlineMode() then
        self.levelSelectMode = LEVEL_SELECT_MODE_LIBRARY
        self:clearLevelSelectLeaderboardFlip()
        return
    end

    if self.levelSelectMode == resolvedMode then
        return
    end

    self.levelSelectMode = resolvedMode
    self.levelSelectHoverId = nil
    self.levelSelectHoverInfo = nil
    self.levelSelectIssue = nil
    self:clearLevelSelectActionState()
    self:getSelectedLevelMap()
    self:resetLevelSelectVisualIndex()
    self:clearLevelSelectLeaderboardFlip()
end

function Game:toggleLevelSelectMode()
    if not self:isOnlineMode() then
        self:setLevelSelectMode(LEVEL_SELECT_MODE_LIBRARY)
        return
    end

    if self:isLevelSelectMarketplaceMode() then
        self:setLevelSelectMode(LEVEL_SELECT_MODE_LIBRARY)
        return
    end

    self:setLevelSelectMode(LEVEL_SELECT_MODE_MARKETPLACE)
end

function Game:setLevelSelectMarketplaceTab(tabId)
    for _, allowedTabId in ipairs(LEVEL_SELECT_MARKETPLACE_TAB_ORDER) do
        if tabId == allowedTabId then
            self.levelSelectMarketplaceTab = tabId
            self.levelSelectHoverId = nil
            self.levelSelectHoverInfo = nil
            self:clearLevelSelectActionState()
            self:getSelectedLevelMap()
            self:resetLevelSelectVisualIndex()
            self.levelSelectScroll = 0
            return
        end
    end
end

function Game:cycleLevelSelectMarketplaceTab(direction)
    local currentIndex = 1
    for index, tabId in ipairs(LEVEL_SELECT_MARKETPLACE_TAB_ORDER) do
        if tabId == self.levelSelectMarketplaceTab then
            currentIndex = index
            break
        end
    end

    local nextIndex = currentIndex + direction
    if nextIndex < 1 then
        nextIndex = #LEVEL_SELECT_MARKETPLACE_TAB_ORDER
    elseif nextIndex > #LEVEL_SELECT_MARKETPLACE_TAB_ORDER then
        nextIndex = 1
    end

    self:setLevelSelectMarketplaceTab(LEVEL_SELECT_MARKETPLACE_TAB_ORDER[nextIndex])
end

function Game:appendLevelSelectMarketplaceSearch(text)
    if text == "" or not self:isLevelSelectMarketplaceSearchActive() then
        return
    end

    local nextValue = self.levelSelectMarketplaceSearchQuery .. text
    if #nextValue > LEVEL_SELECT_MARKETPLACE_SEARCH_MAX_LENGTH then
        return
    end

    self.levelSelectMarketplaceSearchQuery = nextValue
    self:clearLevelSelectActionState()
    self:getSelectedLevelMap()
    self:resetLevelSelectVisualIndex()
end

function Game:backspaceLevelSelectMarketplaceSearch()
    if not self:isLevelSelectMarketplaceSearchActive() then
        return
    end

    self.levelSelectMarketplaceSearchQuery = trimLastUtf8Character(self.levelSelectMarketplaceSearchQuery)
    self:clearLevelSelectActionState()
    self:getSelectedLevelMap()
    self:resetLevelSelectVisualIndex()
end

function Game:updateLevelSelectAnimation(dt)
    local pendingScrollDirections = self.levelSelectPendingScrollDirections or {}
    if #pendingScrollDirections > 0 then
        self.levelSelectPendingScrollDirections = {}
        for _, direction in ipairs(pendingScrollDirections) do
            self:moveLevelSelectSelection(direction)
        end
    end

    local maps = self:getLevelSelectMaps()
    local targetIndex = findLevelSelectIndex(self, maps)
    if not targetIndex then
        self.levelSelectVisualIndex = nil
        self.levelSelectTargetVisualIndex = nil
        return
    end

    if not self.levelSelectTargetVisualIndex then
        if self.levelSelectVisualIndex then
            self.levelSelectTargetVisualIndex = closestWrappedIndex(self.levelSelectVisualIndex, targetIndex, #maps)
        else
            self.levelSelectTargetVisualIndex = targetIndex
        end
    end

    if not self.levelSelectVisualIndex then
        self.levelSelectVisualIndex = self.levelSelectTargetVisualIndex
        return
    end

    local targetValue = self.levelSelectTargetVisualIndex

    local smoothing = 1 - math.exp(-dt * 12)
    self.levelSelectVisualIndex = self.levelSelectVisualIndex + ((targetValue - self.levelSelectVisualIndex) * smoothing)

    if math.abs(targetValue - self.levelSelectVisualIndex) < 0.001 then
        local normalizedTarget = normalizeWrappedIndex(targetValue, #maps)
        self.levelSelectVisualIndex = normalizedTarget
        self.levelSelectTargetVisualIndex = normalizedTarget
        if #maps > 0 then
            local normalizedIndex = normalizeWrappedIndex(normalizedTarget, #maps)
            self.levelSelectSelectedId = maps[normalizedIndex].id
            self.levelSelectSelectedMapUuid = maps[normalizedIndex].mapUuid
        end
    end
end

function Game:moveLevelSelectSelection(direction)
    local maps = self:getLevelSelectMaps()
    if #maps == 0 then
        self.levelSelectSelectedId = nil
        self.levelSelectTargetVisualIndex = nil
        self.levelSelectScroll = 0
        self:clearLevelSelectLeaderboardFlip()
        return nil
    end

    if not self.levelSelectTargetVisualIndex then
        local currentIndex = findLevelSelectIndex(self, maps) or 1
        if self.levelSelectVisualIndex then
            self.levelSelectTargetVisualIndex = closestWrappedIndex(self.levelSelectVisualIndex, currentIndex, #maps)
        else
            self.levelSelectTargetVisualIndex = currentIndex
        end
    end

    self.levelSelectTargetVisualIndex = self.levelSelectTargetVisualIndex + direction
    local nextIndex = normalizeWrappedIndex(self.levelSelectTargetVisualIndex, #maps)

    self.levelSelectSelectedId = maps[nextIndex].id
    self.levelSelectSelectedMapUuid = maps[nextIndex].mapUuid
    self:clearLevelSelectLeaderboardFlip()
    return maps[nextIndex]
end

function Game:scrollLevelSelect(delta)
    if delta == 0 then
        return
    end

    local steps = math.max(1, math.floor(math.abs(delta) + 0.5))
    local direction = delta > 0 and 1 or -1
    for _ = 1, steps do
        self:moveLevelSelectSelection(direction)
    end
end

function Game:toggleLevelSelectLeaderboardFlip(mapDescriptor)
    local mapUuid = mapDescriptor and mapDescriptor.mapUuid or nil
    if not mapUuid or mapUuid == "" then
        return
    end

    if self.levelSelectLeaderboardFlipMapUuid == mapUuid then
        self:clearLevelSelectLeaderboardFlip()
        return
    end

    self.levelSelectSelectedId = mapDescriptor.id
    self.levelSelectSelectedMapUuid = mapDescriptor.mapUuid
    self.levelSelectScroll = 0
    self.levelSelectLeaderboardFlipMapUuid = mapUuid
    local openStateOptions = levelSelectPreviewLogic.buildOpenStateOptions(self:isLevelSelectPreviewCacheFresh(mapUuid))
    self:setLevelSelectPreviewState(mapUuid, openStateOptions.status, nil, {
        forceImmediateFetch = openStateOptions.forceImmediateFetch,
        hasResolvedInitialRemoteAttempt = openStateOptions.hasResolvedInitialRemoteAttempt,
    })
end

function Game:getBuiltinShortcutMap(index)
    local builtinIndex = 0
    for _, descriptor in ipairs(self.availableMaps or {}) do
        if descriptor.source == "builtin" then
            builtinIndex = builtinIndex + 1
            if builtinIndex == index then
                return descriptor
            end
        end
    end
    return nil
end

function Game:openMenu()
    if not self:isProfileComplete() then
        self.screen = "profile_setup"
        return
    end

    if not self:isPlayModeConfigured() then
        self.screen = "profile_mode_setup"
        return
    end

    self.screen = "menu"
    self.levelSelectIssue = nil
    self.levelSelectHoverId = nil
    self.levelSelectHoverInfo = nil
    self:clearLevelSelectActionState()
    self.resultsSummary = nil
    self.playOverlayMode = nil
    self.playPhase = nil
    self:refreshMaps()
end

function Game:openLevelSelect()
    self.screen = "level_select"
    self.levelSelectIssue = nil
    self.levelSelectFilter = "campaign"
    self.levelSelectHoverId = nil
    self.levelSelectHoverInfo = nil
    self.levelSelectMode = LEVEL_SELECT_MODE_LIBRARY
    self.levelSelectMarketplaceTab = LEVEL_SELECT_MARKETPLACE_TAB_TOP
    self.levelSelectMarketplaceSearchQuery = ""
    self:clearLevelSelectActionState()
    self:clearLevelSelectLeaderboardFlip()
    self.resultsSummary = nil
    self.playOverlayMode = nil
    self.playPhase = nil
    self:refreshMaps()
    local preferredMap = self.currentMapDescriptor
    if preferredMap then
        local maps = self:getLevelSelectMaps()
        for _, descriptor in ipairs(maps) do
            if descriptor.id == preferredMap.id then
                self.levelSelectSelectedId = descriptor.id
                break
            end
        end
    end
    self:getSelectedLevelMap()
    self:resetLevelSelectVisualIndex()
    self.levelSelectScroll = 0
end

function Game:openEditorBlank()
    self.screen = "editor"
    self.levelSelectIssue = nil
    self.resultsSummary = nil
    self.playOverlayMode = nil
    self.playPhase = nil
    self.editor:resetFromMap(nil, nil)
end

function Game:openEditorMap(mapDescriptor)
    local mapData, loadError = mapStorage.loadMap(mapDescriptor)
    if not mapData then
        self.editor:showStatus(loadError or "That map could not be loaded into the editor.")
        self.screen = "editor"
        return false
    end

    if mapDescriptor and mapDescriptor.isRemoteImport then
        self:setLevelSelectActionState(
            LEVEL_SELECT_ACTION_STATUS_INFO,
            "Downloaded maps are read-only. Clone the map first to edit it."
        )
        return false
    end

    self.screen = "editor"
    self.levelSelectIssue = nil
    self.resultsSummary = nil
    self.playOverlayMode = nil
    self.playPhase = nil
    self.editor:resetFromMap(mapData, mapDescriptor)
    return true
end

function Game:showMapIssue(mapDescriptor, mapData, fallbackError)
    local errors = (mapData and mapData.validationErrors) or {}
    if #errors == 0 then
        errors = { fallbackError or "This map still has unresolved issues." }
    end

    self.levelSelectIssue = {
        map = mapDescriptor,
        errors = errors,
    }
end

function Game:startMap(mapDescriptor, options)
    local mapData, loadError = mapStorage.loadMap(mapDescriptor)
    if not mapData or not mapData.level then
        return false, loadError or "That map does not contain playable level data.", mapData
    end

    local startOptions = options or {}
    self.levelComplete = false
    self.failureReason = nil
    self.currentMapDescriptor = mapDescriptor
    self.currentRunOrigin = startOptions.origin
    self.levelSelectIssue = nil
    self.resultsSummary = nil
    self.resultsOnlineState = nil
    self.playOverlayMode = nil
    self.playPhase = "prepare"
    self.playHoverInfo = nil
    self.world = world.new(self.viewport.w, self.viewport.h, mapData.level)
    self.playGuide = self:buildPlayGuideState(mapData.level)
    self.playGuideTransition = nil
    self.screen = "play"
    return true
end

function Game:processEditorPlaytestRequest()
    local descriptor = self.editor:consumePlaytestRequest()
    if not descriptor then
        return
    end

    local ok, startError = self:startMap(descriptor, { origin = "editor" })
    if not ok then
        self.screen = "editor"
        self.editor:showStatus(startError or "The saved map could not be started.")
    end
end

function Game:processEditorOpenBlankRequest()
    if not self.editor:consumeOpenBlankMapRequest() then
        return false
    end

    self:openEditorBlank()
    return true
end

function Game:navigateBackFromRun()
    if self.currentRunOrigin == "editor" and self.currentMapDescriptor then
        if self:openEditorMap(self.currentMapDescriptor) then
            return
        end
    end

    self:openLevelSelect()
end

function Game:restart()
    if not self.currentMapDescriptor then
        return
    end

    self:startMap(self.currentMapDescriptor, { origin = self.currentRunOrigin })
end

function Game:isRunLocked()
    return self.levelComplete or self.failureReason ~= nil
end

function Game:isPreparingRun()
    return self.screen == "play" and self.playPhase == "prepare"
end

function Game:startPlayPhase()
    if not self.world or self.playPhase ~= "prepare" or self.playGuide then
        return false
    end

    self.playPhase = "play"
    self.playHoverInfo = nil
    return true
end

function Game:openResults()
    if not self.world then
        return
    end

    self.resultsSummary = self.world:getRunSummary()
    self.resultsHoverInfo = nil
    self.failureReason = self.resultsSummary.endReason == "level_clear" and nil or self.resultsSummary.endReason
    self.levelComplete = self.resultsSummary.endReason == "level_clear"
    self.screen = "results"
    self:submitResultsScore()
end

function Game:update(dt)
    self:updateLeaderboardFetchState()
    self:updatePlayGuideTransition(dt)

    if self.screen == "level_select" then
        self:updateLevelSelectAnimation(dt)
        return
    end

    if self.screen == "editor" then
        self.editor:update(dt)
        if self:processEditorOpenBlankRequest() then
            return
        end
        self:processEditorPlaytestRequest()
        return
    end

    if (self.screen ~= "play" and self.screen ~= "results") or not self.world then
        return
    end

    if self.screen == "results" or self:isRunLocked() then
        return
    end

    if self.playPhase ~= "play" then
        return
    end

    self.world:update(dt)
    self.failureReason = self.world:getFailureReason()
    self.levelComplete = self.world:isLevelComplete()
    if self.failureReason or self.levelComplete then
        self:openResults()
    end
end

function Game:draw()
    love.graphics.clear(0.02, 0.03, 0.04, 1)

    love.graphics.push()
    love.graphics.translate(self.renderOffsetX, self.renderOffsetY)
    love.graphics.scale(self.renderScale, self.renderScale)

    if self.screen == "menu" then
        ui.drawMenu(self)
    elseif self.screen == "profile_setup" then
        ui.drawProfileSetup(self)
    elseif self.screen == "profile_mode_setup" then
        ui.drawProfileModeSetup(self)
    elseif self.screen == "level_select" then
        ui.drawLevelSelect(self)
    elseif self.screen == "leaderboard" then
        ui.drawLeaderboard(self)
    elseif self.screen == "editor" then
        self.editor:draw(self)
    elseif self.screen == "results" then
        ui.drawResults(self)
    elseif self.screen == "play" and self.world then
        self.world:draw()
        ui.drawPlay(self)
    end

    love.graphics.pop()
end

function Game:resize(w, h)
    self.window.w = w
    self.window.h = h
    self:updateRenderTransform()
end

function Game:keypressed(key)
    if key == "escape" then
        if self.screen == "profile_setup" or self.screen == "profile_mode_setup" or self.screen == "menu" then
            love.event.quit()
        elseif self.screen == "leaderboard" then
            self:returnFromLeaderboard()
        elseif self.screen == "level_select" and self.levelSelectUploadDialog then
            self:closeLevelSelectUploadDialog()
        elseif self.screen == "level_select" and self.levelSelectIssue then
            self.levelSelectIssue = nil
        elseif self.screen == "editor" then
            if not self.editor:keypressed(key) then
                self:openMenu()
            end
        elseif self.screen == "play" or self.screen == "results" then
            self:navigateBackFromRun()
        else
            self:openMenu()
        end
        return
    end

    if self.screen == "profile_setup" then
        if key == "backspace" then
            self:backspaceProfileName()
        elseif key == "return" then
            self:confirmProfileSetup()
        end
        return
    end

    if self.screen == "profile_mode_setup" then
        if key == "left" or key == "up" then
            self:cycleProfileModeSelection(-1)
        elseif key == "right" or key == "down" then
            self:cycleProfileModeSelection(1)
        elseif key == "return" then
            self:confirmProfileModeSelection()
        end
        return
    end

    if self.screen == "menu" then
        if key == "return" or key == "space" then
            self:openLevelSelect()
        elseif key == "e" then
            self:openEditorBlank()
        elseif key == "l" then
            self:openLeaderboard({ returnScreen = "menu" })
        elseif key == "o" then
            self:togglePlayMode()
        end
        return
    end

    if self.screen == "leaderboard" then
        if key == "m" then
            self:returnFromLeaderboard()
        end
        return
    end

    if self.screen == "level_select" then
        if self.levelSelectUploadDialog then
            if key == "return" or key == "space" or key == "c" then
                self:copyLevelSelectUploadDialogId()
            end
            return
        end
        if self.levelSelectIssue and key == "return" then
            self:openEditorMap(self.levelSelectIssue.map)
            return
        end
        if key == "tab" then
            self:toggleLevelSelectMode()
            return
        end
        if self:isLevelSelectMarketplaceMode() then
            if key == "up" then
                self:cycleLevelSelectMarketplaceTab(-1)
                return
            end
            if key == "down" then
                self:cycleLevelSelectMarketplaceTab(1)
                return
            end
            if key == "left" then
                self:moveLevelSelectSelection(-1)
                return
            end
            if key == "right" then
                self:moveLevelSelectSelection(1)
                return
            end
            if key == "pageup" then
                self:scrollLevelSelect(-3)
                return
            end
            if key == "pagedown" then
                self:scrollLevelSelect(3)
                return
            end
            if key == "backspace" then
                self:backspaceLevelSelectMarketplaceSearch()
                return
            end
            return
        end
        if key == "left" then
            self:moveLevelSelectSelection(-1)
            return
        end
        if key == "right" then
            self:moveLevelSelectSelection(1)
            return
        end
        if key == "pageup" then
            self:scrollLevelSelect(-3)
            return
        end
        if key == "pagedown" then
            self:scrollLevelSelect(3)
            return
        end
        if key == "return" or key == "space" then
            local selectedMap = self:getSelectedLevelMap()
            if selectedMap then
                local ok, startError, mapData = self:startMap(selectedMap)
                if not ok then
                    self:showMapIssue(selectedMap, mapData, startError)
                end
            end
            return
        end
        if key == "e" then
            local selectedMap = self:getSelectedLevelMap()
            if selectedMap then
                if self:canCloneMapDescriptor(selectedMap) then
                    self:cloneMapForEditing(selectedMap)
                else
                    self:openEditorMap(selectedMap)
                end
            end
            return
        end
        local requestedLevel = input.getLevelShortcut(key)
        if requestedLevel then
            local descriptor = self:getBuiltinShortcutMap(requestedLevel)
            if descriptor then
                local ok, startError, mapData = self:startMap(descriptor)
                if not ok then
                    self:showMapIssue(descriptor, mapData, startError)
                end
            end
        end
        return
    end

    if self.screen == "editor" then
        if self.editor:keypressed(key) then
            self:refreshMaps()
            return
        end

        if key == "tab" then
            self:openMenu()
        end
        return
    end

    if self.screen == "results" then
        if key == "m" then
            self:navigateBackFromRun()
            return
        end
        if key == "l" then
            self:openLeaderboard({
                returnScreen = "results",
                mapUuid = self.resultsSummary and self.resultsSummary.mapUuid or nil,
            })
            return
        end
        if (key == "e" or key == "tab") and self.currentMapDescriptor then
            self:openEditorMap(self.currentMapDescriptor)
            return
        end
        if key == "r" or key == "return" or key == "space" then
            self:restart()
        end
        return
    end

    if self.screen ~= "play" or not self.world then
        return
    end

    if key == "f2" then
        if self.playOverlayMode == "help" then
            self.playOverlayMode = nil
        else
            self.playOverlayMode = "help"
        end
        return
    end

    if key == "f3" then
        if self.playOverlayMode == "debug" then
            self.playOverlayMode = nil
        else
            self.playOverlayMode = "debug"
        end
        return
    end

    if key == "m" then
        self:navigateBackFromRun()
        return
    end

    if key == "e" or key == "tab" then
        if self.currentMapDescriptor then
            self:openEditorMap(self.currentMapDescriptor)
        end
        return
    end

    if key == "r" then
        self:restart()
        return
    end

    if self.playGuide then
        if key == "return" or key == "space" then
            self:advancePlayGuide()
            return
        end
        if key == "s" then
            self:skipPlayGuide()
            return
        end
    end

    if self.playPhase == "prepare" and key == "space" then
        self:startPlayPhase()
        return
    end

    if self:isRunLocked() and (key == "return" or key == "space") then
        self:restart()
    end
end

function Game:textinput(text)
    if self.screen == "profile_setup" then
        self:appendProfileNameInput(text)
    elseif self.screen == "level_select" then
        if self.levelSelectUploadDialog then
            return
        end
        self:appendLevelSelectMarketplaceSearch(text)
    elseif self.screen == "editor" then
        self.editor:textinput(text)
    end
end

function Game:mousepressed(x, y, button)
    local viewportX, viewportY = self:toViewportPosition(x, y)

    if self.screen == "profile_setup" then
        local action = ui.getProfileSetupActionAt(self, viewportX, viewportY)
        if action == "confirm" then
            self:confirmProfileSetup()
        end
        return
    end

    if self.screen == "profile_mode_setup" then
        local action = ui.getProfileModeSetupActionAt(self, viewportX, viewportY)
        if action == PLAY_MODE_ONLINE or action == PLAY_MODE_OFFLINE then
            self.profileModeSelection = action
            self:confirmProfileModeSelection()
        elseif action == "confirm_mode" then
            self:confirmProfileModeSelection()
        end
        return
    end

    if self.screen == "menu" then
        local action = ui.getMenuActionAt(self, viewportX, viewportY)
        if action == "play" then
            self:openLevelSelect()
        elseif action == "leaderboard" then
            self:openLeaderboard({ returnScreen = "menu" })
        elseif action == "toggle_play_mode" then
            self:togglePlayMode()
        elseif action == "editor" then
            self:openEditorBlank()
        elseif action == "quit" then
            love.event.quit()
        end
        return
    end

    if self.screen == "leaderboard" then
        local action = ui.getLeaderboardActionAt(self, viewportX, viewportY)
        if action == "back" then
            self:returnFromLeaderboard()
            return
        end
        if action == "cycle_filter" then
            self:cycleLeaderboardMapFilter()
            return
        end

        local mapHit = ui.getLeaderboardMapHitAt(self, viewportX, viewportY)
        if mapHit then
            self:openLeaderboardForMap(mapHit.mapUuid, mapHit.mapName)
        end
        return
    end

    if self.screen == "level_select" then
        local hit = ui.getLevelSelectHit(self, viewportX, viewportY, button)
        if not hit then
            return
        end

        if hit.kind == "back" then
            self:openMenu()
        elseif hit.kind == "set_mode" then
            self:setLevelSelectMode(hit.mode)
        elseif hit.kind == "set_marketplace_tab" then
            self:setLevelSelectMarketplaceTab(hit.tab)
        elseif hit.kind == "set_filter" then
            self:setLevelSelectFilter(hit.filter)
        elseif hit.kind == "issue_edit" then
            self:openEditorMap(hit.map)
        elseif hit.kind == "issue_cancel" then
            self.levelSelectIssue = nil
        elseif hit.kind == "issue_blocked" then
            return
        elseif hit.kind == "upload_dialog_copy" then
            self:copyLevelSelectUploadDialogId()
        elseif hit.kind == "upload_dialog_close" then
            self:closeLevelSelectUploadDialog()
        elseif hit.kind == "upload_dialog_blocked" then
            return
        elseif hit.kind == "select_map" then
            self:setLevelSelectSelection(hit.map)
        elseif hit.kind == "download_map" then
            self:setLevelSelectSelection(hit.map)
            self:downloadMarketplaceMap(hit.map)
        elseif hit.kind == "favorite_map" then
            self:favoriteMarketplaceMap(hit.map)
        elseif hit.kind == "refresh_marketplace" then
            self:refreshMarketplaceData()
        elseif hit.kind == "upload_map" then
            self:setLevelSelectSelection(hit.map)
            self:uploadSelectedMap()
        elseif hit.kind == "toggle_leaderboard_card" then
            self:toggleLevelSelectLeaderboardFlip(hit.map)
        elseif hit.kind == "open_map" then
            self:setLevelSelectSelection(hit.map)
            local ok, startError, mapData = self:startMap(hit.map)
            if not ok then
                self:showMapIssue(hit.map, mapData, startError)
            end
        elseif hit.kind == "edit_map" then
            self:setLevelSelectSelection(hit.map)
            self:openEditorMap(hit.map)
        elseif hit.kind == "clone_map" then
            self:setLevelSelectSelection(hit.map)
            self:cloneMapForEditing(hit.map)
        end
        return
    end

    if self.screen == "editor" then
        self.editor:mousepressed(viewportX, viewportY, button)
        self:refreshMaps()
        return
    end

    if self.screen == "results" then
        if button ~= 1 then
            return
        end

        local hit = ui.getResultsHit(self, viewportX, viewportY)
        if not hit then
            return
        end

        if hit == "replay" then
            self:restart()
        elseif hit == "leaderboard" then
            self:openLeaderboard({
                returnScreen = "results",
                mapUuid = self.resultsSummary and self.resultsSummary.mapUuid or nil,
            })
        elseif hit == "menu" then
            self:navigateBackFromRun()
        elseif hit == "editor" and self.currentMapDescriptor then
            self:openEditorMap(self.currentMapDescriptor)
        end
        return
    end

    if self.screen ~= "play" or not self.world then
        return
    end

    if button ~= 1 and button ~= 2 then
        return
    end

    if self.playGuide then
        if button == 1 then
            local guideAction = ui.getPlayGuideActionAt(self, viewportX, viewportY)
            if guideAction == "next" then
                self:advancePlayGuide()
            elseif guideAction == "skip" then
                self:skipPlayGuide()
            elseif self:canInteractWithGuideControlDuringGuide(viewportX, viewportY) then
                self.world:handleClick(viewportX, viewportY, button, self.playPhase == "prepare")
            end
        elseif self:canInteractWithGuideControlDuringGuide(viewportX, viewportY) then
            self.world:handleClick(viewportX, viewportY, button, self.playPhase == "prepare")
        end
        return
    end

    if ui.getPlayBackHit(self, viewportX, viewportY) then
        self:navigateBackFromRun()
        return
    end

    if button == 1 and ui.getPlayStartHit(self, viewportX, viewportY) then
        self:startPlayPhase()
        return
    end

    self.world:handleClick(viewportX, viewportY, button, self.playPhase == "prepare")
end

function Game:mousemoved(x, y, dx, dy)
    self.playHoverInfo = nil
    self.resultsHoverInfo = nil
    self.levelSelectHoverInfo = nil
    if self.screen == "leaderboard" then
        local viewportX, viewportY = self:toViewportPosition(x, y)
        self.leaderboardHoverInfo = ui.getLeaderboardHoverInfoAt(self, viewportX, viewportY)
        return
    end

    if self.screen == "profile_mode_setup" then
        local viewportX, viewportY = self:toViewportPosition(x, y)
        self.profileModeHoverId = ui.getProfileModeSetupActionAt(self, viewportX, viewportY)
        return
    end

    if self.screen == "level_select" then
        local viewportX, viewportY = self:toViewportPosition(x, y)
        self.levelSelectHoverId = ui.getLevelSelectHoverId(self, viewportX, viewportY)
        self.levelSelectHoverInfo = ui.getLevelSelectHoverInfoAt(self, viewportX, viewportY)
        return
    end

    if self.screen == "editor" then
        local viewportX, viewportY = self:toViewportPosition(x, y)
        self.editor:mousemoved(viewportX, viewportY, dx, dy)
        return
    end

    if self.screen == "results" then
        local viewportX, viewportY = self:toViewportPosition(x, y)
        self.resultsHoverInfo = ui.getResultsHoverInfoAt(self, viewportX, viewportY)
        return
    end

    if self.screen == "play" and self.world then
        local viewportX, viewportY = self:toViewportPosition(x, y)
        self.playHoverInfo = ui.getPlayHoverInfoAt(self, viewportX, viewportY)
    end
end

function Game:mousereleased(x, y, button)
    if self.screen == "editor" then
        local viewportX, viewportY = self:toViewportPosition(x, y)
        self.editor:mousereleased(viewportX, viewportY, button)
        self:refreshMaps()
    end
end

function Game:keyreleased(_)
end

function Game:wheelmoved(screenX, screenY)
    if self.screen == "editor" then
        local mouseX, mouseY = love.mouse.getPosition()
        local viewportX, viewportY = self:toViewportPosition(mouseX, mouseY)
        return self.editor:wheelmoved(viewportX, viewportY, screenX, screenY)
    end

    local y = screenY
    if self.screen == "level_select" and not self.levelSelectIssue and y ~= 0 then
        local steps = math.max(1, math.floor(math.abs(y) + 0.5))
        local direction = y > 0 and -1 or 1
        self.levelSelectPendingScrollDirections = self.levelSelectPendingScrollDirections or {}
        for _ = 1, steps do
            self.levelSelectPendingScrollDirections[#self.levelSelectPendingScrollDirections + 1] = direction
        end
        return true
    end

    return false
end

function Game:gamepadpressed(_, button)
    if self.screen == "play" and (button == "start" or button == "a") then
        if self:isRunLocked() then
            self:restart()
        end
    end
end

function Game:gamepadreleased(_, _)
end

return Game
