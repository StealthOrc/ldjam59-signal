love = love or {}
love.graphics = love.graphics or {}

local renderer = require("src.game.rendering.track_scene_renderer")

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected %s, got %s)", message, tostring(expected), tostring(actual)), 2)
    end
end

local function assertTrue(value, message)
    if not value then
        error(message, 2)
    end
end

local function buildRenderedTrack(id)
    return {
        id = id,
        color = { 1, 1, 1 },
        darkColor = { 0.5, 0.5, 0.5 },
        colors = {},
        styleSections = {},
        path = {
            points = {
                { x = 0, y = 0 },
                { x = 10, y = 0 },
            },
        },
        renderedPoints = {
            { x = 0, y = 0 },
            { x = 10, y = 0 },
        },
    }
end

local lineJoinCalls = {}
love.graphics.setLineStyle = function()
end
love.graphics.setLineJoin = function(value)
    lineJoinCalls[#lineJoinCalls + 1] = value
end
love.graphics.setColor = function()
end
love.graphics.setLineWidth = function()
end
love.graphics.line = function()
end
love.graphics.circle = function()
end
love.graphics.arc = function()
end
love.graphics.push = function()
end
love.graphics.pop = function()
end
love.graphics.translate = function()
end
love.graphics.rotate = function()
end
love.graphics.scale = function()
end
love.graphics.printf = function()
end
love.graphics.rectangle = function()
end

local originalDrawTrackRoadTypeMarkers = renderer.drawTrackRoadTypeMarkers
renderer.drawTrackRoadTypeMarkers = function()
end

local renderScene = {
    trackWidth = 12,
    sharedWidth = 16,
    getRenderedTrackPoints = function(_, track)
        return track.renderedPoints
    end,
    getOutputDisplayColor = function()
        return { 1, 1, 1 }
    end,
}

local inputTrack = buildRenderedTrack("input_track")
local standaloneTrack = buildRenderedTrack("standalone_track")
local outputTrack = buildRenderedTrack("output_track")
local outputJunction = {
    outputs = { outputTrack },
}

renderer.drawInputTrack(renderScene, inputTrack, true)
renderer.drawStandaloneTrack(renderScene, standaloneTrack, true)
renderer.drawOutputTrack(renderScene, outputJunction, 1, true)

assertEqual(lineJoinCalls[1], "bevel", "input tracks should use beveled line joins")
assertEqual(lineJoinCalls[2], "bevel", "standalone tracks should use beveled line joins")
assertEqual(lineJoinCalls[3], "bevel", "output tracks should use beveled line joins")

renderer.drawTrackRoadTypeMarkers = originalDrawTrackRoadTypeMarkers

local drawOrder = {}
local originalDrawOutputTrack = renderer.drawOutputTrack
local originalDrawInputTrack = renderer.drawInputTrack
local originalDrawStandaloneTrack = renderer.drawStandaloneTrack
local originalDrawCrossing = renderer.drawCrossing
local originalDrawTrackSignal = renderer.drawTrackSignal
local originalDrawTrain = renderer.drawTrain
local originalDrawOutputSelector = renderer.drawOutputSelector

renderer.drawOutputTrack = function(_, _, _, _)
    drawOrder[#drawOrder + 1] = "output"
end
renderer.drawInputTrack = function(_, _, _)
    drawOrder[#drawOrder + 1] = "input"
end
renderer.drawStandaloneTrack = function(_, track, _)
    drawOrder[#drawOrder + 1] = "standalone:" .. tostring(track.id)
end
renderer.drawCrossing = function(_, junction)
    drawOrder[#drawOrder + 1] = "crossing:" .. tostring(junction.id)
end
renderer.drawTrackSignal = function(_, junction, inputIndex)
    drawOrder[#drawOrder + 1] = "signal:" .. tostring(junction.id) .. ":" .. tostring(inputIndex)
end
renderer.drawTrain = function(_, train)
    drawOrder[#drawOrder + 1] = "train:" .. tostring(train.id)
end
renderer.drawOutputSelector = function(_, junction)
    drawOrder[#drawOrder + 1] = "selector:" .. tostring(junction.id)
end

local scene = {
    viewport = { w = 320, h = 200 },
    junctionOrder = {
        {
            id = "junction_alpha",
            outputs = { { id = "junction_output" } },
            inputs = { { id = "junction_input", signalPoint = { x = 0, y = 0 } } },
            control = { type = "direct" },
            mergePoint = { x = 20, y = 20 },
            crossingRadius = 24,
            activeInputIndex = 1,
            activeOutputIndex = 1,
        },
    },
    edges = {
        { id = "free_edge" },
    },
    trains = {
        { id = "train_alpha" },
    },
    getHighlightedEdgeIds = function()
        return {}
    end,
}

renderer.drawScene(scene, {})

renderer.drawOutputTrack = originalDrawOutputTrack
renderer.drawInputTrack = originalDrawInputTrack
renderer.drawStandaloneTrack = originalDrawStandaloneTrack
renderer.drawCrossing = originalDrawCrossing
renderer.drawTrackSignal = originalDrawTrackSignal
renderer.drawTrain = originalDrawTrain
renderer.drawOutputSelector = originalDrawOutputSelector

local crossingIndex = nil
local standaloneIndex = nil
for index, call in ipairs(drawOrder) do
    if call == "crossing:junction_alpha" then
        crossingIndex = index
    elseif call == "standalone:free_edge" then
        standaloneIndex = index
    end
end

assertTrue(standaloneIndex ~= nil, "standalone track should be rendered")
assertTrue(crossingIndex ~= nil, "crossing should be rendered")
assertTrue(crossingIndex > standaloneIndex, "crossing should render after standalone lanes so the junction stays on top")
assertEqual(drawOrder[#drawOrder], "selector:junction_alpha", "output selector should stay on the final overlay pass")

print("track scene renderer layering tests passed")
