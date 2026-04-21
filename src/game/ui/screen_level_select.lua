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

function getMapKind(descriptor)
    -- Check if it's a downloaded/remote import first
    if descriptor.source == "user" and descriptor.isRemoteImport then
        return "downloaded"
    end
    if descriptor.mapKind then
        return descriptor.mapKind
    end
    if descriptor.source == "user" then
        return "user"
    end
    return "campaign"
end

function getMapKindLabel(descriptor)
    local kind = getMapKind(descriptor)
    if kind == "tutorial" then
        return "Guidebook"
    end
    if kind == "campaign" then
        return "Campaign"
    end
    if kind == "downloaded" then
        return "Downloaded"
    end
    return "User"
end

function getMapDisplayName(descriptor)
    return descriptor.displayName or descriptor.name or "Untitled Map"
end

function getLevelSelectFilterSegments()
    return {
        { id = "all", label = "All" },
        { id = "campaign", label = "Campaign" },
        { id = "tutorial", label = "Guidebook" },
        { id = "downloaded", label = "Downloaded" },
        { id = "user", label = "User" },
    }
end

function getLevelSelectMaps(game)
    if game.levelSelectMode == "marketplace" then
        local marketplaceEntries = buildMarketplaceDisplayEntries(game)
        local maps = {}
        for _, entry in ipairs(marketplaceEntries) do
            maps[#maps + 1] = entry.descriptor
        end
        return maps
    end

    local maps = {}
    local filterId = game.levelSelectFilter or "campaign"

    for _, mapKind in ipairs({ "campaign", "tutorial", "downloaded", "user" }) do
        if filterId == "all" or filterId == mapKind then
            for _, descriptor in ipairs(game.availableMaps or {}) do
                if getMapKind(descriptor) == mapKind then
                    maps[#maps + 1] = descriptor
                end
            end
        end
    end

    return maps
end

function getSelectedMapIndex(game, maps)
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

function getLevelSelectBottomBarRect(game)
    return {
        x = 2,
        y = LEVEL_SELECT.bottomBarY,
        w = game.viewport.w - 4,
        h = LEVEL_SELECT.bottomBarH,
    }
end

function getLevelSelectTitleBarRect(game)
    return {
        x = 118,
        y = LEVEL_SELECT.titleBarY,
        w = 1044,
        h = LEVEL_SELECT.titleBarH,
    }
end

function getLevelSelectModeSegments()
    return {
        { id = "library", label = "Local Maps" },
        { id = "marketplace", label = "Online Maps" },
    }
end

function getLevelSelectModeSelectorRect(game)
    local bottomBarRect = getLevelSelectBottomBarRect(game)
    return {
        x = math.floor(game.viewport.w * 0.5 - LEVEL_SELECT.filterW * 0.5 + 0.5),
        y = bottomBarRect.y - LEVEL_SELECT.bottomSelectorGap - LEVEL_SELECT.filterH,
        w = LEVEL_SELECT.filterW,
        h = LEVEL_SELECT.filterH,
    }
end

function getMarketplaceTabSegments()
    return {
        { id = "top", label = "Top Maps" },
        { id = "random", label = "Random" },
        { id = "search", label = "Search" },
    }
end

function getMarketplaceTabsRect(game)
    local filterRect = getLevelSelectFilterRect(game)
    return {
        x = filterRect.x,
        y = filterRect.y,
        w = filterRect.w,
        h = filterRect.h,
    }
end

function getMarketplaceSearchRect(game)
    local selectorRect = getLevelSelectFilterRect(game)
    return {
        x = math.floor(game.viewport.w * 0.5 - MARKETPLACE_LAYOUT.searchW * 0.5 + 0.5),
        y = selectorRect.y - LEVEL_SELECT.searchGap - MARKETPLACE_LAYOUT.searchH,
        w = MARKETPLACE_LAYOUT.searchW,
        h = MARKETPLACE_LAYOUT.searchH,
    }
end

function getMarketplaceHash(text)
    local hash = 0
    for index = 1, #text do
        hash = (hash * 33 + text:byte(index)) % 2147483647
    end
    return hash
end

function normalizeMarketplaceMapKind(category)
    local normalizedCategory = string.lower(trim(category or ""))
    if normalizedCategory == "tutorial" then
        return "tutorial"
    end
    if normalizedCategory == "campaign" then
        return "campaign"
    end
    if normalizedCategory == MARKETPLACE_REMOTE_CATEGORY_USERS then
        return "user"
    end

    return "user"
end

function buildMarketplaceDescriptor(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local remoteMap = type(entry.map) == "table" and entry.map or {}
    local mapUuid = tostring(entry.map_uuid or "")
    local internalIdentifier = tostring(entry.internal_identifier or "")
    if mapUuid ~= "" then
        remoteMap.id = remoteMap.id or mapUuid
        remoteMap.mapUuid = remoteMap.mapUuid or mapUuid
    end

    local displayName = tostring(entry.map_name or "Untitled Map")
    return {
        id = string.format(
            "%s:%s:%s:%s",
            MARKETPLACE_REMOTE_SOURCE,
            tostring(entry.creator_uuid or "unknown"),
            mapUuid ~= "" and mapUuid or "map",
            internalIdentifier ~= "" and internalIdentifier or "listing"
        ),
        mapUuid = mapUuid,
        source = MARKETPLACE_REMOTE_SOURCE,
        name = displayName,
        displayName = displayName,
        favoriteCount = tonumber(entry.favorite_count or 0) or 0,
        likedByPlayer = entry.liked_by_player == true,
        mapKind = normalizeMarketplaceMapKind(entry.map_category),
        mapHash = tostring(entry.map_hash or ""),
        savedAt = entry.updated_at,
        hasEditor = false,
        hasLevel = type(entry.map) == "table",
        hasErrors = false,
        isTemplate = false,
        previewLevel = remoteMap,
        previewDescription = remoteMap.previewDescription or remoteMap.description or nil,
        remoteSourceEntry = entry,
    }
end

function getMarketplaceControlsSummary(descriptor)
    local labels = {}
    for _, controlType in ipairs(getMapControlTypes(descriptor)) do
        labels[#labels + 1] = CONTROL_SHORT_LABELS[controlType] or controlType
    end
    if #labels == 0 then
        return "No control tags"
    end
    return table.concat(labels, ", ")
end

function buildMarketplaceEntries(game)
    local entries = {}
    for _, sourceEntry in ipairs(game:getMarketplaceEntries() or {}) do
        local descriptor = buildMarketplaceDescriptor(sourceEntry)
        if descriptor then
            local displayName = getMapDisplayName(descriptor)
            local kindLabel = getMapKindLabel(descriptor)
            local controlsSummary = getMarketplaceControlsSummary(descriptor)
            local favoriteAnimation = descriptor.mapUuid ~= "" and game:getMarketplaceFavoriteAnimation(descriptor.mapUuid) or nil
            entries[#entries + 1] = {
                descriptor = descriptor,
                title = displayName,
                subtitle = string.format("%s  |  %s", kindLabel, controlsSummary),
                creatorDisplayName = tostring(sourceEntry.creator_display_name or "Unknown"),
                creatorUuid = tostring(sourceEntry.creator_uuid or ""),
                favoriteCount = descriptor.favoriteCount or 0,
                favoriteAnimation = favoriteAnimation,
                internalIdentifier = tostring(sourceEntry.internal_identifier or ""),
                likedByPlayer = descriptor.likedByPlayer == true,
                featuredWeight = descriptor.favoriteCount or 0,
                randomWeight = getMarketplaceHash(table.concat({
                    tostring(sourceEntry.map_uuid or ""),
                    tostring(sourceEntry.internal_identifier or ""),
                    tostring(sourceEntry.creator_uuid or ""),
                }, ":")),
            }
        end
    end

    return entries
end

buildMarketplaceDisplayEntries = function(game)
    local entries = buildMarketplaceEntries(game)
    local tabId = game.levelSelectMarketplaceTab or "top"
    local searchQuery = string.lower((game.levelSelectMarketplaceSearchQuery or ""):gsub("^%s+", ""):gsub("%s+$", ""))

    if tabId == "top" then
        table.sort(entries, function(a, b)
            if a.featuredWeight ~= b.featuredWeight then
                return a.featuredWeight > b.featuredWeight
            end
            return a.title < b.title
        end)
    elseif tabId == "random" then
        table.sort(entries, function(a, b)
            if a.randomWeight ~= b.randomWeight then
                return a.randomWeight < b.randomWeight
            end
            return a.title < b.title
        end)
    end

    for index, entry in ipairs(entries) do
        entry.position = index
        if tabId == "top" then
            entry.positionLabel = string.format("#%d", index)
        elseif tabId == "random" then
            entry.positionLabel = string.format("Rnd %d", index)
        else
            entry.positionLabel = string.format("Hit %d", index)
        end
    end

    if tabId == "search" then
        local limitedEntries = {}
        for index, entry in ipairs(entries) do
            if index > MARKETPLACE_LAYOUT.searchResultLimit then
                break
            end
            limitedEntries[#limitedEntries + 1] = entry
        end
        return limitedEntries, #entries, searchQuery
    end

    local limitedEntries = {}
    for index, entry in ipairs(entries) do
        if index > MARKETPLACE_LAYOUT.browseResultLimit then
            break
        end
        limitedEntries[#limitedEntries + 1] = entry
    end

    return limitedEntries, #entries, searchQuery
end

function appendUniqueControl(controls, seen, controlType)
    if controlType and not seen[controlType] then
        seen[controlType] = true
        controls[#controls + 1] = controlType
    end
end

function mapHasLevelDeadline(descriptor)
    local level = descriptor and descriptor.previewLevel or nil
    return level and level.timeLimit ~= nil
end

function mapHasExpressTrain(descriptor)
    local level = descriptor and descriptor.previewLevel or nil
    for _, train in ipairs(level and level.trains or {}) do
        if train.deadline ~= nil then
            return true
        end
    end
    return false
end

function buildLevelSelectBadges(descriptor)
    local badges = {}

    for _, controlType in ipairs(getMapControlTypes(descriptor)) do
        local definition = LEVEL_SELECT_BADGE_DEFINITIONS[controlType] or {}
        badges[#badges + 1] = {
            key = controlType,
            controlType = controlType,
            label = definition.label or CONTROL_SHORT_LABELS[controlType] or controlType,
            tooltipTitle = definition.tooltipTitle or (definition.label or controlType),
            tooltipText = definition.tooltipText or string.format("This map contains %s.", definition.label or controlType),
            fillColor = definition.fillColor,
            lineColor = definition.lineColor,
            textColor = definition.textColor,
        }
    end

    if mapHasLevelDeadline(descriptor) then
        local definition = LEVEL_SELECT_BADGE_DEFINITIONS.deadline
        badges[#badges + 1] = {
            key = "deadline",
            label = definition.label,
            tooltipTitle = definition.tooltipTitle,
            tooltipText = definition.tooltipText,
            fillColor = definition.fillColor,
            lineColor = definition.lineColor,
            textColor = definition.textColor,
        }
    end

    if mapHasExpressTrain(descriptor) then
        local definition = LEVEL_SELECT_BADGE_DEFINITIONS.express
        badges[#badges + 1] = {
            key = "express",
            label = definition.label,
            tooltipTitle = definition.tooltipTitle,
            tooltipText = definition.tooltipText,
            fillColor = definition.fillColor,
            lineColor = definition.lineColor,
            textColor = definition.textColor,
        }
    end

    return badges
end

getMapControlTypes = function(descriptor)
    local controls = {}
    local seen = {}
    local level = descriptor.previewLevel

    for _, junction in ipairs(level and level.junctions or {}) do
        appendUniqueControl(controls, seen, junction.control and junction.control.type or "direct")
    end

    return controls
end

function getPreviewPoint(point, rect)
    local normalizedX = math.max(0, math.min(1, point.x or 0))
    local normalizedY = math.max(0, math.min(1, point.y or 0))
    return rect.x + normalizedX * rect.w, rect.y + normalizedY * rect.h
end

function buildPreviewTracks(level)
    local tracks = {}
    local junctions = {}

    if not level then
        return tracks, junctions
    end

    if level.edges and level.junctions then
        local edgeLookup = {}
        for _, edge in ipairs(level.edges or {}) do
            edgeLookup[edge.id] = edge
            tracks[#tracks + 1] = {
                points = edge.points or {},
                color = edge.color,
                muted = false,
            }
        end

        for _, junction in ipairs(level.junctions or {}) do
            local point = nil
            local inputEdge = edgeLookup[(junction.inputEdgeIds or {})[1]]
            local outputEdge = edgeLookup[(junction.outputEdgeIds or {})[1]]

            if inputEdge and #(inputEdge.points or {}) > 0 then
                point = inputEdge.points[#inputEdge.points]
            elseif outputEdge and #(outputEdge.points or {}) > 0 then
                point = outputEdge.points[1]
            end

            if point then
                junctions[#junctions + 1] = {
                    x = point.x,
                    y = point.y,
                    controlType = junction.control and junction.control.type or "direct",
                    outputCount = #(junction.outputEdgeIds or {}),
                }
            end
        end

        return tracks, junctions
    end

    for _, junction in ipairs(level.junctions or {}) do
        for _, input in ipairs(junction.inputs or {}) do
            tracks[#tracks + 1] = {
                points = input.inputPoints or {},
                color = input.color,
                muted = false,
            }
        end

        for _, output in ipairs(junction.outputs or {}) do
            tracks[#tracks + 1] = {
                points = output.outputPoints or {},
                color = output.color,
                muted = output.adoptInputColor == true,
            }
        end

        local point = nil
        if #(junction.inputs or {}) > 0 and #((junction.inputs or {})[1].inputPoints or {}) > 0 then
            local points = (junction.inputs or {})[1].inputPoints
            point = points[#points]
        elseif #(junction.outputs or {}) > 0 and #((junction.outputs or {})[1].outputPoints or {}) > 0 then
            point = ((junction.outputs or {})[1].outputPoints)[1]
        end

        if point then
            junctions[#junctions + 1] = {
                x = point.x,
                y = point.y,
                controlType = junction.control and junction.control.type or "direct",
                outputCount = #(junction.outputs or {}),
            }
        end
    end

    return tracks, junctions
end

function drawMapPreview(descriptor, rect)
    local graphics = love.graphics
    local tracks, junctions = buildPreviewTracks(descriptor.previewLevel)

    graphics.setColor(PREVIEW_COLORS.background[1], PREVIEW_COLORS.background[2], PREVIEW_COLORS.background[3], PREVIEW_COLORS.background[4])
    graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 16, 16)
    graphics.setColor(PREVIEW_COLORS.frame[1], PREVIEW_COLORS.frame[2], PREVIEW_COLORS.frame[3], PREVIEW_COLORS.frame[4])
    graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 16, 16)

    if #tracks == 0 then
        graphics.setColor(PREVIEW_COLORS.label[1], PREVIEW_COLORS.label[2], PREVIEW_COLORS.label[3], PREVIEW_COLORS.label[4])
        graphics.printf("No Preview", rect.x, rect.y + rect.h * 0.5 - 8, rect.w, "center")
        return
    end

    for _, track in ipairs(tracks) do
        local points = {}
        for _, point in ipairs(track.points or {}) do
            local x, y = getPreviewPoint(point, rect)
            points[#points + 1] = x
            points[#points + 1] = y
        end

        if #points >= 4 then
            graphics.setLineStyle("smooth")
            graphics.setLineJoin("bevel")
            graphics.setLineWidth(10)
            graphics.setColor(PREVIEW_COLORS.railBed[1], PREVIEW_COLORS.railBed[2], PREVIEW_COLORS.railBed[3], PREVIEW_COLORS.railBed[4])
            graphics.line(points)

            local color = track.color or PREVIEW_COLORS.mutedTrack
            local alpha = track.muted and 0.78 or 0.96
            graphics.setLineWidth(5)
            graphics.setColor(color[1], color[2], color[3], alpha)
            graphics.line(points)
        end
    end

    for _, junction in ipairs(junctions) do
        local x, y = getPreviewPoint(junction, rect)
        local color = PREVIEW_COLORS.control[junction.controlType] or PREVIEW_COLORS.control.direct

        graphics.setColor(0.04, 0.06, 0.08, 1)
        graphics.circle("fill", x, y, 10)
        graphics.setColor(color[1], color[2], color[3], color[4] or 1)
        graphics.circle("fill", x, y, 7)

        if junction.outputCount > 1 and junction.controlType ~= "relay" and junction.controlType ~= "crossbar" then
            graphics.setColor(0.99, 0.78, 0.32, 1)
            graphics.circle("line", x, y + 12, 5)
        end
    end
end

function buildCardBadges(game, descriptor, maxWidth)
    local font = game.fonts.small
    local badges = {}
    local totalWidth = 0
    local marketplaceEntry = getMarketplaceEntryForDescriptor(game, descriptor)

    local function appendBadge(badge)
        local nextWidth = totalWidth + badge.width
        if #badges > 0 then
            nextWidth = nextWidth + 6
        end
        if nextWidth > maxWidth then
            return false
        end
        badges[#badges + 1] = badge
        totalWidth = nextWidth
        return true
    end

    if game.levelSelectMode == "marketplace" and game.levelSelectMarketplaceTab == "top" and marketplaceEntry then
        local rankColors = getMarketplaceIndicatorColors(game, marketplaceEntry)
        appendBadge({
            label = marketplaceEntry.positionLabel or "#0",
            width = font:getWidth(marketplaceEntry.positionLabel or "#0") + 22,
            fillColor = rankColors.fill,
            lineColor = rankColors.line,
            textColor = rankColors.text,
        })
    end

    for _, badgeDefinition in ipairs(buildLevelSelectBadges(descriptor)) do
        local label = badgeDefinition.label
        local appended = appendBadge({
            key = badgeDefinition.key,
            controlType = badgeDefinition.controlType,
            label = label,
            width = font:getWidth(label) + 22,
            tooltipTitle = badgeDefinition.tooltipTitle,
            tooltipText = badgeDefinition.tooltipText,
            fillColor = badgeDefinition.fillColor,
            lineColor = badgeDefinition.lineColor,
            textColor = badgeDefinition.textColor,
        })
        if not appended then
            break
        end
    end

    return badges, totalWidth
end

function getLevelSelectBackRect(game)
    local bottomBarRect = getLevelSelectBottomBarRect(game)
    return {
        x = bottomBarRect.x + 24,
        y = bottomBarRect.y + math.floor((bottomBarRect.h - LEVEL_SELECT_ACTION_LAYOUT.buttonH) * 0.5 + 0.5),
        w = 120,
        h = LEVEL_SELECT_ACTION_LAYOUT.buttonH,
    }
end

function getSettledSelectedCardRect(game)
    local width = LEVEL_SELECT.cardBaseW
    local height = LEVEL_SELECT.cardBaseH
    return {
        x = math.floor(game.viewport.w * 0.5 - width * 0.5 + 0.5),
        y = math.floor(LEVEL_SELECT.carouselCenterY - height * 0.5 + 0.5),
        w = width,
        h = height,
    }
end

getLevelSelectFilterRect = function(game)
    local modeRect = getLevelSelectModeSelectorRect(game)

    return {
        x = math.floor(game.viewport.w * 0.5 - LEVEL_SELECT.filterW * 0.5 + 0.5),
        y = modeRect.y - LEVEL_SELECT.selectorGap - LEVEL_SELECT.filterH,
        w = LEVEL_SELECT.filterW,
        h = LEVEL_SELECT.filterH,
    }
end

getLevelSelectActionButtons = function(game)
    local bottomBarRect = getLevelSelectBottomBarRect(game)
    local maps = getLevelSelectMaps(game)
    local selectedIndex = getSelectedMapIndex(game, maps)
    local selectedMap = selectedIndex and maps[selectedIndex] or nil
    local buttonY = bottomBarRect.y + math.floor((bottomBarRect.h - LEVEL_SELECT_ACTION_LAYOUT.buttonH) * 0.5 + 0.5)
    local buttons = {}
    local sideInset = 24
    local primarySpec
    local rightButtonSpecs = {}

    buttons[#buttons + 1] = {
        id = "back",
        label = "Back",
        x = bottomBarRect.x + sideInset,
        y = buttonY,
        w = 120,
        h = LEVEL_SELECT_ACTION_LAYOUT.buttonH,
    }

    if game.levelSelectMode == "marketplace" then
        primarySpec = { id = "download_map", label = "Download", w = LEVEL_SELECT_ACTION_LAYOUT.downloadW }
        rightButtonSpecs = {
            { id = "refresh_marketplace", label = "Refresh", w = LEVEL_SELECT_ACTION_LAYOUT.refreshW },
        }
    else
        local editButtonId = "edit_map"
        local editButtonLabel = "Edit"
        if selectedMap and selectedMap.isRemoteImport then
            editButtonId = "clone_map"
            editButtonLabel = "Clone"
        end

        primarySpec = { id = "open_map", label = "Start", w = LEVEL_SELECT_ACTION_LAYOUT.startW }

        if selectedMap and game:isUploadSelectedMapAvailable(selectedMap) then
            rightButtonSpecs[#rightButtonSpecs + 1] = {
                id = "upload_map",
                label = "Upload",
                w = LEVEL_SELECT_ACTION_LAYOUT.uploadW,
            }
        end

        rightButtonSpecs[#rightButtonSpecs + 1] = {
            id = editButtonId,
            label = editButtonLabel,
            w = LEVEL_SELECT_ACTION_LAYOUT.editW,
        }
    end

    buttons[#buttons + 1] = {
        id = primarySpec.id,
        label = primarySpec.label,
        x = math.floor(game.viewport.w * 0.5 - primarySpec.w * 0.5 + 0.5),
        y = buttonY,
        w = primarySpec.w,
        h = LEVEL_SELECT_ACTION_LAYOUT.buttonH,
    }

    local totalRightWidth = 0
    for index, spec in ipairs(rightButtonSpecs) do
        totalRightWidth = totalRightWidth + spec.w
        if index > 1 then
            totalRightWidth = totalRightWidth + LEVEL_SELECT_ACTION_LAYOUT.buttonGap
        end
    end

    local currentX = bottomBarRect.x + bottomBarRect.w - sideInset - totalRightWidth
    for _, spec in ipairs(rightButtonSpecs) do
        buttons[#buttons + 1] = {
            id = spec.id,
            label = spec.label,
            x = currentX,
            y = buttonY,
            w = spec.w,
            h = LEVEL_SELECT_ACTION_LAYOUT.buttonH,
        }
        currentX = currentX + spec.w + LEVEL_SELECT_ACTION_LAYOUT.buttonGap
    end

    return buttons
end

function findLevelSelectActionButton(buttons, buttonId)
    for _, button in ipairs(buttons or {}) do
        if button.id == buttonId then
            return button
        end
    end

    return nil
end

function getLevelIssueOverlayRects(game)
    local panel = {
        x = game.viewport.w * 0.5 - 280,
        y = game.viewport.h * 0.5 - 170,
        w = 560,
        h = 340,
    }

    return {
        panel = panel,
        edit = {
            x = panel.x + 42,
            y = panel.y + panel.h - 68,
            w = 220,
            h = 40,
        },
        cancel = {
            x = panel.x + panel.w - 262,
            y = panel.y + panel.h - 68,
            w = 220,
            h = 40,
        },
    }
end

function ui.getLevelSelectUploadDialogRects(game)
    local panel = {
        x = math.floor(game.viewport.w * 0.5 - LEVEL_SELECT.uploadDialog.panelW * 0.5 + 0.5),
        y = math.floor(game.viewport.h * 0.5 - LEVEL_SELECT.uploadDialog.panelH * 0.5 + 0.5),
        w = LEVEL_SELECT.uploadDialog.panelW,
        h = LEVEL_SELECT.uploadDialog.panelH,
    }
    local buttonGroupWidth = (LEVEL_SELECT.uploadDialog.buttonW * 2) + LEVEL_SELECT.uploadDialog.buttonGap
    local buttonX = panel.x + math.floor((panel.w - buttonGroupWidth) * 0.5 + 0.5)

    return {
        panel = panel,
        value = {
            x = panel.x + 46,
            y = panel.y + 132,
            w = panel.w - 92,
            h = LEVEL_SELECT.uploadDialog.valueH,
        },
        copy = {
            x = buttonX,
            y = panel.y + panel.h - 66,
            w = LEVEL_SELECT.uploadDialog.buttonW,
            h = LEVEL_SELECT.uploadDialog.buttonH,
        },
        close = {
            x = buttonX + LEVEL_SELECT.uploadDialog.buttonW + LEVEL_SELECT.uploadDialog.buttonGap,
            y = panel.y + panel.h - 66,
            w = LEVEL_SELECT.uploadDialog.buttonW,
            h = LEVEL_SELECT.uploadDialog.buttonH,
        },
    }
end

function ui.getLevelSelectStatusCardLayout(game)
    local actionStatus = game and game.levelSelectActionState or nil
    if not actionStatus or not actionStatus.message then
        return nil
    end

    local title = safeUiText(
        actionStatus.title,
        actionStatus.status == "error" and "Problem"
            or (actionStatus.status == "success" and "Done" or "Working")
    )
    local message = safeUiText(actionStatus.message, "Status message unavailable.")
    local titleBarRect = getLevelSelectTitleBarRect(game)
    local maxPanelWidth = math.min(LEVEL_SELECT.statusCard.maxW, game.viewport.w - 80)
    local maxTextWidth = math.max(40, maxPanelWidth - (LEVEL_SELECT.statusCard.paddingX * 2))

    love.graphics.setFont(game.fonts.small)
    local titleWidth = game.fonts.small:getWidth(title)
    local messageWidth = game.fonts.small:getWidth(message)
    local contentWidth = math.max(titleWidth, math.min(messageWidth, maxTextWidth))
    local textWidth = math.max(
        40,
        math.min(
            maxTextWidth,
            math.max(maxTextWidth >= messageWidth and contentWidth or maxTextWidth, titleWidth)
        )
    )
    local panelWidth = math.max(
        LEVEL_SELECT.statusCard.minW,
        math.min(maxPanelWidth, textWidth + (LEVEL_SELECT.statusCard.paddingX * 2))
    )
    textWidth = panelWidth - (LEVEL_SELECT.statusCard.paddingX * 2)

    local titleHeight = game.fonts.small:getHeight()
    local messageLineCount = getWrappedLineCount(game.fonts.small, message, textWidth)
    local messageHeight = messageLineCount * game.fonts.small:getHeight()
    local panelHeight = (LEVEL_SELECT.statusCard.paddingY * 2)
        + titleHeight
        + LEVEL_SELECT.statusCard.titleGap
        + messageHeight

    return {
        title = title,
        message = message,
        panel = {
            x = math.floor((game.viewport.w - panelWidth) * 0.5 + 0.5),
            y = titleBarRect.y + titleBarRect.h + LEVEL_SELECT.statusCard.topGap,
            w = panelWidth,
            h = panelHeight,
        },
        textWidth = textWidth,
        titleHeight = titleHeight,
    }
end

function ui.drawLevelSelectStatusCard(game)
    local layout = ui.getLevelSelectStatusCardLayout(game)
    if not layout then
        return
    end

    local graphics = love.graphics
    local actionStatus = game.levelSelectActionState
    local panel = layout.panel
    local panelX = panel.x
    local panelY = panel.y
    local accentColor = actionStatus.status == "error"
            and { 0.99, 0.78, 0.32, 1 }
        or (actionStatus.status == "success"
            and { 0.48, 0.92, 0.62, 1 }
            or { 0.56, 0.72, 0.98, 1 })
    local textWidth = layout.textWidth
    local titleHeight = layout.titleHeight
    local panelWidth = panel.w
    local panelHeight = panel.h

    graphics.setColor(0.06, 0.08, 0.12, 0.95)
    graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, LEVEL_SELECT.statusCard.cornerRadius, LEVEL_SELECT.statusCard.cornerRadius)
    graphics.setColor(0.22, 0.28, 0.34, 0.98)
    graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, LEVEL_SELECT.statusCard.cornerRadius, LEVEL_SELECT.statusCard.cornerRadius)

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(accentColor[1], accentColor[2], accentColor[3], accentColor[4])
    graphics.printf(layout.title, panelX + LEVEL_SELECT.statusCard.paddingX, panelY + LEVEL_SELECT.statusCard.paddingY, textWidth, "center")
    graphics.setColor(PANEL_COLORS.bodyText[1], PANEL_COLORS.bodyText[2], PANEL_COLORS.bodyText[3], PANEL_COLORS.bodyText[4])
    graphics.printf(
        layout.message,
        panelX + LEVEL_SELECT.statusCard.paddingX,
        panelY + LEVEL_SELECT.statusCard.paddingY + titleHeight + LEVEL_SELECT.statusCard.titleGap,
        textWidth,
        "center"
    )
end

function ui.drawLevelSelectUploadDialog(game)
    local dialog = game.levelSelectUploadDialog
    if not dialog then
        return
    end

    local graphics = love.graphics
    local rects = ui.getLevelSelectUploadDialogRects(game)
    local panel = rects.panel
    local mapId = safeUiText(dialog.mapId, "Unavailable")
    local mapName = safeUiText(dialog.mapName, "Uploaded map")
    local copyStatus = dialog.copyStatus or {}
    local copyStatusColor = copyStatus.status == "error"
            and { 0.99, 0.78, 0.32, 1 }
        or { 0.48, 0.92, 0.62, 1 }

    graphics.setColor(0, 0, 0, 0.68)
    graphics.rectangle("fill", 0, 0, game.viewport.w, game.viewport.h)

    graphics.setColor(0.09, 0.11, 0.15, 0.98)
    graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 18, 18)
    graphics.setColor(0.3, 0.42, 0.56, 1)
    graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h, 18, 18)

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf("Map uploaded", panel.x + 28, panel.y + 22, panel.w - 56, "center")

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.56, 0.72, 0.98, 1)
    graphics.printf(mapName, panel.x + 36, panel.y + 72, panel.w - 72, "center")

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(PANEL_COLORS.bodyText[1], PANEL_COLORS.bodyText[2], PANEL_COLORS.bodyText[3], PANEL_COLORS.bodyText[4])
    graphics.printf(
        "Copy this map ID if you want to share the upload or find it again later.",
        panel.x + 40,
        panel.y + 102,
        panel.w - 80,
        "center"
    )

    graphics.setColor(0.06, 0.08, 0.12, 1)
    graphics.rectangle("fill", rects.value.x, rects.value.y, rects.value.w, rects.value.h, 14, 14)
    graphics.setColor(0.44, 0.62, 0.78, 1)
    graphics.rectangle("line", rects.value.x, rects.value.y, rects.value.w, rects.value.h, 14, 14)

    graphics.setColor(PANEL_COLORS.mutedText[1], PANEL_COLORS.mutedText[2], PANEL_COLORS.mutedText[3], PANEL_COLORS.mutedText[4])
    graphics.print("Map ID", rects.value.x + 16, rects.value.y + 8)
    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf(mapId, rects.value.x + 16, rects.value.y + 26, rects.value.w - 32, "center")

    love.graphics.setFont(game.fonts.small)
    if copyStatus.message and copyStatus.message ~= "" then
        graphics.setColor(copyStatusColor[1], copyStatusColor[2], copyStatusColor[3], copyStatusColor[4])
        graphics.printf(copyStatus.message, panel.x + 38, panel.y + 214, panel.w - 76, "center")
    end

    if dialog.internalIdentifier and dialog.internalIdentifier ~= "" and dialog.mapUuid and dialog.mapUuid ~= "" then
        graphics.setColor(PANEL_COLORS.mutedText[1], PANEL_COLORS.mutedText[2], PANEL_COLORS.mutedText[3], PANEL_COLORS.mutedText[4])
        graphics.printf(
            string.format("Map UUID: %s", safeUiText(dialog.mapUuid, "n/a")),
            panel.x + 38,
            panel.y + 240,
            panel.w - 76,
            "center"
        )
    end

    graphics.setColor(PANEL_COLORS.mutedText[1], PANEL_COLORS.mutedText[2], PANEL_COLORS.mutedText[3], PANEL_COLORS.mutedText[4])
    graphics.printf("Press Enter/C to copy. Press Esc to close.", panel.x + 38, panel.y + 262, panel.w - 76, "center")

    drawButton(rects.copy, "Copy ID", { 0.1, 0.14, 0.18, 0.98 }, { 0.56, 0.72, 0.98, 1 }, game.fonts.small)
    drawButton(rects.close, "Close", { 0.1, 0.14, 0.18, 0.98 }, { 0.3, 0.36, 0.42, 1 }, game.fonts.small)
end

end
