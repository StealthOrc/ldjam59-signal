package.path = "./?.lua;./?/init.lua;" .. package.path

local toml = require("src.game.util.toml")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %s but got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local payload = {
    version = 1,
    name = "Roundtrip",
    flags = {
        enabled = true,
        colors = { "blue", "orange" },
    },
    points = {
        { x = 1, y = 2 },
        { x = 3, y = 4 },
    },
    nested = {
        routes = {
            {
                id = "route_a",
                control = {
                    type = "direct",
                },
            },
        },
    },
}

local encoded = toml.stringify(payload)
local decoded, parseError = toml.parse(encoded)

assertEqual(parseError, nil, "toml roundtrip parses without error")
assertEqual(decoded.version, 1, "toml preserves root numbers")
assertEqual(decoded.name, "Roundtrip", "toml preserves root strings")
assertEqual(decoded.flags.enabled, true, "toml preserves nested booleans")
assertEqual(decoded.flags.colors[1], "blue", "toml preserves string arrays")
assertEqual(decoded.points[2].y, 4, "toml preserves array table numbers")
assertEqual(decoded.nested.routes[1].id, "route_a", "toml preserves nested array tables")
assertEqual(decoded.nested.routes[1].control.type, "direct", "toml preserves nested subtables")

print("toml roundtrip tests passed")
