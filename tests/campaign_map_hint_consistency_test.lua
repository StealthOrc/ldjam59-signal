package.path = "./?.lua;./?/init.lua;" .. package.path

local toml = require("src.game.util.toml")

local function assertTrue(value, label)
    if not value then
        error(label, 2)
    end
end

local campaignMapPaths = {
    "src/game/data/maps/campaign/01_a_simple_beginning.toml",
    "src/game/data/maps/campaign/02_two_crossings.toml",
    "src/game/data/maps/campaign/03_a_delay_due_to_traffic.toml",
    "src/game/data/maps/campaign/10_sp33dtrain.toml",
    "src/game/data/maps/campaign/11_setup_nah.toml",
}

for _, mapPath in ipairs(campaignMapPaths) do
    local map = toml.parseFile(mapPath)
    local hint = map and map.level and map.level.hint or ""
    local mentionsSelector = type(hint) == "string" and hint:find("bottom selector", 1, true) ~= nil

    if mentionsSelector then
        local hasMultiOutputJunction = false
        for _, junction in ipairs(map.level and map.level.junctions or {}) do
            if #(junction.outputEdgeIds or {}) > 1 then
                hasMultiOutputJunction = true
                break
            end
        end

        assertTrue(
            hasMultiOutputJunction,
            string.format("%s mentions the bottom selector without any multi-output junctions", mapPath)
        )
    end
end

print("campaign map hint consistency tests passed")
