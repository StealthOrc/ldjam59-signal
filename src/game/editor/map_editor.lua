local mapStorage = require("src.game.storage.map_storage")
local mapCompiler = require("src.game.map_compiler.map_compiler")
local json = require("src.game.util.json")
local roadTypes = require("src.game.data.road_types")
local uuid = require("src.game.util.uuid")
local world = require("src.game.gameplay.railway_world")
local trackSceneRenderer = require("src.game.rendering.track_scene_renderer")
local uiControls = require("src.game.ui.ui_controls")

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
local START_MAGNET_DRAW_WIDTH = 58
local END_MAGNET_DRAW_WIDTH = 46
local MAGNET_DRAW_HEIGHT = 24
local MAGNET_DRAW_OUTLINE_PADDING = 3
local MAGNET_SELECTION_PADDING = 8
local BEND_POINT_OUTER_RADIUS = 11
local BEND_POINT_INNER_RADIUS = 8
local BEND_POINT_SELECTION_RADIUS = 16
local POINT_HIT_RADIUS = BEND_POINT_SELECTION_RADIUS
local INTERSECTION_HIT_RADIUS = 22
local INTERSECTION_UNSUPPORTED_HIT_RADIUS = 18
local SEGMENT_HIT_RADIUS = 16
local SEGMENT_HIT_MIN_HALF_WIDTH = 8
local SEGMENT_HIT_HALF_WIDTH_RATIO = 0.3
local SEGMENT_HIT_MIN_INSET = 4
local SEGMENT_HIT_INSET_RATIO = 0.22
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
local MAX_INTERSECTION_MATERIALIZE_PASSES = 3
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
        authored = point.authored ~= false,
        linkedPointGroupId = point.linkedPointGroupId,
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


