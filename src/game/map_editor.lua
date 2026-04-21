local mapStorage = require("src.game.map_storage")
local authoredMap = require("src.game.authored_map")
local json = require("src.game.json")
local roadTypes = require("src.game.road_types")
local uuid = require("src.game.uuid")
local world = require("src.game.world")
local trackSceneRenderer = require("src.game.track_scene_renderer")
local uiControls = require("src.game.ui_controls")

local mapEditor = {}
mapEditor.__index = mapEditor

local DEFAULT_CONTROL = "direct"
local MAX_TRIP_PASS_COUNT = 5
local MERGE_SNAP_RADIUS = 40
local INTERSECTION_GROUP_BUCKET = 20
-- Keep this tight so nearby steep crossings do not collapse into one junction.
-- True multi-route junction hits still land within the point match tolerance.
local STRICT_INTERSECTION_CLUSTER_RADIUS = 3
local SHARED_LANE_STRIPE_LENGTH = 14
local CONTROL_ORDER = { "direct", "delayed", "pump", "spring", "relay", "trip", "crossbar" }
local DEFAULT_TRAIN_WAGONS = 4
local LEGACY_TRAIN_SPEED = 168
local DEFAULT_ROAD_TYPE = roadTypes.DEFAULT_ID
local LEGACY_MAP_WIDTH = 1280
local LEGACY_MAP_HEIGHT = 720
local DEFAULT_NEW_MAP_WIDTH = 1920
local DEFAULT_NEW_MAP_HEIGHT = 1080
local MAP_SIZE_PRESETS = {
    { id = "1x", label = "1x", w = 1280, h = 720 },
    { id = "2x", label = "2x", w = 1920, h = 1080 },
    { id = "3x", label = "3x", w = 2560, h = 1440 },
    { id = "4x", label = "4x", w = 3840, h = 2160 },
}
local DEFAULT_GRID_STEP = 64
local MIN_GRID_STEP = 16
local MAX_GRID_STEP = 256
local CAMERA_PADDING = 36
local CAMERA_MIN_ZOOM = 0.2
local CAMERA_MAX_ZOOM = 3.5
local PANEL_OVERLAY_MARGIN = 18
local GRID_MINOR_ALPHA = 0.16
local GRID_MAJOR_ALPHA = 0.3
local ROAD_TYPE_OPTIONS = roadTypes.getOrderedOptions()
local VALIDATION_CHILD_INDENT = 20
local PANEL_BUTTON_SIDE_MARGIN = 18
local PANEL_BUTTON_HEIGHT = 38
local PANEL_BUTTON_GAP = 12
local PANEL_BUTTON_BOTTOM_MARGIN = 22
local STATUS_TOAST_MARGIN = 18
local STATUS_TOAST_FADE_TIME = 0.35
local POINT_HIT_RADIUS = 12
local INTERSECTION_HIT_RADIUS = 22
local INTERSECTION_UNSUPPORTED_HIT_RADIUS = 18
local SEGMENT_HIT_RADIUS = 16
local SEGMENT_HIT_MIN_T = 0.08
local SEGMENT_HIT_MAX_T = 0.92
local HITBOX_OVERLAY_FILL_ALPHA = 0.18
local HITBOX_OVERLAY_OUTLINE_ALPHA = 0.94
local HITBOX_OVERLAY_LABEL_BACKGROUND_ALPHA = 0.92
local HITBOX_OVERLAY_LABEL_TEXT_ALPHA = 0.98
local HITBOX_OVERLAY_LABEL_OFFSET_Y = 22
local HITBOX_OVERLAY_LABEL_PADDING_X = 6
local HITBOX_OVERLAY_LABEL_PADDING_Y = 4
local HITBOX_OVERLAY_LABEL_CORNER_RADIUS = 6
local HITBOX_OVERLAY_RECT_CORNER_RADIUS = 6
local HITBOX_OVERLAY_STROKE_WIDTH = 2
local HITBOX_OVERLAY_EPSILON = 0.0001
local DRAG_START_DISTANCE_SQUARED = 25
local INTERSECTION_SELECTOR_OFFSET_Y = 36
local INTERSECTION_SELECTOR_CLICK_RADIUS = 16
local INTERSECTION_SELECTOR_DRAW_RADIUS = 15
local INTERSECTION_POINT_TOLERANCE_SQUARED = 9
local INTERNAL_POINT_MATCH_DISTANCE_SQUARED = 1
local INTERSECTION_SHARED_POINT_DISTANCE_SQUARED = 12 * 12
local INTERSECTION_STATE_MATCH_DISTANCE_SQUARED = 24 * 24
local JUNCTION_MENU_SIZE_MULTIPLIER = 1.5
local JUNCTION_MENU_POP_DURATION = 0.14
local JUNCTION_MENU_ROOT_RADIUS = 36 * JUNCTION_MENU_SIZE_MULTIPLIER
local JUNCTION_MENU_RING_INNER_RADIUS = 22 * JUNCTION_MENU_SIZE_MULTIPLIER
local JUNCTION_MENU_COLOR_OUTER_RADIUS = 56 * JUNCTION_MENU_SIZE_MULTIPLIER
local JUNCTION_MENU_TYPE_OUTER_RADIUS = 72 * JUNCTION_MENU_SIZE_MULTIPLIER
local JUNCTION_MENU_BRANCH_RATIO = 0.35
local JUNCTION_MENU_ICON_SIZE = 15 * JUNCTION_MENU_SIZE_MULTIPLIER
local JUNCTION_MENU_TYPE_ICON_SIZE = 18 * JUNCTION_MENU_SIZE_MULTIPLIER
local JUNCTION_MENU_SWATCH_RADIUS = 8 * JUNCTION_MENU_SIZE_MULTIPLIER
local JUNCTION_MENU_EDGE_MARGIN = 8 * JUNCTION_MENU_SIZE_MULTIPLIER
local EMPTY_MAP_VALIDATION_TEXT = "Draw at least one route before starting this map."
local UPLOAD_UNAVAILABLE_MESSAGE = "Uploading is currently not possible."
local ROAD_PATTERN_OUTLINE = { 0.04, 0.05, 0.07, 0.98 }
local ROAD_PATTERN_FILL = { 0.97, 0.98, 1.0, 0.94 }
local CONTROL_LABELS = {
    direct = "D",
    delayed = "T",
    pump = "P",
    spring = "S",
    relay = "R",
    trip = "1X",
    crossbar = "X",
}
local CONTROL_NAMES = {
    direct = "Direct Lever",
    delayed = "Delayed Button",
    pump = "Charge Lever",
    spring = "Spring Switch",
    relay = "Relay Dial",
    trip = "Trip Switch",
    crossbar = "Crossbar Dial",
}
local CONTROL_FILL_COLORS = {
    direct = { 0.34, 0.84, 0.98 },
    delayed = { 0.99, 0.78, 0.32 },
    pump = { 0.93, 0.22, 0.84 },
    spring = { 0.4, 0.96, 0.74 },
    relay = { 0.56, 0.72, 0.98 },
    trip = { 0.98, 0.6, 0.28 },
    crossbar = { 0.92, 0.38, 0.68 },
}
local COLOR_OPTIONS = {
    { id = "blue", label = "Blue", color = { 0.33, 0.8, 0.98 } },
    { id = "yellow", label = "Yellow", color = { 0.98, 0.82, 0.34 } },
    { id = "mint", label = "Mint", color = { 0.4, 0.92, 0.76 } },
    { id = "rose", label = "Rose", color = { 0.98, 0.48, 0.62 } },
    { id = "orange", label = "Orange", color = { 0.98, 0.7, 0.28 } },
    { id = "violet", label = "Violet", color = { 0.82, 0.56, 0.98 } },
}
local SAO_CAST = {
    "Kirito",
    "Asuna",
    "Klein",
    "Agil",
    "Silica",
    "Lisbeth",
    "Sinon",
    "Leafa",
    "Yuuki",
    "Alice",
    "Eugeo",
    "Yui",
    "Sachi",
    "Argo",
    "Heathcliff",
    "Bercouli",
    "Fanatio",
    "Tiese",
    "Ronie",
    "Liena",
    "Selka",
    "Suguha",
    "Keiko",
    "Shino",
    "Andrew",
    "Rinko",
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
    spring = {
        label = "Spring Switch",
        holdTime = 1.6,
    },
    relay = {
        label = "Relay Dial",
    },
    trip = {
        label = "Trip Switch",
        passCount = 1,
    },
    crossbar = {
        label = "Crossbar Dial",
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

local function loadOptionalImage(path)
    if not (love and love.graphics and love.filesystem and love.filesystem.getInfo(path, "file")) then
        return nil
    end

    local ok, image = pcall(love.graphics.newImage, path)
    if ok and image then
        image:setFilter("linear", "linear")
        return image
    end

    return nil
end

local function encodeUrlPath(path)
    return tostring(path or ""):gsub("\\", "/"):gsub("([^%w%-%._~/:])", function(character)
        return string.format("%%%02X", string.byte(character))
    end)
end

local function buildFileUrl(path)
    local normalizedPath = tostring(path or ""):gsub("\\", "/")
    if normalizedPath:match("^[A-Za-z]:") then
        normalizedPath = "/" .. normalizedPath
    end
    return "file://" .. encodeUrlPath(normalizedPath)
end

local function distanceSquared(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by
    return dx * dx + dy * dy
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function copyPoint(point)
    return {
        x = point.x,
        y = point.y,
        sharedPointId = point.sharedPointId,
    }
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

local function buildRouteKey(routeIds)
    local sortedIds = {}

    for _, routeId in ipairs(routeIds or {}) do
        sortedIds[#sortedIds + 1] = routeId
    end

    table.sort(sortedIds)
    return table.concat(sortedIds, "|"), sortedIds
end

local function buildBlankEditorData()
    return {
        mapSize = {
            w = DEFAULT_NEW_MAP_WIDTH,
            h = DEFAULT_NEW_MAP_HEIGHT,
        },
        timeLimit = nil,
        endpoints = {},
        routes = {},
        junctions = {},
        trains = {},
    }
end

local function isLocalSavedMapDescriptor(descriptor)
    return descriptor ~= nil
        and descriptor.source == "user"
        and descriptor.isRemoteImport ~= true
        and descriptor.hasLevel == true
end

local function segmentLength(a, b)
    local dx = b.x - a.x
    local dy = b.y - a.y
    return math.sqrt(dx * dx + dy * dy)
end

local function angleBetweenPoints(a, b)
    local dx = b.x - a.x
    local dy = b.y - a.y

    if math.atan2 then
        return math.atan2(dy, dx)
    end

    if dx == 0 then
        if dy >= 0 then
            return math.pi * 0.5
        end
        return -math.pi * 0.5
    end

    local angle = math.atan(dy / dx)
    if dx < 0 then
        angle = angle + math.pi
    end
    return angle
end

local function angleBetweenCoordinates(centerX, centerY, x, y)
    if math.atan2 then
        return math.atan2(y - centerY, x - centerX)
    end

    return angleBetweenPoints({ x = centerX, y = centerY }, { x = x, y = y })
end

local function normalizeAngle(angle)
    local fullTurn = math.pi * 2
    local normalized = angle % fullTurn
    if normalized < 0 then
        normalized = normalized + fullTurn
    end
    return normalized
end

local function buildDefaultSegmentRoadTypes(pointCount, fallbackRoadType)
    local segmentRoadTypes = {}
    local normalizedRoadType = roadTypes.normalizeRoadType(fallbackRoadType)
    local segmentCount = math.max(0, (pointCount or 0) - 1)

    for segmentIndex = 1, segmentCount do
        segmentRoadTypes[segmentIndex] = normalizedRoadType
    end

    return segmentRoadTypes
end

local function formatNumber(value)
    return string.format("%.4f", value)
end

local function clampRectValue(value, minValue, maxValue)
    if minValue > maxValue then
        return (minValue + maxValue) * 0.5
    end
    return clamp(value, minValue, maxValue)
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

local function normalizeEndpointColors(kind, source, fallbackId)
    local lookup = colorsToLookup(source, fallbackId)
    if kind ~= "input" then
        return lookup
    end

    local orderedIds = lookupToSortedIds(lookup)
    local resolvedId = orderedIds[1] or fallbackId
    local normalizedLookup = {}
    if resolvedId then
        normalizedLookup[resolvedId] = true
    end
    return normalizedLookup
end

local function getEndpointColorIds(endpoint)
    if not endpoint then
        return {}
    end

    local orderedIds = lookupToSortedIds(endpoint.colors)
    if endpoint.kind == "input" then
        return orderedIds[1] and { orderedIds[1] } or {}
    end

    return orderedIds
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

local function getColorOrderIndex(colorId)
    for index, option in ipairs(COLOR_OPTIONS) do
        if option.id == colorId then
            return index
        end
    end
    return #COLOR_OPTIONS + 1
end

local function roundStep(value, step)
    local divisor = step or 1
    return math.floor((value / divisor) + 0.5) * divisor
end

local function copyArray(source)
    local copy = {}
    for _, value in ipairs(source or {}) do
        copy[#copy + 1] = value
    end
    return copy
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

local function chooseBestCandidatePoint(candidates)
    local bestCandidate = nil
    local bestScore = nil

    for _, candidate in ipairs(candidates or {}) do
        local score = candidate.distanceScore or math.huge
        if not bestScore or score < bestScore then
            bestCandidate = candidate
            bestScore = score
        end
    end

    return bestCandidate
end

local function roundPointKey(point)
    return string.format("%.2f:%.2f", point.x, point.y)
end

local function buildSegmentGroupKey(a, b)
    local firstKey = roundPointKey(a)
    local secondKey = roundPointKey(b)
    if firstKey < secondKey then
        return firstKey .. "|" .. secondKey
    end
    return secondKey .. "|" .. firstKey
end

local function buildIntersectionId(routeKey, point)
    local safeRouteKey = tostring(routeKey or "junction"):gsub("[^%w]+", "_")
    local pointKey = roundPointKey(point or { x = 0, y = 0 }):gsub("[^%w]+", "_")
    return string.format("junction_%s_%s", safeRouteKey, pointKey)
end

local function getWrappedLineCount(font, text, width)
    local firstValue, secondValue = font:getWrap(text, width)
    if type(firstValue) == "table" then
        return math.max(1, #firstValue)
    end
    if type(secondValue) == "table" then
        return math.max(1, #secondValue)
    end
    return 1
end

local function sanitizeMapSize(mapSize, fallbackW, fallbackH)
    local fallbackWidth = fallbackW or LEGACY_MAP_WIDTH
    local fallbackHeight = fallbackH or LEGACY_MAP_HEIGHT
    local width = math.max(320, math.floor(tonumber(mapSize and mapSize.w) or fallbackWidth))
    local height = math.max(180, math.floor(tonumber(mapSize and mapSize.h) or fallbackHeight))
    local normalizedHeight = math.max(180, math.floor(width * 9 / 16 + 0.5))

    if math.abs(height - normalizedHeight) > 1 then
        height = normalizedHeight
    end

    return {
        w = width,
        h = height,
    }
end

local function sanitizeGridStep(value)
    local numericValue = math.floor(tonumber(value) or DEFAULT_GRID_STEP)
    return clamp(numericValue, MIN_GRID_STEP, MAX_GRID_STEP)
end
local function getValidationEntryMessage(entry)
    if type(entry) == "table" then
        return tostring(entry.message or "")
    end
    return tostring(entry or "")
end

local function getColorLabel(colorId)
    local option = getColorOptionById(colorId)
    if option then
        return option.label
    end

    local text = tostring(colorId or "Unknown")
    return (text:gsub("^%l", string.upper))
end

local function buildTrainValidationLabel(trainInfo, diagnostic)
    local lineColorLabel = getColorLabel(trainInfo and trainInfo.lineColor or diagnostic and diagnostic.lineColor)
    local trainColorLabel = getColorLabel(trainInfo and trainInfo.trainColor or diagnostic and diagnostic.trainColor)

    if trainInfo and trainInfo.castName then
        return string.format("%s (%s -> %s)", trainInfo.castName, lineColorLabel, trainColorLabel)
    end

    return string.format("Train (%s -> %s)", lineColorLabel, trainColorLabel)
end

local function getValidationColorDisplayMode(editor)
    return editor and editor.validationColorDisplayMode or "swatch"
end

local function getValidationColorSwatchSize(font)
    return math.max(8, math.floor(font:getHeight() * 0.75 + 0.5))
end

local function sanitizeColorAffix(text)
    if not text or text == "" then
        return ""
    end

    return (text:gsub("['\"`]", ""))
end

local function parseValidationColorWord(word)
    if not word or word == "" then
        return nil
    end

    local startIndex, endIndex = word:find("%a+")
    if not startIndex then
        return nil
    end

    local core = word:sub(startIndex, endIndex)
    local colorId = nil

    for _, option in ipairs(COLOR_OPTIONS) do
        if core:lower() == option.id or core:lower() == option.label:lower() then
            colorId = option.id
            break
        end
    end

    if not colorId then
        return nil
    end

    return {
        prefix = sanitizeColorAffix(word:sub(1, startIndex - 1)),
        colorId = colorId,
        suffix = sanitizeColorAffix(word:sub(endIndex + 1)),
    }
end

local function buildValidationWordParts(font, word, displayMode)
    local parts = {}
    local width = 0

    if displayMode == "swatch" then
        local colorWord = parseValidationColorWord(word)
        if colorWord then
            if colorWord.prefix ~= "" then
                parts[#parts + 1] = { type = "text", text = colorWord.prefix }
                width = width + font:getWidth(colorWord.prefix)
            end

            parts[#parts + 1] = { type = "swatch", colorId = colorWord.colorId }
            width = width + getValidationColorSwatchSize(font)

            if colorWord.suffix ~= "" then
                parts[#parts + 1] = { type = "text", text = colorWord.suffix }
                width = width + font:getWidth(colorWord.suffix)
            end

            return parts, width
        end
    end

    parts[1] = { type = "text", text = word }
    return parts, font:getWidth(word)
end

local function measureValidationMessage(font, text, width, displayMode)
    local maxWidth = math.max(20, width or 20)
    local spaceWidth = font:getWidth(" ")
    local lineWidth = 0
    local lineCount = 1

    for word in tostring(text or ""):gmatch("%S+") do
        local _, wordWidth = buildValidationWordParts(font, word, displayMode)
        local extraWidth = lineWidth > 0 and spaceWidth or 0

        if lineWidth > 0 and lineWidth + extraWidth + wordWidth > maxWidth then
            lineCount = lineCount + 1
            lineWidth = wordWidth
        else
            lineWidth = lineWidth + extraWidth + wordWidth
        end
    end

    return math.max(font:getHeight(), lineCount * font:getHeight())
end

local function drawValidationMessage(font, text, x, y, width, textColor, displayMode)
    local graphics = love.graphics
    local maxWidth = math.max(20, width or 20)
    local lineHeight = font:getHeight()
    local swatchSize = getValidationColorSwatchSize(font)
    local spaceWidth = font:getWidth(" ")
    local cursorX = x
    local cursorY = y

    for word in tostring(text or ""):gmatch("%S+") do
        local parts, wordWidth = buildValidationWordParts(font, word, displayMode)
        local extraWidth = cursorX > x and spaceWidth or 0

        if cursorX > x and cursorX + extraWidth + wordWidth > x + maxWidth then
            cursorX = x
            cursorY = cursorY + lineHeight
            extraWidth = 0
        end

        cursorX = cursorX + extraWidth

        for _, part in ipairs(parts) do
            if part.type == "swatch" then
                local option = getColorOptionById(part.colorId)
                local swatchY = cursorY + (lineHeight - swatchSize) * 0.5
                local swatchColor = option and option.color or getColorById(part.colorId)

                graphics.setColor(swatchColor[1], swatchColor[2], swatchColor[3], 1)
                graphics.rectangle("fill", cursorX, swatchY, swatchSize, swatchSize, 3, 3)
                graphics.setColor(0.97, 0.98, 1, 0.95)
                graphics.setLineWidth(1.2)
                graphics.rectangle("line", cursorX, swatchY, swatchSize, swatchSize, 3, 3)
                cursorX = cursorX + swatchSize
            else
                graphics.setColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
                graphics.print(part.text, cursorX, cursorY)
                cursorX = cursorX + font:getWidth(part.text)
            end
        end
    end

    graphics.setLineWidth(1)
end

function mapEditor.new(viewportW, viewportH, level, options)
    local self = setmetatable({}, mapEditor)
    local editorOptions = options or {}
    local editorPreferences = editorOptions.editorPreferences or {}

    self.viewport = { w = viewportW, h = viewportH }
    self.mapSize = sanitizeMapSize(nil, DEFAULT_NEW_MAP_WIDTH, DEFAULT_NEW_MAP_HEIGHT)
    self.endpoints = {}
    self.routes = {}
    self.nextEndpointId = 1
    self.nextRouteId = 1
    self.nextSharedPointId = 1
    self.selectedRouteId = nil
    self.selectedPointIndex = nil
    self.drag = nil
    self.colorPicker = nil
    self.routeTypePicker = nil
    self.dialog = nil
    self.currentMapName = nil
    self.editingMapUuid = nil
    self.sourceInfo = nil
    self.lastSavedDescriptor = nil
    self.pendingPlaytestDescriptor = nil
    self.pendingUploadDescriptor = nil
    self.pendingOpenBlankMap = false
    self.loadedMapPayload = nil
    self.savedStateSnapshotJson = nil
    self.savedMapUploadAvailable = false
    self.savedMapUploadPending = false
    self.lastValidationError = nil
    self.validationErrors = {}
    self.previewWorld = nil
    self.validationEntries = {}
    self.hoveredValidationIndex = nil
    self.statusText = nil
    self.statusTimer = 0
    self.intersections = {}
    self.importedJunctionState = {}
    self.trains = {}
    self.nextTrainId = 1
    self.timeLimit = nil
    self.sidePanelMode = "default"
    self.sequencerScroll = 0
    self.activeTextField = nil
    self.sequencerScrollDrag = nil
    self.camera = {
        x = self.mapSize.w * 0.5,
        y = self.mapSize.h * 0.5,
        zoom = 1,
    }
    self.panDrag = nil
    self.onPreferencesChanged = editorOptions.onPreferencesChanged
    self.gridVisible = editorPreferences.gridVisible ~= false
    self.gridStep = sanitizeGridStep(editorPreferences.gridStep)
    self.editorChargeImage = nil
    self.editorCrossImage = nil
    self.editorDirectImage = nil
    self.editorRelayImage = nil
    self.editorSpringImage = nil
    self.editorTripImage = nil
    self.editorJunctionIconsLoaded = false
    self.validationScroll = 0
    self.validationScrollDrag = nil
    self.validationColorDisplayMode = "swatch"
    self.hitboxOverlayVisible = false

    self:updateLayout()
    self:resetCameraToFit()
    self:resetFromMap(level and { level = level, name = level.title } or nil, nil)

    return self
end

function mapEditor:updateLayout()
    self.margin = PANEL_OVERLAY_MARGIN
    self.panelWidth = 320
    self.canvas = {
        x = 0,
        y = 0,
        w = self.mapSize.w,
        h = self.mapSize.h,
    }
    self.spawnBandHeight = 58
    self.spawnY = self.canvas.y + 22
    self.sidePanel = {
        x = self.viewport.w - self.panelWidth - self.margin,
        y = self.margin,
        w = self.panelWidth,
        h = self.viewport.h - self.margin * 2,
    }
end

function mapEditor:ensureEditorJunctionIcons()
    if self.editorJunctionIconsLoaded then
        return
    end

    self.editorJunctionIconsLoaded = true
    self.editorChargeImage = loadOptionalImage("assets/Charge.png")
    self.editorCrossImage = loadOptionalImage("assets/cross.png")
    self.editorDirectImage = loadOptionalImage("assets/direct.png")
    self.editorRelayImage = loadOptionalImage("assets/relay.png")
    self.editorSpringImage = loadOptionalImage("assets/spring.png")
    self.editorTripImage = loadOptionalImage("assets/trip.png")
end

function mapEditor:clearSelection()
    self.selectedRouteId = nil
    self.selectedPointIndex = nil
end

function mapEditor:notifyPreferencesChanged()
    if self.onPreferencesChanged then
        self.onPreferencesChanged({
            gridVisible = self.gridVisible ~= false,
            gridStep = sanitizeGridStep(self.gridStep),
        })
    end
end

function mapEditor:getCameraViewportRect()
    local width = self.sidePanel and (self.sidePanel.x - self.margin) or self.viewport.w
    return {
        x = 0,
        y = 0,
        w = math.max(1, width),
        h = self.viewport.h,
    }
end

function mapEditor:getCameraViewportCenter()
    local rect = self:getCameraViewportRect()
    return rect.x + rect.w * 0.5, rect.y + rect.h * 0.5
end

function mapEditor:getCameraViewHalfExtents(zoom)
    local resolvedZoom = zoom or self.camera.zoom or 1
    local rect = self:getCameraViewportRect()
    return rect.w * 0.5 / resolvedZoom, rect.h * 0.5 / resolvedZoom
end

function mapEditor:clampCamera()
    local halfW, halfH = self:getCameraViewHalfExtents()
    local minX = halfW
    local maxX = self.mapSize.w - halfW
    local minY = halfH
    local maxY = self.mapSize.h - halfH
    self.camera.x = clampRectValue(self.camera.x, minX, maxX)
    self.camera.y = clampRectValue(self.camera.y, minY, maxY)
end

function mapEditor:resetCameraToFit()
    local cameraViewport = self:getCameraViewportRect()
    local fitZoom = math.min(
        (cameraViewport.w - CAMERA_PADDING * 2) / math.max(1, self.mapSize.w),
        (cameraViewport.h - CAMERA_PADDING * 2) / math.max(1, self.mapSize.h)
    )

    self.camera.zoom = clamp(fitZoom, CAMERA_MIN_ZOOM, CAMERA_MAX_ZOOM)
    self.camera.x = self.mapSize.w * 0.5
    self.camera.y = self.mapSize.h * 0.5
    self:clampCamera()
end

function mapEditor:screenToMap(screenX, screenY)
    local centerX, centerY = self:getCameraViewportCenter()
    return (screenX - centerX) / self.camera.zoom + self.camera.x,
        (screenY - centerY) / self.camera.zoom + self.camera.y
end

function mapEditor:mapToScreen(mapX, mapY)
    local centerX, centerY = self:getCameraViewportCenter()
    return (mapX - self.camera.x) * self.camera.zoom + centerX,
        (mapY - self.camera.y) * self.camera.zoom + centerY
end

function mapEditor:isModifierSnapActive()
    return love.keyboard.isDown("lctrl", "rctrl")
end

function mapEditor:snapPointToGrid(x, y)
    local step = sanitizeGridStep(self.gridStep)
    return math.floor((x / step) + 0.5) * step,
        math.floor((y / step) + 0.5) * step
end

function mapEditor:zoomAroundScreenPoint(screenX, screenY, deltaY)
    if deltaY == 0 then
        return
    end

    local anchorMapX, anchorMapY = self:screenToMap(screenX, screenY)
    local zoomFactor = deltaY > 0 and 1.12 or (1 / 1.12)
    self.camera.zoom = clamp(self.camera.zoom * zoomFactor, CAMERA_MIN_ZOOM, CAMERA_MAX_ZOOM)
    local centerX, centerY = self:getCameraViewportCenter()

    self.camera.x = anchorMapX - ((screenX - centerX) / self.camera.zoom)
    self.camera.y = anchorMapY - ((screenY - centerY) / self.camera.zoom)
    self:clampCamera()
end

function mapEditor:generateTrainId()
    local trainId = "train_" .. self.nextTrainId
    self.nextTrainId = self.nextTrainId + 1
    return trainId
end

function mapEditor:createTrainDefinition(definition)
    local trainId = definition and definition.id or self:generateTrainId()
    local train = {
        id = trainId,
        lineColor = (definition and definition.lineColor) or COLOR_OPTIONS[1].id,
        trainColor = (definition and definition.trainColor) or ((definition and definition.lineColor) or COLOR_OPTIONS[1].id),
        spawnTime = math.max(0, roundStep((definition and definition.spawnTime) or 0, 0.5)),
        wagonCount = math.max(1, math.floor((definition and definition.wagonCount) or DEFAULT_TRAIN_WAGONS)),
        deadline = definition and definition.deadline or nil,
        collapsed = definition and definition.collapsed == true or false,
    }

    if definition and definition.deadline ~= nil then
        train.deadline = math.max(0, roundStep(definition.deadline, 0.5))
    end

    return train
end

function mapEditor:getSortedTrainEntries()
    local entries = {}

    for trainIndex, train in ipairs(self.trains) do
        entries[#entries + 1] = {
            train = train,
            trainIndex = trainIndex,
        }
    end

    table.sort(entries, function(a, b)
        if math.abs((a.train.spawnTime or 0) - (b.train.spawnTime or 0)) > 0.0001 then
            return (a.train.spawnTime or 0) < (b.train.spawnTime or 0)
        end
        local firstColorIndex = getColorOrderIndex(a.train.trainColor)
        local secondColorIndex = getColorOrderIndex(b.train.trainColor)
        if firstColorIndex ~= secondColorIndex then
            return firstColorIndex < secondColorIndex
        end
        return tostring(a.train.id) < tostring(b.train.id)
    end)

    for entryIndex, entry in ipairs(entries) do
        entry.castName = SAO_CAST[((entryIndex - 1) % #SAO_CAST) + 1]
    end

    return entries
end

function mapEditor:getAvailableLineColorIds()
    local lookup = {}
    local colors = {}

    for _, endpoint in ipairs(self.endpoints) do
        if endpoint.kind == "input" then
            for _, colorId in ipairs(getEndpointColorIds(endpoint)) do
                if not lookup[colorId] then
                    lookup[colorId] = true
                    colors[#colors + 1] = colorId
                end
            end
        end
    end

    for _, train in ipairs(self.trains) do
        if train.lineColor and not lookup[train.lineColor] then
            lookup[train.lineColor] = true
            colors[#colors + 1] = train.lineColor
        end
    end

    table.sort(colors, function(a, b)
        return getColorOrderIndex(a) < getColorOrderIndex(b)
    end)

    if #colors == 0 then
        colors[1] = COLOR_OPTIONS[1].id
    end

    return colors
end

function mapEditor:cycleColorValue(currentColor, availableColors, direction)
    local options = availableColors or {}
    if #options == 0 then
        return currentColor
    end

    local currentIndex = 1
    for colorIndex, colorId in ipairs(options) do
        if colorId == currentColor then
            currentIndex = colorIndex
            break
        end
    end

    local nextIndex = currentIndex + direction
    if nextIndex < 1 then
        nextIndex = #options
    elseif nextIndex > #options then
        nextIndex = 1
    end
    return options[nextIndex]
end

function mapEditor:clampSequencerScroll()
    local entries = self:getSortedTrainEntries()
    local backRect = self:getSequencerBackButtonRect()
    local listHeight = backRect.y - (self.sidePanel.y + 192) - 12
    local totalHeight = 0
    for _, entry in ipairs(entries) do
        totalHeight = totalHeight + self:getTrainRowHeight(entry.train) + 8
    end
    if totalHeight > 0 then
        totalHeight = totalHeight - 8
    end
    self.sequencerScroll = clamp(self.sequencerScroll or 0, 0, math.max(0, totalHeight - listHeight))
end

function mapEditor:getValidationEntries()
    if self.validationEntries and #self.validationEntries > 0 then
        return self.validationEntries
    end

    local fallbackEntries = {}
    for _, message in ipairs(self.validationErrors or {}) do
        if message ~= EMPTY_MAP_VALIDATION_TEXT then
            fallbackEntries[#fallbackEntries + 1] = { message = message }
        end
    end
    return fallbackEntries
end

function mapEditor:getTrainValidationLookup()
    local lookup = {}

    for _, entry in ipairs(self:getSortedTrainEntries()) do
        lookup[tostring(entry.train.id)] = {
            castName = entry.castName,
            lineColor = entry.train.lineColor,
            trainColor = entry.train.trainColor,
        }
    end

    return lookup
end

function mapEditor:buildValidationEntry(message, diagnostic, trainLookup)
    local entry = {
        message = message,
        diagnostic = diagnostic,
        indentLevel = diagnostic and diagnostic.parentDiagnosticIndex and 1 or 0,
        parentEntryIndex = diagnostic and diagnostic.parentDiagnosticIndex or nil,
    }

    if diagnostic and diagnostic.kind and diagnostic.kind:match("^train_") then
        local trainInfo = trainLookup and trainLookup[tostring(diagnostic.trainId)] or nil
        entry.message = tostring(message or ""):gsub(
            "^Train%s+%d+",
            buildTrainValidationLabel(trainInfo, diagnostic),
            1
        )
    end

    return entry
end

function mapEditor:groupValidationEntriesByHierarchy()
    local orderedEntries = {}
    local childrenByParent = {}
    local entryBySourceIndex = {}
    local visited = {}

    for _, entry in ipairs(self.validationEntries or {}) do
        entryBySourceIndex[entry.sourceIndex] = entry
        if entry.parentEntryIndex then
            childrenByParent[entry.parentEntryIndex] = childrenByParent[entry.parentEntryIndex] or {}
            childrenByParent[entry.parentEntryIndex][#childrenByParent[entry.parentEntryIndex] + 1] = entry
        end
    end

    local function appendEntry(entry)
        if not entry or visited[entry] then
            return
        end

        visited[entry] = true
        orderedEntries[#orderedEntries + 1] = entry

        for _, child in ipairs(childrenByParent[entry.sourceIndex] or {}) do
            appendEntry(child)
        end
    end

    for _, entry in ipairs(self.validationEntries or {}) do
        if not entry.parentEntryIndex or not entryBySourceIndex[entry.parentEntryIndex] then
            appendEntry(entry)
        end
    end

    for _, entry in ipairs(self.validationEntries or {}) do
        appendEntry(entry)
    end

    local orderedIndexBySourceIndex = {}
    for orderedIndex, entry in ipairs(orderedEntries) do
        orderedIndexBySourceIndex[entry.sourceIndex] = orderedIndex
    end

    for _, entry in ipairs(orderedEntries) do
        if entry.parentEntryIndex then
            entry.parentEntryIndex = orderedIndexBySourceIndex[entry.parentEntryIndex]
        end
    end

    self.validationEntries = orderedEntries
end

function mapEditor:refreshValidationEntryNumbering()
    local topLevelCount = 0
    local childCounts = {}

    for index, entry in ipairs(self.validationEntries or {}) do
        local parentIndex = entry.parentEntryIndex
        local parentEntry = parentIndex and self.validationEntries[parentIndex] or nil

        if parentEntry then
            childCounts[parentIndex] = (childCounts[parentIndex] or 0) + 1
            entry.displayNumber = string.format("%s.%d", parentEntry.displayNumber or tostring(parentIndex), childCounts[parentIndex])
            entry.numberLabel = entry.displayNumber
            entry.indentLevel = 1
        else
            topLevelCount = topLevelCount + 1
            entry.displayNumber = tostring(topLevelCount)
            entry.numberLabel = entry.displayNumber .. "."
            entry.indentLevel = 0
        end

        self.validationEntries[index] = entry
    end
end

function mapEditor:getValidationListLayout(font)
    font = font or love.graphics.getFont()

    local drawerLayout = self:getEditorDrawerLayout()
    local panelX = self.sidePanel.x + 18
    local panelWidth = self.sidePanel.w - 36
    local panelBottom = self:getPlayTestButtonRect().y - 16
    local issuesTitleY = drawerLayout.gridToggleRect.y + drawerLayout.gridToggleRect.h + 26
    local resolveText = "Resolve these before the run can start:"
    local resolveTextHeight = getWrappedLineCount(font, resolveText, panelWidth) * font:getHeight()
    local listTop = issuesTitleY + 26 + resolveTextHeight + 10
    local listBottom = panelBottom - 12

    local listHeight = math.max(72, listBottom - listTop)
    local listRect = {
        x = panelX,
        y = listTop,
        w = panelWidth,
        h = listHeight,
    }

    local entries = self:getValidationEntries()
    local displayMode = getValidationColorDisplayMode(self)
    local totalContentHeight = 0
    for index, entry in ipairs(entries) do
        local item = getValidationEntryMessage(entry)
        local indentOffset = math.max(0, (entry.indentLevel or 0) * VALIDATION_CHILD_INDENT)
        local numberWidth = font:getWidth((entry.numberLabel or (tostring(index) .. ".")) .. " ")
        local lineHeight = font:getHeight()
        local itemHeight = measureValidationMessage(font, item, listRect.w - numberWidth - indentOffset, displayMode)
        totalContentHeight = totalContentHeight + itemHeight
        if index < #entries then
            totalContentHeight = totalContentHeight + 10
        end
    end

    local maxScroll = math.max(0, totalContentHeight - listRect.h)
    self.validationScroll = clamp(self.validationScroll or 0, 0, maxScroll)

    local scrollbar = nil
    local contentWidth = listRect.w
    if maxScroll > 0 then
        local track = {
            x = panelX + panelWidth - 8,
            y = listRect.y,
            w = 8,
            h = listRect.h,
        }
        local thumbHeight = math.max(28, track.h * (listRect.h / math.max(totalContentHeight, listRect.h)))
        local thumbY = track.y + (track.h - thumbHeight) * ((self.validationScroll or 0) / maxScroll)
        scrollbar = {
            track = track,
            thumb = {
                x = track.x,
                y = thumbY,
                w = track.w,
                h = thumbHeight,
            },
            maxScroll = maxScroll,
        }
        contentWidth = panelWidth - 16
    end

    return {
        panelX = panelX,
        panelWidth = panelWidth,
        panelBottom = panelBottom,
        issuesTitleY = issuesTitleY,
        resolveText = resolveText,
        resolveTextY = issuesTitleY + 26,
        resolveTextHeight = resolveTextHeight,
        listRect = listRect,
        totalContentHeight = totalContentHeight,
        maxScroll = maxScroll,
        scrollbar = scrollbar,
        contentWidth = contentWidth,
    }
end

function mapEditor:getVisibleValidationRows(font, layout)
    local entries = self:getValidationEntries()
    local displayMode = getValidationColorDisplayMode(self)
    local rows = {}
    local currentY = layout.listRect.y - (self.validationScroll or 0)

    for index, entry in ipairs(entries) do
        local message = getValidationEntryMessage(entry)
        local indentOffset = math.max(0, (entry.indentLevel or 0) * VALIDATION_CHILD_INDENT)
        local lineHeight = font:getHeight()
        local numberLabel = entry.numberLabel or (tostring(index) .. ".")
        local numberWidth = font:getWidth(numberLabel .. " ")
        local textWidth = math.max(20, (layout.contentWidth or layout.listRect.w) - numberWidth - indentOffset)
        local itemHeight = measureValidationMessage(font, message, textWidth, displayMode)
        local itemBottom = currentY + itemHeight

        if itemBottom >= layout.listRect.y and currentY <= layout.listRect.y + layout.listRect.h then
            rows[#rows + 1] = {
                index = index,
                entry = entry,
                message = message,
                rect = {
                    x = layout.listRect.x,
                    y = currentY,
                    w = layout.contentWidth or layout.listRect.w,
                    h = itemHeight,
                },
                indentOffset = indentOffset,
                textWidth = textWidth,
                numberLabel = numberLabel,
                numberWidth = numberWidth,
            }
        end

        currentY = currentY + itemHeight + 10
    end

    return rows
end

function mapEditor:addTrain()
    local lineColors = self:getAvailableLineColorIds()
    local spawnTime = 0
    for _, train in ipairs(self.trains) do
        spawnTime = math.max(spawnTime, (train.spawnTime or 0) + 0.5)
    end
    self.trains[#self.trains + 1] = self:createTrainDefinition({
        lineColor = lineColors[1],
        trainColor = lineColors[1],
        spawnTime = spawnTime,
        wagonCount = DEFAULT_TRAIN_WAGONS,
    })
    self:clampSequencerScroll()
    self:refreshValidation()
    self:showStatus("Train added to the sequencer.")
end

function mapEditor:getTrainRowHeight(_)
    return 38
end

function mapEditor:removeTrainByIndex(trainIndex)
    if not self.trains[trainIndex] then
        return
    end
    table.remove(self.trains, trainIndex)
    self:clampSequencerScroll()
    self:refreshValidation()
    self:showStatus("Train removed from the sequencer.")
end

function mapEditor:getTrainById(trainId)
    for _, train in ipairs(self.trains) do
        if train.id == trainId then
            return train
        end
    end
    return nil
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

function mapEditor:getRouteSegmentCount(route)
    if not route or not route.points then
        return 0
    end

    return math.max(0, #route.points - 1)
end

function mapEditor:ensureRouteSegmentRoadTypes(route)
    if not route then
        return {}
    end

    local segmentCount = self:getRouteSegmentCount(route)
    local segmentRoadTypes = route.segmentRoadTypes or {}
    local normalizedRoadTypes = {}
    local fallbackRoadType = roadTypes.normalizeRoadType(route.roadType)

    for segmentIndex = 1, segmentCount do
        normalizedRoadTypes[segmentIndex] = roadTypes.normalizeRoadType(segmentRoadTypes[segmentIndex] or fallbackRoadType)
    end

    route.segmentRoadTypes = normalizedRoadTypes
    route.roadType = nil
    return route.segmentRoadTypes
end

function mapEditor:getRouteSegmentRoadType(route, segmentIndex)
    local segmentRoadTypes = self:ensureRouteSegmentRoadTypes(route)
    return segmentRoadTypes[segmentIndex] or DEFAULT_ROAD_TYPE
end

function mapEditor:summarizeRouteRoadTypes(route)
    local counts = {}
    local summaryParts = {}

    for _, roadTypeId in ipairs(self:ensureRouteSegmentRoadTypes(route)) do
        counts[roadTypeId] = (counts[roadTypeId] or 0) + 1
    end

    for _, option in ipairs(ROAD_TYPE_OPTIONS) do
        local count = counts[option.id] or 0
        if count > 0 then
            summaryParts[#summaryParts + 1] = string.format("%d %s", count, option.label:lower())
        end
    end

    if #summaryParts == 0 then
        return "No road segments."
    end

    return table.concat(summaryParts, ", ")
end

function mapEditor:createEndpoint(kind, x, y, colors, id)
    local endpointId = id or (kind .. "_endpoint_" .. self.nextEndpointId)
    local fallbackColorId = COLOR_OPTIONS[((self.nextEndpointId - 1) % #COLOR_OPTIONS) + 1].id
    local endpoint = {
        id = endpointId,
        kind = kind,
        x = x,
        y = y,
        colors = normalizeEndpointColors(kind, colors, fallbackColorId),
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

function mapEditor:updatePreviewWorld(previewLevel)
    local level = previewLevel or {
        title = self.currentMapName or "Untitled",
        edges = {},
        junctions = {},
        trains = {},
    }
    self.previewWorld = world.new(self.mapSize.w, self.mapSize.h, level)
end

function mapEditor:setValidationResults(buildError, buildErrors, buildDiagnostics)
    self.lastValidationError = buildError
    self.validationErrors = buildErrors or {}
    self.validationEntries = {}
    local trainLookup = self:getTrainValidationLookup()

    for index, message in ipairs(self.validationErrors) do
        if message ~= EMPTY_MAP_VALIDATION_TEXT then
            local diagnostic = buildDiagnostics and buildDiagnostics[index] or nil
            local entry = self:buildValidationEntry(message, diagnostic, trainLookup)
            entry.sourceIndex = index
            self.validationEntries[#self.validationEntries + 1] = entry
        end
    end
    self:groupValidationEntriesByHierarchy()
    self:refreshValidationEntryNumbering()

    self.hoveredValidationIndex = nil
end

function mapEditor:refreshValidation(mapName)
    local level, previewLevel, buildError, buildErrors, buildDiagnostics = authoredMap.buildEditorPreviewBundle(
        mapName or self.currentMapName or "Untitled",
        self:getExportData(),
        self.editingMapUuid
    )
    self:updatePreviewWorld(previewLevel)
    self:setValidationResults(buildError, buildErrors, buildDiagnostics)
    return level, buildError, self.validationErrors
end

function mapEditor:getSavedMapDescriptor()
    if not isLocalSavedMapDescriptor(self.lastSavedDescriptor) then
        return nil
    end

    return self.lastSavedDescriptor
end

function mapEditor:buildDirtyStateSnapshot()
    return {
        name = self.currentMapName,
        mapUuid = self.editingMapUuid,
        editor = self:getExportData(),
    }
end

function mapEditor:updateSavedStateSnapshot()
    self.savedStateSnapshotJson = json.encode(self:buildDirtyStateSnapshot())
end

function mapEditor:hasUnsavedChanges()
    local savedSnapshotJson = self.savedStateSnapshotJson
    if not savedSnapshotJson then
        savedSnapshotJson = json.encode({
            editor = buildBlankEditorData(),
        })
    end

    return json.encode(self:buildDirtyStateSnapshot()) ~= savedSnapshotJson
end

function mapEditor:canPlaySavedMap()
    return self:getSavedMapDescriptor() ~= nil and not self:hasUnsavedChanges()
end

function mapEditor:setSavedMapUploadState(isAvailable, isPending)
    self.savedMapUploadAvailable = isAvailable == true
    self.savedMapUploadPending = isPending == true
end

function mapEditor:canUploadSavedMap()
    return self:getSavedMapDescriptor() ~= nil
        and not self:hasUnsavedChanges()
        and self.savedMapUploadAvailable == true
        and self.savedMapUploadPending ~= true
end

function mapEditor:requestPlaytestFromSavedMap()
    if self:getSavedMapDescriptor() == nil then
        self:showStatus("Save a playable map first, then test it from here.")
        return false
    end

    if self:hasUnsavedChanges() then
        self:showStatus("Save the map again before starting the saved version.")
        return false
    end

    self.pendingPlaytestDescriptor = self:getSavedMapDescriptor()
    self:showStatus("Starting test run from the saved map...")
    return true
end

function mapEditor:consumePlaytestRequest()
    local descriptor = self.pendingPlaytestDescriptor
    self.pendingPlaytestDescriptor = nil
    return descriptor
end

function mapEditor:requestUploadFromSavedMap()
    if self:getSavedMapDescriptor() == nil then
        self:showStatus("Save a playable local map before uploading it.")
        return false
    end

    if self:hasUnsavedChanges() then
        self:showStatus("Save the map again before uploading it.")
        return false
    end

    if self.savedMapUploadPending == true then
        self:showStatus("This map is already uploading.")
        return false
    end

    if self.savedMapUploadAvailable ~= true then
        self:showStatus(UPLOAD_UNAVAILABLE_MESSAGE)
        return false
    end

    self.pendingUploadDescriptor = self:getSavedMapDescriptor()
    self:showStatus("Uploading the saved map...")
    return true
end

function mapEditor:consumeUploadRequest()
    local descriptor = self.pendingUploadDescriptor
    self.pendingUploadDescriptor = nil
    return descriptor
end

function mapEditor:requestOpenBlankMap()
    self.pendingOpenBlankMap = true
    self:closeDialog()
    return true
end

function mapEditor:consumeOpenBlankMapRequest()
    local isPending = self.pendingOpenBlankMap
    self.pendingOpenBlankMap = false
    return isPending
end

function mapEditor:createRoute(points, color, id, label, colorId, startColors, endColors, startEndpointId, endEndpointId, segmentRoadTypes)
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
        segmentRoadTypes = {},
    }

    for _, point in ipairs(points) do
        route.points[#route.points + 1] = copyPoint(point)
    end

    self.routes[#self.routes + 1] = route
    self.nextRouteId = self.nextRouteId + 1
    route.segmentRoadTypes = buildDefaultSegmentRoadTypes(#route.points, DEFAULT_ROAD_TYPE)
    if type(segmentRoadTypes) == "table" then
        for segmentIndex = 1, #route.segmentRoadTypes do
            route.segmentRoadTypes[segmentIndex] = roadTypes.normalizeRoadType(segmentRoadTypes[segmentIndex])
        end
    end
    self:updateRouteEndpointPoint(route, "start")
    self:updateRouteEndpointPoint(route, "end")
    return route
end

function mapEditor:getSaveButtonRect()
    local fullWidth = self.sidePanel.w - PANEL_BUTTON_SIDE_MARGIN * 2
    local buttonWidth = (fullWidth - PANEL_BUTTON_GAP) * 0.5
    return {
        x = self.sidePanel.x + PANEL_BUTTON_SIDE_MARGIN,
        y = self.sidePanel.y + self.sidePanel.h - (PANEL_BUTTON_BOTTOM_MARGIN + PANEL_BUTTON_HEIGHT * 4 + PANEL_BUTTON_GAP * 3),
        w = buttonWidth,
        h = PANEL_BUTTON_HEIGHT,
    }
end

function mapEditor:getOpenButtonRect()
    local saveRect = self:getSaveButtonRect()
    return {
        x = saveRect.x + saveRect.w + PANEL_BUTTON_GAP,
        y = saveRect.y,
        w = saveRect.w,
        h = saveRect.h,
    }
end

function mapEditor:getPlayTestButtonRect()
    return {
        x = self.sidePanel.x + PANEL_BUTTON_SIDE_MARGIN,
        y = self.sidePanel.y + self.sidePanel.h - (PANEL_BUTTON_BOTTOM_MARGIN + PANEL_BUTTON_HEIGHT * 5 + PANEL_BUTTON_GAP * 4),
        w = (self.sidePanel.w - PANEL_BUTTON_SIDE_MARGIN * 2 - PANEL_BUTTON_GAP) * 0.5,
        h = PANEL_BUTTON_HEIGHT,
    }
end

function mapEditor:getUploadMapButtonRect()
    local playRect = self:getPlayTestButtonRect()
    return {
        x = playRect.x + playRect.w + PANEL_BUTTON_GAP,
        y = playRect.y,
        w = playRect.w,
        h = playRect.h,
    }
end

function mapEditor:getSequencerButtonRect()
    return {
        x = self.sidePanel.x + PANEL_BUTTON_SIDE_MARGIN,
        y = self.sidePanel.y + self.sidePanel.h - (PANEL_BUTTON_BOTTOM_MARGIN + PANEL_BUTTON_HEIGHT * 3 + PANEL_BUTTON_GAP * 2),
        w = self.sidePanel.w - PANEL_BUTTON_SIDE_MARGIN * 2,
        h = PANEL_BUTTON_HEIGHT,
    }
end

function mapEditor:getResetButtonRect()
    local fullWidth = self.sidePanel.w - PANEL_BUTTON_SIDE_MARGIN * 2
    local buttonWidth = (fullWidth - PANEL_BUTTON_GAP) * 0.5
    return {
        x = self.sidePanel.x + PANEL_BUTTON_SIDE_MARGIN,
        y = self.sidePanel.y + self.sidePanel.h - (PANEL_BUTTON_BOTTOM_MARGIN + PANEL_BUTTON_HEIGHT * 2 + PANEL_BUTTON_GAP),
        w = buttonWidth,
        h = PANEL_BUTTON_HEIGHT,
    }
end

function mapEditor:getHitboxToggleRect()
    local resetRect = self:getResetButtonRect()
    return {
        x = resetRect.x + resetRect.w + PANEL_BUTTON_GAP,
        y = resetRect.y,
        w = resetRect.w,
        h = resetRect.h,
    }
end

function mapEditor:getSequencerBackButtonRect()
    return self:getOpenUserMapsButtonRect()
end

function mapEditor:getOpenUserMapsButtonRect()
    return {
        x = self.sidePanel.x + PANEL_BUTTON_SIDE_MARGIN,
        y = self.sidePanel.y + self.sidePanel.h - (PANEL_BUTTON_BOTTOM_MARGIN + PANEL_BUTTON_HEIGHT),
        w = self.sidePanel.w - PANEL_BUTTON_SIDE_MARGIN * 2,
        h = PANEL_BUTTON_HEIGHT,
    }
end

function mapEditor:getSequencerAddButtonRect()
    return {
        x = self.sidePanel.x + 18,
        y = self.sidePanel.y + 126,
        w = self.sidePanel.w - 36,
        h = 34,
    }
end

function mapEditor:getSequencerLayout()
    local panelX = self.sidePanel.x + 18
    local panelWidth = self.sidePanel.w - 36
    local backRect = self:getSequencerBackButtonRect()
    local sortedEntries = self:getSortedTrainEntries()
    local listHeaderRect = {
        x = panelX,
        y = self.sidePanel.y + 170,
        w = panelWidth,
        h = 18,
    }
    local listRect = {
        x = panelX,
        y = self.sidePanel.y + 192,
        w = panelWidth,
        h = backRect.y - (self.sidePanel.y + 192) - 12,
    }
    local totalContentHeight = 0
    for _, entry in ipairs(sortedEntries) do
        totalContentHeight = totalContentHeight + self:getTrainRowHeight(entry.train) + 8
    end
    if totalContentHeight > 0 then
        totalContentHeight = totalContentHeight - 8
    end
    local maxScroll = math.max(0, totalContentHeight - listRect.h)
    self.sequencerScroll = clamp(self.sequencerScroll or 0, 0, maxScroll)

    local scrollbar = nil
    local contentWidth = panelWidth
    if maxScroll > 0 then
        local track = {
            x = panelX + panelWidth - 8,
            y = listRect.y,
            w = 8,
            h = listRect.h,
        }
        local thumbHeight = math.max(28, track.h * (listRect.h / math.max(totalContentHeight, listRect.h)))
        local thumbY = track.y + (track.h - thumbHeight) * ((self.sequencerScroll or 0) / maxScroll)
        scrollbar = {
            track = track,
            thumb = {
                x = track.x,
                y = thumbY,
                w = track.w,
                h = thumbHeight,
            },
            maxScroll = maxScroll,
        }
        contentWidth = panelWidth - 16
    end

    self:clampSequencerScroll()

    local rows = {}
    local currentY = listRect.y - (self.sequencerScroll or 0)
    for _, entry in ipairs(sortedEntries) do
        local rowHeight = self:getTrainRowHeight(entry.train)
        local rowRect = {
            x = panelX,
            y = currentY,
            w = contentWidth,
            h = rowHeight,
        }
        if rowRect.y + rowRect.h >= listRect.y and rowRect.y <= listRect.y + listRect.h then
            rows[#rows + 1] = {
                entry = entry,
                rect = rowRect,
            }
        end
        currentY = currentY + rowHeight + 8
    end

    return {
        panelX = panelX,
        panelWidth = panelWidth,
        sortedEntries = sortedEntries,
        mapDeadlineRect = {
            x = panelX,
            y = self.sidePanel.y + 74,
            w = panelWidth,
            h = 32,
        },
        addRect = self:getSequencerAddButtonRect(),
        listHeaderRect = listHeaderRect,
        listRect = listRect,
        totalContentHeight = totalContentHeight,
        maxScroll = maxScroll,
        scrollbar = scrollbar,
        rows = rows,
        backRect = backRect,
    }
end

function mapEditor:getEditorDrawerLayout()
    local panelX = self.sidePanel.x + 18
    local panelWidth = self.sidePanel.w - 36
    local mapSizeRect = {
        x = panelX,
        y = self.sidePanel.y + 92,
        w = panelWidth,
        h = 34,
    }
    local gridToggleRect = { x = panelX, y = mapSizeRect.y + mapSizeRect.h + 16, w = 120, h = 28 }
    local gridStepRect = self:getTextFieldRect(panelX + 130, gridToggleRect.y + 1, panelWidth - 130)

    return {
        mapSizeRect = mapSizeRect,
        gridToggleRect = gridToggleRect,
        gridStepRect = gridStepRect,
    }
end

function mapEditor:getMapSizePreset()
    for _, preset in ipairs(MAP_SIZE_PRESETS) do
        if preset.w == self.mapSize.w then
            return preset
        end
    end
    return MAP_SIZE_PRESETS[1]
end

function mapEditor:handleEditorDrawerClick(x, y)
    local layout = self:getEditorDrawerLayout()
    if pointInRect(x, y, layout.mapSizeRect) then
        for presetIndex, preset in ipairs(MAP_SIZE_PRESETS) do
            if pointInRect(x, y, uiControls.segmentRect(layout.mapSizeRect, presetIndex, #MAP_SIZE_PRESETS)) then
                self:commitTextField()
                self:resizeMapTo(preset.w)
                return true
            end
        end
    end

    if pointInRect(x, y, layout.gridToggleRect) then
        self.gridVisible = not self.gridVisible
        self:notifyPreferencesChanged()
        self:showStatus(self.gridVisible and "Grid shown." or "Grid hidden.")
        return true
    end

    if pointInRect(x, y, layout.gridStepRect) then
        self:openTextField("map", "editor", "gridStep", tostring(self.gridStep), "int")
        return true
    end

    return false
end

function mapEditor:clampPoint(x, y, isStartPoint)
    local clampedX = clamp(x, self.canvas.x + 14, self.canvas.x + self.canvas.w - 14)
    local minY = self.canvas.y + 14
    local maxY = self.canvas.y + self.canvas.h - 14
    local clampedY = clamp(y, minY, maxY)

    return clampedX, clampedY
end

function mapEditor:closeColorPicker()
    self.colorPicker = nil
end

function mapEditor:closeRouteTypePicker()
    self.routeTypePicker = nil
end

local function easeOutBack(t)
    local overshoot = 1.15
    local shifted = t - 1
    return 1 + (overshoot + 1) * shifted * shifted * shifted + overshoot * shifted * shifted
end

function mapEditor:restartJunctionPickerPopup(originX, originY)
    if not self.colorPicker or self.colorPicker.mode ~= "junction" then
        return
    end

    self.colorPicker.popupOriginX = originX or self.colorPicker.anchorX
    self.colorPicker.popupOriginY = originY or self.colorPicker.anchorY
    self.colorPicker.popupTimer = 0
end

function mapEditor:getJunctionPickerPopupScale()
    if not self.colorPicker or self.colorPicker.mode ~= "junction" then
        return 1
    end

    local timer = self.colorPicker.popupTimer
    if timer == nil then
        return 1
    end

    local progress = clamp(timer / JUNCTION_MENU_POP_DURATION, 0, 1)
    return math.max(0.06, easeOutBack(progress))
end

function mapEditor:getJunctionPickerPopupOrigin()
    if not self.colorPicker or self.colorPicker.mode ~= "junction" then
        return 0, 0
    end

    return self.colorPicker.popupOriginX or self.colorPicker.anchorX, self.colorPicker.popupOriginY or self.colorPicker.anchorY
end

function mapEditor:screenToJunctionPickerSpace(x, y)
    local scale = self:getJunctionPickerPopupScale()
    if scale == 1 then
        return x, y
    end

    local originX, originY = self:getJunctionPickerPopupOrigin()
    return originX + (x - originX) / scale, originY + (y - originY) / scale
end

function mapEditor:openColorPicker(route, magnetKind)
    if magnetKind ~= "end" then
        return
    end

    local point = magnetKind == "start" and route.points[1] or route.points[#route.points]
    local anchorX, anchorY = self:mapToScreen(point.x, point.y)
    self.colorPicker = {
        mode = "route_end",
        routeId = route.id,
        magnetKind = magnetKind,
        anchorX = anchorX,
        anchorY = anchorY,
        hoverBranch = nil,
        branch = "disconnect",
        hoverOptionIndex = nil,
    }
    self:closeRouteTypePicker()
end

function mapEditor:openRouteTypePicker(route, segmentIndex, anchorX, anchorY)
    self.routeTypePicker = {
        routeId = route.id,
        segmentIndex = segmentIndex,
        anchorX = anchorX,
        anchorY = anchorY,
    }
    self:closeColorPicker()
end

function mapEditor:openJunctionPicker(intersection, clickX, clickY)
    self:prepareIntersectionForDrag(intersection)

    local anchorX, anchorY = self:mapToScreen(intersection.x, intersection.y)
    local liveIntersection = self:getIntersectionById(intersection.id) or intersection
    self.colorPicker = {
        mode = "junction",
        intersectionId = liveIntersection.id,
        anchorX = anchorX,
        anchorY = anchorY,
        hoverBranch = nil,
        branch = nil,
        hoverOptionIndex = nil,
    }
    self:restartJunctionPickerPopup(clickX, clickY)
    self:closeRouteTypePicker()
end

function mapEditor:openSequencerColorPicker(trainId, fieldName, anchorX, anchorY)
    self.colorPicker = {
        mode = "sequencer",
        trainId = trainId,
        fieldName = fieldName,
        anchorX = anchorX,
        anchorY = anchorY,
    }
end

function mapEditor:getColorPickerOptions()
    if not self.colorPicker then
        return {}
    end

    if self.colorPicker.mode == "sequencer" then
        return COLOR_OPTIONS
    end

    local lookup = {}
    if self.colorPicker.mode == "route" or self.colorPicker.mode == "route_end" then
        local route = self:getRouteById(self.colorPicker.routeId)
        local endpoint = route and route.id == self.colorPicker.routeId
            and (self.colorPicker.magnetKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route))
            or nil
        lookup = endpoint and endpoint.colors or {}
    elseif self.colorPicker.mode == "junction" then
        local intersection = self:getIntersectionById(self.colorPicker.intersectionId)
        local group = intersection and self:getSharedPointGroupForIntersection(intersection) or nil
        lookup = group and group.colorLookup or {}
    end

    local options = {}
    for _, option in ipairs(COLOR_OPTIONS) do
        if lookup[option.id] then
            options[#options + 1] = option
        end
    end
    return options
end

function mapEditor:getColorPickerSelectionLookup()
    local lookup = {}
    if not self.colorPicker then
        return lookup
    end

    if self.colorPicker.mode == "route" or self.colorPicker.mode == "route_end" then
        local route = self:getRouteById(self.colorPicker.routeId)
        if not route or route.id ~= self.colorPicker.routeId then
            return lookup
        end
        local endpoint = self.colorPicker.magnetKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route)
        return endpoint and endpoint.colors or {}
    elseif self.colorPicker.mode == "junction" then
        local intersection = self:getIntersectionById(self.colorPicker.intersectionId)
        local group = intersection and self:getSharedPointGroupForIntersection(intersection) or nil
        return group and group.colorLookup or lookup
    elseif self.colorPicker.mode == "sequencer" then
        local train = self:getTrainById(self.colorPicker.trainId)
        if not train then
            return lookup
        end
        lookup[train[self.colorPicker.fieldName]] = true
        return lookup
    end

    return lookup
end

function mapEditor:getJunctionPickerRootHover(x, y)
    if not self.colorPicker or (self.colorPicker.mode ~= "junction" and self.colorPicker.mode ~= "route_end") then
        return nil
    end

    local dx = x - self.colorPicker.anchorX
    local dy = y - self.colorPicker.anchorY
    if math.abs(dx) < math.abs(dy) * JUNCTION_MENU_BRANCH_RATIO then
        return nil
    end

    if dx < 0 then
        return "disconnect"
    end
    if dx > 0 and self.colorPicker.mode == "junction" then
        return "junctions"
    end
    return nil
end

function mapEditor:buildJunctionPickerEntries(branch, centerX, centerY, innerRadius, outerRadius)
    local entries = {}
    local options = {}

    if branch == "disconnect" then
        options = self:getColorPickerOptions()
    elseif branch == "junctions" then
        for _, controlType in ipairs(CONTROL_ORDER) do
            options[#options + 1] = {
                id = controlType,
                controlType = controlType,
            }
        end
    end

    if #options == 0 then
        return entries
    end

    local step = (math.pi * 2) / #options
    local startAngle = -math.pi * 0.5 - step * 0.5
    local iconRadius = (innerRadius + outerRadius) * 0.5

    for optionIndex, option in ipairs(options) do
        local segmentStart = startAngle + (optionIndex - 1) * step
        local segmentMiddle = segmentStart + step * 0.5
        entries[#entries + 1] = {
            option = option,
            index = optionIndex,
            startAngle = segmentStart,
            endAngle = segmentStart + step,
            centerX = centerX + math.cos(segmentMiddle) * iconRadius,
            centerY = centerY + math.sin(segmentMiddle) * iconRadius,
        }
    end

    return entries
end

function mapEditor:getJunctionPickerLayout()
    if not self.colorPicker or (self.colorPicker.mode ~= "junction" and self.colorPicker.mode ~= "route_end") then
        return nil
    end

    local branch = self.colorPicker.branch
    local rootCenterX = self.colorPicker.anchorX
    local rootCenterY = self.colorPicker.anchorY
    local submenu = nil

    if branch then
        local outerRadius = branch == "junctions" and JUNCTION_MENU_TYPE_OUTER_RADIUS or JUNCTION_MENU_COLOR_OUTER_RADIUS
        local submenuCenterX = clamp(
            rootCenterX,
            self.canvas.x + outerRadius + JUNCTION_MENU_EDGE_MARGIN,
            self.viewport.w - outerRadius - JUNCTION_MENU_EDGE_MARGIN
        )
        local submenuCenterY = clamp(
            rootCenterY,
            self.canvas.y + outerRadius + JUNCTION_MENU_EDGE_MARGIN,
            self.viewport.h - outerRadius - JUNCTION_MENU_EDGE_MARGIN
        )
        submenu = {
            branch = branch,
            x = submenuCenterX,
            y = submenuCenterY,
            radius = outerRadius,
            innerRadius = JUNCTION_MENU_RING_INNER_RADIUS,
            outerRadius = outerRadius,
            entries = self:buildJunctionPickerEntries(
                branch,
                submenuCenterX,
                submenuCenterY,
                JUNCTION_MENU_RING_INNER_RADIUS,
                outerRadius
            ),
        }
    end

    return {
        kind = "junction_radial",
        root = {
            x = rootCenterX,
            y = rootCenterY,
            radius = JUNCTION_MENU_ROOT_RADIUS,
        },
        branch = branch,
        hoverBranch = self.colorPicker.hoverBranch,
        submenu = submenu,
    }
end

function mapEditor:getJunctionPickerOptionHit(submenu, x, y)
    if not submenu then
        return nil
    end
    if #submenu.entries == 0 then
        return nil
    end

    local distance = math.sqrt(distanceSquared(x, y, submenu.x, submenu.y))
    if distance > submenu.outerRadius then
        return nil
    end

    local fullTurn = math.pi * 2
    local step = fullTurn / #submenu.entries
    -- The top wedge is centered on the zero-angle seam, so shift by half a step
    -- before quantizing to keep hover and click boundaries aligned with the arcs.
    local baseAngle = normalizeAngle(angleBetweenCoordinates(submenu.x, submenu.y, x, y) + math.pi * 0.5 + step * 0.5)
    local entryIndex = math.floor(baseAngle / step) + 1
    return submenu.entries[entryIndex]
end

function mapEditor:updateJunctionPickerHover(x, y)
    if not self.colorPicker or (self.colorPicker.mode ~= "junction" and self.colorPicker.mode ~= "route_end") then
        return false
    end

    x, y = self:screenToJunctionPickerSpace(x, y)

    local rootDistance = math.sqrt(distanceSquared(x, y, self.colorPicker.anchorX, self.colorPicker.anchorY))
    local hoverBranch = rootDistance <= JUNCTION_MENU_ROOT_RADIUS and self:getJunctionPickerRootHover(x, y) or nil

    self.colorPicker.hoverBranch = hoverBranch
    self.colorPicker.hoverOptionIndex = nil

    local layout = self:getJunctionPickerLayout()
    if layout and layout.submenu then
        local hitEntry = self:getJunctionPickerOptionHit(layout.submenu, x, y)
        self.colorPicker.hoverOptionIndex = hitEntry and hitEntry.index or nil
    end

    return true
end

function mapEditor:getColorPickerLayout()
    if not self.colorPicker then
        return nil
    end

    local options = self:getColorPickerOptions()
    if self.colorPicker.mode ~= "junction" and self.colorPicker.mode ~= "route_end" and #options == 0 then
        return nil
    end

    if self.colorPicker.mode == "junction" or self.colorPicker.mode == "route_end" then
        return self:getJunctionPickerLayout()
    end

    local columns = math.min(3, math.max(1, #options))
    local swatchSize = 34
    local gap = 10
    local rows = math.ceil(#options / columns)
    local rect = {
        w = 32 + columns * swatchSize + math.max(0, columns - 1) * gap,
        h = 32 + rows * swatchSize + math.max(0, rows - 1) * gap,
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
    local startX = rect.x + 16
    local startY = rect.y + 16

    for index, option in ipairs(options) do
        local column = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        swatches[#swatches + 1] = {
            option = option,
            rect = {
                x = startX + column * (swatchSize + gap),
                y = startY + row * (swatchSize + gap),
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

function mapEditor:getRouteTypePickerLayout()
    if not self.routeTypePicker then
        return nil
    end

    local optionCount = #ROAD_TYPE_OPTIONS
    local optionHeight = 42
    local optionGap = 10
    local rect = {
        w = 236,
        h = 66 + optionCount * optionHeight + math.max(0, optionCount - 1) * optionGap,
    }
    rect.x = clamp(
        self.routeTypePicker.anchorX + 18,
        self.canvas.x + 8,
        self.viewport.w - rect.w - 8
    )
    rect.y = clamp(
        self.routeTypePicker.anchorY - rect.h * 0.5,
        self.canvas.y + 8,
        self.viewport.h - rect.h - 8
    )

    local optionRects = {}
    local currentY = rect.y + 46

    for _, option in ipairs(ROAD_TYPE_OPTIONS) do
        optionRects[#optionRects + 1] = {
            option = option,
            rect = {
                x = rect.x + 14,
                y = currentY,
                w = rect.w - 28,
                h = optionHeight,
            },
        }
        currentY = currentY + optionHeight + optionGap
    end

    return {
        rect = rect,
        options = optionRects,
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
        scroll = 0,
    }
end

function mapEditor:openResetDialog()
    self.dialog = {
        type = "confirm_reset",
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

function mapEditor:getConfirmResetDialogButtons()
    local rect = self:getDialogRect()
    local buttonWidth = 180
    local buttonHeight = 42
    local gap = 18
    local totalWidth = buttonWidth * 2 + gap
    local startX = rect.x + (rect.w - totalWidth) * 0.5
    local y = rect.y + rect.h - 84

    return {
        confirm = {
            x = startX,
            y = y,
            w = buttonWidth,
            h = buttonHeight,
        },
        cancel = {
            x = startX + buttonWidth + gap,
            y = y,
            w = buttonWidth,
            h = buttonHeight,
        },
    }
end

function mapEditor:getOpenDialogListLayout()
    local rect = self:getDialogRect()
    local maps = (self.dialog and self.dialog.maps) or {}
    local listRect = {
        x = rect.x + 24,
        y = rect.y + 78,
        w = rect.w - 48,
        h = rect.h - 142,
    }
    local rowStride = 54
    local rowHeight = 44
    local visibleRows = math.max(1, math.floor(listRect.h / rowStride))
    local maxScroll = math.max(0, #maps - visibleRows)
    local scroll = clamp((self.dialog and self.dialog.scroll) or 0, 0, maxScroll)

    if self.dialog then
        self.dialog.scroll = scroll
    end

    local contentWidth = listRect.w
    local scrollbar = nil
    if maxScroll > 0 then
        local track = {
            x = listRect.x + listRect.w - 8,
            y = listRect.y,
            w = 8,
            h = listRect.h,
        }
        local thumbHeight = math.max(26, track.h * (visibleRows / #maps))
        local thumbY = track.y + ((track.h - thumbHeight) * (scroll / maxScroll))
        scrollbar = {
            track = track,
            thumb = {
                x = track.x,
                y = thumbY,
                w = track.w,
                h = thumbHeight,
            },
            maxScroll = maxScroll,
        }
        contentWidth = listRect.w - 14
    end

    local rows = {}
    for slot = 1, visibleRows do
        local mapIndex = scroll + slot
        local savedMap = maps[mapIndex]
        if not savedMap then
            break
        end

        rows[#rows + 1] = {
            index = mapIndex,
            map = savedMap,
            rect = {
                x = listRect.x,
                y = listRect.y + (slot - 1) * rowStride,
                w = contentWidth,
                h = rowHeight,
            },
        }
    end

    return {
        listRect = listRect,
        rows = rows,
        totalMaps = #maps,
        visibleRows = visibleRows,
        maxScroll = maxScroll,
        firstVisibleIndex = (#rows > 0) and rows[1].index or 0,
        lastVisibleIndex = (#rows > 0) and rows[#rows].index or 0,
        scrollbar = scrollbar,
    }
end

function mapEditor:scrollOpenDialog(delta)
    if not self.dialog or self.dialog.type ~= "open" then
        return false
    end

    local layout = self:getOpenDialogListLayout()
    if layout.maxScroll <= 0 then
        return false
    end

    self.dialog.scroll = clamp((self.dialog.scroll or 0) + delta, 0, layout.maxScroll)
    return true
end

function mapEditor:scrollValidationList(delta)
    local layout = self:getValidationListLayout()
    if layout.maxScroll <= 0 then
        return false
    end

    self.validationScroll = clamp((self.validationScroll or 0) + delta, 0, layout.maxScroll)
    return true
end

function mapEditor:updateHoveredValidationEntry(font)
    self.hoveredValidationIndex = nil

    if self.sidePanelMode ~= "default" then
        return
    end

    if not (love and love.mouse and love.mouse.getPosition) then
        return
    end

    local mouseX, mouseY = love.mouse.getPosition()
    local layout = self:getValidationListLayout(font)
    if not pointInRect(mouseX, mouseY, layout.listRect) then
        return
    end

    for _, row in ipairs(self:getVisibleValidationRows(font, layout)) do
        if pointInRect(mouseX, mouseY, row.rect) then
            self.hoveredValidationIndex = row.index
            return
        end
    end
end

function mapEditor:handleValidationListClick(x, y)
    if self.sidePanelMode ~= "default" or #self:getValidationEntries() == 0 then
        return false
    end

    local layout = self:getValidationListLayout()
    if layout.scrollbar and pointInRect(x, y, layout.scrollbar.thumb) then
        self.validationScrollDrag = {
            offsetY = y - layout.scrollbar.thumb.y,
            track = layout.scrollbar.track,
            thumbHeight = layout.scrollbar.thumb.h,
            maxScroll = layout.scrollbar.maxScroll,
        }
        return true
    end

    if layout.scrollbar and pointInRect(x, y, layout.scrollbar.track) then
        local thumbTravel = math.max(1, layout.scrollbar.track.h - layout.scrollbar.thumb.h)
        local targetY = clamp(y - layout.scrollbar.thumb.h * 0.5, layout.scrollbar.track.y, layout.scrollbar.track.y + thumbTravel)
        self.validationScroll = ((targetY - layout.scrollbar.track.y) / thumbTravel) * layout.scrollbar.maxScroll
        return true
    end

    return pointInRect(x, y, layout.listRect)
end

function mapEditor:openDialogMap(savedMap)
    local loadedMap, loadError = mapStorage.loadMap(savedMap)
    if not loadedMap or not loadedMap.editor then
        self:showStatus(loadError or "That map could not be opened.")
        return false
    end

    self:resetFromMap(loadedMap, savedMap)
    return true
end

function mapEditor:openUserMapsFolder()
    local saveDirectory = mapStorage.getSaveDirectory()
    if not (love and love.system and love.system.openURL) then
        self:showStatus("Opening the user maps folder is not supported here.")
        return false
    end

    local ok, result = pcall(love.system.openURL, buildFileUrl(saveDirectory))
    if not ok or result == false then
        self:showStatus("The user maps folder could not be opened.")
        return false
    end

    self:showStatus("Opened the user maps folder.")
    return true
end

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
            x = point.x / self.mapSize.w,
            y = point.y / self.mapSize.h,
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
    return self:refreshValidation(mapName)
end

function mapEditor:saveMap(name)
    local trimmedName = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if trimmedName == "" then
        return false, "Give the map a name before saving it."
    end

    local level, buildError, buildErrors = self:buildPlayableLevel(trimmedName)
    if not level then
        buildError = buildError or "This map cannot be played yet, but the editor layout can still be saved."
    end

    local payload = {
        version = 1,
        name = trimmedName,
        mapUuid = self.editingMapUuid or uuid.generateV4(),
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
    self.editingMapUuid = payload.mapUuid
    self.sourceInfo = record
    self.lastSavedDescriptor = record.hasLevel and record or nil
    self.loadedMapPayload = payload
    self.pendingUploadDescriptor = nil
    self.hoveredValidationIndex = nil
    self:updateSavedStateSnapshot()
    self:closeDialog()
    if level then
        self:showStatus((wasBuiltinTemplate and "Saved copy: " or "Saved map: ") .. trimmedName .. " to " .. mapStorage.getSaveDirectory() .. ".")
    else
        self:showStatus("Saved map: " .. trimmedName .. ". Remaining issues: " .. buildError)
    end
    return true
end

function mapEditor:resetFromMap(mapData, sourceInfo)
    self.loadedMapPayload = mapData
    self.sourceInfo = sourceInfo
    self.editingMapUuid = mapData and mapData.mapUuid or nil
    self.lastSavedDescriptor = sourceInfo and sourceInfo.hasLevel and sourceInfo or nil
    self.pendingPlaytestDescriptor = nil
    self.pendingUploadDescriptor = nil

    if not mapData then
        self.level = nil
        self.mapSize = sanitizeMapSize(nil, DEFAULT_NEW_MAP_WIDTH, DEFAULT_NEW_MAP_HEIGHT)
        self.currentMapName = nil
        self.editingMapUuid = nil
        self.endpoints = {}
        self.routes = {}
        self.trains = {}
        self.timeLimit = nil
        self.nextEndpointId = 1
        self.nextRouteId = 1
        self.nextSharedPointId = 1
        self.nextTrainId = 1
        self.importedJunctionState = {}
        self.drag = nil
        self.sidePanelMode = "default"
        self.sequencerScroll = 0
        self.activeTextField = nil
        self.sequencerScrollDrag = nil
        self.validationScroll = 0
        self.validationScrollDrag = nil
        self.validationEntries = {}
        self.hoveredValidationIndex = nil
        self:closeColorPicker()
        self:closeRouteTypePicker()
        self:clearSelection()
        self:updateLayout()
        self:resetCameraToFit()
        self:rebuildIntersections()
        self:updateSavedStateSnapshot()
        return
    end

    if mapData.editor then
        if sourceInfo and sourceInfo.source == "builtin" then
            self.editingMapUuid = nil
        end
        self:loadEditorData(mapData.editor, mapData.name, sourceInfo, mapData.level)
        return
    end

    self:resetFromLevel(mapData.level)
    self.sourceInfo = sourceInfo
    self.loadedMapPayload = mapData
    self:updateSavedStateSnapshot()
end

function mapEditor:resetFromLevel(level)
    self.level = level
    self.mapSize = sanitizeMapSize(nil, LEGACY_MAP_WIDTH, LEGACY_MAP_HEIGHT)
    self.currentMapName = level and level.title or nil
    self.endpoints = {}
    self.routes = {}
    self.trains = self:synthesizeTrainsFromLevel(level)
    self.timeLimit = level and level.timeLimit or nil
    self.nextEndpointId = 1
    self.nextRouteId = 1
    self.nextSharedPointId = 1
    self.nextTrainId = 1
    self.importedJunctionState = {}
    self.drag = nil
    self.sidePanelMode = "default"
    self.sequencerScroll = 0
    self.activeTextField = nil
    self.sequencerScrollDrag = nil
    self.validationScroll = 0
    self.validationScrollDrag = nil
    self.validationEntries = {}
    self.hoveredValidationIndex = nil
    self:closeColorPicker()
    self:closeRouteTypePicker()
    self:clearSelection()
    self:updateLayout()
    self:resetCameraToFit()

    for _, train in ipairs(self.trains) do
        local numericId = tonumber((train.id or ""):match("train_(%d+)$"))
        if numericId and numericId >= self.nextTrainId then
            self.nextTrainId = numericId + 1
        end
    end

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
                        x = point.x * self.mapSize.w,
                        y = point.y * self.mapSize.h,
                    }
                end
                for pointIndex = 2, #branchDefinition.sharedPoints do
                    local point = branchDefinition.sharedPoints[pointIndex]
                    points[#points + 1] = {
                        x = point.x * self.mapSize.w,
                        y = point.y * self.mapSize.h,
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
            self.importedJunctionState[key] = self.importedJunctionState[key] or {}
            self.importedJunctionState[key][#self.importedJunctionState[key] + 1] = {
                x = mergeX,
                y = mergeY,
                controlType = ((junctionDefinition.control or {}).type) or DEFAULT_CONTROL,
                activeInputIndex = junctionDefinition.activeBranch or 1,
                activeOutputIndex = 1,
            }
        end

        local routeIds = {}
        for _, route in ipairs(branchRoutes) do
            routeIds[#routeIds + 1] = route.id
        end
        self:restoreSharedPointsForRoutes(routeIds)
    end

    self:rebuildIntersections()
end

function mapEditor:resize(viewportW, viewportH)
    self.viewport.w = viewportW
    self.viewport.h = viewportH
    self:updateLayout()
    self:clampCamera()
    self:rebuildIntersections()
end

function mapEditor:resizeMapTo(width)
    local nextMapSize = sanitizeMapSize({
        w = width,
        h = math.floor((tonumber(width) or self.mapSize.w) * 9 / 16 + 0.5),
    }, self.mapSize.w, self.mapSize.h)

    if nextMapSize.w == self.mapSize.w and nextMapSize.h == self.mapSize.h then
        return false
    end

    local scaleX = nextMapSize.w / self.mapSize.w
    local scaleY = nextMapSize.h / self.mapSize.h

    for _, endpoint in ipairs(self.endpoints) do
        endpoint.x = endpoint.x * scaleX
        endpoint.y = endpoint.y * scaleY
    end

    for _, route in ipairs(self.routes) do
        for _, point in ipairs(route.points or {}) do
            point.x = point.x * scaleX
            point.y = point.y * scaleY
        end
    end

    for _, intersection in ipairs(self.intersections) do
        intersection.x = intersection.x * scaleX
        intersection.y = intersection.y * scaleY
    end

    for _, state in pairs(self.importedJunctionState or {}) do
        state.x = (state.x or 0) * scaleX
        state.y = (state.y or 0) * scaleY
    end

    self.mapSize = nextMapSize
    self:updateLayout()
    self:resetCameraToFit()
    self:rebuildIntersections()
    self:showStatus(string.format("Map size set to %dx%d.", self.mapSize.w, self.mapSize.h))
    return true
end

function mapEditor:update(dt)
    if self.statusTimer > 0 then
        self.statusTimer = math.max(0, self.statusTimer - dt)
        if self.statusTimer <= 0 then
            self.statusText = nil
        end
    end

    if self.colorPicker and self.colorPicker.mode == "junction" and self.colorPicker.popupTimer ~= nil then
        self.colorPicker.popupTimer = math.min(JUNCTION_MENU_POP_DURATION, self.colorPicker.popupTimer + dt)
    end
end

function mapEditor:findIntersectionHit(x, y)
    local radiusScale = 1 / math.max(self.camera.zoom, HITBOX_OVERLAY_EPSILON)
    for _, intersection in ipairs(self.intersections) do
        local radius = (intersection.unsupported and INTERSECTION_UNSUPPORTED_HIT_RADIUS or INTERSECTION_HIT_RADIUS) * radiusScale
        if distanceSquared(x, y, intersection.x, intersection.y) <= radius * radius then
            return intersection
        end
    end

    return nil
end

function mapEditor:getMagnetHitRect(point, magnetKind)
    local width = magnetKind == "start" and 58 or 46
    local height = 24
    local padding = 8

    return {
        x = point.x - width * 0.5 - padding,
        y = point.y - height * 0.5 - padding,
        w = width + padding * 2,
        h = height + padding * 2,
    }
end

function mapEditor:findPointHit(x, y)
    local radiusScale = 1 / math.max(self.camera.zoom, HITBOX_OVERLAY_EPSILON)
    for routeIndex = #self.routes, 1, -1 do
        local route = self.routes[routeIndex]
        for pointIndex = #route.points, 1, -1 do
            local point = route.points[pointIndex]
            local isMagnet = pointIndex == 1 or pointIndex == #route.points
            local isSharedJunctionPoint = not isMagnet and point.sharedPointId and self:getSharedPointGroupForPoint(route, pointIndex)
            if not isSharedJunctionPoint then
                local magnetKind = nil
                if pointIndex == 1 then
                    magnetKind = "start"
                elseif pointIndex == #route.points then
                    magnetKind = "end"
                end

                local hit = false
                if isMagnet then
                    hit = pointInRect(x, y, self:getMagnetHitRect(point, magnetKind))
                else
                    local radius = POINT_HIT_RADIUS * radiusScale
                    hit = distanceSquared(x, y, point.x, point.y) <= radius * radius
                end

                if hit then
                    return route, pointIndex, magnetKind
                end
            end
        end
    end

    return nil, nil, nil
end

function mapEditor:findBendPointAt(x, y, excludeRouteId, excludePointIndex)
    local radius = MERGE_SNAP_RADIUS / math.max(self.camera.zoom, 0.0001)
    local radiusSquared = radius * radius
    for routeIndex = #self.routes, 1, -1 do
        local route = self.routes[routeIndex]
        for pointIndex = #route.points - 1, 2, -1 do
            local point = route.points[pointIndex]
            if not (route.id == excludeRouteId and pointIndex == excludePointIndex)
                and distanceSquared(x, y, point.x, point.y) <= radiusSquared then
                return route, pointIndex, point
            end
        end
    end

    return nil, nil, nil
end

function mapEditor:getIntersectionById(intersectionId)
    for _, intersection in ipairs(self.intersections) do
        if intersection.id == intersectionId then
            return intersection
        end
    end
    return nil
end

function mapEditor:getSharedPointGroupForIntersection(intersection)
    if not intersection then
        return nil
    end

    local groups = {}
    for _, routeId in ipairs(intersection.routeIds or {}) do
        local route = self:getRouteById(routeId)
        if route then
            for pointIndex = 2, #route.points - 1 do
                local point = route.points[pointIndex]
                if point.sharedPointId and distanceSquared(point.x, point.y, intersection.x, intersection.y) <= INTERSECTION_SHARED_POINT_DISTANCE_SQUARED then
                    local group = groups[point.sharedPointId]
                    if not group then
                        group = {
                            sharedPointId = point.sharedPointId,
                            members = {},
                            colorLookup = {},
                            colorIds = {},
                        }
                        groups[point.sharedPointId] = group
                    end
                    group.members[#group.members + 1] = {
                        route = route,
                        pointIndex = pointIndex,
                        point = point,
                    }
                    if not group.colorLookup[route.colorId] then
                        group.colorLookup[route.colorId] = true
                        group.colorIds[#group.colorIds + 1] = route.colorId
                    end
                end
            end
        end
    end

    local bestGroup = nil
    for _, group in pairs(groups) do
        if not bestGroup
            or #group.members > #bestGroup.members
            or (#group.members == #bestGroup.members and #group.colorIds > #bestGroup.colorIds) then
            bestGroup = group
        end
    end

    return bestGroup
end

function mapEditor:getSharedPointGroupForPoint(route, pointIndex)
    local point = route and route.points and route.points[pointIndex] or nil
    if not point or not point.sharedPointId or pointIndex <= 1 or pointIndex >= #route.points then
        return nil
    end

    for _, intersection in ipairs(self.intersections) do
        if distanceSquared(point.x, point.y, intersection.x, intersection.y) <= INTERSECTION_SHARED_POINT_DISTANCE_SQUARED then
            local group = self:getSharedPointGroupForIntersection(intersection)
            if group and group.sharedPointId == point.sharedPointId then
                return group, intersection
            end
        end
    end

    return nil
end

function mapEditor:ensureSharedPointId(point)
    if not point.sharedPointId then
        point.sharedPointId = self.nextSharedPointId
        self.nextSharedPointId = self.nextSharedPointId + 1
    end
    return point.sharedPointId
end

function mapEditor:reassignSharedPointGroup(fromSharedPointId, toSharedPointId)
    if not fromSharedPointId or not toSharedPointId or fromSharedPointId == toSharedPointId then
        return
    end

    for _, route in ipairs(self.routes) do
        for _, point in ipairs(route.points) do
            if point.sharedPointId == fromSharedPointId then
                point.sharedPointId = toSharedPointId
            end
        end
    end
end

function mapEditor:updateSharedPointGroup(sharedPointId, x, y)
    if not sharedPointId then
        return
    end

    for _, route in ipairs(self.routes) do
        for _, point in ipairs(route.points) do
            if point.sharedPointId == sharedPointId then
                point.x = x
                point.y = y
            end
        end
    end
end

function mapEditor:restoreSharedPointsForRoutes(routeIds)
    local pointGroups = {}

    for _, routeId in ipairs(routeIds or {}) do
        local route = self:getRouteById(routeId)
        if route then
            for pointIndex = 2, #route.points - 1 do
                local point = route.points[pointIndex]
                local matchedGroup = nil

                for _, group in ipairs(pointGroups) do
                    if distanceSquared(point.x, point.y, group.x, group.y) <= 4 then
                        matchedGroup = group
                        break
                    end
                end

                if not matchedGroup then
                    matchedGroup = {
                        x = point.x,
                        y = point.y,
                        members = {},
                    }
                    pointGroups[#pointGroups + 1] = matchedGroup
                end

                matchedGroup.members[#matchedGroup.members + 1] = point
            end
        end
    end

    for _, group in ipairs(pointGroups) do
        if #group.members > 1 then
            local sharedPointId = nil

            for _, point in ipairs(group.members) do
                if point.sharedPointId then
                    sharedPointId = point.sharedPointId
                    break
                end
            end

            if not sharedPointId then
                sharedPointId = self.nextSharedPointId
                self.nextSharedPointId = self.nextSharedPointId + 1
            end

            for _, point in ipairs(group.members) do
                point.sharedPointId = sharedPointId
            end
        end
    end
end

function mapEditor:mergeBendPointInto(route, pointIndex, targetRoute, targetPointIndex)
    local point = route and route.points and route.points[pointIndex] or nil
    local targetPoint = targetRoute and targetRoute.points and targetRoute.points[targetPointIndex] or nil
    if not point or not targetPoint then
        return false
    end

    point.x = targetPoint.x
    point.y = targetPoint.y

    local targetSharedPointId = self:ensureSharedPointId(targetPoint)
    if point.sharedPointId and point.sharedPointId ~= targetSharedPointId then
        self:reassignSharedPointGroup(point.sharedPointId, targetSharedPointId)
    end
    point.sharedPointId = targetSharedPointId
    self:updateSharedPointGroup(targetSharedPointId, targetPoint.x, targetPoint.y)
    self:rebuildIntersections()
    self:showStatus("Bend points merged into a shared junction.")
    return true
end

function mapEditor:findEndpointAt(x, y, kind, excludeEndpointId)
    local radius = MERGE_SNAP_RADIUS / math.max(self.camera.zoom, 0.0001)
    for _, endpoint in ipairs(self.endpoints) do
        if endpoint.kind == kind and endpoint.id ~= excludeEndpointId then
            if distanceSquared(x, y, endpoint.x, endpoint.y) <= radius * radius then
                return endpoint
            end
        end
    end
    return nil
end

function mapEditor:findSegmentHit(x, y)
    local bestHit = nil
    local segmentRadius = SEGMENT_HIT_RADIUS / math.max(self.camera.zoom, HITBOX_OVERLAY_EPSILON)
    local bestDistance = segmentRadius * segmentRadius

    for routeIndex = #self.routes, 1, -1 do
        local route = self.routes[routeIndex]
        for pointIndex = 1, #route.points - 1 do
            local a = route.points[pointIndex]
            local b = route.points[pointIndex + 1]
            local closestX, closestY, t, distance = closestPointOnSegment(x, y, a, b)

            if distance < bestDistance and t > SEGMENT_HIT_MIN_T and t < SEGMENT_HIT_MAX_T then
                bestDistance = distance
                bestHit = {
                    route = route,
                    segmentIndex = pointIndex,
                    insertIndex = pointIndex + 1,
                    point = { x = closestX, y = closestY },
                }
            end
        end
    end

    return bestHit
end

function mapEditor:getPointHitRadius()
    return POINT_HIT_RADIUS / math.max(self.camera.zoom, HITBOX_OVERLAY_EPSILON)
end

function mapEditor:getIntersectionHitRadius(intersection)
    local baseRadius = intersection and intersection.unsupported and INTERSECTION_UNSUPPORTED_HIT_RADIUS or INTERSECTION_HIT_RADIUS
    return baseRadius / math.max(self.camera.zoom, HITBOX_OVERLAY_EPSILON)
end

function mapEditor:getOutputSelectorHitRect(intersection)
    return {
        x = intersection.x - INTERSECTION_SELECTOR_CLICK_RADIUS,
        y = intersection.y + INTERSECTION_SELECTOR_OFFSET_Y - INTERSECTION_SELECTOR_CLICK_RADIUS,
        w = INTERSECTION_SELECTOR_CLICK_RADIUS * 2,
        h = INTERSECTION_SELECTOR_CLICK_RADIUS * 2,
    }
end

function mapEditor:getRouteDebugName(route)
    local routeName = tostring(route and (route.label or route.id) or "")
    if routeName == "" then
        return "route"
    end
    return routeName
end

function mapEditor:getHitboxOverlayColor(index)
    local option = COLOR_OPTIONS[((index - 1) % #COLOR_OPTIONS) + 1]
    return option and option.color or COLOR_OPTIONS[1].color
end

function mapEditor:buildSegmentHitboxPolygon(pointA, pointB)
    local dx = pointB.x - pointA.x
    local dy = pointB.y - pointA.y
    local length = math.sqrt(dx * dx + dy * dy)

    if length <= HITBOX_OVERLAY_EPSILON then
        return nil
    end

    local startX = lerp(pointA.x, pointB.x, SEGMENT_HIT_MIN_T)
    local startY = lerp(pointA.y, pointB.y, SEGMENT_HIT_MIN_T)
    local endX = lerp(pointA.x, pointB.x, SEGMENT_HIT_MAX_T)
    local endY = lerp(pointA.y, pointB.y, SEGMENT_HIT_MAX_T)
    local normalX = -dy / length
    local normalY = dx / length
    local halfWidth = SEGMENT_HIT_RADIUS / math.max(self.camera.zoom, HITBOX_OVERLAY_EPSILON)

    return {
        points = {
            startX + normalX * halfWidth, startY + normalY * halfWidth,
            endX + normalX * halfWidth, endY + normalY * halfWidth,
            endX - normalX * halfWidth, endY - normalY * halfWidth,
            startX - normalX * halfWidth, startY - normalY * halfWidth,
        },
        labelX = (startX + endX) * 0.5,
        labelY = (startY + endY) * 0.5,
    }
end

function mapEditor:getHitboxOverlayEntries()
    local entries = {}

    for routeIndex = #self.routes, 1, -1 do
        local route = self.routes[routeIndex]
        local routeName = self:getRouteDebugName(route)

        for pointIndex = #route.points, 1, -1 do
            local point = route.points[pointIndex]
            local isMagnet = pointIndex == 1 or pointIndex == #route.points
            local isSharedJunctionPoint = not isMagnet and point.sharedPointId and self:getSharedPointGroupForPoint(route, pointIndex)

            if not isSharedJunctionPoint then
                local label = nil
                local rect = nil

                if pointIndex == 1 then
                    rect = self:getMagnetHitRect(point, "start")
                    label = string.format("%s start", routeName)
                elseif pointIndex == #route.points then
                    rect = self:getMagnetHitRect(point, "end")
                    label = string.format("%s end", routeName)
                else
                    local radius = self:getPointHitRadius()
                    rect = {
                        x = point.x - radius,
                        y = point.y - radius,
                        w = radius * 2,
                        h = radius * 2,
                    }
                    label = string.format("%s bend %d", routeName, pointIndex)
                end

                entries[#entries + 1] = {
                    kind = "rect",
                    rect = rect,
                    label = label,
                    labelX = rect.x + rect.w * 0.5,
                    labelY = rect.y + rect.h * 0.5,
                }
            end
        end
    end

    for _, intersection in ipairs(self.intersections) do
        if self:isIntersectionOutputSelectorHit(intersection, intersection.x, intersection.y + INTERSECTION_SELECTOR_OFFSET_Y) then
            local rect = self:getOutputSelectorHitRect(intersection)
            entries[#entries + 1] = {
                kind = "rect",
                rect = rect,
                label = string.format("%s output", tostring(intersection.routeKey or intersection.id or "junction")),
                labelX = rect.x + rect.w * 0.5,
                labelY = rect.y + rect.h * 0.5,
            }
        end
    end

    for _, intersection in ipairs(self.intersections) do
        local radius = self:getIntersectionHitRadius(intersection)
        entries[#entries + 1] = {
            kind = "rect",
            rect = {
                x = intersection.x - radius,
                y = intersection.y - radius,
                w = radius * 2,
                h = radius * 2,
            },
            label = string.format("%s %s", tostring(intersection.routeKey or intersection.id or "junction"), intersection.controlType or "junction"),
            labelX = intersection.x,
            labelY = intersection.y,
        }
    end

    for routeIndex = #self.routes, 1, -1 do
        local route = self.routes[routeIndex]
        local routeName = self:getRouteDebugName(route)

        for segmentIndex = 1, #route.points - 1 do
            local polygon = self:buildSegmentHitboxPolygon(route.points[segmentIndex], route.points[segmentIndex + 1])
            if polygon then
                entries[#entries + 1] = {
                    kind = "polygon",
                    points = polygon.points,
                    label = string.format("%s segment %d", routeName, segmentIndex),
                    labelX = polygon.labelX,
                    labelY = polygon.labelY,
                }
            end
        end
    end

    local totalEntries = #entries
    for index, entry in ipairs(entries) do
        entry.zIndex = totalEntries - index + 1
        entry.color = self:getHitboxOverlayColor(index)
        entry.label = string.format("Z%d %s", entry.zIndex, entry.label)
    end

    return entries
end

function mapEditor:deleteSelection()
    local selectedRoute = self:getSelectedRoute()
    if not selectedRoute then
        return
    end

    self:closeColorPicker()
    self:closeRouteTypePicker()

    if self.selectedPointIndex and self.selectedPointIndex > 1 and self.selectedPointIndex < #selectedRoute.points then
        self:mergeRouteSegmentStyle(selectedRoute, self.selectedPointIndex)
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
    local bestDistanceSquared = nil
    local bestControlType = nil

    for _, imported in ipairs(self.importedJunctionState[intersection.routeKey] or {}) do
        local candidateDistanceSquared = distanceSquared(imported.x, imported.y, intersection.x, intersection.y)
        if candidateDistanceSquared <= INTERSECTION_STATE_MATCH_DISTANCE_SQUARED
            and (not bestDistanceSquared or candidateDistanceSquared < bestDistanceSquared) then
            bestDistanceSquared = candidateDistanceSquared
            bestControlType = imported.controlType
        end
    end

    for _, previous in ipairs(previousMatches) do
        if previous.routeKey == intersection.routeKey then
            local candidateDistanceSquared = distanceSquared(previous.x, previous.y, intersection.x, intersection.y)
            if candidateDistanceSquared <= INTERSECTION_STATE_MATCH_DISTANCE_SQUARED
                and (not bestDistanceSquared or candidateDistanceSquared < bestDistanceSquared) then
                bestDistanceSquared = candidateDistanceSquared
                bestControlType = previous.controlType
            end
        end
    end

    if bestControlType then
        return bestControlType
    end

    return DEFAULT_CONTROL
end

function mapEditor:getJunctionState(intersection, previousMatches)
    local bestDistanceSquared = nil
    local bestMatch = nil

    for _, imported in ipairs(self.importedJunctionState[intersection.routeKey] or {}) do
        local candidateDistanceSquared = distanceSquared(imported.x, imported.y, intersection.x, intersection.y)
        if candidateDistanceSquared <= INTERSECTION_STATE_MATCH_DISTANCE_SQUARED
            and (not bestDistanceSquared or candidateDistanceSquared < bestDistanceSquared) then
            bestDistanceSquared = candidateDistanceSquared
            bestMatch = imported
        end
    end

    for _, previous in ipairs(previousMatches) do
        if previous.routeKey == intersection.routeKey then
            local candidateDistanceSquared = distanceSquared(previous.x, previous.y, intersection.x, intersection.y)
            if candidateDistanceSquared <= INTERSECTION_STATE_MATCH_DISTANCE_SQUARED
                and (not bestDistanceSquared or candidateDistanceSquared < bestDistanceSquared) then
                bestDistanceSquared = candidateDistanceSquared
                bestMatch = previous
            end
        end
    end

    if bestMatch then
        return bestMatch
    end

    return nil
end

function mapEditor:getRoutesPassingThroughPoint(routeIds, point, toleranceSquared)
    local matchedRouteIds = {}
    local distanceScore = 0

    for _, routeId in ipairs(routeIds or {}) do
        local route = self:getRouteById(routeId)
        local bestDistanceSquared = nil

        if route and route.points and #route.points >= 2 then
            for pointIndex = 1, #route.points - 1 do
                local a = route.points[pointIndex]
                local b = route.points[pointIndex + 1]
                local _, _, _, segmentDistanceSquared = closestPointOnSegment(point.x, point.y, a, b)
                if not bestDistanceSquared or segmentDistanceSquared < bestDistanceSquared then
                    bestDistanceSquared = segmentDistanceSquared
                end
            end
        end

        if bestDistanceSquared and bestDistanceSquared <= (toleranceSquared or 4) then
            matchedRouteIds[#matchedRouteIds + 1] = routeId
            distanceScore = distanceScore + bestDistanceSquared
        end
    end

    local routeKey, sortedRouteIds = buildRouteKey(matchedRouteIds)
    return sortedRouteIds, routeKey, distanceScore
end

function mapEditor:resolveGroupedIntersections(groupedIntersection)
    local resolved = {}
    local candidatesByRouteKey = {}
    local clusterRadiusSquared = STRICT_INTERSECTION_CLUSTER_RADIUS * STRICT_INTERSECTION_CLUSTER_RADIUS

    for _, hit in ipairs(groupedIntersection.hits or {}) do
        local routeIds, routeKey, distanceScore = self:getRoutesPassingThroughPoint(
            groupedIntersection.routeIds,
            hit,
            4
        )

        if #routeIds >= 2 then
            candidatesByRouteKey[routeKey] = candidatesByRouteKey[routeKey] or {}

            local targetCluster = nil
            for _, cluster in ipairs(candidatesByRouteKey[routeKey]) do
                if distanceSquared(cluster.x, cluster.y, hit.x, hit.y) <= clusterRadiusSquared then
                    targetCluster = cluster
                    break
                end
            end

            if not targetCluster then
                targetCluster = {
                    x = hit.x,
                    y = hit.y,
                    routeIds = routeIds,
                    candidates = {},
                }
                candidatesByRouteKey[routeKey][#candidatesByRouteKey[routeKey] + 1] = targetCluster
            end

            targetCluster.candidates[#targetCluster.candidates + 1] = {
                x = hit.x,
                y = hit.y,
                distanceScore = distanceScore,
            }
        end
    end

    for routeKey, clusters in pairs(candidatesByRouteKey) do
        for _, cluster in ipairs(clusters) do
            local bestCandidate = chooseBestCandidatePoint(cluster.candidates)
            if bestCandidate then
                resolved[#resolved + 1] = {
                    id = buildIntersectionId(routeKey, bestCandidate),
                    x = bestCandidate.x,
                    y = bestCandidate.y,
                    routeIds = cluster.routeIds,
                }
            end
        end
    end

    return resolved
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

function mapEditor:isSharedEndpointIntersection(groupedIntersection)
    local sharedStartEndpointId = nil
    local sharedEndEndpointId = nil
    local allAtSharedStart = true
    local allAtSharedEnd = true
    local toleranceSquared = 12 * 12

    for _, routeId in ipairs(groupedIntersection.routeIds or {}) do
        local route = self:getRouteById(routeId)
        if not route or not route.points or #route.points < 2 then
            return false
        end

        local startPoint = route.points[1]
        local endPoint = route.points[#route.points]
        local touchesStart = distanceSquared(startPoint.x, startPoint.y, groupedIntersection.x, groupedIntersection.y) <= toleranceSquared
        local touchesEnd = distanceSquared(endPoint.x, endPoint.y, groupedIntersection.x, groupedIntersection.y) <= toleranceSquared

        if not touchesStart then
            allAtSharedStart = false
        elseif sharedStartEndpointId and sharedStartEndpointId ~= route.startEndpointId then
            allAtSharedStart = false
        else
            sharedStartEndpointId = route.startEndpointId
        end

        if not touchesEnd then
            allAtSharedEnd = false
        elseif sharedEndEndpointId and sharedEndEndpointId ~= route.endEndpointId then
            allAtSharedEnd = false
        else
            sharedEndEndpointId = route.endEndpointId
        end
    end

    return (allAtSharedStart and sharedStartEndpointId ~= nil)
        or (allAtSharedEnd and sharedEndEndpointId ~= nil)
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
                        local groupX = math.floor(hit.x / INTERSECTION_GROUP_BUCKET + 0.5) * INTERSECTION_GROUP_BUCKET
                        local groupY = math.floor(hit.y / INTERSECTION_GROUP_BUCKET + 0.5) * INTERSECTION_GROUP_BUCKET
                        local groupKey = groupX .. ":" .. groupY
                        local entry = grouped[groupKey]

                        if not entry then
                            entry = {
                                x = hit.x,
                                y = hit.y,
                                routeIds = {},
                                routeLookup = {},
                                hits = {},
                            }
                            grouped[groupKey] = entry
                        else
                            entry.x = (entry.x + hit.x) * 0.5
                            entry.y = (entry.y + hit.y) * 0.5
                        end

                        entry.hits[#entry.hits + 1] = { x = hit.x, y = hit.y }

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
        for _, strictIntersection in ipairs(self:resolveGroupedIntersections(groupedIntersection)) do
            if self:isSharedEndpointIntersection(strictIntersection) then
                goto continue_strict_intersection
            end

            local routeKey = table.concat(strictIntersection.routeIds, "|")
            local inputEndpointIds = {}
            local outputEndpointIds = {}
            local inputLookup = {}
            local outputLookup = {}
            local inputRouteIds = {}
            local outputRouteIds = {}

            for _, routeId in ipairs(strictIntersection.routeIds) do
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
                id = strictIntersection.id,
                x = strictIntersection.x,
                y = strictIntersection.y,
                routeIds = strictIntersection.routeIds,
                routeKey = routeKey,
                inputEndpointIds = inputEndpointIds,
                outputEndpointIds = outputEndpointIds,
                inputRouteIds = inputRouteIds,
                outputRouteIds = outputRouteIds,
            }
            local state = self:getJunctionState(intersection, previousIntersections)
            intersection.controlType = self:getIntersectionControlType(intersection, previousIntersections)
            intersection.passCount = math.max(1, math.min(MAX_TRIP_PASS_COUNT, (state and state.passCount) or DEFAULT_CONTROL_CONFIGS.trip.passCount))
            intersection.activeInputIndex = math.min((state and state.activeInputIndex) or 1, math.max(1, #inputRouteIds))
            intersection.activeOutputIndex = math.min((state and state.activeOutputIndex) or 1, math.max(1, #outputEndpointIds))
            self.intersections[#self.intersections + 1] = intersection

            ::continue_strict_intersection::
        end
    end

    table.sort(self.intersections, function(a, b)
        if math.abs(a.y - b.y) > 1 then
            return a.y < b.y
        end
        return a.x < b.x
    end)

    self:refreshValidation()
end

function mapEditor:beginRoute(x, y)
    local colorOption = COLOR_OPTIONS[((self.nextRouteId - 1) % #COLOR_OPTIONS) + 1]
    local startX, startY = self:clampPoint(x, y, false)
    local route = self:createRoute(
        {
            { x = startX, y = startY },
            { x = startX, y = startY },
        },
        colorOption.color,
        nil,
        nil,
        colorOption.id,
        { colorOption.id },
        { colorOption.id },
        nil,
        nil,
        { DEFAULT_ROAD_TYPE }
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
    self:closeRouteTypePicker()
    self:rebuildIntersections()
end

function mapEditor:updateDraggedPoint(x, y)
    if not self.drag then
        return
    end

    if self.drag.kind == "intersection" then
        local movedDistance = distanceSquared(x, y, self.drag.startMouseX, self.drag.startMouseY)
        if movedDistance > DRAG_START_DISTANCE_SQUARED then
            self.drag.moved = true
        end

        if not self.drag.moved then
            return
        end

        if not self.drag.sharedPointId then
            local liveIntersection = self:getIntersectionById(self.drag.intersectionId)
            local preparedDrag = self:prepareIntersectionForDrag(liveIntersection or self.drag.intersectionSnapshot)
            if not preparedDrag then
                return
            end
            self.drag.sharedPointId = preparedDrag.sharedPointId
            self.drag.routeId = preparedDrag.routeId
            self.drag.pointIndex = preparedDrag.pointIndex
            self.selectedRouteId = preparedDrag.routeId
            self.selectedPointIndex = preparedDrag.pointIndex
        end

        local clampedX, clampedY = self:clampPoint(x, y, false)
        self:updateSharedPointGroup(self.drag.sharedPointId, clampedX, clampedY)
        self:closeColorPicker()
        self:closeRouteTypePicker()
        self:rebuildIntersections()
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
    if movedDistance > DRAG_START_DISTANCE_SQUARED then
        self.drag.moved = true
    end

    if not self.drag.moved then
        return
    end

    local clampedX, clampedY = self:clampPoint(x, y, self.drag.pointIndex == 1)
    if self:isModifierSnapActive() then
        clampedX, clampedY = self:snapPointToGrid(clampedX, clampedY)
        clampedX, clampedY = self:clampPoint(clampedX, clampedY, self.drag.pointIndex == 1)
    end
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
        if point.sharedPointId then
            self:updateSharedPointGroup(point.sharedPointId, clampedX, clampedY)
        end
    end
    self:closeColorPicker()
    self:rebuildIntersections()
end

function mapEditor:ensureRoutePointAtIntersection(route, intersectionPoint)
    if not route or not route.points or #route.points < 2 then
        return nil, nil
    end

    for pointIndex = 2, #route.points - 1 do
        local point = route.points[pointIndex]
        if distanceSquared(point.x, point.y, intersectionPoint.x, intersectionPoint.y) <= INTERSECTION_POINT_TOLERANCE_SQUARED then
            return pointIndex, point
        end
    end

    for segmentIndex = 1, #route.points - 1 do
        local pointA = route.points[segmentIndex]
        local pointB = route.points[segmentIndex + 1]
        local hitPoint = pointOnSegment(intersectionPoint, pointA, pointB, INTERSECTION_POINT_TOLERANCE_SQUARED)
        if hitPoint then
            if distanceSquared(hitPoint.x, hitPoint.y, pointA.x, pointA.y) <= INTERNAL_POINT_MATCH_DISTANCE_SQUARED and segmentIndex > 1 then
                return segmentIndex, pointA
            end
            if distanceSquared(hitPoint.x, hitPoint.y, pointB.x, pointB.y) <= INTERNAL_POINT_MATCH_DISTANCE_SQUARED
                and (segmentIndex + 1) < #route.points then
                return segmentIndex + 1, pointB
            end

            local insertIndex = segmentIndex + 1
            table.insert(route.points, insertIndex, hitPoint)
            self:splitRouteSegmentStyle(route, segmentIndex)
            return insertIndex, route.points[insertIndex]
        end
    end

    return nil, nil
end

function mapEditor:prepareIntersectionForDrag(intersection)
    if not intersection then
        return nil
    end

    local members = {}
    local sharedPointId = nil

    for _, routeId in ipairs(intersection.routeIds or {}) do
        local route = self:getRouteById(routeId)
        local pointIndex, point = self:ensureRoutePointAtIntersection(route, intersection)
        if route and pointIndex and point then
            members[#members + 1] = {
                route = route,
                pointIndex = pointIndex,
                point = point,
            }
            if point.sharedPointId and not sharedPointId then
                sharedPointId = point.sharedPointId
            end
        end
    end

    if #members == 0 then
        return nil
    end

    if not sharedPointId then
        sharedPointId = self.nextSharedPointId
        self.nextSharedPointId = self.nextSharedPointId + 1
    end

    for _, member in ipairs(members) do
        if member.point.sharedPointId and member.point.sharedPointId ~= sharedPointId then
            self:reassignSharedPointGroup(member.point.sharedPointId, sharedPointId)
        end
        member.point.sharedPointId = sharedPointId
    end
    self:updateSharedPointGroup(sharedPointId, intersection.x, intersection.y)
    self:rebuildIntersections()

    return {
        sharedPointId = sharedPointId,
        routeId = members[1].route.id,
        pointIndex = members[1].pointIndex,
    }
end

function mapEditor:isIntersectionOutputSelectorHit(intersection, x, y)
    if not intersection or #intersection.outputEndpointIds <= 1 then
        return false
    end
    return distanceSquared(x, y, intersection.x, intersection.y + INTERSECTION_SELECTOR_OFFSET_Y)
        <= INTERSECTION_SELECTOR_CLICK_RADIUS * INTERSECTION_SELECTOR_CLICK_RADIUS
end

function mapEditor:findIntersectionOutputSelectorHit(x, y)
    for _, intersection in ipairs(self.intersections) do
        if self:isIntersectionOutputSelectorHit(intersection, x, y) then
            return intersection
        end
    end

    return nil
end

function mapEditor:setIntersectionControlType(intersection, controlType)
    if not intersection or not controlType then
        return false
    end
    if intersection.unsupported then
        self:showStatus("Junctions currently support up to five inputs and five outputs.")
        return false
    end
    if intersection.controlType == controlType then
        return false
    end

    intersection.controlType = controlType
    if intersection.controlType == "relay" then
        self:syncIntersectionOutputToControl(intersection)
    elseif intersection.controlType == "crossbar" then
        self:syncIntersectionOutputToControl(intersection)
    end

    self:refreshValidation(self.currentMapName)
    self:showStatus("Intersection switched to " .. self:getControlName(intersection.controlType) .. ".")
    return true
end

function mapEditor:cycleIntersection(intersection)
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

    self:setIntersectionControlType(intersection, CONTROL_ORDER[nextIndex])
end

function mapEditor:syncIntersectionOutputToControl(intersection)
    if not intersection then
        return
    end

    local outputCount = #(intersection.outputEndpointIds or {})
    if outputCount <= 0 then
        intersection.activeOutputIndex = 1
        return
    end

    if intersection.controlType == "relay" then
        intersection.activeOutputIndex = math.min(intersection.activeInputIndex or 1, outputCount)
    elseif intersection.controlType == "crossbar" then
        intersection.activeOutputIndex = math.max(1, outputCount - (intersection.activeInputIndex or 1) + 1)
    else
        intersection.activeOutputIndex = clamp(intersection.activeOutputIndex or 1, 1, outputCount)
    end
end

function mapEditor:cycleIntersectionInput(intersection)
    if not intersection then
        return false
    end
    if intersection.unsupported then
        self:showStatus("Junctions currently support up to five inputs and five outputs.")
        return false
    end

    local inputCount = #(intersection.inputRouteIds or {})
    if inputCount <= 1 then
        intersection.activeInputIndex = 1
        self:syncIntersectionOutputToControl(intersection)
        return false
    end

    intersection.activeInputIndex = (intersection.activeInputIndex or 1) + 1
    if intersection.activeInputIndex > inputCount then
        intersection.activeInputIndex = 1
    end

    self:syncIntersectionOutputToControl(intersection)
    self:refreshValidation(self.currentMapName)
    self:showStatus("Junction start switched to " .. intersection.activeInputIndex .. ".")
    return true
end

function mapEditor:cycleIntersectionOutput(intersection, direction)
    if intersection.controlType == "relay" or intersection.controlType == "crossbar" then
        self:showStatus("This dial couples start and end together.")
        return
    end

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

    self:refreshValidation(self.currentMapName)
    self:showStatus("Junction end switched to " .. intersection.activeOutputIndex .. ".")
end

function mapEditor:cycleIntersectionPassCount(intersection, direction)
    if intersection.controlType ~= "trip" then
        return false
    end

    local nextPassCount = (intersection.passCount or DEFAULT_CONTROL_CONFIGS.trip.passCount) + direction
    if nextPassCount < 1 then
        nextPassCount = MAX_TRIP_PASS_COUNT
    elseif nextPassCount > MAX_TRIP_PASS_COUNT then
        nextPassCount = 1
    end

    intersection.passCount = nextPassCount
    self:showStatus("Trip switch now waits for " .. nextPassCount .. " train(s).")
    self:refreshValidation(self.currentMapName)
    return true
end

function mapEditor:toggleMagnetColor(route, magnetKind, colorId)
    if magnetKind == "start" then
        self:showStatus("Starts use a single fixed color.")
        return
    end

    local endpoint = magnetKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route)
    if not endpoint then
        return
    end
    local lookup = endpoint.colors
    if lookup[colorId] then
        if countLookupEntries(lookup) <= 1 then
            self:showStatus("Each endpoint needs at least one allowed color.")
            return
        end
        lookup[colorId] = nil
    else
        lookup[colorId] = true
    end

    self:showStatus((magnetKind == "start" and "Start" or "End") .. " colors updated.")
end

function mapEditor:splitEndpointColor(route, magnetKind, colorId, startMouseX, startMouseY)
    if magnetKind ~= "end" then
        return false
    end

    local endpoint = magnetKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route)
    if not endpoint or not endpoint.colors[colorId] or countLookupEntries(endpoint.colors) <= 1 then
        self:showStatus("That color cannot be split from this endpoint.")
        return false
    end

    local matchingRoutes = {}
    for _, candidateRoute in ipairs(self.routes) do
        if candidateRoute.endEndpointId == endpoint.id and candidateRoute.colorId == colorId then
            matchingRoutes[#matchingRoutes + 1] = candidateRoute
        end
    end

    if #matchingRoutes == 0 then
        self:showStatus("That color is not present on this end.")
        return false
    end

    endpoint.colors[colorId] = nil
    local newEndpoint = self:createEndpoint(
        endpoint.kind,
        endpoint.x + (magnetKind == "start" and 38 or 48),
        endpoint.y + 18,
        { colorId }
    )

    for _, matchingRoute in ipairs(matchingRoutes) do
        if magnetKind == "start" then
            matchingRoute.startEndpointId = newEndpoint.id
        else
            matchingRoute.endEndpointId = newEndpoint.id
        end
        self:updateRouteEndpointPoint(matchingRoute, magnetKind)
    end

    local activeRoute = route.colorId == colorId and route or matchingRoutes[1]
    self.selectedRouteId = activeRoute.id
    self.selectedPointIndex = magnetKind == "start" and 1 or #activeRoute.points
    self.drag = {
        kind = "point",
        routeId = activeRoute.id,
        pointIndex = self.selectedPointIndex,
        startMouseX = startMouseX or newEndpoint.x,
        startMouseY = startMouseY or newEndpoint.y,
        moved = true,
        isMagnet = true,
        magnetKind = magnetKind,
    }
    self:closeColorPicker()
    self:rebuildIntersections()
    self:showStatus("Color split into a new " .. (endpoint.kind == "input" and "start" or "end") .. " endpoint.")
    return true
end

function mapEditor:splitSharedJunctionColor(intersection, colorId, startMouseX, startMouseY)
    local group = self:getSharedPointGroupForIntersection(intersection)
    if not group or not group.colorLookup[colorId] or #group.colorIds <= 1 then
        self:showStatus("That color cannot be split from this merger lane.")
        return false
    end

    local matchingMembers = {}
    for _, member in ipairs(group.members) do
        if member.route.colorId == colorId then
            matchingMembers[#matchingMembers + 1] = member
        end
    end

    if #matchingMembers == 0 then
        self:showStatus("That color is not present on this merger lane.")
        return false
    end

    local newSharedPointId = self.nextSharedPointId
    self.nextSharedPointId = self.nextSharedPointId + 1

    for _, member in ipairs(matchingMembers) do
        member.point.sharedPointId = newSharedPointId
    end

    local selectedMember = matchingMembers[1]
    self.selectedRouteId = selectedMember.route.id
    self.selectedPointIndex = selectedMember.pointIndex
    self.drag = {
        kind = "point",
        routeId = selectedMember.route.id,
        pointIndex = selectedMember.pointIndex,
        startMouseX = startMouseX or intersection.x,
        startMouseY = startMouseY or intersection.y,
        moved = true,
        isMagnet = false,
        magnetKind = nil,
        splitOriginSharedPointId = group.sharedPointId,
    }
    self:closeColorPicker()
    self:rebuildIntersections()
    self:showStatus("Drag to split that color out of the merger lane.")
    return true
end

function mapEditor:mergeEndpointInto(route, magnetKind, targetEndpoint)
    if magnetKind == "start" then
        return false
    end

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
    self:showStatus(currentEndpoint.kind == "input" and "Starts merged." or "Ends merged.")
    return true
end

function mapEditor:getActiveTextFieldValue(kind, targetId, fieldName, fallback)
    local field = self.activeTextField
    if field
        and field.kind == kind
        and field.targetId == targetId
        and field.fieldName == fieldName then
        return field.buffer
    end
    return fallback
end

function mapEditor:openTextField(kind, targetId, fieldName, buffer, valueType)
    self.activeTextField = {
        kind = kind,
        targetId = targetId,
        fieldName = fieldName,
        buffer = buffer or "",
        valueType = valueType,
    }
end

function mapEditor:cancelTextField()
    self.activeTextField = nil
end

function mapEditor:commitTextField()
    local field = self.activeTextField
    if not field then
        return false
    end

    local target = nil
    if field.kind == "map" then
        target = self
    elseif field.kind == "train" then
        target = self:getTrainById(field.targetId)
    end

    if not target then
        self.activeTextField = nil
        return false
    end

    local rawValue = field.buffer or ""
    local trimmedValue = rawValue:gsub("^%s+", ""):gsub("%s+$", "")
    local changed = false

    if field.kind == "map" and field.fieldName == "gridStep" then
        local numericValue = tonumber(trimmedValue)
        self.activeTextField = nil
        if numericValue then
            self.gridStep = sanitizeGridStep(numericValue)
            self:notifyPreferencesChanged()
            self:showStatus(string.format("Grid step set to %d.", self.gridStep))
            return true
        end
        return false
    end

    if trimmedValue == "" then
        if field.valueType == "optional_float" then
            target[field.fieldName] = nil
            changed = true
        end
    else
        local numericValue = tonumber(trimmedValue)
        if numericValue then
            if field.valueType == "int" then
                numericValue = math.max(1, math.floor(numericValue))
            else
                numericValue = math.max(0, numericValue)
            end
            target[field.fieldName] = numericValue
            changed = true
        end
    end

    if field.kind == "train" and target.deadline ~= nil and target.deadline < target.spawnTime then
        target.deadline = target.spawnTime
    end

    self.activeTextField = nil

    if changed then
        self:refreshValidation()
        self:showStatus("Sequencer updated.")
    end

    return changed
end

function mapEditor:appendTextFieldInput(text)
    local field = self.activeTextField
    if not field then
        return
    end

    local filtered = {}
    for index = 1, #text do
        local character = text:sub(index, index)
        if character:match("%d") then
            filtered[#filtered + 1] = character
        elseif character == "." and field.valueType ~= "int" and not field.buffer:find("%.", 1, true) then
            filtered[#filtered + 1] = character
        end
    end

    if #filtered > 0 then
        field.buffer = field.buffer .. table.concat(filtered)
    end
end

function mapEditor:handleColorPickerClick(x, y, button)
    local layout = self:getColorPickerLayout()
    if not layout then
        return false
    end

    if layout.kind == "junction_radial" then
        local rawX = x
        local rawY = y
        x, y = self:screenToJunctionPickerSpace(x, y)
        local intersection = nil
        local route = nil
        if self.colorPicker.mode == "junction" then
            intersection = self:getIntersectionById(self.colorPicker.intersectionId)
            if not intersection then
                self:closeColorPicker()
                return true
            end
        elseif self.colorPicker.mode == "route_end" then
            route = self:getRouteById(self.colorPicker.routeId)
            if not route then
                self:closeColorPicker()
                return true
            end
        end

        local insideRoot = not layout.branch
            and distanceSquared(x, y, layout.root.x, layout.root.y) <= layout.root.radius * layout.root.radius
        local insideSubmenu = layout.submenu
            and distanceSquared(x, y, layout.submenu.x, layout.submenu.y) <= layout.submenu.radius * layout.submenu.radius

        if not insideRoot and not insideSubmenu then
            self:closeColorPicker()
            return false
        end

        if insideRoot and not layout.branch then
            local selectedBranch = self:getJunctionPickerRootHover(x, y)
            if selectedBranch == "disconnect" and #self:getColorPickerOptions() == 0 then
                selectedBranch = nil
            end
            if selectedBranch then
                self.colorPicker.branch = selectedBranch
                self.colorPicker.hoverBranch = nil
                self.colorPicker.hoverOptionIndex = nil
                self:restartJunctionPickerPopup(rawX, rawY)
            end
            return true
        end

        if layout.submenu then
            local hitEntry = self:getJunctionPickerOptionHit(layout.submenu, x, y)
            if hitEntry then
                if layout.submenu.branch == "disconnect" then
                    if self.colorPicker.mode == "junction" then
                        self:splitSharedJunctionColor(intersection, hitEntry.option.id, rawX, rawY)
                    elseif self.colorPicker.mode == "route_end" then
                        local mapX, mapY = self:screenToMap(rawX, rawY)
                        self:splitEndpointColor(route, "end", hitEntry.option.id, mapX, mapY)
                    end
                else
                    self:setIntersectionControlType(intersection, hitEntry.option.controlType)
                    self:closeColorPicker()
                end
                return true
            end
        end

        self:updateJunctionPickerHover(x, y)
        return true
    end

    if not pointInRect(x, y, layout.rect) then
        self:closeColorPicker()
        return false
    end

    for _, swatch in ipairs(layout.swatches) do
        if pointInRect(x, y, swatch.rect) then
            if self.colorPicker.mode == "sequencer" then
                local train = self:getTrainById(self.colorPicker.trainId)
                if train then
                    train[self.colorPicker.fieldName] = swatch.option.id
                    self:refreshValidation()
                    self:showStatus("Sequencer updated.")
                end
                self:closeColorPicker()
                return true
            end

            if self.colorPicker.mode == "junction" then
                local intersection = self:getIntersectionById(self.colorPicker.intersectionId)
                if not intersection then
                    self:closeColorPicker()
                    return true
                end

                local group = self:getSharedPointGroupForIntersection(intersection)
                if not group or not group.colorLookup[swatch.option.id] then
                    self:showStatus("Choose one of the colors already merged into this lane.")
                    return true
                end

                local mapX, mapY = self:screenToMap(x, y)
                self:splitSharedJunctionColor(intersection, swatch.option.id, mapX, mapY)
                return true
            end

            local route = self:getSelectedRoute()
            if not route or route.id ~= self.colorPicker.routeId then
                self:closeColorPicker()
                return true
            end

            local endpoint = self.colorPicker.magnetKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route)
            local lookup = endpoint and endpoint.colors or {}
            if not lookup[swatch.option.id] then
                self:showStatus("Choose one of the colors already merged into this endpoint.")
                return true
            end
            local mapX, mapY = self:screenToMap(x, y)
            self:splitEndpointColor(route, self.colorPicker.magnetKind, swatch.option.id, mapX, mapY)
            return true
        end
    end

    return true
end

function mapEditor:getTextFieldRect(x, y, width)
    return {
        x = x,
        y = y,
        w = width,
        h = 26,
    }
end

function mapEditor:getSequencerSummaryRects(rowRect)
    local x = rowRect.x + 8
    local y = rowRect.y + 8
    local gap = 4

    local startRect = { x = x, y = y, w = 34, h = 18 }
    local nameRect = { x = startRect.x + startRect.w + gap, y = y, w = 60, h = 18 }
    local lineRect = { x = nameRect.x + nameRect.w + gap, y = y, w = 16, h = 16 }
    local goalRect = { x = lineRect.x + lineRect.w + gap, y = y, w = 16, h = 16 }
    local wagonsRect = { x = goalRect.x + goalRect.w + gap, y = y, w = 30, h = 18 }
    local removeRect = { x = rowRect.x + rowRect.w - 20, y = rowRect.y + 8, w = 16, h = 16 }
    local deadlineRect = {
        x = wagonsRect.x + wagonsRect.w + gap,
        y = y,
        w = math.max(42, removeRect.x - gap - (wagonsRect.x + wagonsRect.w + gap)),
        h = 18,
    }

    return {
        start = startRect,
        name = nameRect,
        lineChip = lineRect,
        goalChip = goalRect,
        wagons = wagonsRect,
        deadline = deadlineRect,
        remove = removeRect,
    }
end

function mapEditor:getSequencerRowControlRects(rowRect)
    return {
        summary = self:getSequencerSummaryRects(rowRect),
    }
end

function mapEditor:handleSequencerClick(x, y, button)
    local layout = self:getSequencerLayout()
    local deadlineRect = layout.mapDeadlineRect

    if self.colorPicker then
        self:closeColorPicker()
    end

    if pointInRect(x, y, layout.backRect) then
        self:commitTextField()
        self.sidePanelMode = "default"
        self:showStatus("Returned to the map editor pane.")
        return true
    end

    if pointInRect(x, y, layout.addRect) then
        self:commitTextField()
        self:addTrain()
        return true
    end

    if pointInRect(x, y, deadlineRect) then
        self:commitTextField()
        self:openTextField("map", "map", "timeLimit", self.timeLimit and tostring(self.timeLimit) or "", "optional_float")
        return true
    end

    if layout.scrollbar and pointInRect(x, y, layout.scrollbar.thumb) then
        self:commitTextField()
        self.sequencerScrollDrag = {
            offsetY = y - layout.scrollbar.thumb.y,
            track = layout.scrollbar.track,
            thumbHeight = layout.scrollbar.thumb.h,
            maxScroll = layout.scrollbar.maxScroll,
        }
        return true
    end

    if layout.scrollbar and pointInRect(x, y, layout.scrollbar.track) then
        self:commitTextField()
        local thumbTravel = math.max(1, layout.scrollbar.track.h - layout.scrollbar.thumb.h)
        local targetY = clamp(y - layout.scrollbar.thumb.h * 0.5, layout.scrollbar.track.y, layout.scrollbar.track.y + thumbTravel)
        self.sequencerScroll = ((targetY - layout.scrollbar.track.y) / thumbTravel) * layout.scrollbar.maxScroll
        return true
    end

    for _, row in ipairs(layout.rows) do
        local train = row.entry.train
        local controls = self:getSequencerRowControlRects(row.rect)
        if pointInRect(x, y, controls.summary.remove) then
            self:commitTextField()
            self:removeTrainByIndex(row.entry.trainIndex)
            return true
        end

        if pointInRect(x, y, controls.summary.lineChip) then
            self:commitTextField()
            self:openSequencerColorPicker(train.id, "lineColor", controls.summary.lineChip.x, controls.summary.lineChip.y)
            return true
        end

        if pointInRect(x, y, controls.summary.goalChip) then
            self:commitTextField()
            self:openSequencerColorPicker(train.id, "trainColor", controls.summary.goalChip.x, controls.summary.goalChip.y)
            return true
        end

        if pointInRect(x, y, controls.summary.start) then
            self:commitTextField()
            self:openTextField("train", train.id, "spawnTime", tostring(train.spawnTime or 0), "float")
            return true
        end

        if pointInRect(x, y, controls.summary.wagons) then
            self:commitTextField()
            self:openTextField("train", train.id, "wagonCount", tostring(train.wagonCount or DEFAULT_TRAIN_WAGONS), "int")
            return true
        end

        if pointInRect(x, y, controls.summary.deadline) then
            self:commitTextField()
            self:openTextField("train", train.id, "deadline", train.deadline and tostring(train.deadline) or "", "optional_float")
            return true
        end
    end

    self:commitTextField()
    return pointInRect(x, y, self.sidePanel)
end

function mapEditor:splitRouteSegmentStyle(route, segmentIndex)
    local segmentRoadTypes = self:ensureRouteSegmentRoadTypes(route)
    local duplicatedRoadType = segmentRoadTypes[segmentIndex] or DEFAULT_ROAD_TYPE
    table.insert(segmentRoadTypes, segmentIndex + 1, duplicatedRoadType)
end

function mapEditor:mergeRouteSegmentStyle(route, selectedPointIndex)
    local segmentRoadTypes = self:ensureRouteSegmentRoadTypes(route)
    table.remove(segmentRoadTypes, selectedPointIndex)
end

function mapEditor:setRouteSegmentRoadType(route, segmentIndex, roadType)
    if not route or not segmentIndex then
        return
    end

    local normalizedRoadType = roadTypes.normalizeRoadType(roadType)
    local segmentRoadTypes = self:ensureRouteSegmentRoadTypes(route)
    if not segmentRoadTypes[segmentIndex] then
        return
    end

    segmentRoadTypes[segmentIndex] = normalizedRoadType
    self:refreshValidation()
    self:showStatus("Segment road type set to " .. roadTypes.getConfig(normalizedRoadType).label .. ".")
end

function mapEditor:handleRouteTypePickerClick(x, y)
    local layout = self:getRouteTypePickerLayout()
    if not layout then
        return false
    end

    if not pointInRect(x, y, layout.rect) then
        self:closeRouteTypePicker()
        return false
    end

    local route = self:getRouteById(self.routeTypePicker.routeId)
    if not route then
        self:closeRouteTypePicker()
        return true
    end

    for _, optionEntry in ipairs(layout.options) do
        if pointInRect(x, y, optionEntry.rect) then
            self:setRouteSegmentRoadType(route, self.routeTypePicker.segmentIndex, optionEntry.option.id)
            self:closeRouteTypePicker()
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
        return true
    end

    if self.dialog.type == "open" then
        local layout = self:getOpenDialogListLayout()
        if layout.scrollbar and pointInRect(x, y, layout.scrollbar.track) then
            local thumbTravel = math.max(1, layout.scrollbar.track.h - layout.scrollbar.thumb.h)
            local thumbY = clamp(y - layout.scrollbar.thumb.h * 0.5, layout.scrollbar.track.y, layout.scrollbar.track.y + thumbTravel)
            self.dialog.scroll = ((thumbY - layout.scrollbar.track.y) / thumbTravel) * layout.scrollbar.maxScroll
            self.dialog.scroll = math.floor(self.dialog.scroll + 0.5)
            return true
        end

        for _, row in ipairs(layout.rows) do
            if pointInRect(x, y, row.rect) then
                self:openDialogMap(row.map)
                self:closeDialog()
                return true
            end
        end
    elseif self.dialog.type == "confirm_reset" then
        local buttons = self:getConfirmResetDialogButtons()
        if pointInRect(x, y, buttons.confirm) then
            self:requestOpenBlankMap()
            return true
        end
        if pointInRect(x, y, buttons.cancel) then
            self:closeDialog()
            self:showStatus("Reset cancelled.")
            return true
        end
    end

    return true
end

function mapEditor:keypressed(key)
    if key == "escape" then
        if self.dialog then
            local dialogType = self.dialog.type
            self:closeDialog()
            self:showStatus(dialogType == "confirm_reset" and "Reset cancelled." or "Dialog closed.")
            return true
        end
        if self.activeTextField then
            self:cancelTextField()
            self:showStatus("Text edit cancelled.")
            return true
        end
        if self.colorPicker then
            self:closeColorPicker()
            self:showStatus("Color picker closed.")
            return true
        end
        if self.routeTypePicker then
            self:closeRouteTypePicker()
            self:showStatus("Road type picker closed.")
            return true
        end
        if self.sidePanelMode == "sequencer" then
            self.sidePanelMode = "default"
            self:showStatus("Returned to the map editor pane.")
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

        if self.dialog.type == "open" then
            if key == "up" then
                self:scrollOpenDialog(-1)
                return true
            end
            if key == "down" then
                self:scrollOpenDialog(1)
                return true
            end
            if key == "pageup" then
                local layout = self:getOpenDialogListLayout()
                self:scrollOpenDialog(-layout.visibleRows)
                return true
            end
            if key == "pagedown" then
                local layout = self:getOpenDialogListLayout()
                self:scrollOpenDialog(layout.visibleRows)
                return true
            end
            if key == "home" then
                self.dialog.scroll = 0
                return true
            end
            if key == "end" then
                local layout = self:getOpenDialogListLayout()
                self.dialog.scroll = layout.maxScroll
                return true
            end
            if key == "return" or key == "kpenter" then
                local layout = self:getOpenDialogListLayout()
                if layout.rows[1] then
                    self:openDialogMap(layout.rows[1].map)
                    self:closeDialog()
                end
                return true
            end
        end

        if self.dialog.type == "confirm_reset" then
            if key == "return" or key == "kpenter" or key == "y" then
                self:requestOpenBlankMap()
                return true
            end
            if key == "n" then
                self:closeDialog()
                self:showStatus("Reset cancelled.")
                return true
            end
        end

        return true
    end

    if self.activeTextField then
        if key == "backspace" then
            if #self.activeTextField.buffer > 0 then
                self.activeTextField.buffer = string.sub(self.activeTextField.buffer, 1, #self.activeTextField.buffer - 1)
            end
            return true
        end

        if key == "return" or key == "kpenter" then
            self:commitTextField()
            return true
        end
    end

    if key == "delete" or key == "backspace" then
        self:deleteSelection()
        return true
    end

    if key == "g" then
        self.gridVisible = not self.gridVisible
        self:notifyPreferencesChanged()
        self:showStatus(self.gridVisible and "Grid shown." or "Grid hidden.")
        return true
    end

    if key == "f" then
        self:resetCameraToFit()
        self:showStatus("Camera reset to fit.")
        return true
    end

    if key == "s" then
        self:commitTextField()
        self:openSaveDialog()
        return true
    end

    if key == "o" then
        self:commitTextField()
        self:openOpenDialog()
        return true
    end

    if key == "p" then
        self:commitTextField()
        self:requestPlaytestFromSavedMap()
        return true
    end

    if key == "u" then
        self:commitTextField()
        self:requestUploadFromSavedMap()
        return true
    end

    if key == "c" then
        self:commitTextField()
        self.sidePanelMode = self.sidePanelMode == "sequencer" and "default" or "sequencer"
        self:showStatus(self.sidePanelMode == "sequencer" and "Sequencer opened." or "Returned to the map editor pane.")
        return true
    end

    if key == "r" then
        self:commitTextField()
        self:openResetDialog()
        return true
    end

    if key == "f3" then
        self.hitboxOverlayVisible = not self.hitboxOverlayVisible
        self:showStatus(self.hitboxOverlayVisible and "Hitbox overlay shown." or "Hitbox overlay hidden.")
        return true
    end

    return false
end

function mapEditor:textinput(text)
    if self.dialog and self.dialog.type == "save" then
        self.dialog.input = self.dialog.input .. text
    elseif self.activeTextField then
        self:appendTextFieldInput(text)
    end
end

function mapEditor:mousepressed(screenX, screenY, button)
    if button ~= 1 and button ~= 2 and button ~= 3 then
        return false
    end

    if self.dialog and self:handleDialogClick(screenX, screenY) then
        return true
    end

    if self.activeTextField and not pointInRect(screenX, screenY, self.sidePanel) then
        self:commitTextField()
    end

    if self.colorPicker and self:handleColorPickerClick(screenX, screenY, button) then
        return true
    end

    if self.routeTypePicker and self:handleRouteTypePickerClick(screenX, screenY) then
        return true
    end

    if pointInRect(screenX, screenY, self.sidePanel) then
        if self.sidePanelMode == "sequencer" then
            return self:handleSequencerClick(screenX, screenY, button)
        end

        if self:handleEditorDrawerClick(screenX, screenY) then
            return true
        end

        if self:handleValidationListClick(screenX, screenY) then
            return true
        end

        if pointInRect(screenX, screenY, self:getSaveButtonRect()) then
            self:openSaveDialog()
            return true
        end

        if pointInRect(screenX, screenY, self:getOpenButtonRect()) then
            self:openOpenDialog()
            return true
        end

        if pointInRect(screenX, screenY, self:getPlayTestButtonRect()) then
            self:requestPlaytestFromSavedMap()
            return true
        end

        if pointInRect(screenX, screenY, self:getUploadMapButtonRect()) then
            self:requestUploadFromSavedMap()
            return true
        end

        if pointInRect(screenX, screenY, self:getSequencerButtonRect()) then
            self.sidePanelMode = "sequencer"
            self:showStatus("Sequencer opened.")
            return true
        end

        if pointInRect(screenX, screenY, self:getResetButtonRect()) then
            self:openResetDialog()
            return true
        end

        if pointInRect(screenX, screenY, self:getHitboxToggleRect()) then
            self.hitboxOverlayVisible = not self.hitboxOverlayVisible
            self:showStatus(self.hitboxOverlayVisible and "Hitbox overlay shown." or "Hitbox overlay hidden.")
            return true
        end

        if pointInRect(screenX, screenY, self:getOpenUserMapsButtonRect()) then
            self:openUserMapsFolder()
            return true
        end

        return true
    end

    if button == 3 then
        self.panDrag = {
            startScreenX = screenX,
            startScreenY = screenY,
            startCameraX = self.camera.x,
            startCameraY = self.camera.y,
        }
        return true
    end

    local x, y = self:screenToMap(screenX, screenY)

    if button == 2 then
        local route, pointIndex, magnetKind = self:findPointHit(x, y)
        if route and magnetKind then
            self.selectedRouteId = route.id
            self.selectedPointIndex = pointIndex
            if magnetKind == "end" then
                self:openColorPicker(route, magnetKind)
                self:updateJunctionPickerHover(screenX, screenY)
                self:showStatus("End color menu opened.")
            else
                self:closeColorPicker()
            end
            return true
        end

        local outputSelectorIntersection = self:findIntersectionOutputSelectorHit(x, y)
        if outputSelectorIntersection then
            self:cycleIntersectionOutput(outputSelectorIntersection, -1)
            return true
        end

        local hitIntersection = self:findIntersectionHit(x, y)
        if hitIntersection then
            self:openJunctionPicker(hitIntersection, screenX, screenY)
            self:updateJunctionPickerHover(screenX, screenY)
            return true
        end

        local segmentHit = self:findSegmentHit(x, y)
        if segmentHit and segmentHit.route then
            self.selectedRouteId = segmentHit.route.id
            self.selectedPointIndex = nil
            self:openRouteTypePicker(segmentHit.route, segmentHit.segmentIndex, screenX, screenY)
            self:showStatus("Road type picker opened.")
            return true
        end

        return false
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

    local outputSelectorIntersection = self:findIntersectionOutputSelectorHit(x, y)
    if outputSelectorIntersection then
        self:cycleIntersectionOutput(outputSelectorIntersection, 1)
        return true
    end

    local hitIntersection = self:findIntersectionHit(x, y)
    if hitIntersection then
        self.drag = {
            kind = "intersection",
            intersectionId = hitIntersection.id,
            intersectionSnapshot = {
                id = hitIntersection.id,
                x = hitIntersection.x,
                y = hitIntersection.y,
                routeIds = copyArray(hitIntersection.routeIds),
            },
            sharedPointId = nil,
            routeId = nil,
            pointIndex = nil,
            startMouseX = x,
            startMouseY = y,
            moved = false,
            isMagnet = false,
            magnetKind = nil,
        }
        self:closeColorPicker()
        self:closeRouteTypePicker()
        return true
    end

    local segmentHit = self:findSegmentHit(x, y)
    if segmentHit then
        table.insert(segmentHit.route.points, segmentHit.insertIndex, segmentHit.point)
        self:splitRouteSegmentStyle(segmentHit.route, segmentHit.segmentIndex)
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
        self:closeRouteTypePicker()
        self:rebuildIntersections()
        self:showStatus("Bend point added.")
        return true
    end

    if pointInRect(x, y, self.canvas) then
        self:beginRoute(x, y)
        return true
    end

    self:closeColorPicker()
    self:closeRouteTypePicker()

    if pointInRect(x, y, self.canvas) then
        self:clearSelection()
        return true
    end

    return false
end

function mapEditor:wheelmoved(screenX, screenY, _, y)
    if self.dialog and self.dialog.type == "open" then
        if y > 0 then
            self:scrollOpenDialog(-1)
            return true
        end
        if y < 0 then
            self:scrollOpenDialog(1)
            return true
        end
        return false
    end

    if pointInRect(screenX, screenY, self.sidePanel) then
        if self.sidePanelMode == "default" then
            if y > 0 then
                return self:scrollValidationList(-40)
            end
            if y < 0 then
                return self:scrollValidationList(40)
            end
            return false
        end

        if self.sidePanelMode == "sequencer" then
            local layout = self:getSequencerLayout()
            if layout.maxScroll <= 0 then
                return false
            end

            if y > 0 then
                self.sequencerScroll = math.max(0, (self.sequencerScroll or 0) - 40)
            elseif y < 0 then
                self.sequencerScroll = math.min(layout.maxScroll, (self.sequencerScroll or 0) + 40)
            end
            return true
        end
    end

    self:zoomAroundScreenPoint(screenX, screenY, y)
    return true
end

function mapEditor:mousemoved(screenX, screenY, deltaX, deltaY)
    if self.validationScrollDrag then
        local drag = self.validationScrollDrag
        local thumbTravel = math.max(1, drag.track.h - drag.thumbHeight)
        local thumbY = clamp(screenY - drag.offsetY, drag.track.y, drag.track.y + thumbTravel)
        self.validationScroll = ((thumbY - drag.track.y) / thumbTravel) * drag.maxScroll
        return true
    end
    if self.sequencerScrollDrag then
        local drag = self.sequencerScrollDrag
        local thumbTravel = math.max(1, drag.track.h - drag.thumbHeight)
        local thumbY = clamp(screenY - drag.offsetY, drag.track.y, drag.track.y + thumbTravel)
        self.sequencerScroll = ((thumbY - drag.track.y) / thumbTravel) * drag.maxScroll
        return true
    end

    if self.panDrag and not love.mouse.isDown(3) then
        self.panDrag = nil
    end

    if not self.panDrag
        and love.mouse.isDown(3)
        and not pointInRect(screenX, screenY, self.sidePanel)
        and not self.dialog
        and not self.colorPicker
        and not self.routeTypePicker then
        self.panDrag = {
            startScreenX = screenX - (deltaX or 0),
            startScreenY = screenY - (deltaY or 0),
            startCameraX = self.camera.x,
            startCameraY = self.camera.y,
        }
    end

    if self.panDrag then
        self.camera.x = self.panDrag.startCameraX - ((screenX - self.panDrag.startScreenX) / self.camera.zoom)
        self.camera.y = self.panDrag.startCameraY - ((screenY - self.panDrag.startScreenY) / self.camera.zoom)
        self:clampCamera()
        return true
    end

    if self.colorPicker and (self.colorPicker.mode == "junction" or self.colorPicker.mode == "route_end") then
        self:updateJunctionPickerHover(screenX, screenY)
    end

    if not self.drag then
        return false
    end

    local x, y = self:screenToMap(screenX, screenY)
    self:updateDraggedPoint(x, y)
    return true
end

function mapEditor:mousereleased(screenX, screenY, button)
    if button == 3 and self.panDrag then
        self.panDrag = nil
        return true
    end

    if button ~= 1 then
        return false
    end

    if self.validationScrollDrag then
        self.validationScrollDrag = nil
        return true
    end

    if self.sequencerScrollDrag then
        self.sequencerScrollDrag = nil
        return true
    end

    if not self.drag then
        return false
    end

    local x, y = self:screenToMap(screenX, screenY)
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
    elseif route and self.drag.kind == "point" and self.drag.isMagnet and self.drag.magnetKind == "end" then
        local currentEndpoint = self.drag.magnetKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route)
        local target = currentEndpoint and self:findEndpointAt(x, y, currentEndpoint.kind, currentEndpoint.id) or nil
        if target then
            self:mergeEndpointInto(route, self.drag.magnetKind, target)
        end
    elseif route and self.drag.kind == "point" and self.drag.moved then
        local targetRoute, targetPointIndex, targetPoint = self:findBendPointAt(x, y, route.id, self.drag.pointIndex)
        if targetRoute and targetPointIndex then
            local blockedByOriginalGroup = self.drag.splitOriginSharedPointId
                and targetPoint
                and targetPoint.sharedPointId == self.drag.splitOriginSharedPointId
            if not blockedByOriginalGroup then
                self:mergeBendPointInto(route, self.drag.pointIndex, targetRoute, targetPointIndex)
            end
        end
    end

    if self.drag.kind == "intersection" then
        local activeIntersection = self:getIntersectionById(self.drag.intersectionId)
        local wasMoved = self.drag.moved
        self.drag = nil

        if wasMoved then
            self:showStatus("Junction moved.")
            self:rebuildIntersections()
            return true
        end

        self:cycleIntersectionInput(activeIntersection)
        return true
    end

    self.drag = nil
    self:rebuildIntersections()
    return true
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
            local sharedPointSuffix = point.sharedPointId and string.format(", sharedPointId = %d", point.sharedPointId) or ""
            lines[#lines + 1] = string.format(
                "                { x = %s, y = %s%s },",
                formatNumber(point.x / self.mapSize.w),
                formatNumber(point.y / self.mapSize.h),
                sharedPointSuffix
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

function mapEditor:drawMagnet(route, point, magnetKind, selected)
    local graphics = love.graphics
    local endpoint = magnetKind == "start" and self:getRouteStartEndpoint(route) or self:getRouteEndEndpoint(route)
    local selectedColors = magnetKind == "end" and getEndpointColorIds(endpoint) or {}
    local endpointColorOption = (#selectedColors == 1) and getColorOptionById(selectedColors[1]) or nil
    local width = magnetKind == "start" and 58 or 46
    local height = 24

    graphics.setColor(0.08, 0.1, 0.14, 1)
    graphics.rectangle("fill", point.x - width * 0.5 - 3, point.y - height * 0.5 - 3, width + 6, height + 6, 9, 9)
    if magnetKind == "end" and endpointColorOption then
        graphics.setColor(endpointColorOption.color[1], endpointColorOption.color[2], endpointColorOption.color[3], 1)
    else
        graphics.setColor(route.color[1], route.color[2], route.color[3], 1)
    end
    graphics.rectangle("fill", point.x - width * 0.5, point.y - height * 0.5, width, height, 9, 9)

    graphics.setColor(0.05, 0.06, 0.08, 1)
    graphics.printf(
        magnetKind == "start" and "START" or "END",
        point.x - width * 0.5,
        point.y - 7,
        width,
        "center"
    )

    if magnetKind == "end" and #selectedColors > 1 then
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
    end

    if selected then
        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.setLineWidth(2)
        graphics.rectangle("line", point.x - width * 0.5 - 8, point.y - height * 0.5 - 8, width + 16, height + 16, 12, 12)
    end
end

function mapEditor:drawRoutePatternStroke(pointA, pointB, roadTypeId, alpha)
    local roadTypeConfig = roadTypes.getConfig(roadTypeId)
    if roadTypeConfig.pattern == "plain" then
        return
    end

    local graphics = love.graphics
    local length = segmentLength(pointA, pointB)
    if length <= 0.001 then
        return
    end

    local angle = angleBetweenPoints(pointA, pointB)
    local directionX = math.cos(angle)
    local directionY = math.sin(angle)
    local normalX = -directionY
    local normalY = directionX
    local markerSpacing = roadTypeConfig.markerSpacing
    local markerSize = roadTypeConfig.markerSize
    local markerDistance = markerSpacing * 0.5
    local outlineWidth = roadTypeConfig.markerWidth + 2
    local fillWidth = roadTypeConfig.markerWidth

    local function drawPatternSegment(startX, startY, endX, endY)
        graphics.setColor(ROAD_PATTERN_OUTLINE[1], ROAD_PATTERN_OUTLINE[2], ROAD_PATTERN_OUTLINE[3], alpha)
        graphics.setLineWidth(outlineWidth)
        graphics.line(startX, startY, endX, endY)
        graphics.setColor(ROAD_PATTERN_FILL[1], ROAD_PATTERN_FILL[2], ROAD_PATTERN_FILL[3], alpha)
        graphics.setLineWidth(fillWidth)
        graphics.line(startX, startY, endX, endY)
    end

    while markerDistance < length do
        local markerX = pointA.x + directionX * markerDistance
        local markerY = pointA.y + directionY * markerDistance

        if roadTypeConfig.pattern == "chevron" then
            local tipX = markerX + directionX * markerSize
            local tipY = markerY + directionY * markerSize
            local leftX = markerX - normalX * markerSize * 0.7
            local leftY = markerY - normalY * markerSize * 0.7
            local rightX = markerX + normalX * markerSize * 0.7
            local rightY = markerY + normalY * markerSize * 0.7
            drawPatternSegment(leftX, leftY, tipX, tipY)
            drawPatternSegment(rightX, rightY, tipX, tipY)
        elseif roadTypeConfig.pattern == "crossbar" then
            local startX = markerX - normalX * markerSize
            local startY = markerY - normalY * markerSize
            local endX = markerX + normalX * markerSize
            local endY = markerY + normalY * markerSize
            drawPatternSegment(startX, startY, endX, endY)
        end

        markerDistance = markerDistance + markerSpacing
    end
end

function mapEditor:drawRouteRoadTypeMarkers(route, selectedRouteId)
    local alpha = selectedRouteId == route.id and 0.98 or 0.86
    local segmentRoadTypes = self:ensureRouteSegmentRoadTypes(route)

    for segmentIndex = 1, #route.points - 1 do
        self:drawRoutePatternStroke(
            route.points[segmentIndex],
            route.points[segmentIndex + 1],
            segmentRoadTypes[segmentIndex],
            alpha
        )
    end
end

function mapEditor:buildRouteSegmentGroups(selectedRouteId)
    local grouped = {}

    for _, route in ipairs(self.routes) do
        for pointIndex = 1, #route.points - 1 do
            local a = route.points[pointIndex]
            local b = route.points[pointIndex + 1]
            local key = buildSegmentGroupKey(a, b)
            local group = grouped[key]

            if not group then
                group = {
                    a = copyPoint(a),
                    b = copyPoint(b),
                    routeIds = {},
                    routeLookup = {},
                    colorIds = {},
                    colorLookup = {},
                    selected = false,
                }
                grouped[key] = group
            end

            if not group.routeLookup[route.id] then
                group.routeLookup[route.id] = true
                group.routeIds[#group.routeIds + 1] = route.id
            end
            if not group.colorLookup[route.colorId] then
                group.colorLookup[route.colorId] = true
                group.colorIds[#group.colorIds + 1] = route.colorId
            end
            if route.id == selectedRouteId then
                group.selected = true
            end
        end
    end

    local groups = {}
    for _, group in pairs(grouped) do
        groups[#groups + 1] = group
    end

    table.sort(groups, function(first, second)
        if #first.colorIds ~= #second.colorIds then
            return #first.colorIds < #second.colorIds
        end
        if math.abs(first.a.y - second.a.y) > 0.5 then
            return first.a.y < second.a.y
        end
        if math.abs(first.a.x - second.a.x) > 0.5 then
            return first.a.x < second.a.x
        end
        return (#first.routeIds) < (#second.routeIds)
    end)

    return groups
end

function mapEditor:drawRoute(route, selectedRouteId)
    local graphics = love.graphics
    local points = {}
    self:ensureRouteSegmentRoadTypes(route)

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

    self:drawRouteRoadTypeMarkers(route, selectedRouteId)

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

function mapEditor:drawRouteSegmentGroup(group)
    local graphics = love.graphics
    local a = group.a
    local b = group.b
    local dx = b.x - a.x
    local dy = b.y - a.y
    local length = math.sqrt(dx * dx + dy * dy)
    local outerWidth = group.selected and 28 or 24
    local innerWidth = group.selected and 18 or 14

    graphics.setLineStyle("rough")
    graphics.setLineJoin("bevel")
    graphics.setColor(0.11, 0.14, 0.18, 1)
    graphics.setLineWidth(outerWidth)
    graphics.line(a.x, a.y, b.x, b.y)

    if #group.colorIds <= 1 or length <= 0.0001 then
        local option = getColorOptionById(group.colorIds[1] or COLOR_OPTIONS[1].id)
        local color = option and option.color or COLOR_OPTIONS[1].color
        graphics.setColor(color[1], color[2], color[3], group.selected and 1 or 0.86)
        graphics.setLineWidth(innerWidth)
        graphics.line(a.x, a.y, b.x, b.y)
        return
    end

    local unitX = dx / length
    local unitY = dy / length
    local stripeCount = math.max(1, #group.colorIds)
    local stripeLength = math.max(8, SHARED_LANE_STRIPE_LENGTH - stripeCount)

    graphics.setLineWidth(innerWidth)
    for stripeIndex = 0, math.ceil(length / stripeLength) - 1 do
        local stripeStart = stripeIndex * stripeLength
        local stripeEnd = math.min(length, stripeStart + stripeLength)
        local colorId = group.colorIds[(stripeIndex % #group.colorIds) + 1]
        local option = getColorOptionById(colorId)
        local color = option and option.color or COLOR_OPTIONS[1].color
        graphics.setColor(color[1], color[2], color[3], group.selected and 1 or 0.92)
        graphics.line(
            a.x + unitX * stripeStart,
            a.y + unitY * stripeStart,
            a.x + unitX * stripeEnd,
            a.y + unitY * stripeEnd
        )
    end
end

function mapEditor:drawRouteHandles(route, selectedRouteId)
    local graphics = love.graphics

    for pointIndex, point in ipairs(route.points) do
        local selected = selectedRouteId == route.id and pointIndex == self.selectedPointIndex
        if pointIndex == 1 then
            self:drawMagnet(route, point, "start", selected)
        elseif pointIndex == #route.points then
            self:drawMagnet(route, point, "end", selected)
        else
            local isSharedJunctionPoint = point.sharedPointId and self:getSharedPointGroupForPoint(route, pointIndex)
            if not isSharedJunctionPoint then
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
end

function mapEditor:drawIntersection(intersection)
    if not intersection.unsupported then
        return
    end

    local graphics = love.graphics
    local radius = 16 / math.max(self.camera.zoom, 0.0001)

    graphics.setColor(0.78, 0.22, 0.18, 0.92)
    graphics.circle("fill", intersection.x, intersection.y, radius)
    graphics.setColor(0.98, 0.96, 0.96, 1)
    graphics.setLineWidth(3 / math.max(self.camera.zoom, 0.0001))
    graphics.line(intersection.x - radius * 0.45, intersection.y - radius * 0.45, intersection.x + radius * 0.45, intersection.y + radius * 0.45)
    graphics.line(intersection.x - radius * 0.45, intersection.y + radius * 0.45, intersection.x + radius * 0.45, intersection.y - radius * 0.45)
end

function mapEditor:drawPanelButton(rect, label, accentColor, isDisabled)
    local graphics = love.graphics
    local font = graphics.getFont()
    if isDisabled then
        graphics.setColor(0.08, 0.1, 0.13, 0.72)
    else
        graphics.setColor(0.1, 0.12, 0.16, 0.96)
    end
    graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 12, 12)
    graphics.setLineWidth(1.5)
    if isDisabled then
        graphics.setColor(0.34, 0.38, 0.42, 0.85)
    else
        graphics.setColor(accentColor[1], accentColor[2], accentColor[3], 1)
    end
    graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 12, 12)
    if isDisabled then
        graphics.setColor(0.6, 0.64, 0.68, 0.9)
    else
        graphics.setColor(0.97, 0.98, 1, 1)
    end
    graphics.printf(label, rect.x, rect.y + math.floor((rect.h - font:getHeight()) * 0.5), rect.w, "center")
end

function mapEditor:drawHitboxToggle(game)
    local graphics = love.graphics
    local rect = self:getHitboxToggleRect()
    local accentColor = self.hitboxOverlayVisible and { 0.48, 0.92, 0.62 } or { 0.36, 0.42, 0.5 }
    self:drawPanelButton(rect, "Hitboxes (F3)", accentColor)
end

function mapEditor:drawGrid()
    if not self.gridVisible then
        return
    end

    local graphics = love.graphics
    local step = sanitizeGridStep(self.gridStep)
    local halfW, halfH = self:getCameraViewHalfExtents()
    local startX = math.max(0, math.floor((self.camera.x - halfW) / step) * step)
    local endX = math.min(self.mapSize.w, math.ceil((self.camera.x + halfW) / step) * step)
    local startY = math.max(0, math.floor((self.camera.y - halfH) / step) * step)
    local endY = math.min(self.mapSize.h, math.ceil((self.camera.y + halfH) / step) * step)
    local majorStep = step * 4

    graphics.setLineWidth(1 / math.max(self.camera.zoom, 0.0001))
    for gridX = startX, endX, step do
        local isMajor = (gridX % majorStep) == 0
        graphics.setColor(0.62, 0.72, 0.82, isMajor and GRID_MAJOR_ALPHA or GRID_MINOR_ALPHA)
        graphics.line(gridX, 0, gridX, self.mapSize.h)
    end

    for gridY = startY, endY, step do
        local isMajor = (gridY % majorStep) == 0
        graphics.setColor(0.62, 0.72, 0.82, isMajor and GRID_MAJOR_ALPHA or GRID_MINOR_ALPHA)
        graphics.line(0, gridY, self.mapSize.w, gridY)
    end
end

function mapEditor:drawWrappedList(font, items, x, y, width, limitY, color, numberColor)
    local graphics = love.graphics
    local currentY = y
    local renderedCount = 0

    love.graphics.setFont(font)
    for index, item in ipairs(items or {}) do
        local bullet = string.format("%d. ", index)
        local lineHeight = font:getHeight()
        local lineCount = getWrappedLineCount(font, item, math.max(20, width - 22))
        local itemHeight = math.max(lineHeight, lineCount * lineHeight)

        if currentY + itemHeight > limitY then
            break
        end

        graphics.setColor(numberColor[1], numberColor[2], numberColor[3], numberColor[4] or 1)
        graphics.print(bullet, x, currentY)
        graphics.setColor(color[1], color[2], color[3], color[4] or 1)
        graphics.printf(item, x + 22, currentY, width - 22)
        currentY = currentY + itemHeight + 10
        renderedCount = renderedCount + 1
    end

    return currentY, renderedCount
end

function mapEditor:drawStatusToast(game)
    if not self.statusText or self.statusTimer <= 0 then
        return
    end

    local graphics = love.graphics
    local fadeAlpha = 1
    if self.statusTimer < STATUS_TOAST_FADE_TIME then
        fadeAlpha = self.statusTimer / STATUS_TOAST_FADE_TIME
    end

    local font = game.fonts.small
    local maxWidth = math.max(220, math.min(420, self:getCameraViewportRect().w - STATUS_TOAST_MARGIN * 2))
    local textWidth = maxWidth - 24
    local textHeight = getWrappedLineCount(font, self.statusText, textWidth) * font:getHeight()
    local toastRect = {
        x = STATUS_TOAST_MARGIN,
        y = self.viewport.h - STATUS_TOAST_MARGIN - textHeight - 20,
        w = maxWidth,
        h = textHeight + 20,
    }

    love.graphics.setFont(font)
    graphics.setColor(0.08, 0.1, 0.14, 0.96 * fadeAlpha)
    graphics.rectangle("fill", toastRect.x, toastRect.y, toastRect.w, toastRect.h, 12, 12)
    graphics.setColor(0.48, 0.92, 0.62, 0.95 * fadeAlpha)
    graphics.rectangle("line", toastRect.x, toastRect.y, toastRect.w, toastRect.h, 12, 12)
    graphics.setColor(0.48, 0.92, 0.62, 0.9 * fadeAlpha)
    graphics.rectangle("fill", toastRect.x, toastRect.y, 4, toastRect.h, 12, 12)
    graphics.setColor(0.92, 0.96, 1, fadeAlpha)
    graphics.printf(self.statusText, toastRect.x + 14, toastRect.y + 10, textWidth)
end

function mapEditor:drawEditorStaticJunctionIcon(image, centerX, centerY, size, scaleMultiplier, alpha)
    if not image then
        return false
    end

    local imageWidth, imageHeight = image:getDimensions()
    local scale = math.min((size * scaleMultiplier) / imageWidth, (size * scaleMultiplier) / imageHeight)
    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(
        image,
        centerX,
        centerY,
        0,
        scale,
        scale,
        imageWidth * 0.5,
        imageHeight * 0.5
    )
    return true
end

function mapEditor:drawEditorHourglassIcon(centerX, centerY, size, color)
    local graphics = love.graphics
    local halfWidth = size * 0.34
    local halfHeight = size * 0.46
    local neckWidth = size * 0.08

    graphics.push()
    graphics.translate(centerX, centerY)
    graphics.setColor(color[1], color[2], color[3], 1)
    graphics.polygon(
        "fill",
        -halfWidth, -halfHeight,
        halfWidth, -halfHeight,
        neckWidth, 0,
        -neckWidth, 0
    )
    graphics.polygon(
        "fill",
        -neckWidth, 0,
        neckWidth, 0,
        halfWidth, halfHeight,
        -halfWidth, halfHeight
    )
    graphics.setLineWidth(2)
    graphics.setColor(0.05, 0.06, 0.08, 0.96)
    graphics.line(-halfWidth, -halfHeight, halfWidth, -halfHeight)
    graphics.line(-halfWidth, halfHeight, halfWidth, halfHeight)
    graphics.line(-halfWidth, -halfHeight, -neckWidth, 0, -halfWidth, halfHeight)
    graphics.line(halfWidth, -halfHeight, neckWidth, 0, halfWidth, halfHeight)
    graphics.pop()
end

function mapEditor:drawEditorControlIcon(controlType, centerX, centerY, size)
    self:ensureEditorJunctionIcons()

    if controlType == "direct" then
        if self:drawEditorStaticJunctionIcon(self.editorDirectImage, centerX, centerY, size, 1.4, 0.98) then
            return
        end
    elseif controlType == "delayed" then
        self:drawEditorHourglassIcon(centerX, centerY, size, { 0.05, 0.06, 0.08 })
        return
    elseif controlType == "pump" then
        if self:drawEditorStaticJunctionIcon(self.editorChargeImage, centerX, centerY, size, 1.32, 0.98) then
            return
        end
    elseif controlType == "spring" then
        if self:drawEditorStaticJunctionIcon(self.editorSpringImage, centerX, centerY, size, 1.18, 0.98) then
            return
        end
    elseif controlType == "relay" then
        if self:drawEditorStaticJunctionIcon(self.editorRelayImage, centerX, centerY, size, 1.42, 0.98) then
            return
        end
    elseif controlType == "trip" then
        if self:drawEditorStaticJunctionIcon(self.editorTripImage, centerX, centerY, size, 1.36, 0.98) then
            return
        end
    elseif controlType == "crossbar" then
        if self:drawEditorStaticJunctionIcon(self.editorCrossImage, centerX, centerY, size, 1.4, 0.98) then
            return
        end
    end

    love.graphics.setColor(0.05, 0.06, 0.08, 1)
    love.graphics.printf(
        self:getControlLabel(controlType),
        centerX - size,
        centerY - 8,
        size * 2,
        "center"
    )
end

function mapEditor:drawJunctionMenuRoot(layout, intersection, colorOptions)
    local graphics = love.graphics
    local root = layout.root
    local leftColor = #colorOptions > 0 and { 0.82, 0.86, 0.9, 0.92 } or { 0.24, 0.28, 0.32, 0.82 }
    local isRouteEnd = self.colorPicker and self.colorPicker.mode == "route_end"
    local rightColor = isRouteEnd
        and { 0.36, 0.42, 0.5, 0.92 }
        or (CONTROL_FILL_COLORS[intersection.controlType] or CONTROL_FILL_COLORS.direct)
    local hoverBranch = layout.hoverBranch

    graphics.setColor(0.05, 0.06, 0.08, 0.94)
    graphics.circle("fill", root.x, root.y, root.radius + 6)

    graphics.setColor(leftColor[1], leftColor[2], leftColor[3], hoverBranch == "disconnect" and 0.32 or 0.18)
    graphics.arc("fill", "pie", root.x, root.y, root.radius, math.pi * 0.5, math.pi * 1.5)
    graphics.setColor(rightColor[1], rightColor[2], rightColor[3], hoverBranch == "junctions" and 0.38 or 0.22)
    graphics.arc("fill", "pie", root.x, root.y, root.radius, -math.pi * 0.5, math.pi * 0.5)

    graphics.setColor(0.97, 0.98, 1, 0.86)
    graphics.setLineWidth(2)
    graphics.circle("line", root.x, root.y, root.radius)
    graphics.line(root.x, root.y - root.radius + 4, root.x, root.y + root.radius - 4)

    local colorCount = math.min(3, #colorOptions)
    for colorIndex = 1, colorCount do
        local option = colorOptions[colorIndex]
        local dotY = root.y + (colorIndex - (colorCount + 1) * 0.5) * (JUNCTION_MENU_SWATCH_RADIUS * 2 + 4)
        graphics.setColor(0.05, 0.06, 0.08, 1)
        graphics.circle("fill", root.x - root.radius * 0.36, dotY, JUNCTION_MENU_SWATCH_RADIUS + 3)
        graphics.setColor(option.color[1], option.color[2], option.color[3], 1)
        graphics.circle("fill", root.x - root.radius * 0.36, dotY, JUNCTION_MENU_SWATCH_RADIUS)
    end

    if isRouteEnd then
        graphics.setColor(0.05, 0.06, 0.08, 1)
        graphics.printf(
            "END",
            root.x + 4,
            root.y - 9,
            root.radius - 8,
            "center"
        )
    else
        self:drawEditorControlIcon(intersection.controlType, root.x + root.radius * 0.5, root.y, JUNCTION_MENU_ICON_SIZE)
    end
end

function mapEditor:drawJunctionMenuSubmenu(layout, intersection)
    local graphics = love.graphics
    local submenu = layout.submenu
    if not submenu then
        return
    end

    graphics.setColor(0.05, 0.06, 0.08, 0.94)
    graphics.circle("fill", submenu.x, submenu.y, submenu.radius + 6)
    graphics.setColor(0.97, 0.98, 1, 0.86)
    graphics.setLineWidth(2)
    graphics.circle("line", submenu.x, submenu.y, submenu.radius)

    if #submenu.entries == 0 then
        return
    end

    for _, entry in ipairs(submenu.entries) do
        local isHovered = self.colorPicker.hoverOptionIndex == entry.index
        local color = nil
        local iconSize = submenu.branch == "junctions" and JUNCTION_MENU_TYPE_ICON_SIZE or JUNCTION_MENU_ICON_SIZE
        if submenu.branch == "disconnect" then
            color = entry.option.color
        else
            color = CONTROL_FILL_COLORS[entry.option.controlType] or CONTROL_FILL_COLORS.direct
        end

        graphics.setColor(color[1], color[2], color[3], isHovered and 0.44 or 0.26)
        graphics.arc("fill", "pie", submenu.x, submenu.y, submenu.outerRadius, entry.startAngle, entry.endAngle)
        graphics.setColor(0.05, 0.06, 0.08, 1)
        graphics.arc("line", "open", submenu.x, submenu.y, submenu.outerRadius, entry.startAngle, entry.endAngle)

        if submenu.branch == "disconnect" then
            graphics.setColor(0.05, 0.06, 0.08, 1)
            graphics.circle("fill", entry.centerX, entry.centerY, JUNCTION_MENU_SWATCH_RADIUS + 3)
            graphics.setColor(color[1], color[2], color[3], 1)
            graphics.circle("fill", entry.centerX, entry.centerY, JUNCTION_MENU_SWATCH_RADIUS)
        else
            self:drawEditorControlIcon(entry.option.controlType, entry.centerX, entry.centerY, iconSize)
            if entry.option.controlType == intersection.controlType then
                graphics.setColor(0.97, 0.98, 1, 1)
                graphics.setLineWidth(2)
                graphics.circle("line", entry.centerX, entry.centerY, iconSize + 6)
            end
        end
    end
end

function mapEditor:drawScrollableWrappedList(font, items, listRect, scrollOffset, color, numberColor)
    local graphics = love.graphics
    local currentY = listRect.y - (scrollOffset or 0)

    love.graphics.setFont(font)
    love.graphics.setScissor(listRect.x, listRect.y, listRect.w, listRect.h)
    for index, item in ipairs(items or {}) do
        local bullet = string.format("%d. ", index)
        local lineHeight = font:getHeight()
        local lineCount = getWrappedLineCount(font, item, math.max(20, listRect.w - 22))
        local itemHeight = math.max(lineHeight, lineCount * lineHeight)
        local itemBottom = currentY + itemHeight

        if itemBottom >= listRect.y and currentY <= listRect.y + listRect.h then
            graphics.setColor(numberColor[1], numberColor[2], numberColor[3], numberColor[4] or 1)
            graphics.print(bullet, listRect.x, currentY)
            graphics.setColor(color[1], color[2], color[3], color[4] or 1)
            graphics.printf(item, listRect.x + 22, currentY, listRect.w - 22)
        end

        currentY = currentY + itemHeight + 10
    end
    love.graphics.setScissor()
end

function mapEditor:drawValidationMarkers()
    local graphics = love.graphics
    local cameraViewport = self:getCameraViewportRect()

    for index, entry in ipairs(self:getValidationEntries()) do
        local diagnostic = type(entry) == "table" and entry.diagnostic or nil
        if diagnostic and diagnostic.x and diagnostic.y then
            local x, y = self:mapToScreen(diagnostic.x, diagnostic.y)
            local isHovered = self.hoveredValidationIndex == index
            local size = isHovered and 13 or 9

            if pointInRect(x, y, cameraViewport) then
                graphics.setLineWidth(isHovered and 5 or 4)
                graphics.setColor(0.96, 0.22, 0.22, isHovered and 1 or 0.92)
                graphics.line(x - size, y - size, x + size, y + size)
                graphics.line(x - size, y + size, x + size, y - size)

                if isHovered then
                    graphics.setColor(1, 0.9, 0.35, 0.95)
                    graphics.circle("line", x, y, size + 7)
                end
            end
        end
    end
end

function mapEditor:drawHitboxOverlay(game)
    if not self.hitboxOverlayVisible then
        return
    end

    local graphics = love.graphics
    local font = game.fonts.small
    local zoom = math.max(self.camera.zoom, HITBOX_OVERLAY_EPSILON)
    local inverseZoom = 1 / zoom

    love.graphics.setFont(font)

    for _, entry in ipairs(self:getHitboxOverlayEntries()) do
        local color = entry.color

        graphics.setColor(color[1], color[2], color[3], HITBOX_OVERLAY_FILL_ALPHA)
        if entry.kind == "polygon" then
            graphics.polygon("fill", entry.points)
        else
            graphics.rectangle(
                "fill",
                entry.rect.x,
                entry.rect.y,
                entry.rect.w,
                entry.rect.h,
                HITBOX_OVERLAY_RECT_CORNER_RADIUS,
                HITBOX_OVERLAY_RECT_CORNER_RADIUS
            )
        end

        graphics.setColor(color[1], color[2], color[3], HITBOX_OVERLAY_OUTLINE_ALPHA)
        graphics.setLineWidth(HITBOX_OVERLAY_STROKE_WIDTH * inverseZoom)
        if entry.kind == "polygon" then
            graphics.polygon("line", entry.points)
        else
            graphics.rectangle(
                "line",
                entry.rect.x,
                entry.rect.y,
                entry.rect.w,
                entry.rect.h,
                HITBOX_OVERLAY_RECT_CORNER_RADIUS,
                HITBOX_OVERLAY_RECT_CORNER_RADIUS
            )
        end

        local labelWidth = font:getWidth(entry.label) + HITBOX_OVERLAY_LABEL_PADDING_X * 2
        local labelHeight = font:getHeight() + HITBOX_OVERLAY_LABEL_PADDING_Y * 2

        graphics.push()
        graphics.translate(entry.labelX, entry.labelY)
        graphics.scale(inverseZoom, inverseZoom)
        graphics.setColor(0.05, 0.06, 0.08, HITBOX_OVERLAY_LABEL_BACKGROUND_ALPHA)
        graphics.rectangle(
            "fill",
            -labelWidth * 0.5,
            -HITBOX_OVERLAY_LABEL_OFFSET_Y - labelHeight,
            labelWidth,
            labelHeight,
            HITBOX_OVERLAY_LABEL_CORNER_RADIUS,
            HITBOX_OVERLAY_LABEL_CORNER_RADIUS
        )
        graphics.setColor(color[1], color[2], color[3], HITBOX_OVERLAY_OUTLINE_ALPHA)
        graphics.rectangle(
            "line",
            -labelWidth * 0.5,
            -HITBOX_OVERLAY_LABEL_OFFSET_Y - labelHeight,
            labelWidth,
            labelHeight,
            HITBOX_OVERLAY_LABEL_CORNER_RADIUS,
            HITBOX_OVERLAY_LABEL_CORNER_RADIUS
        )
        graphics.setColor(0.97, 0.98, 1, HITBOX_OVERLAY_LABEL_TEXT_ALPHA)
        graphics.print(
            entry.label,
            -labelWidth * 0.5 + HITBOX_OVERLAY_LABEL_PADDING_X,
            -HITBOX_OVERLAY_LABEL_OFFSET_Y - labelHeight + HITBOX_OVERLAY_LABEL_PADDING_Y
        )
        graphics.pop()
    end
end

function mapEditor:drawColorPicker(game)
    local layout = self:getColorPickerLayout()
    if not layout then
        return
    end

    local graphics = love.graphics
    local lookup = self:getColorPickerSelectionLookup()

    if layout.kind == "junction_radial" then
        local intersection = nil
        if self.colorPicker.mode == "junction" then
            intersection = self:getIntersectionById(self.colorPicker.intersectionId)
            if not intersection then
                return
            end
        elseif self.colorPicker.mode ~= "route_end" then
            return
        end

        local colorOptions = self:getColorPickerOptions()
        local popupScale = self:getJunctionPickerPopupScale()
        local originX, originY = self:getJunctionPickerPopupOrigin()

        graphics.push()
        graphics.translate(originX, originY)
        graphics.scale(popupScale, popupScale)
        graphics.translate(-originX, -originY)
        if layout.branch then
            self:drawJunctionMenuSubmenu(layout, intersection)
        else
            self:drawJunctionMenuRoot(layout, intersection, colorOptions)
        end
        graphics.pop()
        return
    end

    graphics.setColor(0.08, 0.1, 0.14, 0.98)
    graphics.rectangle("fill", layout.rect.x, layout.rect.y, layout.rect.w, layout.rect.h, 16, 16)
    graphics.setColor(0.24, 0.32, 0.4, 1)
    graphics.setLineWidth(1.2)
    graphics.rectangle("line", layout.rect.x, layout.rect.y, layout.rect.w, layout.rect.h, 16, 16)

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
            graphics.setLineWidth(2)
            graphics.rectangle("line", rect.x - 3, rect.y - 3, rect.w + 6, rect.h + 6, 10, 10)
        end
    end
end

function mapEditor:drawRoadTypePreview(option, rect, alpha)
    local graphics = love.graphics
    local centerY = rect.y + rect.h * 0.5
    local startX = rect.x + 10
    local endX = rect.x + rect.w - 10

    graphics.setColor(0.1, 0.12, 0.16, alpha)
    graphics.setLineWidth(10)
    graphics.line(startX, centerY, endX, centerY)
    graphics.setColor(0.84, 0.88, 0.92, alpha)
    graphics.setLineWidth(4)
    graphics.line(startX, centerY, endX, centerY)

    if option.pattern == "chevron" then
        self:drawRoutePatternStroke(
            { x = rect.x + 18, y = centerY },
            { x = rect.x + rect.w - 18, y = centerY },
            option.id,
            alpha
        )
    elseif option.pattern == "crossbar" then
        self:drawRoutePatternStroke(
            { x = rect.x + 18, y = centerY },
            { x = rect.x + rect.w - 18, y = centerY },
            option.id,
            alpha
        )
    end
end

function mapEditor:drawRouteTypePicker(game)
    local layout = self:getRouteTypePickerLayout()
    if not layout then
        return
    end

    local route = self:getRouteById(self.routeTypePicker.routeId)
    if not route then
        return
    end

    local graphics = love.graphics
    local selectedRoadType = self:getRouteSegmentRoadType(route, self.routeTypePicker.segmentIndex)

    graphics.setColor(0.08, 0.1, 0.14, 0.98)
    graphics.rectangle("fill", layout.rect.x, layout.rect.y, layout.rect.w, layout.rect.h, 16, 16)
    graphics.setColor(0.24, 0.32, 0.4, 1)
    graphics.rectangle("line", layout.rect.x, layout.rect.y, layout.rect.w, layout.rect.h, 16, 16)

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf(
        "Road Type For Segment " .. tostring(self.routeTypePicker.segmentIndex),
        layout.rect.x + 14,
        layout.rect.y + 14,
        layout.rect.w - 28,
        "center"
    )

    for _, optionEntry in ipairs(layout.options) do
        local option = optionEntry.option
        local rect = optionEntry.rect
        local isSelected = option.id == selectedRoadType

        graphics.setColor(0.05, 0.06, 0.08, 1)
        graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 12, 12)
        graphics.setColor(0.58, 0.64, 0.7, 1)
        graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 12, 12)

        self:drawRoadTypePreview(option, {
            x = rect.x + 10,
            y = rect.y + 8,
            w = 48,
            h = rect.h - 16,
        }, 1)

        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.print(option.label, rect.x + 68, rect.y + 8)
        graphics.setColor(0.72, 0.78, 0.84, 1)
        graphics.print(string.format("%d%% speed", math.floor(option.speedScale * 100 + 0.5)), rect.x + 68, rect.y + 22)

        if isSelected then
            graphics.setColor(0.97, 0.98, 1, 1)
            graphics.setLineWidth(2)
            graphics.rectangle("line", rect.x - 2, rect.y - 2, rect.w + 4, rect.h + 4, 14, 14)
        end
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

    if self.dialog.type == "confirm_reset" then
        graphics.printf("Reset Map", rect.x, rect.y + 20, rect.w, "center")
        love.graphics.setFont(game.fonts.body)
        graphics.setColor(0.84, 0.88, 0.92, 1)
        graphics.printf(
            "Discard the current map without saving and open a new blank map?\nAny unsaved changes will be lost.",
            rect.x + 32,
            rect.y + 102,
            rect.w - 64,
            "center"
        )
        local buttons = self:getConfirmResetDialogButtons()
        love.graphics.setFont(game.fonts.small)
        self:drawPanelButton(buttons.confirm, "Open Blank Map", { 0.99, 0.78, 0.32 })
        self:drawPanelButton(buttons.cancel, "Cancel", { 0.33, 0.8, 0.98 })
        graphics.setColor(0.72, 0.78, 0.84, 1)
        graphics.printf("Enter confirms. Esc or N cancels.", rect.x + 24, rect.y + rect.h - 126, rect.w - 48, "center")
        return
    end

    graphics.printf("Open Map", rect.x, rect.y + 20, rect.w, "center")
    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.84, 0.88, 0.92, 1)
    local layout = self:getOpenDialogListLayout()
    if layout.totalMaps == 0 then
        graphics.printf("No maps were found yet.", rect.x + 24, rect.y + 142, rect.w - 48, "center")
        return
    end

    love.graphics.setScissor(layout.listRect.x, layout.listRect.y, layout.listRect.w, layout.listRect.h)
    for _, row in ipairs(layout.rows) do
        local savedMap = row.map
        local itemRect = row.rect
        graphics.setColor(0.05, 0.06, 0.08, 1)
        graphics.rectangle("fill", itemRect.x, itemRect.y, itemRect.w, itemRect.h, 12, 12)
        graphics.setColor(0.3, 0.36, 0.42, 1)
        graphics.rectangle("line", itemRect.x, itemRect.y, itemRect.w, itemRect.h, 12, 12)
        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.print(savedMap.name, itemRect.x + 14, itemRect.y + 12)
        graphics.setColor(0.72, 0.78, 0.84, 1)
        graphics.printf(savedMap.source == "builtin" and "Tutorial" or "User Save", itemRect.x, itemRect.y + 12, itemRect.w - 12, "right")
    end
    love.graphics.setScissor()

    if layout.scrollbar then
        graphics.setColor(0.1, 0.12, 0.16, 1)
        graphics.rectangle("fill", layout.scrollbar.track.x, layout.scrollbar.track.y, layout.scrollbar.track.w, layout.scrollbar.track.h, 4, 4)
        graphics.setColor(0.34, 0.44, 0.54, 1)
        graphics.rectangle("fill", layout.scrollbar.thumb.x, layout.scrollbar.thumb.y, layout.scrollbar.thumb.w, layout.scrollbar.thumb.h, 4, 4)
    end

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.72, 0.78, 0.84, 1)
    local rangeText = string.format("Showing %d-%d of %d", layout.firstVisibleIndex, layout.lastVisibleIndex, layout.totalMaps)
    graphics.printf(rangeText, rect.x + 24, rect.y + rect.h - 52, rect.w - 48, "left")
end

function mapEditor:drawTextField(label, rect, valueText, accentColor, active)
    local graphics = love.graphics
    local color = accentColor or { 0.48, 0.92, 0.62 }

    graphics.setColor(0.72, 0.78, 0.84, 1)
    graphics.printf(label, rect.x - 4, rect.y - 17, rect.w + 8, "center")

    graphics.setColor(0.06, 0.08, 0.1, 1)
    graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)
    graphics.setLineWidth(active and 2 or 1.2)
    graphics.setColor(color[1], color[2], color[3], 1)
    graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 8, 8)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf(valueText, rect.x + 6, rect.y + 5, rect.w - 12, "left")
end

function mapEditor:drawColorChip(label, rect, colorId, accentColor)
    local graphics = love.graphics
    local color = accentColor or getColorById(colorId)
    local labelWidth = love.graphics.getFont():getWidth(label)

    graphics.setColor(0.72, 0.78, 0.84, 1)
    graphics.print(label, rect.x - labelWidth - 6, rect.y - 1)

    graphics.setColor(0.06, 0.08, 0.1, 1)
    graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 5, 5)
    graphics.setColor(color[1], color[2], color[3], 1)
    graphics.rectangle("fill", rect.x + 2, rect.y + 2, rect.w - 4, rect.h - 4, 4, 4)
    graphics.setLineWidth(1.1)
    graphics.setColor(0.24, 0.32, 0.4, 1)
    graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 5, 5)
end

function mapEditor:drawSequencerSummaryChip(rect, colorId)
    local graphics = love.graphics
    local color = getColorById(colorId)

    graphics.setColor(0.06, 0.08, 0.1, 1)
    graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 4, 4)
    graphics.setColor(color[1], color[2], color[3], 1)
    graphics.rectangle("fill", rect.x + 2, rect.y + 2, rect.w - 4, rect.h - 4, 3, 3)
    graphics.setLineWidth(1)
    graphics.setColor(0.24, 0.32, 0.4, 1)
    graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 4, 4)
end

function mapEditor:drawSequencerSummaryValue(rect, valueText, align)
    local graphics = love.graphics
    graphics.setColor(0.84, 0.88, 0.92, 1)
    graphics.printf(valueText or "", rect.x, rect.y + 1, rect.w, align or "center")
end

function mapEditor:drawSequencerInlineField(rect, valueText, accentColor, active)
    local graphics = love.graphics
    local color = accentColor or { 0.48, 0.92, 0.62 }

    graphics.setColor(0.06, 0.08, 0.1, 1)
    graphics.rectangle("fill", rect.x, rect.y - 1, rect.w, rect.h + 2, 6, 6)
    graphics.setLineWidth(active and 1.8 or 1)
    graphics.setColor(color[1], color[2], color[3], 1)
    graphics.rectangle("line", rect.x, rect.y - 1, rect.w, rect.h + 2, 6, 6)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.printf(valueText or "", rect.x + 4, rect.y + 1, rect.w - 8, "center")
end

function mapEditor:drawSequencer(game)
    local graphics = love.graphics
    local layout = self:getSequencerLayout()
    local mapDeadlineText = self:getActiveTextFieldValue("map", "map", "timeLimit", self.timeLimit and tostring(self.timeLimit) or "")

    love.graphics.setFont(game.fonts.title)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.print("Train Sequencer", layout.panelX, self.sidePanel.y + 20)

    love.graphics.setFont(game.fonts.small)
    self:drawTextField(
        "Map Deadline",
        layout.mapDeadlineRect,
        mapDeadlineText ~= "" and mapDeadlineText or "",
        { 0.99, 0.78, 0.32 },
        self.activeTextField and self.activeTextField.kind == "map"
    )
    self:drawPanelButton(layout.addRect, "Add Train", { 0.48, 0.92, 0.62 })

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.68, 0.74, 0.8, 1)
    local header = self:getSequencerSummaryRects(layout.listHeaderRect)
    graphics.printf("Start", header.start.x - 2, layout.listHeaderRect.y, header.start.w + 4, "center")
    graphics.printf("Name", header.name.x - 2, layout.listHeaderRect.y, header.name.w + 4, "center")
    graphics.printf("Line", header.lineChip.x - 6, layout.listHeaderRect.y, header.lineChip.w + 12, "center")
    graphics.printf("Goal", header.goalChip.x - 6, layout.listHeaderRect.y, header.goalChip.w + 12, "center")
    graphics.printf("Wagons", header.wagons.x - 4, layout.listHeaderRect.y, header.wagons.w + 8, "center")
    graphics.printf("Deadline", header.deadline.x - 4, layout.listHeaderRect.y, header.deadline.w + 8, "center")

    love.graphics.setScissor(layout.listRect.x, layout.listRect.y, layout.listRect.w, layout.listRect.h)
    for _, row in ipairs(layout.rows) do
        local entry = row.entry
        local train = entry.train
        local controls = self:getSequencerRowControlRects(row.rect)
        local startText = self:getActiveTextFieldValue("train", train.id, "spawnTime", tostring(train.spawnTime or 0))
        local wagonsText = self:getActiveTextFieldValue("train", train.id, "wagonCount", tostring(train.wagonCount or DEFAULT_TRAIN_WAGONS))
        local deadlineText = self:getActiveTextFieldValue("train", train.id, "deadline", train.deadline and tostring(train.deadline) or "--")

        graphics.setColor(0.06, 0.08, 0.1, 1)
        graphics.rectangle("fill", row.rect.x, row.rect.y, row.rect.w, row.rect.h, 12, 12)
        graphics.setLineWidth(1.1)
        graphics.setColor(0.24, 0.32, 0.4, 1)
        graphics.rectangle("line", row.rect.x, row.rect.y, row.rect.w, row.rect.h, 12, 12)

        love.graphics.setFont(game.fonts.small)
        self:drawSequencerInlineField(
            controls.summary.start,
            startText,
            { 0.33, 0.8, 0.98 },
            self.activeTextField and self.activeTextField.kind == "train" and self.activeTextField.targetId == train.id and self.activeTextField.fieldName == "spawnTime"
        )
        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.printf(entry.castName, controls.summary.name.x, controls.summary.name.y + 1, controls.summary.name.w, "left")
        self:drawSequencerSummaryChip(controls.summary.lineChip, train.lineColor)
        self:drawSequencerSummaryChip(controls.summary.goalChip, train.trainColor)
        self:drawSequencerInlineField(
            controls.summary.wagons,
            wagonsText,
            { 0.48, 0.92, 0.62 },
            self.activeTextField and self.activeTextField.kind == "train" and self.activeTextField.targetId == train.id and self.activeTextField.fieldName == "wagonCount"
        )
        self:drawSequencerInlineField(
            controls.summary.deadline,
            deadlineText,
            { 0.99, 0.78, 0.32 },
            self.activeTextField and self.activeTextField.kind == "train" and self.activeTextField.targetId == train.id and self.activeTextField.fieldName == "deadline"
        )

        graphics.setLineWidth(1.1)
        graphics.setColor(0.99, 0.78, 0.32, 1)
        graphics.rectangle("line", controls.summary.remove.x, controls.summary.remove.y, controls.summary.remove.w, controls.summary.remove.h, 5, 5)
        graphics.printf("X", controls.summary.remove.x, controls.summary.remove.y + 1, controls.summary.remove.w, "center")
    end
    love.graphics.setScissor()

    if #layout.rows == 0 then
        love.graphics.setFont(game.fonts.small)
        graphics.setColor(0.84, 0.88, 0.92, 1)
        graphics.printf("No trains are authored yet. Add one to start sequencing this map.", layout.panelX, layout.listRect.y + 24, layout.panelWidth, "center")
    end

    if layout.scrollbar then
        graphics.setColor(0.1, 0.12, 0.16, 1)
        graphics.rectangle("fill", layout.scrollbar.track.x, layout.scrollbar.track.y, layout.scrollbar.track.w, layout.scrollbar.track.h, 4, 4)
        graphics.setColor(0.24, 0.32, 0.4, 1)
        graphics.rectangle("line", layout.scrollbar.track.x, layout.scrollbar.track.y, layout.scrollbar.track.w, layout.scrollbar.track.h, 4, 4)
        graphics.setColor(0.33, 0.8, 0.98, 1)
        graphics.rectangle("fill", layout.scrollbar.thumb.x, layout.scrollbar.thumb.y, layout.scrollbar.thumb.w, layout.scrollbar.thumb.h, 4, 4)
    end

    self:drawPanelButton(layout.backRect, "Back", { 0.99, 0.78, 0.32 })
end

function mapEditor:drawDefaultSidePanel(game)
    local graphics = love.graphics
    local drawerLayout = self:getEditorDrawerLayout()
    local validationLayout = self:getValidationListLayout(game.fonts.small)
    local panelX = validationLayout.panelX
    local panelWidth = validationLayout.panelWidth
    local validationEntries = self:getValidationEntries()

    love.graphics.setFont(game.fonts.small)
    uiControls.drawSegmentedToggle(
        drawerLayout.mapSizeRect,
        MAP_SIZE_PRESETS,
        self:getMapSizePreset().id,
        nil,
        game.fonts.small,
        {
            backgroundColor = { 0.08, 0.1, 0.14, 0.98 },
            activeFillColor = { 0.98, 0.88, 0.34, 0.96 },
            outlineColor = { 0.28, 0.4, 0.52, 1 },
            innerOutlineColor = { 0.46, 0.66, 0.82, 0.45 },
        }
    )
    self:drawPanelButton(
        drawerLayout.gridToggleRect,
        self.gridVisible and "Hide Grid (G)" or "Show Grid (G)",
        { 0.99, 0.78, 0.32 }
    )
    self:drawTextField(
        "Grid Step",
        drawerLayout.gridStepRect,
        self:getActiveTextFieldValue("map", "editor", "gridStep", tostring(self.gridStep)),
        { 0.33, 0.8, 0.98 },
        self.activeTextField and self.activeTextField.kind == "map" and self.activeTextField.fieldName == "gridStep"
    )

    love.graphics.setFont(game.fonts.body)
    graphics.setColor(0.97, 0.98, 1, 1)
    graphics.print("Map Issues", panelX, validationLayout.issuesTitleY)

    love.graphics.setFont(game.fonts.small)
    graphics.setColor(0.99, 0.78, 0.32, 1)
    graphics.printf(validationLayout.resolveText, panelX, validationLayout.resolveTextY, panelWidth)

    graphics.setColor(0.1, 0.12, 0.16, 1)
    graphics.rectangle(
        "fill",
        validationLayout.listRect.x,
        validationLayout.listRect.y,
        validationLayout.listRect.w,
        validationLayout.listRect.h,
        12,
        12
    )
    graphics.setColor(0.24, 0.32, 0.4, 1)
    graphics.rectangle(
        "line",
        validationLayout.listRect.x,
        validationLayout.listRect.y,
        validationLayout.listRect.w,
        validationLayout.listRect.h,
        12,
        12
    )

    if #validationEntries == 0 then
        graphics.setColor(0.62, 0.67, 0.73, 1)
        graphics.printf(
            "No issues found. You're good to go and good to publish this map.",
            validationLayout.listRect.x + 12,
            validationLayout.listRect.y + 12,
            validationLayout.listRect.w - 24
        )
    else
        local visibleRows = self:getVisibleValidationRows(game.fonts.small, validationLayout)

        graphics.setScissor(
            validationLayout.listRect.x,
            validationLayout.listRect.y,
            validationLayout.listRect.w,
            validationLayout.listRect.h
        )
        love.graphics.setFont(game.fonts.small)
        for _, row in ipairs(visibleRows) do
            if row.index == self.hoveredValidationIndex then
                graphics.setColor(0.18, 0.22, 0.27, 0.95)
                graphics.rectangle("fill", row.rect.x - 6, row.rect.y - 4, row.rect.w + 8, row.rect.h + 8, 8, 8)
            end

            local bulletX = row.rect.x + row.indentOffset + 12
            local textX = bulletX + row.numberWidth
            graphics.setColor(0.99, 0.78, 0.32, 1)
            graphics.print(row.numberLabel .. " ", bulletX, row.rect.y)
            drawValidationMessage(
                game.fonts.small,
                row.message,
                textX,
                row.rect.y,
                math.max(20, row.textWidth - 12),
                { 0.84, 0.88, 0.92, 1 },
                getValidationColorDisplayMode(self)
            )
        end
        graphics.setLineWidth(1)
        graphics.setScissor()

        if validationLayout.scrollbar then
            graphics.setColor(0.1, 0.12, 0.16, 1)
            graphics.rectangle(
                "fill",
                validationLayout.scrollbar.track.x,
                validationLayout.scrollbar.track.y,
                validationLayout.scrollbar.track.w,
                validationLayout.scrollbar.track.h,
                4,
                4
            )
            graphics.setColor(0.24, 0.32, 0.4, 1)
            graphics.rectangle(
                "line",
                validationLayout.scrollbar.track.x,
                validationLayout.scrollbar.track.y,
                validationLayout.scrollbar.track.w,
                validationLayout.scrollbar.track.h,
                4,
                4
            )
            graphics.setColor(0.99, 0.78, 0.32, 1)
            graphics.rectangle(
                "fill",
                validationLayout.scrollbar.thumb.x,
                validationLayout.scrollbar.thumb.y,
                validationLayout.scrollbar.thumb.w,
                validationLayout.scrollbar.thumb.h,
                4,
                4
            )
        end
    end

    love.graphics.setFont(game.fonts.small)
    self:drawPanelButton(self:getPlayTestButtonRect(), "Play Map (P)", { 0.64, 0.86, 0.98 }, not self:canPlaySavedMap())
    self:drawPanelButton(self:getUploadMapButtonRect(), "Upload Map (U)", { 0.99, 0.78, 0.32 }, not self:canUploadSavedMap())
    self:drawPanelButton(self:getSaveButtonRect(), "Save Map (S)", { 0.48, 0.92, 0.62 })
    self:drawPanelButton(self:getOpenButtonRect(), "Open Map (O)", { 0.33, 0.8, 0.98 })
    self:drawPanelButton(self:getSequencerButtonRect(), "Train Sequencer (C)", { 0.48, 0.92, 0.62 })
    self:drawPanelButton(self:getResetButtonRect(), "Reset (R)", { 0.99, 0.78, 0.32 })
    self:drawHitboxToggle(game)
    self:drawPanelButton(self:getOpenUserMapsButtonRect(), "Open User Maps Folder", { 0.98, 0.82, 0.34 })
end

function mapEditor:draw(game)
    local graphics = love.graphics
    local cameraCenterX, cameraCenterY = self:getCameraViewportCenter()

    self:updateHoveredValidationEntry(game.fonts.small)

    graphics.setColor(0.05, 0.07, 0.09, 1)
    graphics.rectangle("fill", 0, 0, self.viewport.w, self.viewport.h)

    graphics.push()
    graphics.translate(cameraCenterX, cameraCenterY)
    graphics.scale(self.camera.zoom, self.camera.zoom)
    graphics.translate(-self.camera.x, -self.camera.y)

    graphics.setColor(0.07, 0.09, 0.12, 1)
    graphics.rectangle("fill", self.canvas.x, self.canvas.y, self.canvas.w, self.canvas.h, 18, 18)
    self:drawGrid()

    if self.previewWorld then
        trackSceneRenderer.drawScene(self.previewWorld, {
            drawTrains = false,
            drawCollision = false,
        })
    end

    graphics.setColor(0.25, 0.34, 0.42, 1)
    graphics.setLineWidth(2 / math.max(self.camera.zoom, 0.0001))
    graphics.rectangle("line", self.canvas.x, self.canvas.y, self.canvas.w, self.canvas.h, 18, 18)

    for _, intersection in ipairs(self.intersections) do
        self:drawIntersection(intersection)
    end

    for _, route in ipairs(self.routes) do
        self:drawRouteHandles(route, self.selectedRouteId)
    end

    self:drawHitboxOverlay(game)

    graphics.pop()

    graphics.setColor(0.09, 0.11, 0.15, 0.98)
    graphics.rectangle("fill", self.sidePanel.x, self.sidePanel.y, self.sidePanel.w, self.sidePanel.h, 18, 18)
    graphics.setColor(0.22, 0.28, 0.34, 1)
    graphics.rectangle("line", self.sidePanel.x, self.sidePanel.y, self.sidePanel.w, self.sidePanel.h, 18, 18)

    if self.sidePanelMode == "sequencer" then
        self:drawSequencer(game)
    else
        love.graphics.setFont(game.fonts.title)
        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.print("Map Editor", self.sidePanel.x + 18, self.sidePanel.y + 20)
        self:drawDefaultSidePanel(game)
    end

    self:drawColorPicker(game)
    self:drawRouteTypePicker(game)
    self:drawStatusToast(game)
    self:drawValidationMarkers()

    self:drawDialog(game)
end

return mapEditor
