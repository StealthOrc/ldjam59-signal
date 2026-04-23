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
            segmentRoadTypes = { "normal", "normal", "normal", "normal" },
            points = {
                { x = 0.20, y = 0.10 },
                { x = 0.50, y = 0.28 },
                { x = 0.50, y = 0.43 },
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
editor:loadEditorData(editorData, "Shared Output Lane Collinear Bendpoint Regression", nil, nil)

assertEqual(#(editor.intersections or {}), 2, "shared lane setup should still produce two junctions")

local upperIntersection = editor.intersections[1]
local lowerIntersection = editor.intersections[2]
local previewUpperJunction = editor.previewWorld and editor.previewWorld.junctions and editor.previewWorld.junctions[upperIntersection.id]
local previewLowerJunction = editor.previewWorld and editor.previewWorld.junctions and editor.previewWorld.junctions[lowerIntersection.id]

assertTrue(previewUpperJunction ~= nil, "preview world should expose the top junction")
assertTrue(previewLowerJunction ~= nil, "preview world should expose the bottom junction")
assertEqual(#(previewUpperJunction.outputs or {}), 1, "top junction should still collapse one shared outgoing lane with a redundant bend point")
assertEqual(#(previewLowerJunction.inputs or {}), 1, "bottom junction should still collapse one shared incoming lane with a redundant bend point")

local level, errorText, errors = mapCompiler.buildPlayableLevel(
    "Shared Output Lane Collinear Bendpoint Regression",
    editor:getExportData(),
    nil
)
if errorText ~= nil then
    error(string.format("expected shared output lane map to compile, got %s", tostring(errorText)), 2)
end

assertEqual(#(errors or {}), 0, "shared output lane map should compile without validation errors")
assertEqual(#(level.edges or {}), 5, "shared authored lane between the two junctions should still compile into one edge")

local sharedMiddleEdges = {}
for _, edge in ipairs(level.edges or {}) do
    if edge.sourceId == upperIntersection.id and edge.targetId == lowerIntersection.id then
        sharedMiddleEdges[#sharedMiddleEdges + 1] = edge
    end
end

assertEqual(#sharedMiddleEdges, 1, "top and bottom junctions should still be connected by one merged lane")
assertEqual(#(sharedMiddleEdges[1].colors or {}), 2, "merged lane should keep both contributing route colors")
assertEqual(#(sharedMiddleEdges[1].points or {}), 2, "merged lane should simplify away the redundant collinear bend point")

print("map editor shared output lane collinear bendpoint tests passed")
