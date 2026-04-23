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

local mapEditor = require("src.game.editor.map_editor")
local mapCompiler = require("src.game.map_compiler.map_compiler")

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

local function assertFalse(value, label)
    if value then
        error(label, 2)
    end
end

local editorData = {
    endpoints = {
        { id = "input_blue", kind = "input", x = 0.20, y = 0.10, colors = { "blue" } },
        { id = "input_yellow", kind = "input", x = 0.80, y = 0.10, colors = { "yellow" } },
        { id = "output_blue", kind = "output", x = 0.35, y = 0.90, colors = { "blue" } },
        { id = "output_yellow", kind = "output", x = 0.65, y = 0.90, colors = { "yellow" } },
    },
    routes = {
        {
            id = "route_blue",
            label = "route_blue",
            color = "blue",
            startEndpointId = "input_blue",
            endEndpointId = "output_blue",
            segmentRoadTypes = { "normal", "normal", "normal" },
            points = {
                { x = 0.20, y = 0.10 },
                { x = 0.50, y = 0.28 },
                { x = 0.50, y = 0.58 },
                { x = 0.35, y = 0.90 },
            },
        },
        {
            id = "route_yellow",
            label = "route_yellow",
            color = "yellow",
            startEndpointId = "input_yellow",
            endEndpointId = "output_yellow",
            segmentRoadTypes = { "normal", "normal", "normal" },
            points = {
                { x = 0.80, y = 0.10 },
                { x = 0.50, y = 0.28 },
                { x = 0.50, y = 0.58 },
                { x = 0.65, y = 0.90 },
            },
        },
    },
    junctions = {
        {
            id = "junction_top_seed",
            x = 0.50,
            y = 0.28,
            control = "direct",
            activeInputIndex = 1,
            activeOutputIndex = 1,
            routes = { "route_blue", "route_yellow" },
        },
        {
            id = "junction_bottom_seed",
            x = 0.50,
            y = 0.58,
            control = "direct",
            activeInputIndex = 1,
            activeOutputIndex = 1,
            routes = { "route_blue", "route_yellow" },
        },
    },
    trains = {},
}

local editor = mapEditor.new(1280, 720, nil)
editor:loadEditorData(editorData, "Shared Output Lane Regression", nil, nil)

assertEqual(#(editor.intersections or {}), 2, "shared lane setup should produce two junctions")

local upperIntersection = editor.intersections[1]
local lowerIntersection = editor.intersections[2]
assertTrue(upperIntersection.y < lowerIntersection.y, "junctions should stay sorted from top to bottom")
assertEqual(#(upperIntersection.outputEndpointIds or {}), 2, "raw editor intersection still sees two final route outputs")

local routeBlue = editor:getRouteById("route_blue")
local sharedLane = editor:getSharedLaneForSegment(routeBlue, 2)
assertTrue(sharedLane ~= nil, "shared output lane should expose one shared lane model")
assertEqual(#(sharedLane.members or {}), 2, "shared output lane model should contain both authored routes")

local overlayLabels = {}
for _, entry in ipairs(editor:getHitboxOverlayEntries()) do
    overlayLabels[#overlayLabels + 1] = entry.label
end

local foundSharedLaneLabel = false
for _, label in ipairs(overlayLabels) do
    if label:find("shared lane", 1, true)
        and label:find("route_blue", 1, true)
        and label:find("route_yellow", 1, true) then
        foundSharedLaneLabel = true
        break
    end
end
assertTrue(foundSharedLaneLabel, "shared output lane debug labels should list every member route")
local previewUpperJunction = editor.previewWorld and editor.previewWorld.junctions and editor.previewWorld.junctions[upperIntersection.id]
local previewLowerJunction = editor.previewWorld and editor.previewWorld.junctions and editor.previewWorld.junctions[lowerIntersection.id]

assertTrue(previewUpperJunction ~= nil, "preview world should expose the top junction")
assertTrue(previewLowerJunction ~= nil, "preview world should expose the bottom junction")
assertEqual(#(previewUpperJunction.outputs or {}), 1, "top junction should collapse the shared outgoing lane into one output")
assertEqual(#(previewLowerJunction.inputs or {}), 1, "bottom junction should collapse the shared incoming lane into one input")

local selectorRect = editor:getOutputSelectorHitRect(upperIntersection)
assertFalse(
    editor:isIntersectionOutputSelectorHit(upperIntersection, selectorRect.x + selectorRect.w * 0.5, selectorRect.y + selectorRect.h * 0.5),
    "top junction should not expose an output selector when only one logical output lane remains"
)

local level, errorText, errors = mapCompiler.buildPlayableLevel("Shared Output Lane Regression", editor:getExportData(), nil)
if errorText ~= nil then
    error(string.format("expected shared output lane map to compile, got %s", tostring(errorText)), 2)
end

assertEqual(#(errors or {}), 0, "shared output lane map should compile without validation errors")
assertTrue(level ~= nil, "expected a playable level to be built")
assertEqual(#(level.edges or {}), 5, "shared authored lane between the two junctions should compile into one edge")

local sharedMiddleEdges = {}
for _, edge in ipairs(level.edges or {}) do
    if edge.sourceId == upperIntersection.id and edge.targetId == lowerIntersection.id then
        sharedMiddleEdges[#sharedMiddleEdges + 1] = edge
    end
end

assertEqual(#sharedMiddleEdges, 1, "top and bottom junctions should be connected by a single merged lane")
assertEqual(#(sharedMiddleEdges[1].colors or {}), 2, "merged lane should keep both contributing route colors")
assertTrue(sharedMiddleEdges[1].colors[1] ~= sharedMiddleEdges[1].colors[2], "merged lane colors should remain distinct")

print("map editor shared output lane tests passed")

