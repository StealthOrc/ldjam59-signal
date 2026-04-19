return {
    version = 1,
    name = "Map 4: Spring Switch",
    template = true,
    editor = {
        endpoints = {
            { id = "in_blue", kind = "input", x = 0.2477, y = 0.0583, colors = { "blue" } },
            { id = "in_violet", kind = "input", x = 0.4867, y = 0.0583, colors = { "violet" } },
            { id = "out_main", kind = "output", x = 0.3672, y = 0.9722, colors = { "blue", "violet" } },
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
                id = "route_violet",
                label = "Violet",
                color = "violet",
                startEndpointId = "in_violet",
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
                id = "junction_spring",
                x = 0.3672,
                y = 0.4811,
                control = "spring",
                activeInputIndex = 1,
                activeOutputIndex = 1,
                routes = { "route_blue", "route_violet" },
                inputEndpointIds = { "in_blue", "in_violet" },
                outputEndpointIds = { "out_main" },
            },
        },
    },
    level = {
        title = "Map 4: Spring Switch",
        description = "A spring-loaded switch flips over for a moment, then snaps back to its previous route on its own.",
        hint = "Let the near violet train slip through, then trust the spring to reset for the delayed blue train.",
        footer = "Spring switches reward late timing. Flip too early and the reset happens before the train arrives.",
        junctions = {
            {
                id = "spring_tutorial",
                activeInputIndex = 1,
                activeOutputIndex = 1,
                control = {
                    type = "spring",
                    label = "Spring Switch",
                    holdTime = 1.6,
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
                        id = "route_violet_input",
                        label = "Input 2",
                        colors = { "violet" },
                        color = { 0.82, 0.56, 0.98 },
                        darkColor = { 0.34, 0.2, 0.44 },
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
                        colors = { "blue", "violet" },
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
            { id = "spring_blue_train", junctionId = "spring_tutorial", inputIndex = 1, progress = -250, speedScale = 0.94, color = { 0.33, 0.80, 0.98 } },
            { id = "spring_violet_train", junctionId = "spring_tutorial", inputIndex = 2, progress = -78, speedScale = 1.0, color = { 0.82, 0.56, 0.98 } },
        },
    },
}
