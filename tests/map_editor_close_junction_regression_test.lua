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
        { id = "input_a", kind = "input", x = 636 / 1280, y = 400 / 720, colors = { "blue" } },
        { id = "output_a", kind = "output", x = 644 / 1280, y = 400 / 720, colors = { "blue" } },
        { id = "input_b", kind = "input", x = 636 / 1280, y = 360 / 720, colors = { "orange" } },
        { id = "output_b", kind = "output", x = 644 / 1280, y = 360 / 720, colors = { "orange" } },
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
                { x = 636 / 1280, y = 400 / 720 },
                { x = 640 / 1280, y = 360 / 720 },
                { x = 644 / 1280, y = 400 / 720 },
            },
        },
        {
            id = "route_b",
            label = "route_b",
            color = "orange",
            startEndpointId = "input_b",
            endEndpointId = "output_b",
            segmentRoadTypes = { "normal", "normal" },
            points = {
                { x = 636 / 1280, y = 360 / 720 },
                { x = 640 / 1280, y = 400 / 720 },
                { x = 644 / 1280, y = 360 / 720 },
            },
        },
    },
    junctions = {},
    trains = {},
}

local editor = mapEditor.new(1280, 720, nil)
editor:loadEditorData(editorData, "Close Junction Regression", nil, nil)

assertEqual(#(editor.intersections or {}), 2, "close double-crossing routes should produce two separate junctions")
assertTrue(
    editor.previewWorld and editor.previewWorld.junctionOrder and #(editor.previewWorld.junctionOrder or {}) == 2,
    "preview world should keep both close junctions renderable"
)

local first = editor.intersections[1]
local second = editor.intersections[2]
assertTrue(first and second and math.abs(first.x - second.x) >= 4, "junctions should remain visually distinct after rebuild")

print("map editor close junction regression tests passed")
