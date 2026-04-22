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
        { id = "input_blue", kind = "input", x = 0.2805, y = 0.1536, colors = { "blue" } },
        { id = "output_blue", kind = "output", x = 0.7523, y = 0.8943, colors = { "blue" } },
        { id = "input_yellow", kind = "input", x = 0.7817, y = 0.1953, colors = { "yellow" } },
        { id = "output_yellow", kind = "output", x = 0.2089, y = 0.8839, colors = { "yellow" } },
        { id = "input_mint", kind = "input", x = 0.4401, y = 0.1390, colors = { "mint" } },
        { id = "output_mint", kind = "output", x = 0.5903, y = 0.9214, colors = { "mint" } },
        { id = "input_rose", kind = "input", x = 0.6235, y = 0.1346, colors = { "rose" } },
        { id = "output_rose", kind = "output", x = 0.4038, y = 0.8995, colors = { "rose" } },
        { id = "input_orange", kind = "input", x = 0.7714, y = 0.7287, colors = { "orange" } },
        { id = "output_orange", kind = "output", x = 0.2710, y = 0.3217, colors = { "orange" } },
    },
    routes = {
        {
            id = "route_blue",
            label = "route_blue",
            color = "blue",
            startEndpointId = "input_blue",
            endEndpointId = "output_blue",
            segmentRoadTypes = { "normal" },
            points = {
                { x = 0.2805, y = 0.1536 },
                { x = 0.5129, y = 0.5184 },
                { x = 0.7523, y = 0.8943 },
            },
        },
        {
            id = "route_yellow",
            label = "route_yellow",
            color = "yellow",
            startEndpointId = "input_yellow",
            endEndpointId = "output_yellow",
            segmentRoadTypes = { "normal" },
            points = {
                { x = 0.7817, y = 0.1953 },
                { x = 0.5129, y = 0.5184 },
                { x = 0.2089, y = 0.8839 },
            },
        },
        {
            id = "route_mint",
            label = "route_mint",
            color = "mint",
            startEndpointId = "input_mint",
            endEndpointId = "output_mint",
            segmentRoadTypes = { "normal" },
            points = {
                { x = 0.4401, y = 0.1390 },
                { x = 0.5129, y = 0.5184 },
                { x = 0.5903, y = 0.9214 },
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
                { x = 0.6235, y = 0.1346 },
                { x = 0.5129, y = 0.5184 },
                { x = 0.4038, y = 0.8995 },
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
                { x = 0.7714, y = 0.7287 },
                { x = 0.5129, y = 0.5184 },
                { x = 0.2710, y = 0.3217 },
            },
        },
    },
    junctions = {},
    trains = {},
}

local editor = mapEditor.new(1280, 720, nil)
editor:loadEditorData(editorData, "Directional Junction Cycle Regression", nil, nil)

assertEqual(#(editor.intersections or {}), 1, "crossing routes should produce one intersection")
local intersection = editor.intersections[1]

editor:setIntersectionControlType(intersection, "crossbar")
assertEqual(intersection.activeInputIndex, 1, "crossbar starts on blue")
assertEqual(intersection.activeOutputIndex, 3, "crossbar blue should map to blue on the preview intersection")

assertTrue(editor:cycleIntersectionInput(intersection), "crossbar should cycle to the second lane")
assertEqual(intersection.activeInputIndex, 2, "crossbar second lane should be mint")
assertEqual(intersection.activeOutputIndex, 5, "crossbar mint should map to mint")

assertTrue(editor:cycleIntersectionInput(intersection), "crossbar should cycle to the third lane")
assertEqual(intersection.activeInputIndex, 3, "crossbar third lane should be rose")
assertEqual(intersection.activeOutputIndex, 4, "crossbar rose should map to rose")

assertTrue(editor:cycleIntersectionInput(intersection), "crossbar should cycle to yellow before orange")
assertEqual(intersection.activeInputIndex, 5, "crossbar fourth visual lane should be yellow")
assertEqual(intersection.activeOutputIndex, 2, "crossbar yellow should map to yellow")

assertTrue(editor:cycleIntersectionInput(intersection), "crossbar should cycle to orange last")
assertEqual(intersection.activeInputIndex, 4, "crossbar fifth visual lane should be orange")
assertEqual(intersection.activeOutputIndex, 1, "crossbar orange should map to orange")

editor:setIntersectionControlType(intersection, "relay")
intersection.activeInputIndex = 3
editor:syncIntersectionOutputToControl(intersection)
assertEqual(intersection.activeOutputIndex, 4, "relay rose should map to rose")

assertTrue(editor:cycleIntersectionInput(intersection), "relay should cycle from rose to yellow before orange")
assertEqual(intersection.activeInputIndex, 5, "relay fourth visual lane should be yellow")

assertTrue(editor:cycleIntersectionInput(intersection), "relay should cycle from yellow to orange last")
assertEqual(intersection.activeInputIndex, 4, "relay fifth visual lane should be orange")

print("map editor directional junction cycle tests passed")
