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
editor:loadEditorData(editorData, "Junction State Regression", nil, nil)

assertEqual(#(editor.intersections or {}), 1, "crossing routes should produce one junction")
assertTrue(editor.previewWorld and editor.previewWorld.junctionOrder and editor.previewWorld.junctionOrder[1], "editor preview should build a playable junction")

local intersection = editor.intersections[1]
local previewJunction = editor.previewWorld.junctionOrder[1]

assertEqual(intersection.activeInputIndex, 1, "junction starts on the first input by default")
assertEqual(intersection.activeOutputIndex, 1, "junction starts on the first output by default")
assertEqual(previewJunction.activeInputIndex, 1, "preview world starts on the first input by default")
assertEqual(previewJunction.activeOutputIndex, 1, "preview world starts on the first output by default")

local centerScreenX, centerScreenY = editor:mapToScreen(intersection.x, intersection.y)
editor:mousepressed(centerScreenX, centerScreenY, 1)
editor:mousereleased(centerScreenX, centerScreenY, 1)

intersection = editor.intersections[1]
previewJunction = editor.previewWorld.junctionOrder[1]

assertEqual(intersection.activeInputIndex, 2, "left-clicking a junction cycles the saved starting input")
assertEqual(previewJunction.activeInputIndex, 2, "preview world reflects the cycled starting input")

local selectorScreenX, selectorScreenY = editor:mapToScreen(intersection.x, intersection.y + 36)
editor:mousepressed(selectorScreenX, selectorScreenY, 1)

intersection = editor.intersections[1]
previewJunction = editor.previewWorld.junctionOrder[1]

assertEqual(intersection.activeOutputIndex, 2, "clicking the output selector cycles the saved starting output")
assertEqual(previewJunction.activeOutputIndex, 2, "preview world reflects the cycled starting output")

local exported = editor:getExportData()
local reloadedEditor = mapEditor.new(1280, 720, nil)
reloadedEditor:loadEditorData(exported, "Junction State Reloaded", nil, nil)

assertEqual(reloadedEditor.intersections[1].activeInputIndex, 2, "reloaded editor keeps the saved starting input")
assertEqual(reloadedEditor.intersections[1].activeOutputIndex, 2, "reloaded editor keeps the saved starting output")

local movedIntersection = reloadedEditor.intersections[1]
local beforeX = movedIntersection.x
local beforeY = movedIntersection.y
local beforeInputIndex = movedIntersection.activeInputIndex
local dragStartScreenX, dragStartScreenY = reloadedEditor:mapToScreen(beforeX, beforeY)
local dragEndScreenX, dragEndScreenY = reloadedEditor:mapToScreen(beforeX + 16, beforeY + 8)

reloadedEditor:mousepressed(dragStartScreenX, dragStartScreenY, 1)
reloadedEditor:mousemoved(dragEndScreenX, dragEndScreenY, dragEndScreenX - dragStartScreenX, dragEndScreenY - dragStartScreenY)
reloadedEditor:mousereleased(dragEndScreenX, dragEndScreenY, 1)

local movedAfterDrag = reloadedEditor.intersections[1]
assertTrue(
    math.abs(movedAfterDrag.x - beforeX) > 10 or math.abs(movedAfterDrag.y - beforeY) > 10,
    "dragging a junction should still move it instead of cycling the saved state"
)
assertEqual(movedAfterDrag.activeInputIndex, beforeInputIndex, "dragging keeps the chosen starting input")

print("map editor junction state tests passed")
