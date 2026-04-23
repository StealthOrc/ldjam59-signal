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

local function assertTrue(value, label)
    if not value then
        error(label, 2)
    end
end

local editor = mapEditor.new(1280, 720, nil)
editor.gridSnapEnabled = true
editor.gridStep = 64

local startMapX = 170
local startMapY = 170
local endMapX = 300
local endMapY = 300

local startScreenX, startScreenY = editor:mapToScreen(startMapX, startMapY)
local endScreenX, endScreenY = editor:mapToScreen(endMapX, endMapY)

editor:mousepressed(startScreenX, startScreenY, 1)
assertTrue(editor.drag ~= nil and editor.drag.kind == "new_route", "clicking the canvas should begin a new route")

local route = editor:getSelectedRoute()
assertTrue(route ~= nil, "new route should be selected immediately")
assertEqual(route.points[1].x, 192, "new route start x should snap to the grid when snap mode is enabled")
assertEqual(route.points[1].y, 192, "new route start y should snap to the grid when snap mode is enabled")
assertEqual(route.points[2].x, 192, "new route provisional end x should start on the snapped start point")
assertEqual(route.points[2].y, 192, "new route provisional end y should start on the snapped start point")

editor:mousemoved(endScreenX, endScreenY, endScreenX - startScreenX, endScreenY - startScreenY)
editor:mousereleased(endScreenX, endScreenY, 1)

assertEqual(route.points[1].x, 192, "snapped route start x should remain snapped after release")
assertEqual(route.points[1].y, 192, "snapped route start y should remain snapped after release")
assertEqual(route.points[2].x, 320, "new route end x should also snap while dragging")
assertEqual(route.points[2].y, 320, "new route end y should also snap while dragging")

print("map editor new route snap tests passed")
