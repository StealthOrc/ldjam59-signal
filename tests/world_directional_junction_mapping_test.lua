package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}

local world = require("src.game.gameplay.railway_world")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %q but got %q", label, expected, actual), 2)
    end
end

local function buildSimulation(controlType)
    return world.new(1200, 800, {
        junctions = {
            {
                id = controlType .. "_directional",
                label = controlType,
                control = {
                    type = controlType,
                },
                activeInputIndex = 1,
                activeOutputIndex = 1,
                inputs = {
                    {
                        id = controlType .. "_input_top_left",
                        color = { 0.33, 0.80, 0.98 },
                        colors = { "blue" },
                        inputPoints = {
                            { x = 0.20, y = 0.10 },
                            { x = 0.32, y = 0.28 },
                            { x = 0.50, y = 0.50 },
                        },
                    },
                    {
                        id = controlType .. "_input_top_right",
                        color = { 0.98, 0.82, 0.34 },
                        colors = { "yellow" },
                        inputPoints = {
                            { x = 0.80, y = 0.10 },
                            { x = 0.68, y = 0.28 },
                            { x = 0.50, y = 0.50 },
                        },
                    },
                },
                outputs = {
                    {
                        id = controlType .. "_output_bottom_right",
                        color = { 0.98, 0.82, 0.34 },
                        colors = { "blue", "yellow" },
                        adoptInputColor = true,
                        outputPoints = {
                            { x = 0.50, y = 0.50 },
                            { x = 0.68, y = 0.72 },
                            { x = 0.80, y = 0.90 },
                        },
                    },
                    {
                        id = controlType .. "_output_bottom_left",
                        color = { 0.33, 0.80, 0.98 },
                        colors = { "blue", "yellow" },
                        adoptInputColor = true,
                        outputPoints = {
                            { x = 0.50, y = 0.50 },
                            { x = 0.32, y = 0.72 },
                            { x = 0.20, y = 0.90 },
                        },
                    },
                },
            },
        },
        trains = {},
    })
end

local function buildRankedLaneSimulation(controlType)
    return world.new(1200, 800, {
        junctions = {
            {
                id = controlType .. "_ranked",
                label = controlType,
                control = {
                    type = controlType,
                },
                activeInputIndex = 1,
                activeOutputIndex = 1,
                inputs = {
                    {
                        id = controlType .. "_input_yellow",
                        color = { 0.98, 0.82, 0.34 },
                        colors = { "yellow" },
                        inputPoints = {
                            { x = 0.28, y = 0.22 },
                            { x = 0.40, y = 0.55 },
                        },
                    },
                    {
                        id = controlType .. "_input_mint",
                        color = { 0.40, 0.92, 0.76 },
                        colors = { "mint" },
                        inputPoints = {
                            { x = 0.34, y = 0.22 },
                            { x = 0.40, y = 0.55 },
                        },
                    },
                    {
                        id = controlType .. "_input_rose",
                        color = { 0.98, 0.48, 0.62 },
                        colors = { "rose" },
                        inputPoints = {
                            { x = 0.50, y = 0.22 },
                            { x = 0.40, y = 0.55 },
                        },
                    },
                    {
                        id = controlType .. "_input_orange",
                        color = { 0.98, 0.70, 0.28 },
                        colors = { "orange" },
                        inputPoints = {
                            { x = 0.63, y = 0.22 },
                            { x = 0.40, y = 0.55 },
                        },
                    },
                },
                outputs = {
                    {
                        id = controlType .. "_output_orange",
                        color = { 0.98, 0.70, 0.28 },
                        colors = { "yellow", "mint", "rose", "orange" },
                        adoptInputColor = true,
                        outputPoints = {
                            { x = 0.40, y = 0.55 },
                            { x = 0.30, y = 0.78 },
                        },
                    },
                    {
                        id = controlType .. "_output_rose",
                        color = { 0.98, 0.48, 0.62 },
                        colors = { "yellow", "mint", "rose", "orange" },
                        adoptInputColor = true,
                        outputPoints = {
                            { x = 0.40, y = 0.55 },
                            { x = 0.37, y = 0.79 },
                        },
                    },
                    {
                        id = controlType .. "_output_mint",
                        color = { 0.40, 0.92, 0.76 },
                        colors = { "yellow", "mint", "rose", "orange" },
                        adoptInputColor = true,
                        outputPoints = {
                            { x = 0.40, y = 0.55 },
                            { x = 0.45, y = 0.79 },
                        },
                    },
                    {
                        id = controlType .. "_output_yellow",
                        color = { 0.98, 0.82, 0.34 },
                        colors = { "yellow", "mint", "rose", "orange" },
                        adoptInputColor = true,
                        outputPoints = {
                            { x = 0.40, y = 0.55 },
                            { x = 0.51, y = 0.80 },
                        },
                    },
                },
            },
        },
        trains = {},
    })
