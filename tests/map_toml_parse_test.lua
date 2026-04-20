package.path = "./?.lua;./?/init.lua;" .. package.path

local toml = require("src.game.toml")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %s but got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local map = toml.parseFile("src/game/maps/tutorial/01_direct_lever.toml")

assertEqual(type(map), "table", "map toml parses into a table")
assertEqual(map.name, "Map 1: Direct Lever", "map toml keeps the title")
assertEqual(map.editor.endpoints[1].id, "in_blue", "map toml keeps endpoint arrays")
assertEqual(map.level.junctions[1].inputs[2].id, "route_orange_input", "map toml keeps nested array tables")

print("map toml parse tests passed")
