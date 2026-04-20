return {
    editor = {
        endpoints = {
            {
                colors = {
                    "blue",
                },
                id = "input_endpoint_1",
                kind = "input",
                x = 0.33333333333333,
                y = 0.012962962962963,
            },
            {
                colors = {
                    "blue",
                    "yellow",
                },
                id = "output_endpoint_2",
                kind = "output",
                x = 0.46666666666667,
                y = 0.98703703703704,
            },
            {
                colors = {
                    "yellow",
                },
                id = "input_endpoint_3",
                kind = "input",
                x = 0.6,
                y = 0.012962962962963,
            },
        },
        junctions = {
            {
                activeInputIndex = 1,
                activeOutputIndex = 1,
                control = "direct",
                id = "junction_route_1_route_2_1",
                inputEndpointIds = {
                    "input_endpoint_1",
                    "input_endpoint_3",
                },
                outputEndpointIds = {
                    "output_endpoint_2",
                },
                passCount = 1,
                routes = {
                    "route_1",
                    "route_2",
                },
                x = 0.46625936484184,
                y = 0.50547247432834,
            },
        },
        mapSize = {
            h = 1080,
            w = 1920,
        },
        routes = {
            {
                color = "blue",
                endEndpointId = "output_endpoint_2",
                id = "route_1",
                label = "route_1",
                points = {
                    {
                        x = 0.33333333333333,
                        y = 0.012962962962963,
                    },
                    {
                        sharedPointId = 1,
                        x = 0.46625936484184,
                        y = 0.50547247432834,
                    },
                    {
                        x = 0.46666666666667,
                        y = 0.98703703703704,
                    },
                },
                segmentRoadTypes = {
                    "normal",
                    "normal",
                },
                startEndpointId = "input_endpoint_1",
            },
            {
                color = "yellow",
                endEndpointId = "output_endpoint_2",
                id = "route_2",
                label = "route_2",
                points = {
                    {
                        x = 0.6,
                        y = 0.012962962962963,
                    },
                    {
                        sharedPointId = 1,
                        x = 0.46625936484184,
                        y = 0.50547247432834,
                    },
                    {
                        x = 0.46666666666667,
                        y = 0.98703703703704,
                    },
                },
                segmentRoadTypes = {
                    "normal",
                    "normal",
                },
                startEndpointId = "input_endpoint_3",
            },
        },
        trains = {
            {
                id = "route_1_segment_1_train_blue_1",
                lineColor = "blue",
                spawnTime = 0.5,
                trainColor = "blue",
                wagonCount = 4,
            },
            {
                id = "route_2_segment_1_train_yellow_1",
                lineColor = "yellow",
                spawnTime = 0.5,
                trainColor = "yellow",
                wagonCount = 4,
            },
        },
    },
    level = {
        description = "Custom map loaded from the editor.",
        edges = {
            {
                adoptInputColor = false,
                color = {
                    0.33,
                    0.8,
                    0.98,
                },
                colors = {
                    "blue",
                },
                darkColor = {
                    0.1386,
                    0.336,
                    0.4116,
                },
                id = "route_1_segment_1",
                inputColors = {
                    "blue",
                },
                label = "Blue route Segment 1",
                points = {
                    {
                        x = 0.33333333333333,
                        y = 0.012962962962963,
                    },
                    {
                        x = 0.46625936484184,
                        y = 0.50547247432834,
                    },
                },
                roadType = "normal",
                routeId = "route_1",
                sourceId = "input_endpoint_1",
                sourceType = "start",
                speedScale = 1,
                styleSections = {
                    {
                        endRatio = 1,
                        roadType = "normal",
                        speedScale = 1,
                        startRatio = 0,
                    },
                },
                targetId = "junction_route_1_route_2_1",
                targetType = "junction",
            },
            {
                adoptInputColor = false,
                color = {
                    0.33,
                    0.8,
                    0.98,
                },
                colors = {
                    "blue",
                    "yellow",
                },
                darkColor = {
                    0.1386,
                    0.336,
                    0.4116,
                },
                id = "route_1_segment_2",
                inputColors = {
                },
                label = "Blue route Segment 2",
                points = {
                    {
                        x = 0.46625936484184,
                        y = 0.50547247432834,
                    },
                    {
                        x = 0.46666666666667,
                        y = 0.98703703703704,
                    },
                },
                roadType = "normal",
                routeId = "route_1",
                sourceId = "junction_route_1_route_2_1",
                sourceType = "junction",
                speedScale = 1,
                styleSections = {
                    {
                        endRatio = 1,
                        roadType = "normal",
                        speedScale = 1,
                        startRatio = 0,
                    },
                },
                targetId = "output_endpoint_2",
                targetType = "exit",
            },
            {
                adoptInputColor = false,
                color = {
                    0.98,
                    0.82,
                    0.34,
                },
                colors = {
                    "yellow",
                },
                darkColor = {
                    0.4116,
                    0.3444,
                    0.1428,
                },
                id = "route_2_segment_1",
                inputColors = {
                    "yellow",
                },
                label = "Yellow route Segment 1",
                points = {
                    {
                        x = 0.6,
                        y = 0.012962962962963,
                    },
                    {
                        x = 0.46625936484184,
                        y = 0.50547247432834,
                    },
                },
                roadType = "normal",
                routeId = "route_2",
                sourceId = "input_endpoint_3",
                sourceType = "start",
                speedScale = 1,
                styleSections = {
                    {
                        endRatio = 1,
                        roadType = "normal",
                        speedScale = 1,
                        startRatio = 0,
                    },
                },
                targetId = "junction_route_1_route_2_1",
                targetType = "junction",
            },
        },
        footer = "Sequence trains from the editor pane and clear every goal on time.",
        hint = "Click the junction center to switch inputs. Use the bottom selector to switch outputs.",
        id = "3206710d-793f-474e-957a-fdb721926f52",
        junctions = {
            {
                activeInputIndex = 1,
                activeOutputIndex = 1,
                control = {
                    label = "Direct Lever",
                    passCount = 1,
                    type = "direct",
                },
                id = "junction_route_1_route_2_1",
                inputEdgeIds = {
                    "route_1_segment_1",
                    "route_2_segment_1",
                },
                outputEdgeIds = {
                    "route_1_segment_2",
                },
                x = 0.46625936484184,
                y = 0.50547247432834,
            },
        },
        mapUuid = "3206710d-793f-474e-957a-fdb721926f52",
        title = "A Simple Beginning",
        trains = {
            {
                color = {
                    0.33,
                    0.8,
                    0.98,
                },
                edgeId = "route_1_segment_1",
                goalColor = "blue",
                id = "route_1_segment_1_train_blue_1",
                lineColor = "blue",
                spawnTime = 0.5,
                trainColor = "blue",
                wagonCount = 4,
            },
            {
                color = {
                    0.98,
                    0.82,
                    0.34,
                },
                edgeId = "route_2_segment_1",
                goalColor = "yellow",
                id = "route_2_segment_1_train_yellow_1",
                lineColor = "yellow",
                spawnTime = 0.5,
                trainColor = "yellow",
                wagonCount = 4,
            },
        },
    },
    mapUuid = "3206710d-793f-474e-957a-fdb721926f52",
    name = "A Simple Beginning",
    savedAt = "2026-04-20T19:00:17Z",
    version = 1,
}
