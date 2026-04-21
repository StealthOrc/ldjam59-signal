local mapCompiler = {}
local DEFAULT_WAGON_COUNT = 4
local LEGACY_TRAIN_SPACING = 110
local LEGACY_TRAIN_OFFSET = 70
local LEGACY_TRAIN_SPEED = 168
local roadTypes = require("src.game.data.road_types")

local COLOR_LOOKUP = {
    blue = { 0.33, 0.80, 0.98 },
    yellow = { 0.98, 0.82, 0.34 },
    mint = { 0.40, 0.92, 0.76 },
    rose = { 0.98, 0.48, 0.62 },
    orange = { 0.98, 0.70, 0.28 },
    violet = { 0.82, 0.56, 0.98 },
}

local DEFAULT_CONTROL_CONFIGS = {
    direct = {
        label = "Direct Lever",
    },
    delayed = {
        label = "Delayed Button",
        delay = 2.25,
    },
    pump = {
        label = "Charge Lever",
        target = 7,
        decayDelay = 0.55,
        decayInterval = 0.2,
    },
    spring = {
        label = "Spring Switch",
        holdTime = 1.6,
    },
    relay = {
        label = "Relay Dial",
    },
    trip = {
        label = "Trip Switch",
        passCount = 1,
    },
    crossbar = {
        label = "Crossbar Dial",
    },
}


local shared = {
    DEFAULT_WAGON_COUNT = DEFAULT_WAGON_COUNT,
    LEGACY_TRAIN_SPACING = LEGACY_TRAIN_SPACING,
    LEGACY_TRAIN_OFFSET = LEGACY_TRAIN_OFFSET,
    LEGACY_TRAIN_SPEED = LEGACY_TRAIN_SPEED,
    roadTypes = roadTypes,
    COLOR_LOOKUP = COLOR_LOOKUP,
    DEFAULT_CONTROL_CONFIGS = DEFAULT_CONTROL_CONFIGS,
}

require("src.game.map_compiler.map_compiler_geometry")(mapCompiler, shared)
require("src.game.map_compiler.map_compiler_builder")(mapCompiler, shared)
require("src.game.map_compiler.map_compiler_public")(mapCompiler, shared)

return mapCompiler
