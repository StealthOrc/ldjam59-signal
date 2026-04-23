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
        error(string.format("%s expected %q but got %q", label, expected, actual), 2)
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

local function interpolateY(a, b, x)
    local deltaX = b.x - a.x
    if math.abs(deltaX) <= 0.0001 then
        return a.y
    end

    local t = (x - a.x) / deltaX
    return a.y + (b.y - a.y) * t
end

local editorData = {
    endpoints = {
        { id = "input_blue", kind = "input", x = 0.10, y = 0.20, colors = { "blue" } },
        { id = "output_blue", kind = "output", x = 0.70, y = 0.80, colors = { "blue" } },
        { id = "input_orange", kind = "input", x = 0.25, y = 0.08, colors = { "orange" } },
        { id = "output_orange", kind = "output", x = 0.25, y = 0.92, colors = { "orange" } },
        { id = "input_rose", kind = "input", x = 0.45, y = 0.08, colors = { "rose" } },
        { id = "output_rose", kind = "output", x = 0.45, y = 0.92, colors = { "rose" } },
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
                { x = 0.70, y = 0.20 },
                { x = 0.70, y = 0.80 },
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
                { x = 0.25, y = 0.08 },
                { x = 0.25, y = 0.92 },
            },
        },
        {
            id = "route_rose",
            label = "route_rose",
            color = "rose",
            startEndpointId = "input_rose",
            endEndpointId = "output_rose",
            segmentRoadTypes = { "normal" },
            points = {
                { x = 0.45, y = 0.08 },
                { x = 0.45, y = 0.92 },
            },
        },
    },
    junctions = {},
    trains = {},
}

local editor = mapEditor.new(1280, 720, nil)
editor:loadEditorData(editorData, "Endpoint Ctrl Drag Rebuild", nil, nil)

local routeBlue = editor:getRouteById("route_blue")
local routeOrange = editor:getRouteById("route_orange")
local routeRose = editor:getRouteById("route_rose")

assertEqual(#(editor.intersections or {}), 2, "setup should create two junctions on the first blue segment")
assertEqual(#routeBlue.points, 5, "blue route should materialize both junctions before the authored bend")

local originalFirstJunctionX = routeBlue.points[2].x
local originalFirstJunctionY = routeBlue.points[2].y
local originalSecondJunctionX = routeBlue.points[3].x
local originalSecondJunctionY = routeBlue.points[3].y
local authoredBend = {
    x = routeBlue.points[4].x,
    y = routeBlue.points[4].y,
}

local draggedStart = {
    x = editor.mapSize.w * 0.10,
    y = editor.mapSize.h * 0.35,
}

local startScreenX, startScreenY = editor:mapToScreen(routeBlue.points[1].x, routeBlue.points[1].y)
local targetScreenX, targetScreenY = editor:mapToScreen(draggedStart.x, draggedStart.y)

ctrlHeld = true
editor:mousepressed(startScreenX, startScreenY, 1)
ctrlHeld = false
editor:mousemoved(targetScreenX, targetScreenY, targetScreenX - startScreenX, targetScreenY - startScreenY)
editor:mousereleased(targetScreenX, targetScreenY, 1)

assertEqual(#(editor.intersections or {}), 2, "ctrl-drag should keep both crossings after rebuilding the first segment")
assertEqual(#routeBlue.points, 5, "ctrl-drag should rebuild the blue route back to two junctions plus the authored bend")
assertEqual(#routeOrange.points, 3, "orange route should keep a single rebuilt junction point")
assertEqual(#routeRose.points, 3, "rose route should keep a single rebuilt junction point")

assertClose(routeBlue.points[1].x, draggedStart.x, 0.001, "ctrl-drag should move the blue start endpoint")
assertClose(routeBlue.points[1].y, draggedStart.y, 0.001, "ctrl-drag should move the blue start endpoint")
assertClose(routeBlue.points[4].x, authoredBend.x, 0.001, "ctrl-drag should preserve the first authored bend x")
assertClose(routeBlue.points[4].y, authoredBend.y, 0.001, "ctrl-drag should preserve the first authored bend y")

local expectedFirstJunctionY = interpolateY(draggedStart, authoredBend, editor.mapSize.w * 0.25)
local expectedSecondJunctionY = interpolateY(draggedStart, authoredBend, editor.mapSize.w * 0.45)
local tolerance = 1.5

assertTrue(math.abs(routeBlue.points[2].y - originalFirstJunctionY) > 8, "ctrl-drag should rebuild the first junction instead of keeping the old tail anchor")
assertTrue(math.abs(routeBlue.points[3].y - originalSecondJunctionY) > 8, "ctrl-drag should rebuild the second junction instead of keeping the old tail anchor")
assertClose(routeBlue.points[2].x, originalFirstJunctionX, tolerance, "rebuilt first junction should stay on the orange crossing x")
assertClose(routeBlue.points[2].y, expectedFirstJunctionY, tolerance, "rebuilt first junction should lie on the dragged start-to-bend segment")
assertClose(routeBlue.points[3].x, originalSecondJunctionX, tolerance, "rebuilt second junction should stay on the rose crossing x")
assertClose(routeBlue.points[3].y, expectedSecondJunctionY, tolerance, "rebuilt second junction should lie on the dragged start-to-bend segment")
assertClose(routeOrange.points[2].y, expectedFirstJunctionY, tolerance, "orange route should rebuild to the new first crossing")
assertClose(routeRose.points[2].y, expectedSecondJunctionY, tolerance, "rose route should rebuild to the new second crossing")

print("map editor endpoint ctrl drag rebuild tests passed")