end

local function buildAsymmetricRankedSimulation(controlType)
    return world.new(1200, 800, {
        junctions = {
            {
                id = controlType .. "_asymmetric",
                label = controlType,
                control = {
                    type = controlType,
                },
                activeInputIndex = 1,
                activeOutputIndex = 1,
                inputs = {
                    {
                        id = controlType .. "_input_blue",
                        color = { 0.33, 0.80, 0.98 },
                        colors = { "blue" },
                        inputPoints = {
                            { x = 0.36, y = 0.21 },
                            { x = 0.46, y = 0.54 },
                        },
                    },
                    {
                        id = controlType .. "_input_mint",
                        color = { 0.40, 0.92, 0.76 },
                        colors = { "mint" },
                        inputPoints = {
                            { x = 0.40, y = 0.21 },
                            { x = 0.46, y = 0.54 },
                        },
                    },
                    {
                        id = controlType .. "_input_rose",
                        color = { 0.98, 0.48, 0.62 },
                        colors = { "rose" },
                        inputPoints = {
                            { x = 0.54, y = 0.18 },
                            { x = 0.46, y = 0.54 },
                        },
                    },
                    {
                        id = controlType .. "_input_yellow",
                        color = { 0.98, 0.82, 0.34 },
                        colors = { "yellow" },
                        inputPoints = {
                            { x = 0.60, y = 0.25 },
                            { x = 0.46, y = 0.54 },
                        },
                    },
                    {
                        id = controlType .. "_input_orange",
                        color = { 0.98, 0.70, 0.28 },
                        colors = { "orange" },
                        inputPoints = {
                            { x = 0.67, y = 0.70 },
                            { x = 0.46, y = 0.54 },
                        },
                    },
                },
                outputs = {
                    {
                        id = controlType .. "_output_orange",
                        color = { 0.98, 0.70, 0.28 },
                        colors = { "blue", "mint", "rose", "yellow", "orange" },
                        adoptInputColor = true,
                        outputPoints = {
                            { x = 0.46, y = 0.54 },
                            { x = 0.25, y = 0.37 },
                        },
                    },
                    {
                        id = controlType .. "_output_yellow",
                        color = { 0.98, 0.82, 0.34 },
                        colors = { "blue", "mint", "rose", "yellow", "orange" },
                        adoptInputColor = true,
                        outputPoints = {
                            { x = 0.46, y = 0.54 },
                            { x = 0.29, y = 0.90 },
                        },
                    },
                    {
                        id = controlType .. "_output_rose",
                        color = { 0.98, 0.48, 0.62 },
                        colors = { "blue", "mint", "rose", "yellow", "orange" },
                        adoptInputColor = true,
                        outputPoints = {
                            { x = 0.46, y = 0.54 },
                            { x = 0.39, y = 0.90 },
                        },
                    },
                    {
                        id = controlType .. "_output_mint",
                        color = { 0.40, 0.92, 0.76 },
                        colors = { "blue", "mint", "rose", "yellow", "orange" },
                        adoptInputColor = true,
                        outputPoints = {
                            { x = 0.46, y = 0.54 },
                            { x = 0.53, y = 0.93 },
                        },
                    },
                    {
                        id = controlType .. "_output_blue",
                        color = { 0.33, 0.80, 0.98 },
                        colors = { "blue", "mint", "rose", "yellow", "orange" },
                        adoptInputColor = true,
                        outputPoints = {
                            { x = 0.46, y = 0.54 },
                            { x = 0.59, y = 0.92 },
                        },
                    },
                },
            },
        },
        trains = {},
    })
end

