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

function getCardScale(distance)
    local absDistance = math.abs(distance)
    if absDistance <= 1 then
        return lerp(1, 0.84, absDistance)
    end
    if absDistance <= 2 then
        return lerp(0.84, 0.68, absDistance - 1)
    end
    return lerp(0.68, 0.54, math.min(1, absDistance - 2))
end

function getCarouselOffset(distance)
    local direction = distance < 0 and -1 or 1
    local absDistance = math.abs(distance)
    local magnitude

    if absDistance <= 1 then
        magnitude = lerp(0, 304, absDistance)
    elseif absDistance <= 2 then
        magnitude = lerp(304, 560, absDistance - 1)
    else
        magnitude = lerp(560, 720, math.min(1, absDistance - 2))
    end

    return magnitude * direction
end

function getCarouselLift(distance)
    local absDistance = math.abs(distance)

    if absDistance <= 1 then
        return lerp(0, 42, absDistance)
    elseif absDistance <= 2 then
        return lerp(42, 76, absDistance - 1)
    end

    return lerp(76, 104, math.min(1, absDistance - 2))
end

function getWrappedDistance(index, visualIndex, count)
    local distance = index - visualIndex
    local halfCount = count * 0.5

    while distance > halfCount do
        distance = distance - count
    end

    while distance < -halfCount do
        distance = distance + count
    end

    return distance
end

function getMarketplaceFavoriteButtonRect(rect)
    if not rect then
        return nil
    end

    local buttonScale = rect.scale or 1
    local buttonWidth = math.max(
        MARKETPLACE_LAYOUT.favoriteButtonMinW,
        math.floor(MARKETPLACE_LAYOUT.favoriteButtonW * buttonScale + 0.5)
    )
    local buttonHeight = math.max(
        MARKETPLACE_LAYOUT.favoriteButtonMinH,
        math.floor(MARKETPLACE_LAYOUT.favoriteButtonH * buttonScale + 0.5)
    )
    local inset = math.floor(MARKETPLACE_LAYOUT.favoriteButtonInset * buttonScale + 0.5)
    return {
        x = rect.x + math.floor((rect.w - buttonWidth) * 0.5 + 0.5),
        y = rect.y + rect.h - buttonHeight + MARKETPLACE_LAYOUT.favoriteLift,
        w = buttonWidth,
        h = buttonHeight,
    }
end

function getMarketplaceFavoriteHoverId(descriptor)
    return descriptor and ("favorite:" .. tostring(descriptor.id or "")) or nil
end

function formatMarketplaceFavoriteLabel(favoriteCount)
    local resolvedFavoriteCount = tonumber(favoriteCount or 0) or 0
    return tostring(resolvedFavoriteCount)
end

function getMarketplaceFavoriteLabel(marketplaceEntry)
    local favoriteCount = tonumber(marketplaceEntry and marketplaceEntry.favoriteCount or 0) or 0
    return formatMarketplaceFavoriteLabel(favoriteCount)
end

function getMarketplaceFavoriteContentLayout(rect)
    local horizontalPadding = math.max(6, math.floor(rect.h * 0.22 + 0.5))
    local iconBoxW = math.max(14, math.floor(rect.h * 1.15 + 0.5))
    local iconCenterX = rect.x + horizontalPadding + math.floor(iconBoxW * 0.5 + 0.5)
    local iconCenterY = rect.y + math.floor(rect.h * 0.5 + 0.5)
    local textX = rect.x + horizontalPadding + iconBoxW + math.max(4, math.floor(rect.h * 0.16 + 0.5))
    local textRightInset = math.max(6, math.floor(rect.h * 0.22 + 0.5))

    return {
        iconCenterX = iconCenterX,
        iconCenterY = iconCenterY,
        textX = textX,
        textRightInset = textRightInset,
    }
end

function drawMarketplaceHeartIcon(rect, isLiked, lineColor, fillColor)
    local graphics = love.graphics
    local contentLayout = getMarketplaceFavoriteContentLayout(rect)
    local radius = math.max(3, math.floor(rect.h * 0.18 + 0.5))
    local leftCenterX = contentLayout.iconCenterX - math.floor(radius * 0.9 + 0.5)
    local rightCenterX = contentLayout.iconCenterX + math.floor(radius * 0.9 + 0.5)
    local topCenterY = contentLayout.iconCenterY - math.floor(radius * 0.25 + 0.5)
    local bottomY = contentLayout.iconCenterY + math.floor(radius * 1.35 + 0.5)
    local centerX = contentLayout.iconCenterX

    if isLiked then
        graphics.setColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 1)
        graphics.circle("fill", leftCenterX, topCenterY, radius)
        graphics.circle("fill", rightCenterX, topCenterY, radius)
        graphics.polygon(
            "fill",
            leftCenterX - radius,
            topCenterY,
            rightCenterX + radius,
            topCenterY,
            centerX,
            bottomY
        )
    end

    graphics.setColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4] or 1)
    graphics.setLineWidth(MARKETPLACE_LAYOUT.favoriteButtonOutlineWidth)
    graphics.circle("line", leftCenterX, topCenterY, radius)
    graphics.circle("line", rightCenterX, topCenterY, radius)
    graphics.line(leftCenterX - radius, topCenterY, centerX, bottomY, rightCenterX + radius, topCenterY)
    graphics.setLineWidth(1)
end

