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

local editor = mapEditor.new(1280, 720, nil)
local route = editor:createRoute(
    {
        { x = 100, y = 100 },
        { x = 200, y = 200, sharedPointId = 1 },
        { x = 240, y = 240, sharedPointId = 1 },
        { x = 400, y = 300 },
    },
    { 0.33, 0.8, 0.98 },
    "route_test",
    "route_test",
    "blue",
    { "blue" },
    { "blue" },
    "start_endpoint",
    "end_endpoint",
    { "normal", "normal", "normal" }
)

assertEqual(#route.points, 4, "setup should start with two consecutive shared points")
assertEqual(#route.segmentRoadTypes, 3, "setup should keep one road type per segment")

editor:updateSharedPointGroup(1, 220, 220)

assertEqual(#route.points, 3, "shared point collapse should remove duplicate consecutive points")
assertEqual(#route.segmentRoadTypes, 2, "shared point collapse should remove the redundant segment road type")
assertTrue(
    not (
        math.abs(route.points[2].x - route.points[1].x) <= 1
        and math.abs(route.points[2].y - route.points[1].y) <= 1
    ),
    "collapsed route should not leave a zero-length segment behind"
)

print("map editor shared point collapse tests passed")
