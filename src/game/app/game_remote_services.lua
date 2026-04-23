return function(Game, shared)
    -- Reuse the original module scope through a shared lookup table during the extraction refactor.
    setfenv(1, setmetatable({ Game = Game }, {
        __index = function(_, key)
            local sharedValue = shared[key]
            if sharedValue ~= nil then
                return sharedValue
            end

            return _G[key]
        end,
    }))

local SCORE_SUBMIT_REQUEST_KIND_REPLAY = "replay_submit"
local SCORE_SUBMIT_REQUEST_KIND_SCORE = "score_submit"
local RESULTS_MESSAGE_REPLAY_UPLOAD_PENDING = "Uploading replay..."
local RESULTS_MESSAGE_REPLAY_UPLOAD_TIMEOUT = "The replay upload timed out."
local RESULTS_MESSAGE_REPLAY_UPLOAD_FAILED = "The replay upload failed."
local RESULTS_MESSAGE_SCORE_SUBMIT_PENDING = "Replay upload failed. Submitting the score only..."
local RESULTS_MESSAGE_SCORE_SUBMIT_SUCCESS = "Replay upload failed, but the score was submitted."
local RESULTS_MESSAGE_SCORE_SUBMIT_KEPT = "Replay upload failed. The score was valid, but it stayed outside the online leaderboard."
local RESULTS_MESSAGE_SCORE_SUBMIT_FAILED = "Replay upload failed, and the score fallback also failed."

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

local function getOnlineModeConfigurationError(onlineConfig)
    local errors = onlineConfig and onlineConfig.errors or nil
    if type(errors) == "table" and #errors > 0 then
        return table.concat(errors, " ")
    end

    return "The online marketplace is not configured."
end

function Game:isOnlineConfigAvailable()
    local onlineConfig = self:reloadOnlineConfig()
    return onlineConfig and onlineConfig.isConfigured == true
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

function Game:updateLocalReplayIndex(replayRecord, summary)
    local updatedReplayIndex, replayOutcomeOrError = mapReplayIndexStorage.updateReplayIndex(
        self.localReplayIndex or {},
        replayRecord,
        summary
    )
    if not updatedReplayIndex then
        return false, nil, replayOutcomeOrError
    end

    local savedReplayIndex, saveError = mapReplayIndexStorage.save(updatedReplayIndex)
    if not savedReplayIndex then
        return false, nil, saveError
    end

    self.localReplayIndex = savedReplayIndex

    for _, prunedEntry in ipairs(replayOutcomeOrError.prunedEntries or {}) do
        if tostring(prunedEntry.replayFilePath or "") ~= "" then
            replayStorage.delete(prunedEntry.replayFilePath)
        end
    end

    return true, replayOutcomeOrError.keptReplay == true, replayOutcomeOrError
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
end

local function clearActiveScoreSubmitRequestContext(game)
    game.activeScoreSubmitRequestId = nil
    game.activeScoreSubmitRequestStartedAt = nil
    game.activeScoreSubmitRequestKind = nil
    game.activeScoreSubmitRequestSummary = nil
    game.activeScoreSubmitRequestOnlineConfig = nil
    game.activeScoreSubmitFallbackAttempted = false
end

local function clearActiveScoreSubmitRequestInFlight(game)
    game.activeScoreSubmitRequestId = nil
    game.activeScoreSubmitRequestStartedAt = nil
    game.activeScoreSubmitRequestKind = nil
end

local function cloneActiveScoreSubmitConfig(onlineConfig)
    return {
        apiKey = onlineConfig.apiKey,
        apiBaseUrl = onlineConfig.apiBaseUrl,
        hmacSecret = onlineConfig.hmacSecret,
    }
end

function Game:setPlayMode(playMode)
    if playMode ~= PLAY_MODE_ONLINE and playMode ~= PLAY_MODE_OFFLINE then
        return false, "Select online or offline mode before continuing."
    end

    if playMode == PLAY_MODE_ONLINE then
        local onlineConfig = self:reloadOnlineConfig()
        if not (onlineConfig and onlineConfig.isConfigured) then
            self.profileModeSelection = PLAY_MODE_OFFLINE
            return false, getOnlineModeConfigurationError(onlineConfig)
        end
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

local function copyTextToClipboard(text, emptyMessage, successMessage, failureMessage)
    local resolvedText = tostring(text or "")
    if resolvedText == "" then
        return false, emptyMessage
    end

    if not (love and love.system and love.system.setClipboardText) then
        return false, "Clipboard copy is not available here."
    end

    local ok, copyError = pcall(love.system.setClipboardText, resolvedText)
    if not ok then
        return false, tostring(copyError or failureMessage)
    end

    return true, successMessage
end

function Game:copyLevelSelectUploadDialogId()
    local dialog = self.levelSelectUploadDialog
    if type(dialog) ~= "table" then
        return false, "No upload dialog is open."
    end

    local mapId = tostring(dialog.mapId or "")
    local ok, copyMessage = copyTextToClipboard(
        mapId,
        "No map ID was returned for this upload.",
        "Map ID copied to clipboard.",
        "The map ID could not be copied."
    )
    dialog.copyStatus = {
        status = ok and LEVEL_SELECT_ACTION_STATUS_SUCCESS or LEVEL_SELECT_ACTION_STATUS_ERROR,
        message = copyMessage,
    }
    self.levelSelectUploadDialog = dialog
    return ok, copyMessage
end

function Game:copyPlayDebugValue(copyText, copyLabel)
    local ok, copyMessage = copyTextToClipboard(
        copyText,
        string.format("No %s is available for this map.", tostring(copyLabel or "value")),
        string.format("%s copied to clipboard.", tostring(copyLabel or "Value")),
        string.format("The %s could not be copied.", tostring(copyLabel or "value"))
    )
    self.playOverlayCopyStatus = {
        status = ok and "success" or "error",
        message = copyMessage,
    }
    return ok, copyMessage