function drawMarketplaceFavoriteButton(game, descriptor, rect, marketplaceEntry)
    if not rect or not marketplaceEntry then
        return
    end

    local graphics = love.graphics
    local hoverId = getMarketplaceFavoriteHoverId(descriptor)
    local isHovered = game.levelSelectHoverId == hoverId
    local isLiked = marketplaceEntry.likedByPlayer == true
    local fillColor = isLiked and MARKETPLACE_FAVORITE_COLORS.likedFill or MARKETPLACE_FAVORITE_COLORS.unlikedFill
    local lineColor = isLiked and MARKETPLACE_FAVORITE_COLORS.likedLine or MARKETPLACE_FAVORITE_COLORS.unlikedLine
    local textColor = isLiked and MARKETPLACE_FAVORITE_COLORS.likedText or MARKETPLACE_FAVORITE_COLORS.unlikedText

    graphics.setColor(fillColor[1], fillColor[2], fillColor[3], isHovered and 1 or (fillColor[4] or 1))
    graphics.rectangle(
        "fill",
        rect.x,
        rect.y,
        rect.w,
        rect.h,
        MARKETPLACE_LAYOUT.favoriteButtonCornerRadius,
        MARKETPLACE_LAYOUT.favoriteButtonCornerRadius
    )
    graphics.setColor(lineColor[1], lineColor[2], lineColor[3], isHovered and 1 or (lineColor[4] or 1))
    graphics.setLineWidth(MARKETPLACE_LAYOUT.favoriteButtonOutlineWidth)
    graphics.rectangle(
        "line",
        rect.x,
        rect.y,
        rect.w,
        rect.h,
        MARKETPLACE_LAYOUT.favoriteButtonCornerRadius,
        MARKETPLACE_LAYOUT.favoriteButtonCornerRadius
    )
    graphics.setLineWidth(1)
    drawMarketplaceHeartIcon(rect, isLiked, lineColor, fillColor)

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
    local contentLayout = getMarketplaceFavoriteContentLayout(rect)
    local textRightEdge = rect.x + rect.w - contentLayout.textRightInset
    graphics.printf(
        getMarketplaceFavoriteLabel(marketplaceEntry),
        contentLayout.textX,
        rect.y + math.floor((rect.h - game.fonts.small:getHeight()) * 0.5 + 0.5),
        math.max(0, textRightEdge - contentLayout.textX),
        "right"
    )

    local favoriteAnimation = marketplaceEntry.favoriteAnimation
    local favoriteAnimationDelta = type(favoriteAnimation) == "table" and tonumber(favoriteAnimation.delta or 0) or 0
    if favoriteAnimationDelta ~= 0 then
        local progress = math.max(0, math.min(1, tonumber(favoriteAnimation.progress or 0) or 0))
        local alpha = 1 - progress
        local deltaLabel = string.format("%+d", favoriteAnimationDelta)
        graphics.setColor(textColor[1], textColor[2], textColor[3], alpha)
        graphics.printf(
            deltaLabel,
            contentLayout.textX,
            rect.y - MARKETPLACE_LAYOUT.favoritePlusOneBaseOffset - math.floor(MARKETPLACE_LAYOUT.favoritePlusOneRise * progress + 0.5),
            math.max(0, textRightEdge - contentLayout.textX),
            "right"
        )
    end
end

