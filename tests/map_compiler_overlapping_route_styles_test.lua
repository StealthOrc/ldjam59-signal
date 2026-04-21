package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}

local mapCompiler = require("src.game.map_compiler.map_compiler")

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
        { id = "input_orange", kind = "input", x = 0.10, y = 0.80, colors = { "orange" } },
        { id = "output_blue", kind = "output", x = 0.90, y = 0.20, colors = { "blue" } },
        { id = "output_orange", kind = "output", x = 0.90, y = 0.80, colors = { "orange" } },
    },
    routes = {
        {
            id = "route_blue",
            label = "route_blue",
            color = "blue",
            startEndpointId = "input_blue",
            endEndpointId = "output_blue",
            segmentRoadTypes = { "normal", "slow", "normal" },
            points = {
                { x = 0.10, y = 0.20 },
                { x = 0.35, y = 0.35 },
                { x = 0.65, y = 0.50 },
                { x = 0.90, y = 0.20 },
            },
        },
        {
            id = "route_orange",
            label = "route_orange",
            color = "orange",
            startEndpointId = "input_orange",
            endEndpointId = "output_orange",
            segmentRoadTypes = { "normal", "fast", "normal" },
            points = {
                { x = 0.10, y = 0.80 },
                { x = 0.35, y = 0.35 },
                { x = 0.65, y = 0.50 },
                { x = 0.90, y = 0.80 },
            },
        },
    },
    junctions = {
        {
            id = "junction_left",
            x = 0.35,
            y = 0.35,
            control = "direct",
            activeInputIndex = 1,
            activeOutputIndex = 1,
            routes = { "route_blue", "route_orange" },
        },
        {
            id = "junction_right",
            x = 0.65,
            y = 0.50,
            control = "direct",
            activeInputIndex = 1,
            activeOutputIndex = 1,
            routes = { "route_blue", "route_orange" },
        },
    },
    trains = {
        {
            id = "train_blue",
            lineColor = "blue",
            trainColor = "blue",
            spawnTime = 0,
            wagonCount = 4,
        },
        {
            id = "train_orange",
            lineColor = "orange",
            trainColor = "orange",
            spawnTime = 0,
            wagonCount = 4,
        },
    },
}

local level, errorText, errors, diagnostics = mapCompiler.buildPlayableLevel("Overlapping Route Styles", editorData, nil)

if errorText ~= nil then
    error(string.format("expected overlapping routes with different styles to compile, got %s", tostring(errorText)), 2)
end

assertEqual(#(errors or {}), 0, "overlapping routes with different styles should not emit validation errors")
assertEqual(#(diagnostics or {}), 0, "overlapping routes with different styles should not emit diagnostics")
assertTrue(level ~= nil, "expected a playable level to be built")
assertEqual(#(level.edges or {}), 6, "each authored segment should stay distinct in the playable level")
assertEqual(#(level.junctions or {}), 2, "expected both shared junctions to remain playable")

local junctionById = {}
for _, junction in ipairs(level.junctions or {}) do
    junctionById[junction.id] = junction
end

assertEqual(#(junctionById.junction_left.inputEdgeIds or {}), 2, "left junction should keep two input lanes")
assertEqual(#(junctionById.junction_left.outputEdgeIds or {}), 2, "left junction should keep two overlapping output lanes")
assertEqual(#(junctionById.junction_right.inputEdgeIds or {}), 2, "right junction should keep two overlapping input lanes")
assertEqual(#(junctionById.junction_right.outputEdgeIds or {}), 2, "right junction should keep two output lanes")

local middleSegments = {}
for _, edge in ipairs(level.edges or {}) do
    if edge.sourceId == "junction_left" and edge.targetId == "junction_right" then
        middleSegments[#middleSegments + 1] = edge
    end
end

assertEqual(#middleSegments, 2, "shared middle section should remain as two lanes")
assertTrue(middleSegments[1].roadType ~= middleSegments[2].roadType, "shared middle lanes should preserve their distinct road types")

print("authored map overlapping route styles tests passed")
