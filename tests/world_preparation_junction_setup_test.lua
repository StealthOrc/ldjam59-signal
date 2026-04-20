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

local function buildSimulation(controlType)
    return world.new(1200, 800, {
        junctions = {
            {
                id = controlType .. "_junction",
                label = controlType,
                control = {
                    type = controlType,
                    delay = 2.25,
                    target = 3,
                    holdTime = 1.6,
                    passCount = 2,
                    decayDelay = 0.55,
                    decayInterval = 0.2,
                },
                activeInputIndex = 1,
                activeOutputIndex = 1,
                inputs = {
                    {
                        id = controlType .. "_input_a",
                        color = { 0.33, 0.80, 0.98 },
                        colors = { "blue" },
                        inputPoints = {
                            { x = 0.20, y = 0.12 },
                            { x = 0.32, y = 0.28 },
                            { x = 0.50, y = 0.50 },
                        },
                    },
                    {
                        id = controlType .. "_input_b",
                        color = { 0.98, 0.70, 0.28 },
                        colors = { "orange" },
                        inputPoints = {
                            { x = 0.80, y = 0.12 },
                            { x = 0.68, y = 0.28 },
                            { x = 0.50, y = 0.50 },
                        },
                    },
                },
                outputs = {
                    {
                        id = controlType .. "_output_a",
                        color = { 0.40, 0.92, 0.76 },
                        colors = { "mint" },
                        outputPoints = {
                            { x = 0.50, y = 0.50 },
                            { x = 0.32, y = 0.72 },
                            { x = 0.20, y = 0.88 },
                        },
                    },
                    {
                        id = controlType .. "_output_b",
                        color = { 0.82, 0.56, 0.98 },
                        colors = { "violet" },
                        outputPoints = {
                            { x = 0.50, y = 0.50 },
                            { x = 0.68, y = 0.72 },
                            { x = 0.80, y = 0.88 },
                        },
                    },
                },
            },
        },
        trains = {},
    })
end

local function assertNoPreparationSideEffects(junction, controlType)
    local control = junction.control
    assertEqual(control.armed, false, controlType .. " prep click should not arm the control")
    assertEqual(control.remainingDelay, 0, controlType .. " prep click should not start a delay")
    assertEqual(control.remainingHold, 0, controlType .. " prep click should not start a spring hold")
    assertEqual(control.releaseTimer, 0, controlType .. " prep click should not start a spring release")
    assertEqual(control.remainingTrips, 0, controlType .. " prep click should not start trip counting")
    assertEqual(control.pendingResetTrainId, nil, controlType .. " prep click should not bind a trip reset train")
    assertEqual(control.pendingResetEdgeId, nil, controlType .. " prep click should not bind a trip reset edge")
    assertEqual(control.pumpCount, 0, controlType .. " prep click should not add pump charge")
    assertEqual(control.decayHold, 0, controlType .. " prep click should not start pump decay")
    assertEqual(control.decayTimer, 0, controlType .. " prep click should not start pump decay timing")
    assertEqual(control.iconPress, 0, controlType .. " prep click should not queue a control press animation")
    assertEqual(control.iconPressVelocity, 0, controlType .. " prep click should not queue a control press velocity")
    assertEqual(junction.selectorPress, 0, controlType .. " prep click should not queue an output selector animation")
    assertEqual(junction.selectorPressVelocity, 0, controlType .. " prep click should not queue an output selector velocity")

    if controlType == "relay" or controlType == "crossbar" or controlType == "trip" then
        assertEqual(control.flashTimer, 0, controlType .. " prep click should not trigger a flash")
    end
end

local controlTypes = { "direct", "delayed", "pump", "spring", "relay", "trip", "crossbar" }

for _, controlType in ipairs(controlTypes) do
    local simulation = buildSimulation(controlType)
    local junction = simulation.junctions[controlType .. "_junction"]
    local centerX = junction.mergePoint.x
    local centerY = junction.mergePoint.y

    local clickedCenter = simulation:handleClick(centerX, centerY, 1, true)
    assertEqual(clickedCenter, true, controlType .. " prep center click should be consumed")
    assertEqual(junction.activeInputIndex, 2, controlType .. " prep center click should cycle the selected input")

    if controlType == "relay" then
        assertEqual(junction.activeOutputIndex, 2, controlType .. " prep center click should keep the coupled output mapping in sync")
    elseif controlType == "crossbar" then
        assertEqual(junction.activeOutputIndex, 1, controlType .. " prep center click should keep the mirrored output mapping in sync")
    else
        assertEqual(junction.activeOutputIndex, 1, controlType .. " prep center click should not force a different output")
    end

    assertNoPreparationSideEffects(junction, controlType)

    local clickedSelector = simulation:handleClick(centerX, centerY + 48, 1, true)
    if controlType == "relay" or controlType == "crossbar" then
        assertEqual(clickedSelector, false, controlType .. " should not expose a separate output selector")
        if controlType == "relay" then
            assertEqual(junction.activeOutputIndex, 2, controlType .. " should still keep the coupled output after selector click")
        else
            assertEqual(junction.activeOutputIndex, 1, controlType .. " should still keep the mirrored output after selector click")
        end
    else
        assertEqual(clickedSelector, true, controlType .. " prep output selector click should be consumed")
        assertEqual(junction.activeOutputIndex, 2, controlType .. " prep output selector click should cycle the selected output")
    end

    assertNoPreparationSideEffects(junction, controlType)
end

print("world preparation junction setup tests passed")