local shared = {
    mapStorage = mapStorage,
    mapCompiler = mapCompiler,
    json = json,
    roadTypes = roadTypes,
    uuid = uuid,
    world = world,
    trackSceneRenderer = trackSceneRenderer,
    uiControls = uiControls,
    DEFAULT_CONTROL = DEFAULT_CONTROL,
    MAX_TRIP_PASS_COUNT = MAX_TRIP_PASS_COUNT,
    MERGE_SNAP_RADIUS = MERGE_SNAP_RADIUS,
    INTERSECTION_GROUP_BUCKET = INTERSECTION_GROUP_BUCKET,
    STRICT_INTERSECTION_CLUSTER_RADIUS = STRICT_INTERSECTION_CLUSTER_RADIUS,
    SHARED_LANE_STRIPE_LENGTH = SHARED_LANE_STRIPE_LENGTH,
    CONTROL_ORDER = CONTROL_ORDER,
    DEFAULT_TRAIN_WAGONS = DEFAULT_TRAIN_WAGONS,
    LEGACY_TRAIN_SPEED = LEGACY_TRAIN_SPEED,
    DEFAULT_ROAD_TYPE = DEFAULT_ROAD_TYPE,
    LEGACY_MAP_WIDTH = LEGACY_MAP_WIDTH,
    LEGACY_MAP_HEIGHT = LEGACY_MAP_HEIGHT,
    DEFAULT_NEW_MAP_WIDTH = DEFAULT_NEW_MAP_WIDTH,
    DEFAULT_NEW_MAP_HEIGHT = DEFAULT_NEW_MAP_HEIGHT,
    MAP_SIZE_PRESETS = MAP_SIZE_PRESETS,
    DEFAULT_GRID_STEP = DEFAULT_GRID_STEP,
    MIN_GRID_STEP = MIN_GRID_STEP,
    MAX_GRID_STEP = MAX_GRID_STEP,
    CAMERA_PADDING = CAMERA_PADDING,
    CAMERA_MIN_ZOOM = CAMERA_MIN_ZOOM,
    CAMERA_MAX_ZOOM = CAMERA_MAX_ZOOM,
    PANEL_OVERLAY_MARGIN = PANEL_OVERLAY_MARGIN,
    GRID_MINOR_ALPHA = GRID_MINOR_ALPHA,
    GRID_MAJOR_ALPHA = GRID_MAJOR_ALPHA,
    ROAD_TYPE_OPTIONS = ROAD_TYPE_OPTIONS,
    VALIDATION_CHILD_INDENT = VALIDATION_CHILD_INDENT,
    PANEL_BUTTON_SIDE_MARGIN = PANEL_BUTTON_SIDE_MARGIN,
    PANEL_BUTTON_HEIGHT = PANEL_BUTTON_HEIGHT,
    PANEL_BUTTON_GAP = PANEL_BUTTON_GAP,
    PANEL_BUTTON_BOTTOM_MARGIN = PANEL_BUTTON_BOTTOM_MARGIN,
    STATUS_TOAST_MARGIN = STATUS_TOAST_MARGIN,
    STATUS_TOAST_FADE_TIME = STATUS_TOAST_FADE_TIME,
    START_MAGNET_DRAW_WIDTH = START_MAGNET_DRAW_WIDTH,
    END_MAGNET_DRAW_WIDTH = END_MAGNET_DRAW_WIDTH,
    MAGNET_DRAW_HEIGHT = MAGNET_DRAW_HEIGHT,
    MAGNET_DRAW_OUTLINE_PADDING = MAGNET_DRAW_OUTLINE_PADDING,
    MAGNET_SELECTION_PADDING = MAGNET_SELECTION_PADDING,
    BEND_POINT_OUTER_RADIUS = BEND_POINT_OUTER_RADIUS,
    BEND_POINT_INNER_RADIUS = BEND_POINT_INNER_RADIUS,
    BEND_POINT_SELECTION_RADIUS = BEND_POINT_SELECTION_RADIUS,
    POINT_HIT_RADIUS = POINT_HIT_RADIUS,
    INTERSECTION_HIT_RADIUS = INTERSECTION_HIT_RADIUS,
    INTERSECTION_UNSUPPORTED_HIT_RADIUS = INTERSECTION_UNSUPPORTED_HIT_RADIUS,
    SEGMENT_HIT_RADIUS = SEGMENT_HIT_RADIUS,
    SEGMENT_HIT_MIN_HALF_WIDTH = SEGMENT_HIT_MIN_HALF_WIDTH,
    SEGMENT_HIT_HALF_WIDTH_RATIO = SEGMENT_HIT_HALF_WIDTH_RATIO,
    SEGMENT_HIT_MIN_INSET = SEGMENT_HIT_MIN_INSET,
    SEGMENT_HIT_INSET_RATIO = SEGMENT_HIT_INSET_RATIO,
    HITBOX_OVERLAY_FILL_ALPHA = HITBOX_OVERLAY_FILL_ALPHA,
    HITBOX_OVERLAY_OUTLINE_ALPHA = HITBOX_OVERLAY_OUTLINE_ALPHA,
    HITBOX_OVERLAY_LABEL_BACKGROUND_ALPHA = HITBOX_OVERLAY_LABEL_BACKGROUND_ALPHA,
    HITBOX_OVERLAY_LABEL_TEXT_ALPHA = HITBOX_OVERLAY_LABEL_TEXT_ALPHA,
    HITBOX_OVERLAY_LABEL_OFFSET_Y = HITBOX_OVERLAY_LABEL_OFFSET_Y,
    HITBOX_OVERLAY_LABEL_PADDING_X = HITBOX_OVERLAY_LABEL_PADDING_X,
    HITBOX_OVERLAY_LABEL_PADDING_Y = HITBOX_OVERLAY_LABEL_PADDING_Y,
    HITBOX_OVERLAY_LABEL_CORNER_RADIUS = HITBOX_OVERLAY_LABEL_CORNER_RADIUS,
    HITBOX_OVERLAY_RECT_CORNER_RADIUS = HITBOX_OVERLAY_RECT_CORNER_RADIUS,
    HITBOX_OVERLAY_STROKE_WIDTH = HITBOX_OVERLAY_STROKE_WIDTH,
    HITBOX_OVERLAY_EPSILON = HITBOX_OVERLAY_EPSILON,
    DRAG_START_DISTANCE_SQUARED = DRAG_START_DISTANCE_SQUARED,
    INTERSECTION_SELECTOR_OFFSET_Y = INTERSECTION_SELECTOR_OFFSET_Y,
    INTERSECTION_SELECTOR_CLICK_RADIUS = INTERSECTION_SELECTOR_CLICK_RADIUS,
    INTERSECTION_SELECTOR_DRAW_RADIUS = INTERSECTION_SELECTOR_DRAW_RADIUS,
    INTERSECTION_POINT_TOLERANCE_SQUARED = INTERSECTION_POINT_TOLERANCE_SQUARED,
    INTERNAL_POINT_MATCH_DISTANCE_SQUARED = INTERNAL_POINT_MATCH_DISTANCE_SQUARED,
    INTERSECTION_SHARED_POINT_DISTANCE_SQUARED = INTERSECTION_SHARED_POINT_DISTANCE_SQUARED,
    INTERSECTION_STATE_MATCH_DISTANCE_SQUARED = INTERSECTION_STATE_MATCH_DISTANCE_SQUARED,
    MAX_INTERSECTION_MATERIALIZE_PASSES = MAX_INTERSECTION_MATERIALIZE_PASSES,
    JUNCTION_MENU_SIZE_MULTIPLIER = JUNCTION_MENU_SIZE_MULTIPLIER,
    JUNCTION_MENU_POP_DURATION = JUNCTION_MENU_POP_DURATION,
    JUNCTION_MENU_ROOT_RADIUS = JUNCTION_MENU_ROOT_RADIUS,
    JUNCTION_MENU_RING_INNER_RADIUS = JUNCTION_MENU_RING_INNER_RADIUS,
    JUNCTION_MENU_COLOR_OUTER_RADIUS = JUNCTION_MENU_COLOR_OUTER_RADIUS,
    JUNCTION_MENU_TYPE_OUTER_RADIUS = JUNCTION_MENU_TYPE_OUTER_RADIUS,
    JUNCTION_MENU_BRANCH_RATIO = JUNCTION_MENU_BRANCH_RATIO,
    JUNCTION_MENU_ICON_SIZE = JUNCTION_MENU_ICON_SIZE,
    JUNCTION_MENU_TYPE_ICON_SIZE = JUNCTION_MENU_TYPE_ICON_SIZE,
    JUNCTION_MENU_SWATCH_RADIUS = JUNCTION_MENU_SWATCH_RADIUS,
    JUNCTION_MENU_EDGE_MARGIN = JUNCTION_MENU_EDGE_MARGIN,
    EMPTY_MAP_VALIDATION_TEXT = EMPTY_MAP_VALIDATION_TEXT,
    UPLOAD_UNAVAILABLE_MESSAGE = UPLOAD_UNAVAILABLE_MESSAGE,
    ROAD_PATTERN_OUTLINE = ROAD_PATTERN_OUTLINE,
    ROAD_PATTERN_FILL = ROAD_PATTERN_FILL,
    CONTROL_LABELS = CONTROL_LABELS,
    CONTROL_NAMES = CONTROL_NAMES,
    CONTROL_FILL_COLORS = CONTROL_FILL_COLORS,
    COLOR_OPTIONS = COLOR_OPTIONS,
    SAO_CAST = SAO_CAST,
    DEFAULT_CONTROL_CONFIGS = DEFAULT_CONTROL_CONFIGS,
    clamp = clamp,
    pointInRect = pointInRect,
    loadOptionalImage = loadOptionalImage,
    encodeUrlPath = encodeUrlPath,
    buildFileUrl = buildFileUrl,
    distanceSquared = distanceSquared,
    lerp = lerp,
    copyPoint = copyPoint,
    normalizeColor = normalizeColor,
    darkerColor = darkerColor,
    routePairKey = routePairKey,
    buildRouteKey = buildRouteKey,
    buildBlankEditorData = buildBlankEditorData,
    isLocalSavedMapDescriptor = isLocalSavedMapDescriptor,
    segmentLength = segmentLength,
    angleBetweenPoints = angleBetweenPoints,
    angleBetweenCoordinates = angleBetweenCoordinates,
    normalizeAngle = normalizeAngle,
    buildDefaultSegmentRoadTypes = buildDefaultSegmentRoadTypes,
    formatNumber = formatNumber,
    clampRectValue = clampRectValue,
    countLookupEntries = countLookupEntries,
    lookupToSortedIds = lookupToSortedIds,
    colorsToLookup = colorsToLookup,
    normalizeEndpointColors = normalizeEndpointColors,
    getEndpointColorIds = getEndpointColorIds,
    getColorOptionById = getColorOptionById,
    getColorById = getColorById,
    getColorOrderIndex = getColorOrderIndex,
    roundStep = roundStep,
    copyArray = copyArray,
    nearestColorId = nearestColorId,
    segmentIntersection = segmentIntersection,
    closestPointOnSegment = closestPointOnSegment,
    pointOnSegment = pointOnSegment,
    chooseBestCandidatePoint = chooseBestCandidatePoint,
    roundPointKey = roundPointKey,
    buildSegmentGroupKey = buildSegmentGroupKey,
    buildIntersectionId = buildIntersectionId,
    getWrappedLineCount = getWrappedLineCount,
    sanitizeMapSize = sanitizeMapSize,
    sanitizeGridStep = sanitizeGridStep,
    getValidationEntryMessage = getValidationEntryMessage,
    getColorLabel = getColorLabel,
    buildTrainValidationLabel = buildTrainValidationLabel,
    getValidationColorDisplayMode = getValidationColorDisplayMode,
    getValidationColorSwatchSize = getValidationColorSwatchSize,
    sanitizeColorAffix = sanitizeColorAffix,
    parseValidationColorWord = parseValidationColorWord,
    buildValidationWordParts = buildValidationWordParts,
    measureValidationMessage = measureValidationMessage,
    drawValidationMessage = drawValidationMessage,
}

require("src.game.editor.map_editor_state")(mapEditor, shared)
require("src.game.editor.map_editor_panels")(mapEditor, shared)
require("src.game.editor.map_editor_document")(mapEditor, shared)
require("src.game.editor.map_editor_shared_lanes")(mapEditor, shared)
require("src.game.editor.map_editor_intersections")(mapEditor, shared)
require("src.game.editor.map_editor_input")(mapEditor, shared)
require("src.game.editor.map_editor_rendering")(mapEditor, shared)

return mapEditor