end

function Game:copyNetworkRequestOverlayValue(copyText, copyLabel)
    local ok, copyMessage = copyTextToClipboard(
        copyText,
        string.format("No %s is available for this request.", tostring(copyLabel or "value")),
        string.format("%s copied to clipboard.", tostring(copyLabel or "Value")),
        string.format("The %s could not be copied.", tostring(copyLabel or "value"))
    )
    self.networkRequestOverlayCopyStatus = {
        status = ok and "success" or "error",
        message = copyMessage,
    }
    return ok, copyMessage
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

local function buildLevelSelectPreviewCacheKey(mapUuid, mapHash)
    local resolvedMapUuid = tostring(mapUuid or "")
    local resolvedMapHash = tostring(mapHash or "")
    if resolvedMapUuid == "" then
        return ""
    end
    if resolvedMapHash == "" then
        return resolvedMapUuid
    end

    return string.format("%s:%s", resolvedMapUuid, resolvedMapHash)
end

function Game:setLevelSelectPreviewState(cacheKey, status, message, options)
    local resolvedOptions = options or {}
    self.levelSelectPreviewState = {
        cacheKey = cacheKey,
        mapUuid = resolvedOptions.mapUuid,
        mapHash = resolvedOptions.mapHash,
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

local function buildLevelSelectPreviewCacheEntry(mapUuid, mapHash, payload, fetchedAt)
    return {
        map_uuid = mapUuid,
        map_hash = tostring(mapHash or payload.map_hash or ""),
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

function Game:getLevelSelectPreviewCacheEntry(mapUuid, mapHash)
    local cacheKey = buildLevelSelectPreviewCacheKey(mapUuid, mapHash)
    if cacheKey == "" then
        return nil
    end

    local entry = self.levelSelectPreviewCacheByMap[cacheKey]
    if type(entry) ~= "table" then
        return nil
    end

    if tostring(entry.map_hash or "") ~= tostring(mapHash or "") then
        return nil
    end

    return entry
end

function Game:setLevelSelectPreviewCacheEntry(mapUuid, mapHash, entry)
    local cacheKey = buildLevelSelectPreviewCacheKey(mapUuid, mapHash)
    if cacheKey == "" then
        return
    end

    if type(entry) == "table" then
        self.levelSelectPreviewCacheByMap[cacheKey] = entry
    else
        self.levelSelectPreviewCacheByMap[cacheKey] = nil
    end

    leaderboardPreviewCache.save(self.levelSelectPreviewCacheByMap)
end

function Game:isLevelSelectPreviewCacheFresh(mapUuid, mapHash)
    local cacheEntry = self:getLevelSelectPreviewCacheEntry(mapUuid, mapHash)
    local fetchedAt = cacheEntry and tonumber(cacheEntry.fetched_at) or nil
    if not fetchedAt then
        return false
    end

    return (getNowUnixSeconds() - fetchedAt) < LEVEL_SELECT_PREVIEW_CACHE_DURATION_SECONDS
end

function Game:isLevelSelectPreviewFetchAllowed(mapUuid, mapHash)
    local cacheKey = buildLevelSelectPreviewCacheKey(mapUuid, mapHash)
    if cacheKey == "" then
        return false
    end

    return getNowUnixSeconds() >= (self.levelSelectPreviewNextFetchAtByMap[cacheKey] or 0)
end

function Game:getActiveLevelSelectPreviewMapDescriptor()
    if self.screen ~= "level_select" then
        return nil
    end

    local selectedMap = self:getSelectedLevelMap()
    local mapUuid = selectedMap and selectedMap.mapUuid or nil
    if mapUuid and mapUuid ~= "" and self.levelSelectLeaderboardFlipMapUuid == mapUuid then
        return selectedMap
    end

    return nil
end

function Game:clearLevelSelectLeaderboardFlip()
    self.levelSelectLeaderboardFlipMapUuid = nil
    self:setLevelSelectPreviewState(nil, LEVEL_SELECT_PREVIEW_STATUS_IDLE, nil)
end

function Game:getLevelSelectPreviewDisplayState(mapDescriptor)
    local resolvedMapDescriptor = type(mapDescriptor) == "table" and mapDescriptor or nil
    local mapUuid = resolvedMapDescriptor and resolvedMapDescriptor.mapUuid or nil
    local mapHash = resolvedMapDescriptor and resolvedMapDescriptor.mapHash or nil
    if self:isOfflineMode() then
        return self:getLocalLevelSelectPreviewDisplayState(mapUuid)
    end

    local cacheKey = buildLevelSelectPreviewCacheKey(mapUuid, mapHash)
    local cacheEntry = self:getLevelSelectPreviewCacheEntry(mapUuid, mapHash)
    local previewState = self.levelSelectPreviewState or {}
    local shouldShowCachedEntries = levelSelectPreviewLogic.shouldShowCachedEntries(previewState, cacheKey, cacheEntry ~= nil)
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
    local isLoading = self.activeLevelSelectPreviewRequestId ~= nil and self.activeLevelSelectPreviewRequestCacheKey == cacheKey
    local shouldShowSpinner = isLoading or (previewState.cacheKey == cacheKey and previewState.status == LEVEL_SELECT_PREVIEW_STATUS_LOADING)
    local message = nil

    if shouldShowSpinner and not shouldShowCachedEntries then
        message = LEVEL_SELECT_PREVIEW_MESSAGE_LOADING
    elseif shouldShowCachedEntries and hasCache and not hasVisibleEntries and not playerEntry then
        message = LEVEL_SELECT_PREVIEW_MESSAGE_EMPTY
    elseif previewState.cacheKey == cacheKey and previewState.status == LEVEL_SELECT_PREVIEW_STATUS_ERROR and not shouldShowCachedEntries then
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
            self.levelSelectPreviewNextFetchAtByMap[cacheKey],
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
    local mapHash = tostring(response.map_hash or (self.currentMapDescriptor and self.currentMapDescriptor.mapHash) or "")
    if mapUuid == "" then
        return
    end

    local submittedEntry = {
        display_name = response.display_name or self.profile.playerDisplayName or "Unknown",
        map_uuid = mapUuid,
        player_uuid = response.player_uuid or getProfilePlayerUuid(self.profile),
        rank = tonumber(response.rank) or nil,
        score = tonumber(response.score or 0) or 0,
        replay_uuid = tostring(response.replay_uuid or response.replayUuid or ""),
        duration_seconds = tonumber(response.duration_seconds or 0) or 0,
        updated_at = response.updated_at,
    }

    local cacheEntry = self:getLevelSelectPreviewCacheEntry(mapUuid, mapHash) or {
        map_uuid = mapUuid,
        map_hash = mapHash,
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
    cacheEntry.map_hash = mapHash
    cacheEntry.fetched_at = getNowUnixSeconds()
    self:setLevelSelectPreviewCacheEntry(mapUuid, mapHash, cacheEntry)
end

local function copyNetworkRequestLogFields(targetEntry, sourceEntry)
    for key, value in pairs(sourceEntry or {}) do
        targetEntry[key] = value
    end
end

function Game:trimNetworkRequestLog()
    while #self.networkRequestLogEntries > NETWORK_REQUEST_LOG_MAX_ENTRIES do
        local removedEntry = table.remove(self.networkRequestLogEntries)
        if removedEntry and removedEntry.requestDebugId ~= nil then
            self.networkRequestLogEntryById[removedEntry.requestDebugId] = nil
            if self.networkRequestSelectedLogEntryId == removedEntry.requestDebugId then
                self.networkRequestSelectedLogEntryId = self.networkRequestLogEntries[1]
                    and self.networkRequestLogEntries[1].requestDebugId
                    or nil
            end
        end
    end
end

function Game:applyNetworkRequestDebugEvent(event)
    if type(event) ~= "table" or event.eventKind ~= "network_request_debug" then
        return
    end

    local requestDebugId = tonumber(event.requestDebugId)
    if not requestDebugId then
        return
    end

    local existingEntry = self.networkRequestLogEntryById[requestDebugId]
    if existingEntry then
        copyNetworkRequestLogFields(existingEntry, event)
    else
        local createdEntry = {}
        copyNetworkRequestLogFields(createdEntry, event)
        self.networkRequestLogEntryById[requestDebugId] = createdEntry
        table.insert(self.networkRequestLogEntries, 1, createdEntry)
        self:trimNetworkRequestLog()
        existingEntry = createdEntry
    end

    if self.networkRequestSelectedLogEntryId == nil or event.phase == "started" then
        self.networkRequestSelectedLogEntryId = requestDebugId
    end
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
            player_uuid = getProfilePlayerUuid(self.profile),
            size = LEADERBOARD_ENTRY_LIMIT,
            mapUuid = self.leaderboardMapUuid,
        },
    }))
