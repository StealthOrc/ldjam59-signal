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
        { id = "input_a", kind = "input", x = 0.12, y = 0.65, colors = { "blue" } },
        { id = "output_a", kind = "output", x = 0.85, y = 0.22, colors = { "blue" } },
        { id = "input_b", kind = "input", x = 0.56, y = 0.14, colors = { "orange" } },
        { id = "output_b", kind = "output", x = 0.56, y = 0.86, colors = { "orange" } },
    },
    routes = {
        {
            id = "route_drag",
            label = "route_drag",
            color = "blue",
            startEndpointId = "input_a",
            endEndpointId = "output_a",
            segmentRoadTypes = { "normal", "normal" },
            points = {
                { x = 0.12, y = 0.65 },
                { x = 0.24, y = 0.82 },
                { x = 0.85, y = 0.22 },
            },
        },
        {
            id = "route_static",
            label = "route_static",
            color = "orange",
            startEndpointId = "input_b",
            endEndpointId = "output_b",
            segmentRoadTypes = { "normal" },
            points = {
                { x = 0.56, y = 0.14 },
                { x = 0.56, y = 0.86 },
            },
        },
    },
    junctions = {},
    trains = {},
}

local editor = mapEditor.new(1280, 720, nil)
editor:loadEditorData(editorData, "Bendpoint Live Intersection", nil, nil)

assertEqual(#(editor.intersections or {}), 0, "initial layout should not start with a junction")

local routeDrag = editor:getRouteById("route_drag")
local routeStatic = editor:getRouteById("route_static")
local bendPoint = routeDrag.points[2]
local startScreenX, startScreenY = editor:mapToScreen(bendPoint.x, bendPoint.y)

editor:mousepressed(startScreenX, startScreenY, 1)

local dragTargets = {
    { x = editor.mapSize.w * 0.48, y = editor.mapSize.h * 0.60 },
    { x = editor.mapSize.w * 0.54, y = editor.mapSize.h * 0.56 },
    { x = editor.mapSize.w * 0.60, y = editor.mapSize.h * 0.52 },
}

local previousScreenX = startScreenX
local previousScreenY = startScreenY

for _, target in ipairs(dragTargets) do
    local screenX, screenY = editor:mapToScreen(target.x, target.y)
    editor:mousemoved(screenX, screenY, screenX - previousScreenX, screenY - previousScreenY)
    previousScreenX = screenX
    previousScreenY = screenY

    assertTrue(#(editor.intersections or {}) <= 1, "live bend drag should keep the crossing count bounded")
    assertEqual(#routeStatic.points, 2, "crossed route should not gain new bend points during live drag")
end

editor:mousereleased(previousScreenX, previousScreenY, 1)

assertTrue(#(editor.intersections or {}) <= 1, "release should leave at most one resolved crossing")
assertTrue(#routeStatic.points <= 3, "crossed route may materialize one final junction point after release")

print("map editor bendpoint live intersection tests passed")