function buildLevelSelectCardRects(game)
    local maps = getLevelSelectMaps(game)
    local selectedIndex = getSelectedMapIndex(game, maps)
    local rects = {}

    if not selectedIndex then
        return rects, maps, nil
    end

    local visualIndex = game.levelSelectVisualIndex or selectedIndex
    local centerX = game.viewport.w * 0.5
    for index, descriptor in ipairs(maps) do
        local distance = getWrappedDistance(index, visualIndex, #maps)
        if math.abs(distance) <= 2.4 then
            local scale = getCardScale(distance)
            local width = math.floor(LEVEL_SELECT.cardBaseW * scale + 0.5)
            local height = math.floor(LEVEL_SELECT.cardBaseH * scale + 0.5)
            local centerOffset = getCarouselOffset(distance)
            local x = math.floor(centerX + centerOffset - width * 0.5 + 0.5)
            local y = math.floor(LEVEL_SELECT.carouselCenterY - height * 0.5 + getCarouselLift(distance) + 0.5)
            rects[#rects + 1] = {
                map = descriptor,
                index = index,
                selected = math.abs(distance) < 0.35,
                distance = distance,
                scale = scale,
                x = x,
                y = y,
                w = width,
                h = height,
            }
            if game.levelSelectMode == "marketplace" and descriptor.source == MARKETPLACE_REMOTE_SOURCE then
                rects[#rects].favoriteButtonRect = getMarketplaceFavoriteButtonRect(rects[#rects])
            end

            local badgeGap = 12
            local badgeH = 22
            local badgeWidths, badgeTotalWidth = buildCardBadges(game, descriptor, width - 36)
            local badgeBottomPadding = 18
            local favoriteButtonRect = rects[#rects].favoriteButtonRect
            local badgeY = y + height - badgeH - badgeBottomPadding
            if favoriteButtonRect then
                badgeY = favoriteButtonRect.y - badgeH - MARKETPLACE_LAYOUT.favoriteSpacing
            end
            local previewTop = y + 18
            local previewBottom = badgeY - badgeGap
            rects[#rects].previewRect = {
                x = x + 18,
                y = previewTop,
                w = width - 36,
                h = math.max(56, previewBottom - previewTop),
            }
            rects[#rects].badgeRow = {
                x = x + math.floor((width - badgeTotalWidth) * 0.5 + 0.5),
                y = badgeY,
                badges = badgeWidths,
                totalWidth = badgeTotalWidth,
            }
            local badgeRects = {}
            local badgeX = rects[#rects].badgeRow.x
            for _, badge in ipairs(badgeWidths) do
                badgeRects[#badgeRects + 1] = {
                    badge = badge,
                    x = badgeX,
                    y = badgeY,
                    w = badge.width,
                    h = badgeH,
                }
                badgeX = badgeX + badge.width + 6
            end
            rects[#rects].badgeRow.badgeRects = badgeRects
        end
    end

    table.sort(rects, function(a, b)
        local aDistance = math.abs(a.distance)
        local bDistance = math.abs(b.distance)
        if aDistance ~= bDistance then
            return aDistance > bDistance
        end
        return a.distance < b.distance
    end)

    return rects, maps, selectedIndex
end

function drawControlBadges(game, descriptor, x, y, maxWidth, badgeRow)
    local graphics = love.graphics
    love.graphics.setFont(game.fonts.small)

    local widths = {}
    local totalWidth = 0

    if badgeRow and badgeRow.badges then
        widths = badgeRow.badges
        totalWidth = badgeRow.totalWidth or 0
    else
        widths, totalWidth = buildCardBadges(game, descriptor, maxWidth)
    end

    local badgeX = x + math.floor((maxWidth - totalWidth) * 0.5 + 0.5)
    for _, badge in ipairs(widths) do
        local fillColor = badge.fillColor or PREVIEW_COLORS.control[badge.controlType] or PREVIEW_COLORS.control.direct
        local lineColor = badge.lineColor or { 0.06, 0.08, 0.1, 0.4 }
        local textColor = badge.textColor or { 0.08, 0.1, 0.14, 1 }
        graphics.setColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 0.96)
        graphics.rectangle("fill", badgeX, y, badge.width, 22, 11, 11)
        graphics.setColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4] or 1)
        graphics.rectangle("line", badgeX, y, badge.width, 22, 11, 11)
        graphics.setColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
        graphics.printf(badge.label, badgeX, y + 3, badge.width, "center")
        badgeX = badgeX + badge.width + 6
    end
end

function getLevelSelectBadgeHoverInfo(game, x, y)
    for _, rect in ipairs(buildLevelSelectCardRects(game)) do
        local badgeRow = rect.badgeRow
        for _, badgeRect in ipairs(badgeRow and badgeRow.badgeRects or {}) do
            if pointInRect(x, y, badgeRect) then
                return {
                    x = badgeRect.x + badgeRect.w * 0.5,
                    y = badgeRect.y,
                    title = badgeRect.badge.tooltipTitle or badgeRect.badge.label,
                    text = badgeRect.badge.tooltipText or badgeRect.badge.label,
                }
            end
        end
    end

    return nil
end

function drawLevelSelectChrome(game)
    local graphics = love.graphics
    local bottomBarRect = getLevelSelectBottomBarRect(game)
    graphics.setColor(0.08, 0.12, 0.18, 0.82)
    graphics.circle("fill", 164, 188, 168)
    graphics.circle("fill", 1082, 274, 214)
    graphics.circle("fill", 1014, 628, 178)

    graphics.setColor(0.18, 0.26, 0.34, 0.5)
    graphics.setLineWidth(2)
    graphics.setLineWidth(1)

    drawMetalPanel(bottomBarRect, 0.98)
end

getMarketplaceEntryForDescriptor = function(game, descriptor)
    if game.levelSelectMode ~= "marketplace" or not descriptor then
        return nil
    end

    local entries = buildMarketplaceDisplayEntries(game)
    for _, entry in ipairs(entries) do
        if entry.descriptor.id == descriptor.id then
            return entry
        end
    end

    return nil
end

getMarketplaceIndicatorColors = function(game, marketplaceEntry)
    local defaultColors = {
        fill = { 0.12, 0.17, 0.24, 0.98 },
        line = { 0.56, 0.72, 0.98, 1 },
        text = PANEL_COLORS.titleText,
    }

    if game.levelSelectMarketplaceTab ~= "top" or not marketplaceEntry then
        return defaultColors
    end

    local position = tonumber(marketplaceEntry.position) or 0
    if position == 1 then
        return {
            fill = { 0.42, 0.31, 0.08, 0.98 },
            line = { 0.99, 0.83, 0.32, 1 },
            text = { 1, 0.97, 0.82, 1 },
        }
    end
    if position == 2 then
        return {
            fill = { 0.24, 0.28, 0.34, 0.98 },
            line = { 0.82, 0.88, 0.96, 1 },
            text = { 0.97, 0.98, 1, 1 },
        }
    end
    if position == 3 then
        return {
            fill = { 0.34, 0.18, 0.1, 0.98 },
            line = { 0.91, 0.58, 0.32, 1 },
            text = { 1, 0.92, 0.86, 1 },
        }
    end
    if position >= 4 and position <= 10 then
        return {
            fill = { 0.14, 0.2, 0.28, 0.98 },
            line = { 0.48, 0.66, 0.88, 1 },
            text = { 0.93, 0.96, 1, 1 },
        }
    end

    return defaultColors
end

function getLevelSelectTitleText(game, selectedMap)
    if game.levelSelectMode == "marketplace" then
        local sectionLabel = "Top Maps"
        local selectedEntry = getMarketplaceEntryForDescriptor(game, selectedMap)
        local marketplaceState = game.getMarketplaceViewState and game:getMarketplaceViewState() or nil
        if game.levelSelectMarketplaceTab == "random" then
            sectionLabel = "Random"
        elseif game.levelSelectMarketplaceTab == "search" then
            sectionLabel = "Search"
        end

        if selectedEntry then
            return selectedEntry.title, string.format(
                "Online Maps  |  %s  |  %s votes  |  by %s",
                selectedEntry.positionLabel or sectionLabel,
                tostring(selectedEntry.favoriteCount or 0),
                selectedEntry.creatorDisplayName or "Unknown"
            )
        end
        if marketplaceState and marketplaceState.message and marketplaceState.status ~= "ready" then
            return "Online Maps", marketplaceState.message
        end
        return "Online Maps", string.format("Online Maps  |  %s", sectionLabel)
    end

    if not selectedMap then
        return "Level Select", "Pick a map to start or edit."
    end

    return getMapDisplayName(selectedMap), getMapKindLabel(selectedMap)
end

function drawLevelSelectTitleBar(game, selectedMap)
    local graphics = love.graphics
    local barRect = getLevelSelectTitleBarRect(game)

    graphics.setColor(PANEL_COLORS.panelFill[1], PANEL_COLORS.panelFill[2], PANEL_COLORS.panelFill[3], PANEL_COLORS.panelFill[4])
    graphics.rectangle("fill", barRect.x, barRect.y, barRect.w, barRect.h, 12, 12)
    graphics.setLineWidth(2)
    graphics.setColor(PANEL_COLORS.panelLine[1], PANEL_COLORS.panelLine[2], PANEL_COLORS.panelLine[3], PANEL_COLORS.panelLine[4])
    graphics.rectangle("line", barRect.x, barRect.y, barRect.w, barRect.h, 12, 12)
    graphics.setColor(PANEL_COLORS.panelInnerLine[1], PANEL_COLORS.panelInnerLine[2], PANEL_COLORS.panelInnerLine[3], PANEL_COLORS.panelInnerLine[4])
    graphics.rectangle("line", barRect.x + 4, barRect.y + 4, barRect.w - 8, barRect.h - 8, 10, 10)
    graphics.setLineWidth(1)

    local titleText, subtitleText = getLevelSelectTitleText(game, selectedMap)

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(PANEL_COLORS.titleText[1], PANEL_COLORS.titleText[2], PANEL_COLORS.titleText[3], PANEL_COLORS.titleText[4])
    graphics.printf(titleText, barRect.x + 30, barRect.y + 8, barRect.w - 60, "center")

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(PANEL_COLORS.bodyText[1], PANEL_COLORS.bodyText[2], PANEL_COLORS.bodyText[3], PANEL_COLORS.bodyText[4])
    graphics.printf(subtitleText, barRect.x + 30, barRect.y + MARKETPLACE_LAYOUT.titleMetaTop, barRect.w - 60, "center")
end

function isLevelSelectLeaderboardCardFlipped(game, rect)
    local mapUuid = rect and rect.map and rect.map.mapUuid or nil
    return rect
        and rect.selected
        and mapUuid
        and mapUuid ~= ""
        and game.levelSelectLeaderboardFlipMapUuid == mapUuid
end

function drawLevelSelectLeaderboardRow(game, rowRect, entry, isHighlighted)
    local graphics = love.graphics
    local hasReplay = tostring(entry and entry.replayUuid or "") ~= ""
        or tostring(entry and entry.replayFilePath or "") ~= ""
    local rankText = tostring(entry.rank or "-")
    local fillColor = isHighlighted and { 0.16, 0.28, 0.38, 0.98 } or { 0.08, 0.11, 0.15, 0.96 }
    local lineColor = isHighlighted and { 0.48, 0.72, 0.92, 1 } or { 0.24, 0.32, 0.4, 1 }
    local nameColor = hasReplay and { 0.84, 0.95, 1, 1 } or PANEL_COLORS.bodyText

    if hasReplay and not isHighlighted then
        lineColor = { 0.34, 0.56, 0.74, 1 }
    end

    graphics.setColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4])
    graphics.rectangle("fill", rowRect.x, rowRect.y, rowRect.w, rowRect.h, LEVEL_SELECT_LEADERBOARD_CARD.rowRadius, LEVEL_SELECT_LEADERBOARD_CARD.rowRadius)
    graphics.setColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
    graphics.rectangle("line", rowRect.x, rowRect.y, rowRect.w, rowRect.h, LEVEL_SELECT_LEADERBOARD_CARD.rowRadius, LEVEL_SELECT_LEADERBOARD_CARD.rowRadius)

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(PANEL_COLORS.bodyText[1], PANEL_COLORS.bodyText[2], PANEL_COLORS.bodyText[3], PANEL_COLORS.bodyText[4])
    graphics.printf(
        rankText,
        rowRect.x + LEVEL_SELECT_LEADERBOARD_CARD.rowPaddingX,
        rowRect.y + 4,
        LEVEL_SELECT_LEADERBOARD_CARD.rankWidth,
        "left"
    )

    local nameX = rowRect.x + LEVEL_SELECT_LEADERBOARD_CARD.rowPaddingX + LEVEL_SELECT_LEADERBOARD_CARD.rankWidth
    local nameWidth = rowRect.w - LEVEL_SELECT_LEADERBOARD_CARD.rankWidth - LEVEL_SELECT_LEADERBOARD_CARD.scoreWidth - (LEVEL_SELECT_LEADERBOARD_CARD.rowPaddingX * 2)
    if hasReplay then
        local indicatorDiameter = LEVEL_SELECT_LEADERBOARD_CARD.replayIndicatorDiameter
        local indicatorRadius = LEVEL_SELECT_LEADERBOARD_CARD.replayIndicatorRadius
        local rankX = rowRect.x + LEVEL_SELECT_LEADERBOARD_CARD.rowPaddingX
        local rankTextWidth = game.fonts.small:getWidth(rankText)
        local indicatorX = rankX + rankTextWidth + LEVEL_SELECT_LEADERBOARD_CARD.replayIndicatorRankGap
        local indicatorY = rowRect.y + math.floor((rowRect.h - indicatorDiameter) * 0.5 + 0.5)
        local indicatorCenterX = indicatorX + indicatorRadius
        local indicatorCenterY = indicatorY + indicatorRadius
        local nameStartX = indicatorX
            + indicatorDiameter
            + LEVEL_SELECT_LEADERBOARD_CARD.replayIndicatorNameGap

        graphics.setColor(0.52, 0.08, 0.08, 0.98)
        graphics.circle(
            "fill",
            indicatorCenterX,
            indicatorCenterY,
            indicatorRadius
        )
        graphics.setColor(0.98, 0.24, 0.24, 1)
        graphics.circle("fill", indicatorCenterX, indicatorCenterY, indicatorRadius - 2)
        graphics.setColor(1, 0.88, 0.88, 0.9)
        graphics.circle("line", indicatorCenterX, indicatorCenterY, indicatorRadius)

        if nameStartX > nameX then
            local nameShift = nameStartX - nameX
            nameX = nameStartX
            nameWidth = nameWidth - nameShift
        end
    end

    graphics.setColor(nameColor[1], nameColor[2], nameColor[3], nameColor[4])
    graphics.printf(
        formatLevelSelectLeaderboardPlayerName(entry.playerDisplayName or "Unknown"),
        nameX,
        rowRect.y + 4,
        math.max(0, nameWidth),
        "left"
    )

    graphics.printf(
        formatLeaderboardScore(entry.score or 0),
        rowRect.x + rowRect.w - LEVEL_SELECT_LEADERBOARD_CARD.scoreWidth - LEVEL_SELECT_LEADERBOARD_CARD.rowPaddingX,
        rowRect.y + 4,
        LEVEL_SELECT_LEADERBOARD_CARD.scoreWidth,
        "right"
    )
