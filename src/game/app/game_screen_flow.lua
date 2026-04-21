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

function Game:processEditorUploadRequest()
    local descriptor = self.editor:consumeUploadRequest()
    if not descriptor then
        return
    end

    self:uploadMapDescriptor(descriptor, "editor")
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


end
