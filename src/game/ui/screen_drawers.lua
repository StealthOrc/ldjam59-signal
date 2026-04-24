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
    local modeToggleRect = nil
    local modeToggleProgress = 0
    local menuTitle = "Out of Signal"
    local menuElapsed = game.getMenuIntroElapsed and game:getMenuIntroElapsed() or 0
    local backgroundTitleState = game.getMenuBackgroundReplayTitleState and game:getMenuBackgroundReplayTitleState() or nil
    local titleEnterDuration = 0.55
    local buttonRevealDuration = 0.52
    local buttonStagger = 0.07

    local function clamp01(value)
        return clamp(value or 0, 0, 1)
    end

    local function easeOutCubic(t)
        local clamped = clamp01(t)
        local inverse = 1 - clamped
        return 1 - inverse * inverse * inverse
    end

    local function easeOutBack(t)
        local clamped = clamp01(t)
        local s = 1.70158
        local value = clamped - 1
        return 1 + value * value * ((s + 1) * value + s)
    end

    local function easeInCubic(t)
        local clamped = clamp01(t)
        return clamped * clamped * clamped
    end

    local function withTranslatedDraw(offsetX, offsetY, drawFn)
        graphics.push()
        graphics.translate(offsetX or 0, offsetY or 0)
        drawFn()
        graphics.pop()
    end

    local function getBorderSlideOffset(rect, progress)
        local eased = easeOutBack(progress)
        local viewport = game.viewport or { w = 1280, h = 720 }
        local leftDistance = rect.x
        local rightDistance = viewport.w - (rect.x + rect.w)
        local topDistance = rect.y
        local bottomDistance = viewport.h - (rect.y + rect.h)
        local bestDistance = leftDistance
        local border = "left"

        if rightDistance < bestDistance then
            bestDistance = rightDistance
            border = "right"
        end
        if topDistance < bestDistance then
            bestDistance = topDistance
            border = "top"
        end
        if bottomDistance < bestDistance then
            border = "bottom"
        end

        local startOffsetX = 0
        local startOffsetY = 0
        if border == "left" then
            startOffsetX = -rect.x - rect.w - 28
        elseif border == "right" then
            startOffsetX = viewport.w - rect.x + 28
        elseif border == "top" then
            startOffsetY = -rect.y - rect.h - 28
        else
            startOffsetY = viewport.h - rect.y + 28
        end

        return startOffsetX * (1 - eased), startOffsetY * (1 - eased)
    end

    local function getButtonProgress(index)
        local revealStart = titleEnterDuration + ((index - 1) * buttonStagger)
        return clamp01((menuElapsed - revealStart) / buttonRevealDuration)
    end

    if not (game.hasMenuBackgroundReplay and game:hasMenuBackgroundReplay()) then
        graphics.setColor(0.05, 0.07, 0.1, 1)
        graphics.rectangle("fill", 0, 0, game.viewport.w, game.viewport.h)

        graphics.setColor(0, 0, 0, 0.22)
        graphics.circle("fill", 200, 140, 180)
        graphics.circle("fill", 1080, 560, 220)
    else
        graphics.setColor(0.02, 0.03, 0.04, 0.42)
        graphics.rectangle("fill", 0, 0, game.viewport.w, game.viewport.h)
    end

    if backgroundTitleState then
        local sequence = backgroundTitleState.titleSequence or {}
        local centerX = (game.viewport and game.viewport.w or 1280) * 0.5
        local centerY = (game.viewport and game.viewport.h or 720) / 6
        local titleFont = game.fonts.title
        local subtitleFont = game.fonts.body
        local subtitleGap = 8
        local titleHeight = titleFont:getHeight()
        local hasSubtitle = backgroundTitleState.subtitle ~= nil and backgroundTitleState.subtitle ~= ""
        local subtitleHeight = hasSubtitle and subtitleFont:getHeight() or 0
        local totalHeight = titleHeight + (hasSubtitle and (subtitleGap + subtitleHeight) or 0)
        local titleCenterY = centerY - totalHeight * 0.5 + titleHeight * 0.5
        local subtitleCenterY = titleCenterY + titleHeight * 0.5 + subtitleGap + subtitleHeight * 0.5

        local function drawMovingLine(text, font, lineCenterY, delay, alphaScale)
            if not text or text == "" then
                return
            end

            local localElapsed = (backgroundTitleState.elapsed or 0) - (delay or 0)
            if localElapsed <= 0 then
                return
            end

            local enterDuration = sequence.enterDuration or 0.55
            local holdDuration = sequence.holdDuration or 2.0
            local exitDuration = sequence.exitDuration or 0.55
            local travelDistance = sequence.travelDistance or 420
            local alpha = 0
            local centerOffsetX = 0

            if localElapsed < enterDuration then
                local progress = easeOutCubic(localElapsed / enterDuration)
                centerOffsetX = (1 - progress) * travelDistance
                alpha = progress
            elseif localElapsed < enterDuration + holdDuration then
                alpha = 1
            elseif localElapsed < enterDuration + holdDuration + exitDuration then
                local progress = easeInCubic((localElapsed - enterDuration - holdDuration) / exitDuration)
                centerOffsetX = -travelDistance * progress
                alpha = 1 - progress
            else
                return
            end

            alpha = alpha * (alphaScale or 1)
            love.graphics.setFont(font)
            local drawX = math.floor(centerX - font:getWidth(text) * 0.5 + centerOffsetX + 0.5)
            local drawY = math.floor(lineCenterY - font:getHeight() * 0.5 + 0.5)
            graphics.setColor(0.02, 0.03, 0.05, alpha * 0.55)
            graphics.print(text, drawX + 4, drawY + 4)
            graphics.setColor(0.97, 0.98, 1, alpha)
            graphics.print(text, drawX, drawY)
        end

        drawMovingLine(backgroundTitleState.title or "Untitled Map", titleFont, titleCenterY, 0, 1)
        drawMovingLine(backgroundTitleState.subtitle or "", subtitleFont, subtitleCenterY, sequence.lineDelay or 0.18, 0.94)
    end

    do
        local enterDuration = 0.55
        local travelDistance = 420
        local titleScale = 2
        local progress = clamp01(menuElapsed / enterDuration)
        local eased = easeOutCubic(progress)
        local alpha = eased
        local centerOffsetX = (1 - eased) * travelDistance
        local centerX = (game.viewport and game.viewport.w or 1280) * 0.5
        local centerY = (game.viewport and game.viewport.h or 720) * 0.5
        local font = game.fonts.title
        local scaledWidth = font:getWidth(menuTitle) * titleScale
        local scaledHeight = font:getHeight() * titleScale
        local drawX = math.floor(centerX - scaledWidth * 0.5 + centerOffsetX + 0.5)
        local drawY = math.floor(centerY - scaledHeight * 0.5 + 0.5)

        love.graphics.setFont(font)
        graphics.push()
        graphics.translate(drawX, drawY)
        graphics.scale(titleScale, titleScale)
        graphics.setColor(0.02, 0.03, 0.05, alpha * 0.55)
        graphics.print(menuTitle, 2, 2)
        graphics.setColor(0.97, 0.98, 1, alpha)
        graphics.print(menuTitle, 0, 0)
        graphics.pop()
    end

    for index, rect in ipairs(buttons) do
        local progress = getButtonProgress(index)
        if progress > 0 then
            local offsetX, offsetY = getBorderSlideOffset(rect, progress)
            withTranslatedDraw(offsetX, offsetY, function()
                if rect.id == "toggle_play_mode" and rect.segments then
                    modeToggleRect = rect
                    modeToggleProgress = progress
                    if not game.onlineConfig or not game.onlineConfig.isConfigured then
                        local unavailableProgress = clamp01(
                            (menuElapsed - (titleEnterDuration + ((index - 1) * buttonStagger) + buttonRevealDuration)) / 0.18
                        )
                        if unavailableProgress > 0 then
                            local unavailableLabel = "Online unavailable"
                            local easedUnavailable = easeOutCubic(unavailableProgress)
                            love.graphics.setFont(game.fonts.small)
                            local labelWidth = game.fonts.small:getWidth(unavailableLabel)
                            local finalLabelX = rect.x + rect.w + 14
                            local startLabelX = rect.x + rect.w - labelWidth - 18
                            local labelX = startLabelX + ((finalLabelX - startLabelX) * easedUnavailable)
                            local labelY = rect.y + math.floor((rect.h - game.fonts.small:getHeight()) * 0.5 + 0.5)
                            graphics.setColor(0.7, 0.76, 0.82, 0.94 * easedUnavailable)
                            graphics.print(unavailableLabel, labelX, labelY)
                        end
                    end

                    uiControls.drawSegmentedToggle(
                        rect,
                        rect.segments,
                        game:isOnlineMode() and "online" or "offline",
                        nil,
                        game.fonts.small,
                        {
                            cornerRadius = 14,
                            backgroundColor = { 0.08, 0.1, 0.14, 0.98 },
                            activeFillColor = { 0.78, 0.88, 0.98, 0.94 },
                            hoverColor = { 0.3, 0.4, 0.5, 0.22 },
                            outlineColor = { 0.26, 0.38, 0.5, 1 },
                            innerOutlineColor = { 0.44, 0.62, 0.78, 0.34 },
                            selectedTextColor = { 0.08, 0.11, 0.15, 1 },
                            textColor = { 0.9, 0.93, 0.97, 1 },
                        }
                    )

                    if not game.onlineConfig or not game.onlineConfig.isConfigured then
                        local onlineSegment = uiControls.segmentRect(rect, 2, #rect.segments)
                        graphics.setColor(0.08, 0.1, 0.14, 0.42 * progress)
                        graphics.rectangle(
                            "fill",
                            onlineSegment.x + 2,
                            onlineSegment.y + 2,
                            onlineSegment.w - 4,
                            onlineSegment.h - 4,
                            12,
                            12
                        )
                    end
                elseif rect.id == "quit" then
                    drawButton(
                        rect,
                        rect.label,
                        { 0.2, 0.07, 0.08, 0.98 * progress },
                        { 0.99, 0.4, 0.44, progress },
                        game.fonts.small,
                        nil,
                        progress
                    )
                else
                    local font = rect.h <= 42 and game.fonts.small or game.fonts.body
                    local strokeColor = rect.id == "editor"
                        and { 0.99, 0.78, 0.32, progress }
                        or { 0.48, 0.92, 0.62, progress }
                    drawButton(
                        rect,
                        rect.label,
                        { 0.09, 0.11, 0.15, 0.98 * progress },
                        strokeColor,
                        font,
                        nil,
                        progress
                    )
                end
            end)
        end
    end

    if modeToggleRect and game.menuStatusMessage and game.menuStatusMessage ~= "" then
        love.graphics.setFont(game.fonts.small)
        graphics.setColor(0.99, 0.78, 0.32, modeToggleProgress)
        graphics.printf(
            game.menuStatusMessage,
            modeToggleRect.x,
            modeToggleRect.y - game.fonts.small:getHeight() - 28,
            math.max(modeToggleRect.w, 220),
            "left"
        )
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
    local promptText = "Do you want to use online features such as online leaderboards and community maps?"
    local offlineTooltipText = "We're only storing your username as well as the uploaded maps and leaderboard stats. You can turn this on or off at any time in the main menu."
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
    graphics.printf("Enable Online Functionality?", panel.x + 24, panel.y + 34, panel.w - 48, "center")

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
        "Online",
        isOnlineSelected and { 0.1, 0.22, 0.14, 0.98 } or { 0.08, 0.18, 0.11, 0.98 },
        isOnlineSelected and { 0.54, 0.96, 0.66, 1 } or { 0.42, 0.86, 0.55, 1 },
        game.fonts.body
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
        local hasReplay = entry and entry.hasReplay == true
        local timestampText = game:isOfflineMode()
            and formatLeaderboardRecordedAt(entry.recordedAt or entry.updatedAt)
            or formatLeaderboardEntryTimestamp(entry.updatedAt or entry.recordedAt)
        graphics.setColor(0.1, 0.13, 0.17, 0.94)
        graphics.rectangle("fill", rowRect.row.x, rowRect.row.y, rowRect.row.w, rowRect.row.h, LEADERBOARD_LAYOUT.rowRadius, LEADERBOARD_LAYOUT.rowRadius)
        if hasReplay then
            graphics.setColor(0.34, 0.56, 0.74, 1)
        else
            graphics.setColor(0.26, 0.34, 0.42, 1)
        end
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
            timestampText,
            rowRect.record.x,
            rowY + (hasReplay and LEADERBOARD_LAYOUT.replayTimestampOffsetY or LEADERBOARD_LAYOUT.defaultTimestampOffsetY),
            rowRect.record.w,
            "left"
        )
        if hasReplay then
            graphics.setColor(0.98, 0.3, 0.3, 1)
            graphics.circle(
                "fill",
                rowRect.record.x + LEADERBOARD_LAYOUT.replayDotOffsetX,
                rowY + LEADERBOARD_LAYOUT.replayDotOffsetY,
                LEADERBOARD_LAYOUT.replayDotRadius
            )
            graphics.setColor(0.92, 0.96, 1, 1)
            graphics.print(
                "Replay",
                rowRect.record.x + LEADERBOARD_LAYOUT.replayLabelOffsetX,
                rowY + LEADERBOARD_LAYOUT.replayLabelOffsetY
            )
        end
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

