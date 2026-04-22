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
        { id = "input_yellow", kind = "input", x = 0.80, y = 0.10, colors = { "yellow" } },
        { id = "output_shared", kind = "output", x = 0.50, y = 0.90, colors = { "blue", "yellow" } },
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
            routes = { "route_blue", "route_yellow" },
        },
    },
    trains = {},
}

local editor = mapEditor.new(1280, 720, nil)
editor:loadEditorData(editorData, "Shared Exit Lane Edit Regression", nil, nil)

assertEqual(#(editor.intersections or {}), 1, "shared exit lane setup should produce one junction")

local routeBlue = editor:getRouteById("route_blue")
local routeYellow = editor:getRouteById("route_yellow")
local segmentHit = editor:findSegmentHit(640, 504)

assertTrue(segmentHit ~= nil, "expected to hit the shared exit lane segment")
assertTrue(segmentHit.route ~= nil, "segment hit should resolve to a route")

local insertedMember = editor:insertBendPointAtSegmentHit(segmentHit)
assertTrue(insertedMember ~= nil, "shared exit lane should accept a new bend point")
assertEqual(#(editor.intersections or {}), 1, "inserting a shared-lane bend point should not create an extra junction")

assertEqual(#routeBlue.points, 4, "blue route should gain a bend point on the shared exit lane")
assertEqual(#routeYellow.points, 4, "yellow route should gain a bend point on the shared exit lane")
assertEqual(#routeBlue.segmentRoadTypes, 3, "blue route should keep one road type entry per segment after the split")
assertEqual(#routeYellow.segmentRoadTypes, 3, "yellow route should keep one road type entry per segment after the split")
assertTrue(routeBlue.points[3].sharedPointId == nil, "shared exit bend point should not become a junction shared point")
assertTrue(routeBlue.points[3].linkedPointGroupId ~= nil, "blue inserted bend point should join a linked multi-line group")
assertEqual(routeBlue.points[3].linkedPointGroupId, routeYellow.points[3].linkedPointGroupId, "both inserted bend points should stay linked as one shared lane control point")
assertEqual(routeBlue.points[3].x, routeYellow.points[3].x, "inserted shared bend points should keep the same x coordinate")
assertEqual(routeBlue.points[3].y, routeYellow.points[3].y, "inserted shared bend points should keep the same y coordinate")

local linkedPointGroupId = routeBlue.points[3].linkedPointGroupId
editor:updateLinkedPointGroup(linkedPointGroupId, routeBlue.points[3].x + 60, routeBlue.points[3].y - 40)

assertEqual(routeBlue.points[3].x, routeYellow.points[3].x, "moving a linked bend point should move both routes horizontally")
assertEqual(routeBlue.points[3].y, routeYellow.points[3].y, "moving a linked bend point should move both routes vertically")
assertEqual(#(editor.intersections or {}), 1, "moving a shared-lane bend point should not create an extra junction")

editor:setRouteSegmentRoadType(routeBlue, 3, "fast")
assertEqual(routeBlue.segmentRoadTypes[3], "fast", "blue shared exit segment should change road type")
assertEqual(routeYellow.segmentRoadTypes[3], "fast", "yellow shared exit segment should stay synchronized with the shared lane road type")

local previewJunction = editor.previewWorld and editor.previewWorld.junctions and editor.previewWorld.junctions[editor.intersections[1].id]
assertTrue(previewJunction ~= nil, "preview world should still expose the merged junction")
assertEqual(#(previewJunction.outputs or {}), 1, "shared exit lane should remain one logical output after inserting a bend point")

editor.selectedRouteId = routeBlue.id
editor.selectedPointIndex = 3
editor:deleteSelection()

assertEqual(#routeBlue.points, 3, "deleting a linked bend point should remove it from the blue route")
assertEqual(#routeYellow.points, 3, "deleting a linked bend point should remove it from the yellow route")
assertEqual(#routeBlue.segmentRoadTypes, 2, "blue route road type entries should collapse after removing the linked bend point")
assertEqual(#routeYellow.segmentRoadTypes, 2, "yellow route road type entries should collapse after removing the linked bend point")
assertEqual(#(editor.intersections or {}), 1, "removing a linked bend point should not disturb the real junction count")

print("map editor shared exit lane edit tests passed")



