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

local mapEditor = require("src.game.editor.map_editor")

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

local function assertNear(actual, expected, tolerance, label)
    if math.abs(actual - expected) > tolerance then
        error(string.format("%s expected %.4f but got %.4f", label, expected, actual), 2)
    end
end

local editorData = {
    endpoints = {
        { id = "input_blue", kind = "input", x = 0.20, y = 0.20, colors = { "blue" } },
        { id = "input_yellow", kind = "input", x = 0.20, y = 0.70, colors = { "yellow" } },
        { id = "output_shared", kind = "output", x = 0.82, y = 0.45, colors = { "blue", "yellow" } },
    },
    routes = {
        {
            id = "route_blue",
            label = "route_blue",
            color = "blue",
            startEndpointId = "input_blue",
            endEndpointId = "output_shared",
            segmentRoadTypes = { "normal" },
            points = {
                { x = 0.20, y = 0.20 },
                { x = 0.82, y = 0.45 },
            },
        },
        {
            id = "route_yellow",
            label = "route_yellow",
            color = "yellow",
            startEndpointId = "input_yellow",
            endEndpointId = "output_shared",
            segmentRoadTypes = { "normal" },
            points = {
                { x = 0.20, y = 0.70 },
                { x = 0.82, y = 0.45 },
            },
        },
    },
    junctions = {},
    trains = {},
}

local editor = mapEditor.new(1280, 720, nil)
editor:loadEditorData(editorData, "Route End Disconnect Drag", nil, nil)

local routeBlue = editor:getRouteById("route_blue")
local sharedEndpoint = editor:getEndpointById("output_shared")
assertTrue(routeBlue ~= nil, "blue route should exist")
assertTrue(sharedEndpoint ~= nil, "shared endpoint should exist")

local endPoint = routeBlue.points[#routeBlue.points]
local endScreenX, endScreenY = editor:mapToScreen(endPoint.x, endPoint.y)

assertTrue(editor:mousepressed(endScreenX, endScreenY, 2), "right-clicking the shared end should open the route-end wheel")
assertTrue(editor.colorPicker ~= nil and editor.colorPicker.mode == "route_end", "route-end wheel should be open")
assertEqual(editor.colorPicker.branch, "disconnect", "route-end wheel should open directly on disconnect options")

local layout = editor:getColorPickerLayout()
local blueEntry = nil
for _, entry in ipairs(layout.submenu.entries or {}) do
    if entry.option.id == "blue" then
        blueEntry = entry
        break
    end
end

assertTrue(blueEntry ~= nil, "disconnect wheel should list the selected route color")
assertTrue(editor:handleColorPickerClick(blueEntry.centerX, blueEntry.centerY, 1), "clicking the route color should split the shared end")
assertTrue(editor.drag ~= nil and editor.drag.kind == "point", "splitting the shared end should immediately start an endpoint drag")
assertTrue(editor.drag.pickupMode == true, "shared end split should use pickup mode")
assertTrue(editor.drag.awaitingPickupRelease == true, "shared end split should wait for the first release before dropping")

editor:mousereleased(blueEntry.centerX, blueEntry.centerY, 1)
assertTrue(editor.drag ~= nil and editor.drag.kind == "point", "the first release after splitting should keep the endpoint in hand")
assertTrue(editor.drag.awaitingPickupRelease == false, "the first release should only arm the pickup drag")

local targetMapX = endPoint.x + 60
local targetMapY = endPoint.y - 40
local targetScreenX, targetScreenY = editor:mapToScreen(targetMapX, targetMapY)
editor:mousemoved(targetScreenX, targetScreenY, targetScreenX - blueEntry.centerX, targetScreenY - blueEntry.centerY)
editor:mousepressed(targetScreenX, targetScreenY, 1)
editor:mousereleased(targetScreenX, targetScreenY, 1)

local detachedEndpoint = editor:getRouteEndEndpoint(routeBlue)
assertTrue(detachedEndpoint ~= nil and detachedEndpoint.id ~= sharedEndpoint.id, "blue route should now use a detached endpoint")
assertNear(detachedEndpoint.x, targetMapX, 0.001, "detached endpoint should land on the clicked x position")
assertNear(detachedEndpoint.y, targetMapY, 0.001, "detached endpoint should land on the clicked y position")
assertEqual(editor:getEndpointRouteCount(sharedEndpoint.id), 1, "the original shared endpoint should keep only the other route")

print("map editor route end disconnect drag tests passed")