end

function buildLevelSelectLeaderboardBackRows(game, rect)
    local previewState = game:getLevelSelectPreviewDisplayState(rect.map)
    local topEntries, pinnedPlayerEntry = getLevelSelectLeaderboardVisibleEntries(
        previewState.topEntries or {},
        previewState.pinnedPlayerEntry,
        LEVEL_SELECT_LEADERBOARD_CARD.maxRows
    )
    local contentRect = {
        x = rect.x + LEVEL_SELECT_LEADERBOARD_CARD.inset,
        y = rect.y + LEVEL_SELECT_LEADERBOARD_CARD.inset,
        w = rect.w - (LEVEL_SELECT_LEADERBOARD_CARD.inset * 2),
        h = rect.h - (LEVEL_SELECT_LEADERBOARD_CARD.inset * 2),
    }
    local rowRects = {}
    local rowY = contentRect.y + LEVEL_SELECT_LEADERBOARD_CARD.rowTop

    for _, entry in ipairs(topEntries) do
        rowRects[#rowRects + 1] = {
            x = contentRect.x,
            y = rowY,
            w = contentRect.w,
            h = LEVEL_SELECT_LEADERBOARD_CARD.rowHeight,
            entry = entry,
        }
        rowY = rowY + LEVEL_SELECT_LEADERBOARD_CARD.rowHeight + LEVEL_SELECT_LEADERBOARD_CARD.rowGap
    end

    if pinnedPlayerEntry then
        rowRects[#rowRects + 1] = {
            x = contentRect.x,
            y = getLevelSelectLeaderboardPinnedRowY(contentRect, #topEntries),
            w = contentRect.w,
            h = LEVEL_SELECT_LEADERBOARD_CARD.rowHeight,
            entry = pinnedPlayerEntry,
            pinned = true,
        }
    end

    return contentRect, previewState, topEntries, pinnedPlayerEntry, rowRects
end

function getLevelSelectLeaderboardVisibleEntries(topEntries, pinnedPlayerEntry, maxRows)
    local resolvedMaxRows = math.max(0, tonumber(maxRows) or LEVEL_SELECT_LEADERBOARD_CARD.maxRows)
    local visibleTopEntries = {}
    local visiblePinnedPlayerEntry = pinnedPlayerEntry
    local visibleTopEntryLimit = resolvedMaxRows
    local pinnedPlayerUuid = tostring(
        visiblePinnedPlayerEntry
            and (visiblePinnedPlayerEntry.playerUuid or visiblePinnedPlayerEntry.player_uuid)
            or ""
    )

    if pinnedPlayerUuid ~= "" then
        for _, entry in ipairs(topEntries or {}) do
            if tostring(entry and (entry.playerUuid or entry.player_uuid) or "") == pinnedPlayerUuid then
                visiblePinnedPlayerEntry = nil
                break
            end
        end
    end

    if visiblePinnedPlayerEntry and visibleTopEntryLimit > 0 then
        visibleTopEntryLimit = visibleTopEntryLimit - 1
    end

    for index, entry in ipairs(topEntries or {}) do
        if index > visibleTopEntryLimit then
            break
        end

        visibleTopEntries[#visibleTopEntries + 1] = entry
    end

    if resolvedMaxRows <= 0 then
        visiblePinnedPlayerEntry = nil
    end

    return visibleTopEntries, visiblePinnedPlayerEntry
end

function getLevelSelectLeaderboardPinnedRowY(contentRect, visibleEntryCount)
    local resolvedVisibleEntryCount = math.max(0, tonumber(visibleEntryCount) or 0)
    local baseRowY = contentRect.y + LEVEL_SELECT_LEADERBOARD_CARD.rowTop

    if resolvedVisibleEntryCount == 0 then
        return baseRowY
    end

    return baseRowY
        + (resolvedVisibleEntryCount * LEVEL_SELECT_LEADERBOARD_CARD.rowHeight)
        + ((resolvedVisibleEntryCount - 1) * LEVEL_SELECT_LEADERBOARD_CARD.rowGap)
        + LEVEL_SELECT_LEADERBOARD_CARD.pinnedGap
end

function shouldShowLevelSelectLeaderboardMessage(topEntries, pinnedPlayerEntry, previewState)
    local hasTopEntries = #(topEntries or {}) > 0
    local hasPinnedEntry = pinnedPlayerEntry ~= nil

    return not hasTopEntries
        and not hasPinnedEntry
        and not (previewState and previewState.isLoading)
        and previewState
        and previewState.message ~= nil
end

function drawLevelSelectLeaderboardBack(game, rect)
    local graphics = love.graphics
    local contentRect, previewState, topEntries, pinnedPlayerEntry, rowRects = buildLevelSelectLeaderboardBackRows(game, rect)

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(PANEL_COLORS.titleText[1], PANEL_COLORS.titleText[2], PANEL_COLORS.titleText[3], PANEL_COLORS.titleText[4])
    graphics.printf(previewState.title or "Leaderboard", contentRect.x, contentRect.y + LEVEL_SELECT_LEADERBOARD_CARD.titleTop, contentRect.w, "center")

    for index, rowRect in ipairs(rowRects) do
        local entry = rowRect.entry
        local profilePlayerUuid = tostring(game.profile and game.profile.player_uuid or "")
        local isPlayerEntry = tostring(entry.playerUuid or "") == profilePlayerUuid
        drawLevelSelectLeaderboardRow(game, rowRect, entry, isPlayerEntry)
        if index >= LEVEL_SELECT_LEADERBOARD_CARD.maxRows and not rowRect.pinned then
            break
        end
    end

    if not pinnedPlayerEntry and previewState.isLoading and #topEntries == 0 then
        drawLoadingSpinner(
            contentRect.x + math.floor(contentRect.w * 0.5 + 0.5),
            contentRect.y + math.floor(contentRect.h * 0.56 + 0.5),
            { 0.48, 0.92, 0.62, 1 }
        )
    elseif shouldShowLevelSelectLeaderboardMessage(topEntries, pinnedPlayerEntry, previewState) then
        love.graphics.setFont(game.fonts.small)
        graphics.setColor(PANEL_COLORS.mutedText[1], PANEL_COLORS.mutedText[2], PANEL_COLORS.mutedText[3], PANEL_COLORS.mutedText[4])
        graphics.printf(
            previewState.message,
            contentRect.x + LEVEL_SELECT_LEADERBOARD_CARD.statusPaddingX,
            contentRect.y + math.floor(contentRect.h * 0.52 + 0.5),
            math.max(0, contentRect.w - LEVEL_SELECT_LEADERBOARD_CARD.statusWidthMargin),
            "center"
        )
    end

    drawLevelSelectLeaderboardRefreshIndicator(game, contentRect, previewState)
end

function drawLevelCard(game, rect)
    local graphics = love.graphics
    local descriptor = rect.map
    local marketplaceEntry = getMarketplaceEntryForDescriptor(game, descriptor)
    local selected = rect.selected
    local cardFill = selected and { 0.09, 0.11, 0.15, 0.98 } or { 0.08, 0.1, 0.13, 0.94 }
    local trim = selected and { 0.45, 0.7, 0.92, 1 } or { 0.24, 0.34, 0.44, 0.95 }

    graphics.setColor(0.09, 0.1, 0.11, 0.26)
    graphics.rectangle("fill", rect.x + 6, rect.y + rect.h - 8, rect.w, 16, 10, 10)

    graphics.setColor(cardFill[1], cardFill[2], cardFill[3], cardFill[4])
    graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 18, 18)
    graphics.setColor(trim[1], trim[2], trim[3], trim[4])
    graphics.setLineWidth(selected and 4 or 3)
    graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 18, 18)
    graphics.rectangle("line", rect.x + 4, rect.y + 4, rect.w - 8, rect.h - 8, 14, 14)

    if selected then
        graphics.setColor(0.2, 0.72, 0.96, 0.18)
        graphics.rectangle("line", rect.x - 6, rect.y - 6, rect.w + 12, rect.h + 12, 22, 22)
    end

    if isLevelSelectLeaderboardCardFlipped(game, rect) then
        drawLevelSelectLeaderboardBack(game, rect)
    else
        drawMapPreview(descriptor, rect.previewRect)
        drawMarketplaceFavoriteButton(game, descriptor, rect.favoriteButtonRect, marketplaceEntry)

        local badgeY = rect.badgeRow and rect.badgeRow.y or (rect.y + rect.h - 40)
        drawControlBadges(game, descriptor, rect.x + 18, badgeY, rect.w - 36, rect.badgeRow)
    end