local function buildAsymmetricCycleSimulation(controlType)
    return world.new(1200, 800, {
        junctions = {
            {
                id = controlType .. "_cycle",
                label = controlType,
                control = {
                    type = controlType,
                },
                activeInputIndex = 3,
                activeOutputIndex = 1,
                inputs = {
                    {
                        id = controlType .. "_input_blue",
                        color = { 0.33, 0.80, 0.98 },
                        colors = { "blue" },
                        inputPoints = {
                            { x = 0.28, y = 0.15 },
                            { x = 0.51, y = 0.52 },
                        },
                    },
                    {
                        id = controlType .. "_input_mint",
                        color = { 0.40, 0.92, 0.76 },
                        colors = { "mint" },
                        inputPoints = {
                            { x = 0.44, y = 0.14 },
                            { x = 0.51, y = 0.52 },
                        },
                    },
                    {
                        id = controlType .. "_input_rose",
                        color = { 0.98, 0.48, 0.62 },
                        colors = { "rose" },
                        inputPoints = {
                            { x = 0.62, y = 0.13 },
                            { x = 0.51, y = 0.52 },
                        },
                    },
                    {
                        id = controlType .. "_input_orange",
                        color = { 0.98, 0.70, 0.28 },
                        colors = { "orange" },
                        inputPoints = {
                            { x = 0.77, y = 0.73 },
                            { x = 0.51, y = 0.52 },
                        },
                    },
                    {
                        id = controlType .. "_input_yellow",
                        color = { 0.98, 0.82, 0.34 },
                        colors = { "yellow" },
                        inputPoints = {
                            { x = 0.78, y = 0.20 },
                            { x = 0.51, y = 0.52 },
                        },
                    },
                },
                outputs = {
                    {
                        id = controlType .. "_output_orange",
                        color = { 0.98, 0.70, 0.28 },
                        colors = { "blue", "mint", "rose", "orange", "yellow" },
                        adoptInputColor = true,
                        outputPoints = {
                            { x = 0.51, y = 0.52 },
                            { x = 0.27, y = 0.32 },
                        },
                    },
                    {
                        id = controlType .. "_output_yellow",
                        color = { 0.98, 0.82, 0.34 },
                        colors = { "blue", "mint", "rose", "orange", "yellow" },
                        adoptInputColor = true,
                        outputPoints = {
                            { x = 0.51, y = 0.52 },
                            { x = 0.21, y = 0.88 },
                        },
                    },
                    {
                        id = controlType .. "_output_blue",
                        color = { 0.33, 0.80, 0.98 },
                        colors = { "blue", "mint", "rose", "orange", "yellow" },
                        adoptInputColor = true,
                        outputPoints = {
                            { x = 0.51, y = 0.52 },
                            { x = 0.75, y = 0.89 },
                        },
                    },
                    {
                        id = controlType .. "_output_rose",
                        color = { 0.98, 0.48, 0.62 },
                        colors = { "blue", "mint", "rose", "orange", "yellow" },
                        adoptInputColor = true,
                        outputPoints = {
                            { x = 0.51, y = 0.52 },
                            { x = 0.40, y = 0.90 },
                        },
                    },
                    {
                        id = controlType .. "_output_mint",
                        color = { 0.40, 0.92, 0.76 },
                        colors = { "blue", "mint", "rose", "orange", "yellow" },
                        adoptInputColor = true,
                        outputPoints = {
                            { x = 0.51, y = 0.52 },
                            { x = 0.59, y = 0.92 },
                        },
                    },
                },
            },
        },
        trains = {},
    })
end

local relaySimulation = buildSimulation("relay")
local relayJunction = relaySimulation.junctions.relay_directional

assertEqual(
    relayJunction.activeOutputIndex,
    2,
    "relay should reflect the top-left input across the y axis even when outputs are shuffled"
)

local relayReachableFirst = relaySimulation:getReachableOutputEdgesForInput(relayJunction, relayJunction.inputs[1].id)
assertEqual(relayReachableFirst[1].id, relayJunction.outputs[2].id, "relay reachable output should stay on the same x side for the top-left input")

relayJunction.activeInputIndex = 2
relaySimulation:syncRelayOutput(relayJunction)
assertEqual(relayJunction.activeOutputIndex, 1, "relay should reflect the top-right input onto the bottom-right output")

