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

local dragOffsetX = 60
local dragOffsetY = -40

local editor = mapEditor.new(1280, 720, nil)
editor:loadEditorData(editorData, "Shared Bendpoint Mouse Release", nil, nil)

local routeBlue = editor:getRouteById("route_blue")
local routeYellow = editor:getRouteById("route_yellow")
local segmentHit = editor:findSegmentHit(640, 504)
assertTrue(segmentHit ~= nil, "expected to hit the shared exit lane segment")

local startScreenX, startScreenY = editor:mapToScreen(segmentHit.point.x, segmentHit.point.y)
local targetScreenX, targetScreenY = editor:mapToScreen(segmentHit.point.x + dragOffsetX, segmentHit.point.y + dragOffsetY)

assertTrue(editor:mousepressed(startScreenX, startScreenY, 1), "mouse press should add a bend point on the shared lane")
editor:mousemoved(targetScreenX, targetScreenY, targetScreenX - startScreenX, targetScreenY - startScreenY)
assertTrue(editor:mousereleased(targetScreenX, targetScreenY, 1), "mouse release should finish dragging the shared bend point")

assertEqual(#routeBlue.points, 4, "blue route should keep one inserted bend point after the real mouse drag path")
assertEqual(#routeYellow.points, 4, "yellow route should keep one inserted bend point after the real mouse drag path")
assertTrue(routeBlue.points[3].sharedPointId == nil, "shared bend point should not turn into a junction on mouse release")
assertTrue(routeBlue.points[3].linkedPointGroupId ~= nil, "shared bend point should stay linked on mouse release")
assertEqual(routeBlue.points[3].linkedPointGroupId, routeYellow.points[3].linkedPointGroupId, "both shared bend points should stay in one linked group after mouse release")

editor:deleteSelection()

assertEqual(#routeBlue.points, 3, "deleting the shared bend point after a real mouse drag should collapse the blue route")
assertEqual(#routeYellow.points, 3, "deleting the shared bend point after a real mouse drag should collapse the yellow route")

local restoredSharedLane = editor:getSharedLaneForSegment(routeBlue, 2)
assertTrue(restoredSharedLane ~= nil, "deleting the dragged shared bend point should restore the shared lane")
assertEqual(#(restoredSharedLane.members or {}), 2, "deleting the dragged shared bend point should restore one shared lane with both routes")

local previewJunction = editor.previewWorld and editor.previewWorld.junctions and editor.previewWorld.junctions[editor.intersections[1].id]
assertTrue(previewJunction ~= nil, "preview world should still expose the merged junction after deleting the dragged shared bend point")
assertEqual(#(previewJunction.outputs or {}), 1, "deleting the dragged shared bend point should restore one compiled shared output")

print("map editor shared bendpoint mouse release tests passed")
