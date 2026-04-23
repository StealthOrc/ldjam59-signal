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
        { id = "output_blue", kind = "output", x = 0.35, y = 0.90, colors = { "blue" } },
        { id = "output_yellow", kind = "output", x = 0.65, y = 0.90, colors = { "yellow" } },
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
editor:loadEditorData(editorData, "Shared Lane Endpoint Collapse", nil, nil)

local routeBlue = editor:getRouteById("route_blue")
local routeYellow = editor:getRouteById("route_yellow")
local segmentHit = editor:findSegmentHit(640, 504)
assertTrue(segmentHit ~= nil, "expected to hit the shared exit lane segment")

local insertedMember = editor:insertBendPointAtSegmentHit(segmentHit)
assertTrue(insertedMember ~= nil, "shared exit lane should accept a linked bend point before collapse")

local linkedPointGroupId = routeBlue.points[3].linkedPointGroupId
assertTrue(linkedPointGroupId ~= nil, "inserted bend point should belong to a linked shared lane group")

editor:updateLinkedPointGroup(linkedPointGroupId, routeBlue.points[4].x, routeBlue.points[4].y)

assertEqual(#routeBlue.points, 3, "moving a linked bend point onto the blue exit should collapse the blue route")
assertEqual(#routeYellow.points, 3, "moving a linked bend point onto the yellow exit should collapse the yellow route")
assertEqual(#routeBlue.segmentRoadTypes, 2, "blue route road type entries should collapse after endpoint merge")
assertEqual(#routeYellow.segmentRoadTypes, 2, "yellow route road type entries should collapse after endpoint merge")

local restoredSharedLane = editor:getSharedLaneForSegment(routeBlue, 2)
assertTrue(restoredSharedLane ~= nil, "collapsing a linked bend point should restore the shared lane index entry")
assertEqual(#(restoredSharedLane.members or {}), 2, "collapsing a linked bend point should restore one shared lane with both routes")

local foundSharedLaneLabel = false
for _, entry in ipairs(editor:getHitboxOverlayEntries()) do
    if entry.kind == "polygon" and string.find(entry.label, "shared lane", 1, true) then
        foundSharedLaneLabel = true
        break
    end
end
assertTrue(foundSharedLaneLabel, "collapsing a linked bend point should show the restored segment as a shared lane in hitbox debug mode")

assertEqual(#(editor.intersections or {}), 2, "collapsing the bend point should keep the two real junctions")

for _, intersection in ipairs(editor.intersections or {}) do
    local previewJunction = editor.previewWorld and editor.previewWorld.junctions and editor.previewWorld.junctions[intersection.id]
    assertTrue(previewJunction ~= nil, "preview world should keep both real junctions after collapsing the bend point")

    if intersection.y < routeBlue.points[3].y then
        assertEqual(#(previewJunction.outputs or {}), 1, "top junction should restore one compiled shared output after collapse")
    else
        assertEqual(#(previewJunction.inputs or {}), 1, "bottom junction should restore one compiled shared input after collapse")
    end
end

print("map editor shared lane endpoint collapse tests passed")