end

function drawLevelSelectEmptyState(game, filterId)
    local graphics = love.graphics
    local panel = {
        x = game.viewport.w * 0.5 - 210,
        y = 250,
        w = 420,
        h = 150,
    }

    drawMetalPanel(panel, 0.96)

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(PANEL_COLORS.titleText[1], PANEL_COLORS.titleText[2], PANEL_COLORS.titleText[3], PANEL_COLORS.titleText[4])
    graphics.printf("No maps in this section yet.", panel.x + 24, panel.y + 38, panel.w - 48, "center")

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(PANEL_COLORS.bodyText[1], PANEL_COLORS.bodyText[2], PANEL_COLORS.bodyText[3], PANEL_COLORS.bodyText[4])
    if filterId == "marketplace" then
        local marketplaceState = game.getMarketplaceViewState and game:getMarketplaceViewState() or nil
        graphics.printf(
            (marketplaceState and marketplaceState.message) or "Try a different online tab or broaden the search term.",
            panel.x + 34,
            panel.y + 78,
            panel.w - 68,
            "center"
        )
    elseif filterId == "user" then
        graphics.printf("Open the editor and save a map to have it show up here.", panel.x + 34, panel.y + 78, panel.w - 68, "center")
    elseif filterId == "downloaded" then
        graphics.printf("Download a map from the online store to have it show up here.", panel.x + 34, panel.y + 78, panel.w - 68, "center")
    else
        graphics.printf("Switch filters or pick All to browse the full level list.", panel.x + 34, panel.y + 78, panel.w - 68, "center")
    end