local function drawLevelSelectReplayOverlay(game, selectedMap)
    local graphics = love.graphics
    local overlay = ui.getLevelSelectReplayOverlayRects(game)
    local entries = game:getLevelSelectReplayOverlayEntries()
    local selectedEntry = game:getSelectedLevelSelectReplayEntry()
    local panel = overlay.panel
    local layout = LEVEL_SELECT.replayOverlay
    local listInsetX = layout.listInsetX
    local contentX = panel.x + listInsetX
    local contentW = panel.w - (listInsetX * 2)
    local tableHeader = {
        x = contentX,
        y = panel.y + layout.tableHeaderTop,
        w = contentW,
        h = layout.tableHeaderH,
    }
    local scoreColumnWidth = 108
    local durationColumnWidth = 88
    local endReasonColumnWidth = 156
    local rowTextInsetX = 14
    local recordedColumnWidth = contentW - durationColumnWidth - scoreColumnWidth - endReasonColumnWidth - 36
    local durationColumnX = contentX + contentW - endReasonColumnWidth - durationColumnWidth - scoreColumnWidth - 36
    local scoreColumnX = contentX + contentW - endReasonColumnWidth - scoreColumnWidth - 18
    local endReasonColumnX = contentX + contentW - endReasonColumnWidth - 16
    local recordedColumnX = contentX + rowTextInsetX
    local mapName = selectedMap and getMapDisplayName(selectedMap) or "Selected Map"
    local mapUuid = safeUiText(selectedMap and selectedMap.mapUuid, "n/a")
    local uuidLabel = "Map UUID"
    local metaBox = {
        x = 0,
        y = panel.y + layout.metaBoxTop,
        w = 0,
        h = layout.metaBoxH,
    }

    graphics.setColor(0, 0, 0, 0.68)
    graphics.rectangle("fill", 0, 0, game.viewport.w, game.viewport.h)

    graphics.setColor(0.09, 0.11, 0.15, 0.98)
    graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 18, 18)
    graphics.setColor(0.3, 0.42, 0.56, 1)
    graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h, 18, 18)

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf("Local Replays", panel.x + 28, panel.y + layout.titleTop, panel.w - 56, "center")

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.56, 0.72, 0.98, 1)
    graphics.printf(
        string.format("%s  |  %d stored for this revision", safeUiText(mapName, "Untitled Map"), #entries),
        panel.x + 40,
        panel.y + layout.subtitleTop,
        panel.w - 80,
        "center"
    )

    love.graphics.setFont(game.fonts.small)
    local metaContentWidth = math.max(
        game.fonts.small:getWidth(uuidLabel),
        game.fonts.small:getWidth(mapUuid)
    )
    metaBox.w = math.max(layout.metaBoxMinW, metaContentWidth + (layout.metaBoxPaddingX * 2))
    metaBox.x = math.floor(panel.x + (panel.w - metaBox.w) * 0.5 + 0.5)

    graphics.setColor(0.06, 0.08, 0.12, 0.96)
    graphics.rectangle("fill", metaBox.x, metaBox.y, metaBox.w, metaBox.h, 14, 14)
    graphics.setColor(0.24, 0.32, 0.4, 1)
    graphics.rectangle("line", metaBox.x, metaBox.y, metaBox.w, metaBox.h, 14, 14)

    graphics.setColor(PANEL_COLORS.mutedText[1], PANEL_COLORS.mutedText[2], PANEL_COLORS.mutedText[3], PANEL_COLORS.mutedText[4])
    graphics.printf(uuidLabel, metaBox.x, metaBox.y + layout.metaLabelTop, metaBox.w, "center")

    graphics.setColor(PANEL_COLORS.bodyText[1], PANEL_COLORS.bodyText[2], PANEL_COLORS.bodyText[3], PANEL_COLORS.bodyText[4])
    graphics.printf(mapUuid, metaBox.x, metaBox.y + layout.metaValueTop, metaBox.w, "center")

    graphics.setColor(0.08, 0.1, 0.14, 0.98)
    graphics.rectangle("fill", tableHeader.x, tableHeader.y, tableHeader.w, tableHeader.h, 12, 12)
    graphics.setColor(0.24, 0.32, 0.4, 1)
    graphics.rectangle("line", tableHeader.x, tableHeader.y, tableHeader.w, tableHeader.h, 12, 12)

    graphics.setColor(PANEL_COLORS.mutedText[1], PANEL_COLORS.mutedText[2], PANEL_COLORS.mutedText[3], PANEL_COLORS.mutedText[4])
    graphics.printf("Recorded", recordedColumnX, tableHeader.y + 6, recordedColumnWidth, "left")
    graphics.printf("Duration", durationColumnX, tableHeader.y + 6, durationColumnWidth, "center")
    graphics.printf("Score", scoreColumnX, tableHeader.y + 6, scoreColumnWidth, "center")
    graphics.printf("Result", endReasonColumnX, tableHeader.y + 6, endReasonColumnWidth, "left")

    if #entries == 0 then
        love.graphics.setFont(game.fonts.body)
        graphics.setColor(PANEL_COLORS.bodyText[1], PANEL_COLORS.bodyText[2], PANEL_COLORS.bodyText[3], PANEL_COLORS.bodyText[4])
        graphics.printf(
            "No local replays match this exact map revision yet.",
            contentX,
            panel.y + LEVEL_SELECT.replayOverlay.emptyTop,
            contentW,
            "center"
        )
    else
        for _, rowRect in ipairs(overlay.rows or {}) do
            local entry = rowRect.entry or {}
            local isSelected = selectedEntry and selectedEntry.replayUuid == entry.replayUuid
            local fillColor = isSelected and { 0.16, 0.28, 0.38, 0.98 } or { 0.08, 0.11, 0.15, 0.96 }
            local lineColor = isSelected and { 0.48, 0.72, 0.92, 1 } or { 0.24, 0.32, 0.4, 1 }

            graphics.setColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4])
            graphics.rectangle("fill", rowRect.x, rowRect.y, rowRect.w, rowRect.h, 12, 12)
            graphics.setColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
            graphics.rectangle("line", rowRect.x, rowRect.y, rowRect.w, rowRect.h, 12, 12)

            graphics.setColor(0.97, 0.98, 1, 1)
            graphics.printf(
                formatLeaderboardEntryTimestamp(entry.recordedAt),
                recordedColumnX,
                rowRect.y + 10,
                recordedColumnWidth,
                "left"
            )
            graphics.printf(
                formatSecondsLabel(entry.duration or 0),
                durationColumnX,
                rowRect.y + 10,
                durationColumnWidth,
                "center"
            )
            graphics.printf(
                formatScore(entry.score or 0),
                scoreColumnX,
                rowRect.y + 10,
                scoreColumnWidth,
                "center"
            )
            graphics.printf(
                safeUiText(entry.endReason, "unknown"),
                endReasonColumnX,
                rowRect.y + 10,
                endReasonColumnWidth,
                "left"
            )
        end
    end

    drawButton(
        overlay.start,
        "Start Replay",
        { 0.1, 0.14, 0.18, 0.98 },
        { 0.48, 0.92, 0.62, 1 },
        game.fonts.small,
        selectedEntry == nil
    )
    drawButton(
        overlay.close,
        "Close",
        { 0.1, 0.14, 0.18, 0.98 },
        { 0.3, 0.36, 0.42, 1 },
        game.fonts.small
    )
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
    local modeSelectionSegments = getLevelSelectModeSegments()

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
        elseif buttonRect.id == "open_replays" then
            fillColor = { 0.12, 0.17, 0.2, 0.98 }
            strokeColor = { 0.56, 0.72, 0.98, 1 }
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

    if game.levelSelectReplayOverlay then
        drawLevelSelectReplayOverlay(game, selectedMap)
    end

    if game.levelSelectHoverInfo and not game.levelSelectIssue and not game.levelSelectUploadDialog and not game.levelSelectReplayOverlay then
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
    local presentationState = game.mapPresentation
    local introState = game.playPhase == "prepare" and presentationState and presentationState.titleOnly ~= true and presentationState or nil
    local titleOverlayState = presentationState
        and (presentationState.elapsed or 0) < (((presentationState.titleSequence or {}).endTime) or 0)
        and presentationState
        or nil

    local function clamp01(value)
        return clamp(value or 0, 0, 1)
    end

    local function easeInCubic(t)
        local clamped = clamp01(t)
        return clamped * clamped * clamped
    end

    local function easeOutCubic(t)
        local clamped = clamp01(t)
        local inverse = 1 - clamped
        return 1 - inverse * inverse * inverse
    end

    local function easeOutBack(t)
        local clamped = clamp01(t)
        local s = 1.70158
        local value = clamped - 1
        return 1 + value * value * ((s + 1) * value + s)
    end

    local function getTimedProgress(startTime, duration)
        return clamp01(((introState and introState.elapsed or 0) - (startTime or 0)) / math.max(0.0001, duration or 0))
    end

    local function withTranslatedDraw(offsetX, offsetY, drawFn)
        graphics.push()
        graphics.translate(offsetX or 0, offsetY or 0)
        drawFn()
        graphics.pop()
    end

    local function getBorderSlideOffset(rect, progress)
        local eased = easeOutBack(progress)
        local viewport = game.viewport or { w = 1280, h = 720 }
        local leftDistance = rect.x
        local rightDistance = viewport.w - (rect.x + rect.w)
        local topDistance = rect.y
        local bottomDistance = viewport.h - (rect.y + rect.h)
        local bestDistance = leftDistance
        local border = "left"

        if rightDistance < bestDistance then
            bestDistance = rightDistance
            border = "right"
        end
        if topDistance < bestDistance then
            bestDistance = topDistance
            border = "top"
        end
        if bottomDistance < bestDistance then
            border = "bottom"
        end

        local startOffsetX = 0
        local startOffsetY = 0
        if border == "left" then
            startOffsetX = -rect.x - rect.w - 28
        elseif border == "right" then
            startOffsetX = viewport.w - rect.x + 28
        elseif border == "top" then
            startOffsetY = -rect.y - rect.h - 28
        else
            startOffsetY = viewport.h - rect.y + 28
        end

        return startOffsetX * (1 - eased), startOffsetY * (1 - eased)
    end

    local function drawIntroTitle()
        if not titleOverlayState then
            return
        end

        local sequence = titleOverlayState.titleSequence or {}
        local centerX = (game.viewport and game.viewport.w or 1280) * 0.5
        local centerY = (game.viewport and game.viewport.h or 720) / 6
        local titleFont = game.fonts.title
        local subtitleFont = game.fonts.body
        local subtitleGap = 8
        local titleHeight = titleFont:getHeight()
        local subtitleHeight = titleOverlayState.subtitle ~= "" and subtitleFont:getHeight() or 0
        local totalHeight = titleHeight + (titleOverlayState.subtitle ~= "" and (subtitleGap + subtitleHeight) or 0)
        local titleCenterY = centerY - totalHeight * 0.5 + titleHeight * 0.5
        local subtitleCenterY = titleCenterY + titleHeight * 0.5 + subtitleGap + subtitleHeight * 0.5

        local function drawMovingLine(text, font, lineCenterY, delay, alphaScale)
            if not text or text == "" then
                return
            end

            local localElapsed = (titleOverlayState.elapsed or 0) - (delay or 0)
            if localElapsed <= 0 then
                return
            end

            local enterDuration = sequence.enterDuration or 0.55
            local holdDuration = sequence.holdDuration or 2.0
            local exitDuration = sequence.exitDuration or 0.55
            local travelDistance = sequence.travelDistance or 420
            local alpha = 0
            local centerOffsetX = 0

            if localElapsed < enterDuration then
                local progress = easeOutCubic(localElapsed / enterDuration)
                centerOffsetX = (1 - progress) * travelDistance
                alpha = progress
            elseif localElapsed < enterDuration + holdDuration then
                centerOffsetX = 0
                alpha = 1
            elseif localElapsed < enterDuration + holdDuration + exitDuration then
                local progress = easeInCubic((localElapsed - enterDuration - holdDuration) / exitDuration)
                centerOffsetX = -travelDistance * progress
                alpha = 1 - progress
            else
                return
            end

            alpha = alpha * (alphaScale or 1)
            love.graphics.setFont(font)
            local drawX = math.floor(centerX - font:getWidth(text) * 0.5 + centerOffsetX + 0.5)
            local drawY = math.floor(lineCenterY - font:getHeight() * 0.5 + 0.5)
            graphics.setColor(0.02, 0.03, 0.05, alpha * 0.55)
            graphics.print(text, drawX + 4, drawY + 4)
            graphics.setColor(0.97, 0.98, 1, alpha)
            graphics.print(text, drawX, drawY)
        end

        drawMovingLine(titleOverlayState.title or "Untitled Map", titleFont, titleCenterY, 0, 1)
        drawMovingLine(titleOverlayState.subtitle or "", subtitleFont, subtitleCenterY, sequence.lineDelay or 0.18, 0.94)
    end

    if introState then
        local uiReveal = introState.uiReveal or {}
        local topProgress = getTimedProgress(uiReveal.startTime or 0, uiReveal.duration or 0.52)
        if topProgress > 0 then
            local topOffsetY = -140 * (1 - easeOutBack(topProgress))
            local backRect = getPlayBackRect(game)
            local startRect = getPlayStartRect()
            drawButton(
                {
                    x = backRect.x,
                    y = backRect.y + topOffsetY,
                    w = backRect.w,
                    h = backRect.h,
                },
                getRunBackLabel(game),
                { 0.09, 0.11, 0.15, 0.98 },
                { 0.3, 0.36, 0.42, 1 },
                game.fonts.small
            )
            drawButton(
                {
                    x = startRect.x,
                    y = startRect.y + topOffsetY,
                    w = startRect.w,
                    h = startRect.h,
                },
                "Start Run",
                { 0.12, 0.17, 0.2, 0.98 },
                { 0.48, 0.92, 0.62, 1 },
                game.fonts.body
            )
            love.graphics.setFont(game.fonts.small)
            graphics.setColor(0.84, 0.88, 0.92, 1)
            graphics.printf(
                "Preparation Phase: set your routes, then start the clock.",
                0,
                34 + topOffsetY,
                game.viewport.w,
                "center"
            )
        end

        for index, badge in ipairs(outputGroups) do
            local progress = getTimedProgress(
                (uiReveal.startTime or 0) + ((index - 1) * (uiReveal.cardStagger or 0)),
                uiReveal.duration or 0.52
            )
            if progress > 0 then
                local rect = getOutputBadgeRect(game, badge.edge, badge)
                local offsetX, offsetY = getBorderSlideOffset(rect, progress)
                withTranslatedDraw(offsetX, offsetY, function()
                    drawOutputBadge(game, badge)
                end)
            end
        end

        for index, group in ipairs(inputGroups) do
            local progress = getTimedProgress(
                (uiReveal.startTime or 0) + ((index - 1) * (uiReveal.cardStagger or 0)),
                uiReveal.duration or 0.52
            )
            if progress > 0 then
                local rect = getInputPrepCardRect(game, group.edge, #(group.trains or {}), inputGroups)
                local offsetX, offsetY = getBorderSlideOffset(rect, progress)
                withTranslatedDraw(offsetX, offsetY, function()
                    drawInputPrepCard(game, group)
                end)
            end
        end

        local textAlpha = getTimedProgress(
            (uiReveal.startTime or 0) + (uiReveal.textFadeDelay or 0.1),
            uiReveal.textFadeDuration or 0.32
        )
        if textAlpha > 0 then
            love.graphics.setFont(game.fonts.small)
            local lineHeight = game.fonts.small:getHeight() + 6
            local hintBlockHeight = #headerHintLines * lineHeight
            local headerHintY = math.floor((game.viewport.h - hintBlockHeight) * 0.5 + 0.5)
            graphics.setColor(0.72, 0.78, 0.84, 0.96 * textAlpha)
            for index, hintLine in ipairs(headerHintLines) do
                graphics.print(hintLine, headerHintX, headerHintY + ((index - 1) * lineHeight))
            end

            if not activeGuideStep then
                local blinkAlpha = 0.3
                if love and love.timer and love.timer.getTime then
                    blinkAlpha = (math.sin(love.timer.getTime() * 4.8) > 0) and 1 or 0.3
                end
                graphics.setColor(1, 1, 1, blinkAlpha * textAlpha)
                graphics.printf("Press Spacebar to Start", 0, game.viewport.h - 86, game.viewport.w, "center")
            end
        end

        drawIntroTitle()

        return
    end

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
    drawIntroTitle()
end

function ui.drawResults(game)
    local graphics = love.graphics
    local summary = game.resultsSummary or {}
    local level = game.world and game.world:getLevel() or {}
    local currentMapDescriptor = game.currentMapDescriptor or {}
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
        string.format("Revision: %s", tostring(currentMapDescriptor.revisionLabel or "v0.0.1")),
        string.format("Map UUID: %s", summary.mapUuid or "n/a"),
    }

    for _, stat in ipairs(stats) do
        graphics.setColor(0.72, 0.78, 0.84, 1)
        graphics.print(stat, breakdownX, lineY)
        lineY = lineY + 26
    end

    drawButton(buttons.retry, "Retry", { 0.1, 0.14, 0.18, 0.98 }, { 0.99, 0.78, 0.32, 1 }, game.fonts.small)
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