end

function Game:beginLevelSelectPreviewFetch(onlineConfig, mapDescriptor)
    local resolvedMapDescriptor = type(mapDescriptor) == "table" and mapDescriptor or nil
    local mapUuid = resolvedMapDescriptor and tostring(resolvedMapDescriptor.mapUuid or "") or ""
    local mapHash = resolvedMapDescriptor and tostring(resolvedMapDescriptor.mapHash or "") or ""
    if self.activeLevelSelectPreviewRequestId ~= nil or mapUuid == "" or mapHash == "" then
        return
    end

    self:ensureLeaderboardWorker()
    local cacheKey = buildLevelSelectPreviewCacheKey(mapUuid, mapHash)
    local cacheEntry = self:getLevelSelectPreviewCacheEntry(mapUuid, mapHash)
    local previewState = self.levelSelectPreviewState or {}
    local showCachedWhileLoading = previewState.cacheKey == cacheKey
        and previewState.hasResolvedInitialRemoteAttempt
        and cacheEntry ~= nil
    self.levelSelectPreviewRequestSequence = self.levelSelectPreviewRequestSequence + 1
    self.activeLevelSelectPreviewRequestId = self.levelSelectPreviewRequestSequence
    self.activeLevelSelectPreviewRequestStartedAt = getNowSeconds()
    self.activeLevelSelectPreviewRequestMapUuid = mapUuid
    self.activeLevelSelectPreviewRequestMapHash = mapHash
    self.activeLevelSelectPreviewRequestCacheKey = cacheKey
    self:setLevelSelectPreviewState(cacheKey, LEVEL_SELECT_PREVIEW_STATUS_LOADING, nil, {
        mapUuid = mapUuid,
        mapHash = mapHash,
        forceImmediateFetch = false,
        showCachedWhileLoading = showCachedWhileLoading,
        hasResolvedInitialRemoteAttempt = previewState.cacheKey == cacheKey and previewState.hasResolvedInitialRemoteAttempt or false,
    })
    self.leaderboardRequestChannel:push(json.encode({
        kind = "preview",
        requestId = self.activeLevelSelectPreviewRequestId,
        config = {
            apiKey = onlineConfig.apiKey,
            apiBaseUrl = onlineConfig.apiBaseUrl,
            include_replay = true,
            mapUuid = mapUuid,
            mapHash = mapHash,
            player_uuid = getProfilePlayerUuid(self.profile),
            size = LEVEL_SELECT_PREVIEW_ENTRY_LIMIT,
        },
    }))
end

