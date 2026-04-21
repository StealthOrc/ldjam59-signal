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

local roadEditorData = {
    mapSize = { w = 1280, h = 720 },
    endpoints = {
        { id = "input_a", kind = "input", x = 120 / 1280, y = 160 / 720, colors = { "blue" } },
        { id = "output_a", kind = "output", x = 1120 / 1280, y = 160 / 720, colors = { "blue" } },
        { id = "input_b", kind = "input", x = 120 / 1280, y = 320 / 720, colors = { "orange" } },
        { id = "output_b", kind = "output", x = 520 / 1280, y = 320 / 720, colors = { "orange" } },
    },
    routes = {
        {
            id = "route_straight",
            label = "route_straight",
            color = "blue",
            startEndpointId = "input_a",
            endEndpointId = "output_a",
            segmentRoadTypes = { "normal" },
            points = {
                { x = 120 / 1280, y = 160 / 720 },
                { x = 1120 / 1280, y = 160 / 720 },
            },
        },
        {
            id = "route_bend",
            label = "route_bend",
            color = "orange",
            startEndpointId = "input_b",
            endEndpointId = "output_b",
            segmentRoadTypes = { "normal", "normal" },
            points = {
                { x = 120 / 1280, y = 320 / 720 },
                { x = 320 / 1280, y = 320 / 720 },
                { x = 520 / 1280, y = 320 / 720 },
            },
        },
    },
    junctions = {},
    trains = {},
}

local intersectionEditorData = {
    mapSize = { w = 1280, h = 720 },
    endpoints = {
        { id = "input_left", kind = "input", x = 0.18, y = 0.2, colors = { "blue" } },
        { id = "output_right", kind = "output", x = 0.82, y = 0.8, colors = { "blue" } },
        { id = "input_right", kind = "input", x = 0.82, y = 0.2, colors = { "orange" } },
        { id = "output_left", kind = "output", x = 0.18, y = 0.8, colors = { "orange" } },
    },
    routes = {
        {
            id = "route_blue",
            label = "route_blue",
            color = "blue",
            startEndpointId = "input_left",
            endEndpointId = "output_right",
            segmentRoadTypes = { "normal" },
            points = {
                { x = 0.18, y = 0.2 },
                { x = 0.82, y = 0.8 },
            },
        },
        {
            id = "route_orange",
            label = "route_orange",
            color = "orange",
            startEndpointId = "input_right",
            endEndpointId = "output_left",
            segmentRoadTypes = { "normal" },
            points = {
                { x = 0.82, y = 0.2 },
                { x = 0.18, y = 0.8 },
            },
        },
    },
    junctions = {},
    trains = {},
}

local function newRoadEditor()
    local editor = mapEditor.new(1280, 720, nil)
    editor:loadEditorData(roadEditorData, "Road Guard Regression", nil, nil)
    editor.camera.zoom = 1
    return editor
end

local function newIntersectionEditor()
    local editor = mapEditor.new(1280, 720, nil)
    editor:loadEditorData(intersectionEditorData, "Intersection Guard Regression", nil, nil)
    editor.camera.zoom = 1
    return editor
end

local roadEditor = newRoadEditor()
local roadRouteCountBefore = #roadEditor.routes
local roadPointCountBefore = #roadEditor.routes[1].points
local roadNearScreenX, roadNearScreenY = roadEditor:mapToScreen(320, 196)
roadEditor:mousepressed(roadNearScreenX, roadNearScreenY, 1)
assertEqual(#roadEditor.routes, roadRouteCountBefore, "near-road misses should not create a new route")
assertEqual(#roadEditor.routes[1].points, roadPointCountBefore, "near-road misses should not change an existing route")

local bendEditor = newRoadEditor()
local bendRouteCountBefore = #bendEditor.routes
local bendScreenX, bendScreenY = bendEditor:mapToScreen(349, 320)
bendEditor:mousepressed(bendScreenX, bendScreenY, 1)
assertEqual(#bendEditor.routes, bendRouteCountBefore, "near-bend misses should not create a new route")

local endpointEditor = newRoadEditor()
local endpointRouteCountBefore = #endpointEditor.routes
local endpointScreenX, endpointScreenY = endpointEditor:mapToScreen(120, 183)
endpointEditor:mousepressed(endpointScreenX, endpointScreenY, 1)
assertEqual(#endpointEditor.routes, endpointRouteCountBefore, "near-endpoint misses should not create a new route")

local intersectionEditor = newIntersectionEditor()
local intersectionRouteCountBefore = #intersectionEditor.routes
local intersectionScreenX, intersectionScreenY = intersectionEditor:mapToScreen(640, 388)
intersectionEditor:mousepressed(intersectionScreenX, intersectionScreenY, 1)
assertEqual(#intersectionEditor.routes, intersectionRouteCountBefore, "near-junction misses should not create a new route")

local farEditor = newRoadEditor()
local farRouteCountBefore = #farEditor.routes
local farScreenX, farScreenY = farEditor:mapToScreen(900, 520)
farEditor:mousepressed(farScreenX, farScreenY, 1)
assertEqual(#farEditor.routes, farRouteCountBefore + 1, "far clicks should still start a new route")
assertTrue(farEditor.drag and farEditor.drag.kind == "new_route", "far clicks should start dragging the new route endpoint")

print("map editor hitbox regression tests passed")
