package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}
love.graphics = love.graphics or {}
love.filesystem = love.filesystem or {}

love.graphics.setLineStyle = function()
end
love.graphics.setColor = function()
end
love.graphics.setLineWidth = function()
end
love.graphics.line = function()
end
love.filesystem.getInfo = function()
    return false
end

local world = require("src.game.world")

local function assertTrue(value, label)
    if not value then
        error(label, 2)
    end
end

local simulation = world.new(100, 100, {
    edges = {},
    junctions = {},
    trains = {},
})

local markersCalled = 0
simulation.drawTrackRoadTypeMarkers = function(_, track, isActive)
    markersCalled = markersCalled + 1
    assertTrue(track.id == "input_track", "input track markers should receive the input track")
    assertTrue(isActive == true, "input track markers should preserve the active state")
end

simulation.drawTrackLine = function()
end

simulation.drawStripedTrack = function()
end

local inputTrack = {
    id = "input_track",
    color = { 1, 1, 1 },
    darkColor = { 0.5, 0.5, 0.5 },
    colors = {},
    styleSections = {
        {
            roadType = "fast",
            startDistance = 0,
            endDistance = 100,
        },
    },
    path = {
        length = 100,
        points = {
            { x = 0, y = 0 },
            { x = 100, y = 0 },
        },
        segments = {
            {
                a = { x = 0, y = 0 },
                b = { x = 100, y = 0 },
                startDistance = 0,
                length = 100,
            },
        },
    },
    sourceType = "start",
    targetType = "junction",
}

simulation:drawInputTrack(inputTrack, true)

assertTrue(markersCalled == 1, "input tracks should render road type markers once")

print("world input track marker tests passed")