local function extractReplayRecordFromPayload(payload)
    if type(payload) ~= "table" then
        return nil
    end

    if type(payload.replay) == "table" then
        return deepCopy(payload.replay)
    end

    if type(payload.replay_json) == "string" then
        local decodedReplay = json.decode(payload.replay_json)
        if type(decodedReplay) == "table" then
            return decodedReplay
        end
    end

    if type(payload.replayJson) == "string" then
        local decodedReplay = json.decode(payload.replayJson)
        if type(decodedReplay) == "table" then
            return decodedReplay
        end
    end

    if payload.cursorSamples or payload.timelineEvents or payload.initialJunctions or payload.interactions then
        return deepCopy(payload)
    end

    return nil
end

function Game:getReplayLevelSourceForDescriptor(mapDescriptor)
    if type(mapDescriptor) ~= "table" then
        return nil, "The selected map could not be resolved for replay."
    end

    if type(mapDescriptor.previewLevel) == "table" then
        return deepCopy(mapDescriptor.previewLevel)
    end

    local mapData, mapError = mapStorage.loadMap(mapDescriptor)
    if not mapData or not mapData.level then
        return nil, mapError or "The selected map could not be loaded for replay."
    end

    return deepCopy(mapData.level)
end

function Game:beginReplayDownloadRequest(onlineConfig, mapDescriptor, replayEntry)
    if self.activeReplayDownloadRequestId ~= nil then
        return false
    end

    local resolvedMapDescriptor = type(mapDescriptor) == "table" and mapDescriptor or nil
    local resolvedReplayEntry = type(replayEntry) == "table" and replayEntry or nil
    local mapUuid = tostring(resolvedMapDescriptor and resolvedMapDescriptor.mapUuid or "")
    local replayUuid = tostring(resolvedReplayEntry and resolvedReplayEntry.replayUuid or "")
    if mapUuid == "" or replayUuid == "" then
        return false
    end

    self:ensureLeaderboardWorker()
    self.remoteWriteRequestSequence = self.remoteWriteRequestSequence + 1
    self.activeReplayDownloadRequestId = self.remoteWriteRequestSequence
    self.activeReplayDownloadRequestStartedAt = getNowSeconds()
    self.activeReplayDownloadMapDescriptor = resolvedMapDescriptor
    self.activeReplayDownloadEntry = resolvedReplayEntry
    self.activeReplayDownloadRequestMapUuid = mapUuid
    self.activeReplayDownloadRequestMapHash = tostring(resolvedMapDescriptor.mapHash or "")
    self:setLevelSelectActionState(LEVEL_SELECT_ACTION_STATUS_INFO, "Downloading replay...")
    self.leaderboardRequestChannel:push(json.encode({
        kind = "replay_fetch",
        requestId = self.activeReplayDownloadRequestId,
        config = {
            apiKey = onlineConfig.apiKey,
            apiBaseUrl = onlineConfig.apiBaseUrl,
            mapUuid = mapUuid,
            replayUuid = replayUuid,
        },
    }))
    return true
end

function Game:applyReplayDownloadResult(response, mapDescriptor, replayEntry)
    local resolvedMapDescriptor = type(mapDescriptor) == "table" and mapDescriptor or nil
    local resolvedReplayEntry = type(replayEntry) == "table" and replayEntry or nil
    if not resolvedMapDescriptor then
        self:setLevelSelectActionState(LEVEL_SELECT_ACTION_STATUS_ERROR, "The replay target map is missing.")
        return
    end

    if not response.ok or type(response.payload) ~= "table" then
        self:setLevelSelectActionState(
            LEVEL_SELECT_ACTION_STATUS_ERROR,
            response.error or "The replay could not be downloaded."
        )
        return
    end

    local replayRecord = extractReplayRecordFromPayload(response.payload)
    if type(replayRecord) ~= "table" then
        self:setLevelSelectActionState(
            LEVEL_SELECT_ACTION_STATUS_ERROR,
            "The replay response did not include a valid replay payload."
        )
        return
    end

    replayRecord.replayId = replayRecord.replayId
        or response.payload.replay_uuid
        or response.payload.replayUuid
        or (resolvedReplayEntry and resolvedReplayEntry.replayUuid)
    replayRecord.mapUuid = replayRecord.mapUuid or resolvedMapDescriptor.mapUuid
    replayRecord.mapHash = replayRecord.mapHash or resolvedMapDescriptor.mapHash
    replayRecord.mapTitle = replayRecord.mapTitle or resolvedMapDescriptor.displayName or resolvedMapDescriptor.name
    replayRecord.duration = tonumber(replayRecord.duration or response.payload.duration_seconds or (resolvedReplayEntry and resolvedReplayEntry.durationSeconds) or 0) or 0
    replayRecord.createdAt = replayRecord.createdAt or response.payload.created_at or response.payload.updated_at
    replayRecord.endReason = replayRecord.endReason or response.payload.end_reason or response.payload.endReason

    if tostring(replayRecord.mapUuid or "") ~= tostring(resolvedMapDescriptor.mapUuid or "")
        or tostring(replayRecord.mapHash or "") ~= tostring(resolvedMapDescriptor.mapHash or "") then
        self:setLevelSelectActionState(
            LEVEL_SELECT_ACTION_STATUS_ERROR,
            "The downloaded replay does not match the selected map revision."
        )
        return
    end

    local savedReplayRecord, saveError = replayStorage.save(replayRecord)
    local resolvedReplayRecord = savedReplayRecord or replayRecord
    resolvedReplayRecord.localSaveError = saveError

    local summary = {
        mapUuid = resolvedMapDescriptor.mapUuid,
        mapHash = resolvedMapDescriptor.mapHash,
        finalScore = resolvedReplayEntry and resolvedReplayEntry.score or response.payload.score or 0,
        recorded_at = resolvedReplayEntry and resolvedReplayEntry.createdAt or response.payload.created_at or response.payload.updated_at,
        endReason = replayRecord.endReason or (resolvedReplayEntry and resolvedReplayEntry.endReason) or "",
        mapTitle = resolvedMapDescriptor.displayName or resolvedMapDescriptor.name,
    }
    if savedReplayRecord then
        self:updateLocalReplayIndex(resolvedReplayRecord, summary)
    end

    local replayLevelSource, levelError = self:getReplayLevelSourceForDescriptor(resolvedMapDescriptor)
    if not replayLevelSource then
        self:setLevelSelectActionState(LEVEL_SELECT_ACTION_STATUS_ERROR, levelError or "The replay map could not be loaded.")
        return
    end

    self.currentMapDescriptor = resolvedMapDescriptor
    self.currentRunOrigin = "level_select"
    self.resultsSummary = nil
    self.replayRecord = resolvedReplayRecord
    self.replayLevelSource = replayLevelSource
    self.replayHoverInfo = nil
    self.replayDragActive = false
    self.replayDragTime = nil
    self:clearLevelSelectActionState()
    self:openReplay()
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

