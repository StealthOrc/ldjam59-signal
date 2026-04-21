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
        { id = "input_blue", kind = "input", x = 0.10, y = 0.20, colors = { "blue" } },
        { id = "output_blue", kind = "output", x = 0.90, y = 0.20, colors = { "blue" } },
        { id = "input_orange", kind = "input", x = 0.10, y = 0.60, colors = { "orange" } },
        { id = "output_orange", kind = "output", x = 0.90, y = 0.60, colors = { "orange" } },
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
                { x = 0.50, y = 0.80 },
                { x = 0.90, y = 0.20 },
            },
        },
        {
            id = "route_orange",
            label = "route_orange",
            color = "orange",
            startEndpointId = "input_orange",
            endEndpointId = "output_orange",
            segmentRoadTypes = { "normal", "normal" },
            points = {
                { x = 0.10, y = 0.60 },
                { x = 0.50, y = 0.00 },
                { x = 0.90, y = 0.60 },
            },
        },
    },
    junctions = {},
    trains = {},
}

local editor = mapEditor.new(1280, 720, nil)
editor:loadEditorData(editorData, "Repeated Route Pair Junctions", nil, nil)

assertEqual(#(editor.intersections or {}), 2, "two crossings on the same route pair should produce two editor junctions")
assertTrue(editor.intersections[1].id ~= editor.intersections[2].id, "repeated crossings should keep distinct junction ids")
assertTrue(
    editor.previewWorld and editor.previewWorld.junctionOrder and #(editor.previewWorld.junctionOrder or {}) == 2,
    "preview world should render both repeated-route junctions"
)

local exported = editor:getExportData()
assertEqual(#(exported.junctions or {}), 2, "export should keep both repeated-route junctions")
assertTrue(exported.junctions[1].id ~= exported.junctions[2].id, "exported repeated-route junction ids should stay unique")

local reloadedEditor = mapEditor.new(1280, 720, nil)
reloadedEditor:loadEditorData(exported, "Repeated Route Pair Reloaded", nil, nil)
assertEqual(#(reloadedEditor.intersections or {}), 2, "reloaded editor should keep both repeated-route junctions")
assertTrue(
    reloadedEditor.previewWorld and reloadedEditor.previewWorld.junctionOrder and #(reloadedEditor.previewWorld.junctionOrder or {}) == 2,
    "reloaded preview should keep both repeated-route junctions"
)

print("map editor repeated route pair junction tests passed")
