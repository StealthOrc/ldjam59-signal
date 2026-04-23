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

local function assertFalse(value, label)
    if value then
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
editor:loadEditorData(editorData, "Shared Endpoint Route Delete", nil, nil)

editor.selectedRouteId = "route_blue"
editor.selectedPointIndex = 1
editor:deleteSelection()

assertTrue(editor:getRouteById("route_blue") == nil, "deleting the selected route start should remove the full route")
assertTrue(editor:getRouteById("route_yellow") ~= nil, "deleting one route should keep the remaining shared-end route")
assertTrue(editor:getEndpointById("input_blue") == nil, "unused input endpoint should be removed with the deleted route")

local sharedOutput = editor:getEndpointById("output_shared")
assertTrue(sharedOutput ~= nil, "shared output endpoint should stay when another route still uses it")
assertTrue(sharedOutput.colors["yellow"] == true, "shared output endpoint should keep the remaining route color")
assertFalse(sharedOutput.colors["blue"] == true, "shared output endpoint should drop the deleted route color")
assertEqual(#(editor.intersections or {}), 0, "shared lane junction should collapse away when only one route remains")

print("map editor shared endpoint route delete tests passed")