function Game:applyLevelSelectPreviewFetchResult(response, mapUuid, mapHash)
    if not mapUuid or mapUuid == "" then
        return
    end

    local cacheKey = buildLevelSelectPreviewCacheKey(mapUuid, mapHash)
    local cacheEntry = self:getLevelSelectPreviewCacheEntry(mapUuid, mapHash)
    local previewState = self.levelSelectPreviewState or {}
    if response.ok and type(response.payload) == "table" then
        local fetchedAt = getNowUnixSeconds()
        local payloadToPersist = levelSelectPreviewLogic.getPayloadToPersistAfterFetch(response.payload, cacheEntry)
        self.levelSelectPreviewNextFetchAtByMap[cacheKey] = fetchedAt + LEVEL_SELECT_PREVIEW_CACHE_DURATION_SECONDS
        if not levelSelectPreviewPayloadHasData(response.payload) and cacheEntry ~= nil then
            self:setLevelSelectPreviewCacheEntry(mapUuid, mapHash, buildLevelSelectPreviewCacheEntry(mapUuid, mapHash, payloadToPersist, fetchedAt))
            self:setLevelSelectPreviewState(cacheKey, LEVEL_SELECT_PREVIEW_STATUS_READY, nil, {
                mapUuid = mapUuid,
                mapHash = mapHash,
                hasResolvedInitialRemoteAttempt = true,
            })
            return
        end

        if previewState.cacheKey == cacheKey and previewState.showCachedWhileLoading and cacheEntry ~= nil then
            self:setLevelSelectPreviewState(cacheKey, LEVEL_SELECT_PREVIEW_STATUS_LOADING, nil, {
                mapUuid = mapUuid,
                mapHash = mapHash,
                hasResolvedInitialRemoteAttempt = true,
                clearVisibleEntries = true,
                pendingPayload = response.payload,
                pendingFetchedAt = fetchedAt,
                pendingDelayFrames = LEVEL_SELECT_PREVIEW_DISPLAY_SWAP_DELAY_FRAMES,
            })
            return
        end

        self:setLevelSelectPreviewCacheEntry(mapUuid, mapHash, buildLevelSelectPreviewCacheEntry(mapUuid, mapHash, payloadToPersist, fetchedAt))
        self:setLevelSelectPreviewState(cacheKey, LEVEL_SELECT_PREVIEW_STATUS_READY, nil, {
            mapUuid = mapUuid,
            mapHash = mapHash,
            hasResolvedInitialRemoteAttempt = true,
        })
        return
    end

    self.levelSelectPreviewNextFetchAtByMap[cacheKey] = getNowUnixSeconds() + LEVEL_SELECT_PREVIEW_CACHE_DURATION_SECONDS
    if cacheEntry then
        self:setLevelSelectPreviewState(cacheKey, LEVEL_SELECT_PREVIEW_STATUS_READY, nil, {
            mapUuid = mapUuid,
            mapHash = mapHash,
            hasResolvedInitialRemoteAttempt = true,
        })
        return
    end

    self:setLevelSelectPreviewState(cacheKey, LEVEL_SELECT_PREVIEW_STATUS_ERROR, LEVEL_SELECT_PREVIEW_MESSAGE_NO_LOCAL_DATA, {
        mapUuid = mapUuid,
        mapHash = mapHash,
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
            mapHash = mapData.mapHash,
            mapName = mapData.name or selectedMap.displayName or selectedMap.name,
            playerDisplayName = self.profile and self.profile.playerDisplayName or "",
            mapUuid = mapData.mapUuid or selectedMap.mapUuid,
            mode = "upload_map",
        },
    }))
    return true
end

function Game:beginReplaySubmitRequest(onlineConfig, summary, replayRecord)
    if self.activeScoreSubmitRequestId ~= nil then
        return false
    end

    local replayMapUuid = summary.mapUuid or (replayRecord and replayRecord.mapUuid) or nil
    local replayMapHash = replayRecord and replayRecord.mapHash or summary.mapHash or nil
    self:ensureLeaderboardWorker()
    self.remoteWriteRequestSequence = self.remoteWriteRequestSequence + 1
    self.activeScoreSubmitRequestId = self.remoteWriteRequestSequence
    self.activeScoreSubmitRequestStartedAt = getNowSeconds()
    self.activeScoreSubmitRequestKind = SCORE_SUBMIT_REQUEST_KIND_REPLAY
    self.activeScoreSubmitRequestSummary = {
        finalScore = tonumber(summary.finalScore or 0) or 0,
        mapHash = replayMapHash,
        mapUuid = replayMapUuid,
    }
    self.activeScoreSubmitRequestOnlineConfig = cloneActiveScoreSubmitConfig(onlineConfig)
    self.activeScoreSubmitFallbackAttempted = false
    self.leaderboardRequestChannel:push(json.encode({
        kind = SCORE_SUBMIT_REQUEST_KIND_REPLAY,
        requestId = self.activeScoreSubmitRequestId,
        config = {
            apiKey = onlineConfig.apiKey,
            apiBaseUrl = onlineConfig.apiBaseUrl,
            hmacSecret = onlineConfig.hmacSecret,
            mapUuid = replayMapUuid,
            mapHash = replayMapHash,
            mode = SCORE_SUBMIT_REQUEST_KIND_REPLAY,
            playerDisplayName = self.profile.playerDisplayName,
            player_uuid = getProfilePlayerUuid(self.profile),
            score = summary.finalScore or 0,
            replay = replayStorage.toJsonPayload(replayRecord or {}),
        },
    }))
    return true
