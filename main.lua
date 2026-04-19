local Game = require("src.game.game")

local game

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    game = Game.new()
end

function love.update(dt)
    game:update(dt)
end

function love.draw()
    game:draw()
end

function love.resize(w, h)
    game:resize(w, h)
end

function love.keypressed(key)
    game:keypressed(key)
end

function love.keyreleased(key)
    game:keyreleased(key)
end

function love.textinput(text)
    game:textinput(text)
end

function love.mousepressed(x, y, button)
    game:mousepressed(x, y, button)
end

function love.mousemoved(x, y)
    game:mousemoved(x, y)
end

function love.mousereleased(x, y, button)
    game:mousereleased(x, y, button)
end

function love.wheelmoved(x, y)
    game:wheelmoved(x, y)
end

function love.gamepadpressed(joystick, button)
    game:gamepadpressed(joystick, button)
end

function love.gamepadreleased(joystick, button)
    game:gamepadreleased(joystick, button)
end
