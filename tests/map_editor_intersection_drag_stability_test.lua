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
        { id = "input_left", kind = "input", x = 0.18, y = 0.2, colors = { "blue" } },
        { id = "output_right", kind = "output", x = 0.82, y = 0.8, colors = { "blue" } },
        { id = "input_right", kind = "input", x = 0.82, y = 0.2, colors = { "orange" } },
        { id = "output_left", kind = "output", x = 0.18, y = 0.8, colors = { "orange" } },
        { id = "input_top", kind = "input", x = 0.5, y = 0.64, colors = { "yellow" } },
        { id = "output_bottom", kind = "output", x = 0.5, y = 0.92, colors = { "yellow" } },
    },
    routes = {
        {
            id = "route_blue",
            label = "route_blue",
            color = "blue",
            startEndpointId = "input_left",
            endEndpointId = "output_right",
            segmentRoadTypes = { "normal" },
            points = {
                { x = 0.18, y = 0.2 },
                { x = 0.82, y = 0.8 },
            },
        },
        {
            id = "route_orange",
            label = "route_orange",
            color = "orange",
            startEndpointId = "input_right",
            endEndpointId = "output_left",
            segmentRoadTypes = { "normal" },
            points = {
                { x = 0.82, y = 0.2 },
                { x = 0.18, y = 0.8 },
            },
        },
        {
            id = "route_yellow",
            label = "route_yellow",
            color = "yellow",
            startEndpointId = "input_top",
            endEndpointId = "output_bottom",
            segmentRoadTypes = { "normal" },
            points = {
                { x = 0.5, y = 0.64 },
                { x = 0.5, y = 0.92 },
            },
        },
    },
    junctions = {},
    trains = {},
}

local editor = mapEditor.new(1280, 720, nil)
editor:loadEditorData(editorData, "Intersection Drag Stability", nil, nil)

assertEqual(#(editor.intersections or {}), 1, "initial crossing should produce one junction")

local intersection = editor.intersections[1]
local startScreenX, startScreenY = editor:mapToScreen(intersection.x, intersection.y)

editor:mousepressed(startScreenX, startScreenY, 1)

local dragTargets = {
    { x = editor.mapSize.w * 0.5, y = editor.mapSize.h * 0.70 },
    { x = editor.mapSize.w * 0.5, y = editor.mapSize.h * 0.76 },
    { x = editor.mapSize.w * 0.5, y = editor.mapSize.h * 0.82 },
}

local previousScreenX = startScreenX
local previousScreenY = startScreenY

for _, target in ipairs(dragTargets) do
    local screenX, screenY = editor:mapToScreen(target.x, target.y)
    editor:mousemoved(screenX, screenY, screenX - previousScreenX, screenY - previousScreenY)
    previousScreenX = screenX
    previousScreenY = screenY

    assertEqual(#(editor.intersections or {}), 1, "live intersection drag should keep one resolved junction")
    assertTrue(#editor:getRouteById("route_blue").points <= 3, "blue route should stay bounded during live drag")
    assertTrue(#editor:getRouteById("route_orange").points <= 3, "orange route should stay bounded during live drag")
    assertEqual(#editor:getRouteById("route_yellow").points, 2, "crossed route should not gain bend points during live junction drag")
end

editor:mousereleased(previousScreenX, previousScreenY, 1)

assertEqual(#(editor.intersections or {}), 1, "dragging a junction onto another road should converge to one shared junction")
assertTrue(#editor:getRouteById("route_blue").points <= 3, "blue route should not accumulate runaway junction points")
assertTrue(#editor:getRouteById("route_orange").points <= 3, "orange route should not accumulate runaway junction points")
assertTrue(#editor:getRouteById("route_yellow").points <= 3, "yellow route may materialize one final junction point after release")

local movedIntersection = editor.intersections[1]
local finalTarget = dragTargets[#dragTargets]
assertTrue(math.abs(movedIntersection.x - finalTarget.x) < 8, "junction should stay near the dragged x target")
assertTrue(math.abs(movedIntersection.y - finalTarget.y) < 8, "junction should stay near the dragged y target")

print("map editor intersection drag stability tests passed")
