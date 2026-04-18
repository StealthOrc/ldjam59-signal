local mapStorage = require("src.game.map_storage")
local authoredMap = require("src.game.authored_map")

local mapEditor = {}
mapEditor.__index = mapEditor

local DEFAULT_CONTROL = "direct"
local CONTROL_ORDER = { "direct", "delayed", "pump" }
local CONTROL_LABELS = {
    direct = "D",
    delayed = "T",
    pump = "P",
}
local CONTROL_NAMES = {
    direct = "Direct Lever",
    delayed = "Delayed Button",
    pump = "Charge Lever",
}
local COLOR_OPTIONS = {
    { id = "blue", label = "Blue", color = { 0.33, 0.8, 0.98 } },
    { id = "yellow", label = "Yellow", color = { 0.98, 0.82, 0.34 } },
    { id = "mint", label = "Mint", color = { 0.4, 0.92, 0.76 } },
    { id = "rose", label = "Rose", color = { 0.98, 0.48, 0.62 } },
    { id = "orange", label = "Orange", color = { 0.98, 0.7, 0.28 } },
    { id = "violet", label = "Violet", color = { 0.82, 0.56, 0.98 } },
}

local DEFAULT_CONTROL_CONFIGS = {
    direct = {
        label = "Direct Lever",
    },
    delayed = {
        label = "Delayed Button",
        delay = 2.25,
    },
    pump = {
        label = "Charge Lever",
        target = 7,
        decayDelay = 0.55,
        decayInterval = 0.2,
    },
}

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function pointInRect(x, y, rect)
    return x >= rect.x
        and x <= rect.x + rect.w
        and y >= rect.y
        and y <= rect.y + rect.h
end