end

function drawMarketplaceSearchField(game)
    local graphics = love.graphics
    local searchRect = getMarketplaceSearchRect(game)
    local query = game.levelSelectMarketplaceSearchQuery or ""
    local hasQuery = query ~= ""

    graphics.setColor(0.08, 0.1, 0.14, 0.98)
    graphics.rectangle("fill", searchRect.x, searchRect.y, searchRect.w, searchRect.h, 14, 14)
    graphics.setColor(0.44, 0.62, 0.78, 1)
    graphics.rectangle("line", searchRect.x, searchRect.y, searchRect.w, searchRect.h, 14, 14)

    love.graphics.setFont(game.fonts.body)
    if hasQuery then
        graphics.setColor(PANEL_COLORS.titleText[1], PANEL_COLORS.titleText[2], PANEL_COLORS.titleText[3], PANEL_COLORS.titleText[4])
    else
        graphics.setColor(PANEL_COLORS.mutedText[1], PANEL_COLORS.mutedText[2], PANEL_COLORS.mutedText[3], PANEL_COLORS.mutedText[4])
    end
    graphics.printf(
        hasQuery and query or "Search maps, ids, or tags",
        searchRect.x + 16,
        searchRect.y + 11,
        searchRect.w - 32,
        "left"
    )
end

function getMenuButtons(game)
    local centerX = math.floor((game.viewport.w - MENU_LAYOUT.buttonWidth) * 0.5 + 0.5)
    local buttonY = MENU_LAYOUT.firstButtonY
    return {
        {
            id = "play",
            x = centerX,
            y = buttonY,
            w = MENU_LAYOUT.buttonWidth,
            h = MENU_LAYOUT.buttonHeight,
            label = "Level Select",
        },
        {
            id = "leaderboard",
            x = centerX,
            y = buttonY + MENU_LAYOUT.buttonHeight + MENU_LAYOUT.buttonGap,
            w = MENU_LAYOUT.buttonWidth,
            h = MENU_LAYOUT.buttonHeight,
            label = game:getLeaderboardButtonLabel(),
        },
        {
            id = "editor",
            x = centerX,
            y = buttonY + ((MENU_LAYOUT.buttonHeight + MENU_LAYOUT.buttonGap) * 2),
            w = MENU_LAYOUT.buttonWidth,
            h = MENU_LAYOUT.buttonHeight,
            label = "Map Editor",
        },
        {
            id = "toggle_play_mode",
            x = centerX,
            y = buttonY + ((MENU_LAYOUT.buttonHeight + MENU_LAYOUT.buttonGap) * 3),
            w = MENU_LAYOUT.buttonWidth,
            h = MENU_LAYOUT.buttonHeight,
            label = game:getPlayModeButtonLabel(),
        },
        {
            id = "quit",
            x = centerX,
            y = buttonY + ((MENU_LAYOUT.buttonHeight + MENU_LAYOUT.buttonGap) * 4),
            w = MENU_LAYOUT.buttonWidth,
            h = MENU_LAYOUT.buttonHeight,
            label = "Quit",
        },
    }
end

function getProfileSetupConfirmRect(game)
    return {
        x = game.viewport.w * 0.5 - 110,
        y = 430,
        w = 220,
        h = 52,
    }
end

function getProfileModeSetupPanelRect(game)
    return {
        x = math.floor(game.viewport.w * 0.5 - PROFILE_MODE_SETUP_LAYOUT.panelW * 0.5 + 0.5),
        y = math.floor(game.viewport.h * 0.5 - PROFILE_MODE_SETUP_LAYOUT.panelH * 0.5 + 0.5),
        w = PROFILE_MODE_SETUP_LAYOUT.panelW,
        h = PROFILE_MODE_SETUP_LAYOUT.panelH,
    }
end

