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
        error(string.format("%s expected %s but got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local editorData = {
    endpoints = {
        { id = "input_a", kind = "input", x = 0.10, y = 0.10, colors = { "blue" } },
        { id = "output_a", kind = "output", x = 0.40, y = 0.40, colors = { "blue" } },
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
                { x = 0.10, y = 0.10 },
                { x = 0.20, y = 0.20 },
                { x = 0.40, y = 0.40 },
            },
        },
    },
    junctions = {},
    trains = {},
}

local editor = mapEditor.new(1280, 720, nil)
editor:loadEditorData(editorData, "Snap Toggle", nil, nil)
editor.gridStep = 64

local route = editor:getRouteById("route_a")
local point = route.points[2]

editor.selectedRouteId = route.id
editor.selectedPointIndex = 2
editor.drag = {
    kind = "point",
    routeId = route.id,
    pointIndex = 2,
    startMouseX = point.x,
    startMouseY = point.y,
    moved = true,
    isMagnet = false,
    magnetKind = nil,
}

editor:updateDraggedPoint(170, 170)
assertEqual(route.points[2].x, 170, "dragging with snap off should keep the raw x position")
assertEqual(route.points[2].y, 170, "dragging with snap off should keep the raw y position")

editor:keypressed("q")
assertEqual(editor.gridSnapEnabled, true, "pressing q should enable snap-to-grid")

editor.drag = {
    kind = "point",
    routeId = route.id,
    pointIndex = 2,
    startMouseX = route.points[2].x,
    startMouseY = route.points[2].y,
    moved = true,
    isMagnet = false,
    magnetKind = nil,
}

editor:updateDraggedPoint(170, 170)
assertEqual(route.points[2].x, 192, "dragging with snap on should round x to the grid")
assertEqual(route.points[2].y, 192, "dragging with snap on should round y to the grid")

editor:keypressed("q")
assertEqual(editor.gridSnapEnabled, false, "pressing q again should disable snap-to-grid")

print("map editor snap toggle tests passed")
