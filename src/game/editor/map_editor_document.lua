return function(mapEditor, shared)
    local moduleEnvironment = setmetatable({ mapEditor = mapEditor }, {
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

function mapEditor:synthesizeTrainsFromLevel(levelData)
    local trains = {}
    local sourceTrains = levelData and levelData.trains or {}

    for _, trainDefinition in ipairs(sourceTrains) do
        local lineColor = trainDefinition.lineColor
        if not lineColor and trainDefinition.edgeId and levelData and levelData.edges then
            for _, edgeDefinition in ipairs(levelData.edges or {}) do
                if edgeDefinition.id == trainDefinition.edgeId then
                    lineColor = (edgeDefinition.colors or {})[1] or nearestColorId(edgeDefinition.color)
                    break
                end
            end
        end

        if not lineColor and trainDefinition.junctionId and levelData then
            for _, junctionDefinition in ipairs(levelData.junctions or {}) do
                if junctionDefinition.id == trainDefinition.junctionId then
                    local inputDefinition = (junctionDefinition.inputs or {})[trainDefinition.inputIndex or trainDefinition.branchIndex or 1]
                    if inputDefinition then
                        lineColor = (inputDefinition.colors or {})[1] or nearestColorId(inputDefinition.color)
                    end
                    break
                end
            end
        end

        local trainColor = trainDefinition.goalColor
            or trainDefinition.trainColor
            or nearestColorId(trainDefinition.color)
            or lineColor
            or COLOR_OPTIONS[1].id

        local spawnTime = trainDefinition.spawnTime
        if spawnTime == nil then
            local speedScale = trainDefinition.speedScale or 1
            local speed = LEGACY_TRAIN_SPEED * speedScale
            spawnTime = trainDefinition.progress and trainDefinition.progress < 0
                and math.abs(trainDefinition.progress) / math.max(1, speed)
                or 0
        end

        trains[#trains + 1] = self:createTrainDefinition({
            id = trainDefinition.id,
            lineColor = lineColor or trainColor,
            trainColor = trainColor,
            spawnTime = spawnTime,
            wagonCount = trainDefinition.wagonCount or DEFAULT_TRAIN_WAGONS,
            deadline = trainDefinition.deadline,
        })
    end

    return trains
end

function mapEditor:getExportData()
    local export = {
        mapSize = {
            w = self.mapSize.w,
            h = self.mapSize.h,
        },
        timeLimit = self.timeLimit,
        endpoints = {},
        routes = {},
        junctions = {},
        trains = {},
    }

    for _, endpoint in ipairs(self.endpoints) do
        export.endpoints[#export.endpoints + 1] = {
            id = endpoint.id,
            kind = endpoint.kind,
            x = endpoint.x / self.mapSize.w,
            y = endpoint.y / self.mapSize.h,
            colors = getEndpointColorIds(endpoint),
        }
    end

    for _, route in ipairs(self.routes) do
        self:ensureRouteSegmentRoadTypes(route)
        local exportRoute = {
            id = route.id,
            label = route.label or route.id,
            color = route.colorId,
            startEndpointId = route.startEndpointId,
            endEndpointId = route.endEndpointId,
            points = {},
            segmentRoadTypes = {},
        }

        for _, point in ipairs(route.points) do
            exportRoute.points[#exportRoute.points + 1] = {
                x = point.x / self.mapSize.w,
                y = point.y / self.mapSize.h,
                sharedPointId = point.sharedPointId,
                authored = point.authored ~= false,
            }
        end

        for _, roadTypeId in ipairs(route.segmentRoadTypes) do
            exportRoute.segmentRoadTypes[#exportRoute.segmentRoadTypes + 1] = roadTypeId
        end

        export.routes[#export.routes + 1] = exportRoute
    end

    for _, intersection in ipairs(self.intersections) do
        local exportJunction = {
            id = intersection.id,
            x = intersection.x / self.mapSize.w,
            y = intersection.y / self.mapSize.h,
            control = intersection.controlType,
            passCount = intersection.passCount or DEFAULT_CONTROL_CONFIGS.trip.passCount,
            routes = {},
            inputEndpointIds = {},
            outputEndpointIds = {},
            activeInputIndex = intersection.activeInputIndex or 1,
            activeOutputIndex = intersection.activeOutputIndex or 1,
        }
        for _, routeId in ipairs(intersection.routeIds) do
            exportJunction.routes[#exportJunction.routes + 1] = routeId
        end
        for _, endpointId in ipairs(intersection.inputEndpointIds or {}) do
            exportJunction.inputEndpointIds[#exportJunction.inputEndpointIds + 1] = endpointId
        end
        for _, endpointId in ipairs(intersection.outputEndpointIds or {}) do
            exportJunction.outputEndpointIds[#exportJunction.outputEndpointIds + 1] = endpointId
        end
        export.junctions[#export.junctions + 1] = exportJunction
    end

    for _, train in ipairs(self.trains) do
        export.trains[#export.trains + 1] = {
            id = train.id,
            lineColor = train.lineColor,
            trainColor = train.trainColor,
            spawnTime = train.spawnTime,
            wagonCount = train.wagonCount,
            deadline = train.deadline,
        }
    end

    return export
end

function mapEditor:loadEditorData(editorData, mapName, sourceInfo, levelData)
    self.level = levelData
    self.mapSize = sanitizeMapSize(editorData and editorData.mapSize)
    self.endpoints = {}
    self.routes = {}
    self.nextEndpointId = 1
    self.nextRouteId = 1
    self.nextSharedPointId = 1
    self.nextTrainId = 1
    self.importedJunctionState = {}
    self.drag = nil
    self.currentMapName = mapName
    self.sourceInfo = sourceInfo
    self.timeLimit = (editorData and editorData.timeLimit) or (levelData and levelData.timeLimit) or nil
    self.sidePanelMode = "default"
    self.sequencerScroll = 0
    self.activeTextField = nil
    self.sequencerScrollDrag = nil
    self.validationScroll = 0
    self.validationScrollDrag = nil
    self.validationEntries = {}
    self.hoveredValidationIndex = nil
    self:closeDialog()
    self:closeColorPicker()
    self:closeRouteTypePicker()
    self:clearSelection()
    self:updateLayout()
    self:resetCameraToFit()

    for _, endpointData in ipairs((editorData or {}).endpoints or {}) do
        self:createEndpoint(
            endpointData.kind or "output",
            endpointData.x * self.mapSize.w,
            endpointData.y * self.mapSize.h,
            endpointData.colors,
            endpointData.id
        )
    end

    for _, routeData in ipairs((editorData or {}).routes or {}) do
        local points = {}
        for _, point in ipairs(routeData.points or {}) do
            points[#points + 1] = {
                x = point.x * self.mapSize.w,
                y = point.y * self.mapSize.h,
                sharedPointId = point.sharedPointId,
                authored = point.authored ~= false,
            }
            if point.sharedPointId and point.sharedPointId >= self.nextSharedPointId then
                self.nextSharedPointId = point.sharedPointId + 1
            end
        end

        self:createRoute(
            points,
            getColorById(routeData.color),
            routeData.id,
            routeData.label,
            routeData.color,
            nil,
            nil,
            routeData.startEndpointId,
            routeData.endEndpointId,
            routeData.segmentRoadTypes or buildDefaultSegmentRoadTypes(#points, routeData.roadType)
        )
    end

    for _, junctionData in ipairs((editorData or {}).junctions or {}) do
        local sortedRouteIds = {}
        for _, routeId in ipairs(junctionData.routes or {}) do
            sortedRouteIds[#sortedRouteIds + 1] = routeId
        end
        table.sort(sortedRouteIds)
        self:restoreSharedPointsForRoutes(sortedRouteIds)
        local routeKey = table.concat(sortedRouteIds, "|")
        self.importedJunctionState[routeKey] = self.importedJunctionState[routeKey] or {}
        self.importedJunctionState[routeKey][#self.importedJunctionState[routeKey] + 1] = {
            id = junctionData.id,
            x = junctionData.x * self.mapSize.w,
            y = junctionData.y * self.mapSize.h,
            controlType = junctionData.control or DEFAULT_CONTROL,
            passCount = junctionData.passCount or DEFAULT_CONTROL_CONFIGS.trip.passCount,
            activeInputIndex = junctionData.activeInputIndex or 1,
            activeOutputIndex = junctionData.activeOutputIndex or 1,
            inputEndpointIds = junctionData.inputEndpointIds,
            outputEndpointIds = junctionData.outputEndpointIds,
        }
    end

    self.trains = {}
    local trainSource = (editorData or {}).trains
    if trainSource and #trainSource > 0 then
        for _, trainDefinition in ipairs(trainSource) do
            self.trains[#self.trains + 1] = self:createTrainDefinition(trainDefinition)
        end
    else
        self.trains = self:synthesizeTrainsFromLevel(levelData)
    end

    for _, train in ipairs(self.trains) do
        local numericId = tonumber((train.id or ""):match("train_(%d+)$"))
        if numericId and numericId >= self.nextTrainId then
            self.nextTrainId = numericId + 1
        end
    end

    self:rebuildIntersections()
    self:updateSavedStateSnapshot()
    self:showStatus("Map loaded into the editor.")
end

function mapEditor:serialize()
    local lines = {
        "return {",
        string.format("    mapSize = { w = %d, h = %d },", self.mapSize.w, self.mapSize.h),
        string.format("    timeLimit = %s,", self.timeLimit and formatNumber(self.timeLimit) or "nil"),
        "    endpoints = {",
    }

    for _, endpoint in ipairs(self.endpoints) do
        lines[#lines + 1] = "        {"
        lines[#lines + 1] = string.format("            id = %q,", endpoint.id)
        lines[#lines + 1] = string.format("            kind = %q,", endpoint.kind)
        lines[#lines + 1] = string.format("            x = %s,", formatNumber(endpoint.x / self.mapSize.w))
        lines[#lines + 1] = string.format("            y = %s,", formatNumber(endpoint.y / self.mapSize.h))
        lines[#lines + 1] = "            colors = {"
        for _, colorId in ipairs(getEndpointColorIds(endpoint)) do
            lines[#lines + 1] = string.format("                %q,", colorId)
        end
        lines[#lines + 1] = "            },"
        lines[#lines + 1] = "        },"
    end

    lines[#lines + 1] = "    },"
    lines[#lines + 1] = "    routes = {"

    for _, route in ipairs(self.routes) do
        self:ensureRouteSegmentRoadTypes(route)
        lines[#lines + 1] = "        {"
        lines[#lines + 1] = string.format("            id = %q,", route.id)
        lines[#lines + 1] = string.format("            label = %q,", route.label or route.id)
        lines[#lines + 1] = string.format("            color = %q,", route.colorId)
        lines[#lines + 1] = string.format("            startEndpointId = %q,", route.startEndpointId)
        lines[#lines + 1] = string.format("            endEndpointId = %q,", route.endEndpointId)
        lines[#lines + 1] = "            segmentRoadTypes = {"
        for _, roadTypeId in ipairs(route.segmentRoadTypes) do
            lines[#lines + 1] = string.format("                %q,", roadTypeId)
        end
        lines[#lines + 1] = "            },"
        lines[#lines + 1] = "            points = {"
        for _, point in ipairs(route.points) do
            local pointSuffixParts = {}
            if point.sharedPointId then
                pointSuffixParts[#pointSuffixParts + 1] = string.format("sharedPointId = %d", point.sharedPointId)
            end
            if point.authored == false then
                pointSuffixParts[#pointSuffixParts + 1] = "authored = false"
            end
            local pointSuffix = #pointSuffixParts > 0 and (", " .. table.concat(pointSuffixParts, ", ")) or ""
            lines[#lines + 1] = string.format(
                "                { x = %s, y = %s%s },",
                formatNumber(point.x / self.mapSize.w),
                formatNumber(point.y / self.mapSize.h),
                pointSuffix
            )
        end
        lines[#lines + 1] = "            },"
        lines[#lines + 1] = "        },"
    end

    lines[#lines + 1] = "    },"
    lines[#lines + 1] = "    trains = {"

    for _, train in ipairs(self.trains) do
        lines[#lines + 1] = "        {"
        lines[#lines + 1] = string.format("            id = %q,", train.id)
        lines[#lines + 1] = string.format("            lineColor = %q,", train.lineColor)
        lines[#lines + 1] = string.format("            trainColor = %q,", train.trainColor)
        lines[#lines + 1] = string.format("            spawnTime = %s,", formatNumber(train.spawnTime))
        lines[#lines + 1] = string.format("            wagonCount = %d,", train.wagonCount)
        lines[#lines + 1] = string.format("            deadline = %s,", train.deadline and formatNumber(train.deadline) or "nil")
        lines[#lines + 1] = "        },"
    end

    lines[#lines + 1] = "    },"
    lines[#lines + 1] = "    junctions = {"

    for _, intersection in ipairs(self.intersections) do
        lines[#lines + 1] = "        {"
        lines[#lines + 1] = string.format("            id = %q,", intersection.id)
        lines[#lines + 1] = string.format("            x = %s,", formatNumber(intersection.x / self.mapSize.w))
        lines[#lines + 1] = string.format("            y = %s,", formatNumber(intersection.y / self.mapSize.h))
        lines[#lines + 1] = string.format("            control = %q,", intersection.controlType)
        lines[#lines + 1] = string.format("            passCount = %d,", intersection.passCount or DEFAULT_CONTROL_CONFIGS.trip.passCount)
        lines[#lines + 1] = string.format("            activeInputIndex = %d,", intersection.activeInputIndex or 1)
        lines[#lines + 1] = string.format("            activeOutputIndex = %d,", intersection.activeOutputIndex or 1)
        lines[#lines + 1] = "            routes = {"
        for _, routeId in ipairs(intersection.routeIds) do
            lines[#lines + 1] = string.format("                %q,", routeId)
        end
        lines[#lines + 1] = "            },"
        lines[#lines + 1] = "            inputEndpointIds = {"
        for _, endpointId in ipairs(intersection.inputEndpointIds or {}) do
            lines[#lines + 1] = string.format("                %q,", endpointId)
        end
        lines[#lines + 1] = "            },"
        lines[#lines + 1] = "            outputEndpointIds = {"
        for _, endpointId in ipairs(intersection.outputEndpointIds or {}) do
            lines[#lines + 1] = string.format("                %q,", endpointId)
        end
        lines[#lines + 1] = "            },"
        lines[#lines + 1] = "        },"
    end

    lines[#lines + 1] = "    },"
    lines[#lines + 1] = "}"

    return table.concat(lines, "\n")
end

end