local function distanceSquared(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by
    return dx * dx + dy * dy
end

local function copyPoint(point)
    return { x = point.x, y = point.y }
end

local function normalizeColor(color)
    return {
        clamp(color[1], 0, 1),
        clamp(color[2], 0, 1),
        clamp(color[3], 0, 1),
    }
end

local function darkerColor(color)
    return {
        color[1] * 0.42,
        color[2] * 0.42,
        color[3] * 0.42,
    }
end

local function routePairKey(a, b)
    if a < b then
        return a .. "|" .. b
    end
    return b .. "|" .. a
end

local function formatNumber(value)
    return string.format("%.4f", value)
end

local function countLookupEntries(lookup)
    local count = 0
    for _, enabled in pairs(lookup or {}) do
        if enabled then
            count = count + 1
        end
    end
    return count
end

local function lookupToSortedIds(lookup)
    local ids = {}
    for _, option in ipairs(COLOR_OPTIONS) do
        if lookup and lookup[option.id] then
            ids[#ids + 1] = option.id
        end
    end
    return ids
end

local function colorsToLookup(source, fallbackId)
    local lookup = {}

    if type(source) == "table" then
        local isArray = false
        for key, _ in pairs(source) do
            if type(key) == "number" then
                isArray = true
                break
            end
        end

        if isArray then
            for _, id in ipairs(source) do
                lookup[id] = true
            end
        else
            for id, enabled in pairs(source) do
                lookup[id] = enabled and true or nil
            end
        end
    end

    if countLookupEntries(lookup) == 0 and fallbackId then
        lookup[fallbackId] = true
    end

    return lookup
end

local function getColorOptionById(colorId)
    for _, option in ipairs(COLOR_OPTIONS) do
        if option.id == colorId then
            return option
        end
    end
    return nil
end

local function getColorById(colorId)
    local option = getColorOptionById(colorId)
    if option then
        return option.color
    end
    return COLOR_OPTIONS[1].color
end

local function nearestColorId(color)
    if not color then
        return COLOR_OPTIONS[1].id
    end

    local bestId = COLOR_OPTIONS[1].id
    local bestDistance = math.huge

    for _, option in ipairs(COLOR_OPTIONS) do
        local distance = distanceSquared(
            color[1], color[2],
            option.color[1], option.color[2]
        ) + (color[3] - option.color[3]) * (color[3] - option.color[3])

        if distance < bestDistance then
            bestDistance = distance
            bestId = option.id
        end
    end

    return bestId
end

local function segmentIntersection(a, b, c, d)
    local rX = b.x - a.x
    local rY = b.y - a.y
    local sX = d.x - c.x
    local sY = d.y - c.y
    local denominator = rX * sY - rY * sX
    local qpx = c.x - a.x
    local qpy = c.y - a.y
    local crossQPR = qpx * rY - qpy * rX

    if math.abs(denominator) < 0.0001 then
        if math.abs(crossQPR) > 0.0001 then
            return nil
        end

        local sharedPoints = {
            { x = a.x, y = a.y },
            { x = b.x, y = b.y },
            { x = c.x, y = c.y },
            { x = d.x, y = d.y },
        }

        for _, point in ipairs(sharedPoints) do
            local onAB = math.min(a.x, b.x) - 0.001 <= point.x and point.x <= math.max(a.x, b.x) + 0.001
                and math.min(a.y, b.y) - 0.001 <= point.y and point.y <= math.max(a.y, b.y) + 0.001
            local onCD = math.min(c.x, d.x) - 0.001 <= point.x and point.x <= math.max(c.x, d.x) + 0.001
                and math.min(c.y, d.y) - 0.001 <= point.y and point.y <= math.max(c.y, d.y) + 0.001

            if onAB and onCD then
                return { x = point.x, y = point.y }
            end
        end

        return nil
    end

    local t = (qpx * sY - qpy * sX) / denominator
    local u = (qpx * rY - qpy * rX) / denominator

    if t < -0.0001 or t > 1.0001 or u < -0.0001 or u > 1.0001 then
        return nil
    end

    return {
        x = a.x + t * rX,
        y = a.y + t * rY,
    }
end

local function closestPointOnSegment(px, py, a, b)
    local abX = b.x - a.x
    local abY = b.y - a.y
    local lengthSquared = abX * abX + abY * abY

    if lengthSquared <= 0.0001 then
        return a.x, a.y, 0, distanceSquared(px, py, a.x, a.y)
    end

    local t = ((px - a.x) * abX + (py - a.y) * abY) / lengthSquared
    t = clamp(t, 0, 1)

    local x = a.x + abX * t
    local y = a.y + abY * t
    return x, y, t, distanceSquared(px, py, x, y)
end

local function pointOnSegment(point, a, b, toleranceSquared)
    local closestX, closestY, _, distance = closestPointOnSegment(point.x, point.y, a, b)
    if distance <= (toleranceSquared or 4) then
        return { x = closestX, y = closestY }
    end
    return nil
end

function mapEditor.new(viewportW, viewportH, level)
    local self = setmetatable({}, mapEditor)

    self.viewport = { w = viewportW, h = viewportH }
    self.endpoints = {}
    self.routes = {}
    self.nextEndpointId = 1
    self.nextRouteId = 1
    self.selectedRouteId = nil
    self.selectedPointIndex = nil
    self.drag = nil
    self.colorPicker = nil
    self.dialog = nil
    self.currentMapName = nil
    self.sourceInfo = nil
    self.loadedMapPayload = nil
    self.lastValidationError = nil
    self.statusText = nil
    self.statusTimer = 0
    self.intersections = {}
    self.importedJunctionState = {}

    self:updateLayout()
    self:resetFromMap(level and { level = level, name = level.title } or nil, nil)

    return self
end

function mapEditor:updateLayout()
    self.margin = 20
    self.panelWidth = 320
    self.canvas = {
        x = self.margin,
        y = self.margin,
        w = self.viewport.w - self.panelWidth - self.margin * 3,
        h = self.viewport.h - self.margin * 2,
    }
    self.spawnBandHeight = 58
    self.spawnY = self.canvas.y + 22
    self.sidePanel = {
        x = self.canvas.x + self.canvas.w + self.margin,
        y = self.margin,
        w = self.panelWidth,
        h = self.viewport.h - self.margin * 2,
    }
end

function mapEditor:clearSelection()
    self.selectedRouteId = nil
    self.selectedPointIndex = nil
end

function mapEditor:getSelectedRoute()
    if not self.selectedRouteId then
        return nil
    end

    for _, route in ipairs(self.routes) do
        if route.id == self.selectedRouteId then
            return route
        end
    end

    return nil
end

function mapEditor:createEndpoint(kind, x, y, colors, id)
    local endpointId = id or (kind .. "_endpoint_" .. self.nextEndpointId)
    local fallbackColorId = COLOR_OPTIONS[((self.nextEndpointId - 1) % #COLOR_OPTIONS) + 1].id
    local endpoint = {
        id = endpointId,
        kind = kind,
        x = x,
        y = y,
        colors = colorsToLookup(colors, fallbackColorId),
    }
    self.endpoints[#self.endpoints + 1] = endpoint
    self.nextEndpointId = self.nextEndpointId + 1
    return endpoint
end

function mapEditor:getEndpointById(endpointId)
    for _, endpoint in ipairs(self.endpoints) do
        if endpoint.id == endpointId then
            return endpoint
        end
    end
    return nil
end

function mapEditor:getRouteStartEndpoint(route)
    return self:getEndpointById(route.startEndpointId)
end

function mapEditor:getRouteEndEndpoint(route)
    return self:getEndpointById(route.endEndpointId)
end

function mapEditor:getEndpointRouteCount(endpointId)
    local count = 0
    for _, route in ipairs(self.routes) do
        if route.startEndpointId == endpointId or route.endEndpointId == endpointId then
            count = count + 1
        end
    end
    return count
end

function mapEditor:removeEndpointIfUnused(endpointId)
    if self:getEndpointRouteCount(endpointId) > 0 then
        return
    end

    for endpointIndex, endpoint in ipairs(self.endpoints) do
        if endpoint.id == endpointId then
            table.remove(self.endpoints, endpointIndex)
            return
        end
    end
end

function mapEditor:updateRouteEndpointPoint(route, endpointKind)
    local endpoint = endpointKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route)
    if not endpoint then
        return
    end

    if endpointKind == "start" then
        route.points[1].x = endpoint.x
        route.points[1].y = endpoint.y
    else
        route.points[#route.points].x = endpoint.x
        route.points[#route.points].y = endpoint.y
    end
end

function mapEditor:updateRoutesForEndpoint(endpointId)
    for _, route in ipairs(self.routes) do
        if route.startEndpointId == endpointId then
            self:updateRouteEndpointPoint(route, "start")
        end
        if route.endEndpointId == endpointId then
            self:updateRouteEndpointPoint(route, "end")
        end
    end
end

function mapEditor:getControlName(controlType)
    return CONTROL_NAMES[controlType] or CONTROL_NAMES[DEFAULT_CONTROL]
end

function mapEditor:getControlLabel(controlType)
    return CONTROL_LABELS[controlType] or CONTROL_LABELS[DEFAULT_CONTROL]
end

function mapEditor:showStatus(text)
    self.statusText = text
    self.statusTimer = 2.8
end

function mapEditor:createRoute(points, color, id, label, colorId, startColors, endColors, startEndpointId, endEndpointId)
    local routeId = id or ("route_" .. self.nextRouteId)
    local resolvedColorId = colorId or nearestColorId(color)
    local resolvedColor = normalizeColor(color or getColorById(resolvedColorId))
    local startPoint = points[1]
    local endPoint = points[#points]
    local startEndpoint = startEndpointId and self:getEndpointById(startEndpointId)
        or self:createEndpoint("input", startPoint.x, startPoint.y, startColors or { resolvedColorId }, startEndpointId)
    local endEndpoint = endEndpointId and self:getEndpointById(endEndpointId)
        or self:createEndpoint("output", endPoint.x, endPoint.y, endColors or { resolvedColorId }, endEndpointId)
    local route = {
        id = routeId,
        label = label or routeId,
        colorId = resolvedColorId,
        color = resolvedColor,
        darkColor = darkerColor(resolvedColor),
        startEndpointId = startEndpoint.id,
        endEndpointId = endEndpoint.id,
        points = {},
    }

    for _, point in ipairs(points) do
        route.points[#route.points + 1] = copyPoint(point)
    end

    self.routes[#self.routes + 1] = route
    self.nextRouteId = self.nextRouteId + 1
    self:updateRouteEndpointPoint(route, "start")
    self:updateRouteEndpointPoint(route, "end")
    return route
end

function mapEditor:getSaveButtonRect()
    return {
        x = self.sidePanel.x + 18,
        y = self.sidePanel.y + self.sidePanel.h - 210,
        w = self.sidePanel.w - 36,
        h = 38,
    }
end

function mapEditor:getOpenButtonRect()
    return {
        x = self.sidePanel.x + 18,
        y = self.sidePanel.y + self.sidePanel.h - 160,
        w = self.sidePanel.w - 36,
        h = 38,
    }
end

function mapEditor:getCopyButtonRect()
    return {
        x = self.sidePanel.x + 18,
        y = self.sidePanel.y + self.sidePanel.h - 110,
        w = self.sidePanel.w - 36,
        h = 38,
    }
end

function mapEditor:getResetButtonRect()
    return {
        x = self.sidePanel.x + 18,
        y = self.sidePanel.y + self.sidePanel.h - 60,
        w = self.sidePanel.w - 36,
        h = 38,
    }
end

function mapEditor:isInSpawnBand(x, y)
    return x >= self.canvas.x
        and x <= self.canvas.x + self.canvas.w
        and y >= self.canvas.y
        and y <= self.canvas.y + self.spawnBandHeight
end

function mapEditor:clampPoint(x, y, isStartPoint)
    local clampedX = clamp(x, self.canvas.x + 14, self.canvas.x + self.canvas.w - 14)
    local minY = self.canvas.y + 14
    local maxY = self.canvas.y + self.canvas.h - 14
    local clampedY = clamp(y, minY, maxY)

    if isStartPoint then
        clampedY = self.spawnY
    end

    return clampedX, clampedY
end

function mapEditor:closeColorPicker()
    self.colorPicker = nil
end

function mapEditor:openColorPicker(route, magnetKind)
    local point = magnetKind == "start" and route.points[1] or route.points[#route.points]
    self.colorPicker = {
        routeId = route.id,
        magnetKind = magnetKind,
        anchorX = point.x,
        anchorY = point.y,
    }
end

function mapEditor:getColorPickerLayout()
    if not self.colorPicker then
        return nil
    end

    local rect = {
        w = 196,
        h = 146,
    }
    rect.x = clamp(
        self.colorPicker.anchorX + 18,
        self.canvas.x + 8,
        self.viewport.w - rect.w - 8
    )
    rect.y = clamp(
        self.colorPicker.anchorY - rect.h * 0.5,
        self.canvas.y + 8,
        self.viewport.h - rect.h - 8
    )

    local swatches = {}
    local columns = 3
    local swatchSize = 34
    local gap = 12
    local startX = rect.x + 16
    local startY = rect.y + 52

    for index, option in ipairs(COLOR_OPTIONS) do
        local column = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        swatches[#swatches + 1] = {
            option = option,
            rect = {
                x = startX + column * (swatchSize + gap),
                y = startY + row * (swatchSize + 28),
                w = swatchSize,
                h = swatchSize,
            },
        }
    end

    return {
        rect = rect,
        swatches = swatches,
    }
end

function mapEditor:closeDialog()
    self.dialog = nil
end

function mapEditor:openSaveDialog()
    local defaultName = self.currentMapName or ""
    if self.sourceInfo and self.sourceInfo.source == "builtin" and defaultName ~= "" and not defaultName:match(" Copy$") then
        defaultName = defaultName .. " Copy"
    end
    self.dialog = {
        type = "save",
        input = defaultName,
    }
end

function mapEditor:openOpenDialog()
    self.dialog = {
        type = "open",
        maps = mapStorage.listMaps(),
    }
end

function mapEditor:getDialogRect()
    return {
        x = self.viewport.w * 0.5 - 260,
        y = self.viewport.h * 0.5 - 180,
        w = 520,
        h = 360,
    }
end

function mapEditor:getExportData()
    local export = {
        endpoints = {},
        routes = {},
        junctions = {},
    }

    for _, endpoint in ipairs(self.endpoints) do
        export.endpoints[#export.endpoints + 1] = {
            id = endpoint.id,
            kind = endpoint.kind,
            x = endpoint.x / self.viewport.w,
            y = endpoint.y / self.viewport.h,
            colors = lookupToSortedIds(endpoint.colors),
        }
    end

    for _, route in ipairs(self.routes) do
        local exportRoute = {
            id = route.id,
            label = route.label or route.id,
            color = route.colorId,
            startEndpointId = route.startEndpointId,
            endEndpointId = route.endEndpointId,
            points = {},
        }

        for _, point in ipairs(route.points) do
            exportRoute.points[#exportRoute.points + 1] = {
                x = point.x / self.viewport.w,
                y = point.y / self.viewport.h,
            }
        end

        export.routes[#export.routes + 1] = exportRoute
    end

    for _, intersection in ipairs(self.intersections) do
        local exportJunction = {
            id = intersection.id,
            x = intersection.x / self.viewport.w,
            y = intersection.y / self.viewport.h,
            control = intersection.controlType,
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

    return export
end

function mapEditor:loadEditorData(editorData, mapName, sourceInfo, levelData)
    self.level = levelData
    self.endpoints = {}
    self.routes = {}
    self.nextEndpointId = 1
    self.nextRouteId = 1
    self.importedJunctionState = {}
    self.drag = nil
    self.currentMapName = mapName
    self.sourceInfo = sourceInfo
    self:closeDialog()
    self:closeColorPicker()
    self:clearSelection()

    for _, endpointData in ipairs((editorData or {}).endpoints or {}) do
        self:createEndpoint(
            endpointData.kind or "output",
            endpointData.x * self.viewport.w,
            endpointData.y * self.viewport.h,
            endpointData.colors,
            endpointData.id
        )
    end

    for _, routeData in ipairs((editorData or {}).routes or {}) do
        local points = {}
        for _, point in ipairs(routeData.points or {}) do
            points[#points + 1] = {
                x = point.x * self.viewport.w,
                y = point.y * self.viewport.h,
            }
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
            routeData.endEndpointId
        )
    end

    for _, junctionData in ipairs((editorData or {}).junctions or {}) do
        local sortedRouteIds = {}
        for _, routeId in ipairs(junctionData.routes or {}) do
            sortedRouteIds[#sortedRouteIds + 1] = routeId
        end
        table.sort(sortedRouteIds)
        self.importedJunctionState[table.concat(sortedRouteIds, "|")] = {
            id = junctionData.id,
            x = junctionData.x * self.viewport.w,
            y = junctionData.y * self.viewport.h,
            controlType = junctionData.control or DEFAULT_CONTROL,
            activeInputIndex = junctionData.activeInputIndex or 1,
            activeOutputIndex = junctionData.activeOutputIndex or 1,
            inputEndpointIds = junctionData.inputEndpointIds,
            outputEndpointIds = junctionData.outputEndpointIds,
        }
    end

    self:rebuildIntersections()
    self:showStatus("Map loaded into the editor.")
end

function mapEditor:getRouteById(routeId)
    for _, route in ipairs(self.routes) do
        if route.id == routeId then
            return route
        end
    end
    return nil
end

function mapEditor:getControlConfig(controlType)
    local config = DEFAULT_CONTROL_CONFIGS[controlType] or DEFAULT_CONTROL_CONFIGS.direct
    local copy = {}
    for key, value in pairs(config) do
        copy[key] = value
    end
    copy.type = controlType
    return copy
end

function mapEditor:splitRouteAtIntersection(route, intersectionPoint)
    local prefix = {}
    prefix[#prefix + 1] = copyPoint(route.points[1])

    for pointIndex = 1, #route.points - 1 do
        local a = route.points[pointIndex]
        local b = route.points[pointIndex + 1]
        local hitPoint = pointOnSegment(intersectionPoint, a, b, 9)

        if hitPoint then
            if distanceSquared(prefix[#prefix].x, prefix[#prefix].y, hitPoint.x, hitPoint.y) > 1 then
                prefix[#prefix + 1] = hitPoint
            end
            return prefix
        end

        prefix[#prefix + 1] = copyPoint(b)
    end

    return nil
end

function mapEditor:splitRouteSuffixAtIntersection(route, intersectionPoint)
    for pointIndex = 1, #route.points - 1 do
        local a = route.points[pointIndex]
        local b = route.points[pointIndex + 1]
        local hitPoint = pointOnSegment(intersectionPoint, a, b, 9)

        if hitPoint then
            local suffix = { hitPoint }
            if distanceSquared(hitPoint.x, hitPoint.y, b.x, b.y) > 1 then
                suffix[#suffix + 1] = copyPoint(b)
            end
            for suffixIndex = pointIndex + 2, #route.points do
                suffix[#suffix + 1] = copyPoint(route.points[suffixIndex])
            end
            return suffix
        end
    end

    return nil
end

function mapEditor:normalizePoints(points)
    local normalized = {}
    for _, point in ipairs(points) do
        normalized[#normalized + 1] = {
            x = point.x / self.viewport.w,
            y = point.y / self.viewport.h,
        }
    end
    return normalized
end

local function pointsRoughlyMatch(firstPoints, secondPoints, tolerance)
    if #firstPoints ~= #secondPoints then
        return false
    end

    tolerance = tolerance or 6
    local toleranceSquared = tolerance * tolerance

    for index = 1, #firstPoints do
        if distanceSquared(firstPoints[index].x, firstPoints[index].y, secondPoints[index].x, secondPoints[index].y) > toleranceSquared then
            return false
        end
    end

    return true
end

function mapEditor:buildOutputRoutesByEndpoint(intersection)
    local routesByEndpoint = {}

    for _, routeId in ipairs(intersection.routeIds or {}) do
        local route = self:getRouteById(routeId)
        if route and route.endEndpointId then
            routesByEndpoint[route.endEndpointId] = routesByEndpoint[route.endEndpointId] or {}
            routesByEndpoint[route.endEndpointId][#routesByEndpoint[route.endEndpointId] + 1] = route
        end
    end

    return routesByEndpoint
end

function mapEditor:buildPlayableLevel(mapName)
    local level, buildError = authoredMap.buildPlayableLevel(mapName, self:getExportData())
    self.lastValidationError = buildError
    return level, buildError
end

function mapEditor:saveMap(name)
    local trimmedName = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if trimmedName == "" then
        return false, "Give the map a name before saving it."
    end

    local level, buildError = self:buildPlayableLevel(trimmedName)
    if not level then
        buildError = buildError or "This map cannot be played yet, but the editor layout can still be saved."
    end

    local payload = {
        version = 1,
        name = trimmedName,
        savedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        editor = self:getExportData(),
    }
    if level then
        payload.level = level
    end
    local wasBuiltinTemplate = self.sourceInfo and self.sourceInfo.source == "builtin"
    local record, saveError = mapStorage.saveMap(trimmedName, payload)
    if not record then
        return false, saveError or "The map could not be written to disk."
    end

    self.currentMapName = trimmedName
    self.sourceInfo = record
    self.loadedMapPayload = payload
    self:closeDialog()
    if level then
        self:showStatus((wasBuiltinTemplate and "Saved copy: " or "Saved map: ") .. trimmedName .. " to " .. mapStorage.getSaveDirectory())
    else
        self:showStatus("Saved editor map only: " .. trimmedName .. ". " .. buildError)
    end
    return true
end

function mapEditor:resetFromMap(mapData, sourceInfo)
    self.loadedMapPayload = mapData
    self.sourceInfo = sourceInfo

    if not mapData then
        self.level = nil
        self.currentMapName = nil
        self.endpoints = {}
        self.routes = {}
        self.nextEndpointId = 1
        self.nextRouteId = 1
        self.importedJunctionState = {}
        self.drag = nil
        self:closeColorPicker()
        self:clearSelection()
        self:rebuildIntersections()
        return
    end

    if mapData.editor then
        self:loadEditorData(mapData.editor, mapData.name, sourceInfo, mapData.level)
        return
    end

    self:resetFromLevel(mapData.level)
    self.sourceInfo = sourceInfo
    self.loadedMapPayload = mapData
end

function mapEditor:resetFromLevel(level)
    self.level = level
    self.currentMapName = level and level.title or nil
    self.endpoints = {}
    self.routes = {}
    self.nextEndpointId = 1
    self.nextRouteId = 1
    self.importedJunctionState = {}
    self.drag = nil
    self:closeColorPicker()
    self:clearSelection()

    if not level then
        self:rebuildIntersections()
        return
    end

    for _, junctionDefinition in ipairs(level.junctions or {}) do
        local mergeX
        local mergeY
        local exitY
        local branchRoutes = {}

        for _, branchDefinition in ipairs(junctionDefinition.branches or {}) do
            local branchColorId = nearestColorId(branchDefinition.color)
            local points

            if branchDefinition.branchPoints and branchDefinition.sharedPoints then
                points = {}
                for _, point in ipairs(branchDefinition.branchPoints) do
                    points[#points + 1] = {
                        x = point.x * self.viewport.w,
                        y = point.y * self.viewport.h,
                    }
                end
                for pointIndex = 2, #branchDefinition.sharedPoints do
                    local point = branchDefinition.sharedPoints[pointIndex]
                    points[#points + 1] = {
                        x = point.x * self.viewport.w,
                        y = point.y * self.viewport.h,
                    }
                end
                mergeX = points[#branchDefinition.branchPoints].x
                mergeY = points[#branchDefinition.branchPoints].y
                exitY = points[#points].y
            else
                mergeX = self.canvas.x + self.canvas.w * junctionDefinition.mergeX
                mergeY = self.canvas.y + self.canvas.h * junctionDefinition.mergeY
                exitY = self.canvas.y + self.canvas.h * clamp(junctionDefinition.exitY or 1.0, 0, 1)
                local bendY = mergeY - self.canvas.h * 0.22
                local startX = self.canvas.x + self.canvas.w * branchDefinition.startX
                points = {
                    { x = startX, y = self.spawnY },
                    { x = startX, y = bendY },
                    { x = mergeX, y = mergeY },
                    { x = mergeX, y = exitY },
                }
            end

            local route = self:createRoute(
                points,
                branchDefinition.color,
                nil,
                branchDefinition.label or branchDefinition.id,
                branchColorId,
                { branchColorId },
                { branchColorId }
            )
            branchRoutes[#branchRoutes + 1] = route
        end

        if #branchRoutes == 2 then
            local key = routePairKey(branchRoutes[1].id, branchRoutes[2].id)
            self.importedJunctionState[key] = {
                x = mergeX,
                y = mergeY,
                controlType = ((junctionDefinition.control or {}).type) or DEFAULT_CONTROL,
                activeInputIndex = junctionDefinition.activeBranch or 1,
                activeOutputIndex = 1,
            }
        end
    end

    self:rebuildIntersections()
end

function mapEditor:resize(viewportW, viewportH)
    self.viewport.w = viewportW
    self.viewport.h = viewportH
    self:updateLayout()
    self:rebuildIntersections()
end

function mapEditor:update(dt)
    if self.statusTimer > 0 then
        self.statusTimer = math.max(0, self.statusTimer - dt)
        if self.statusTimer <= 0 then
            self.statusText = nil
        end
    end
end

function mapEditor:findIntersectionHit(x, y)
    for _, intersection in ipairs(self.intersections) do
        local radius = intersection.unsupported and 18 or 22
        if distanceSquared(x, y, intersection.x, intersection.y) <= radius * radius then
            return intersection
        end
    end

    return nil
end

function mapEditor:findPointHit(x, y)
    for routeIndex = #self.routes, 1, -1 do
        local route = self.routes[routeIndex]
        for pointIndex = #route.points, 1, -1 do
            local point = route.points[pointIndex]
            local isMagnet = pointIndex == 1 or pointIndex == #route.points
            local radius = isMagnet and 16 or 12
            if distanceSquared(x, y, point.x, point.y) <= radius * radius then
                local magnetKind = nil
                if pointIndex == 1 then
                    magnetKind = "start"
                elseif pointIndex == #route.points then
                    magnetKind = "end"
                end
                return route, pointIndex, magnetKind
            end
        end
    end

    return nil, nil, nil
end

function mapEditor:findEndpointAt(x, y, kind, excludeEndpointId)
    for _, endpoint in ipairs(self.endpoints) do
        if endpoint.kind == kind and endpoint.id ~= excludeEndpointId then
            if distanceSquared(x, y, endpoint.x, endpoint.y) <= 18 * 18 then
                return endpoint
            end
        end
    end
    return nil
end

function mapEditor:findSegmentHit(x, y)
    local bestHit = nil
    local bestDistance = 16 * 16

    for routeIndex = #self.routes, 1, -1 do
        local route = self.routes[routeIndex]
        for pointIndex = 1, #route.points - 1 do
            local a = route.points[pointIndex]
            local b = route.points[pointIndex + 1]
            local closestX, closestY, t, distance = closestPointOnSegment(x, y, a, b)

            if distance < bestDistance and t > 0.08 and t < 0.92 then
                bestDistance = distance
                bestHit = {
                    route = route,
                    insertIndex = pointIndex + 1,
                    point = { x = closestX, y = closestY },
                }
            end
        end
    end

    return bestHit
end

function mapEditor:deleteSelection()
    local selectedRoute = self:getSelectedRoute()
    if not selectedRoute then
        return
    end

    self:closeColorPicker()

    if self.selectedPointIndex and self.selectedPointIndex > 1 and self.selectedPointIndex < #selectedRoute.points then
        table.remove(selectedRoute.points, self.selectedPointIndex)
        self.selectedPointIndex = nil
        self:rebuildIntersections()
        self:showStatus("Bend point removed.")
        return
    end

    for routeIndex, route in ipairs(self.routes) do
        if route.id == selectedRoute.id then
            table.remove(self.routes, routeIndex)
            break
        end
    end

    self:clearSelection()
    self:rebuildIntersections()
    self:showStatus("Route removed.")
end

function mapEditor:getIntersectionControlType(intersection, previousMatches)
    local imported = self.importedJunctionState[intersection.routeKey]
    if imported and distanceSquared(imported.x, imported.y, intersection.x, intersection.y) <= 24 * 24 then
        return imported.controlType
    end

    for _, previous in ipairs(previousMatches) do
        if previous.routeKey == intersection.routeKey and distanceSquared(previous.x, previous.y, intersection.x, intersection.y) <= 24 * 24 then
            return previous.controlType
        end
    end

    return DEFAULT_CONTROL
end

function mapEditor:getJunctionState(intersection, previousMatches)
    local imported = self.importedJunctionState[intersection.routeKey]
    if imported and distanceSquared(imported.x, imported.y, intersection.x, intersection.y) <= 24 * 24 then
        return imported
    end

    for _, previous in ipairs(previousMatches) do
        if previous.routeKey == intersection.routeKey and distanceSquared(previous.x, previous.y, intersection.x, intersection.y) <= 24 * 24 then
            return previous
        end
    end

    return nil
end

function mapEditor:sortEndpointIdsByPosition(endpointIds, kind)
    table.sort(endpointIds, function(firstId, secondId)
        local first = self:getEndpointById(firstId)
        local second = self:getEndpointById(secondId)
        if not first or not second then
            return tostring(firstId) < tostring(secondId)
        end

        if kind == "input" then
            if math.abs(first.x - second.x) > 1 then
                return first.x < second.x
            end
            return first.y < second.y
        end

        if math.abs(first.y - second.y) > 1 then
            return first.y < second.y
        end
        return first.x < second.x
    end)
end

function mapEditor:sortRouteIdsByMagnet(routeIds, magnetKind)
    table.sort(routeIds, function(firstRouteId, secondRouteId)
        local firstRoute = self:getRouteById(firstRouteId)
        local secondRoute = self:getRouteById(secondRouteId)
        if not firstRoute or not secondRoute then
            return tostring(firstRouteId) < tostring(secondRouteId)
        end

        local firstEndpoint = magnetKind == "start"
            and self:getRouteStartEndpoint(firstRoute)
            or self:getRouteEndEndpoint(firstRoute)
        local secondEndpoint = magnetKind == "start"
            and self:getRouteStartEndpoint(secondRoute)
            or self:getRouteEndEndpoint(secondRoute)

        if not firstEndpoint or not secondEndpoint then
            return tostring(firstRouteId) < tostring(secondRouteId)
        end

        if magnetKind == "start" then
            if math.abs(firstEndpoint.x - secondEndpoint.x) > 1 then
                return firstEndpoint.x < secondEndpoint.x
            end
            if math.abs(firstEndpoint.y - secondEndpoint.y) > 1 then
                return firstEndpoint.y < secondEndpoint.y
            end
        else
            if math.abs(firstEndpoint.y - secondEndpoint.y) > 1 then
                return firstEndpoint.y < secondEndpoint.y
            end
            if math.abs(firstEndpoint.x - secondEndpoint.x) > 1 then
                return firstEndpoint.x < secondEndpoint.x
            end
        end

        return tostring(firstRouteId) < tostring(secondRouteId)
    end)
end

function mapEditor:rebuildIntersections()
    local previousIntersections = self.intersections or {}
    local grouped = {}

    for firstIndex = 1, #self.routes - 1 do
        local firstRoute = self.routes[firstIndex]
        for secondIndex = firstIndex + 1, #self.routes do
            local secondRoute = self.routes[secondIndex]
            for firstSegmentIndex = 1, #firstRoute.points - 1 do
                local a = firstRoute.points[firstSegmentIndex]
                local b = firstRoute.points[firstSegmentIndex + 1]
                for secondSegmentIndex = 1, #secondRoute.points - 1 do
                    local c = secondRoute.points[secondSegmentIndex]
                    local d = secondRoute.points[secondSegmentIndex + 1]
                    local hit = segmentIntersection(a, b, c, d)

                    if hit then
                        local groupX = math.floor(hit.x / 10 + 0.5) * 10
                        local groupY = math.floor(hit.y / 10 + 0.5) * 10
                        local groupKey = groupX .. ":" .. groupY
                        local entry = grouped[groupKey]

                        if not entry then
                            entry = {
                                x = hit.x,
                                y = hit.y,
                                routeIds = {},
                                routeLookup = {},
                            }
                            grouped[groupKey] = entry
                        else
                            entry.x = (entry.x + hit.x) * 0.5
                            entry.y = (entry.y + hit.y) * 0.5
                        end

                        if not entry.routeLookup[firstRoute.id] then
                            entry.routeLookup[firstRoute.id] = true
                            entry.routeIds[#entry.routeIds + 1] = firstRoute.id
                        end
                        if not entry.routeLookup[secondRoute.id] then
                            entry.routeLookup[secondRoute.id] = true
                            entry.routeIds[#entry.routeIds + 1] = secondRoute.id
                        end
                    end
                end
            end
        end
    end

    self.intersections = {}

    for _, groupedIntersection in pairs(grouped) do
        table.sort(groupedIntersection.routeIds)
        local routeKey = table.concat(groupedIntersection.routeIds, "|")
        local inputEndpointIds = {}
        local outputEndpointIds = {}
        local inputLookup = {}
        local outputLookup = {}
        local inputRouteIds = {}
        local outputRouteIds = {}

        for _, routeId in ipairs(groupedIntersection.routeIds) do
            local route = self:getRouteById(routeId)
            if route then
                inputRouteIds[#inputRouteIds + 1] = route.id
                outputRouteIds[#outputRouteIds + 1] = route.id
                if not inputLookup[route.startEndpointId] then
                    inputLookup[route.startEndpointId] = true
                    inputEndpointIds[#inputEndpointIds + 1] = route.startEndpointId
                end
                if not outputLookup[route.endEndpointId] then
                    outputLookup[route.endEndpointId] = true
                    outputEndpointIds[#outputEndpointIds + 1] = route.endEndpointId
                end
            end
        end

        self:sortEndpointIdsByPosition(inputEndpointIds, "input")
        self:sortEndpointIdsByPosition(outputEndpointIds, "output")
        self:sortRouteIdsByMagnet(inputRouteIds, "start")
        self:sortRouteIdsByMagnet(outputRouteIds, "end")

        local intersection = {
            id = "junction_" .. routeKey:gsub("[^%w]+", "_"),
            x = groupedIntersection.x,
            y = groupedIntersection.y,
            routeIds = groupedIntersection.routeIds,
            routeKey = routeKey,
            inputEndpointIds = inputEndpointIds,
            outputEndpointIds = outputEndpointIds,
            inputRouteIds = inputRouteIds,
            outputRouteIds = outputRouteIds,
            unsupported = #inputRouteIds > 5 or #outputEndpointIds > 5,
        }
        local state = self:getJunctionState(intersection, previousIntersections)
        intersection.controlType = self:getIntersectionControlType(intersection, previousIntersections)
        intersection.activeInputIndex = math.min((state and state.activeInputIndex) or 1, math.max(1, #inputRouteIds))
        intersection.activeOutputIndex = math.min((state and state.activeOutputIndex) or 1, math.max(1, #outputEndpointIds))
        self.intersections[#self.intersections + 1] = intersection
    end

    table.sort(self.intersections, function(a, b)
        if math.abs(a.y - b.y) > 1 then
            return a.y < b.y
        end
        return a.x < b.x
    end)
end

function mapEditor:beginRoute(x, y)
    local colorOption = COLOR_OPTIONS[((self.nextRouteId - 1) % #COLOR_OPTIONS) + 1]
    local startX, startY = self:clampPoint(x, y, true)
    local route = self:createRoute(
        {
            { x = startX, y = startY },
            { x = startX, y = startY + 24 },
        },
        colorOption.color,
        nil,
        nil,
        colorOption.id,
        { colorOption.id },
        { colorOption.id }
    )

    self.selectedRouteId = route.id
    self.selectedPointIndex = 2
    self.drag = {
        kind = "new_route",
        routeId = route.id,
        pointIndex = 2,
        startMouseX = x,
        startMouseY = y,
        moved = false,
        isMagnet = true,
        magnetKind = "end",
    }
    self:closeColorPicker()
    self:rebuildIntersections()
end

function mapEditor:updateDraggedPoint(x, y)
    if not self.drag then
        return
    end

    local route = self:getSelectedRoute()
    if not route then
        return
    end

    local point = route.points[self.drag.pointIndex]
    if not point then
        return
    end

    local movedDistance = distanceSquared(x, y, self.drag.startMouseX, self.drag.startMouseY)
    if movedDistance > 25 then
        self.drag.moved = true
    end

    if not self.drag.moved then
        return
    end

    local clampedX, clampedY = self:clampPoint(x, y, self.drag.pointIndex == 1)
    if self.drag.isMagnet then
        local endpoint = self.drag.magnetKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route)
        if endpoint then
            endpoint.x = clampedX
            endpoint.y = clampedY
            self:updateRoutesForEndpoint(endpoint.id)
        end
    else
        point.x = clampedX
        point.y = clampedY
    end
    self:closeColorPicker()
    self:rebuildIntersections()
end

function mapEditor:cycleIntersection(intersection)
    if intersection.unsupported then
        self:showStatus("Junctions currently support up to five inputs and five outputs.")
        return
    end

    local currentIndex = 1
    for controlIndex, controlType in ipairs(CONTROL_ORDER) do
        if controlType == intersection.controlType then
            currentIndex = controlIndex
            break
        end
    end

    local nextIndex = currentIndex + 1
    if nextIndex > #CONTROL_ORDER then
        nextIndex = 1
    end

    intersection.controlType = CONTROL_ORDER[nextIndex]
    self:showStatus("Intersection switched to " .. self:getControlName(intersection.controlType) .. ".")
end

function mapEditor:cycleIntersectionOutput(intersection, direction)
    if (intersection.outputEndpointIds and #intersection.outputEndpointIds or 0) <= 1 then
        return
    end

    local outputCount = #intersection.outputEndpointIds
    intersection.activeOutputIndex = intersection.activeOutputIndex + direction
    if intersection.activeOutputIndex < 1 then
        intersection.activeOutputIndex = outputCount
    elseif intersection.activeOutputIndex > outputCount then
        intersection.activeOutputIndex = 1
    end

    self:showStatus("Junction output switched to " .. intersection.activeOutputIndex .. ".")
end

function mapEditor:toggleMagnetColor(route, magnetKind, colorId)
    local endpoint = magnetKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route)
    if not endpoint then
        return
    end
    local lookup = endpoint.colors
    if lookup[colorId] then
        if countLookupEntries(lookup) <= 1 then
            self:showStatus("Each magnet needs at least one allowed color.")
            return
        end
        lookup[colorId] = nil
    else
        lookup[colorId] = true
    end

    self:showStatus((magnetKind == "start" and "Start" or "Exit") .. " magnet colors updated.")
end

function mapEditor:splitEndpointColor(route, magnetKind, colorId)
    local endpoint = magnetKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route)
    if not endpoint or not endpoint.colors[colorId] or countLookupEntries(endpoint.colors) <= 1 then
        self:showStatus("That color cannot be split from this magnet.")
        return
    end

    endpoint.colors[colorId] = nil
    local newEndpoint = self:createEndpoint(
        endpoint.kind,
        endpoint.x + (magnetKind == "start" and 38 or 48),
        endpoint.y + 18,
        { colorId }
    )

    if magnetKind == "start" then
        route.startEndpointId = newEndpoint.id
    else
        route.endEndpointId = newEndpoint.id
    end
    self:updateRouteEndpointPoint(route, magnetKind)
    self.selectedRouteId = route.id
    self.selectedPointIndex = magnetKind == "start" and 1 or #route.points
    self.drag = {
        kind = "point",
        routeId = route.id,
        pointIndex = self.selectedPointIndex,
        startMouseX = newEndpoint.x,
        startMouseY = newEndpoint.y,
        moved = true,
        isMagnet = true,
        magnetKind = magnetKind,
    }
    self:closeColorPicker()
    self:rebuildIntersections()
    self:showStatus("Color split into a new " .. endpoint.kind .. " magnet.")
end

function mapEditor:mergeEndpointInto(route, magnetKind, targetEndpoint)
    local currentEndpoint = magnetKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route)
    if not currentEndpoint or not targetEndpoint or currentEndpoint.id == targetEndpoint.id or currentEndpoint.kind ~= targetEndpoint.kind then
        return false
    end

    for colorId, enabled in pairs(currentEndpoint.colors or {}) do
        if enabled then
            targetEndpoint.colors[colorId] = true
        end
    end

    if magnetKind == "start" then
        route.startEndpointId = targetEndpoint.id
    else
        route.endEndpointId = targetEndpoint.id
    end
    self:updateRouteEndpointPoint(route, magnetKind)
    self:removeEndpointIfUnused(currentEndpoint.id)
    self:rebuildIntersections()
    self:showStatus(currentEndpoint.kind == "input" and "Inputs merged." or "Outputs merged.")
    return true
end

function mapEditor:handleColorPickerClick(x, y, button)
    local layout = self:getColorPickerLayout()
    if not layout then
        return false
    end

    if not pointInRect(x, y, layout.rect) then
        self:closeColorPicker()
        return false
    end

    local route = self:getSelectedRoute()
    if not route or route.id ~= self.colorPicker.routeId then
        self:closeColorPicker()
        return true
    end

    for _, swatch in ipairs(layout.swatches) do
        if pointInRect(x, y, swatch.rect) then
            if button == 2 then
                self:splitEndpointColor(route, self.colorPicker.magnetKind, swatch.option.id)
            else
                self:toggleMagnetColor(route, self.colorPicker.magnetKind, swatch.option.id)
            end
            return true
        end
    end

    return true
end

function mapEditor:handleDialogClick(x, y)
    if not self.dialog then
        return false
    end

    local rect = self:getDialogRect()
    if not pointInRect(x, y, rect) then
        self:closeDialog()
        return false
    end

    if self.dialog.type == "open" then
        for mapIndex, savedMap in ipairs(self.dialog.maps or {}) do
            local itemRect = {
                x = rect.x + 24,
                y = rect.y + 78 + (mapIndex - 1) * 54,
                w = rect.w - 48,
                h = 44,
            }
            if pointInRect(x, y, itemRect) then
                local loadedMap, loadError = mapStorage.loadMap(savedMap)
                if not loadedMap or not loadedMap.editor then
                    self:showStatus(loadError or "That map could not be opened.")
                else
                    self:resetFromMap(loadedMap, savedMap)
                end
                self:closeDialog()
                return true
            end
        end
    end

    return true
end

function mapEditor:copyToClipboard()
    love.system.setClipboardText(self:serialize())
    self:showStatus("Editor data copied to the clipboard.")
end

function mapEditor:keypressed(key)
    if key == "escape" then
        if self.dialog then
            self:closeDialog()
            self:showStatus("Dialog closed.")
            return true
        end
        return false
    end

    if self.dialog then
        if self.dialog.type == "save" then
            if key == "backspace" then
                if #self.dialog.input > 0 then
                    self.dialog.input = string.sub(self.dialog.input, 1, #self.dialog.input - 1)
                end
                return true
            end

            if key == "return" or key == "kpenter" then
                local ok, saveError = self:saveMap(self.dialog.input)
                if not ok then
                    self:showStatus(saveError)
                end
                return true
            end
        end

        return true
    end

    if key == "delete" or key == "backspace" then
        self:deleteSelection()
        return true
    end

    if key == "s" then
        self:openSaveDialog()
        return true
    end

    if key == "o" then
        self:openOpenDialog()
        return true
    end

    if key == "c" then
        self:copyToClipboard()
        return true
    end

    if key == "r" then
        self:resetFromMap(self.loadedMapPayload, self.sourceInfo)
        self:showStatus("Editor reset to the current map.")
        return true
    end

    return false
end

function mapEditor:textinput(text)
    if self.dialog and self.dialog.type == "save" then
        self.dialog.input = self.dialog.input .. text
    end
end

function mapEditor:mousepressed(x, y, button)
    if button ~= 1 and button ~= 2 then
        return false
    end

    if self.dialog and self:handleDialogClick(x, y) then
        return true
    end

    if self.colorPicker and self:handleColorPickerClick(x, y, button) then
        return true
    end

    if button == 2 then
        local hitIntersection = self:findIntersectionHit(x, y)
        if hitIntersection
            and #hitIntersection.outputEndpointIds > 1
            and distanceSquared(x, y, hitIntersection.x, hitIntersection.y + 36) <= 16 * 16 then
            self:cycleIntersectionOutput(hitIntersection, -1)
            return true
        end
        return false
    end

    if pointInRect(x, y, self:getSaveButtonRect()) then
        self:openSaveDialog()
        return true
    end

    if pointInRect(x, y, self:getOpenButtonRect()) then
        self:openOpenDialog()
        return true
    end

    if pointInRect(x, y, self:getCopyButtonRect()) then
        self:copyToClipboard()
        return true
    end

    if pointInRect(x, y, self:getResetButtonRect()) then
        self:resetFromMap(self.loadedMapPayload, self.sourceInfo)
        self:showStatus("Editor reset to the current map.")
        return true
    end

    local hitIntersection = self:findIntersectionHit(x, y)
    if hitIntersection then
        if #hitIntersection.outputEndpointIds > 1 and distanceSquared(x, y, hitIntersection.x, hitIntersection.y + 36) <= 16 * 16 then
            self:cycleIntersectionOutput(hitIntersection, 1)
        else
            self:cycleIntersection(hitIntersection)
        end
        return true
    end

    local route, pointIndex, magnetKind = self:findPointHit(x, y)
    if route then
        self.selectedRouteId = route.id
        self.selectedPointIndex = pointIndex
        self.drag = {
            kind = "point",
            routeId = route.id,
            pointIndex = pointIndex,
            startMouseX = x,
            startMouseY = y,
            moved = false,
            isMagnet = magnetKind ~= nil,
            magnetKind = magnetKind,
        }
        return true
    end

    local segmentHit = self:findSegmentHit(x, y)
    if segmentHit then
        table.insert(segmentHit.route.points, segmentHit.insertIndex, segmentHit.point)
        self.selectedRouteId = segmentHit.route.id
        self.selectedPointIndex = segmentHit.insertIndex
        self.drag = {
            kind = "point",
            routeId = segmentHit.route.id,
            pointIndex = segmentHit.insertIndex,
            startMouseX = x,
            startMouseY = y,
            moved = true,
            isMagnet = false,
            magnetKind = nil,
        }
        self:closeColorPicker()
        self:rebuildIntersections()
        self:showStatus("Bend point added.")
        return true
    end

    if self:isInSpawnBand(x, y) then
        self:beginRoute(x, y)
        return true
    end

    self:closeColorPicker()

    if pointInRect(x, y, self.canvas) or pointInRect(x, y, self.sidePanel) then
        self:clearSelection()
        return true
    end

    return false
end

function mapEditor:mousemoved(x, y)
    if not self.drag then
        return false
    end

    self:updateDraggedPoint(x, y)
    return true
end

function mapEditor:mousereleased(x, y, button)
    if button ~= 1 or not self.drag then
        return false
    end

    local route = self:getSelectedRoute()
    if self.drag.kind == "new_route" and route then
        local startPoint = route.points[1]
        local endPoint = route.points[#route.points]
        if distanceSquared(startPoint.x, startPoint.y, endPoint.x, endPoint.y) < 40 * 40 then
            for routeIndex, candidate in ipairs(self.routes) do
                if candidate.id == route.id then
                    table.remove(self.routes, routeIndex)
                    break
                end
            end
            self:clearSelection()
            self:showStatus("Route discarded because it was too short.")
        else
            self:showStatus("Route created. Drag any segment to add a bend point.")
        end
    elseif route and self.drag.kind == "point" and self.drag.isMagnet and not self.drag.moved then
        self:openColorPicker(route, self.drag.magnetKind)
        self:showStatus((self.drag.magnetKind == "start" and "Start" or "Exit") .. " magnet color picker opened.")
    elseif route and self.drag.kind == "point" and self.drag.isMagnet then
        local currentEndpoint = self.drag.magnetKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route)
        local target = currentEndpoint and self:findEndpointAt(x, y, currentEndpoint.kind, currentEndpoint.id) or nil
        if target then
            self:mergeEndpointInto(route, self.drag.magnetKind, target)
        end
    end

    self.drag = nil
    self:rebuildIntersections()
    return true
end

function mapEditor:serialize()
    local lines = {
        "return {",
        "    endpoints = {",
    }

    for _, endpoint in ipairs(self.endpoints) do
        lines[#lines + 1] = "        {"
        lines[#lines + 1] = string.format("            id = %q,", endpoint.id)
        lines[#lines + 1] = string.format("            kind = %q,", endpoint.kind)
        lines[#lines + 1] = string.format("            x = %s,", formatNumber(endpoint.x / self.viewport.w))
        lines[#lines + 1] = string.format("            y = %s,", formatNumber(endpoint.y / self.viewport.h))
        lines[#lines + 1] = "            colors = {"
        for _, colorId in ipairs(lookupToSortedIds(endpoint.colors)) do
            lines[#lines + 1] = string.format("                %q,", colorId)
        end
        lines[#lines + 1] = "            },"
        lines[#lines + 1] = "        },"
    end

    lines[#lines + 1] = "    },"
    lines[#lines + 1] = "    routes = {"

    for _, route in ipairs(self.routes) do
        lines[#lines + 1] = "        {"
        lines[#lines + 1] = string.format("            id = %q,", route.id)
        lines[#lines + 1] = string.format("            label = %q,", route.label or route.id)
        lines[#lines + 1] = string.format("            color = %q,", route.colorId)
        lines[#lines + 1] = string.format("            startEndpointId = %q,", route.startEndpointId)
        lines[#lines + 1] = string.format("            endEndpointId = %q,", route.endEndpointId)
        lines[#lines + 1] = "            points = {"
        for _, point in ipairs(route.points) do
            lines[#lines + 1] = string.format(
                "                { x = %s, y = %s },",
                formatNumber(point.x / self.viewport.w),
                formatNumber(point.y / self.viewport.h)
            )
        end
        lines[#lines + 1] = "            },"
        lines[#lines + 1] = "        },"
    end

    lines[#lines + 1] = "    },"
    lines[#lines + 1] = "    junctions = {"

    for _, intersection in ipairs(self.intersections) do
        lines[#lines + 1] = "        {"
        lines[#lines + 1] = string.format("            id = %q,", intersection.id)
        lines[#lines + 1] = string.format("            x = %s,", formatNumber(intersection.x / self.viewport.w))
        lines[#lines + 1] = string.format("            y = %s,", formatNumber(intersection.y / self.viewport.h))
        lines[#lines + 1] = string.format("            control = %q,", intersection.controlType)
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

function mapEditor:drawMagnet(route, point, magnetKind, selected)
    local graphics = love.graphics
    local endpoint = magnetKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route)
    local lookup = endpoint and endpoint.colors or {}
    local selectedColors = lookupToSortedIds(lookup)
    local width = magnetKind == "start" and 38 or 34
    local height = 24

    graphics.setColor(0.08, 0.1, 0.14, 1)
    graphics.rectangle("fill", point.x - width * 0.5 - 3, point.y - height * 0.5 - 3, width + 6, height + 6, 9, 9)
    graphics.setColor(route.color[1], route.color[2], route.color[3], 1)
    graphics.rectangle("fill", point.x - width * 0.5, point.y - height * 0.5, width, height, 9, 9)

    graphics.setColor(0.05, 0.06, 0.08, 1)
    graphics.printf(
        magnetKind == "start" and "IN" or "OUT",
        point.x - width * 0.5,
        point.y - 7,
        width,
        "center"
    )

    for index, colorId in ipairs(selectedColors) do
        local option = getColorOptionById(colorId)
        if option then
            local dotX = point.x - (#selectedColors - 1) * 6 + (index - 1) * 12
            local dotY = point.y + height * 0.5 + 9
            graphics.setColor(0.08, 0.1, 0.14, 1)
            graphics.circle("fill", dotX, dotY, 5)
            graphics.setColor(option.color[1], option.color[2], option.color[3], 1)
            graphics.circle("fill", dotX, dotY, 3.5)
        end
    end

    if selected then
        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.setLineWidth(2)
        graphics.rectangle("line", point.x - width * 0.5 - 8, point.y - height * 0.5 - 8, width + 16, height + 16, 12, 12)
    end
end

function mapEditor:drawRoute(route, selectedRouteId)
    local graphics = love.graphics
    local points = {}

    for _, point in ipairs(route.points) do
        points[#points + 1] = point.x
        points[#points + 1] = point.y
    end

    graphics.setLineStyle("smooth")
    graphics.setLineJoin("bevel")
    graphics.setColor(0.11, 0.14, 0.18, 1)
    graphics.setLineWidth(selectedRouteId == route.id and 16 or 13)
    graphics.line(points)

    graphics.setColor(route.color[1], route.color[2], route.color[3], selectedRouteId == route.id and 1 or 0.86)
    graphics.setLineWidth(selectedRouteId == route.id and 8 or 6)
    graphics.line(points)

    for pointIndex, point in ipairs(route.points) do
        local selected = selectedRouteId == route.id and pointIndex == self.selectedPointIndex
        if pointIndex == 1 then
            self:drawMagnet(route, point, "start", selected)
        elseif pointIndex == #route.points then
            self:drawMagnet(route, point, "end", selected)
        else
            graphics.setColor(0.08, 0.1, 0.14, 1)
            graphics.circle("fill", point.x, point.y, 11)
            graphics.setColor(route.color[1], route.color[2], route.color[3], 1)
            graphics.circle("fill", point.x, point.y, 8)
            if selected then
                graphics.setColor(0.97, 0.98, 1, 1)
                graphics.setLineWidth(2)
                graphics.circle("line", point.x, point.y, 16)
            end
        end
    end
end

function mapEditor:drawIntersection(intersection)
    local graphics = love.graphics
    local radius = intersection.unsupported and 14 or 18

    if intersection.unsupported then
        graphics.setColor(0.78, 0.22, 0.18, 0.95)
        graphics.circle("fill", intersection.x, intersection.y, radius)
        graphics.setColor(0.98, 0.96, 0.96, 1)
        graphics.setLineWidth(3)
        graphics.line(intersection.x - 7, intersection.y - 7, intersection.x + 7, intersection.y + 7)
        graphics.line(intersection.x - 7, intersection.y + 7, intersection.x + 7, intersection.y - 7)
        return
    end

    local fillColor = {
        direct = { 0.34, 0.84, 0.98 },
        delayed = { 0.99, 0.78, 0.32 },
        pump = { 0.93, 0.22, 0.84 },
    }
    local color = fillColor[intersection.controlType] or fillColor.direct

    graphics.setColor(0.08, 0.1, 0.13, 1)
    graphics.circle("fill", intersection.x, intersection.y, radius + 6)
    graphics.setColor(color[1], color[2], color[3], 1)
    graphics.circle("fill", intersection.x, intersection.y, radius)

    graphics.setColor(0.05, 0.06, 0.08, 1)
    graphics.printf(
        self:getControlLabel(intersection.controlType),
        intersection.x - radius,
        intersection.y - 8,
        radius * 2,
        "center"
    )

    if #intersection.outputEndpointIds > 1 then
        local selectorY = intersection.y + 36
        graphics.setColor(0.08, 0.1, 0.13, 1)
        graphics.circle("fill", intersection.x, selectorY, 15)
        graphics.setColor(0.99, 0.78, 0.32, 1)
        graphics.circle("line", intersection.x, selectorY, 15)
        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.printf(
            tostring(intersection.activeOutputIndex or 1),
            intersection.x - 14,
            selectorY - 7,
            28,
            "center"
        )
    end
end

function mapEditor:drawPanelButton(rect, label, accentColor)
    local graphics = love.graphics
    graphics.setColor(0.1, 0.12, 0.16, 0.96)
    graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 12, 12)
    graphics.setColor(accentColor[1], accentColor[2], accentColor[3], 1)
    graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 12, 12)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf(label, rect.x, rect.y + 11, rect.w, "center")
end

function mapEditor:drawColorPicker(game)
    local layout = self:getColorPickerLayout()
    if not layout then
        return
    end

    local route = self:getSelectedRoute()
    if not route or route.id ~= self.colorPicker.routeId then
        return
    end

    local graphics = love.graphics
    local endpoint = self.colorPicker.magnetKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route)
    local lookup = endpoint and endpoint.colors or {}

    graphics.setColor(0.08, 0.1, 0.14, 0.98)
    graphics.rectangle("fill", layout.rect.x, layout.rect.y, layout.rect.w, layout.rect.h, 16, 16)
    graphics.setColor(0.24, 0.32, 0.4, 1)
    graphics.rectangle("line", layout.rect.x, layout.rect.y, layout.rect.w, layout.rect.h, 16, 16)

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf(
        self.colorPicker.magnetKind == "start" and "Allowed Start Colors" or "Allowed Exit Colors",
        layout.rect.x + 14,
        layout.rect.y + 14,
        layout.rect.w - 28,
        "center"
    )

    for _, swatch in ipairs(layout.swatches) do
        local rect = swatch.rect
        local option = swatch.option
        local selected = lookup[option.id]

        graphics.setColor(0.05, 0.06, 0.08, 1)
        graphics.rectangle("fill", rect.x - 3, rect.y - 3, rect.w + 6, rect.h + 6, 10, 10)
        graphics.setColor(option.color[1], option.color[2], option.color[3], 1)
        graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)

        if selected then
            graphics.setColor(0.97, 0.98, 1, 1)
            graphics.setLineWidth(3)
            graphics.rectangle("line", rect.x - 3, rect.y - 3, rect.w + 6, rect.h + 6, 10, 10)
        end

        graphics.setColor(0.84, 0.88, 0.92, 1)
        graphics.printf(option.label, rect.x - 14, rect.y + rect.h + 6, rect.w + 28, "center")
    end
end

function mapEditor:drawDialog(game)
    if not self.dialog then
        return
    end

    local graphics = love.graphics
    local rect = self:getDialogRect()

    graphics.setColor(0, 0, 0, 0.48)
    graphics.rectangle("fill", 0, 0, self.viewport.w, self.viewport.h)

    graphics.setColor(0.09, 0.11, 0.15, 0.98)
    graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 18, 18)
    graphics.setColor(0.24, 0.32, 0.4, 1)
    graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 18, 18)

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)

    if self.dialog.type == "save" then
        graphics.printf("Save Map", rect.x, rect.y + 20, rect.w, "center")
        love.graphics.setFont(game.fonts.body)
        graphics.setColor(0.84, 0.88, 0.92, 1)
        graphics.printf("Give this map a name and press Enter to save it.", rect.x + 24, rect.y + 88, rect.w - 48, "center")
        graphics.setColor(0.05, 0.06, 0.08, 1)
        graphics.rectangle("fill", rect.x + 34, rect.y + 150, rect.w - 68, 52, 14, 14)
        graphics.setColor(0.48, 0.92, 0.62, 1)
        graphics.rectangle("line", rect.x + 34, rect.y + 150, rect.w - 68, 52, 14, 14)
        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.printf(self.dialog.input ~= "" and self.dialog.input or "Type a map name...", rect.x + 48, rect.y + 166, rect.w - 96, "left")
        love.graphics.setFont(game.fonts.small)
        graphics.setColor(0.72, 0.78, 0.84, 1)
        graphics.printf("Esc closes this dialog. S opens save. O opens load.", rect.x + 24, rect.y + 236, rect.w - 48, "center")
        return
    end

    graphics.printf("Open Map", rect.x, rect.y + 20, rect.w, "center")
    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.84, 0.88, 0.92, 1)
    if #(self.dialog.maps or {}) == 0 then
        graphics.printf("No maps were found yet.", rect.x + 24, rect.y + 142, rect.w - 48, "center")
        return
    end

    for mapIndex, savedMap in ipairs(self.dialog.maps or {}) do
        local itemRect = {
            x = rect.x + 24,
            y = rect.y + 78 + (mapIndex - 1) * 54,
            w = rect.w - 48,
            h = 44,
        }
        graphics.setColor(0.05, 0.06, 0.08, 1)
        graphics.rectangle("fill", itemRect.x, itemRect.y, itemRect.w, itemRect.h, 12, 12)
        graphics.setColor(0.3, 0.36, 0.42, 1)
        graphics.rectangle("line", itemRect.x, itemRect.y, itemRect.w, itemRect.h, 12, 12)
        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.print(savedMap.name, itemRect.x + 14, itemRect.y + 12)
        graphics.setColor(0.72, 0.78, 0.84, 1)
        graphics.print(savedMap.source == "builtin" and "Tutorial" or "User Save", itemRect.x + itemRect.w - 110, itemRect.y + 12)
    end
end

function mapEditor:draw(game)
    local graphics = love.graphics

    graphics.setColor(0.05, 0.07, 0.09, 1)
    graphics.rectangle("fill", 0, 0, self.viewport.w, self.viewport.h)

    graphics.setColor(0.07, 0.09, 0.12, 1)
    graphics.rectangle("fill", self.canvas.x, self.canvas.y, self.canvas.w, self.canvas.h, 18, 18)

    graphics.setColor(0.1, 0.14, 0.18, 0.96)
    graphics.rectangle("fill", self.canvas.x, self.canvas.y, self.canvas.w, self.spawnBandHeight, 18, 18)

    graphics.setColor(0.25, 0.34, 0.42, 1)
    graphics.setLineWidth(2)
    graphics.rectangle("line", self.canvas.x, self.canvas.y, self.canvas.w, self.canvas.h, 18, 18)

    graphics.setColor(0.16, 0.2, 0.24, 1)
    graphics.line(
        self.canvas.x + 16,
        self.canvas.y + self.spawnBandHeight,
        self.canvas.x + self.canvas.w - 16,
        self.canvas.y + self.spawnBandHeight
    )

    for _, route in ipairs(self.routes) do
        self:drawRoute(route, self.selectedRouteId)
    end

    for _, intersection in ipairs(self.intersections) do
        self:drawIntersection(intersection)
    end

    self:drawColorPicker(game)

    graphics.setColor(0.09, 0.11, 0.15, 0.98)
    graphics.rectangle("fill", self.sidePanel.x, self.sidePanel.y, self.sidePanel.w, self.sidePanel.h, 18, 18)
    graphics.setColor(0.22, 0.28, 0.34, 1)
    graphics.rectangle("line", self.sidePanel.x, self.sidePanel.y, self.sidePanel.w, self.sidePanel.h, 18, 18)

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.print("Map Editor", self.sidePanel.x + 18, self.sidePanel.y + 20)

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.48, 0.92, 0.62, 1)
    graphics.printf("Esc returns to the main menu", self.sidePanel.x + 18, self.sidePanel.y + 64, self.sidePanel.w - 36)

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.84, 0.88, 0.92, 1)
    graphics.printf("Click the top band to create a new route. Release to place its endpoint.", self.sidePanel.x + 18, self.sidePanel.y + 110, self.sidePanel.w - 36)
    graphics.printf("Drag any segment to create a bend point. Drag existing points to reshape the route.", self.sidePanel.x + 18, self.sidePanel.y + 182, self.sidePanel.w - 36)
    graphics.printf("Click an IN or OUT magnet to open its color grid. Right-click a color there to split it into a new magnet.", self.sidePanel.x + 18, self.sidePanel.y + 254, self.sidePanel.w - 36)
    graphics.printf("Click a lever at an intersection to cycle inputs. Click the bottom selector to cycle outputs, or right-click it to go backwards.", self.sidePanel.x + 18, self.sidePanel.y + 340, self.sidePanel.w - 36)
    graphics.printf("Playable saves support up to five input tracks and five output tracks per junction.", self.sidePanel.x + 18, self.sidePanel.y + 426, self.sidePanel.w - 36)

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.68, 0.74, 0.8, 1)
    graphics.printf(
        string.format("Routes: %d\nIntersections: %d", #self.routes, #self.intersections),
        self.sidePanel.x + 18,
        self.sidePanel.y + 462,
        self.sidePanel.w - 36
    )

    local selectedRoute = self:getSelectedRoute()
    if selectedRoute then
        local startEndpoint = self:getRouteStartEndpoint(selectedRoute)
        local endEndpoint = self:getRouteEndEndpoint(selectedRoute)
        local startColors = table.concat(lookupToSortedIds(startEndpoint and startEndpoint.colors or {}), ", ")
        local endColors = table.concat(lookupToSortedIds(endEndpoint and endEndpoint.colors or {}), ", ")
        graphics.setColor(selectedRoute.color[1], selectedRoute.color[2], selectedRoute.color[3], 1)
        graphics.printf(
            "Selected route: " .. (selectedRoute.label or selectedRoute.id),
            self.sidePanel.x + 18,
            self.sidePanel.y + 520,
            self.sidePanel.w - 36
        )
        graphics.setColor(0.84, 0.88, 0.92, 1)
        graphics.printf(
            "Start magnet: " .. startColors .. "\nExit magnet: " .. endColors,
            self.sidePanel.x + 18,
            self.sidePanel.y + 546,
            self.sidePanel.w - 36
        )
    end

    if self.statusText then
        graphics.setColor(0.48, 0.92, 0.62, 1)
        graphics.printf(self.statusText, self.sidePanel.x + 18, self.sidePanel.y + 610, self.sidePanel.w - 36)
    end

    self:drawPanelButton(self:getSaveButtonRect(), "Save Map (S)", { 0.48, 0.92, 0.62 })
    self:drawPanelButton(self:getOpenButtonRect(), "Open Map (O)", { 0.33, 0.8, 0.98 })
    self:drawPanelButton(self:getCopyButtonRect(), "Copy Export (C)", { 0.48, 0.92, 0.62 })
    self:drawPanelButton(self:getResetButtonRect(), "Reset To Map (R)", { 0.99, 0.78, 0.32 })

    graphics.setColor(0.7, 0.76, 0.82, 1)
    local sourceLabel
    if self.sourceInfo and self.sourceInfo.source == "builtin" then
        sourceLabel = "Current source: Tutorial Template - " .. (self.currentMapName or "Untitled")
    elseif self.sourceInfo and self.sourceInfo.source == "user" then
        sourceLabel = "Current source: Saved Map - " .. (self.currentMapName or "Untitled")
    else
        sourceLabel = "Current source: " .. (self.currentMapName or (self.level and self.level.title) or "Blank")
    end
    graphics.printf(sourceLabel, self.canvas.x + 18, self.canvas.y + 16, self.canvas.w - 36)
    graphics.printf(
        "Create starts from the top edge. Imported maps are editable immediately.",
        self.canvas.x + 18,
        self.canvas.y + self.spawnBandHeight - 24,
        self.canvas.w - 36
    )

    self:drawDialog(game)
end

return mapEditor
