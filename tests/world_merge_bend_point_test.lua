package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}

local world = require("src.game.world")

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

local function assertNear(actual, expected, epsilon, label)
    if math.abs(actual - expected) > epsilon then
        error(string.format("%s expected %.4f but got %.4f", label, expected, actual), 2)
    end
end

local simulation = world.new(1200, 800, {
    junctions = {
        {
            id = "merge_junction",
            label = "merge",
            control = {
                type = "merge",
            },
            activeInputIndex = 1,
            activeOutputIndex = 1,
            inputs = {
                {
                    id = "merge_input_a",
                    color = { 0.33, 0.80, 0.98 },
                    colors = { "blue" },
                    inputPoints = {
                        { x = 0.22, y = 0.16 },
                        { x = 0.34, y = 0.3 },
                        { x = 0.5, y = 0.5 },
                    },
                },
                {
                    id = "merge_input_b",
                    color = { 0.98, 0.70, 0.28 },
                    colors = { "orange" },
                    inputPoints = {
                        { x = 0.78, y = 0.16 },
                        { x = 0.66, y = 0.3 },
                        { x = 0.5, y = 0.5 },
                    },
                },
            },
            outputs = {
                {
                    id = "merge_output_a",
                    color = { 0.4, 0.92, 0.76 },
                    colors = { "blue", "orange" },
                    outputPoints = {
                        { x = 0.5, y = 0.5 },
                        { x = 0.5, y = 0.72 },
                        { x = 0.5, y = 0.9 },
                    },
                },
            },
        },
    },
    trains = {
        {
            id = "merge_train",
            junctionId = "merge_junction",
            inputIndex = 2,
            lineColor = "orange",
            trainColor = "orange",
            spawnTime = 0,
            progress = 0,
        },
    },
})

local junction = simulation.junctions.merge_junction
assertTrue(junction ~= nil, "simulation should build the merge bend point junction")
assertEqual(simulation:handleClick(junction.mergePoint.x, junction.mergePoint.y, 1, true), false, "merge bend point should ignore preparation clicks")
assertEqual(simulation:handleClick(junction.mergePoint.x, junction.mergePoint.y, 1, false), false, "merge bend point should ignore play clicks")
assertEqual(simulation:isCrossingHit(junction, junction.mergePoint.x, junction.mergePoint.y), false, "merge bend point should not register as a clickable junction")

local firstInputRendered = simulation:getRenderedTrackPoints(junction.inputs[1])
local firstOutputRendered = simulation:getRenderedTrackPoints(junction.outputs[1])
assertNear(firstInputRendered[#firstInputRendered].x, junction.mergePoint.x, 0.001, "merge bend point should not trim input tracks away from the merge")
assertNear(firstInputRendered[#firstInputRendered].y, junction.mergePoint.y, 0.001, "merge bend point should keep input tracks touching the merge")
assertNear(firstOutputRendered[1].x, junction.mergePoint.x, 0.001, "merge bend point should not trim output tracks away from the merge")
assertNear(firstOutputRendered[1].y, junction.mergePoint.y, 0.001, "merge bend point should keep output tracks touching the merge")

local train = simulation.trains[1]
assertEqual(train.edgeId, "merge_junction_input_2", "train should start on the second input lane")
assertEqual(simulation:getDesiredLeadDistance(train), nil, "merge bend point should not force trains to stop for an active input")

local advancedToOutput = false
for _ = 1, 240 do
    simulation:updateTrain(train, 1 / 60)
    if train.edgeId == "merge_junction_output_1" or train.completed then
        advancedToOutput = true
        break
    end
end

assertTrue(advancedToOutput, "train should automatically pass through the merge bend point onto the shared output lane")

print("world merge bend point tests passed")
