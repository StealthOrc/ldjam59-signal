package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}
love.timer = love.timer or {
    getTime = function()
        return 0
    end,
}
love.filesystem = love.filesystem or {}

local mapEditor = require("src.game.editor.map_editor")

local function assertTrue(value, label)
    if not value then
        error(label, 2)
    end
end

local editor = mapEditor.new(1280, 720, nil)
editor.validationErrors = {}
for index = 1, 20 do
    editor.validationErrors[#editor.validationErrors + 1] = string.format(
        "Validation issue %d: this is a deliberately long message so the list needs wrapping and scrolling in the side panel.",
        index
    )
end

local layout = editor:getValidationListLayout(love.graphics.getFont())

assertTrue(layout.maxScroll > 0, "validation issue layout should become scrollable when many errors are present")
assertTrue(layout.scrollbar ~= nil, "validation issue layout should expose a scrollbar for long error lists")
assertTrue(layout.listRect.h > 0, "validation issue layout should reserve visible height for the error list")

print("map editor validation scroll tests passed")
