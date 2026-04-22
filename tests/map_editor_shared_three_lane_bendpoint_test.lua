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
        { id = "input_blue", kind = "input", x = 0.20, y = 0.10, colors = { "blue" } },
        { id = "input_yellow", kind = "input", x = 0.50, y = 0.10, colors = { "yellow" } },
        { id = "input_orange", kind = "input", x = 0.80, y = 0.10, colors = { "orange" } },
        { id = "output_shared", kind = "output", x = 0.50, y = 0.90, colors = { "blue", "yellow", "orange" } },
    },
    routes = {
        {
            id = "route_blue",
            label = "route_blue",
            color = "blue",
            startEndpointId = "input_blue",
            endEndpointId = "output_shared",
            segmentRoadTypes = { "normal", "normal" },
            points = {
                { x = 0.20, y = 0.10 },
                { x = 0.50, y = 0.35 },
                { x = 0.50, y = 0.90 },
            },
        },
        {
            id = "route_yellow",
            label = "route_yellow",
            color = "yellow",
            startEndpointId = "input_yellow",
            endEndpointId = "output_shared",
            segmentRoadTypes = { "normal", "normal" },
            points = {
                { x = 0.50, y = 0.10 },
                { x = 0.50, y = 0.35 },
                { x = 0.50, y = 0.90 },
            },
        },
        {
            id = "route_orange",
            label = "route_orange",
            color = "orange",
            startEndpointId = "input_orange",
            endEndpointId = "output_shared",
            segmentRoadTypes = { "normal", "normal" },
            points = {
                { x = 0.80, y = 0.10 },
                { x = 0.50, y = 0.35 },
                { x = 0.50, y = 0.90 },
            },
        },
    },
    junctions = {
        {
            id = "junction_merge_seed",
            x = 0.50,
            y = 0.35,
            control = "direct",
            activeInputIndex = 1,
            activeOutputIndex = 1,
            routes = { "route_blue", "route_yellow", "route_orange" },
        },
    },
    trains = {},
}

local editor = mapEditor.new(1280, 720, nil)
editor:loadEditorData(editorData, "Shared Three Lane Bendpoint Regression", nil, nil)
assertEqual(#(editor.intersections or {}), 1, "three shared lanes should still start with one real junction")

local routeBlue = editor:getRouteById("route_blue")
local routeYellow = editor:getRouteById("route_yellow")
local routeOrange = editor:getRouteById("route_orange")
local segmentHit = editor:findSegmentHit(640, 504)
assertTrue(segmentHit ~= nil, "expected to hit the shared three-lane exit segment")

local insertedMember = editor:insertBendPointAtSegmentHit(segmentHit)
assertTrue(insertedMember ~= nil, "three-lane shared exit should accept a linked bend point")
assertEqual(#(editor.intersections or {}), 1, "linked three-lane bend point should not create extra junctions")
assertEqual(routeBlue.points[3].linkedPointGroupId, routeYellow.points[3].linkedPointGroupId, "blue and yellow bend points should share one linked group")
assertEqual(routeBlue.points[3].linkedPointGroupId, routeOrange.points[3].linkedPointGroupId, "all three bend points should share one linked group")

editor:setRouteSegmentRoadType(routeBlue, 3, "fast")
assertEqual(routeBlue.segmentRoadTypes[3], "fast", "blue shared segment should become fast")
assertEqual(routeYellow.segmentRoadTypes[3], "fast", "yellow shared segment should stay synced")
assertEqual(routeOrange.segmentRoadTypes[3], "fast", "orange shared segment should stay synced")

editor.selectedRouteId = routeYellow.id
editor.selectedPointIndex = 3
editor:deleteSelection()

assertEqual(#routeBlue.points, 3, "deleting the linked point should collapse the blue route")
assertEqual(#routeYellow.points, 3, "deleting the linked point should collapse the yellow route")
assertEqual(#routeOrange.points, 3, "deleting the linked point should collapse the orange route")
assertEqual(#routeBlue.segmentRoadTypes, 2, "blue route road types should collapse back to two segments")
assertEqual(#routeYellow.segmentRoadTypes, 2, "yellow route road types should collapse back to two segments")
assertEqual(#routeOrange.segmentRoadTypes, 2, "orange route road types should collapse back to two segments")
assertEqual(#(editor.intersections or {}), 1, "removing the linked three-lane bend point should keep only the real junction")

local previewJunction = editor.previewWorld and editor.previewWorld.junctions and editor.previewWorld.junctions[editor.intersections[1].id]
assertTrue(previewJunction ~= nil, "preview world should still expose the real junction after three-lane collapse")
assertEqual(#(previewJunction.outputs or {}), 1, "three-lane shared exit should collapse back to one logical output")

print("map editor shared three lane bendpoint tests passed")