local relayReachableSecond = relaySimulation:getReachableOutputEdgesForInput(relayJunction, relayJunction.inputs[2].id)
assertEqual(relayReachableSecond[1].id, relayJunction.outputs[1].id, "relay reachable output should stay on the same x side for the top-right input")

local crossbarSimulation = buildSimulation("crossbar")
local crossbarJunction = crossbarSimulation.junctions.crossbar_directional

assertEqual(
    crossbarJunction.activeOutputIndex,
    1,
    "crossbar should choose the fully opposite diagonal for the top-left input even when outputs are shuffled"
)

local crossbarReachableFirst = crossbarSimulation:getReachableOutputEdgesForInput(crossbarJunction, crossbarJunction.inputs[1].id)
assertEqual(crossbarReachableFirst[1].id, crossbarJunction.outputs[1].id, "crossbar reachable output should be diagonally opposite for the top-left input")

crossbarJunction.activeInputIndex = 2
crossbarSimulation:syncCrossbarOutput(crossbarJunction)
assertEqual(crossbarJunction.activeOutputIndex, 2, "crossbar should choose the fully opposite diagonal for the top-right input")

local crossbarReachableSecond = crossbarSimulation:getReachableOutputEdgesForInput(crossbarJunction, crossbarJunction.inputs[2].id)
assertEqual(crossbarReachableSecond[1].id, crossbarJunction.outputs[2].id, "crossbar reachable output should be diagonally opposite for the top-right input")

local rankedRelaySimulation = buildRankedLaneSimulation("relay")
local rankedRelayJunction = rankedRelaySimulation.junctions.relay_ranked

assertEqual(rankedRelaySimulation:getReachableOutputEdgesForInput(rankedRelayJunction, rankedRelayJunction.inputs[1].id)[1].id, rankedRelayJunction.outputs[1].id, "relay should keep the first horizontal lane rank")
assertEqual(rankedRelaySimulation:getReachableOutputEdgesForInput(rankedRelayJunction, rankedRelayJunction.inputs[2].id)[1].id, rankedRelayJunction.outputs[2].id, "relay should keep the second horizontal lane rank")
assertEqual(rankedRelaySimulation:getReachableOutputEdgesForInput(rankedRelayJunction, rankedRelayJunction.inputs[3].id)[1].id, rankedRelayJunction.outputs[3].id, "relay should keep the third horizontal lane rank")
assertEqual(rankedRelaySimulation:getReachableOutputEdgesForInput(rankedRelayJunction, rankedRelayJunction.inputs[4].id)[1].id, rankedRelayJunction.outputs[4].id, "relay should keep the fourth horizontal lane rank")

local rankedCrossbarSimulation = buildRankedLaneSimulation("crossbar")
local rankedCrossbarJunction = rankedCrossbarSimulation.junctions.crossbar_ranked

assertEqual(rankedCrossbarSimulation:getReachableOutputEdgesForInput(rankedCrossbarJunction, rankedCrossbarJunction.inputs[1].id)[1].id, rankedCrossbarJunction.outputs[4].id, "crossbar should reverse the horizontal lane rank for the first input")
assertEqual(rankedCrossbarSimulation:getReachableOutputEdgesForInput(rankedCrossbarJunction, rankedCrossbarJunction.inputs[2].id)[1].id, rankedCrossbarJunction.outputs[3].id, "crossbar should reverse the horizontal lane rank for the second input")
assertEqual(rankedCrossbarSimulation:getReachableOutputEdgesForInput(rankedCrossbarJunction, rankedCrossbarJunction.inputs[3].id)[1].id, rankedCrossbarJunction.outputs[2].id, "crossbar should reverse the horizontal lane rank for the third input")
assertEqual(rankedCrossbarSimulation:getReachableOutputEdgesForInput(rankedCrossbarJunction, rankedCrossbarJunction.inputs[4].id)[1].id, rankedCrossbarJunction.outputs[1].id, "crossbar should reverse the horizontal lane rank for the fourth input")

local asymmetricRelaySimulation = buildAsymmetricRankedSimulation("relay")
local asymmetricRelayJunction = asymmetricRelaySimulation.junctions.relay_asymmetric

