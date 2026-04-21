local json = require("src.game.util.json")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local decodedValue, decodeError = json.decode('{"ok":true}')
assertEqual(type(decodedValue), "table", "valid JSON decodes into a table")
assertEqual(decodedValue.ok, true, "valid JSON preserves boolean values")
assertEqual(decodeError, nil, "valid JSON has no decode error")

local invalidValue, invalidError = json.decode("not-json")
assertEqual(invalidValue, nil, "invalid JSON returns nil")
assertEqual(type(invalidError), "string", "invalid JSON returns a string error")
