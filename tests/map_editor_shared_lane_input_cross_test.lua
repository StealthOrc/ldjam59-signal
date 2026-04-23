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
        { id = "input_blue", kind = "input", x = 0.20, y = 0.60, colors = { "blue" } },
        { id = "input_yellow", kind = "input", x = 0.82, y = 0.12, colors = { "yellow" } },
        { id = "output_blue", kind = "output", x = 0.28, y = 0.90, colors = { "blue" } },
        { id = "output_yellow", kind = "output", x = 0.72, y = 0.90, colors = { "yellow" } },
    },
    routes = {
        {
            id = "route_blue",
            label = "route_blue",
            color = "blue",
            startEndpointId = "input_blue",
            endEndpointId = "output_blue",
            segmentRoadTypes = { "normal", "normal", "normal" },
            points = {
                { x = 0.20, y = 0.60 },
                { x = 0.50, y = 0.30 },
                { x = 0.50, y = 0.70 },
                { x = 0.28, y = 0.90 },
            },
        },
        {
            id = "route_yellow",
            label = "route_yellow",
            color = "yellow",
            startEndpointId = "input_yellow",
            endEndpointId = "output_yellow",
            segmentRoadTypes = { "normal", "normal", "normal" },
            points = {
                { x = 0.82, y = 0.12 },
                { x = 0.50, y = 0.30 },
                { x = 0.50, y = 0.70 },
                { x = 0.72, y = 0.90 },
            },
        },
    },
    junctions = {
        {
            id = "junction_top_seed",
            x = 0.50,
            y = 0.30,
            control = "direct",
            activeInputIndex = 1,
            activeOutputIndex = 1,
            routes = { "route_blue", "route_yellow" },
        },
        {
            id = "junction_bottom_seed",
            x = 0.50,
            y = 0.70,
            control = "direct",
            activeInputIndex = 1,
            activeOutputIndex = 1,
            routes = { "route_blue", "route_yellow" },
        },
    },
    trains = {},
}

local editor = mapEditor.new(1280, 720, nil)
editor:loadEditorData(editorData, "Shared Lane Input Cross", nil, nil)

assertEqual(#(editor.intersections or {}), 2, "shared lane setup should start with only the top and bottom junctions")

local segmentHit = editor:findSegmentHit(640, 360)
assertTrue(segmentHit ~= nil, "expected to hit the shared lane between the two real junctions")

local insertedMember = editor:insertBendPointAtSegmentHit(segmentHit)
assertTrue(insertedMember ~= nil, "shared lane should accept a linked bend point before the cross test")

local routeBlue = editor:getRouteById("route_blue")
local linkedPointGroupId = routeBlue.points[3].linkedPointGroupId
assertTrue(linkedPointGroupId ~= nil, "inserted bend point should stay linked across the shared lane")

editor:updateLinkedPointGroup(linkedPointGroupId, editor.mapSize.w * 0.20, editor.mapSize.h * 0.35)
editor:rebuildIntersections()

assertEqual(#(editor.intersections or {}), 2, "crossing a member input branch should not create a new junction from the shared lane")

print("map editor shared lane input cross tests passed")
