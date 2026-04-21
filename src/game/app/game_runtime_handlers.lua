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

function Game:update(dt)
    self:updateLeaderboardFetchState()
    self:updatePlayGuideTransition(dt)

    if self.screen == "level_select" then
        self:updateLevelSelectAnimation(dt)
        return
    end

    if self.screen == "editor" then
        self:updateEditorSavedMapActionState()
        self.editor:update(dt)
        if self:processEditorOpenBlankRequest() then
            return
        end
        self:processEditorPlaytestRequest()
        self:processEditorUploadRequest()
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


end
