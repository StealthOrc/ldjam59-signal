return function(ui, shared)
    local moduleEnvironment = setmetatable({ ui = ui }, {
        __index = function(_, key)
            local sharedValue = shared[key]
            if sharedValue ~= nil then
                return sharedValue
            end

            return _G[key]
        end,
        __newindex = shared,
    })

    setfenv(1, moduleEnvironment)

function ui.drawMenu(game)
    local graphics = love.graphics
    local buttons = getMenuButtons(game)
    local supportsOnlineServices = game.supportsOnlineServices and game:supportsOnlineServices() or false

    graphics.setColor(0.05, 0.07, 0.1, 1)
    graphics.rectangle("fill", 0, 0, game.viewport.w, game.viewport.h)

    graphics.setColor(0, 0, 0, 0.22)
    graphics.circle("fill", 200, 140, 180)
    graphics.circle("fill", 1080, 560, 220)

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf("Out of Signal", 0, 128, game.viewport.w, "center")

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.84, 0.88, 0.92, 1)
    graphics.printf(
        not supportsOnlineServices
            and "Route trains through lever-controlled merges in the jam-ready HTML5 build, with scores saved locally in your browser."
            or game:isOfflineMode()
            and "Route trains through lever-controlled merges and keep your personal scores on this device."
            or "Route trains through lever-controlled merges, upload cleared scores, and compare runs online.",
        game.viewport.w * 0.5 - 280,
        188,
        560,
        "center"
    )

    for _, rect in ipairs(buttons) do
        drawButton(rect, rect.label, { 0.09, 0.11, 0.15, 0.98 }, { 0.48, 0.92, 0.62, 1 }, game.fonts.body)
    end
end

function ui.drawProfileSetup(game)
    local graphics = love.graphics
    local panel = {
        x = game.viewport.w * 0.5 - 280,
        y = game.viewport.h * 0.5 - 150,
        w = 560,
        h = 300,
    }
    local inputRect = {
        x = panel.x + 56,
        y = panel.y + 126,
        w = panel.w - 112,
        h = 56,
    }
    local confirmRect = getProfileSetupConfirmRect(game)

    graphics.setColor(0.05, 0.07, 0.1, 1)
    graphics.rectangle("fill", 0, 0, game.viewport.w, game.viewport.h)
    drawMetalPanel(panel, 0.98)

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf("Choose Name", panel.x + 24, panel.y + 34, panel.w - 48, "center")

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.84, 0.88, 0.92, 1)
    graphics.printf("Enter the name to use in the game.", panel.x + 42, panel.y + 84, panel.w - 84, "center")

    graphics.setColor(0.48, 0.92, 0.62, 0.12)
    graphics.rectangle("fill", inputRect.x - 4, inputRect.y - 4, inputRect.w + 8, inputRect.h + 8, 16, 16)
    graphics.setColor(0.08, 0.1, 0.14, 0.98)
    graphics.rectangle("fill", inputRect.x, inputRect.y, inputRect.w, inputRect.h, 14, 14)
    graphics.setColor(0.48, 0.92, 0.62, 1)
    graphics.rectangle("line", inputRect.x, inputRect.y, inputRect.w, inputRect.h, 14, 14)
    graphics.setColor(0.48, 0.92, 0.62, 0.24)
    graphics.rectangle("line", inputRect.x - 4, inputRect.y - 4, inputRect.w + 8, inputRect.h + 8, 16, 16)

    love.graphics.setFont(game.fonts.body)
    local typedText = game.profileSetupNameBuffer or ""
    local hasTypedText = typedText ~= ""
    local nameText = hasTypedText and typedText or "Type a name..."
    if hasTypedText then
        graphics.setColor(0.97, 0.98, 1, 1)
    else
        graphics.setColor(0.5, 0.58, 0.66, 1)
    end
    graphics.printf(nameText, inputRect.x + 18, inputRect.y + 16, inputRect.w - 36, "left")

    if math.floor((love.timer.getTime() or 0) * 2) % 2 == 0 then
        local textWidth = game.fonts.body:getWidth(typedText)
        local caretX = hasTypedText
            and math.min(inputRect.x + inputRect.w - 24, inputRect.x + 18 + textWidth + 2)
            or (inputRect.x + 12)
        graphics.setColor(0.48, 0.92, 0.62, 1)
        graphics.rectangle("fill", caretX, inputRect.y + 12, 3, inputRect.h - 24, 1, 1)
    end

    love.graphics.setFont(game.fonts.small)
    if game.profileSetupError then
        graphics.setColor(0.99, 0.78, 0.32, 1)
        graphics.printf(game.profileSetupError, panel.x + 42, panel.y + 194, panel.w - 84, "center")
    end

    drawButton(confirmRect, "Continue", { 0.09, 0.11, 0.15, 0.98 }, { 0.48, 0.92, 0.62, 1 }, game.fonts.body)
