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
editor:loadEditorData(editorData, "Junction Disconnect Drag Regression", nil, nil)

local intersection = editor.intersections[1]
assertTrue(intersection ~= nil, "crossing routes should produce one junction")

local centerScreenX, centerScreenY = editor:mapToScreen(intersection.x, intersection.y)
editor:mousepressed(centerScreenX, centerScreenY, 2)
assertTrue(editor.colorPicker ~= nil and editor.colorPicker.mode == "junction", "right-clicking a junction should open the radial menu")

local rootScale = editor:getJunctionPickerPopupScale()
local disconnectRootClickX = centerScreenX - 12 * rootScale
local disconnectRootClickY = centerScreenY
assertTrue(editor:handleColorPickerClick(disconnectRootClickX, disconnectRootClickY, 1), "left-side root click should open the disconnect branch")
assertTrue(editor.colorPicker.branch == "disconnect", "left-side root click should select the disconnect branch")

editor:update(0.08)

local layout = editor:getJunctionPickerLayout()
local blueEntry = nil
for _, entry in ipairs(layout.submenu.entries or {}) do
    if entry.option.id == "blue" then
        blueEntry = entry
        break
    end
end

assertTrue(blueEntry ~= nil, "disconnect branch should list the blue route color")

local originX, originY = editor:getJunctionPickerPopupOrigin()
local submenuScale = editor:getJunctionPickerPopupScale()
local submenuClickX = originX + (blueEntry.centerX - originX) * submenuScale
local submenuClickY = originY + (blueEntry.centerY - originY) * submenuScale

assertTrue(editor:handleColorPickerClick(submenuClickX, submenuClickY, 1), "disconnect submenu click should be handled")
assertTrue(editor.drag ~= nil and editor.drag.kind == "point", "disconnecting a route from a junction should immediately start a bend-point drag")
editor:mousereleased(submenuClickX, submenuClickY, 1)
assertTrue(editor.drag ~= nil and editor.drag.kind == "point", "the initial release after disconnecting should keep the bend point in hand")

local targetMapX = intersection.x - 32
local targetMapY = intersection.y - 18
local targetScreenX, targetScreenY = editor:mapToScreen(targetMapX, targetMapY)
editor:mousemoved(targetScreenX, targetScreenY, targetScreenX - submenuClickX, targetScreenY - submenuClickY)
editor:mousepressed(targetScreenX, targetScreenY, 1)
editor:mousereleased(targetScreenX, targetScreenY, 1)

local blueRoute = editor:getRouteById("route_blue")
local orangeRoute = editor:getRouteById("route_orange")
local bluePoint = blueRoute.points[2]
local orangePoint = orangeRoute.points[2]
local tolerance = 0.001
local intersectionTolerance = 1.5

assertClose(bluePoint.x, targetMapX, tolerance, "disconnect drag should move the detached blue bend point")
assertClose(bluePoint.y, targetMapY, tolerance, "disconnect drag should move the detached blue bend point")
assertClose(orangePoint.x, intersection.x, intersectionTolerance, "disconnect drag should leave the other route on the original junction")
assertClose(orangePoint.y, intersection.y, intersectionTolerance, "disconnect drag should leave the other route on the original junction")

print("map editor junction disconnect drag tests passed")
