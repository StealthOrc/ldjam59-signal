package.path = "./?.lua;./?/init.lua;" .. package.path

local mapPresentation = require("src.game.app.map_presentation")

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected %s, got %s)", message, tostring(expected), tostring(actual)), 2)
    end
end

local function assertNear(actual, expected, epsilon, message)
    if math.abs((actual or 0) - (expected or 0)) > (epsilon or 0.0001) then
        error(string.format("%s (expected %.4f, got %.4f)", message, expected, actual), 2)
    end
end

assertEqual(
    mapPresentation.resolveSubtitle({ mapKind = "campaign" }, { playerDisplayName = "Signal" }),
    "Campaign Map",
    "campaign maps show their map type"
)

assertEqual(
    mapPresentation.resolveSubtitle({ mapKind = "tutorial" }, { playerDisplayName = "Signal" }),
    "Guidebook Map",
    "tutorial maps show the guidebook label"
)

assertEqual(
    mapPresentation.resolveSubtitle({ mapKind = "user" }, { playerDisplayName = "Signal" }),
    "by Signal",
    "local user maps use the current player name"
)

assertEqual(
    mapPresentation.resolveSubtitle({
        mapKind = "user",
        remoteSource = { creatorDisplayName = "Test Player" },
    }, { playerDisplayName = "Signal" }),
    "by Test Player",
    "downloaded or imported user maps prefer the recorded creator name"
)

local fakeWorld = {
    edges = {
        start_a = {
            id = "start_a",
            sourceType = "start",
            targetType = "junction",
            targetId = "junction_1",
            path = {
                length = 100,
                points = {
                    { x = 0, y = 0 },
                    { x = 100, y = 0 },
                },
            },
        },
        exit_a = {
            id = "exit_a",
            sourceType = "junction",
            sourceId = "junction_1",
            targetType = "exit",
            path = {
                length = 80,
                points = {
                    { x = 100, y = 0 },
                    { x = 180, y = 0 },
                },
            },
        },
        exit_b = {
            id = "exit_b",
            sourceType = "junction",
            sourceId = "junction_1",
            targetType = "exit",
            path = {
                length = 90,
                points = {
                    { x = 100, y = 0 },
                    { x = 100, y = 90 },
                },
            },
        },
    },
    getRenderedTrackWindow = function(_, edge)
        return 0, edge.path.length
    end,
    getLevel = function()
        return { title = "Fork In The Line" }
    end,
    getInputEdgeGroups = function()
        return {
            { edge = { id = "start_a" } },
        }
    end,
    getOutputBadgeGroups = function()
        return {
            { edge = { id = "exit_a" } },
            { edge = { id = "exit_b" } },
        }
    end,
}

local state = mapPresentation.buildState(fakeWorld, { mapKind = "campaign" }, { playerDisplayName = "Signal" })
local junctionSchedule = state.junctionScheduleById.junction_1
assertEqual(state.title, "Fork In The Line", "map presentation uses the level title when present")
assertNear(
    state.graphCompleteTime,
    3.5,
    0.0001,
    "graph reveal duration is normalized to the fixed map presentation length"
)
assertNear(
    state.edgeScheduleById.exit_a.startTime,
    junctionSchedule.ringEndTime,
    0.0001,
    "the first outgoing edge waits until the junction ring reveal finishes"
)
assertNear(
    state.edgeScheduleById.exit_b.startTime,
    junctionSchedule.ringEndTime,
    0.0001,
    "parallel outgoing edges start together once the junction ring finishes"
)
assertNear(
    state.uiReveal.startTime,
    state.graphCompleteTime + 0.08,
    0.0001,
    "ui reveal begins shortly after the track presentation finishes"
)
assertNear(
    state.trackStateBlend.startTime,
    state.graphCompleteTime,
    0.0001,
    "track state blending starts when the graph reveal finishes"
)
assertNear(
    state.signalPop.startTime,
    state.graphCompleteTime,
    0.0001,
    "signal pop-in starts when the graph reveal finishes"
)
assertEqual(
    state.finishTime >= state.signalPop.endTime,
    true,
    "presentation remains alive until the signal pop finishes"
)

