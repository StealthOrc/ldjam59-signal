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

local function distanceBetween(firstPoint, secondPoint)
    local dx = (firstPoint.x or 0) - (secondPoint.x or 0)
    local dy = (firstPoint.y or 0) - (secondPoint.y or 0)
    return math.sqrt(dx * dx + dy * dy)
end

local function findTrackByEndpoint(tracks, endpointPoint, useLastPoint)
    for _, track in ipairs(tracks or {}) do
        local pathPoints = track and track.path and track.path.points or {}
        local candidatePoint = useLastPoint and pathPoints[#pathPoints] or pathPoints[1]
        if candidatePoint and distanceBetween(candidatePoint, endpointPoint) <= 0.001 then
            return track
        end
    end

    return nil
end

local editorData = {
    endpoints = {
        { id = "input_bottom", kind = "input", x = 0.50, y = 0.90, colors = { "blue" } },
        { id = "input_left", kind = "input", x = 0.20, y = 0.50, colors = { "yellow" } },
        { id = "output_top_right", kind = "output", x = 0.80, y = 0.10, colors = { "blue" } },
        { id = "output_top_left", kind = "output", x = 0.20, y = 0.10, colors = { "yellow" } },
    },
    routes = {
        {
            id = "route_blue",
            label = "route_blue",
            color = "blue",
            startEndpointId = "input_bottom",
            endEndpointId = "output_top_right",
            segmentRoadTypes = { "normal", "normal" },
            points = {
                { x = 0.50, y = 0.90 },
                { x = 0.50, y = 0.50 },
                { x = 0.80, y = 0.10 },
            },
        },
        {
            id = "route_yellow",
            label = "route_yellow",
            color = "yellow",
            startEndpointId = "input_left",
            endEndpointId = "output_top_left",
            segmentRoadTypes = { "normal", "normal" },
            points = {
                { x = 0.20, y = 0.50 },
                { x = 0.50, y = 0.50 },
                { x = 0.20, y = 0.10 },
            },
        },
    },
    junctions = {
        {
            id = "junction_center_seed",
            x = 0.50,
            y = 0.50,
            control = "direct",
            activeInputIndex = 1,
            activeOutputIndex = 1,
            routes = { "route_blue", "route_yellow" },
        },
    },
    trains = {},
}

local editor = mapEditor.new(1280, 720, nil)
editor:loadEditorData(editorData, "Junction Track Trim Alignment", nil, nil)

local routeBlue = editor:getRouteById("route_blue")
local intersection = editor.intersections and editor.intersections[1] or nil
local previewJunction = intersection and editor.previewWorld and editor.previewWorld.junctions and editor.previewWorld.junctions[intersection.id] or nil

assertTrue(routeBlue ~= nil, "bottom route should exist")
assertTrue(intersection ~= nil, "shared center junction should exist")
assertTrue(previewJunction ~= nil, "preview world should expose the center junction")

local bottomInputTrack = findTrackByEndpoint(previewJunction.inputs, routeBlue.points[1], false)
local blueOutputTrack = findTrackByEndpoint(previewJunction.outputs, routeBlue.points[#routeBlue.points], true)

assertTrue(bottomInputTrack ~= nil, "preview junction should expose the bottom input track")
assertTrue(blueOutputTrack ~= nil, "preview junction should expose the blue output track")

local inputMetrics = editor:getSegmentHitMetrics(routeBlue, 1)
local outputMetrics = editor:getSegmentHitMetrics(routeBlue, 2)
local renderedBottomInputPoints = editor.previewWorld:getRenderedTrackPoints(bottomInputTrack)
local renderedBlueOutputPoints = editor.previewWorld:getRenderedTrackPoints(blueOutputTrack)
local junctionPoint = routeBlue.points[2]

assertNear(
    distanceBetween(renderedBottomInputPoints[#renderedBottomInputPoints], junctionPoint),
    inputMetrics.endInset,
    0.001,
    "bottom input track trim should match the editor hitbox inset"
)

assertNear(
    distanceBetween(renderedBlueOutputPoints[1], junctionPoint),
    outputMetrics.startInset,
    0.001,
    "output track trim should match the editor hitbox inset"
)

assertNear(
    distanceBetween(bottomInputTrack.signalPoint, renderedBottomInputPoints[#renderedBottomInputPoints]),
    editor.previewWorld.junctionSignalGap or 0,
    0.001,
    "bottom input signal should sit a fixed distance before the rendered lane end"
)

print("map editor junction track trim alignment tests passed")
