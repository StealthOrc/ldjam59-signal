package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}
love.graphics = love.graphics or {}
love.filesystem = love.filesystem or {}

love.graphics.setColor = function()
end
love.graphics.setLineWidth = function()
end
love.graphics.line = function()
end
love.filesystem.getInfo = function()
    return false
end

local renderer = require("src.game.track_scene_renderer")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %s but got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local calls = {}
local originalDrawTrackPatternSegment = renderer.drawTrackPatternSegment

renderer.drawTrackPatternSegment = function(_, startX, startY, endX, endY)
    calls[#calls + 1] = {
        startX = startX,
        startY = startY,
        endX = endX,
        endY = endY,
    }
end

local scene = {
    getRenderedTrackWindow = function()
        return 0, 20
    end,
    pointOnPath = function(_, _, distance)
        return distance, 0, 0
    end,
}

local track = {
    styleSections = {
        {
            roadType = "fast",
            startDistance = 0,
            endDistance = 20,
        },
    },
}

renderer.drawTrackRoadTypeMarkers(scene, track, true)
renderer.drawTrackPatternSegment = originalDrawTrackPatternSegment

assertEqual(#calls, 2, "short visible fast sections should still draw one chevron marker")

print("track scene renderer short section marker tests passed")
