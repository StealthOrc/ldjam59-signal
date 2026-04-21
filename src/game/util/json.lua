local json = {}

local function isArray(value)
    if type(value) ~= "table" then
        return false
    end

    local count = 0
    local maxIndex = 0
    for key, _ in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end
        count = count + 1
        if key > maxIndex then
            maxIndex = key
        end
    end

    return count == maxIndex
end

local ESCAPE_MAP = {
    ['\\'] = '\\\\',
    ['"'] = '\\"',
    ['\b'] = '\\b',
    ['\f'] = '\\f',
    ['\n'] = '\\n',
    ['\r'] = '\\r',
    ['\t'] = '\\t',
}

local function encodeString(value)
    return '"' .. value:gsub('[%z\1-\31\\"]', function(character)
        return ESCAPE_MAP[character] or string.format("\\u%04x", character:byte())
    end) .. '"'
end

local function encodeValue(value)
    local valueType = type(value)

    if valueType == "nil" then
        return "null"
    end
    if valueType == "boolean" then
        return value and "true" or "false"
    end
    if valueType == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            error("Cannot encode non-finite number to JSON")
        end
        return tostring(value)
    end
    if valueType == "string" then
        return encodeString(value)
    end
    if valueType ~= "table" then
        error("Unsupported JSON value type: " .. valueType)
    end

    if isArray(value) then
        local items = {}
        for index = 1, #value do
            items[index] = encodeValue(value[index])
        end
        return "[" .. table.concat(items, ",") .. "]"
    end

    local items = {}
    for key, entry in pairs(value) do
        if type(key) ~= "string" then
            error("JSON object keys must be strings")
        end
        items[#items + 1] = encodeString(key) .. ":" .. encodeValue(entry)
    end
    table.sort(items)
    return "{" .. table.concat(items, ",") .. "}"
end

local function decodeError(index, message)
    return nil, string.format("JSON decode error at character %d: %s", index, message)
end

local function codepointToUtf8(codepoint)
    if codepoint <= 0x7F then
        return string.char(codepoint)
    end
    if codepoint <= 0x7FF then
        local byte1 = 0xC0 + math.floor(codepoint / 0x40)
        local byte2 = 0x80 + (codepoint % 0x40)
        return string.char(byte1, byte2)
    end
    if codepoint <= 0xFFFF then
        local byte1 = 0xE0 + math.floor(codepoint / 0x1000)
        local byte2 = 0x80 + (math.floor(codepoint / 0x40) % 0x40)
        local byte3 = 0x80 + (codepoint % 0x40)
        return string.char(byte1, byte2, byte3)
    end

    local byte1 = 0xF0 + math.floor(codepoint / 0x40000)
    local byte2 = 0x80 + (math.floor(codepoint / 0x1000) % 0x40)
    local byte3 = 0x80 + (math.floor(codepoint / 0x40) % 0x40)
    local byte4 = 0x80 + (codepoint % 0x40)
    return string.char(byte1, byte2, byte3, byte4)
end

local function skipWhitespace(text, index)
    while true do
        local character = text:sub(index, index)
        if character == " " or character == "\t" or character == "\r" or character == "\n" then
            index = index + 1
        else
            break
        end
    end
    return index
end

local parseValue

local function parseString(text, index)
    index = index + 1
    local parts = {}

    while index <= #text do
        local character = text:sub(index, index)
        if character == '"' then
            return table.concat(parts), index + 1
        end

        if character == "\\" then
            local escape = text:sub(index + 1, index + 1)
            if escape == '"' or escape == "\\" or escape == "/" then
                parts[#parts + 1] = escape
                index = index + 2
            elseif escape == "b" then
                parts[#parts + 1] = "\b"
                index = index + 2
            elseif escape == "f" then
                parts[#parts + 1] = "\f"
                index = index + 2
            elseif escape == "n" then
                parts[#parts + 1] = "\n"
                index = index + 2
            elseif escape == "r" then
                parts[#parts + 1] = "\r"
                index = index + 2
            elseif escape == "t" then
                parts[#parts + 1] = "\t"
                index = index + 2
            elseif escape == "u" then
                local hex = text:sub(index + 2, index + 5)
                if #hex < 4 or not hex:match("^[0-9a-fA-F]+$") then
                    return decodeError(index, "invalid unicode escape")
                end
                parts[#parts + 1] = codepointToUtf8(tonumber(hex, 16))
                index = index + 6
            else
                return decodeError(index, "invalid escape character")
            end
        else
            parts[#parts + 1] = character
            index = index + 1
        end
    end

    return decodeError(index, "unterminated string")
end

local function parseNumber(text, index)
    local startIndex = index
    local token = text:match("^-?%d+%.?%d*[eE]?[+-]?%d*", index)
    if not token or token == "" then
        return decodeError(index, "invalid number")
    end

    local number = tonumber(token)
    if not number then
        return decodeError(index, "invalid number")
    end

    return number, startIndex + #token
end

local function parseLiteral(text, index, literal, value)
    if text:sub(index, index + #literal - 1) ~= literal then
        return decodeError(index, "invalid literal")
    end
    return value, index + #literal
end

local function parseArray(text, index)
    index = index + 1
    local result = {}
    index = skipWhitespace(text, index)
    if text:sub(index, index) == "]" then
        return result, index + 1
    end

    while index <= #text do
        local value, nextIndex = parseValue(text, index)
        if nextIndex == nil then
            return value, nextIndex
        end
        result[#result + 1] = value
        index = skipWhitespace(text, nextIndex)
        local character = text:sub(index, index)
        if character == "]" then
            return result, index + 1
        end
        if character ~= "," then
            return decodeError(index, "expected ',' or ']' in array")
        end
        index = skipWhitespace(text, index + 1)
    end

    return decodeError(index, "unterminated array")
end

local function parseObject(text, index)
    index = index + 1
    local result = {}
    index = skipWhitespace(text, index)
    if text:sub(index, index) == "}" then
        return result, index + 1
    end

    while index <= #text do
        if text:sub(index, index) ~= '"' then
            return decodeError(index, "expected string key")
        end

        local key, nextIndex = parseString(text, index)
        if nextIndex == nil then
            return key, nextIndex
        end

        index = skipWhitespace(text, nextIndex)
        if text:sub(index, index) ~= ":" then
            return decodeError(index, "expected ':' after key")
        end

        local value
        value, nextIndex = parseValue(text, skipWhitespace(text, index + 1))
        if nextIndex == nil then
            return value, nextIndex
        end
        result[key] = value
        index = skipWhitespace(text, nextIndex)

        local character = text:sub(index, index)
        if character == "}" then
            return result, index + 1
        end
        if character ~= "," then
            return decodeError(index, "expected ',' or '}' in object")
        end
        index = skipWhitespace(text, index + 1)
    end

    return decodeError(index, "unterminated object")
end

parseValue = function(text, index)
    index = skipWhitespace(text, index)
    local character = text:sub(index, index)

    if character == '"' then
        return parseString(text, index)
    end
    if character == "{" then
        return parseObject(text, index)
    end
    if character == "[" then
        return parseArray(text, index)
    end
    if character == "-" or character:match("%d") then
        return parseNumber(text, index)
    end
    if character == "t" then
        return parseLiteral(text, index, "true", true)
    end
    if character == "f" then
        return parseLiteral(text, index, "false", false)
    end
    if character == "n" then
        return parseLiteral(text, index, "null", nil)
    end

    return decodeError(index, "unexpected character")
end

function json.encode(value)
    return encodeValue(value)
end

function json.decode(text)
    if type(text) ~= "string" then
        return nil, "JSON decode expects a string"
    end

    local value, index = parseValue(text, 1)
    if type(index) ~= "number" then
        return value, index
    end

    index = skipWhitespace(text, index)
    if index <= #text then
        return decodeError(index, "trailing characters")
    end

    return value
end

return json
