local input = require("src.game.input")
local mapEditor = require("src.game.map_editor")
local mapStorage = require("src.game.map_storage")
local profileStorage = require("src.game.profile_storage")
local simpleboardsClient = require("src.game.simpleboards_client")
local world = require("src.game.world")
local ui = require("src.game.ui")
local json = require("src.game.json")

local Game = {}
Game.__index = Game

local function findLevelSelectIndex(game, maps)
    local fallbackIndex = #maps > 0 and 1 or nil

    for index, descriptor in ipairs(maps or {}) do
        if descriptor.id == game.levelSelectSelectedId then
            return index
        end
    end

    if fallbackIndex then
        game.levelSelectSelectedId = maps[fallbackIndex].id
    else
        game.levelSelectSelectedId = nil
    end

    return fallbackIndex
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

local function trim(value)
    return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function trimLastUtf8Character(value)
    return (value or ""):gsub("[%z\1-\127\194-\244][\128-\191]*$", "")
end

local function extractMapUuidFromMetadata(metadata)
    if type(metadata) ~= "string" then
        return nil
    end

    local trimmedMetadata = trim(metadata)
    if trimmedMetadata == "" then
        return nil
    end

    if trimmedMetadata:sub(1, 1) == "{" then
        local decoded = json.decode(trimmedMetadata)
        if type(decoded) == "table" then
            return decoded.mapUuid
        end
    end

    return trimmedMetadata
end

local function normalizeLeaderboardEntries(entries, mapUuid)
    local normalized = {}

    if type(entries) ~= "table" then
        return normalized
    end

    local sourceEntries = entries.entries or entries
    if type(sourceEntries) ~= "table" then
        return normalized
    end

    for _, entry in ipairs(sourceEntries) do
        local entryMapUuid = extractMapUuidFromMetadata(entry.metadata)
        if not mapUuid or entryMapUuid == mapUuid then
            normalized[#normalized + 1] = {
                playerDisplayName = entry.playerDisplayName or entry.playerName or "Unknown",
                playerId = entry.playerId,
                score = tonumber(entry.score or 0) or 0,
                metadata = entry.metadata,
                mapUuid = entryMapUuid,
                createdAt = entry.createdAt or entry.created_at,
            }
        end
    end

    table.sort(normalized, function(firstEntry, secondEntry)
        if firstEntry.score == secondEntry.score then
            return tostring(firstEntry.playerDisplayName or "") < tostring(secondEntry.playerDisplayName or "")
        end
        return firstEntry.score > secondEntry.score
    end)

    return normalized
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
    self.onlineConfig = simpleboardsClient.getConfig()
    self.screen = trim(profile.playerDisplayName) ~= "" and "menu" or "profile_setup"
    self.levelComplete = false
    self.failureReason = nil
    self.world = nil
    self.editor = mapEditor.new(self.viewport.w, self.viewport.h, nil)
    self.availableMaps = {}
    self.currentMapDescriptor = nil
    self.currentRunOrigin = nil
    self.levelSelectIssue = nil
    self.levelSelectSelectedId = nil
    self.levelSelectFilter = "all"
    self.levelSelectFilterHoverId = nil
    self.levelSelectVisualIndex = nil
    self.levelSelectScroll = 0
    self.resultsSummary = nil
    self.resultsOnlineState = nil
    self.profileSetupNameBuffer = profile.playerDisplayName or ""
    self.profileSetupError = nil
    self.playOverlayMode = nil
    self.leaderboardState = {
        status = "idle",
        message = nil,
        entries = {},
        totalEntries = 0,
    }
    self.leaderboardReturnScreen = "menu"
    self.leaderboardMapUuid = nil
    self.leaderboardTitle = "Online Leaderboard"

    self:updateRenderTransform()
    self:refreshMaps()

    return self
end

function Game:reloadOnlineConfig()
    self.onlineConfig = simpleboardsClient.getConfig()
    return self.onlineConfig
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
    if #nextValue <= 24 then
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
    self:openMenu()
    return true
end

function Game:submitResultsScore()
    self.resultsOnlineState = nil

    local onlineConfig = self:reloadOnlineConfig()
    if not onlineConfig.isConfigured then
        self.resultsOnlineState = {
            status = "disabled",
            message = table.concat(onlineConfig.errors or { "SimpleBoards is not configured." }, " "),
        }
        return
    end

    if not self.levelComplete then
        self.resultsOnlineState = {
            status = "skipped",
            message = "Scores are uploaded only after a successful level clear.",
        }
        return
    end

    if self:isDebugModeEnabled() then
        self.resultsOnlineState = {
            status = "skipped",
            message = "Debug mode is enabled, so the online score upload was skipped.",
        }
        return
    end

    local summary = self.resultsSummary or {}
    local _, submitError = simpleboardsClient.submitScore({
        playerId = self.profile.playerId,
        playerDisplayName = self.profile.playerDisplayName,
        score = tostring(summary.finalScore or 0),
        metadata = summary.mapUuid or "",
    }, onlineConfig)

    if submitError then
        self.resultsOnlineState = {
            status = "error",
            message = submitError,
        }
        return
    end

    self.resultsOnlineState = {
        status = "submitted",
        message = "Score uploaded successfully.",
    }