local function getReplayCurrentEvent(game)
    local runtime = game and game.replayRuntime or nil
    if not runtime then
        return nil
    end

    local bestEvent = nil
    for _, event in ipairs(runtime.record and runtime.record.timelineEvents or {}) do
        if (event.time or 0) <= (runtime.currentTime or 0) then
            bestEvent = event
        else
            break
        end
    end

    return bestEvent
end

local function drawReplayCursor(game)
    local runtime = game and game.replayRuntime or nil
    if not runtime then
        return
    end

    local graphics = love.graphics
    local cursor = runtime:getCursor()
    if not cursor then
        return
    end

    local cursorRadius = 7
    graphics.setColor(0.02, 0.03, 0.04, 0.94)
    graphics.circle("fill", cursor.x, cursor.y, cursorRadius + 3)
    graphics.setColor(0.98, 0.98, 1, 1)
    graphics.circle("fill", cursor.x, cursor.y, cursorRadius)
    graphics.setColor(0.18, 0.24, 0.32, 1)
    graphics.circle("fill", cursor.x, cursor.y, 2)

    local recentInteraction = runtime:getRecentInteraction()
    if not recentInteraction then
        return
    end

    local pulseDuration = 0.25
    local elapsed = math.max(0, (runtime.currentTime or 0) - (recentInteraction.time or 0))
    if elapsed > pulseDuration then
        return
    end

    local progress = elapsed / pulseDuration
    local radius = 10 + 20 * progress
    local alpha = 1 - progress
    graphics.setColor(0.48, 0.92, 0.62, 0.7 * alpha)
    graphics.setLineWidth(3)
    graphics.circle("line", recentInteraction.x or cursor.x, recentInteraction.y or cursor.y, radius)
    graphics.setLineWidth(1)
