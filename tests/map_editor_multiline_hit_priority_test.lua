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
        { id = "input_blue", kind = "input", x = 0.20, y = 0.10, colors = { "blue" } },
        { id = "input_yellow", kind = "input", x = 0.80, y = 0.10, colors = { "yellow" } },
        { id = "output_shared", kind = "output", x = 0.50, y = 0.90, colors = { "blue", "yellow" } },
    },
    routes = {
        {
            id = "route_blue",
            label = "route_blue",
            color = "blue",
            startEndpointId = "input_blue",
            endEndpointId = "output_shared",
            segmentRoadTypes = { "normal", "normal" },
            points = {
                { x = 0.20, y = 0.10 },
                { x = 0.50, y = 0.35 },
                { x = 0.50, y = 0.90 },
            },
        },
        {
            id = "route_yellow",
            label = "route_yellow",
            color = "yellow",
            startEndpointId = "input_yellow",
            endEndpointId = "output_shared",
            segmentRoadTypes = { "normal", "normal" },
            points = {
                { x = 0.80, y = 0.10 },
                { x = 0.50, y = 0.35 },
                { x = 0.50, y = 0.90 },
            },
        },
    },
    junctions = {
        {
            id = "junction_merge_seed",
            x = 0.50,
            y = 0.35,
            control = "direct",
            activeInputIndex = 1,
            activeOutputIndex = 1,
            routes = { "route_blue", "route_yellow" },
        },
    },
    trains = {},
}

local editor = mapEditor.new(1280, 720, nil)
editor:loadEditorData(editorData, "Multiline Hit Priority Regression", nil, nil)

local routeBlue = editor:getRouteById("route_blue")
local routeYellow = editor:getRouteById("route_yellow")
assertTrue(routeBlue ~= nil and routeYellow ~= nil, "expected both routes to load")

editor.selectedRouteId = routeBlue.id
local hitRoute, hitPointIndex, magnetKind = editor:findPointHit(routeBlue.points[#routeBlue.points].x, routeBlue.points[#routeBlue.points].y)
assertEqual(hitRoute.id, routeBlue.id, "shared endpoint hit should prefer the currently selected route")
assertEqual(hitPointIndex, #routeBlue.points, "shared endpoint hit should return the selected route endpoint")
assertEqual(magnetKind, "end", "shared endpoint hit should stay an end magnet")

local segmentHit = editor:findSegmentHit(640, 504)
assertTrue(segmentHit ~= nil, "expected a segment hit on the shared lane")
assertEqual(segmentHit.route.id, routeBlue.id, "shared segment hit should prefer the currently selected route")

print("map editor multiline hit priority tests passed")