end

function Game:refreshLeaderboard()
    self.leaderboardState = {
        status = "loading",
        message = "Loading leaderboard...",
        entries = {},
        totalEntries = 0,
    }

    local onlineConfig = self:reloadOnlineConfig()
    if not onlineConfig.isConfigured then
        self.leaderboardState = {
            status = "disabled",
            message = table.concat(onlineConfig.errors or { "SimpleBoards is not configured." }, " "),
            entries = {},
            totalEntries = 0,
        }
        return
    end

    local entries, fetchError = simpleboardsClient.fetchLeaderboard(onlineConfig)
    if not entries then
        self.leaderboardState = {
            status = "error",
            message = fetchError or "The leaderboard could not be loaded.",
            entries = {},
            totalEntries = 0,
        }
        return
    end

    local filteredEntries = normalizeLeaderboardEntries(entries, self.leaderboardMapUuid)
    self.leaderboardState = {
        status = "ready",
        message = #filteredEntries > 0 and nil or "No entries were found for this leaderboard yet.",
        entries = filteredEntries,
        totalEntries = #filteredEntries,
    }
end

function Game:openLeaderboard(options)
    local openOptions = options or {}
    self.screen = "leaderboard"
    self.leaderboardReturnScreen = openOptions.returnScreen or "menu"
    self.leaderboardMapUuid = openOptions.mapUuid
    self.leaderboardTitle = openOptions.title or (self.leaderboardMapUuid and "Map Leaderboard" or "Online Leaderboard")
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
end

function Game:getLevelSelectMaps()
    return ui.getLevelSelectMapDescriptors(self)
end

function Game:getSelectedLevelMap()
    local maps = self:getLevelSelectMaps()
    local fallback = nil

    for _, descriptor in ipairs(maps) do
        fallback = fallback or descriptor
        if descriptor.id == self.levelSelectSelectedId then
            return descriptor
        end
    end

    if fallback then
        self.levelSelectSelectedId = fallback.id
    else
        self.levelSelectSelectedId = nil
    end

    return fallback
end

function Game:setLevelSelectSelection(mapDescriptor)
    self.levelSelectSelectedId = mapDescriptor and mapDescriptor.id or nil
    self.levelSelectScroll = 0
end

function Game:resetLevelSelectVisualIndex()
    local maps = self:getLevelSelectMaps()
    local targetIndex = findLevelSelectIndex(self, maps)
    self.levelSelectVisualIndex = targetIndex
end

function Game:setLevelSelectFilter(filterId)
    self.levelSelectFilter = filterId or "all"
    self:getSelectedLevelMap()
    self:resetLevelSelectVisualIndex()
    self.levelSelectScroll = 0
end

