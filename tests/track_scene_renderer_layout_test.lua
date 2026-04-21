love = love or {}
love.graphics = love.graphics or {}

local renderer = require("src.game.rendering.track_scene_renderer")

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected %s, got %s)", message, tostring(expected), tostring(actual)), 2)
    end
end

local function assertTrue(value, message)
    if not value then
        error(message, 2)
    end
end

local directJunction = {
    mergePoint = { x = 100, y = 200 },
    crossingRadius = 24,
    outputs = { {}, {} },
    control = { type = "direct" },
}

local bubbleX, bubbleY, bubbleRadius = renderer.getControlBubbleLayout(directJunction)
assertEqual(bubbleX, 100, "bubble layout keeps the junction horizontally centered")
assertEqual(bubbleY, 200, "bubble layout keeps the junction vertically centered")
assertEqual(bubbleRadius, 24, "bubble layout covers the full junction circle")

local selectorX, selectorY, selectorRadius = renderer.getOutputSelectorLayout(directJunction)
assertEqual(selectorX, 100, "selector stays horizontally centered on the junction")
assertEqual(selectorY, 224, "selector center sits on the bottom border of the main control")
assertEqual(selectorRadius, 15, "selector keeps the expected radius")
assertEqual(selectorY, bubbleY + bubbleRadius, "selector anchors to the main control border")

local singleOutputJunction = {
    mergePoint = { x = 100, y = 200 },
    crossingRadius = 24,
    outputs = { {} },
    control = { type = "direct" },
}

local _, singleBubbleY = renderer.getControlBubbleLayout(singleOutputJunction)
assertEqual(singleBubbleY, 200, "single-output junctions keep the control bubble centered")
assertEqual(renderer.getOutputSelectorLayout(singleOutputJunction), nil, "single-output junctions do not expose a selector")

local crossbarJunction = {
    mergePoint = { x = 100, y = 200 },
    crossingRadius = 24,
    outputs = { {}, {} },
    control = { type = "crossbar" },
}

local _, crossbarBubbleY = renderer.getControlBubbleLayout(crossbarJunction)
assertEqual(crossbarBubbleY, 200, "crossbar junctions keep the main control centered")
assertEqual(renderer.getOutputSelectorLayout(crossbarJunction), nil, "crossbar junctions do not expose the manual selector")

print("track scene renderer layout tests passed")
