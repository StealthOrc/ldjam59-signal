package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}
love.timer = love.timer or {
    getTime = function()
        return 0
    end,
}
love.filesystem = love.filesystem or {}

local ctrlHeld = false

love.keyboard = love.keyboard or {}
love.keyboard.isDown = function(...)
    if not ctrlHeld then
        return false
    end

    for index = 1, select("#", ...) do
        local key = select(index, ...)
        if key == "lctrl" or key == "rctrl" then
            return true
        end
    end

    return false
end

love.mouse = love.mouse or {
    isDown = function()
        return false
    end,
}

local mapEditor = require("src.game.editor.map_editor")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %s but got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local function assertTrue(value, label)
    if not value then
        error(label, 2)
    end
end

local function assertClose(actual, expected, tolerance, label)
    if math.abs(actual - expected) > tolerance then
        error(string.format("%s expected %.4f but got %.4f", label, expected, actual), 2)
    end
end

local editorData = {
    endpoints = {
        { id = "input_blue", kind = "input", x = 0.10, y = 0.20, colors = { "blue" } },
        { id = "output_blue", kind = "output", x = 0.30, y = 0.60, colors = { "blue" } },
        { id = "input_orange", kind = "input", x = 0.30, y = 0.05, colors = { "orange" } },
        { id = "output_orange", kind = "output", x = 0.30, y = 0.95, colors = { "orange" } },
    },
    routes = {
        {
            id = "route_blue",
            label = "route_blue",
            color = "blue",
            startEndpointId = "input_blue",
            endEndpointId = "output_blue",
            segmentRoadTypes = { "normal", "normal" },
            points = {
                { x = 0.10, y = 0.20 },
                { x = 0.30, y = 0.20 },
                { x = 0.30, y = 0.60 },
            },
        },
        {
            id = "route_orange",
            label = "route_orange",
            color = "orange",
            startEndpointId = "input_orange",
            endEndpointId = "output_orange",
            segmentRoadTypes = { "normal" },
            points = {
                { x = 0.30, y = 0.05 },
                { x = 0.30, y = 0.95 },
            },
        },
    },
    junctions = {},
    trains = {},
}

local editor = mapEditor.new(1280, 720, nil)
editor:loadEditorData(editorData, "Endpoint Ctrl Drag Shared Bend", nil, nil)

local routeBlue = editor:getRouteById("route_blue")
assertEqual(#(editor.intersections or {}), 1, "setup should create one junction at the authored bend")
assertEqual(#routeBlue.points, 3, "the authored bend should remain a single shared bend point")
assertTrue(routeBlue.points[2].sharedPointId ~= nil, "the authored bend should be part of the shared junction group")
assertTrue(routeBlue.points[2].authored ~= false, "the authored bend should stay marked as authored")

local startScreenX, startScreenY = editor:mapToScreen(routeBlue.points[1].x, routeBlue.points[1].y)
local newStartX = editor.mapSize.w * 0.12
local newStartY = editor.mapSize.h * 0.32
local targetScreenX, targetScreenY = editor:mapToScreen(newStartX, newStartY)

ctrlHeld = true
editor:mousepressed(startScreenX, startScreenY, 1)
ctrlHeld = false
editor:mousemoved(targetScreenX, targetScreenY, targetScreenX - startScreenX, targetScreenY - startScreenY)
editor:mousereleased(targetScreenX, targetScreenY, 1)

assertEqual(#routeBlue.points, 3, "ctrl-drag should preserve the shared authored bend instead of pruning past it")
assertClose(routeBlue.points[1].x, newStartX, 0.001, "ctrl-drag should still move the route start")
assertClose(routeBlue.points[1].y, newStartY, 0.001, "ctrl-drag should still move the route start")
assertClose(routeBlue.points[2].x, editor.mapSize.w * 0.30, 0.001, "the authored bend x should remain anchored")
assertClose(routeBlue.points[2].y, editor.mapSize.h * 0.20, 0.001, "the authored bend y should remain anchored")
assertTrue(routeBlue.points[2].sharedPointId ~= nil, "the shared authored bend should still belong to the junction")
assertTrue(routeBlue.points[2].authored ~= false, "ctrl-drag should preserve the authored bend metadata")

print("map editor endpoint ctrl drag preserves shared bend tests passed")