function Game:updateLevelSelectAnimation(dt)
    local maps = self:getLevelSelectMaps()
    local targetIndex = findLevelSelectIndex(self, maps)
    if not targetIndex then
        self.levelSelectVisualIndex = nil
        return
    end

    if not self.levelSelectVisualIndex then
        self.levelSelectVisualIndex = targetIndex
        return
    end

    local targetValue = closestWrappedIndex(self.levelSelectVisualIndex, targetIndex, #maps)
    local smoothing = 1 - math.exp(-dt * 12)
    self.levelSelectVisualIndex = self.levelSelectVisualIndex + ((targetValue - self.levelSelectVisualIndex) * smoothing)

    if math.abs(targetValue - self.levelSelectVisualIndex) < 0.001 then
        self.levelSelectVisualIndex = targetValue
    end
end

function Game:moveLevelSelectSelection(direction)
    local maps = self:getLevelSelectMaps()
    if #maps == 0 then
        self.levelSelectSelectedId = nil
        self.levelSelectScroll = 0
        return nil
    end

    local currentIndex = 1
    for index, descriptor in ipairs(maps) do
        if descriptor.id == self.levelSelectSelectedId then
            currentIndex = index
            break
        end
    end

    local nextIndex = currentIndex + direction
    if nextIndex < 1 then
        nextIndex = #maps
    elseif nextIndex > #maps then
        nextIndex = 1
    end

    self.levelSelectSelectedId = maps[nextIndex].id
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

    self.screen = "menu"
    self.levelSelectIssue = nil
    self.levelSelectFilterHoverId = nil
    self.resultsSummary = nil
    self.playOverlayMode = nil
    self:refreshMaps()
end

function Game:openLevelSelect()
    self.screen = "level_select"
    self.levelSelectIssue = nil
    self.levelSelectFilter = "all"
    self.levelSelectFilterHoverId = nil
    self.resultsSummary = nil
    self.playOverlayMode = nil
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
    self.editor:resetFromMap(nil, nil)
end

function Game:openEditorMap(mapDescriptor)
    local mapData, loadError = mapStorage.loadMap(mapDescriptor)
    if not mapData or not mapData.editor then
        self.editor:showStatus(loadError or "That map could not be loaded into the editor.")
        self.screen = "editor"
        return false
    end

    self.screen = "editor"
    self.levelSelectIssue = nil
    self.resultsSummary = nil
    self.playOverlayMode = nil
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
    self.world = world.new(self.viewport.w, self.viewport.h, mapData.level)
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

function Game:navigateBackFromRun()
    if self.currentRunOrigin == "editor" and self.currentMapDescriptor then
        if self:openEditorMap(self.currentMapDescriptor) then
            return
        end
    end

    self:openMenu()
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

function Game:openResults()
    if not self.world then
        return
    end

    self.resultsSummary = self.world:getRunSummary()
    self.failureReason = self.resultsSummary.endReason == "level_clear" and nil or self.resultsSummary.endReason
    self.levelComplete = self.resultsSummary.endReason == "level_clear"
    self.screen = "results"
    self:submitResultsScore()
end

function Game:update(dt)
    if self.screen == "level_select" then
        self:updateLevelSelectAnimation(dt)
        return
    end

    if self.screen == "editor" then
        self.editor:update(dt)
        self:processEditorPlaytestRequest()
        return
    end

    if (self.screen ~= "play" and self.screen ~= "results") or not self.world then
        return
    end

    if self.screen == "results" or self:isRunLocked() then
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
        if self.screen == "profile_setup" or self.screen == "menu" then
            love.event.quit()
        elseif self.screen == "leaderboard" then
            self:returnFromLeaderboard()
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

    if self.screen == "menu" then
        if key == "return" or key == "space" then
            self:openLevelSelect()
        elseif key == "e" then
            self:openEditorBlank()
        elseif key == "d" then
            self:toggleDebugMode()
        elseif key == "l" then
            self:openLeaderboard({ returnScreen = "menu", title = "Online Leaderboard" })
        end
        return
    end

    if self.screen == "leaderboard" then
        if key == "r" then
            self:refreshLeaderboard()
        elseif key == "m" then
            self:returnFromLeaderboard()
        end
        return
    end

    if self.screen == "level_select" then
        if self.levelSelectIssue and key == "return" then
            self:openEditorMap(self.levelSelectIssue.map)
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
                self:openEditorMap(selectedMap)
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
                title = "Current Map Leaderboard",
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

    if self:isRunLocked() and (key == "return" or key == "space") then
        self:restart()
    end
end

function Game:textinput(text)
    if self.screen == "profile_setup" then
        self:appendProfileNameInput(text)
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

    if self.screen == "menu" then
        local action = ui.getMenuActionAt(self, viewportX, viewportY)
        if action == "play" then
            self:openLevelSelect()
        elseif action == "leaderboard" then
            self:openLeaderboard({ returnScreen = "menu", title = "Online Leaderboard" })
        elseif action == "editor" then
            self:openEditorBlank()
        elseif action == "debug" then
            self:toggleDebugMode()
        elseif action == "quit" then
            love.event.quit()
        end
        return
    end

    if self.screen == "leaderboard" then
        local action = ui.getLeaderboardActionAt(self, viewportX, viewportY)
        if action == "back" then
            self:returnFromLeaderboard()
        elseif action == "refresh" then
            self:refreshLeaderboard()
        end
        return
    end

    if self.screen == "level_select" then
        local hit = ui.getLevelSelectHit(self, viewportX, viewportY)
        if not hit then
            return
        end

        if hit.kind == "back" then
            self:openMenu()
        elseif hit.kind == "set_filter" then
            self:setLevelSelectFilter(hit.filter)
        elseif hit.kind == "issue_edit" then
            self:openEditorMap(hit.map)
        elseif hit.kind == "issue_cancel" then
            self.levelSelectIssue = nil
        elseif hit.kind == "issue_blocked" then
            return
        elseif hit.kind == "select_map" then
            self:setLevelSelectSelection(hit.map)
        elseif hit.kind == "open_map" then
            self:setLevelSelectSelection(hit.map)
            local ok, startError, mapData = self:startMap(hit.map)
            if not ok then
                self:showMapIssue(hit.map, mapData, startError)
            end
        elseif hit.kind == "edit_map" then
            self:setLevelSelectSelection(hit.map)
            self:openEditorMap(hit.map)
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
                title = "Current Map Leaderboard",
            })
        elseif hit == "menu" then
            self:openMenu()
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

    if ui.getPlayBackHit(self, viewportX, viewportY) then
        self:navigateBackFromRun()
        return
    end

    self.world:handleClick(viewportX, viewportY, button)
end

function Game:mousemoved(x, y)
    if self.screen == "level_select" then
        local viewportX, viewportY = self:toViewportPosition(x, y)
        self.levelSelectFilterHoverId = ui.getLevelSelectFilterHoverId(self, viewportX, viewportY)
        return
    end

    if self.screen == "editor" then
        local viewportX, viewportY = self:toViewportPosition(x, y)
        self.editor:mousemoved(viewportX, viewportY)
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
        return self.editor:wheelmoved(screenX, screenY)
    end

    local y = screenY
    if self.screen == "level_select" and not self.levelSelectIssue and y ~= 0 then
        self:scrollLevelSelect(y > 0 and -1 or 1)
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
