local levels = {
    {
        id = 1,
        title = "Map 1: Direct Lever",
        description = "Tutorial: click the crossing to flip the route instantly and clear both trains.",
        hint = "The crossing itself is the lever. One click flips the live route immediately.",
        footer = "Route both trains through the merge. Fast switching can still crash them.",
        timeLimit = nil,
        junctions = {
            {
                id = "direct_tutorial",
                mergeX = 0.5,
                mergeY = 0.48,
                exitY = 1.25,
                activeBranch = 1,
                control = {
                    type = "direct",
                    label = "Direct Lever",
                },
                branches = {
                    {
                        id = "blue",
                        label = "Blue",
                        startX = 0.33,
                        color = { 0.33, 0.8, 0.98 },
                        darkColor = { 0.12, 0.32, 0.44 },
                    },
                    {
                        id = "amber",
                        label = "Amber",
                        startX = 0.67,
                        color = { 0.96, 0.7, 0.28 },
                        darkColor = { 0.42, 0.24, 0.08 },
                    },
                },
            },
        },
        trains = {
            { id = "direct_blue_train", junctionId = "direct_tutorial", branchIndex = 1, progress = -70, speedScale = 1.0 },
            { id = "direct_amber_train", junctionId = "direct_tutorial", branchIndex = 2, progress = -210, speedScale = 0.93 },
        },
    },
    {
        id = 2,
        title = "Map 2: Delayed Button",
        description = "Two merges, four trains, and a timer. The left crossing flips instantly, the right button swaps after a delay.",
        hint = "Arm the delayed button early so the second right-side train gets its route in time.",
        footer = "Clear all four trains before the timer expires. The delayed swap only happens after its countdown finishes.",
        timeLimit = 15,
        junctions = {
            {
                id = "left_direct",
                mergeX = 0.28,
                mergeY = 0.5,
                exitY = 1.25,
                activeBranch = 1,
                control = {
                    type = "direct",
                    label = "Direct Lever",
                },
                branches = {
                    {
                        id = "mint",
                        label = "Mint",
                        startX = 0.18,
                        color = { 0.4, 0.92, 0.76 },
                        darkColor = { 0.12, 0.38, 0.31 },
                    },
                    {
                        id = "rose",
                        label = "Rose",
                        startX = 0.38,
                        color = { 0.98, 0.48, 0.62 },
                        darkColor = { 0.42, 0.14, 0.22 },
                    },
                },
            },
            {
                id = "right_delayed",
                mergeX = 0.72,
                mergeY = 0.5,
                exitY = 1.25,
                activeBranch = 1,
                control = {
                    type = "delayed",
                    label = "Delayed Button",
                    delay = 2.25,
                    buttonOffsetX = 112,
                    buttonOffsetY = 26,
                    radius = 28,
                },
                branches = {
                    {
                        id = "blue",
                        label = "Blue",
                        startX = 0.62,
                        color = { 0.33, 0.8, 0.98 },
                        darkColor = { 0.12, 0.32, 0.44 },
                    },
                    {
                        id = "gold",
                        label = "Gold",
                        startX = 0.82,
                        color = { 0.98, 0.82, 0.34 },
                        darkColor = { 0.46, 0.34, 0.08 },
                    },
                },
            },
        },
        trains = {
            { id = "left_mint_train", junctionId = "left_direct", branchIndex = 1, progress = -40, speedScale = 1.0 },
            { id = "left_rose_train", junctionId = "left_direct", branchIndex = 2, progress = -175, speedScale = 0.96 },
            { id = "right_blue_train", junctionId = "right_delayed", branchIndex = 1, progress = -60, speedScale = 1.0 },
            { id = "right_gold_train", junctionId = "right_delayed", branchIndex = 2, progress = -205, speedScale = 0.95 },
        },
    },
    {
        id = 3,
        title = "Map 3: Charge Lever",
        description = "Tutorial: charge the pump lever all the way up to force the route to switch.",
        hint = "You need seven fast clicks. Wait too long and the charge drains away one segment at a time.",
        footer = "Pump the lever to flip the route, then clear both trains. The charge decays if you hesitate.",
        timeLimit = nil,
        junctions = {
            {
                id = "pump_tutorial",
                mergeX = 0.5,
                mergeY = 0.48,
                exitY = 1.25,
                activeBranch = 1,
                control = {
                    type = "pump",
                    label = "Charge Lever",
                    target = 7,
                    decayDelay = 0.55,
                    decayInterval = 0.2,
                    buttonOffsetX = 0,
                    buttonOffsetY = 118,
                    width = 164,
                    height = 46,
                },
                branches = {
                    {
                        id = "blue",
                        label = "Blue",
                        startX = 0.33,
                        color = { 0.33, 0.8, 0.98 },
                        darkColor = { 0.12, 0.32, 0.44 },
                    },
                    {
                        id = "amber",
                        label = "Amber",
                        startX = 0.67,
                        color = { 0.96, 0.7, 0.28 },
                        darkColor = { 0.42, 0.24, 0.08 },
                    },
                },
            },
        },
        trains = {
            { id = "pump_blue_train", junctionId = "pump_tutorial", branchIndex = 1, progress = -70, speedScale = 1.0 },
            { id = "pump_amber_train", junctionId = "pump_tutorial", branchIndex = 2, progress = -210, speedScale = 0.93 },
        },
    },
}

return levels