function getProfileModeSetupOptionRects(game)
    local panel = getProfileModeSetupPanelRect(game)
    local totalWidth = (PROFILE_MODE_SETUP_LAYOUT.buttonW * 2) + PROFILE_MODE_SETUP_LAYOUT.buttonGap
    local startX = panel.x + math.floor((panel.w - totalWidth) * 0.5 + 0.5)

    return {
        online = {
            x = startX,
            y = panel.y + PROFILE_MODE_SETUP_LAYOUT.buttonY,
            w = PROFILE_MODE_SETUP_LAYOUT.buttonW,
            h = PROFILE_MODE_SETUP_LAYOUT.buttonH,
        },
        offline = {
            x = startX + PROFILE_MODE_SETUP_LAYOUT.buttonW + PROFILE_MODE_SETUP_LAYOUT.buttonGap,
            y = panel.y + PROFILE_MODE_SETUP_LAYOUT.buttonY,
            w = PROFILE_MODE_SETUP_LAYOUT.buttonW,
            h = PROFILE_MODE_SETUP_LAYOUT.buttonH,
        },
    }
end

function getLeaderboardActionRects(game)
    return {
        back = { x = 42, y = 38, w = 148, h = 42 },
    }
end

function ui.getLevelSelectMapDescriptors(game)
    return getLevelSelectMaps(game)
end

function ui.getLevelSelectScrollUnit()
    return 1
end

function ui.clampLevelSelectScroll(_, _)
    return 0
end

function ui.scrollLevelSelectToMap(_, _, currentScroll)
    return currentScroll or 0
end

function ui.getMenuActionAt(game, x, y)
    local buttons = getMenuButtons(game)

    for _, rect in ipairs(buttons) do
        if pointInRect(x, y, rect) then
            return rect.id
        end
    end

    return nil
end

function ui.getProfileSetupActionAt(game, x, y)
    if pointInRect(x, y, getProfileSetupConfirmRect(game)) then
        return "confirm"
    end
    return nil
end

function ui.getProfileModeSetupActionAt(game, x, y)
    local optionRects = getProfileModeSetupOptionRects(game)
    if pointInRect(x, y, optionRects.online) then
        return "online"
    end
    if pointInRect(x, y, optionRects.offline) then
        return "offline"
    end
    return nil
end

function ui.getLeaderboardActionAt(game, x, y)
    local buttons = getLeaderboardActionRects(game)
    if pointInRect(x, y, buttons.back) then
        return "back"
    end
    if pointInRect(x, y, getLeaderboardFilterBadgeRect(game)) then
        return "cycle_filter"
    end
    return nil
end

function ui.getLeaderboardHoverInfoAt(game, x, y)
    local state = game.leaderboardState or { entries = {} }
    local rowRects = buildLeaderboardRowRects(game, state.entries or {})

    for _, rowRect in ipairs(rowRects) do
        if pointInRect(x, y, rowRect.player) then
            return {
                x = x,
                y = y,
                label = "Player ID",
                text = rowRect.entry.playerUuid or "No player ID",
            }
        end

        if rowRect.map and pointInRect(x, y, rowRect.map) then
            local mapCount = tonumber(rowRect.entry.mapCount) or 0
            local mapLabel = mapCount > 1
                and string.format("Latest map UUID, %d maps total", mapCount)
                or "Latest map UUID"
            return {
                x = x,
                y = y,
                label = mapLabel,
                text = rowRect.entry.mapUuid or "No map UUID",
            }
        end
    end

    if pointInRect(x, y, getLeaderboardFilterBadgeRect(game)) then
        return {
            x = x,
            y = y,
            label = game.leaderboardMapUuid and "Map UUID" or "Map Filter",
            text = game.leaderboardMapUuid or "Click to cycle through all maps.",
        }
    end

    return nil
end

function ui.getLeaderboardMapHitAt(game, x, y)
    local state = game.leaderboardState or { entries = {} }
    local rowRects = buildLeaderboardRowRects(game, state.entries or {})

    for _, rowRect in ipairs(rowRects) do
        if rowRect.map and pointInRect(x, y, rowRect.map) and rowRect.entry.mapUuid and rowRect.entry.mapUuid ~= "" then
            return {
                mapUuid = rowRect.entry.mapUuid,
                mapName = rowRect.entry.mapName,
            }
        end
    end

    return nil
end

