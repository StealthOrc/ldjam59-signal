local input = require("src.game.input")
local levels = require("src.game.levels")
local mapEditor = require("src.game.map_editor")
local mapStorage = require("src.game.map_storage")
local world = require("src.game.world")
local ui = require("src.game.ui")

local Game = {}
Game.__index = Game

function Game.new()
    local self = setmetatable({}, Game)

    self.viewport = {
        w = 1280,
        h = 720,
    }
    self.window = {
        w = love.graphics.getWidth(),
        h = love.graphics.getHeight(),
    }

    self.fonts = {
        title = love.graphics.newFont(34),
        body = love.graphics.newFont(18),
        small = love.graphics.newFont(14),
    }

    self.screen = "menu"
    self.levelIndex = 1
    self.levelComplete = false
    self.failureReason = nil
    self.world = nil
    self.editor = mapEditor.new(self.viewport.w, self.viewport.h, nil)
    self.savedMaps = {}
    self.currentLevelSource = nil

    self:updateRenderTransform()
    self:refreshSavedMaps()

    return self
end

function Game:updateRenderTransform()
    self.renderScale = math.min(self.window.w / self.viewport.w, self.window.h / self.viewport.h)
    self.renderOffsetX = math.floor((self.window.w - self.viewport.w * self.renderScale) * 0.5 + 0.5)
    self.renderOffsetY = math.floor((self.window.h - self.viewport.h * self.renderScale) * 0.5 + 0.5)
end

function Game:toViewportPosition(screenX, screenY)
    return (screenX - self.renderOffsetX) / self.renderScale,
        (screenY - self.renderOffsetY) / self.renderScale
end

function Game:refreshSavedMaps()
    self.savedMaps = mapStorage.listMaps()
end

function Game:openMenu()
    self.screen = "menu"
    self:refreshSavedMaps()
end

function Game:openLevelSelect()
    self.screen = "level_select"
    self:refreshSavedMaps()
end

function Game:openEditorBlank()
    self.screen = "editor"
    self.editor:resetFromLevel(nil)
end

function Game:openEditorFromLevel(level)
    self.screen = "editor"
    self.editor:resetFromLevel(level)
end

function Game:openEditorSaved(fileName)
    local savedMap, loadError = mapStorage.loadMap(fileName)
    if not savedMap or not savedMap.editor then
        self.editor:showStatus(loadError or "That saved map could not be loaded into the editor.")
        self.screen = "editor"
        return
    end

    self.screen = "editor"
    self.editor:loadEditorData(savedMap.editor, savedMap.name)
end

function Game:startLevel(level, levelSource)
    self.levelComplete = false
    self.failureReason = nil
    self.currentLevelSource = levelSource
    self.world = world.new(self.viewport.w, self.viewport.h, level)
    self.screen = "play"
end

function Game:startBuiltinLevel(levelIndex)
    self.levelIndex = levelIndex
    self:startLevel(levelIndex, { kind = "builtin", index = levelIndex })
end

function Game:startSavedMap(fileName)
    local savedMap, loadError = mapStorage.loadMap(fileName)
    if not savedMap or not savedMap.level then
        return false, loadError or "The saved map did not contain playable level data."
    end

    self:startLevel(savedMap.level, { kind = "saved", fileName = fileName, name = savedMap.name })
    return true
end

function Game:restart()
    if not self.currentLevelSource then
        return
    end

    if self.currentLevelSource.kind == "builtin" then
        self:startBuiltinLevel(self.currentLevelSource.index)
        return
    end

    if self.currentLevelSource.kind == "saved" then
        self:startSavedMap(self.currentLevelSource.fileName)
    end
end

function Game:isRunLocked()
    return self.levelComplete or self.failureReason ~= nil
end

function Game:update(dt)
    if self.screen == "editor" then
        self.editor:update(dt)
        return
    end

    if self.screen ~= "play" or not self.world then
        return
    end

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
    love.graphics.clear(0.02, 0.03, 0.04, 1)

    love.graphics.push()
    love.graphics.translate(self.renderOffsetX, self.renderOffsetY)
    love.graphics.scale(self.renderScale, self.renderScale)

    if self.screen == "menu" then
        ui.drawMenu(self)
    elseif self.screen == "level_select" then
        ui.drawLevelSelect(self)
    elseif self.screen == "editor" then
        self.editor:draw(self)
    elseif self.screen == "play" and self.world then
        self.world:draw()
        ui.drawPlay(self)
    end

    love.graphics.pop()
