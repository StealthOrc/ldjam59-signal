package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}

local mapCompiler = require("src.game.map_compiler.map_compiler")

local editorData = {
    endpoints = {
        { id = "in_orange", kind = "input", x = 0.20, y = 0.10, colors = { "orange" } },
        { id = "out_orange", kind = "output", x = 0.20, y = 0.90, colors = { "orange" } },
    },
    routes = {
        {
            id = "route_5",
            label = "route_5",
            color = "orange",
            startEndpointId = "in_orange",
            endEndpointId = "out_orange",
            segmentRoadTypes = { "normal", "normal" },
            points = {
                { x = 0.20, y = 0.10 },
                { x = 0.50, y = 0.50 },
                { x = 0.20, y = 0.90 },
            },
        },
    },
    junctions = {
        {
            id = "junction_a",
            x = 0.424999,
            y = 0.399999,
            control = "direct",
            activeInputIndex = 1,
            activeOutputIndex = 1,
            routes = { "route_5" },
        },
        {
            id = "junction_b",
            x = 0.425001,
            y = 0.400001,
            control = "direct",
            activeInputIndex = 1,
            activeOutputIndex = 1,
            routes = { "route_5" },
        },
    },
    trains = {
        {
            id = "train_orange",
            lineColor = "orange",
            trainColor = "orange",
            spawnTime = 0,
            wagonCount = 4,
        },
    },
}

local level, errorText, errors, diagnostics = mapCompiler.buildPlayableLevel("Route Diagnostics", editorData, nil)

if level ~= nil then
    error("expected the authored map with near-overlapping junctions to fail validation", 2)
end

local expectedRouteError = "Orange route has two junctions so close together that no track remains between them. Move one junction farther away so a track segment can fit between the junctions."
if not string.find(tostring(errorText), expectedRouteError, 1, true) then
    error(string.format("unexpected first error text: %s", tostring(errorText)), 2)
end

if not errors or errors[1] ~= expectedRouteError then
    error("route validation should explain the overlapping-junction problem using the route color", 2)
end

if not diagnostics or diagnostics[1].kind ~= "route_zero_length_segment" then
    error("route validation should emit a structured zero-length diagnostic", 2)
end

if diagnostics[1].x == nil or diagnostics[1].y == nil then
    error("route zero-length diagnostic should expose a marker position", 2)
end

local expectedTrainError = "Train 1 cannot currently finish on color 'orange' because the orange route could not be built into a playable path."
local foundTrainError = false
for _, message in ipairs(errors or {}) do
    if message == expectedTrainError then
        foundTrainError = true
        break
    end
end

if not foundTrainError then
    error("expected a follow-up train error explaining that the blocked orange route prevents a playable output", 2)
end

local trainDiagnostic = nil
for _, diagnostic in ipairs(diagnostics or {}) do
    if diagnostic.kind == "train_unplayable_output" then
        trainDiagnostic = diagnostic
        break
    end
end

if not trainDiagnostic then
    error("expected a structured follow-up diagnostic for the blocked train output", 2)
end

if trainDiagnostic.parentDiagnosticIndex ~= 1 then
    error("train output diagnostics should point back to the blocking route issue", 2)
end

print("authored map route diagnostics tests passed")
