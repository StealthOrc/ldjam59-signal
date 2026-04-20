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

local function assertFalse(value, label)
    if value then
        error(label, 2)
    end
end

local function findMergeCandidateIntersection(editor)
    for _, intersection in ipairs(editor.intersections or {}) do
        if intersection.canMergeToBendPoint then
            return intersection
        end
    end
    return nil
end

local function findIntersectionByCompiledShape(editor, inputCount, outputCount)
    for _, intersection in ipairs(editor.intersections or {}) do
        local previewJunction = editor.previewWorld
            and editor.previewWorld.junctions
            and editor.previewWorld.junctions[intersection.id]
            or nil
        if previewJunction
            and #(previewJunction.inputs or {}) == inputCount
            and #(previewJunction.outputs or {}) == outputCount then
            return intersection
        end
    end
    return nil
end

local mergeLaneEditorData = {
    endpoints = {
        { id = "input_left", kind = "input", x = 0.18, y = 0.18, colors = { "blue" } },
        { id = "input_right", kind = "input", x = 0.82, y = 0.18, colors = { "orange" } },
        { id = "output_shared", kind = "output", x = 0.5, y = 0.86, colors = { "blue", "orange" } },
    },
    routes = {
        {
            id = "route_blue",
            label = "route_blue",
            color = "blue",
            startEndpointId = "input_left",
            endEndpointId = "output_shared",
            segmentRoadTypes = { "normal", "normal" },
            points = {
                { x = 0.18, y = 0.18 },
                { x = 0.5, y = 0.46, sharedPointId = 1 },
                { x = 0.5, y = 0.86 },
            },
        },
        {
            id = "route_orange",
            label = "route_orange",
            color = "orange",
            startEndpointId = "input_right",
            endEndpointId = "output_shared",
            segmentRoadTypes = { "normal", "normal" },
            points = {
                { x = 0.82, y = 0.18 },
                { x = 0.5, y = 0.46, sharedPointId = 1 },
                { x = 0.5, y = 0.86 },
            },
        },
    },
    junctions = {},
    trains = {},
}

local editor = mapEditor.new(1280, 720, nil)
editor:loadEditorData(mergeLaneEditorData, "Merge Bend Point", nil, nil)

local mergeIntersection = findMergeCandidateIntersection(editor)
assertTrue(mergeIntersection ~= nil, "merged lanes that funnel into one output should offer a merge bend point option")
assertTrue(editor:canIntersectionUseControlType(mergeIntersection, "merge"), "eligible merged lane should accept the merge bend point control")

editor:openJunctionPicker(mergeIntersection, 640, 360)
editor.colorPicker.branch = "junctions"

local mergeOptionFound = false
for _, entry in ipairs((editor:getJunctionPickerLayout().submenu or {}).entries or {}) do
    if entry.option and entry.option.controlType == "merge" then
        mergeOptionFound = true
        break
    end
end
assertTrue(mergeOptionFound, "junction picker should expose a merge bend point option for eligible merged lanes")

assertTrue(editor:setIntersectionControlType(mergeIntersection, "merge"), "editor should allow switching an eligible merged lane to a merge bend point")
assertEqual(findMergeCandidateIntersection(editor).controlType, "merge", "intersection should retain the merge bend point control type")
assertEqual(editor.previewWorld.junctionOrder[1].control.type, "merge", "preview world should compile the passive merge control")

local exported = editor:getExportData()
assertEqual(exported.junctions[1].control, "merge", "exported editor data should persist the merge bend point control type")

local reloadedEditor = mapEditor.new(1280, 720, nil)
reloadedEditor:loadEditorData(exported, "Merge Bend Point Reloaded", nil, nil)
local reloadedIntersection = findMergeCandidateIntersection(reloadedEditor)
assertTrue(reloadedIntersection ~= nil, "reloaded editor should keep the merge bend point candidate")
assertEqual(reloadedIntersection.controlType, "merge", "reloaded editor should preserve the merge bend point control")