end

function Game:beginScoreSubmitRequest(onlineConfig, summary)
    if self.activeScoreSubmitRequestId ~= nil then
        return false
    end

    local resolvedSummary = type(summary) == "table" and summary or nil
    if not resolvedSummary then
        return false
    end

    self:ensureLeaderboardWorker()
    self.remoteWriteRequestSequence = self.remoteWriteRequestSequence + 1
    self.activeScoreSubmitRequestId = self.remoteWriteRequestSequence
    self.activeScoreSubmitRequestStartedAt = getNowSeconds()
    self.activeScoreSubmitRequestKind = SCORE_SUBMIT_REQUEST_KIND_SCORE
    self.leaderboardRequestChannel:push(json.encode({
        kind = SCORE_SUBMIT_REQUEST_KIND_SCORE,
        requestId = self.activeScoreSubmitRequestId,
        config = {
            apiKey = onlineConfig.apiKey,
            apiBaseUrl = onlineConfig.apiBaseUrl,
            hmacSecret = onlineConfig.hmacSecret,
            mapUuid = resolvedSummary.mapUuid,
            mapHash = resolvedSummary.mapHash,
            mode = SCORE_SUBMIT_REQUEST_KIND_SCORE,
            playerDisplayName = self.profile.playerDisplayName,
            player_uuid = getProfilePlayerUuid(self.profile),
            score = resolvedSummary.finalScore or 0,
        },
    }))
    return true
end

function Game:attemptScoreSubmitFallback()
    if self.activeScoreSubmitFallbackAttempted == true then
        return false
    end

    local onlineConfig = self.activeScoreSubmitRequestOnlineConfig
    local summary = self.activeScoreSubmitRequestSummary
    if type(onlineConfig) ~= "table" or type(summary) ~= "table" then
        return false
    end

    self.activeScoreSubmitFallbackAttempted = true
    self.resultsOnlineState = {
        status = "pending",
        message = RESULTS_MESSAGE_SCORE_SUBMIT_PENDING,
    }
    return self:beginScoreSubmitRequest(onlineConfig, summary)
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
    local mapHash = previewState.mapHash
    local cacheKey = buildLevelSelectPreviewCacheKey(mapUuid, mapHash)
    local fetchedAt = tonumber(previewState.pendingFetchedAt) or getNowUnixSeconds()
    self:setLevelSelectPreviewCacheEntry(mapUuid, mapHash, buildLevelSelectPreviewCacheEntry(mapUuid, mapHash, previewState.pendingPayload, fetchedAt))
    self:setLevelSelectPreviewState(cacheKey, LEVEL_SELECT_PREVIEW_STATUS_READY, nil, {
        mapUuid = mapUuid,
        mapHash = mapHash,
        hasResolvedInitialRemoteAttempt = true,
    })
    return true
end

