package.path = "./?.lua;./?/init.lua;" .. package.path

local levelSelectSelection = require("src.game.level_select_selection")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %s but got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local duplicateUuidMaps = {
    { id = "marketplace:creator:shared-map:first", mapUuid = "shared-map" },
    { id = "marketplace:creator:shared-map:second", mapUuid = "shared-map" },
    { id = "marketplace:creator:other-map:listing", mapUuid = "other-map" },
}

assertEqual(
    levelSelectSelection.findIndex(duplicateUuidMaps, "marketplace:creator:shared-map:second", "shared-map"),
    2,
    "level select selection prefers the stable descriptor id when duplicate map UUIDs exist"
)

assertEqual(
    levelSelectSelection.findIndex(duplicateUuidMaps, nil, "other-map"),
    3,
    "level select selection still falls back to a unique map UUID when it is unambiguous"
)

assertEqual(
    levelSelectSelection.findIndex(duplicateUuidMaps, nil, "shared-map"),
    nil,
    "level select selection treats duplicate map UUID fallback as ambiguous"
)

assertEqual(
    levelSelectSelection.findIndex(duplicateUuidMaps, nil, nil),
    1,
    "level select selection falls back to the first entry when nothing is selected"
)

print("level select selection tests passed")

