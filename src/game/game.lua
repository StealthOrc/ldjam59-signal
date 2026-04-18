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

    self.levelIndex = 1
    self.levelComplete = false
    self.failureReason = nil
    self.world = world.new(self.viewport.w, self.viewport.h, self.levelIndex)

    return self
end

function Game:loadLevel(levelIndex)
    self.levelIndex = levelIndex
    self.levelComplete = false
    self.failureReason = nil
    self.world = world.new(self.viewport.w, self.viewport.h, self.levelIndex)
end

function Game:restart()
    self:loadLevel(self.levelIndex)
end

function Game:isRunLocked()
    return self.levelComplete or self.failureReason ~= nil
end

function Game:update(dt)
    if self:isRunLocked() then
        return
    end

    self.world:update(dt)
    self.failureReason = self.world:getFailureReason()
    if not self.failureReason then
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

    local requestedLevel = input.getLevelShortcut(key)
    if requestedLevel then
        self:loadLevel(requestedLevel)
        return
    end

    if key == "r" then
        self:restart()
        return
    end

    if self:isRunLocked() and (key == "return" or key == "space") then
        self:restart()
    end
end

function Game:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    local requestedLevel = ui.getLevelTabAt(self, x, y)
    if requestedLevel then
        self:loadLevel(requestedLevel)
        return
    end

    if self:isRunLocked() then
        self:restart()
        return
    end

    self.world:handleClick(x, y)
end

function Game:keyreleased(_)
end

function Game:gamepadpressed(_, button)
    if button == "leftshoulder" then
        self:loadLevel(math.max(1, self.levelIndex - 1))
        return
    end

    if button == "rightshoulder" then
        self:loadLevel(math.min(self.world:getLevelCount(), self.levelIndex + 1))
        return
    end

    if button == "start" or button == "a" then
        if self:isRunLocked() then
            self:restart()
        end
    end
end

function Game:gamepadreleased(_, _)
end

return Game