local crossingEditorData = {
    endpoints = {
        { id = "input_left", kind = "input", x = 0.18, y = 0.2, colors = { "blue" } },
        { id = "output_right", kind = "output", x = 0.82, y = 0.8, colors = { "blue" } },
        { id = "input_right", kind = "input", x = 0.82, y = 0.2, colors = { "orange" } },
        { id = "output_left", kind = "output", x = 0.18, y = 0.8, colors = { "orange" } },
    },
    routes = {
        {
            id = "route_blue",
            label = "route_blue",
            color = "blue",
            startEndpointId = "input_left",
            endEndpointId = "output_right",
            segmentRoadTypes = { "normal" },
            points = {
                { x = 0.18, y = 0.2 },
                { x = 0.82, y = 0.8 },
            },
        },
        {
            id = "route_orange",
            label = "route_orange",
            color = "orange",
            startEndpointId = "input_right",
            endEndpointId = "output_left",
            segmentRoadTypes = { "normal" },
            points = {
                { x = 0.82, y = 0.2 },
                { x = 0.18, y = 0.8 },
            },
        },
    },
    junctions = {},
    trains = {},
}

local crossingEditor = mapEditor.new(1280, 720, nil)
crossingEditor:loadEditorData(crossingEditorData, "Crossing Junction", nil, nil)
local crossingIntersection = crossingEditor.intersections[1]
assertFalse(crossingEditor:canIntersectionUseControlType(crossingIntersection, "merge"), "regular crossings should not expose the merge bend point control")

crossingEditor:openJunctionPicker(crossingIntersection, 640, 360)
crossingEditor.colorPicker.branch = "junctions"
for _, entry in ipairs((crossingEditor:getJunctionPickerLayout().submenu or {}).entries or {}) do
    if entry.option and entry.option.controlType == "merge" then
        error("regular crossings should not show the merge bend point option", 2)
    end
end

local downstreamJunctionEditorData = {
    endpoints = {
        { id = "input_left", kind = "input", x = 0.18, y = 0.16, colors = { "blue" } },
        { id = "input_right", kind = "input", x = 0.82, y = 0.16, colors = { "orange" } },
        { id = "input_mid_left", kind = "input", x = 0.16, y = 0.66, colors = { "mint" } },
        { id = "output_left", kind = "output", x = 0.22, y = 0.9, colors = { "blue" } },
        { id = "output_right", kind = "output", x = 0.78, y = 0.9, colors = { "orange" } },
        { id = "output_mid", kind = "output", x = 0.84, y = 0.66, colors = { "mint" } },
    },
    routes = {
        {
            id = "route_blue",
            label = "route_blue",
            color = "blue",
            startEndpointId = "input_left",
            endEndpointId = "output_left",
            segmentRoadTypes = { "normal", "normal", "normal" },
            points = {
                { x = 0.18, y = 0.16 },
                { x = 0.5, y = 0.42, sharedPointId = 1 },
                { x = 0.5, y = 0.58 },
                { x = 0.22, y = 0.9 },
            },
        },
        {
            id = "route_orange",
            label = "route_orange",
            color = "orange",
            startEndpointId = "input_right",
            endEndpointId = "output_right",
            segmentRoadTypes = { "normal", "normal", "normal" },
            points = {
                { x = 0.82, y = 0.16 },
                { x = 0.5, y = 0.42, sharedPointId = 1 },
                { x = 0.5, y = 0.58 },
                { x = 0.78, y = 0.9 },
            },
        },
        {
            id = "route_mint",
            label = "route_mint",
            color = "mint",
            startEndpointId = "input_mid_left",
            endEndpointId = "output_mid",
            segmentRoadTypes = { "normal", "normal" },
            points = {
                { x = 0.16, y = 0.66 },
                { x = 0.5, y = 0.58 },
                { x = 0.84, y = 0.66 },
            },
        },
    },
    junctions = {},
    trains = {},
}

local downstreamEditor = mapEditor.new(1280, 720, nil)
downstreamEditor:loadEditorData(downstreamJunctionEditorData, "Merge Before Downstream Junction", nil, nil)
local downstreamMergeIntersection = findIntersectionByCompiledShape(downstreamEditor, 1, 1)
assertTrue(downstreamMergeIntersection ~= nil, "merged lane before a downstream junction should still expose the compiled 1-in/1-out shared-lane point")
assertTrue(
    #(downstreamMergeIntersection.outputEndpointIds or {}) > 1,
    "regression setup should keep multiple final output endpoints so eligibility depends on local merged-lane topology"
)
assertTrue(
    downstreamEditor:canIntersectionUseControlType(downstreamMergeIntersection, "merge"),
    "merge bend point eligibility should follow the compiled local shared-lane topology, not the final endpoint count"
)

print("map editor merge bend point tests passed")
