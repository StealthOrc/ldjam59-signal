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
        { id = "input_mint", kind = "input", x = 0.15, y = 0.45, colors = { "mint" } },
        { id = "output_blue", kind = "output", x = 0.35, y = 0.90, colors = { "blue" } },
        { id = "output_yellow", kind = "output", x = 0.65, y = 0.90, colors = { "yellow" } },
        { id = "output_mint", kind = "output", x = 0.85, y = 0.45, colors = { "mint" } },
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
                { x = 0.20, y = 0.10 },
                { x = 0.50, y = 0.28 },
                { x = 0.50, y = 0.58 },
                { x = 0.35, y = 0.90 },
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
                { x = 0.80, y = 0.10 },
                { x = 0.50, y = 0.28 },
                { x = 0.50, y = 0.58 },
                { x = 0.65, y = 0.90 },
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
                { x = 0.15, y = 0.45 },
                { x = 0.85, y = 0.45 },
            },
        },
    },
    junctions = {
        {
            id = "junction_top_seed",
            x = 0.50,
            y = 0.28,
            control = "direct",
            activeInputIndex = 1,
            activeOutputIndex = 1,
            routes = { "route_blue", "route_yellow" },
        },
        {
            id = "junction_bottom_seed",
            x = 0.50,
            y = 0.58,
            control = "direct",
            activeInputIndex = 1,
            activeOutputIndex = 1,
            routes = { "route_blue", "route_yellow" },
        },
    },
    trains = {},
}

local editor = mapEditor.new(1280, 720, nil)
editor:loadEditorData(editorData, "Shared Lane Junction Restore", nil, nil)

assertEqual(#(editor.intersections or {}), 3, "crossing route should create a middle junction on the shared lane")

local routeBlue = editor:getRouteById("route_blue")
local routeYellow = editor:getRouteById("route_yellow")
assertEqual(#routeBlue.points, 5, "shared lane should materialize the middle junction point on the blue route")
assertEqual(#routeYellow.points, 5, "shared lane should materialize the middle junction point on the yellow route")
assertTrue(routeBlue.points[3].sharedPointId ~= nil, "middle shared-lane junction point should be a junction point before removal")

editor.selectedRouteId = "route_mint"
editor.selectedPointIndex = 1
editor:deleteSelection()

assertEqual(#(editor.intersections or {}), 2, "removing the crossing route should remove the extra middle junction")
assertTrue(routeBlue.points[3].sharedPointId == nil, "former middle junction should stop being a junction point after removal")
assertTrue(routeBlue.points[3].linkedPointGroupId ~= nil, "former middle junction should become a linked shared-lane point again")
assertEqual(routeBlue.points[3].linkedPointGroupId, routeYellow.points[3].linkedPointGroupId, "remaining shared-lane points should relink across both routes")

local linkedPointGroupId = routeBlue.points[3].linkedPointGroupId
editor:updateLinkedPointGroup(linkedPointGroupId, routeBlue.points[3].x + 40, routeBlue.points[3].y)

assertEqual(routeBlue.points[3].x, routeYellow.points[3].x, "restored shared lane should move both routes horizontally")
assertEqual(routeBlue.points[3].y, routeYellow.points[3].y, "restored shared lane should move both routes vertically")

print("map editor shared lane junction restore tests passed")
