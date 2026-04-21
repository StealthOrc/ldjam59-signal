package.path = "./?.lua;./?/init.lua;" .. package.path

local pixelPerfectText = require("src.game.rendering.pixel_perfect_text")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %s but got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local function assertNear(actual, expected, tolerance, label)
    if math.abs(actual - expected) > tolerance then
        error(string.format("%s expected %.4f but got %.4f", label, expected, actual), 2)
    end
end

local function transformPoint(x, y)
    return 30 + x * 1.5, 18 + y * 1.5
end

local textTransform = pixelPerfectText.computeTextTransform(transformPoint, 10, 20)
assertEqual(textTransform.x, 45, "text transform snaps x to the nearest screen pixel")
assertEqual(textTransform.y, 48, "text transform snaps y to the nearest screen pixel")
assertNear(textTransform.scaleX, 1.5, 0.0001, "text transform keeps horizontal scale")
assertNear(textTransform.scaleY, 1.5, 0.0001, "text transform keeps vertical scale")
assertNear(textTransform.rotation, 0, 0.0001, "text transform keeps zero rotation for axis-aligned scaling")

local scissorX, scissorY, scissorW, scissorH = pixelPerfectText.computeScissorRect(transformPoint, 10, 20, 30, 12)
assertEqual(scissorX, 45, "scissor snaps left edge")
assertEqual(scissorY, 48, "scissor snaps top edge")
assertEqual(scissorW, 45, "scissor keeps transformed width")
assertEqual(scissorH, 18, "scissor keeps transformed height")

print("pixel perfect text transform tests passed")
