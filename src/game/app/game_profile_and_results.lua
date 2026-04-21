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

    local summary = self.resultsSummary or {}
    local localReplaySaved, keptLocalReplay, localReplayError = self:updateLocalReplayIndex(self.replayRecord, summary)
    if not localReplaySaved then
        self.resultsOnlineState = {
            status = "error",
            message = localReplayError or "The replay could not be saved in the local replay index.",
        }
        return
    end

    local localScoreSaved = true
    local localSaveError = nil
    if self.levelComplete then
        local isNewLocalBest
        localScoreSaved, isNewLocalBest, localSaveError = self:updateLocalScoreboard(summary)
        if not localScoreSaved then
            self.resultsOnlineState = {
                status = "error",
                message = localSaveError or RESULTS_MESSAGE_LOCAL_SAVE_FAILED,
            }
            return
        end
    end

    if self:isOfflineMode() then
        self.resultsOnlineState = {
            status = keptLocalReplay and "submitted" or "kept",
            message = keptLocalReplay
                and "Replay saved locally."
                or "Replay was saved, but it is outside the local top 10 for this map revision.",
        }
        return
    end

    local onlineConfig = self:reloadOnlineConfig()
    if not onlineConfig.isConfigured then
        self.resultsOnlineState = {
            status = "disabled",
            message = "Replay saved locally. " .. getLeaderboardUnavailableMessage(),
        }
        return
    end

    if self:isDebugModeEnabled() then
        self.resultsOnlineState = {
            status = "skipped",
            message = "Replay saved locally. Debug mode is enabled, so the online replay upload was skipped.",
        }
        return
    end

    self.resultsOnlineState = {
        status = "pending",
        message = "Uploading replay...",
    }
    self:beginReplaySubmitRequest(onlineConfig, summary, self.replayRecord)
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

function Game:updateEditorSavedMapActionState()
    local savedMapDescriptor = self.editor:getSavedMapDescriptor()
    local canUploadSavedMap = false
    if self:canUploadMapDescriptor(savedMapDescriptor) then
        canUploadSavedMap = self:getUploadConfig().isConfigured
    end

    self.editor:setSavedMapUploadState(
        canUploadSavedMap,
        self.activeUploadMapRequestId ~= nil and self.activeUploadMapOrigin == "editor"
    )
end

function Game:showUploadUnavailableMessage(origin, message, title)
    if origin == "editor" then
        self.editor:showStatus("Uploading is currently not possible.")
        return
    end

    self:setLevelSelectActionState(LEVEL_SELECT_ACTION_STATUS_ERROR, message, title or "Upload unavailable")
end

function Game:showUploadStartedMessage(origin)
    if origin == "editor" then
        self.editor:showStatus("Uploading the saved map...")
        return
    end

    self:closeLevelSelectUploadDialog()
    self:setLevelSelectActionState(
        LEVEL_SELECT_ACTION_STATUS_INFO,
        "Sending your map to the online library.",
        "Uploading map"
    )
end

function Game:showUploadSuccessMessage(origin, payload, mapDescriptor)
    if origin == "editor" then
        local resolvedPayload = type(payload) == "table" and payload or {}
        local uploadedMapId = tostring(
            resolvedPayload.internal_identifier
                or resolvedPayload.internalIdentifier
                or resolvedPayload.map_uuid
                or resolvedPayload.mapUuid
                or ""
        )
        if uploadedMapId ~= "" then
            self.editor:showStatus("Map uploaded. ID: " .. uploadedMapId)
        else
            self.editor:showStatus("Map uploaded successfully.")
        end
        return
    end

    self:clearLevelSelectActionState()
    self:openLevelSelectUploadDialog(payload, mapDescriptor)
end

function Game:showUploadFailureMessage(origin, message)
    if origin == "editor" then
        self.editor:showStatus(message)
        return
    end

    self:setLevelSelectActionState(LEVEL_SELECT_ACTION_STATUS_ERROR, message, "Upload failed")
end

function Game:uploadMapDescriptor(mapDescriptor, origin)
    local uploadOrigin = origin or "level_select"
    local selectedMap = mapDescriptor or self:getSelectedLevelMap()
    if not self:canUploadMapDescriptor(selectedMap) then
        self:showUploadUnavailableMessage(uploadOrigin, "Only your own local user maps can be uploaded.")
        return false
    end

    local onlineConfig = self:getUploadConfig()
    if not onlineConfig.isConfigured then
        self:showUploadUnavailableMessage(
            uploadOrigin,
            table.concat(onlineConfig.errors or { "The online marketplace is not configured." }, " ")
        )
        return false
    end

    local mapData, loadError = mapStorage.loadMap(selectedMap)
    if not mapData or type(mapData.level) ~= "table" then
        self:showUploadFailureMessage(uploadOrigin, loadError or "The selected map could not be uploaded.")
        return false
    end

    if not self:beginUploadMapRequest(onlineConfig, mapData, selectedMap) then
        self:showUploadFailureMessage(uploadOrigin, "A map upload is already in progress.")
        return false
    end

    self.activeUploadMapOrigin = uploadOrigin
    self:showUploadStartedMessage(uploadOrigin)
    return true
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
    self:uploadMapDescriptor(self:getSelectedLevelMap(), "level_select")
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
        savedAt = tostring(sourceEntry.updated_at or selectedMap.savedAt or ""),
        previewDescription = selectedMap.previewDescription,
        level = deepCopy(sourceEntry.map),
        remoteSource = {
            creatorUuid = tostring(sourceEntry.creator_uuid or ""),
            creatorDisplayName = tostring(sourceEntry.creator_display_name or ""),
            favoriteCount = tonumber(sourceEntry.favorite_count or 0) or 0,
            internalIdentifier = tostring(sourceEntry.internal_identifier or ""),
            likedByPlayer = sourceEntry.liked_by_player == true,
            mapCategory = tostring(sourceEntry.map_category or ""),
            mapHash = tostring(sourceEntry.map_hash or ""),
            updatedAt = tostring(sourceEntry.updated_at or ""),
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


end
