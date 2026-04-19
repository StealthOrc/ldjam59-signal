return {
    version = 1,
    mapUuid = "83ea86be-9245-41c3-8ce3-7c1b1b845b7c",
    name = "Map 1: Direct Lever",
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
                id = "junction_direct",
                x = 0.3672,
                y = 0.4811,
                control = "direct",
                activeInputIndex = 1,
                activeOutputIndex = 1,
                routes = { "route_blue", "route_orange" },
                inputEndpointIds = { "in_blue", "in_orange" },
                outputEndpointIds = { "out_main" },
            },
        },
    },
    level = {
        title = "Map 1: Direct Lever",
        description = "Tutorial: click the crossing to flip the route instantly and clear both trains.",
        hint = "The crossing itself is the lever. One click flips the live route immediately.",
        footer = "Route both trains through the merge. Fast switching can still crash them.",
        junctions = {
            {
                id = "direct_tutorial",
                activeInputIndex = 1,
                activeOutputIndex = 1,
                control = {
                    type = "direct",
                    label = "Direct Lever",
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
            { id = "direct_blue_train", junctionId = "direct_tutorial", inputIndex = 1, progress = -70, speedScale = 1.0, color = { 0.33, 0.80, 0.98 } },
            { id = "direct_amber_train", junctionId = "direct_tutorial", inputIndex = 2, progress = -210, speedScale = 0.93, color = { 0.98, 0.70, 0.28 } },
        },
    },
}