end

function ui.drawProfileModeSetup(game)
    local graphics = love.graphics
    local panel = getProfileModeSetupPanelRect(game)
    local optionRects = getProfileModeSetupOptionRects(game)
    local isOnlineSelected = game.profileModeSelection == "online"
    local supportsOnlineServices = game.supportsOnlineServices and game:supportsOnlineServices() or false
    local promptText = supportsOnlineServices
        and "Do you want to use online features such as online leaderboards and community maps?"
        or "This HTML5 build uses offline mode only so it can run directly in the browser."
    local offlineTooltipText = supportsOnlineServices
        and "We're only storing your username as well as the uploaded maps and leaderboard stats. You can turn this on or off at any time in the main menu."
        or "Your local progress and personal bests stay in browser storage on this device."
    local promptWidth = panel.w - 88
    local promptLineCount = getWrappedLineCount(game.fonts.body, promptText, promptWidth)
    local promptHeight = promptLineCount * game.fonts.body:getHeight()
    local textBlockHeight = promptHeight
    local textAreaTop = panel.y + 84
    local textAreaBottom = optionRects.online.y - 34
    local textBlockY = textAreaTop + math.floor(((textAreaBottom - textAreaTop) - textBlockHeight) * 0.5 + 0.5)
    local promptX = panel.x + math.floor((panel.w - promptWidth) * 0.5 + 0.5)

    graphics.setColor(0.05, 0.07, 0.1, 1)
    graphics.rectangle("fill", 0, 0, game.viewport.w, game.viewport.h)
    drawMetalPanel(panel, 0.98)

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf(supportsOnlineServices and "Enable Online Functionality?" or "HTML5 Build Mode", panel.x + 24, panel.y + 34, panel.w - 48, "center")

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.84, 0.88, 0.92, 1)
    graphics.printf(
        promptText,
        promptX,
        textBlockY,
        promptWidth,
        "center"
    )

    drawButton(
        optionRects.online,
        supportsOnlineServices and "Online" or "Unavailable",
        isOnlineSelected and { 0.1, 0.22, 0.14, 0.98 } or { 0.08, 0.18, 0.11, 0.98 },
        isOnlineSelected and { 0.54, 0.96, 0.66, 1 } or { 0.42, 0.86, 0.55, 1 },
        game.fonts.body,
        not supportsOnlineServices
    )
    drawButton(
        optionRects.offline,
        "Offline",
        { 0.08, 0.1, 0.14, 0.98 },
        { 0.3, 0.42, 0.54, 1 },
        game.fonts.body
    )

    if game.profileModeHoverId == "offline" then
        drawProfileModeTooltip(game, optionRects.offline, offlineTooltipText)
    elseif game.profileModeHoverId == "online" and not supportsOnlineServices then
        local onlineUnavailableReason = game.getOnlineUnavailableReason and game:getOnlineUnavailableReason() or "Online features are unavailable here."
        drawProfileModeTooltip(game, optionRects.online, onlineUnavailableReason)
    end

    if game.profileModeSetupError then
        graphics.setColor(0.99, 0.78, 0.32, 1)
        graphics.printf(game.profileModeSetupError, panel.x + 40, panel.y + panel.h - 42, panel.w - 80, "center")
    end
end