function ui.getLevelSelectHit(game, x, y, button)
    if game.levelSelectUploadDialog then
        local overlay = ui.getLevelSelectUploadDialogRects(game)
        if pointInRect(x, y, overlay.copy) or pointInRect(x, y, overlay.value) then
            return { kind = "upload_dialog_copy" }
        end
        if pointInRect(x, y, overlay.close) then
            return { kind = "upload_dialog_close" }
        end
        if not pointInRect(x, y, overlay.panel) then
            return { kind = "upload_dialog_close" }
        end
        return { kind = "upload_dialog_blocked" }
    end

    if game.levelSelectReplayOverlay then
        local overlay = ui.getLevelSelectReplayOverlayRects(game)
        for _, rowRect in ipairs(overlay.rows or {}) do
            if pointInRect(x, y, rowRect) then
                return {
                    kind = "replay_overlay_select",
                    replayUuid = rowRect.entry and rowRect.entry.replayUuid or nil,
                }
            end
        end
        if pointInRect(x, y, overlay.start) then
            return { kind = "replay_overlay_open" }
        end
        if pointInRect(x, y, overlay.close) then
            return { kind = "replay_overlay_close" }
        end
        if not pointInRect(x, y, overlay.panel) then
            return { kind = "replay_overlay_close" }
        end
        return { kind = "replay_overlay_blocked" }
    end

    if game.levelSelectIssue then
        local overlay = getLevelIssueOverlayRects(game)
        if pointInRect(x, y, overlay.edit) then
            return { kind = "issue_edit", map = game.levelSelectIssue.map }
        end
        if pointInRect(x, y, overlay.cancel) then
            return { kind = "issue_cancel" }
        end
        if not pointInRect(x, y, overlay.panel) then
            return { kind = "issue_cancel" }
        end
        return { kind = "issue_blocked" }
    end

    if pointInRect(x, y, getLevelSelectBackRect(game)) then
        return { kind = "back" }
    end

    local modeSelectorRect = getLevelSelectModeSelectorRect(game)
    if pointInRect(x, y, modeSelectorRect) then
        local modeSegments = getLevelSelectModeSegments()
        for index, segment in ipairs(modeSegments) do
            if pointInRect(x, y, uiControls.segmentRect(modeSelectorRect, index, #modeSegments)) then
                if segment.id == "marketplace" and not game:isOnlineMode() then
                    return nil
                end
                return { kind = "set_mode", mode = segment.id }
            end
        end
    end

    if game.levelSelectMode == "marketplace" then
        local tabsRect = getMarketplaceTabsRect(game)
        local tabSegments = getMarketplaceTabSegments()
        if pointInRect(x, y, tabsRect) then
            for index, segment in ipairs(tabSegments) do
                if pointInRect(x, y, uiControls.segmentRect(tabsRect, index, #tabSegments)) then
                    return { kind = "set_marketplace_tab", tab = segment.id }
                end
            end
        end
        local marketplaceMaps = getLevelSelectMaps(game)
        local selectedMarketplaceIndex = getSelectedMapIndex(game, marketplaceMaps)
        local selectedMarketplaceMap = selectedMarketplaceIndex and marketplaceMaps[selectedMarketplaceIndex] or nil
        for _, buttonRect in ipairs(getLevelSelectActionButtons(game)) do
            if buttonRect.id ~= "back" and pointInRect(x, y, buttonRect) then
                return {
                    kind = buttonRect.id,
                    map = selectedMarketplaceMap,
                }
            end
        end
        for _, rect in ipairs(buildLevelSelectCardRects(game)) do
            if rect.favoriteButtonRect and pointInRect(x, y, rect.favoriteButtonRect) then
                return { kind = "favorite_map", map = rect.map }
            end
            if rect.selected and isLevelSelectLeaderboardCardFlipped(game, rect) and button == 1 then
                local _, _, _, _, rowRects = buildLevelSelectLeaderboardBackRows(game, rect)
                for _, rowRect in ipairs(rowRects) do
                    if pointInRect(x, y, rowRect) then
                        if tostring(rowRect.entry and rowRect.entry.replayUuid or "") ~= "" then
                            return {
                                kind = "open_leaderboard_replay",
                                map = rect.map,
                                replayEntry = rowRect.entry,
                            }
                        end
                        return { kind = "leaderboard_row_blocked" }
                    end
                end
                if pointInRect(x, y, rect) then
                    return { kind = "leaderboard_row_blocked" }
                end
            end
            if pointInRect(x, y, rect) then
                return { kind = "select_map", map = rect.map }
            end
        end
        return nil
    end

    local cardRects = buildLevelSelectCardRects(game)
    local filterRect = getLevelSelectFilterRect(game)
    local filterSegments = getLevelSelectFilterSegments()
    if pointInRect(x, y, filterRect) then
        for index, segment in ipairs(filterSegments) do
            if pointInRect(x, y, uiControls.segmentRect(filterRect, index, #filterSegments)) then
                return { kind = "set_filter", filter = segment.id }
            end
        end
    end

    local maps = getLevelSelectMaps(game)
    local selectedIndex = getSelectedMapIndex(game, maps)
    local selectedMap = selectedIndex and maps[selectedIndex] or nil
    for _, buttonRect in ipairs(getLevelSelectActionButtons(game)) do
        if buttonRect.id ~= "back" and pointInRect(x, y, buttonRect) then
            return {
                kind = buttonRect.id,
                map = selectedMap,
            }
        end
    end

    for _, rect in ipairs(cardRects) do
        if rect.selected and isLevelSelectLeaderboardCardFlipped(game, rect) and button == 1 then
            local _, _, _, _, rowRects = buildLevelSelectLeaderboardBackRows(game, rect)
            for _, rowRect in ipairs(rowRects) do
                if pointInRect(x, y, rowRect) then
                    if tostring(rowRect.entry and rowRect.entry.replayUuid or "") ~= "" then
                        return {
                            kind = "open_leaderboard_replay",
                            map = rect.map,
                            replayEntry = rowRect.entry,
                        }
                    end
                    return { kind = "leaderboard_row_blocked" }
                end
            end
            if pointInRect(x, y, rect) then
                return { kind = "leaderboard_row_blocked" }
            end
        end
        if pointInRect(x, y, rect) then
            if button == 2 and rect.selected then
                return { kind = "toggle_leaderboard_card", map = rect.map }
            end
            if rect.selected then
                return { kind = "open_map", map = rect.map }
            end
            return { kind = "select_map", map = rect.map }
        end
    end

    return nil
end

function ui.getLevelSelectHoverId(game, x, y)
    if game.levelSelectUploadDialog or game.levelSelectReplayOverlay or game.levelSelectIssue then
        return nil
    end

    if game.levelSelectMode == "marketplace" then
        local tabsRect = getMarketplaceTabsRect(game)
        if pointInRect(x, y, tabsRect) then
            local tabSegments = getMarketplaceTabSegments()
            for index, segment in ipairs(tabSegments) do
                if pointInRect(x, y, uiControls.segmentRect(tabsRect, index, #tabSegments)) then
                    return segment.id
                end
            end
        end
        local modeSelectorRect = getLevelSelectModeSelectorRect(game)
        if pointInRect(x, y, modeSelectorRect) then
            local modeSegments = getLevelSelectModeSegments()
            for index, segment in ipairs(modeSegments) do
                if pointInRect(x, y, uiControls.segmentRect(modeSelectorRect, index, #modeSegments)) then
                    if segment.id == "marketplace" and not game:isOnlineMode() then
                        return nil
                    end
                    return segment.id
                end
            end
        end
        for _, rect in ipairs(buildLevelSelectCardRects(game)) do
            if rect.favoriteButtonRect and pointInRect(x, y, rect.favoriteButtonRect) then
                return getMarketplaceFavoriteHoverId(rect.map)
            end
        end
        return nil
    end

    local filterRect = getLevelSelectFilterRect(game)
    if pointInRect(x, y, filterRect) then
        local filterSegments = getLevelSelectFilterSegments()
        for index, segment in ipairs(filterSegments) do
            if pointInRect(x, y, uiControls.segmentRect(filterRect, index, #filterSegments)) then
                return segment.id
            end
        end
    end

    local modeSelectorRect = getLevelSelectModeSelectorRect(game)
    if pointInRect(x, y, modeSelectorRect) then
        local modeSegments = getLevelSelectModeSegments()
        for index, segment in ipairs(modeSegments) do
            if pointInRect(x, y, uiControls.segmentRect(modeSelectorRect, index, #modeSegments)) then
                if segment.id == "marketplace" and not game:isOnlineMode() then
                    return nil
                end
                return segment.id
            end
        end
    end

    return nil
end

function ui.getLevelSelectHoverInfoAt(game, x, y)
    if game.levelSelectUploadDialog or game.levelSelectReplayOverlay or game.levelSelectIssue then
        return nil
    end

    return getLevelSelectBadgeHoverInfo(game, x, y)
end

end
