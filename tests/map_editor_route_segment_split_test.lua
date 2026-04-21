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

local editor = mapEditor.new(1280, 720, nil)
editor:loadEditorData(editorData, "Route Segment Split Regression", nil, nil)

assertEqual(#(editor.intersections or {}), 1, "crossing routes should produce one junction")

local routeBlue = editor:getRouteById("route_blue")
local routeOrange = editor:getRouteById("route_orange")

assertEqual(#routeBlue.points, 3, "junction crossing should split the blue route into two editor segments")
assertEqual(#routeOrange.points, 3, "junction crossing should split the orange route into two editor segments")
assertEqual(#routeBlue.segmentRoadTypes, 2, "blue route should keep one road type entry per split segment")
assertEqual(#routeOrange.segmentRoadTypes, 2, "orange route should keep one road type entry per split segment")
assertTrue(routeBlue.points[2].sharedPointId ~= nil, "split blue route should create a shared junction point")
assertEqual(routeBlue.points[2].sharedPointId, routeOrange.points[2].sharedPointId, "split routes should share one junction point id")

editor:setRouteSegmentRoadType(routeBlue, 2, "fast")

assertEqual(routeBlue.segmentRoadTypes[1], "normal", "changing the second segment should not change the first segment")
assertEqual(routeBlue.segmentRoadTypes[2], "fast", "changing the second segment should only update that section")

local previewFirst = editor.previewWorld and editor.previewWorld.edges and editor.previewWorld.edges.route_blue_segment_1
local previewSecond = editor.previewWorld and editor.previewWorld.edges and editor.previewWorld.edges.route_blue_segment_2

assertTrue(previewFirst ~= nil, "preview world should keep the pre-junction road section")
assertTrue(previewSecond ~= nil, "preview world should keep the post-junction road section")
assertEqual(previewFirst.roadType, "normal", "pre-junction section should keep its original road type")
assertEqual(previewSecond.roadType, "fast", "post-junction section should use the updated road type")
assertEqual(previewFirst.styleSections[1].roadType, "normal", "pre-junction style section should stay normal")
assertEqual(previewSecond.styleSections[1].roadType, "fast", "post-junction style section should become fast")

local intersection = editor.intersections[1]
local hiddenRoute, hiddenPointIndex = editor:findBendPointAt(intersection.x, intersection.y, nil, nil)

assertTrue(hiddenRoute == nil and hiddenPointIndex == nil, "junction shared points should stay hidden from bend merge targeting")

print("map editor route segment split tests passed")
