local authoredMap = {}

local COLOR_LOOKUP = {
    blue = { 0.33, 0.80, 0.98 },
    yellow = { 0.98, 0.82, 0.34 },
    mint = { 0.40, 0.92, 0.76 },
    rose = { 0.98, 0.48, 0.62 },
    orange = { 0.98, 0.70, 0.28 },
    violet = { 0.82, 0.56, 0.98 },
}

local function distanceSquared(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by
    return dx * dx + dy * dy
end

local function copyPoint(point)
    return { x = point.x, y = point.y }
end

local function copyColor(color)
    return { color[1], color[2], color[3] }
end

local function getColor(colorId)
    return copyColor(COLOR_LOOKUP[colorId] or COLOR_LOOKUP.blue)
end

local function darkerColor(color)
    return {
        color[1] * 0.42,
        color[2] * 0.42,
        color[3] * 0.42,
    }
end

local function closestPointOnSegment(px, py, a, b)
    local abX = b.x - a.x
    local abY = b.y - a.y
    local lengthSquared = abX * abX + abY * abY

    if lengthSquared <= 0.0000001 then
        return a.x, a.y, 0, distanceSquared(px, py, a.x, a.y)
    end

    local t = ((px - a.x) * abX + (py - a.y) * abY) / lengthSquared
    if t < 0 then
        t = 0
    elseif t > 1 then
        t = 1
    end

    local x = a.x + abX * t
    local y = a.y + abY * t
    return x, y, t, distanceSquared(px, py, x, y)
end

local function pointOnSegment(point, a, b, toleranceSquared)
    local closestX, closestY, _, distance = closestPointOnSegment(point.x, point.y, a, b)
    if distance <= (toleranceSquared or 0.000004) then
        return { x = closestX, y = closestY }
    end
    return nil
end

local function splitRouteAtPoint(routePoints, junctionPoint)
    local prefix = { copyPoint(routePoints[1]) }

    for pointIndex = 1, #routePoints - 1 do
        local a = routePoints[pointIndex]
        local b = routePoints[pointIndex + 1]
        local hitPoint = pointOnSegment(junctionPoint, a, b)

        if hitPoint then
            if distanceSquared(prefix[#prefix].x, prefix[#prefix].y, hitPoint.x, hitPoint.y) > 0.0000001 then
                prefix[#prefix + 1] = hitPoint
            end
            return prefix
        end

        prefix[#prefix + 1] = copyPoint(b)
    end

    return nil
end

local function splitRouteSuffixAtPoint(routePoints, junctionPoint)
    for pointIndex = 1, #routePoints - 1 do
        local a = routePoints[pointIndex]
        local b = routePoints[pointIndex + 1]
        local hitPoint = pointOnSegment(junctionPoint, a, b)

        if hitPoint then
            local suffix = { hitPoint }
            if distanceSquared(hitPoint.x, hitPoint.y, b.x, b.y) > 0.0000001 then
                suffix[#suffix + 1] = copyPoint(b)
            end
            for suffixIndex = pointIndex + 2, #routePoints do
                suffix[#suffix + 1] = copyPoint(routePoints[suffixIndex])
            end
            return suffix
        end
    end

    return nil
end

local function pointsRoughlyMatch(firstPoints, secondPoints, tolerance)
    if #firstPoints ~= #secondPoints then
        return false
    end

    local toleranceSquared = (tolerance or 0.001) * (tolerance or 0.001)
    for index = 1, #firstPoints do
        if distanceSquared(firstPoints[index].x, firstPoints[index].y, secondPoints[index].x, secondPoints[index].y) > toleranceSquared then
            return false
        end
    end

    return true
end

local function getEndpointById(editorData, endpointId)
    for _, endpoint in ipairs(editorData.endpoints or {}) do
        if endpoint.id == endpointId then
            return endpoint
        end
    end
    return nil
end

local function getRouteById(editorData, routeId)
    for _, route in ipairs(editorData.routes or {}) do
        if route.id == routeId then
            return route
        end
    end
    return nil
end

local function sortRouteIdsByMagnet(editorData, routeIds, magnetKind)
    table.sort(routeIds, function(firstRouteId, secondRouteId)
        local firstRoute = getRouteById(editorData, firstRouteId)
        local secondRoute = getRouteById(editorData, secondRouteId)
        if not firstRoute or not secondRoute then
            return tostring(firstRouteId) < tostring(secondRouteId)
        end

        local firstEndpoint = getEndpointById(editorData, magnetKind == "start" and firstRoute.startEndpointId or firstRoute.endEndpointId)
        local secondEndpoint = getEndpointById(editorData, magnetKind == "start" and secondRoute.startEndpointId or secondRoute.endEndpointId)
        if not firstEndpoint or not secondEndpoint then
            return tostring(firstRouteId) < tostring(secondRouteId)
        end

        if magnetKind == "start" then
            if math.abs(firstEndpoint.x - secondEndpoint.x) > 0.0001 then
                return firstEndpoint.x < secondEndpoint.x
            end
            return firstEndpoint.y < secondEndpoint.y
        end

        if math.abs(firstEndpoint.y - secondEndpoint.y) > 0.0001 then
            return firstEndpoint.y < secondEndpoint.y
        end
        return firstEndpoint.x < secondEndpoint.x
    end)
end

local function buildOutputRoutesByEndpoint(editorData, junctionData)
    local routesByEndpoint = {}

    for _, routeId in ipairs(junctionData.routes or {}) do
        local route = getRouteById(editorData, routeId)
        if route and route.endEndpointId then
            routesByEndpoint[route.endEndpointId] = routesByEndpoint[route.endEndpointId] or {}
            routesByEndpoint[route.endEndpointId][#routesByEndpoint[route.endEndpointId] + 1] = route
        end
    end

    return routesByEndpoint
end

function authoredMap.buildPlayableLevel(mapName, editorData)
    if not editorData or #(editorData.junctions or {}) == 0 then
        return nil, "Add at least one lever intersection before saving a playable map."
    end

    local routeMembership = {}
    local junctions = {}
    local trains = {}
    local errors = {}

    for junctionIndex, junctionData in ipairs(editorData.junctions or {}) do
        local junctionPoint = { x = junctionData.x, y = junctionData.y }
        local routeIds = {}
        for _, routeId in ipairs(junctionData.routes or {}) do
            routeIds[#routeIds + 1] = routeId
        end

        local inputRouteIds = {}
        for _, routeId in ipairs(routeIds) do
            inputRouteIds[#inputRouteIds + 1] = routeId
            routeMembership[routeId] = (routeMembership[routeId] or 0) + 1
        end
        sortRouteIdsByMagnet(editorData, inputRouteIds, "start")

        local outputRoutesByEndpoint = buildOutputRoutesByEndpoint(editorData, junctionData)
        local outputEndpointIds = {}
        for _, endpointId in ipairs(junctionData.outputEndpointIds or {}) do
            outputEndpointIds[#outputEndpointIds + 1] = endpointId
        end

        if #inputRouteIds > 5 or #outputEndpointIds > 5 then
            errors[#errors + 1] = "A junction exceeds the current limit of five inputs or five outputs."
            goto continue
        end

        local inputs = {}
        for _, routeId in ipairs(inputRouteIds) do
            local route = getRouteById(editorData, routeId)
            local endpoint = route and getEndpointById(editorData, route.startEndpointId) or nil
            if route and endpoint then
                local prefix = splitRouteAtPoint(route.points or {}, junctionPoint)
                if not prefix then
                    errors[#errors + 1] = "An input route did not actually reach its junction."
                    goto continue
                end

                inputs[#inputs + 1] = {
                    id = route.id .. "_input",
                    routeId = route.id,
                    endpointId = endpoint.id,
                    label = "Input " .. tostring(#inputs + 1),
                    colors = endpoint.colors or {},
                    color = getColor(route.color),
                    darkColor = darkerColor(getColor(route.color)),
                    inputPoints = prefix,
                }
            end
        end

        local outputs = {}
        for _, endpointId in ipairs(outputEndpointIds) do
            local endpoint = getEndpointById(editorData, endpointId)
            local attachedRoutes = outputRoutesByEndpoint[endpointId] or {}
            local representativeRoute = attachedRoutes[1]

            if endpoint and representativeRoute then
                local suffix = splitRouteSuffixAtPoint(representativeRoute.points or {}, junctionPoint)
                if not suffix then
                    errors[#errors + 1] = "An output route did not actually leave its junction."
                    goto continue
                end

                for routeIndex = 2, #attachedRoutes do
                    local candidateSuffix = splitRouteSuffixAtPoint(attachedRoutes[routeIndex].points or {}, junctionPoint)
                    if not candidateSuffix or not pointsRoughlyMatch(suffix, candidateSuffix) then
                        errors[#errors + 1] = "Merged outputs must share the same path from the junction to the exit."
                        goto continue
                    end
                end

                outputs[#outputs + 1] = {
                    id = endpoint.id,
                    endpointId = endpoint.id,
                    label = "Output " .. tostring(#outputs + 1),
                    colors = endpoint.colors or {},
                    color = getColor(representativeRoute.color),
                    darkColor = darkerColor(getColor(representativeRoute.color)),
                    adoptInputColor = #(endpoint.colors or {}) > 1,
                    outputPoints = suffix,
                }
            end
        end

        if #inputs == 0 or #outputs == 0 then
            errors[#errors + 1] = "A playable junction needs at least one input and one output."
            goto continue
        end

        junctions[#junctions + 1] = {
            id = "saved_junction_" .. junctionIndex,
            activeInputIndex = math.min(junctionData.activeInputIndex or 1, #inputs),
            activeOutputIndex = math.min(junctionData.activeOutputIndex or 1, #outputs),
            control = {
                type = junctionData.control or "direct",
                label = junctionData.control == "delayed" and "Delayed Button"
                    or junctionData.control == "pump" and "Charge Lever"
                    or "Direct Lever",
                delay = junctionData.control == "delayed" and 2.25 or nil,
                target = junctionData.control == "pump" and 7 or nil,
                decayDelay = junctionData.control == "pump" and 0.55 or nil,
                decayInterval = junctionData.control == "pump" and 0.2 or nil,
            },
            inputs = inputs,
            outputs = outputs,
        }

        local trainOffset = 0
        for inputIndex, inputDefinition in ipairs(inputs) do
            for colorIndex, colorId in ipairs(inputDefinition.colors or {}) do
                trains[#trains + 1] = {
                    id = string.format("saved_junction_%d_train_%d_%s", junctionIndex, inputIndex, colorId),
                    junctionId = "saved_junction_" .. junctionIndex,
                    inputIndex = inputIndex,
                    progress = -70 - trainOffset,
                    speedScale = 1.0 - math.min(0.18, (colorIndex - 1) * 0.05),
                    color = getColor(colorId),
                }
                trainOffset = trainOffset + 110
            end
        end

        ::continue::
    end

    for _, route in ipairs(editorData.routes or {}) do
        local membershipCount = routeMembership[route.id] or 0
        if membershipCount == 0 then
            errors[#errors + 1] = string.format("Route '%s' is not attached to a playable junction.", route.label or route.id)
        elseif membershipCount > 1 then
            errors[#errors + 1] = string.format("Route '%s' is attached to more than one junction.", route.label or route.id)
        end
    end

    if #errors > 0 then
        return nil, table.concat(errors, " ")
    end

    return {
        title = mapName,
        description = "Custom map loaded from the editor.",
        hint = "Click the junction center to switch inputs. Use the bottom selector to switch outputs.",
        footer = "Saved maps support up to five input tracks and five output tracks per junction.",
        timeLimit = nil,
        junctions = junctions,
        trains = trains,
    }
end

return authoredMap
