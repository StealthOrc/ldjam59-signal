return {
    version = 1,
    mapUuid = "95eac4e5-4297-4a36-a113-231debbeca96",
    name = "Map 3: Charge Lever",
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
                id = "junction_pump",
                x = 0.3672,
                y = 0.4811,
                control = "pump",
                activeInputIndex = 1,
                activeOutputIndex = 1,
                routes = { "route_blue", "route_orange" },
                inputEndpointIds = { "in_blue", "in_orange" },
                outputEndpointIds = { "out_main" },
            },
        },
    },
    level = {
        title = "Map 3: Charge Lever",
        description = "Tutorial: charge the pump lever all the way up to force the route to switch.",
        hint = "You need seven fast clicks. Wait too long and the charge drains away one segment at a time.",
        footer = "Pump the lever to flip the route, then clear both trains. The charge decays if you hesitate.",
        junctions = {
            {
                id = "pump_tutorial",
                activeInputIndex = 1,
                activeOutputIndex = 1,
                control = {
                    type = "pump",
                    label = "Charge Lever",
                    target = 7,
                    decayDelay = 0.55,
                    decayInterval = 0.2,
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
            { id = "pump_blue_train", junctionId = "pump_tutorial", inputIndex = 1, progress = -70, speedScale = 1.0, color = { 0.33, 0.80, 0.98 } },
            { id = "pump_amber_train", junctionId = "pump_tutorial", inputIndex = 2, progress = -210, speedScale = 0.93, color = { 0.98, 0.70, 0.28 } },
        },
    },
}
