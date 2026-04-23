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

local visualInsetMargin = 1

local editorData = {
    endpoints = {
        { id = "input_blue", kind = "input", x = 0.20, y = 0.20, colors = { "blue" } },
        { id = "output_blue", kind = "output", x = 0.82, y = 0.72, colors = { "blue" } },
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
                { x = 0.20, y = 0.20 },
                { x = 0.50, y = 0.20 },
                { x = 0.82, y = 0.72 },
            },
        },
    },
    junctions = {},
    trains = {},
}

local editor = mapEditor.new(1280, 720, nil)
editor:loadEditorData(editorData, "Handle Hit Priority", nil, nil)

local routeBlue = editor:getRouteById("route_blue")
assertTrue(routeBlue ~= nil, "route should exist")

local startPoint = routeBlue.points[1]
local startRadius = editor:getMagnetHitRadius("start")
local startScreenX, startScreenY = editor:mapToScreen(startPoint.x + startRadius - visualInsetMargin, startPoint.y)

assertTrue(editor:mousepressed(startScreenX, startScreenY, 1), "clicking inside the visible start handle should be handled")
assertEqual(#routeBlue.points, 3, "clicking inside the visible start handle should not insert a new bend point")
assertEqual(editor.selectedPointIndex, 1, "clicking inside the visible start handle should select the start point")
assertTrue(editor:mousereleased(startScreenX, startScreenY, 1), "releasing the start handle click should finish cleanly")

local bendPoint = routeBlue.points[2]
local bendRadius = editor:getPointHitRadius()
local bendScreenX, bendScreenY = editor:mapToScreen(bendPoint.x + bendRadius - visualInsetMargin, bendPoint.y)

assertTrue(editor:mousepressed(bendScreenX, bendScreenY, 1), "clicking inside the visible bend handle should be handled")
assertEqual(#routeBlue.points, 3, "clicking inside the visible bend handle should not insert another bend point")
assertEqual(editor.selectedPointIndex, 2, "clicking inside the visible bend handle should select the bend point")
assertTrue(editor:mousereleased(bendScreenX, bendScreenY, 1), "releasing the bend handle click should finish cleanly")

print("map editor handle hit priority tests passed")
