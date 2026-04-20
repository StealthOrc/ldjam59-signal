return {
    editor = {
        endpoints = {
            {
                colors = {
                    "blue",
                },
                id = "input_endpoint_1",
                kind = "input",
                x = 0.228125,
                y = 0.058333333333333,
            },
            {
                colors = {
                    "blue",
                },
                id = "output_endpoint_2",
                kind = "output",
                x = 0.2171875,
                y = 0.95277777777778,
            },
            {
                colors = {
                    "yellow",
                },
                id = "input_endpoint_3",
                kind = "input",
                x = 0.0296875,
                y = 0.058333333333333,
            },
            {
                colors = {
                    "yellow",
                },
                id = "output_endpoint_4",
                kind = "output",
                x = 0.540625,
                y = 0.95277777777778,
            },
            {
                colors = {
                    "mint",
                },
                id = "input_endpoint_5",
                kind = "input",
                x = 0.54296875,
                y = 0.058333333333333,
            },
            {
                colors = {
                    "mint",
                },
                id = "output_endpoint_6",
                kind = "output",
                x = 0.303125,
                y = 0.95277777777778,
            },
        },
        junctions = {
            {
                activeInputIndex = 1,
                activeOutputIndex = 1,
                control = "direct",
                id = "junction_route_1_route_2_1",
                inputEndpointIds = {
                    "input_endpoint_3",
                    "input_endpoint_1",
                },
                outputEndpointIds = {
                    "output_endpoint_2",
                    "output_endpoint_4",
                },
                passCount = 1,
                routes = {
                    "route_1",
                    "route_2",
                },
                x = 0.22396613023952,
                y = 0.39843646041251,
            },
            {
                activeInputIndex = 1,
                activeOutputIndex = 1,
                control = "direct",
                id = "junction_route_2_route_3_1",
                inputEndpointIds = {
                    "input_endpoint_3",
                    "input_endpoint_5",
                },
                outputEndpointIds = {
                    "output_endpoint_6",
                    "output_endpoint_4",
                },
                passCount = 1,
                routes = {
                    "route_2",
                    "route_3",
                },
                x = 0.3789964880333,
                y = 0.66983177245925,
            },
        },
        mapSize = {
            h = 720,
            w = 1280,
        },
        routes = {
            {
                color = "blue",
                endEndpointId = "output_endpoint_2",
                id = "route_1",
                label = "route_1",
                points = {
                    {
                        x = 0.228125,
                        y = 0.058333333333333,
                    },
                    {
                        x = 0.2171875,
                        y = 0.95277777777778,
                    },
                },
                segmentRoadTypes = {
                    "normal",
                },
                startEndpointId = "input_endpoint_1",
            },
            {
                color = "yellow",
                endEndpointId = "output_endpoint_4",
                id = "route_2",
                label = "route_2",
                points = {
                    {
                        x = 0.0296875,
                        y = 0.058333333333333,
                    },
                    {
                        x = 0.540625,
                        y = 0.95277777777778,
                    },
                },
                segmentRoadTypes = {
                    "normal",
                },
                startEndpointId = "input_endpoint_3",
            },
            {
                color = "mint",
                endEndpointId = "output_endpoint_6",
                id = "route_3",
                label = "route_3",
                points = {
                    {
                        x = 0.54296875,
                        y = 0.058333333333333,
                    },
                    {
                        x = 0.303125,
                        y = 0.95277777777778,
                    },
                },
                segmentRoadTypes = {
                    "normal",
                },
                startEndpointId = "input_endpoint_5",
            },
        },
        trains = {
            {
                id = "train_1",
                lineColor = "blue",
                spawnTime = 0,
                trainColor = "blue",
                wagonCount = 4,
            },
            {
                id = "train_2",
                lineColor = "yellow",
                spawnTime = 0.5,
                trainColor = "yellow",
                wagonCount = 4,
            },
            {
                id = "train_3",
                lineColor = "mint",
                spawnTime = 1,
                trainColor = "mint",
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
                        x = 0.228125,
                        y = 0.058333333333333,
                    },
                    {
                        x = 0.22396613023952,
                        y = 0.39843646041251,
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
                        x = 0.22396613023952,
                        y = 0.39843646041251,
                    },
                    {
                        x = 0.2171875,
                        y = 0.95277777777778,
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
                        x = 0.0296875,
                        y = 0.058333333333333,
                    },
                    {
                        x = 0.22396613023952,
                        y = 0.39843646041251,
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
            {
                adoptInputColor = false,
                color = {
                    0.98,
                    0.82,
                    0.34,
                },
                colors = {
                },
                darkColor = {
                    0.4116,
                    0.3444,
                    0.1428,
                },
                id = "route_2_segment_2",
                inputColors = {
                },
                label = "Yellow route Segment 2",
                points = {
                    {
                        x = 0.22396613023952,
                        y = 0.39843646041251,
                    },
                    {
                        x = 0.3789964880333,
                        y = 0.66983177245925,
                    },
                },
                roadType = "normal",
                routeId = "route_2",
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
                targetId = "junction_route_2_route_3_1",
                targetType = "junction",
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
                id = "route_2_segment_3",
                inputColors = {
                },
                label = "Yellow route Segment 3",
                points = {
                    {
                        x = 0.3789964880333,
                        y = 0.66983177245925,
                    },
                    {
                        x = 0.540625,
                        y = 0.95277777777778,
                    },
                },
                roadType = "normal",
                routeId = "route_2",
                sourceId = "junction_route_2_route_3_1",
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
                targetId = "output_endpoint_4",
                targetType = "exit",
            },
            {
                adoptInputColor = false,
                color = {
                    0.4,
                    0.92,
                    0.76,
                },
                colors = {
                    "mint",
                },
                darkColor = {
                    0.168,
                    0.3864,
                    0.3192,
                },
                id = "route_3_segment_1",
                inputColors = {
                    "mint",
                },
                label = "Mint route Segment 1",
                points = {
                    {
                        x = 0.54296875,
                        y = 0.058333333333333,
                    },
                    {
                        x = 0.3789964880333,
                        y = 0.66983177245925,
                    },
                },
                roadType = "normal",
                routeId = "route_3",
                sourceId = "input_endpoint_5",
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
                targetId = "junction_route_2_route_3_1",
                targetType = "junction",
            },
            {
                adoptInputColor = false,
                color = {
                    0.4,
                    0.92,
                    0.76,
                },
                colors = {
                    "mint",
                },
                darkColor = {
                    0.168,
                    0.3864,
                    0.3192,
                },
                id = "route_3_segment_2",
                inputColors = {
                },
                label = "Mint route Segment 2",
                points = {
                    {
                        x = 0.3789964880333,
                        y = 0.66983177245925,
                    },
                    {
                        x = 0.303125,
                        y = 0.95277777777778,
                    },
                },
                roadType = "normal",
                routeId = "route_3",
                sourceId = "junction_route_2_route_3_1",
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
                targetId = "output_endpoint_6",
                targetType = "exit",
            },
        },
        footer = "Sequence trains from the editor pane and clear every goal on time.",
        hint = "Click the junction center to switch inputs. Use the bottom selector to switch outputs.",
        id = "16b6e4e1-cafc-4f02-8285-11dc7e2f5d75",
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
                    "route_2_segment_1",
                    "route_1_segment_1",
                },
                outputEdgeIds = {
                    "route_2_segment_2",
                    "route_1_segment_2",
                },
                x = 0.22396613023952,
                y = 0.39843646041251,
            },
            {
                activeInputIndex = 1,
                activeOutputIndex = 1,
                control = {
                    label = "Direct Lever",
                    passCount = 1,
                    type = "direct",
                },
                id = "junction_route_2_route_3_1",
                inputEdgeIds = {
                    "route_2_segment_2",
                    "route_3_segment_1",
                },
                outputEdgeIds = {
                    "route_3_segment_2",
                    "route_2_segment_3",
                },
                x = 0.3789964880333,
                y = 0.66983177245925,
            },
        },
        mapUuid = "16b6e4e1-cafc-4f02-8285-11dc7e2f5d75",
        title = "Two Crossings",
        trains = {
            {
                color = {
                    0.33,
                    0.8,
                    0.98,
                },
                edgeId = "route_1_segment_1",
                goalColor = "blue",
                id = "train_1",
                lineColor = "blue",
                spawnTime = 0,
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
                id = "train_2",
                lineColor = "yellow",
                spawnTime = 0.5,
                trainColor = "yellow",
                wagonCount = 4,
            },
            {
                color = {
                    0.4,
                    0.92,
                    0.76,
                },
                edgeId = "route_3_segment_1",
                goalColor = "mint",
                id = "train_3",
                lineColor = "mint",
                spawnTime = 1,
                trainColor = "mint",
                wagonCount = 4,
            },
        },
    },
    mapUuid = "16b6e4e1-cafc-4f02-8285-11dc7e2f5d75",
    name = "Two Crossings",
    savedAt = "2026-04-20T18:37:39Z",
    version = 1,
}