local skipState = mapPresentation.buildState(fakeWorld, { mapKind = "campaign" }, { playerDisplayName = "Signal" })
skipState.elapsed = 1.1
mapPresentation.skip(skipState)
assertEqual(skipState.titleOnly, true, "skipping the intro keeps the title overlay alive")
assertEqual(mapPresentation.isBlocking(skipState), false, "title-only mode no longer blocks gameplay")

local finishedEarly = mapPresentation.update(skipState, 1.0)
assertEqual(finishedEarly, false, "title-only mode remains active until the title animation completes")

local finishedLate = mapPresentation.update(skipState, 5.0)
assertEqual(finishedLate, true, "title-only mode finishes once the title animation ends")

local mergeWaitWorld = {
    edges = {
        a_to_merge = {
            id = "a_to_merge",
            sourceType = "start",
            targetType = "junction",
            targetId = "merge_junction",
            path = {
                length = 120,
                points = {
                    { x = 0, y = 0 },
                    { x = 120, y = 0 },
                },
            },
        },
        merge_to_second = {
            id = "merge_to_second",
            sourceType = "junction",
            sourceId = "merge_junction",
            targetType = "junction",
            targetId = "second_junction",
            path = {
                length = 90,
                points = {
                    { x = 120, y = 0 },
                    { x = 210, y = 0 },
                },
            },
        },
        b_to_second = {
            id = "b_to_second",
            sourceType = "start",
            targetType = "junction",
            targetId = "second_junction",
            path = {
                length = 70,
                points = {
                    { x = 0, y = 80 },
                    { x = 70, y = 80 },
                },
            },
        },
        second_to_exit = {
            id = "second_to_exit",
            sourceType = "junction",
            sourceId = "second_junction",
            targetType = "exit",
            path = {
                length = 70,
                points = {
                    { x = 220, y = 40 },
                    { x = 290, y = 40 },
                },
            },
        },
    },
    getRenderedTrackWindow = function(_, edge)
        return 0, edge.path.length
    end,
    getLevel = function()
        return { title = "Merge Wait" }
    end,
    getInputEdgeGroups = function()
        return {
            { edge = { id = "a_to_merge" } },
            { edge = { id = "b_to_second" } },
        }
    end,
    getOutputBadgeGroups = function()
        return {
            { edge = { id = "second_to_exit" } },
        }
    end,
}

local mergeWaitState = mapPresentation.buildState(mergeWaitWorld, { mapKind = "campaign" }, { playerDisplayName = "Signal" })
local secondJunctionSchedule = mergeWaitState.junctionScheduleById.second_junction
assertEqual(secondJunctionSchedule ~= nil, true, "downstream junction gets a reveal schedule")
assertNear(
    secondJunctionSchedule.arrivalTime,
    math.max(
        mergeWaitState.edgeScheduleById.merge_to_second.endTime,
        mergeWaitState.edgeScheduleById.b_to_second.endTime
    ),
    0.0001,
    "a junction waits for all incoming edges to finish before its reveal begins"
)
assertNear(
    mergeWaitState.edgeScheduleById.merge_to_second.endTime,
    secondJunctionSchedule.arrivalTime,
    0.0001,
    "the longer path into the junction preserves the target arrival time"
)
assertNear(
    mergeWaitState.edgeScheduleById.b_to_second.endTime,
    secondJunctionSchedule.arrivalTime,
    0.0001,
    "the shorter direct path is stretched so it finishes with the longer incoming path"
)
assertNear(
    mergeWaitState.edgeScheduleById.second_to_exit.startTime,
    secondJunctionSchedule.ringEndTime,
    0.0001,
    "outgoing edges wait for the fully resolved downstream junction ring"
)

print("map presentation tests passed")
