package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}

local junctionControls = require("src.game.junction_controls")
local mapStorage = require("src.game.storage.map_storage")
local world = require("src.game.gameplay.railway_world")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %q but got %q", label, tostring(expected), tostring(actual)), 2)
    end
end

local mapData, loadError = mapStorage.loadMap("01_a_simple_beginning.toml", "builtin", "campaign", "src/game/data/maps/campaign")
if not mapData then
    error(loadError or "failed to load A Simple Beginning", 2)
end

assertEqual(mapData.level.hint, "Click the junction center to switch routes.", "campaign hint should match the merged output behavior")
assertEqual(#(mapData.level.junctions or {}), 1, "campaign map should keep one playable junction")
assertEqual(#(mapData.level.junctions[1].outputEdgeIds or {}), 1, "campaign map should compile to one merged outgoing edge")

local simulation = world.new(1280, 720, mapData.level)
local junction = simulation.junctionOrder[1]
assertEqual(#(junction.outputs or {}), 1, "runtime world should expose a single outgoing lane")
assertEqual(junctionControls.hasManualOutputSelector(junction), false, "single merged outgoing lane should not expose the selector")

print("campaign simple beginning output merge tests passed")
