package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}
love.graphics = love.graphics or {}
love.filesystem = love.filesystem or {}

love.filesystem.getInfo = function()
    return false
end

local world = require("src.game.gameplay.world")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %s but got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local simulation = world.new(100, 100, {
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
        { id = "train_1", junctionId = "main", inputIndex = 1, goalColor = "blue" },
        { id = "train_2", junctionId = "main", inputIndex = 1, goalColor = "blue" },
        { id = "train_3", junctionId = "main", inputIndex = 1, goalColor = "blue" },
        { id = "train_4", junctionId = "main", inputIndex = 1, goalColor = "blue" },
        { id = "train_5", junctionId = "main", inputIndex = 1, goalColor = "blue" },
    },
})

simulation.elapsedTime = 40

for index, train in ipairs(simulation.trains) do
    train.completed = true
    train.deliveredCorrectly = true
    train.deliveredLate = index >= 4
    train.failedWrongDestination = false
    train.actualDistance = train.minimumDistance or 0
end

local summary = simulation:getRunSummary()

assertEqual(summary.totalTrainCount, 5, "run summary keeps the train count")
assertEqual(summary.maxPossibleScore, 50, "run summary exposes the score cap")
assertEqual(summary.onTimePointCap, 50, "run summary exposes the on-time score cap")
assertEqual(summary.correctOnTimeCount, 3, "run summary counts on-time clears")
assertEqual(summary.correctLateCount, 2, "run summary counts late clears")
assertEqual(summary.scoreBreakdown.onTimeClears, 30, "on-time score reflects three trains")
assertEqual(summary.scoreBreakdown.lateClears, 10, "late score reflects two trains")
assertEqual(summary.onTimePointLossBreakdown.lateClears, 10, "late clears report their on-time point loss")
assertEqual(summary.onTimePointLossBreakdown.wrongDestinations, 0, "wrong destinations report no loss when none occurred")
assertEqual(summary.onTimePointLossBreakdown.unfinished, 0, "unfinished trains report no loss when all trains completed")
assertEqual(summary.scoreBreakdown.timePenalty, 10, "time penalty remains part of the final score")
assertEqual(summary.finalScore, 30, "final score can be compared against the score cap")

print("world run summary score cap tests passed")
