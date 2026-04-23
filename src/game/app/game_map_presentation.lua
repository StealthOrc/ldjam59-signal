local mapPresentation = require("src.game.app.map_presentation")

return function(Game, shared)
    setfenv(1, setmetatable({ Game = Game }, {
        __index = function(_, key)
            local sharedValue = shared[key]
            if sharedValue ~= nil then
                return sharedValue
            end

            return _G[key]
        end,
    }))

function Game:beginMapPresentation(mapDescriptor)
    if not self.world then
        self.mapPresentation = nil
        return nil
    end

    self.mapPresentation = mapPresentation.buildState(self.world, mapDescriptor or self.currentMapDescriptor, self.profile)
    return self.mapPresentation
end

function Game:isMapPresentationActive()
    return self.screen == "play"
        and self.mapPresentation ~= nil
        and mapPresentation.isBlocking(self.mapPresentation)
end

function Game:updateMapPresentation(dt)
    if not self.mapPresentation then
        return false
    end

    local finished = mapPresentation.update(self.mapPresentation, dt)
    if finished then
        self.mapPresentation = nil
    end
    return finished
end

function Game:skipMapPresentation()
    if not self.mapPresentation then
        return false
    end

    self.mapPresentation = mapPresentation.skip(self.mapPresentation)
    self.playHoverInfo = nil
    return true
end

function Game:getMapPresentationDrawOptions()
    if self.screen ~= "play" or self.playPhase ~= "prepare" or not self.mapPresentation or not mapPresentation.isBlocking(self.mapPresentation) then
        return nil
    end

    return {
        presentation = self.mapPresentation,
        drawTrains = false,
        drawCollision = false,
    }
end

end
