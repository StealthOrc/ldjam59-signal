package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}

local authoredMap = require("src.game.data.authored_map")

local function assertTrue(value, label)
    if not value then
        error(label, 2)
    end
end

local editorData = {
    endpoints = {
        { id = "in_1", kind = "input", x = 0.10, y = 0.10, colors = { "blue" } },
        { id = "in_2", kind = "input", x = 0.22, y = 0.10, colors = { "yellow" } },
        { id = "in_3", kind = "input", x = 0.34, y = 0.10, colors = { "mint" } },
        { id = "in_4", kind = "input", x = 0.46, y = 0.10, colors = { "rose" } },
        { id = "in_5", kind = "input", x = 0.58, y = 0.10, colors = { "orange" } },
        { id = "in_6", kind = "input", x = 0.70, y = 0.10, colors = { "violet" } },
        { id = "out_1", kind = "output", x = 0.10, y = 0.90, colors = { "blue" } },
        { id = "out_2", kind = "output", x = 0.22, y = 0.90, colors = { "yellow" } },
        { id = "out_3", kind = "output", x = 0.34, y = 0.90, colors = { "mint" } },
        { id = "out_4", kind = "output", x = 0.46, y = 0.90, colors = { "rose" } },
        { id = "out_5", kind = "output", x = 0.58, y = 0.90, colors = { "orange" } },
        { id = "out_6", kind = "output", x = 0.70, y = 0.90, colors = { "violet" } },
    },
    routes = {
        { id = "route_1", label = "route_1", color = "blue", startEndpointId = "in_1", endEndpointId = "out_1", segmentRoadTypes = { "normal", "normal" }, points = { { x = 0.10, y = 0.10 }, { x = 0.50, y = 0.50 }, { x = 0.10, y = 0.90 } } },
        { id = "route_2", label = "route_2", color = "yellow", startEndpointId = "in_2", endEndpointId = "out_2", segmentRoadTypes = { "normal", "normal" }, points = { { x = 0.22, y = 0.10 }, { x = 0.50, y = 0.50 }, { x = 0.22, y = 0.90 } } },
        { id = "route_3", label = "route_3", color = "mint", startEndpointId = "in_3", endEndpointId = "out_3", segmentRoadTypes = { "normal", "normal" }, points = { { x = 0.34, y = 0.10 }, { x = 0.50, y = 0.50 }, { x = 0.34, y = 0.90 } } },
        { id = "route_4", label = "route_4", color = "rose", startEndpointId = "in_4", endEndpointId = "out_4", segmentRoadTypes = { "normal", "normal" }, points = { { x = 0.46, y = 0.10 }, { x = 0.50, y = 0.50 }, { x = 0.46, y = 0.90 } } },
        { id = "route_5", label = "route_5", color = "orange", startEndpointId = "in_5", endEndpointId = "out_5", segmentRoadTypes = { "normal", "normal" }, points = { { x = 0.58, y = 0.10 }, { x = 0.50, y = 0.50 }, { x = 0.58, y = 0.90 } } },
        { id = "route_6", label = "route_6", color = "violet", startEndpointId = "in_6", endEndpointId = "out_6", segmentRoadTypes = { "normal", "normal" }, points = { { x = 0.70, y = 0.10 }, { x = 0.50, y = 0.50 }, { x = 0.70, y = 0.90 } } },
    },
    junctions = {
        {
            id = "junction_six_way",
            x = 0.50,
            y = 0.50,
            control = "direct",
            passCount = 1,
            activeInputIndex = 1,
            activeOutputIndex = 1,
            routes = { "route_1", "route_2", "route_3", "route_4", "route_5", "route_6" },
            inputEndpointIds = { "in_1", "in_2", "in_3", "in_4", "in_5", "in_6" },
            outputEndpointIds = { "out_1", "out_2", "out_3", "out_4", "out_5", "out_6" },
        },
    },
    trains = {},
}

local level, firstError, buildErrors = authoredMap.buildPlayableLevel("Large Junction", editorData, nil)

assertTrue(level ~= nil, "authored map should allow a junction with more than five inputs and outputs")
assertTrue(firstError == nil, "large junction validation should not report a first error")
assertTrue(buildErrors and #buildErrors == 0, "large junction validation should not emit any errors")
assertTrue(level.junctions and #level.junctions == 1, "large junction should still produce a playable junction")
assertTrue(#(level.junctions[1].inputEdgeIds or {}) == 6, "large junction should keep all six inputs")
assertTrue(#(level.junctions[1].outputEdgeIds or {}) == 6, "large junction should keep all six outputs")

print("authored map large junction tests passed")
