package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}
love.graphics = love.graphics or {}
love.filesystem = love.filesystem or {}

love.filesystem.getInfo = function()
    return false
end

local world = require("src.game.gameplay.world")

local function assertTrue(value, label)
    if not value then
        error(label, 2)
    end
end

local function buildSimulation()
    return world.new(100, 100, {
        junctions = {
            {
                id = "main",
                label = "Main",
                control = { type = "direct" },
                activeInputIndex = 1,
                inputs = {
                    {
                        id = "blue_in",
                        color = { 0.33, 0.80, 0.98 },
                        colors = { "blue" },
                        inputPoints = {
                            { x = 0.10, y = 0.50 },
                            { x = 0.50, y = 0.50 },
                        },
                    },
                },
                outputs = {
                    {
                        id = "blue_out",
                        color = { 0.33, 0.80, 0.98 },
                        colors = { "blue" },
                        outputPoints = {
                            { x = 0.50, y = 0.50 },
                            { x = 0.90, y = 0.50 },
                        },
                    },
                },
            },
        },
        trains = {
            {
                id = "blue_train",
                junctionId = "main",
                inputIndex = 1,
                goalColor = "blue",
                wagonCount = 2,
            },
        },
    })
end

local fadeSimulation = buildSimulation()
local fadeTrain = fadeSimulation.trains[1]
local fadeInput = fadeSimulation.junctions.main.inputs[1]
local fadeExit = fadeSimulation.junctions.main.outputs[1]
local occupiedLength = fadeInput.path.length + fadeExit.path.length

fadeTrain.spawned = true
fadeTrain.edgeId = fadeExit.id
fadeTrain.occupiedEdgeIds = { fadeInput.id, fadeExit.id }
fadeTrain.headDistance = occupiedLength - fadeSimulation.carriageLength * 0.5 + 4

local carriages = fadeSimulation:getTrainCarriagePositions(fadeTrain)
assertTrue(#carriages == 2, "train should still render both wagons while only the lead wagon is phasing out")
assertTrue(carriages[1].collidable == false, "lead wagon should lose collision as soon as it reaches the exit")
assertTrue(carriages[1].alpha > 0 and carriages[1].alpha < 1, "lead wagon should start fading immediately after touching the exit")
assertTrue(carriages[2].collidable == true, "following wagon should remain collidable until it reaches the exit")
assertTrue(carriages[2].alpha == 1, "following wagon should stay fully opaque before it reaches the exit")

local completionSimulation = buildSimulation()
local completionTrain = completionSimulation.trains[1]
local completionExit = completionSimulation.junctions.main.outputs[1]
local clearanceDistance = ((completionTrain.wagonCount or completionSimulation.carriageCount) - 1)
    * (completionSimulation.carriageLength + completionSimulation.carriageGap)
    + completionSimulation.carriageLength * 0.5

completionTrain.spawned = true
completionTrain.edgeId = completionExit.id
completionTrain.occupiedEdgeIds = { completionExit.id }
completionTrain.currentSpeed = 0

completionTrain.headDistance = completionExit.path.length + clearanceDistance - 0.5
completionSimulation:updateTrain(completionTrain, 0)
assertTrue(completionTrain.completed == false, "train should not complete until the rear of the last wagon clears the exit")

completionTrain.headDistance = completionExit.path.length + clearanceDistance + 0.5
completionSimulation:updateTrain(completionTrain, 0)
assertTrue(completionTrain.completed == true, "train should complete once the rear of the last wagon clears the exit")

print("world exit phase tests passed")