assertEqual(asymmetricRelaySimulation:getReachableOutputEdgesForInput(asymmetricRelayJunction, asymmetricRelayJunction.inputs[1].id)[1].id, asymmetricRelayJunction.outputs[1].id, "relay should keep the first global horizontal rank")
assertEqual(asymmetricRelaySimulation:getReachableOutputEdgesForInput(asymmetricRelayJunction, asymmetricRelayJunction.inputs[2].id)[1].id, asymmetricRelayJunction.outputs[2].id, "relay should keep the second global horizontal rank")
assertEqual(asymmetricRelaySimulation:getReachableOutputEdgesForInput(asymmetricRelayJunction, asymmetricRelayJunction.inputs[3].id)[1].id, asymmetricRelayJunction.outputs[3].id, "relay should keep the third global horizontal rank")
assertEqual(asymmetricRelaySimulation:getReachableOutputEdgesForInput(asymmetricRelayJunction, asymmetricRelayJunction.inputs[4].id)[1].id, asymmetricRelayJunction.outputs[4].id, "relay should keep the fourth global horizontal rank")
assertEqual(asymmetricRelaySimulation:getReachableOutputEdgesForInput(asymmetricRelayJunction, asymmetricRelayJunction.inputs[5].id)[1].id, asymmetricRelayJunction.outputs[5].id, "relay should rerank the fifth added line instead of keeping a one-item side bucket")

local asymmetricCrossbarSimulation = buildAsymmetricRankedSimulation("crossbar")
local asymmetricCrossbarJunction = asymmetricCrossbarSimulation.junctions.crossbar_asymmetric

assertEqual(asymmetricCrossbarSimulation:getReachableOutputEdgesForInput(asymmetricCrossbarJunction, asymmetricCrossbarJunction.inputs[1].id)[1].id, asymmetricCrossbarJunction.outputs[5].id, "crossbar should reverse the global horizontal rank for the first asymmetric input")
assertEqual(asymmetricCrossbarSimulation:getReachableOutputEdgesForInput(asymmetricCrossbarJunction, asymmetricCrossbarJunction.inputs[2].id)[1].id, asymmetricCrossbarJunction.outputs[4].id, "crossbar should reverse the global horizontal rank for the second asymmetric input")
assertEqual(asymmetricCrossbarSimulation:getReachableOutputEdgesForInput(asymmetricCrossbarJunction, asymmetricCrossbarJunction.inputs[3].id)[1].id, asymmetricCrossbarJunction.outputs[3].id, "crossbar should reverse the global horizontal rank for the third asymmetric input")
assertEqual(asymmetricCrossbarSimulation:getReachableOutputEdgesForInput(asymmetricCrossbarJunction, asymmetricCrossbarJunction.inputs[4].id)[1].id, asymmetricCrossbarJunction.outputs[2].id, "crossbar should reverse the global horizontal rank for the fourth asymmetric input")
assertEqual(asymmetricCrossbarSimulation:getReachableOutputEdgesForInput(asymmetricCrossbarJunction, asymmetricCrossbarJunction.inputs[5].id)[1].id, asymmetricCrossbarJunction.outputs[1].id, "crossbar should reverse the global horizontal rank for the fifth asymmetric input")

local relayCycleSimulation = buildAsymmetricCycleSimulation("relay")
local relayCycleJunction = relayCycleSimulation.junctions.relay_cycle
relayCycleSimulation:cycleInput(relayCycleJunction)
assertEqual(relayCycleJunction.activeInputIndex, 5, "relay should cycle from rose to yellow before the bottom-right orange lane")
relayCycleSimulation:cycleInput(relayCycleJunction)
assertEqual(relayCycleJunction.activeInputIndex, 4, "relay should cycle from yellow to orange after exhausting the top-side lanes")

local crossbarCycleSimulation = buildAsymmetricCycleSimulation("crossbar")
local crossbarCycleJunction = crossbarCycleSimulation.junctions.crossbar_cycle
crossbarCycleSimulation:cycleInput(crossbarCycleJunction)
assertEqual(crossbarCycleJunction.activeInputIndex, 5, "crossbar should cycle from rose to yellow before the bottom-right orange lane")
crossbarCycleSimulation:cycleInput(crossbarCycleJunction)
assertEqual(crossbarCycleJunction.activeInputIndex, 4, "crossbar should cycle from yellow to orange after exhausting the top-side lanes")

print("world directional junction mapping tests passed")
