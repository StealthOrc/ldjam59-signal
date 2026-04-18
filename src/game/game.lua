local input = require("src.game.input")
local world = require("src.game.world")
local ui = require("src.game.ui")

local Game = {}
Game.__index = Game

function Game.new()
    local self = setmetatable({}, Game)

    self.viewport = {
        w = love.graphics.getWidth(),
        h = love.graphics.getHeight(),
    }

    self.fonts = {
        title = love.graphics.newFont(34),
        body = love.graphics.newFont(18),
        small = love.graphics.newFont(14),
    }

    self.world = world.new(self.viewport.w, self.viewport.h)
    self.levelComplete = false
    self.levelFailed = false

    return self
end

function Game:restart()
    self.world = world.new(self.viewport.w, self.viewport.h)
    self.levelComplete = false
    self.levelFailed = false
end

function Game:isRunLocked()
    return self.levelComplete or self.levelFailed
end

function Game:setActiveTrack(trackId)
    if self:isRunLocked() then
        return
    end
    self.world:setActiveTrack(trackId)
end

function Game:toggleTrack()
    if self:isRunLocked() then
        return
    end
    self.world:toggleTrack()
end

function Game:update(dt)
    if self:isRunLocked() then
        return
    end

    self.world:update(dt)
    self.levelFailed = self.world:hasCollision()
    if not self.levelFailed then
        self.levelComplete = self.world:isLevelComplete()
    end
end

function Game:draw()
    love.graphics.clear(0.05, 0.07, 0.09)
    self.world:draw()
    ui.draw(self)
end

function Game:resize(w, h)
    self.viewport.w = w
    self.viewport.h = h
    self.world:resize(w, h)
end

function Game:keypressed(key)
    if key == "escape" then
        love.event.quit()
        return
    end

    if self:isRunLocked() and (key == "r" or key == "return" or key == "space") then
        self:restart()
        return
    end

    local action = input.getTrackAction(key)
    if action == "toggle" then
        self:toggleTrack()
    elseif action then
        self:setActiveTrack(action)
    end
end

function Game:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    if self:isRunLocked() then
        self:restart()
        return
    end

    if self.world:isCrossingHit(x, y) then
        self:toggleTrack()
    end
end

function Game:keyreleased(_)
end

function Game:gamepadpressed(_, button)
    if self:isRunLocked() and (button == "a" or button == "start") then
        self:restart()
        return
    end

    if button == "dpleft" then
        self:setActiveTrack(1)
    elseif button == "dpright" then
        self:setActiveTrack(2)
    elseif button == "a" or button == "x" then
        self:toggleTrack()
    end
end

function Game:gamepadreleased(_, _)
end

return Game