end

local function formatReplayPreparationSummaryEntry(game, interaction)
    local junctionLabel = getReplayJunctionLabel(game, interaction and interaction.junctionId)
    if interaction and interaction.target == "selector" then
        return "Output " .. junctionLabel
    end

    return junctionLabel
end

local function getReplayPreparationSummary(game, maxItems)
    local runtime = game and game.replayRuntime or nil
    local interactions = runtime and runtime.record and runtime.record.preparationInteractions or {}
    if type(interactions) ~= "table" or #interactions == 0 then
        return "Setup: none"
    end

    local resolvedMaxItems = math.max(1, tonumber(maxItems) or 2)
    local labels = {}
    for index, interaction in ipairs(interactions) do
        if index > resolvedMaxItems then
            break
        end

        labels[#labels + 1] = formatReplayPreparationSummaryEntry(game, interaction)
    end

    local remainingCount = math.max(0, #interactions - #labels)
    local summary = "Setup: " .. table.concat(labels, " • ")
    if remainingCount > 0 then
        summary = summary .. string.format(" • +%d more", remainingCount)
    end

    return summary
end

function ui.drawReplay(game)
    local runtime = game and game.replayRuntime or nil
    if not runtime then
        return
    end

    local replayEventColorByKind = {
        start = { 0.56, 0.72, 0.98, 1 },
        preparation = { 0.7, 0.76, 0.84, 1 },
        interaction = { 0.48, 0.92, 0.62, 1 },
        junction_state = { 0.99, 0.78, 0.32, 1 },
        train_spawn = { 0.52, 0.86, 0.98, 1 },
        train_exit = { 0.98, 0.66, 0.28, 1 },
        train_complete = { 0.98, 0.84, 0.38, 1 },
        run_end = { 0.98, 0.48, 0.62, 1 },
    }
    local markerRadius = 5
    local playheadWidth = 4
    local graphics = love.graphics
    local layout = getReplayLayout(game)
    local currentEvent = getReplayCurrentEvent(game)
    local currentEventLabel = currentEvent and formatReplayEventLabel(game, currentEvent) or "Replay loaded"
    local playbackLabel = runtime.isPlaying and "Pause" or "Play"
    local currentTimeLabel = formatSecondsLabel(runtime.currentTime or 0)
    local totalTimeLabel = formatSecondsLabel(runtime.duration or 0)
    local compatibilityStatus = game.replayRecord and game.replayRecord.mapCompatibility or "unknown"
    local showPreparationSummary = (runtime.currentTime or 0) <= 0.0005 and runtime.isPlaying ~= true
    local timelineMidY = layout.timeline.y + layout.timeline.h * 0.5
    local playheadX = getReplayTimelineX(game, runtime.currentTime or 0)

    drawReplayCursor(game)

    drawButton(layout.back, "Back To Results", { 0.09, 0.11, 0.15, 0.98 }, { 0.3, 0.36, 0.42, 1 }, game.fonts.small)
    drawButton(layout.retry, "Retry", { 0.1, 0.14, 0.18, 0.98 }, { 0.99, 0.78, 0.32, 1 }, game.fonts.small)
    drawButton(layout.toggle, playbackLabel, { 0.12, 0.17, 0.2, 0.98 }, { 0.48, 0.92, 0.62, 1 }, game.fonts.small)

    graphics.setColor(0.05, 0.07, 0.1, 0.96)
    graphics.rectangle("fill", layout.panel.x, layout.panel.y, layout.panel.w, layout.panel.h, 20, 20)
    graphics.setColor(0.26, 0.34, 0.42, 1)
    graphics.rectangle("line", layout.panel.x, layout.panel.y, layout.panel.w, layout.panel.h, 20, 20)

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.print("Replay", layout.panel.x + 22, layout.panel.y + 14)
    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.72, 0.78, 0.84, 1)
    graphics.printf(
        currentEventLabel,
        layout.panel.x + 22,
        layout.panel.y + 18,
        layout.panel.w - 44,
        "right"
    )

    local compatibilityLabel = "Replay Unverified"
    local compatibilityColor = { 0.72, 0.78, 0.84, 1 }
    if compatibilityStatus == "stale" then
        compatibilityLabel = "Replay Outdated"
        compatibilityColor = { 0.99, 0.78, 0.32, 1 }
    elseif compatibilityStatus == "matching" then
        compatibilityLabel = "Replay Valid"
        compatibilityColor = { 0.48, 0.92, 0.62, 1 }
    end

    local compatibilityWidth = game.fonts.small:getWidth(compatibilityLabel)
    local preparationSummary = showPreparationSummary and getReplayPreparationSummary(game, 2) or nil
    local preparationSummaryGap = preparationSummary and 18 or 0
    local preparationSummaryWidth = preparationSummary
        and math.max(0, layout.timeline.w - compatibilityWidth - preparationSummaryGap)
        or 0

    graphics.setColor(0.16, 0.2, 0.25, 1)
    graphics.rectangle("fill", layout.timeline.x, layout.timeline.y, layout.timeline.w, layout.timeline.h, 8, 8)
    if preparationSummary then
        graphics.setColor(0.72, 0.78, 0.84, 1)
        graphics.printf(
            preparationSummary,
            layout.timeline.x,
            layout.timeline.y - 18,
            preparationSummaryWidth,
            "left"
        )
    end
    graphics.setColor(compatibilityColor[1], compatibilityColor[2], compatibilityColor[3], compatibilityColor[4])
    graphics.printf(
        compatibilityLabel,
        preparationSummary and (layout.timeline.x + preparationSummaryWidth + preparationSummaryGap) or layout.timeline.x,
        layout.timeline.y - 18,
        preparationSummary and compatibilityWidth or layout.timeline.w,
        "right"
    )
    graphics.setColor(0.48, 0.92, 0.62, 0.26)
    graphics.rectangle(
        "fill",
        layout.timeline.x,
        layout.timeline.y,
        math.max(0, playheadX - layout.timeline.x),
        layout.timeline.h,
        8,
        8
    )

    for _, event in ipairs(runtime.record and runtime.record.timelineEvents or {}) do
        local markerX = getReplayTimelineX(game, event.time or 0)
        local markerColor = replayEventColorByKind[event.kind] or { 0.72, 0.78, 0.84, 1 }
        graphics.setColor(markerColor[1], markerColor[2], markerColor[3], markerColor[4])
        graphics.circle("fill", markerX, timelineMidY, markerRadius)
    end

    graphics.setColor(0.98, 0.98, 1, 1)
    graphics.rectangle(
        "fill",
        playheadX - playheadWidth * 0.5,
        layout.timeline.y - 8,
        playheadWidth,
        layout.timeline.h + 16,
        2,
        2
    )

    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.print(currentTimeLabel, layout.timeline.x, layout.timeline.y + 24)
    graphics.printf(totalTimeLabel, layout.timeline.x, layout.timeline.y + 24, layout.timeline.w, "right")
    graphics.setColor(0.72, 0.78, 0.84, 1)
    graphics.printf(
        "Space Play or Pause  Left or Right Seek  Home Start  End Finish",
        layout.panel.x + 22,
        layout.panel.y + layout.panel.h - 28,
        layout.panel.w - 44,
        "center"
    )

    if game.replayHoverInfo then
        drawPlayTooltip(game, game.replayHoverInfo)
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
ui.getReplayPreparationSummary = getReplayPreparationSummary
ui.formatMarketplaceFavoriteLabel = formatMarketplaceFavoriteLabel
ui.getLevelSelectBadges = buildLevelSelectBadges

end
