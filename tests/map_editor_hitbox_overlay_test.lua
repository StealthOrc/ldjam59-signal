package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}
love.timer = love.timer or {
    getTime = function()
        return 0
    end,
}
love.filesystem = love.filesystem or {}
love.keyboard = love.keyboard or {
    isDown = function()
        return false
    end,
}
love.mouse = love.mouse or {
    isDown = function()
        return false
    end,
}

local mapEditor = require("src.game.map_editor")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %q but got %q", label, expected, actual), 2)
    end
end

local function assertTrue(value, label)
    if not value then
        error(label, 2)
    end
end

local function assertNear(actual, expected, tolerance, label)
    if math.abs(actual - expected) > tolerance then
        error(string.format("%s expected %.4f but got %.4f", label, expected, actual), 2)
    end
end

local function findOverlayEntry(entries, label)
    for _, entry in ipairs(entries or {}) do
        if entry.label == label then
            return entry
        end
    end
    return nil
end

local function polygonEdgeLength(points, startIndex, endIndex)
    local startX = points[startIndex]
    local startY = points[startIndex + 1]
    local endX = points[endIndex]
    local endY = points[endIndex + 1]
    local dx = endX - startX
    local dy = endY - startY
    return math.sqrt(dx * dx + dy * dy)
end

local editorData = {
    endpoints = {
        { id = "input_a", kind = "input", x = 636 / 1280, y = 400 / 720, colors = { "blue" } },
        { id = "output_a", kind = "output", x = 644 / 1280, y = 400 / 720, colors = { "blue" } },
        { id = "input_b", kind = "input", x = 636 / 1280, y = 360 / 720, colors = { "orange" } },
        { id = "output_b", kind = "output", x = 644 / 1280, y = 360 / 720, colors = { "orange" } },
    },
    routes = {
        {
            id = "route_a",
            label = "route_a",
            color = "blue",
            startEndpointId = "input_a",
            endEndpointId = "output_a",
            segmentRoadTypes = { "normal", "normal" },
            points = {
                { x = 636 / 1280, y = 400 / 720 },
                { x = 640 / 1280, y = 360 / 720 },
                { x = 644 / 1280, y = 400 / 720 },
            },
        },
        {
            id = "route_b",
            label = "route_b",
            color = "orange",
            startEndpointId = "input_b",
            endEndpointId = "output_b",
            segmentRoadTypes = { "normal", "normal" },
            points = {
                { x = 636 / 1280, y = 360 / 720 },
                { x = 640 / 1280, y = 400 / 720 },
                { x = 644 / 1280, y = 360 / 720 },
            },
        },
    },
    junctions = {},
    trains = {},
}

local editor = mapEditor.new(1280, 720, nil)
editor:loadEditorData(editorData, "Hitbox Overlay", nil, nil)

local resetRect = editor:getResetButtonRect()
local toggleRect = editor:getHitboxToggleRect()
assertEqual(resetRect.w, toggleRect.w, "reset and hitbox toggle should split the bottom row evenly")
assertTrue(toggleRect.x > resetRect.x + resetRect.w, "hitbox toggle should sit to the right of reset")

assertEqual(editor.hitboxOverlayVisible, false, "hitbox overlay starts hidden")
assertTrue(editor:keypressed("f3"), "f3 should be handled by the editor")
assertEqual(editor.hitboxOverlayVisible, true, "f3 enables the hitbox overlay")

local entries = editor:getHitboxOverlayEntries()
assertTrue(#entries > 0, "hitbox overlay should expose entries for the current map")
assertTrue(entries[1].zIndex > entries[#entries].zIndex, "overlay z-indices should descend through hit order")
assertTrue(entries[1].label:find("route_b end", 1, true) ~= nil, "top hitbox should match the last route end magnet")

local sawSegment = false
local sawIntersection = false
for _, entry in ipairs(entries) do
    if entry.label:find("segment", 1, true) then
        sawSegment = true
    end
    if entry.label:find("direct", 1, true) then
        sawIntersection = true
    end
end

assertTrue(sawSegment, "overlay should include segment hitboxes")
assertTrue(sawIntersection, "overlay should include junction hitboxes")

local defaultBendEntry = findOverlayEntry(entries, "route_b bend 2")
local defaultSegmentEntry = findOverlayEntry(entries, "route_b segment 1")
assertTrue(defaultBendEntry ~= nil, "overlay should expose bend hitboxes by label")
assertTrue(defaultSegmentEntry ~= nil, "overlay should expose segment hitboxes by label")

local defaultBendWidth = defaultBendEntry.rect.w
local defaultSegmentThickness = polygonEdgeLength(defaultSegmentEntry.points, 1, 7)

editor.camera.zoom = 0.5
local zoomedOutEntries = editor:getHitboxOverlayEntries()
local zoomedOutBendEntry = findOverlayEntry(zoomedOutEntries, "route_b bend 2")
local zoomedOutSegmentEntry = findOverlayEntry(zoomedOutEntries, "route_b segment 1")
assertNear(zoomedOutBendEntry.rect.w, defaultBendWidth, 0.0001, "bend hitbox width should stay stable when zooming out")
assertNear(
    polygonEdgeLength(zoomedOutSegmentEntry.points, 1, 7),
    defaultSegmentThickness,
    0.0001,
    "segment hitbox thickness should stay stable when zooming out"
)

editor.camera.zoom = 2
local zoomedInEntries = editor:getHitboxOverlayEntries()
local zoomedInBendEntry = findOverlayEntry(zoomedInEntries, "route_b bend 2")
local zoomedInSegmentEntry = findOverlayEntry(zoomedInEntries, "route_b segment 1")
assertNear(zoomedInBendEntry.rect.w, defaultBendWidth, 0.0001, "bend hitbox width should stay stable when zooming in")
assertNear(
    polygonEdgeLength(zoomedInSegmentEntry.points, 1, 7),
    defaultSegmentThickness,
    0.0001,
    "segment hitbox thickness should stay stable when zooming in"
)

editor.camera.zoom = 1

assertTrue(editor:keypressed("f3"), "f3 should also disable the hitbox overlay")
assertEqual(editor.hitboxOverlayVisible, false, "f3 disables the hitbox overlay")

print("map editor hitbox overlay tests passed")
