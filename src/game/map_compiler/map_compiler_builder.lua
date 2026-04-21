return function(mapCompiler, shared)
    local moduleEnvironment = setmetatable({ mapCompiler = mapCompiler }, {
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

function buildCompiledLevel(mapName, editorData)
    local errors = {}
    local diagnostics = {}

    local function addError(message, diagnostic)
        errors[#errors + 1] = message
        diagnostics[#diagnostics + 1] = diagnostic or { message = message }
        diagnostics[#diagnostics].message = message
        return #diagnostics
    end

    local baseLevel = {
        title = mapName,
        description = "Custom map loaded from the editor.",
        hint = "Shared endpoints are not junctions. Only one train can safely occupy a line end at a time.",
        footer = "Shared line ends stay contested even without a junction, so spacing still matters.",
        timeLimit = editorData and editorData.timeLimit or nil,
        junctions = {},
        edges = {},
        trains = {},
    }

    if not editorData or #(editorData.routes or {}) == 0 then
        addError("Draw at least one route before starting this map.")
        return baseLevel, errors, errors[1], diagnostics
    end

    local junctionLookup = {}
    local orderedJunctions = {}
    local routeJunctions = {}

    for junctionIndex, junctionData in ipairs(editorData.junctions or {}) do
        local junctionId = junctionData.id or ("saved_junction_" .. junctionIndex)
        local junction = {
            id = junctionId,
            x = junctionData.x,
            y = junctionData.y,
            activeInputIndex = junctionData.activeInputIndex or 1,
            activeOutputIndex = junctionData.activeOutputIndex or 1,
            control = copyControlConfig(junctionData.control or "direct"),
            inputEdgeIds = {},
            outputEdgeIds = {},
        }

        if junctionData.passCount then
            junction.control.passCount = junctionData.passCount
        end

        junctionLookup[junctionId] = junction
        orderedJunctions[#orderedJunctions + 1] = junction

        for _, routeId in ipairs(junctionData.routes or {}) do
            routeJunctions[routeId] = routeJunctions[routeId] or {}
            routeJunctions[routeId][#routeJunctions[routeId] + 1] = {
                junctionId = junctionId,
                point = { x = junctionData.x, y = junctionData.y },
            }
        end
    end

    local edgeLookup = {}
    local startEdgeRecords = {}
    local lineColorToEdgeId = {}
    local outputColorLookup = {}
    local duplicateInputColorErrors = {}
    local routeBlockingDiagnosticIndexByColor = {}

    for _, route in ipairs(editorData.routes or {}) do
        local routeHits = routeJunctions[route.id] or {}
        local validRouteHits = {}
        local routeTotalLength = 0
        local skipRoute = false

        for pointIndex = 1, #(route.points or {}) - 1 do
            routeTotalLength = routeTotalLength + segmentLength(route.points[pointIndex], route.points[pointIndex + 1])
        end

        for _, hit in ipairs(routeHits) do
            local distanceAlongRoute, snappedPoint = findDistanceAlongRoute(route.points or {}, hit.point)
            if not distanceAlongRoute then
                local diagnosticIndex = addError(
                    string.format(
                        "%s is marked as connecting to a junction, but the route line no longer reaches that junction point. Move the junction onto the route or redraw the route through it.",
                        getRouteDisplayName(route)
                    ),
                    {
                        kind = "route_junction_miss",
                        routeId = route.id,
                        routeColor = route.color,
                        x = hit.point and hit.point.x or nil,
                        y = hit.point and hit.point.y or nil,
                    }
                )
                routeBlockingDiagnosticIndexByColor[route.color] = diagnosticIndex
                skipRoute = true
                break
            end

            if distanceAlongRoute > 0.0001 and distanceAlongRoute < routeTotalLength - 0.0001 then
                hit.distance = distanceAlongRoute
                hit.point = snappedPoint
                validRouteHits[#validRouteHits + 1] = hit
            end
        end

        if not skipRoute then
            table.sort(validRouteHits, function(first, second)
                return first.distance < second.distance
            end)

            local nodes = {
                {
                    kind = "start",
                    id = route.startEndpointId,
                    point = copyPoint((route.points or {})[1]),
                    distance = 0,
                },
            }

            for _, hit in ipairs(validRouteHits) do
                nodes[#nodes + 1] = {
                    kind = "junction",
                    id = hit.junctionId,
                    point = copyPoint(hit.point),
                    distance = hit.distance,
                }
            end

            nodes[#nodes + 1] = {
                kind = "exit",
                id = route.endEndpointId,
                point = copyPoint((route.points or {})[#(route.points or {})]),
                distance = routeTotalLength,
            }

            for nodeIndex = 1, #nodes - 1 do
                local sourceNode = nodes[nodeIndex]
                local targetNode = nodes[nodeIndex + 1]
                local points = extractRouteSegment(route.points or {}, sourceNode.distance, targetNode.distance)

                if #points < 2 then
                    local diagnosticIndex = addError(
                        string.format(
                            "%s has two junctions so close together that no track remains between them. Move one junction farther away so a track segment can fit between the junctions.",
                            getRouteDisplayName(route)
                        ),
                        {
                            kind = "route_zero_length_segment",
                            routeId = route.id,
                            routeColor = route.color,
                            x = (sourceNode.point.x + targetNode.point.x) * 0.5,
                            y = (sourceNode.point.y + targetNode.point.y) * 0.5,
                            sourceNodeId = sourceNode.id,
                            targetNodeId = targetNode.id,
                        }
                    )
                    routeBlockingDiagnosticIndexByColor[route.color] = diagnosticIndex
                    skipRoute = true
                    break
                end

                local targetEndpoint = targetNode.kind == "exit" and getEndpointById(editorData, targetNode.id) or nil
                local sourceEndpoint = sourceNode.kind == "start" and getEndpointById(editorData, sourceNode.id) or nil
                local styleSections = buildRouteStyleSections(route, sourceNode.distance, targetNode.distance)
                local primaryRoadType = styleSections[1] and styleSections[1].roadType or roadTypes.DEFAULT_ID
                local edge = {
                    id = string.format("%s_segment_%d", route.id, nodeIndex),
                    label = string.format("%s Segment %d", getRouteDisplayName(route), nodeIndex),
                    routeId = route.id,
                    roadType = primaryRoadType,
                    speedScale = roadTypes.getConfig(primaryRoadType).speedScale,
                    styleSections = styleSections,
                    points = points,
                    color = getColor(route.color),
                    darkColor = darkerColor(getColor(route.color)),
                    colors = targetEndpoint and (targetEndpoint.colors or {}) or sourceEndpoint and (sourceEndpoint.colors or {}) or {},
                    inputColors = sourceEndpoint and (sourceEndpoint.colors or {}) or {},
                    -- Merged endpoints may accept multiple colors, but authored route visuals
                    -- should stay tied to the route's defined map color.
                    adoptInputColor = false,
                    sourceType = sourceNode.kind,
                    sourceId = sourceNode.id,
                    targetType = targetNode.kind,
                    targetId = targetNode.id,
                }

                -- Keep authored route segments distinct even when they overlap exactly,
                -- so each lane can preserve its own style and speed profile.
                edgeLookup[edge.id] = edge

                if sourceNode.kind == "junction" then
                    local sourceJunction = junctionLookup[sourceNode.id]
                    sourceJunction.outputEdgeIds[#sourceJunction.outputEdgeIds + 1] = edge.id
                end
                if targetNode.kind == "junction" then
                    local targetJunction = junctionLookup[targetNode.id]
                    targetJunction.inputEdgeIds[#targetJunction.inputEdgeIds + 1] = edge.id
                end
                if sourceNode.kind == "start" then
                    startEdgeRecords[edge.id] = startEdgeRecords[edge.id] or {
                        edgeId = edge.id,
                        colors = {},
                    }
                    for _, colorId in ipairs(sourceEndpoint and (sourceEndpoint.colors or {}) or {}) do
                        startEdgeRecords[edge.id].colors[colorId] = true
                        if lineColorToEdgeId[colorId] and lineColorToEdgeId[colorId] ~= edge.id then
                            if not duplicateInputColorErrors[colorId] then
                                duplicateInputColorErrors[colorId] = true
                                addError(string.format("Input color '%s' is used on more than one source line.", colorId))
                            end
                        else
                            lineColorToEdgeId[colorId] = edge.id
                        end
                    end
                end

                if targetNode.kind == "exit" then
                    addOutputColors(outputColorLookup, edge, sourceEndpoint, targetEndpoint)
                end
            end
        end
    end

    local edges = {}
    for _, edge in pairs(edgeLookup) do
        edges[#edges + 1] = edge
    end
    table.sort(edges, function(a, b)
        return a.id < b.id
    end)

    local edgeById = {}
    for _, edge in ipairs(edges) do
        edgeById[edge.id] = edge
    end

    local playableJunctions = {}
    for _, junction in ipairs(orderedJunctions) do
        local inputEdges = {}
        local outputEdges = {}
        local uniqueInputLookup = {}
        local uniqueOutputLookup = {}

        for _, edgeId in ipairs(junction.inputEdgeIds) do
            if not uniqueInputLookup[edgeId] then
                uniqueInputLookup[edgeId] = true
                inputEdges[#inputEdges + 1] = edgeById[edgeId]
            end
        end
        for _, edgeId in ipairs(junction.outputEdgeIds) do
            if not uniqueOutputLookup[edgeId] then
                uniqueOutputLookup[edgeId] = true
                outputEdges[#outputEdges + 1] = edgeById[edgeId]
            end
        end

        sortEdgesByStart(inputEdges)
        sortEdgesByEnd(outputEdges)

        if #inputEdges > 0 or #outputEdges > 0 then
            if #inputEdges == 0 or #outputEdges == 0 then
                addError(
                    "A playable junction needs at least one input and one output.",
                    {
                        kind = "junction_missing_edges",
                        x = junction.x,
                        y = junction.y,
                        junctionId = junction.id,
                    }
                )
            end

            junction.inputEdgeIds = {}
            junction.outputEdgeIds = {}
            for _, edge in ipairs(inputEdges) do
                junction.inputEdgeIds[#junction.inputEdgeIds + 1] = edge.id
            end
            for _, edge in ipairs(outputEdges) do
                junction.outputEdgeIds[#junction.outputEdgeIds + 1] = edge.id
            end
            junction.activeInputIndex = math.min(junction.activeInputIndex, math.max(1, #junction.inputEdgeIds))
            junction.activeOutputIndex = math.min(junction.activeOutputIndex, math.max(1, #junction.outputEdgeIds))
            playableJunctions[#playableJunctions + 1] = junction
        end
    end

    local authoredTrains = editorData.trains
    if not authoredTrains or #authoredTrains == 0 then
        authoredTrains = buildLegacyAuthoredTrains(startEdgeRecords)
    end

    local trains = {}
    local timeLimit = editorData.timeLimit
    for trainIndex, trainData in ipairs(authoredTrains or {}) do
        local trainId = trainData.id or string.format("train_%d", trainIndex)
        local lineColor = trainData.lineColor
        local trainColor = trainData.trainColor
        local spawnTime = tonumber(trainData.spawnTime or 0) or 0
        local wagonCount = math.floor(tonumber(trainData.wagonCount or DEFAULT_WAGON_COUNT) or DEFAULT_WAGON_COUNT)
        local deadline = trainData.deadline ~= nil and (tonumber(trainData.deadline) or 0) or nil

        if spawnTime < 0 then
            addError(string.format("Train %d has a negative spawn time.", trainIndex), {
                kind = "train_negative_spawn",
                trainId = trainId,
                trainIndex = trainIndex,
                lineColor = lineColor,
                trainColor = trainColor,
            })
        end
        if wagonCount < 1 then
            addError(string.format("Train %d needs at least one wagon.", trainIndex), {
                kind = "train_invalid_wagons",
                trainId = trainId,
                trainIndex = trainIndex,
                lineColor = lineColor,
                trainColor = trainColor,
            })
        end
        if deadline ~= nil and deadline < spawnTime then
            addError(string.format("Train %d has a deadline earlier than its spawn time.", trainIndex), {
                kind = "train_deadline_before_spawn",
                trainId = trainId,
                trainIndex = trainIndex,
                lineColor = lineColor,
                trainColor = trainColor,
            })
        end
        if timeLimit ~= nil and deadline ~= nil and deadline > timeLimit then
            addError(string.format("Train %d has a deadline after the map deadline.", trainIndex), {
                kind = "train_deadline_after_map",
                trainId = trainId,
                trainIndex = trainIndex,
                lineColor = lineColor,
                trainColor = trainColor,
            })
        end
        if not lineColorToEdgeId[lineColor] then
            addError(string.format("Train %d uses source color '%s', but no matching input line exists.", trainIndex, tostring(lineColor)), {
                kind = "train_missing_input",
                trainId = trainId,
                trainIndex = trainIndex,
                lineColor = lineColor,
                trainColor = trainColor,
            })
        end
        if not outputColorLookup[trainColor] then
            local hasOutputEndpoint, outputEndpoint = endpointHasColor(editorData, "output", trainColor)
            local outputMessage
            local parentDiagnosticIndex = hasOutputEndpoint and routeBlockingDiagnosticIndexByColor[trainColor] or nil
            if hasOutputEndpoint then
                if parentDiagnosticIndex then
                    outputMessage = string.format(
                        "Train %d cannot currently finish on color '%s' because the %s could not be built into a playable path.",
                        trainIndex,
                        tostring(trainColor),
                        string.lower(getRouteDisplayName({ color = trainColor }))
                    )
                else
                    outputMessage = string.format(
                        "Train %d targets color '%s', but no playable output exists for that color.",
                        trainIndex,
                        tostring(trainColor)
                    )
                end
            else
                outputMessage = string.format("Train %d targets color '%s', but no matching output exists.", trainIndex, tostring(trainColor))
            end
            addError(
                outputMessage,
                {
                    kind = hasOutputEndpoint and "train_unplayable_output" or "train_missing_output",
                    trainId = trainId,
                    trainIndex = trainIndex,
                    lineColor = lineColor,
                    trainColor = trainColor,
                    x = outputEndpoint and outputEndpoint.x or nil,
                    y = outputEndpoint and outputEndpoint.y or nil,
                    parentDiagnosticIndex = parentDiagnosticIndex,
                }
            )
        end
        if lineColorToEdgeId[lineColor]
            and outputColorLookup[trainColor]
            and not canReachGoalColor(lineColorToEdgeId[lineColor], trainColor, edgeById, junctionLookup) then
            addError(string.format(
                "Train %d cannot reach goal color '%s' from source line '%s'.",
                trainIndex,
                tostring(trainColor),
                tostring(lineColor)
            ), {
                kind = "train_unreachable_output",
                trainId = trainId,
                trainIndex = trainIndex,
                lineColor = lineColor,
                trainColor = trainColor,
            })
        end

        trains[#trains + 1] = {
            id = trainId,
            edgeId = lineColorToEdgeId[lineColor],
            lineColor = lineColor,
            trainColor = trainColor,
            goalColor = trainColor,
            spawnTime = spawnTime,
            wagonCount = wagonCount,
            deadline = deadline,
            color = getColor(trainColor),
        }
    end

    if #errors > 0 then
        return {
            title = mapName,
            description = "Custom map loaded from the editor.",
            hint = "Shared endpoints are not junctions. Only one train can safely occupy a line end at a time.",
            footer = "Shared line ends stay contested even without a junction, so spacing still matters.",
            timeLimit = timeLimit,
            junctions = playableJunctions,
            edges = edges,
            trains = trains,
        }, errors, table.concat(errors, " "), diagnostics
    end
    local hasPlayableJunctions = #playableJunctions > 0

    return {
        title = mapName,
        description = "Custom map loaded from the editor.",
        hint = hasPlayableJunctions
            and "Click the junction center to switch inputs. Use the bottom selector to switch outputs."
            or "Shared endpoints are not junctions. Only one train can safely occupy a line end at a time.",
        footer = hasPlayableJunctions
            and "Sequence trains from the editor pane and clear every goal on time."
            or "Shared line ends stay contested even without a junction, so spacing still matters.",
        timeLimit = timeLimit,
        junctions = playableJunctions,
        edges = edges,
        trains = trains,
    }, {}, nil, diagnostics
end

end
