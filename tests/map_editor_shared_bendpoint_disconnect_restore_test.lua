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

local function assertNear(actual, expected, tolerance, label)
    if math.abs(actual - expected) > tolerance then
        error(string.format("%s expected %.4f but got %.4f", label, expected, actual), 2)
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
editor:loadEditorData(editorData, "Shared Bendpoint Disconnect Restore", nil, nil)

local routeBlue = editor:getRouteById("route_blue")
local routeYellow = editor:getRouteById("route_yellow")
local segmentHit = editor:findSegmentHit(640, 504)
assertTrue(segmentHit ~= nil, "expected to hit the shared exit lane segment")

local insertedMember = editor:insertBendPointAtSegmentHit(segmentHit)
assertTrue(insertedMember ~= nil, "shared lane should accept an inserted bend point before the disconnect test")

local linkedPointGroupId = routeBlue.points[3].linkedPointGroupId
assertTrue(linkedPointGroupId ~= nil, "inserted shared bend point should be linked across the shared lane")

local bendX = routeBlue.points[3].x + 70
local bendY = routeBlue.points[3].y - 30
editor:updateLinkedPointGroup(linkedPointGroupId, bendX, bendY)
editor:rebuildIntersections()

local routeMint = editor:createRoute(
    {
        { x = editor.mapSize.w * 0.22, y = bendY + 80 },
        { x = editor.mapSize.w * 0.78, y = bendY + 80 },
    },
    { 0.4, 0.92, 0.76 },
    "route_mint",
    "route_mint",
    "mint",
    { "mint" },
    { "mint" },
    nil,
    nil,
    { "normal" }
)
editor:rebuildIntersections()

assertTrue(routeMint ~= nil, "temporary crossing route should be created")

local middleIntersection = nil
for _, intersection in ipairs(editor.intersections or {}) do
    if intersection.y > routeBlue.points[2].y + 1 and intersection.y < routeBlue.points[4].y - 1 then
        middleIntersection = intersection
        break
    end
end

assertTrue(middleIntersection ~= nil, "temporary crossing route should create a removable middle junction on the shared lane")

local originX, originY = middleIntersection.x, middleIntersection.y
assertTrue(editor:splitSharedJunctionColor(middleIntersection, "mint", originX, originY), "temporary crossing route should be detachable from the middle junction")

local originScreenX, originScreenY = editor:mapToScreen(originX, originY)
editor:mousereleased(originScreenX, originScreenY, 1)
assertTrue(editor.drag ~= nil and editor.drag.kind == "point", "detached route should stay in hand after the pickup release")

local targetMapX = originX + 90
local targetMapY = originY - 60
local targetScreenX, targetScreenY = editor:mapToScreen(targetMapX, targetMapY)
editor:mousemoved(targetScreenX, targetScreenY, targetScreenX - originScreenX, targetScreenY - originScreenY)
editor:mousepressed(targetScreenX, targetScreenY, 1)
editor:mousereleased(targetScreenX, targetScreenY, 1)

assertEqual(#routeBlue.points, 4, "blue route should keep the shared multiline bend point after disconnecting the temporary junction")
assertEqual(#routeYellow.points, 4, "yellow route should keep the shared multiline bend point after disconnecting the temporary junction")
assertTrue(routeBlue.points[3].sharedPointId == nil, "restored multiline bend point should not stay a junction shared point")
assertTrue(routeBlue.points[3].linkedPointGroupId ~= nil, "restored multiline bend point should become linked again after disconnect")
assertEqual(routeBlue.points[3].linkedPointGroupId, routeYellow.points[3].linkedPointGroupId, "restored multiline bend point should relink both routes after disconnect")
assertNear(routeBlue.points[3].x, bendX, 0.001, "blue route should keep the edited multiline bend x position after disconnect")
assertNear(routeBlue.points[3].y, bendY, 0.001, "blue route should keep the edited multiline bend y position after disconnect")
assertNear(routeYellow.points[3].x, bendX, 0.001, "yellow route should keep the edited multiline bend x position after disconnect")
assertNear(routeYellow.points[3].y, bendY, 0.001, "yellow route should keep the edited multiline bend y position after disconnect")

print("map editor shared bendpoint disconnect restore tests passed")