end

function Game:resize(w, h)
    self.window.w = w
    self.window.h = h
    self:updateRenderTransform()
end

function Game:keypressed(key)
    if key == "escape" then
        if self.screen == "menu" then
            love.event.quit()
        elseif self.screen == "editor" then
            if not self.editor:keypressed(key) then
                self:openMenu()
            end
        else
            self:openMenu()
        end
        return
    end

    if self.screen == "menu" then
        if key == "return" or key == "space" then
            self:openLevelSelect()
        elseif key == "e" then
            self:openEditorBlank()
        end
        return
    end

    if self.screen == "level_select" then
        local requestedLevel = input.getLevelShortcut(key)
        if requestedLevel then
            self:startBuiltinLevel(requestedLevel)
        end
        return
    end

    if self.screen == "editor" then
        if self.editor:keypressed(key) then
            self:refreshSavedMaps()
            return
        end

        if key == "tab" then
            self:openMenu()
        end
        return
    end

    if self.screen ~= "play" or not self.world then
        return
    end

    if key == "m" then
        self:openMenu()
        return
    end

    if key == "e" or key == "tab" then
        self:openEditorFromLevel(self.world:getLevel())
        return
    end

    local requestedLevel = input.getLevelShortcut(key)
    if requestedLevel then
        self:startBuiltinLevel(requestedLevel)
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

function Game:textinput(text)
    if self.screen == "editor" then
        self.editor:textinput(text)
    end
end

function Game:mousepressed(x, y, button)
    local viewportX, viewportY = self:toViewportPosition(x, y)

    if self.screen == "menu" then
        local action = ui.getMenuActionAt(self, viewportX, viewportY)
        if action == "play" then
            self:openLevelSelect()
        elseif action == "editor" then
            self:openEditorBlank()
        elseif action == "quit" then
            love.event.quit()
        end
        return
    end

    if self.screen == "level_select" then
        local hit = ui.getLevelSelectHit(self, viewportX, viewportY)
        if not hit then
            return
        end

        if hit.kind == "back" then
            self:openMenu()
        elseif hit.kind == "builtin" then
            self:startBuiltinLevel(hit.index)
        elseif hit.kind == "saved" then
            local savedMap = mapStorage.loadMap(hit.fileName)
            if savedMap and savedMap.level then
                self:startSavedMap(hit.fileName)
            else
                self:openEditorSaved(hit.fileName)
            end
        elseif hit.kind == "edit_saved" then
            self:openEditorSaved(hit.fileName)
        end
        return
    end

    if self.screen == "editor" then
        self.editor:mousepressed(viewportX, viewportY, button)
        self:refreshSavedMaps()
        return
    end

    if self.screen ~= "play" or not self.world then
        return
    end

    if button ~= 1 then
        return
    end

    if ui.getPlayBackHit(self, viewportX, viewportY) then
        self:openMenu()
        return
    end

    if self:isRunLocked() then
        self:restart()
        return
    end

    self.world:handleClick(viewportX, viewportY)
end

function Game:mousemoved(x, y)
    if self.screen == "editor" then
        local viewportX, viewportY = self:toViewportPosition(x, y)
        self.editor:mousemoved(viewportX, viewportY)
    end
end

function Game:mousereleased(x, y, button)
    if self.screen == "editor" then
        local viewportX, viewportY = self:toViewportPosition(x, y)
        self.editor:mousereleased(viewportX, viewportY, button)
        self:refreshSavedMaps()
    end
end

function Game:keyreleased(_)
end

function Game:gamepadpressed(_, button)
    if self.screen == "play" and (button == "start" or button == "a") then
        if self:isRunLocked() then
            self:restart()
        end
    end
end

function Game:gamepadreleased(_, _)
end

return Game
