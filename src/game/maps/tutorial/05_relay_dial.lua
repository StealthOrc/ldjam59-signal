return {
    version = 1,
    name = "Map 5: Relay Dial",
    template = true,
    editor = {
        endpoints = {
            { id = "in_blue", kind = "input", x = 0.1969, y = 0.0583, colors = { "blue" } },
            { id = "in_yellow", kind = "input", x = 0.5391, y = 0.0583, colors = { "yellow" } },
            { id = "out_left", kind = "output", x = 0.1969, y = 0.9722, colors = { "blue", "yellow" } },
            { id = "out_right", kind = "output", x = 0.5391, y = 0.9722, colors = { "blue", "yellow" } },
        },
        routes = {
            {
                id = "route_blue",
                label = "Blue",
                color = "blue",
                startEndpointId = "in_blue",
                endEndpointId = "out_left",
                points = {
                    { x = 0.1969, y = 0.0583 },
                    { x = 0.1969, y = 0.2794 },
                    { x = 0.3672, y = 0.4556 },
                    { x = 0.1969, y = 0.7000 },
                    { x = 0.1969, y = 0.9722 },
                },
            },
            {
                id = "route_yellow",
                label = "Gold",
                color = "yellow",
                startEndpointId = "in_yellow",
                endEndpointId = "out_right",
                points = {
                    { x = 0.5391, y = 0.0583 },
                    { x = 0.5391, y = 0.2794 },
                    { x = 0.3672, y = 0.4556 },
                    { x = 0.5391, y = 0.7000 },
                    { x = 0.5391, y = 0.9722 },
                },
            },
        },
        junctions = {
            {
                id = "junction_relay",
                x = 0.3672,
                y = 0.4556,
                control = "relay",
                activeInputIndex = 1,
                activeOutputIndex = 1,
                routes = { "route_blue", "route_yellow" },
                inputEndpointIds = { "in_blue", "in_yellow" },
                outputEndpointIds = { "out_left", "out_right" },
            },
        },
    },
    level = {
        title = "Map 5: Relay Dial",
        description = "The relay dial couples the incoming route and exit lane together, so every click advances both sides in lockstep.",
        hint = "Use one click for the near gold train, then another to bring the blue line and left exit back together.",
        footer = "Relay dials trade flexibility for speed. You cannot adjust the output selector separately on this junction.",
        junctions = {
            {
                id = "relay_tutorial",
                activeInputIndex = 1,
                activeOutputIndex = 1,
                control = {
                    type = "relay",
                    label = "Relay Dial",
                },
                inputs = {
                    {
                        id = "route_blue_input",
                        label = "Input 1",
                        colors = { "blue" },
                        color = { 0.33, 0.80, 0.98 },
                        darkColor = { 0.12, 0.32, 0.44 },
                        inputPoints = {
                            { x = 0.1969, y = 0.0583 },
                            { x = 0.1969, y = 0.2794 },
                            { x = 0.3672, y = 0.4556 },
                        },
                    },
                    {
                        id = "route_yellow_input",
                        label = "Input 2",
                        colors = { "yellow" },
                        color = { 0.98, 0.82, 0.34 },
                        darkColor = { 0.46, 0.34, 0.08 },
                        inputPoints = {
                            { x = 0.5391, y = 0.0583 },
                            { x = 0.5391, y = 0.2794 },
                            { x = 0.3672, y = 0.4556 },
                        },
                    },
                },
                outputs = {
                    {
                        id = "out_left",
                        label = "Output 1",
                        colors = { "blue", "yellow" },
                        color = { 0.33, 0.80, 0.98 },
                        darkColor = { 0.12, 0.32, 0.44 },
                        adoptInputColor = true,
                        outputPoints = {
                            { x = 0.3672, y = 0.4556 },
                            { x = 0.1969, y = 0.7000 },
                            { x = 0.1969, y = 0.9722 },
                        },
                    },
                    {
                        id = "out_right",
                        label = "Output 2",
                        colors = { "blue", "yellow" },
                        color = { 0.98, 0.82, 0.34 },
                        darkColor = { 0.46, 0.34, 0.08 },
                        adoptInputColor = true,
                        outputPoints = {
                            { x = 0.3672, y = 0.4556 },
                            { x = 0.5391, y = 0.7000 },
                            { x = 0.5391, y = 0.9722 },
                        },
                    },
                },
            },
        },
        trains = {
            { id = "relay_blue_train", junctionId = "relay_tutorial", inputIndex = 1, progress = -245, speedScale = 0.94, color = { 0.33, 0.80, 0.98 } },
            { id = "relay_gold_train", junctionId = "relay_tutorial", inputIndex = 2, progress = -78, speedScale = 1.0, color = { 0.98, 0.82, 0.34 } },
        },
    },
}
