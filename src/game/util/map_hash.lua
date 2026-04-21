local json = require("src.game.util.json")

local mapHash = {}

local function getSha256Hex(value)
    if not (love and love.data and love.data.hash and love.data.encode) then
        return nil
    end

    local digest = love.data.hash("sha256", tostring(value or ""))
    return love.data.encode("string", "hex", digest)
end

function mapHash.computeForLevel(level)
    if type(level) ~= "table" then
        return nil
    end

    local encodedLevel = json.encode(level)
    if type(encodedLevel) ~= "string" or encodedLevel == "" then
        return nil
    end

    return getSha256Hex(encodedLevel)
end

return mapHash
