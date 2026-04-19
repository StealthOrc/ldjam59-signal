return {
    version = 1,
    mapUuid = "e042a65d-e425-40e0-8c36-43a4acd0d69b",
    name = "Map 6: Trip Switch",
    previewDescription = "One click arms the next passing train only.",
    template = true,
    editor = {
        endpoints = {
            { id = "in_blue", kind = "input", x = 0.2477, y = 0.0583, colors = { "blue" } },
            { id = "in_orange", kind = "input", x = 0.4867, y = 0.0583, colors = { "orange" } },
            { id = "out_main", kind = "output", x = 0.3672, y = 0.9722, colors = { "blue", "orange" } },
        },
        routes = {
            {
                id = "route_blue",
                label = "Blue",
                color = "blue",
                startEndpointId = "in_blue",
                endEndpointId = "out_main",
                points = {
                    { x = 0.2477, y = 0.0583 },
                    { x = 0.2477, y = 0.2733 },
                    { x = 0.3672, y = 0.4811 },
                    { x = 0.3672, y = 0.9722 },
                },
            },
            {
                id = "route_orange",
                label = "Amber",
                color = "orange",
                startEndpointId = "in_orange",
                endEndpointId = "out_main",
                points = {
                    { x = 0.4867, y = 0.0583 },
                    { x = 0.4867, y = 0.2733 },
                    { x = 0.3672, y = 0.4811 },
                    { x = 0.3672, y = 0.9722 },
                },
            },
        },
        junctions = {
            {
                id = "junction_trip",
                x = 0.3672,
                y = 0.4811,
                control = "trip",
                activeInputIndex = 1,
                activeOutputIndex = 1,
                routes = { "route_blue", "route_orange" },
                inputEndpointIds = { "in_blue", "in_orange" },
                outputEndpointIds = { "out_main" },
            },
        },
    },
    level = {
        title = "Map 6: Trip Switch",
        previewDescription = "One click arms the next passing train only.",
        description = "The trip switch holds its alternate route until exactly one train passes, then it snaps back by itself.",
        hint = "Arm the orange route early. It will wait there until that one train passes, then blue is restored automatically.",
        footer = "Trip switches are event driven, not timer driven. They reset only after a train actually crosses.",
        junctions = {
            {
                id = "trip_tutorial",
                activeInputIndex = 1,
                activeOutputIndex = 1,
                control = {
                    type = "trip",
                    label = "Trip Switch",
                },
                inputs = {
                    {
                        id = "route_blue_input",
                        label = "Input 1",
                        colors = { "blue" },
                        color = { 0.33, 0.80, 0.98 },
                        darkColor = { 0.12, 0.32, 0.44 },
                        inputPoints = {
                            { x = 0.2477, y = 0.0583 },
                            { x = 0.2477, y = 0.2733 },
                            { x = 0.3672, y = 0.4811 },
                        },
                    },
                    {
                        id = "route_orange_input",
                        label = "Input 2",
                        colors = { "orange" },
                        color = { 0.98, 0.70, 0.28 },
                        darkColor = { 0.42, 0.24, 0.08 },
                        inputPoints = {
                            { x = 0.4867, y = 0.0583 },
                            { x = 0.4867, y = 0.2733 },
                            { x = 0.3672, y = 0.4811 },
                        },
                    },
                },
                outputs = {
                    {
                        id = "out_main",
                        label = "Output 1",
                        colors = { "blue", "orange" },
                        color = { 0.33, 0.80, 0.98 },
                        darkColor = { 0.12, 0.32, 0.44 },
                        adoptInputColor = true,
                        outputPoints = {
                            { x = 0.3672, y = 0.4811 },
                            { x = 0.3672, y = 0.9722 },
                        },
                    },
                },
            },
        },
        trains = {
            { id = "trip_blue_train", junctionId = "trip_tutorial", inputIndex = 1, progress = -252, speedScale = 0.94, color = { 0.33, 0.80, 0.98 } },
            { id = "trip_orange_train", junctionId = "trip_tutorial", inputIndex = 2, progress = -86, speedScale = 1.0, color = { 0.98, 0.70, 0.28 } },
        },
    },
}
