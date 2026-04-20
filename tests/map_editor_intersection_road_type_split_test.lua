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

local MAP_WIDTH = 1280
local MAP_HEIGHT = 720
local LEFT_X = 0.18
local RIGHT_X = 0.82
local TOP_Y = 0.20
local BOTTOM_Y = 0.80
local CENTER_X = 0.50
local CENTER_Y = 0.50

local editorData = {
    endpoints = {
        { id = "input_fast", kind = "input", x = LEFT_X, y = TOP_Y, colors = { "blue" } },
        { id = "output_fast", kind = "output", x = RIGHT_X, y = BOTTOM_Y, colors = { "blue" } },
        { id = "input_slow", kind = "input", x = RIGHT_X, y = TOP_Y, colors = { "orange" } },
        { id = "output_slow", kind = "output", x = LEFT_X, y = BOTTOM_Y, colors = { "orange" } },
    },
    routes = {
        {
            id = "route_fast",
            label = "route_fast",
            color = "blue",
            startEndpointId = "input_fast",
            endEndpointId = "output_fast",
            segmentRoadTypes = { "fast" },
            points = {
                { x = LEFT_X, y = TOP_Y },
                { x = RIGHT_X, y = BOTTOM_Y },
            },
        },
        {
            id = "route_slow",
            label = "route_slow",
            color = "orange",
            startEndpointId = "input_slow",
            endEndpointId = "output_slow",
            segmentRoadTypes = { "slow" },
            points = {
                { x = RIGHT_X, y = TOP_Y },
                { x = LEFT_X, y = BOTTOM_Y },
            },
        },
    },
    junctions = {},
    trains = {},
}

local editor = mapEditor.new(MAP_WIDTH, MAP_HEIGHT, nil)
editor:loadEditorData(editorData, "Intersection Road Type Split", nil, nil)

assertEqual(#(editor.intersections or {}), 1, "crossing routes should still build one junction")

local fastRoute = editor:getRouteById("route_fast")
local slowRoute = editor:getRouteById("route_slow")

assertEqual(#(fastRoute.points or {}), 3, "fast route should gain a bend point at the junction")
assertEqual(#(slowRoute.points or {}), 3, "slow route should gain a bend point at the junction")
assertEqual(#(fastRoute.segmentRoadTypes or {}), 2, "fast route should split into two styled segments")
assertEqual(#(slowRoute.segmentRoadTypes or {}), 2, "slow route should split into two styled segments")
assertEqual(fastRoute.segmentRoadTypes[1], "fast", "fast route should keep the original style before the junction")
assertEqual(fastRoute.segmentRoadTypes[2], "fast", "fast route should copy the original style after the junction")
assertEqual(slowRoute.segmentRoadTypes[1], "slow", "slow route should keep the original style before the junction")
assertEqual(slowRoute.segmentRoadTypes[2], "slow", "slow route should copy the original style after the junction")

local fastBend = fastRoute.points[2]
local slowBend = slowRoute.points[2]

assertTrue(fastBend.sharedPointId ~= nil, "fast route junction bend point should be shared")
assertEqual(fastBend.sharedPointId, slowBend.sharedPointId, "both routes should share the same junction bend point id")
assertTrue(math.abs(fastBend.x / MAP_WIDTH - CENTER_X) < 0.0001, "fast route bend point should land on the junction x position")
assertTrue(math.abs(fastBend.y / MAP_HEIGHT - CENTER_Y) < 0.0001, "fast route bend point should land on the junction y position")

local exported = editor:getExportData()
local exportedFastRoute = nil
local exportedSlowRoute = nil

for _, route in ipairs(exported.routes or {}) do
    if route.id == "route_fast" then
        exportedFastRoute = route
    elseif route.id == "route_slow" then
        exportedSlowRoute = route
    end
end

assertTrue(exportedFastRoute ~= nil, "fast route should still export")
assertTrue(exportedSlowRoute ~= nil, "slow route should still export")
assertEqual(#(exportedFastRoute.points or {}), 3, "exported fast route should keep the junction bend point")
assertEqual(#(exportedSlowRoute.points or {}), 3, "exported slow route should keep the junction bend point")
assertEqual(exportedFastRoute.segmentRoadTypes[1], "fast", "exported fast route should keep the first split road type")
assertEqual(exportedFastRoute.segmentRoadTypes[2], "fast", "exported fast route should keep the second split road type")
assertEqual(exportedSlowRoute.segmentRoadTypes[1], "slow", "exported slow route should keep the first split road type")
assertEqual(exportedSlowRoute.segmentRoadTypes[2], "slow", "exported slow route should keep the second split road type")

print("map editor intersection road type split tests passed")
