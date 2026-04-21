package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}
love.timer = love.timer or {
    getTime = function()
        return 0
    end,
}
love.filesystem = love.filesystem or {}
love.keyboard = love.keyboard or {
    isDown = function()
        return false
    end,
}
love.mouse = love.mouse or {
    isDown = function()
        return false
    end,
}

local mapEditor = require("src.game.map_editor")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %q but got %q", label, expected, actual), 2)
    end
end

local function assertTrue(value, label)
    if not value then
        error(label, 2)
    end
end

local editorData = {
    endpoints = {
        { id = "input_a", kind = "input", x = 636 / 1280, y = 400 / 720, colors = { "blue" } },
        { id = "output_a", kind = "output", x = 644 / 1280, y = 400 / 720, colors = { "blue" } },
        { id = "input_b", kind = "input", x = 636 / 1280, y = 360 / 720, colors = { "orange" } },
        { id = "output_b", kind = "output", x = 644 / 1280, y = 360 / 720, colors = { "orange" } },
    },
    routes = {
        {
            id = "route_a",
            label = "route_a",
            color = "blue",
            startEndpointId = "input_a",
            endEndpointId = "output_a",
            segmentRoadTypes = { "normal", "normal" },
            points = {
                { x = 636 / 1280, y = 400 / 720 },
                { x = 640 / 1280, y = 360 / 720 },
                { x = 644 / 1280, y = 400 / 720 },
            },
        },
        {
            id = "route_b",
            label = "route_b",
            color = "orange",
            startEndpointId = "input_b",
            endEndpointId = "output_b",
            segmentRoadTypes = { "normal", "normal" },
            points = {
                { x = 636 / 1280, y = 360 / 720 },
                { x = 640 / 1280, y = 400 / 720 },
                { x = 644 / 1280, y = 360 / 720 },
            },
        },
    },
    junctions = {},
    trains = {},
}

local editor = mapEditor.new(1280, 720, nil)
editor:loadEditorData(editorData, "Hitbox Overlay", nil, nil)

local resetRect = editor:getResetButtonRect()
local toggleRect = editor:getHitboxToggleRect()
assertEqual(resetRect.w, toggleRect.w, "reset and hitbox toggle should split the bottom row evenly")
assertTrue(toggleRect.x > resetRect.x + resetRect.w, "hitbox toggle should sit to the right of reset")

assertEqual(editor.hitboxOverlayVisible, false, "hitbox overlay starts hidden")
assertTrue(editor:keypressed("f3"), "f3 should be handled by the editor")
assertEqual(editor.hitboxOverlayVisible, true, "f3 enables the hitbox overlay")

local entries = editor:getHitboxOverlayEntries()
assertTrue(#entries > 0, "hitbox overlay should expose entries for the current map")
assertTrue(entries[1].zIndex > entries[#entries].zIndex, "overlay z-indices should descend through hit order")
assertTrue(entries[1].label:find("route_b end", 1, true) ~= nil, "top hitbox should match the last route end magnet")

local sawSegment = false
local sawIntersection = false
for _, entry in ipairs(entries) do
    if entry.label:find("segment", 1, true) then
        sawSegment = true
    end
    if entry.label:find("direct", 1, true) then
        sawIntersection = true
    end
end

assertTrue(sawSegment, "overlay should include segment hitboxes")
assertTrue(sawIntersection, "overlay should include junction hitboxes")

assertTrue(editor:keypressed("f3"), "f3 should also disable the hitbox overlay")
assertEqual(editor.hitboxOverlayVisible, false, "f3 disables the hitbox overlay")

print("map editor hitbox overlay tests passed")
