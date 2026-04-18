local Game = require("src.game.game")

local game

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.window.setMode(1280, 720, {resizable = true, minwidth = 960, minheight = 540, vsync = 1})
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

function love.gamepadpressed(joystick, button)
    game:gamepadpressed(joystick, button)
end
