package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}
love.timer = love.timer or {
    getTime = function()
        return 0
    end,
}
love.filesystem = love.filesystem or {}

local mapEditor = require("src.game.editor.map_editor")

local function assertFalse(value, label)
    if value then
        error(label, 2)
    end
end

local editorData = {
    endpoints = {
        { id = "input_endpoint_3", kind = "input", x = 0.34103360116874, y = 0.058333333333333, colors = { "yellow", "violet" } },
        { id = "output_endpoint_4", kind = "output", x = 0.36363221329438, y = 0.90284879474069, colors = { "yellow", "violet" } },
        { id = "input_endpoint_5", kind = "input", x = 0.52141161431702, y = 0.058333333333333, colors = { "mint" } },
        { id = "output_endpoint_6", kind = "output", x = 0.49264974433893, y = 0.88897005113221, colors = { "mint" } },
        { id = "input_endpoint_7", kind = "input", x = 0.58838568298028, y = 0.058333333333333, colors = { "rose" } },
        { id = "output_endpoint_8", kind = "output", x = 0.56866325785245, y = 0.8809349890431, colors = { "rose" } },
        { id = "input_endpoint_9", kind = "input", x = 0.25680241051863, y = 0.058333333333333, colors = { "orange" } },
        { id = "output_endpoint_10", kind = "output", x = 0.30528670562454, y = 0.87289992695398, colors = { "orange" } },
    },
    routes = {
        {
            id = "route_3",
            label = "route_3",
            color = "mint",
            startEndpointId = "input_endpoint_5",
            endEndpointId = "output_endpoint_6",
            segmentRoadTypes = { "fast", "normal", "normal", "normal" },
            points = {
                { x = 0.52141161431702, y = 0.058333333333333 },
                { x = 0.3143261504748, y = 0.24762600438276 },
                { x = 0.56126734842951, y = 0.42731921110299 },
                { x = 0.30939554419284, y = 0.75383491599708 },
                { x = 0.49264974433893, y = 0.88897005113221 },
            },
        },
        {
            id = "route_4",
            label = "route_4",
            color = "rose",
            startEndpointId = "input_endpoint_7",
            endEndpointId = "output_endpoint_8",
            segmentRoadTypes = { "fast", "fast", "normal", "normal", "normal" },
            points = {
                { x = 0.58838568298028, y = 0.058333333333333 },
                { x = 0.54153407851226, y = 0.11629985327584 },
                { x = 0.31227173119065, y = 0.3308984660336 },
                { x = 0.56784149013879, y = 0.5317750182615 },
                { x = 0.31062819576333, y = 0.64645726807889 },
                { x = 0.56866325785245, y = 0.8809349890431 },
            },
        },
        {
            id = "route_5",
            label = "route_5",
            color = "orange",
            startEndpointId = "input_endpoint_9",
            endEndpointId = "output_endpoint_10",
            segmentRoadTypes = { "fast", "normal", "normal", "normal" },
            points = {
                { x = 0.25680241051863, y = 0.058333333333333 },
                { x = 0.56496530314098, y = 0.34112490869248 },
                { x = 0.32829620160701, y = 0.53104455807159 },
                { x = 0.56332176771366, y = 0.64353542731921 },
                { x = 0.30528670562454, y = 0.87289992695398 },
            },
        },
        {
            id = "route_6",
            label = "route_6",
            color = "violet",
            startEndpointId = "input_endpoint_3",
            endEndpointId = "output_endpoint_4",
            segmentRoadTypes = { "fast", "normal", "normal", "normal" },
            points = {
                { x = 0.34103360116874, y = 0.058333333333333 },
                { x = 0.56784149013879, y = 0.24397370343316 },
                { x = 0.31103907962016, y = 0.43097151205259 },
                { x = 0.56743060628196, y = 0.73557341124909 },
                { x = 0.36363221329438, y = 0.90284879474069 },
            },
        },
    },
    junctions = {},
    trains = {},
}

local editor = mapEditor.new(1280, 720, nil)
editor:loadEditorData(editorData, "Strict Intersection Regression", nil, nil)

local route4JunctionError = false
for _, errorText in ipairs(editor.validationErrors or {}) do
    if errorText:find("Route 'route_4' did not actually reach a detected junction.", 1, true) then
        route4JunctionError = true
        break
    end
end

assertFalse(route4JunctionError, "editor rebuild should avoid exporting an averaged junction that misses route_4")

local fourWayJunctionFound = false
local centralJunctionCount = 0

for _, intersection in ipairs(editor.intersections or {}) do
    if intersection.routeKey == "route_3|route_4|route_5|route_6" then
        fourWayJunctionFound = true
    end
    if intersection.y > 300 and intersection.y < 500 then
        centralJunctionCount = centralJunctionCount + 1
    end
end

assertFalse(fourWayJunctionFound, "editor should split the coarse central bucket instead of keeping a false 4-way junction")

if centralJunctionCount < 2 then
    error("editor should preserve multiple valid central junctions after splitting the coarse bucket", 2)
end

print("map editor strict intersection tests passed")