function Game:updateLeaderboardFetchState()
    self:applyPendingLevelSelectPreviewSwap()

    local requestScopeKey = self.activeLeaderboardRequestScopeKey or getLeaderboardScopeKey(self.leaderboardMapUuid)
    local cacheEntry = self:getLeaderboardCacheEntry(requestScopeKey)
    local activePreviewMapUuid = self.activeLevelSelectPreviewRequestMapUuid
    local activePreviewMapHash = self.activeLevelSelectPreviewRequestMapHash
    local previewCacheEntry = self:getLevelSelectPreviewCacheEntry(activePreviewMapUuid, activePreviewMapHash)
    local marketplaceScopeKey = self.activeMarketplaceRequestScopeKey
    local activeFavoriteMapUuid = self.activeFavoriteMapMapUuid

    if self.leaderboardWorkerThread and (
        self.activeLeaderboardRequestId ~= nil
        or self.activeLevelSelectPreviewRequestId ~= nil
        or self.activeMarketplaceRequestId ~= nil
        or self.activeFavoriteMapRequestId ~= nil
        or self.activeUploadMapRequestId ~= nil
        or self.activeScoreSubmitRequestId ~= nil
        or self.activeReplayDownloadRequestId ~= nil
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
                    local previewCacheKey = buildLevelSelectPreviewCacheKey(activePreviewMapUuid, activePreviewMapHash)
                    self.levelSelectPreviewNextFetchAtByMap[previewCacheKey] = getNowUnixSeconds() + LEVEL_SELECT_PREVIEW_CACHE_DURATION_SECONDS
                    if previewCacheEntry then
                        self:setLevelSelectPreviewState(previewCacheKey, LEVEL_SELECT_PREVIEW_STATUS_READY, nil, {
                            mapUuid = activePreviewMapUuid,
                            mapHash = activePreviewMapHash,
                            hasResolvedInitialRemoteAttempt = true,
                        })
                    else
                        self:setLevelSelectPreviewState(previewCacheKey, LEVEL_SELECT_PREVIEW_STATUS_ERROR, LEVEL_SELECT_PREVIEW_MESSAGE_NO_LOCAL_DATA, {
                            mapUuid = activePreviewMapUuid,
                            mapHash = activePreviewMapHash,
                            hasResolvedInitialRemoteAttempt = true,
                        })
                    end
                end
                self.activeLevelSelectPreviewRequestMapUuid = nil
                self.activeLevelSelectPreviewRequestMapHash = nil
                self.activeLevelSelectPreviewRequestCacheKey = nil
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
                local uploadOrigin = self.activeUploadMapOrigin
                self.activeUploadMapRequestId = nil
                self.activeUploadMapRequestStartedAt = nil
                self.activeUploadMapDescriptor = nil
                self.activeUploadMapOrigin = nil
                self:showUploadFailureMessage(uploadOrigin, threadError)
            end

            if self.activeScoreSubmitRequestId ~= nil then
                local requestKind = self.activeScoreSubmitRequestKind
                clearActiveScoreSubmitRequestInFlight(self)
                if requestKind == SCORE_SUBMIT_REQUEST_KIND_REPLAY and self:attemptScoreSubmitFallback() then
                    return
                end
                clearActiveScoreSubmitRequestContext(self)
                self.resultsOnlineState = {
                    status = "error",
                    message = requestKind == SCORE_SUBMIT_REQUEST_KIND_SCORE
                        and (RESULTS_MESSAGE_SCORE_SUBMIT_FAILED .. " " .. tostring(threadError))
                        or threadError,
                }
            end

            if self.activeReplayDownloadRequestId ~= nil then
                self.activeReplayDownloadRequestId = nil
                self.activeReplayDownloadRequestStartedAt = nil
                self.activeReplayDownloadMapDescriptor = nil
                self.activeReplayDownloadEntry = nil
                self.activeReplayDownloadRequestMapUuid = nil
                self.activeReplayDownloadRequestMapHash = nil
                self:setLevelSelectActionState(LEVEL_SELECT_ACTION_STATUS_ERROR, threadError)
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
            local previewMapHash = self.activeLevelSelectPreviewRequestMapHash
            self.activeLevelSelectPreviewRequestId = nil
            self.activeLevelSelectPreviewRequestStartedAt = nil
            if previewMapUuid and previewMapUuid ~= "" then
                local previewCacheKey = buildLevelSelectPreviewCacheKey(previewMapUuid, previewMapHash)
                self.levelSelectPreviewNextFetchAtByMap[previewCacheKey] = getNowUnixSeconds() + LEVEL_SELECT_PREVIEW_CACHE_DURATION_SECONDS
                if self:getLevelSelectPreviewCacheEntry(previewMapUuid, previewMapHash) then
                    self:setLevelSelectPreviewState(previewCacheKey, LEVEL_SELECT_PREVIEW_STATUS_READY, nil, {
                        mapUuid = previewMapUuid,
                        mapHash = previewMapHash,
                        hasResolvedInitialRemoteAttempt = true,
                    })
                else
                    self:setLevelSelectPreviewState(previewCacheKey, LEVEL_SELECT_PREVIEW_STATUS_ERROR, LEVEL_SELECT_PREVIEW_MESSAGE_NO_LOCAL_DATA, {
                        mapUuid = previewMapUuid,
                        mapHash = previewMapHash,
                        hasResolvedInitialRemoteAttempt = true,
                    })
                end
            end
            self.activeLevelSelectPreviewRequestMapUuid = nil
            self.activeLevelSelectPreviewRequestMapHash = nil
            self.activeLevelSelectPreviewRequestCacheKey = nil
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
            local uploadOrigin = self.activeUploadMapOrigin
            self.activeUploadMapRequestId = nil
            self.activeUploadMapRequestStartedAt = nil
            self.activeUploadMapDescriptor = nil
            self.activeUploadMapOrigin = nil
            self:showUploadFailureMessage(uploadOrigin, "The map upload timed out.")
        end
    end

    if self.activeScoreSubmitRequestId ~= nil and self.activeScoreSubmitRequestStartedAt ~= nil then
        local elapsedSeconds = getNowSeconds() - self.activeScoreSubmitRequestStartedAt
        if elapsedSeconds >= ONLINE_WRITE_TIMEOUT_SECONDS then
            local requestKind = self.activeScoreSubmitRequestKind
            clearActiveScoreSubmitRequestInFlight(self)
            if requestKind == SCORE_SUBMIT_REQUEST_KIND_REPLAY and self:attemptScoreSubmitFallback() then
                return
            end
            clearActiveScoreSubmitRequestContext(self)
            self.resultsOnlineState = {
                status = "error",
                message = requestKind == SCORE_SUBMIT_REQUEST_KIND_SCORE
                    and RESULTS_MESSAGE_SCORE_SUBMIT_FAILED
                    or RESULTS_MESSAGE_REPLAY_UPLOAD_TIMEOUT,
            }
        end
    end

    if self.activeReplayDownloadRequestId ~= nil and self.activeReplayDownloadRequestStartedAt ~= nil then
        local elapsedSeconds = getNowSeconds() - self.activeReplayDownloadRequestStartedAt
        if elapsedSeconds >= ONLINE_WRITE_TIMEOUT_SECONDS then
            self.activeReplayDownloadRequestId = nil
            self.activeReplayDownloadRequestStartedAt = nil
            self.activeReplayDownloadMapDescriptor = nil
            self.activeReplayDownloadEntry = nil
            self.activeReplayDownloadRequestMapUuid = nil
            self.activeReplayDownloadRequestMapHash = nil
            self:setLevelSelectActionState(LEVEL_SELECT_ACTION_STATUS_ERROR, "The replay download timed out.")
        end
    end

    while true do
        local encodedDebugEvent = self.networkRequestDebugChannel:pop()
        if not encodedDebugEvent then
            break
        end

        local decodedDebugEvent = json.decode(encodedDebugEvent)
        self:applyNetworkRequestDebugEvent(decodedDebugEvent)
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
            local previewMapHash = self.activeLevelSelectPreviewRequestMapHash
            self.activeLevelSelectPreviewRequestId = nil
            self.activeLevelSelectPreviewRequestStartedAt = nil
            self.activeLevelSelectPreviewRequestMapUuid = nil
            self.activeLevelSelectPreviewRequestMapHash = nil
            self.activeLevelSelectPreviewRequestCacheKey = nil
            self:applyLevelSelectPreviewFetchResult(decodedResponse, previewMapUuid, previewMapHash)
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
            local uploadOrigin = self.activeUploadMapOrigin
            self.activeUploadMapRequestId = nil
            self.activeUploadMapRequestStartedAt = nil
            self.activeUploadMapDescriptor = nil
            self.activeUploadMapOrigin = nil
            if decodedResponse.ok and type(decodedResponse.payload) == "table" then
                self:showUploadSuccessMessage(uploadOrigin, decodedResponse.payload, uploadedMapDescriptor)
            else
                local statusCode = tonumber(decodedResponse.status)
                local failureMessage = decodedResponse.error or "The map upload failed."
                if statusCode then
                    failureMessage = string.format("Map upload failed (HTTP %d): %s", statusCode, tostring(failureMessage))
                end
                self:showUploadFailureMessage(uploadOrigin, failureMessage)
            end
        elseif type(decodedResponse) == "table"
            and decodedResponse.requestId == self.activeScoreSubmitRequestId
            and (
                decodedResponse.kind == SCORE_SUBMIT_REQUEST_KIND_REPLAY
                or decodedResponse.kind == SCORE_SUBMIT_REQUEST_KIND_SCORE
            )
        then
            local requestKind = self.activeScoreSubmitRequestKind
            clearActiveScoreSubmitRequestInFlight(self)
            if decodedResponse.ok and type(decodedResponse.payload) == "table" then
                self.resultsOnlineState = {
                    status = decodedResponse.status == 202 and "kept" or "submitted",
                    message = requestKind == SCORE_SUBMIT_REQUEST_KIND_SCORE
                        and (
                            decodedResponse.status == 202
                                and RESULTS_MESSAGE_SCORE_SUBMIT_KEPT
                                or RESULTS_MESSAGE_SCORE_SUBMIT_SUCCESS
                        )
                        or (
                            decodedResponse.status == 202
                                and "Replay was valid, but it was outside the online top 10 for this map revision."
                                or "Replay uploaded successfully."
                        ),
                }
                self:updateLevelSelectPreviewCacheFromSubmit(decodedResponse.payload)
                clearActiveScoreSubmitRequestContext(self)
            else
                if requestKind == SCORE_SUBMIT_REQUEST_KIND_REPLAY and self:attemptScoreSubmitFallback() then
                    return
                end
                clearActiveScoreSubmitRequestContext(self)
                self.resultsOnlineState = {
                    status = "error",
                    message = requestKind == SCORE_SUBMIT_REQUEST_KIND_SCORE
                        and string.format("%s %s", RESULTS_MESSAGE_SCORE_SUBMIT_FAILED, tostring(decodedResponse.error or RESULTS_MESSAGE_REPLAY_UPLOAD_FAILED))
                        or tostring(decodedResponse.error or RESULTS_MESSAGE_REPLAY_UPLOAD_FAILED),
                }
            end
        elseif type(decodedResponse) == "table" and decodedResponse.kind == "replay_fetch" and decodedResponse.requestId == self.activeReplayDownloadRequestId then
            local replayMapDescriptor = self.activeReplayDownloadMapDescriptor
            local replayEntry = self.activeReplayDownloadEntry
            self.activeReplayDownloadRequestId = nil
            self.activeReplayDownloadRequestStartedAt = nil
            self.activeReplayDownloadMapDescriptor = nil
            self.activeReplayDownloadEntry = nil
            self.activeReplayDownloadRequestMapUuid = nil
            self.activeReplayDownloadRequestMapHash = nil
            self:applyReplayDownloadResult(decodedResponse, replayMapDescriptor, replayEntry)
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

    local previewMapDescriptor = self:getActiveLevelSelectPreviewMapDescriptor()
    local previewMapUuid = previewMapDescriptor and previewMapDescriptor.mapUuid or nil
    local previewMapHash = previewMapDescriptor and previewMapDescriptor.mapHash or nil
    local previewCacheKey = buildLevelSelectPreviewCacheKey(previewMapUuid, previewMapHash)
    if levelSelectPreviewLogic.shouldStartFetch(
        self.levelSelectPreviewState,
        previewCacheKey,
        self.activeLevelSelectPreviewRequestId ~= nil,
        previewMapUuid and self:isLevelSelectPreviewCacheFresh(previewMapUuid, previewMapHash) or false,
        previewMapUuid and self:isLevelSelectPreviewFetchAllowed(previewMapUuid, previewMapHash) or false
    ) then
        if self:isOnlineMode() then
            local onlineConfig = self:getActiveOnlineConfig()
            if onlineConfig.isConfigured then
                self:beginLevelSelectPreviewFetch(onlineConfig, previewMapDescriptor)
            elseif self:getLevelSelectPreviewCacheEntry(previewMapUuid, previewMapHash) then
                self:setLevelSelectPreviewState(previewCacheKey, LEVEL_SELECT_PREVIEW_STATUS_READY, nil, {
                    mapUuid = previewMapUuid,
                    mapHash = previewMapHash,
                    hasResolvedInitialRemoteAttempt = true,
                })
            else
                self:setLevelSelectPreviewState(previewCacheKey, LEVEL_SELECT_PREVIEW_STATUS_ERROR, LEVEL_SELECT_PREVIEW_MESSAGE_NO_LOCAL_DATA, {
                    mapUuid = previewMapUuid,
                    mapHash = previewMapHash,
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


end
