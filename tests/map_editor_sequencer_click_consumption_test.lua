package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}
love.timer = love.timer or {
    getTime = function()
        return 0
    end,
}
love.filesystem = love.filesystem or {}

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

local editor = mapEditor.new(1280, 720, nil)
editor.sidePanelMode = "sequencer"

local addRect = editor:getSequencerAddButtonRect()
local overlappingClickX = addRect.x + math.floor(addRect.w * 0.5)
local overlappingClickY = addRect.y + addRect.h - 2

local wasConsumed = editor:mousepressed(overlappingClickX, overlappingClickY, 1)

assertTrue(wasConsumed, "sequencer panel clicks should be consumed")
assertEqual(#editor.trains, 1, "clicking the overlapping add button area should add a train")
assertEqual(editor.gridVisible, true, "sequencer clicks must not toggle the underlying grid button")

local inertPanelClickX = editor.sidePanel.x + 24
local inertPanelClickY = editor.sidePanel.y + editor.sidePanel.h - 120

wasConsumed = editor:mousepressed(inertPanelClickX, inertPanelClickY, 1)

assertTrue(wasConsumed, "clicking unused sequencer panel space should still be consumed")
assertEqual(#editor.trains, 1, "clicking unused sequencer panel space should not trigger drawer actions")
assertEqual(editor.gridVisible, true, "clicking unused sequencer panel space should leave the grid toggle alone")

print("map editor sequencer click consumption tests passed")