function ui.drawLeaderboard(game)
    local graphics = love.graphics
    local layout = getLeaderboardContentLayout(game)
    local panel = layout.panel
    local buttons = getLeaderboardActionRects(game)
    local state = game.leaderboardState or { status = "idle", entries = {} }
    local hasEntries = #(state.entries or {}) > 0
    local contentX = layout.contentX
    local contentW = layout.contentW

    graphics.setColor(0.05, 0.07, 0.1, 1)
    graphics.rectangle("fill", 0, 0, game.viewport.w, game.viewport.h)
    drawMetalPanel(panel, 0.98)

    drawButton(buttons.back, "Back", { 0.1, 0.14, 0.18, 0.98 }, { 0.3, 0.42, 0.54, 1 }, game.fonts.small)

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf(game.leaderboardTitle or "Online Leaderboard", panel.x + 24, panel.y + 24, panel.w - 48, "center")

    local badgeRect = getLeaderboardFilterBadgeRect(game)

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.1, 0.14, 0.18, 0.98)
    graphics.rectangle("fill", badgeRect.x, badgeRect.y, badgeRect.w, badgeRect.h, 14, 14)
    graphics.setColor(game.leaderboardMapUuid and 0.56 or 0.3, game.leaderboardMapUuid and 0.72 or 0.42, game.leaderboardMapUuid and 0.98 or 0.54, 1)
    graphics.rectangle("line", badgeRect.x, badgeRect.y, badgeRect.w, badgeRect.h, 14, 14)
    graphics.setColor(0.9, 0.94, 0.98, 1)
    graphics.printf(
        badgeRect.text,
        badgeRect.x + LEADERBOARD_LAYOUT.filterBadgePaddingX,
        badgeRect.y + 6,
        badgeRect.w - (LEADERBOARD_LAYOUT.filterBadgePaddingX * 2),
        "center"
    )

    if state.status ~= "ready" and not hasEntries then
        if state.status == "loading" then
            drawLoadingSpinner(
                panel.x + panel.w * 0.5,
                panel.y + LEADERBOARD_LOADING.emptyStateYOffset + LEADERBOARD_LOADING.emptySpinnerYOffset,
                { 0.48, 0.92, 0.62, 1 }
            )
        end

        love.graphics.setFont(game.fonts.body)
        graphics.setColor(state.status == "loading" and 0.84 or 0.99, state.status == "loading" and 0.88 or 0.78, state.status == "loading" and 0.92 or 0.32, 1)
        graphics.printf(
            state.message or "The leaderboard is not ready.",
            contentX,
            panel.y + LEADERBOARD_LOADING.emptyStateYOffset + LEADERBOARD_LOADING.emptyTextYOffset,
            contentW,
            "center"
        )
        drawLeaderboardRefreshIndicator(game, panel, state)
        return
    end

    if not hasEntries then
        love.graphics.setFont(game.fonts.body)
        graphics.setColor(0.84, 0.88, 0.92, 1)
        graphics.printf(state.message or "No entries are available yet.", contentX, panel.y + 180, contentW, "center")
        drawLeaderboardRefreshIndicator(game, panel, state)
        return
    end

    local headerY = panel.y + LEADERBOARD_LAYOUT.headerY
    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.68, 0.74, 0.8, 1)
    graphics.print("#", contentX, headerY)
    graphics.print("Player", layout.playerX, headerY)
    graphics.printf("Score", layout.scoreX, headerY, LEADERBOARD_LAYOUT.scoreWidth, "center")
    if shouldShowLeaderboardMapColumn(game) then
        graphics.printf(game:isOfflineMode() and "Map" or "Latest Map", layout.mapX, headerY, layout.mapWidth, "left")
    end
    graphics.printf(game:isOfflineMode() and "Recorded" or "Record", layout.recordX, headerY, LEADERBOARD_LAYOUT.recordWidth, "left")

    local rowRects = buildLeaderboardRowRects(game, state.entries or {})
    for _, rowRect in ipairs(rowRects) do
        local entry = rowRect.entry
        local rowY = rowRect.player.y
        graphics.setColor(0.1, 0.13, 0.17, 0.94)
        graphics.rectangle("fill", rowRect.row.x, rowRect.row.y, rowRect.row.w, rowRect.row.h, LEADERBOARD_LAYOUT.rowRadius, LEADERBOARD_LAYOUT.rowRadius)
        graphics.setColor(0.26, 0.34, 0.42, 1)
        graphics.rectangle("line", rowRect.row.x, rowRect.row.y, rowRect.row.w, rowRect.row.h, LEADERBOARD_LAYOUT.rowRadius, LEADERBOARD_LAYOUT.rowRadius)

        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.print(tostring(entry.rank or 0), contentX + 12, rowY + LEADERBOARD_LAYOUT.rowPrimaryTextOffsetY)
        graphics.printf(
            entry.playerDisplayName or "Unknown",
            rowRect.player.x,
            rowY + LEADERBOARD_LAYOUT.rowPrimaryTextOffsetY,
            rowRect.player.w,
            "left"
        )
        graphics.printf(
            formatLeaderboardScore(entry.score or 0),
            layout.scoreX,
            rowY + LEADERBOARD_LAYOUT.rowPrimaryTextOffsetY,
            LEADERBOARD_LAYOUT.scoreWidth,
            "center"
        )
        if rowRect.map then
            graphics.setColor(0.72, 0.78, 0.84, 1)
            graphics.printf(
                entry.mapName or "Unknown Map",
                rowRect.map.x,
                rowY + LEADERBOARD_LAYOUT.rowPrimaryTextOffsetY,
                rowRect.map.w,
                "left"
            )
        end

        graphics.setColor(0.68, 0.74, 0.8, 1)
        graphics.printf(
            game:isOfflineMode()
                and formatLeaderboardRecordedAt(entry.recordedAt or entry.updatedAt)
                or formatLeaderboardEntryTimestamp(entry.updatedAt or entry.recordedAt),
            rowRect.record.x,
            rowY + 2,
            rowRect.record.w,
            "left"
        )
    end

    if #(state.entries or {}) > #rowRects then
        graphics.setColor(0.68, 0.74, 0.8, 1)
        graphics.printf(
            string.format("%d more entry/entries hidden.", #(state.entries or {}) - #rowRects),
            contentX,
            panel.y + panel.h - 44,
            contentW,
            "center"
        )
    end

    drawLeaderboardRefreshIndicator(game, panel, state)
    drawLeaderboardTooltip(game, game.leaderboardHoverInfo)
end

function ui.drawLevelSelect(game)
    local graphics = love.graphics
    local maps = getLevelSelectMaps(game)
    local selectedIndex = getSelectedMapIndex(game, maps)
    local selectedMap = selectedIndex and maps[selectedIndex] or nil
    local cardRects = buildLevelSelectCardRects(game)
    local actionButtons = getLevelSelectActionButtons(game)
    local primarySelectionRect = game.levelSelectMode == "marketplace" and getMarketplaceTabsRect(game) or getLevelSelectFilterRect(game)
    local primarySelectionSegments = game.levelSelectMode == "marketplace" and getMarketplaceTabSegments() or getLevelSelectFilterSegments()
    local primarySelectionValue = game.levelSelectMode == "marketplace" and (game.levelSelectMarketplaceTab or "top") or (game.levelSelectFilter or "campaign")
    local modeSelectionRect = getLevelSelectModeSelectorRect(game)
    local modeSelectionSegments = getLevelSelectModeSegments(game)

    graphics.setColor(PANEL_COLORS.background[1], PANEL_COLORS.background[2], PANEL_COLORS.background[3], PANEL_COLORS.background[4])
    graphics.rectangle("fill", 0, 0, game.viewport.w, game.viewport.h)

    drawLevelSelectChrome(game)
    drawLevelSelectTitleBar(game, selectedMap)

    for _, cardRect in ipairs(cardRects) do
        drawLevelCard(game, cardRect)
    end

    if #maps == 0 then
        drawLevelSelectEmptyState(game, game.levelSelectMode == "marketplace" and "marketplace" or (game.levelSelectFilter or "campaign"))
    end

    uiControls.drawSegmentedToggle(
        primarySelectionRect,
        primarySelectionSegments,
        primarySelectionValue,
        game.levelSelectHoverId,
        game.fonts.small,
        {
            backgroundColor = { 0.08, 0.1, 0.14, 0.98 },
            activeFillColor = { 0.78, 0.88, 0.98, 0.94 },
            hoverColor = { 0.3, 0.4, 0.5, 0.22 },
            outlineColor = { 0.26, 0.38, 0.5, 1 },
            innerOutlineColor = { 0.44, 0.62, 0.78, 0.34 },
            selectedTextColor = { 0.08, 0.11, 0.15, 1 },
            textColor = { 0.9, 0.93, 0.97, 1 },
        }
    )

    uiControls.drawSegmentedToggle(
        modeSelectionRect,
        modeSelectionSegments,
        game.levelSelectMode or "library",
        game.levelSelectHoverId,
        game.fonts.small,
        {
            backgroundColor = { 0.08, 0.1, 0.14, 0.98 },
            activeFillColor = { 0.78, 0.88, 0.98, 0.94 },
            hoverColor = { 0.3, 0.4, 0.5, 0.22 },
            outlineColor = { 0.26, 0.38, 0.5, 1 },
            innerOutlineColor = { 0.44, 0.62, 0.78, 0.34 },
            selectedTextColor = { 0.08, 0.11, 0.15, 1 },
            textColor = { 0.9, 0.93, 0.97, 1 },
        }
    )

    if game.levelSelectMode == "marketplace" then
        if game.levelSelectMarketplaceTab == "search" then
            drawMarketplaceSearchField(game)
        end
    end

    for _, buttonRect in ipairs(actionButtons) do
        local fillColor = { 0.1, 0.12, 0.15, 0.98 }
        local strokeColor = { 0.24, 0.3, 0.36, 1 }
        local font = game.fonts.body
        local isDisabled = false

        if buttonRect.id == "open_map" and selectedMap then
            fillColor = { 0.12, 0.17, 0.2, 0.98 }
            strokeColor = { 0.48, 0.92, 0.62, 1 }
        elseif buttonRect.id == "edit_map" and selectedMap then
            fillColor = { 0.12, 0.17, 0.2, 0.98 }
            strokeColor = { 0.99, 0.78, 0.32, 1 }
        elseif buttonRect.id == "clone_map" and selectedMap then
            fillColor = { 0.12, 0.17, 0.2, 0.98 }
            strokeColor = { 0.56, 0.72, 0.98, 1 }
        elseif buttonRect.id == "back" then
            fillColor = { 0.1, 0.12, 0.15, 0.98 }
            strokeColor = { 0.3, 0.42, 0.54, 1 }
            font = game.fonts.small
        elseif buttonRect.id == "upload_map" then
            fillColor = { 0.12, 0.17, 0.2, 0.98 }
            strokeColor = { 0.48, 0.72, 0.92, 1 }
        elseif buttonRect.id == "download_map" and selectedMap then
            fillColor = { 0.12, 0.17, 0.2, 0.98 }
            strokeColor = { 0.48, 0.92, 0.62, 1 }
        elseif buttonRect.id == "refresh_marketplace" then
            fillColor = { 0.12, 0.17, 0.2, 0.98 }
            strokeColor = { 0.56, 0.72, 0.98, 1 }
        end

        drawButton(buttonRect, buttonRect.label, fillColor, strokeColor, font, isDisabled)
    end

    ui.drawLevelSelectStatusCard(game)

    if game.levelSelectIssue then
        local overlay = getLevelIssueOverlayRects(game)
        local issue = game.levelSelectIssue

        graphics.setColor(0, 0, 0, 0.62)
        graphics.rectangle("fill", 0, 0, game.viewport.w, game.viewport.h)

        graphics.setColor(0.09, 0.11, 0.15, 0.98)
        graphics.rectangle("fill", overlay.panel.x, overlay.panel.y, overlay.panel.w, overlay.panel.h, 18, 18)
        graphics.setColor(0.3, 0.36, 0.42, 1)
        graphics.rectangle("line", overlay.panel.x, overlay.panel.y, overlay.panel.w, overlay.panel.h, 18, 18)

        love.graphics.setFont(game.fonts.title)
        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.printf("Map Has Issues", overlay.panel.x, overlay.panel.y + 20, overlay.panel.w, "center")

        love.graphics.setFont(game.fonts.body)
        graphics.setColor(0.99, 0.78, 0.32, 1)
        graphics.printf(safeUiText(issue.map and issue.map.name, "Untitled Map"), overlay.panel.x + 24, overlay.panel.y + 74, overlay.panel.w - 48, "center")

        love.graphics.setFont(game.fonts.small)
        graphics.setColor(0.84, 0.88, 0.92, 1)
        graphics.printf(
            "Fix these issues in the editor before this run can start:",
            overlay.panel.x + 30,
            overlay.panel.y + 114,
            overlay.panel.w - 60,
            "left"
        )

        local errorY = overlay.panel.y + 146
        local maxErrors = math.min(5, #(issue.errors or {}))
        for index = 1, maxErrors do
            local message = issue.errors[index]
            graphics.setColor(0.99, 0.78, 0.32, 1)
            graphics.print(string.format("%d.", index), overlay.panel.x + 34, errorY)
            graphics.setColor(0.84, 0.88, 0.92, 1)
            graphics.printf(message, overlay.panel.x + 58, errorY, overlay.panel.w - 92)
            local lineCount = getWrappedLineCount(game.fonts.small, message, overlay.panel.w - 92)
            errorY = errorY + math.max(game.fonts.small:getHeight(), lineCount * game.fonts.small:getHeight()) + 8
        end

        if #(issue.errors or {}) > maxErrors then
            graphics.setColor(0.68, 0.74, 0.8, 1)
            graphics.printf(
                string.format("%d more issue(s) hidden here. Open the editor for the full list.", #(issue.errors or {}) - maxErrors),
                overlay.panel.x + 30,
                overlay.panel.y + 262,
                overlay.panel.w - 60,
                "center"
            )
        end

        drawButton(overlay.edit, "Open In Editor", { 0.1, 0.14, 0.18, 0.98 }, { 0.99, 0.78, 0.32, 1 }, game.fonts.small)
        drawButton(overlay.cancel, "Cancel", { 0.1, 0.14, 0.18, 0.98 }, { 0.3, 0.36, 0.42, 1 }, game.fonts.small)
    end

    if game.levelSelectUploadDialog then
        ui.drawLevelSelectUploadDialog(game)
    end

    if game.levelSelectHoverInfo and not game.levelSelectIssue and not game.levelSelectUploadDialog then
        drawPlayTooltip(game, game.levelSelectHoverInfo)
    end
end

function ui.drawPlay(game)
    local graphics = love.graphics
    local inputGroups = game.world:getInputEdgeGroups()
    local outputGroups = game.world:getOutputBadgeGroups()
    local activeGuideStep = getActivePlayGuideStep(game)
    local allowHoverTooltip = (not game.playGuideTransition) and (not activeGuideStep or activeGuideStep.allowHoverTooltip == true)
    local headerHintLines = ui.getPlayHeaderHintLines(game)
    local headerHintX = 24

    for _, badge in ipairs(outputGroups) do
        drawOutputBadge(game, badge)
    end

    if game.playPhase == "prepare" then
        for _, group in ipairs(inputGroups) do
            drawInputPrepCard(game, group)
        end
    else
        for _, group in ipairs(inputGroups) do
            local nextTrain = game.world:getNextPendingTrainForInputEdge(group.edge.id)
            if nextTrain then
                drawInputLiveCard(game, group.edge, nextTrain)
            end
        end
    end

    drawButton(getPlayBackRect(game), getRunBackLabel(game), { 0.09, 0.11, 0.15, 0.98 }, { 0.3, 0.36, 0.42, 1 }, game.fonts.small)

    if game.playPhase == "prepare" then
        drawButton(getPlayStartRect(), "Start Run", { 0.12, 0.17, 0.2, 0.98 }, { 0.48, 0.92, 0.62, 1 }, game.fonts.body)
        love.graphics.setFont(game.fonts.small)
        graphics.setColor(0.84, 0.88, 0.92, 1)
        graphics.printf("Preparation Phase: set your routes, then start the clock.", 0, 34, game.viewport.w, "center")

        if not activeGuideStep then
            local blinkAlpha = 0.3
            if love and love.timer and love.timer.getTime then
                blinkAlpha = (math.sin(love.timer.getTime() * 4.8) > 0) and 1 or 0.3
            end
            graphics.setColor(1, 1, 1, blinkAlpha)
            graphics.printf("Press Spacebar to Start", 0, game.viewport.h - 86, game.viewport.w, "center")
        end
    end

    love.graphics.setFont(game.fonts.small)
    local lineHeight = game.fonts.small:getHeight() + 6
    local hintBlockHeight = #headerHintLines * lineHeight
    local headerHintY = math.floor((game.viewport.h - hintBlockHeight) * 0.5 + 0.5)
    graphics.setColor(0.72, 0.78, 0.84, 0.96)
    for index, hintLine in ipairs(headerHintLines) do
        graphics.print(hintLine, headerHintX, headerHintY + ((index - 1) * lineHeight))
    end

    drawPlayInfoOverlay(game)
    if activeGuideStep then
        drawPlayGuideOverlay(game)
    end
    if game.playPhase == "prepare" and not game.playOverlayMode and game.playHoverInfo and allowHoverTooltip then
        drawPlayTooltip(game, game.playHoverInfo)
    end
end

function ui.drawResults(game)
    local graphics = love.graphics
    local summary = game.resultsSummary or {}
    local level = game.world and game.world:getLevel() or {}
    local finalScore = summary.finalScore or 0
    local onTimePointCap = summary.onTimePointCap or 0
    local panel = ui.getResultsPanelRect(game)
    local buttons = getResultsButtonRects(game)
    local rowRects = ui.getResultsBreakdownRowRects(game)
    local breakdownX = rowRects[1] and rowRects[1].label.x or (panel.x + 58)

    graphics.setColor(0.05, 0.07, 0.1, 1)
    graphics.rectangle("fill", 0, 0, game.viewport.w, game.viewport.h)
    graphics.setColor(0, 0, 0, 0.22)
    graphics.circle("fill", 190, 130, 170)
    graphics.circle("fill", 1080, 560, 210)

    graphics.setColor(0.09, 0.11, 0.15, 0.98)
    graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 20, 20)
    graphics.setColor(0.26, 0.34, 0.42, 1)
    graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h, 20, 20)

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)
    local title = "Level Clear"
    local accent = { 0.48, 0.92, 0.62, 1 }
    if summary.endReason == "collision" then
        title = "Collision"
        accent = { 0.97, 0.36, 0.3, 1 }
    elseif summary.endReason == "timeout" then
        title = "Time Up"
        accent = { 0.99, 0.83, 0.44, 1 }
    end
    graphics.printf(title, panel.x, panel.y + 24, panel.w, "center")

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.84, 0.88, 0.92, 1)
    graphics.printf(level.title or "Run Results", panel.x, panel.y + 74, panel.w, "center")

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(accent[1], accent[2], accent[3], 1)
    graphics.printf(string.format("Score %s", formatScore(finalScore)), panel.x, panel.y + 108, panel.w, "center")

    love.graphics.setFont(game.fonts.small)
    local onlineState = game.resultsOnlineState or {}
    local onlineColor = { 0.72, 0.78, 0.84, 1 }
    if onlineState.status == "submitted" or onlineState.status == "kept" then
        onlineColor = { 0.48, 0.92, 0.62, 1 }
    elseif onlineState.status == "error" or onlineState.status == "disabled" then
        onlineColor = { 0.99, 0.78, 0.32, 1 }
    end
    graphics.setColor(onlineColor[1], onlineColor[2], onlineColor[3], onlineColor[4])
    graphics.printf(
        onlineState.message or (game:isOfflineMode() and "Local score pending." or "Online sync pending."),
        panel.x + 38,
        panel.y + 158,
        panel.w - 76,
        "center"
    )

    local rows = {
        { "On-time clears", string.format("%s / %s", formatScore((summary.scoreBreakdown and summary.scoreBreakdown.onTimeClears) or 0), formatScore(onTimePointCap)) },
        { "Late clears", string.format("+%s", formatScore((summary.scoreBreakdown and summary.scoreBreakdown.lateClears) or 0)) },
        { "Time penalty", string.format("-%s", formatScore((summary.scoreBreakdown and summary.scoreBreakdown.timePenalty) or 0)) },
        { "Interaction penalty", string.format("-%s", formatScore((summary.scoreBreakdown and summary.scoreBreakdown.interactionPenalty) or 0)) },
        { "Distance penalty", string.format("-%s", formatScore((summary.scoreBreakdown and summary.scoreBreakdown.extraDistancePenalty) or 0)) },
    }

    local lineY = panel.y + 220
    for index, row in ipairs(rows) do
        local rowRect = rowRects[index]
        graphics.setColor(0.84, 0.88, 0.92, 1)
        graphics.print(row[1], rowRect.label.x, lineY)
        graphics.printf(row[2], rowRect.value.x, lineY, rowRect.value.w, "right")
        lineY = lineY + 28
    end

    lineY = lineY + 20
    local stats = {
        string.format("On-time trains: %d", summary.correctOnTimeCount or 0),
        string.format("Late trains: %d", summary.correctLateCount or 0),
        string.format("Wrong destinations: %d", summary.wrongDestinationCount or 0),
        string.format("Elapsed time: %.1fs", summary.elapsedSeconds or 0),
        string.format("Interactions: %d", summary.interactionCount or 0),
        string.format("Map UUID: %s", summary.mapUuid or "n/a"),
    }

    for _, stat in ipairs(stats) do
        graphics.setColor(0.72, 0.78, 0.84, 1)
        graphics.print(stat, breakdownX, lineY)
        lineY = lineY + 26
    end

    drawButton(buttons.replay, "Replay", { 0.1, 0.14, 0.18, 0.98 }, { 0.48, 0.92, 0.62, 1 }, game.fonts.small)
    drawButton(
        buttons.leaderboard,
        game:isOfflineMode() and "Scores" or "Leaderboard",
        { 0.1, 0.14, 0.18, 0.98 },
        { 0.56, 0.72, 0.98, 1 },
        game.fonts.small
    )
    drawButton(buttons.editor, "Open In Editor", { 0.1, 0.14, 0.18, 0.98 }, { 0.99, 0.78, 0.32, 1 }, game.fonts.small)
    drawButton(buttons.menu, getRunBackLabel(game), { 0.1, 0.14, 0.18, 0.98 }, { 0.3, 0.36, 0.42, 1 }, game.fonts.small)

    if game.resultsHoverInfo then
        drawPlayTooltip(game, game.resultsHoverInfo)
    end
end

ui.formatLeaderboardScore = formatLeaderboardScore
ui.formatLeaderboardRecordedAt = formatLeaderboardRecordedAt
ui.formatLeaderboardEntryTimestamp = formatLeaderboardEntryTimestamp
ui.formatLevelSelectLeaderboardPlayerName = formatLevelSelectLeaderboardPlayerName
ui.formatLeaderboardRefreshLabel = formatLeaderboardRefreshLabel
ui.formatLevelSelectLeaderboardRefreshLabel = formatLevelSelectLeaderboardRefreshLabel
ui.getLevelSelectLeaderboardVisibleEntries = getLevelSelectLeaderboardVisibleEntries
ui.getLevelSelectLeaderboardPinnedRowY = getLevelSelectLeaderboardPinnedRowY
ui.formatMarketplaceFavoriteLabel = formatMarketplaceFavoriteLabel
ui.getLevelSelectBadges = buildLevelSelectBadges

end
