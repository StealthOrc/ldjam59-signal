package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}

local world = require("src.game.world")

local function assertNear(actual, expected, tolerance, label)
    if math.abs(actual - expected) > tolerance then
        error(string.format("%s expected %.6f but got %.6f", label, expected, actual), 2)
    end
end

local simulation = world.new(100, 100, {
    junctions = {
        {
            id = "crossbar_test",
            label = "Crossbar Test",
            control = { type = "crossbar" },
            activeInputIndex = 1,
            inputs = {
                {
                    id = "input_blue",
                    color = { 0.33, 0.80, 0.98 },
                    colors = { "blue" },
                    inputPoints = {
                        { x = 0.10, y = 0.00 },
                        { x = 0.10, y = 0.30 },
                        { x = 0.50, y = 0.50 },
                    },
                },
                {
                    id = "input_mint",
                    color = { 0.40, 0.92, 0.76 },
                    colors = { "mint" },
                    inputPoints = {
                        { x = 0.30, y = 0.00 },
                        { x = 0.30, y = 0.30 },
                        { x = 0.50, y = 0.50 },
                    },
                },
                {
                    id = "input_yellow",
                    color = { 0.98, 0.82, 0.34 },
                    colors = { "yellow" },
                    inputPoints = {
                        { x = 0.50, y = 0.00 },
                        { x = 0.50, y = 0.30 },
                        { x = 0.50, y = 0.50 },
                    },
                },
            },
            outputs = {
                {
                    id = "blue_short_exit",
                    color = { 0.33, 0.80, 0.98 },
                    colors = { "blue" },
                    outputPoints = {
                        { x = 0.50, y = 0.50 },
                        { x = 0.60, y = 0.50 },
                    },
                },
                {
                    id = "blue_mid_exit",
                    color = { 0.33, 0.80, 0.98 },
                    colors = { "blue" },
                    outputPoints = {
                        { x = 0.50, y = 0.50 },
                        { x = 0.70, y = 0.50 },
                    },
                },
                {
                    id = "blue_long_exit",
                    color = { 0.33, 0.80, 0.98 },
                    colors = { "blue" },
                    outputPoints = {
                        { x = 0.50, y = 0.50 },
                        { x = 0.80, y = 0.50 },
                    },
                },
            },
        },
    },
    trains = {
        {
            id = "blue_train",
            junctionId = "crossbar_test",
            inputIndex = 1,
            goalColor = "blue",
        },
    },
})

local train = simulation.trains[1]
local startEdge = simulation.edges[train.startEdgeId]
local reachableCrossbarExit = simulation.junctions.crossbar_test.outputs[3]
local unreachableShorterExit = simulation.junctions.crossbar_test.outputs[1]
local expectedMinimumDistance = startEdge.path.length + reachableCrossbarExit.path.length

assertNear(
    train.minimumDistance,
    expectedMinimumDistance,
    0.0001,
    "crossbar minimum distance uses the mirrored reachable output"
)

if math.abs(train.minimumDistance - (startEdge.path.length + unreachableShorterExit.path.length)) <= 0.0001 then
    error("crossbar minimum distance incorrectly used the globally shortest unreachable exit", 2)
end

print("world minimum distance crossbar tests passed")
