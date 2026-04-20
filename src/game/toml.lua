local toml = {}

local LINE_BREAK = "\n"
local INDENT_WIDTH = 4
local QUOTE = '"'

local ESCAPE_MAP = {
    ['"'] = '\\"',
    ["\\"] = "\\\\",
    ["\n"] = "\\n",
    ["\r"] = "\\r",
    ["\t"] = "\\t",
}

local UNESCAPE_MAP = {
    ['"'] = '"',
    ["\\"] = "\\",
    ["n"] = "\n",
    ["r"] = "\r",
    ["t"] = "\t",
}

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function isIntegerString(value)
    return type(value) == "string" and value:match("^%d+$") ~= nil
end

local function isIdentifier(value)
    return type(value) == "string" and value:match("^[%a%d_%-]+$") ~= nil
end

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

local function isPrimitive(value)
    local valueType = type(value)
    return valueType == "string" or valueType == "number" or valueType == "boolean"
end

local function isPrimitiveArray(value)
    if not isArray(value) then
        return false
    end

    for _, entry in ipairs(value) do
        if type(entry) == "table" then
            return false
        end
        if not isPrimitive(entry) then
            return false
        end
    end

    return true
end

local function encodeString(value)
    return QUOTE .. tostring(value):gsub('[\\\"\n\r\t]', ESCAPE_MAP) .. QUOTE
end

local function encodeArray(value)
    local encoded = {}

    for index, entry in ipairs(value) do
        encoded[index] = toml.encodeValue(entry)
    end

    return "[" .. table.concat(encoded, ", ") .. "]"
end

function toml.encodeValue(value)
    local valueType = type(value)

    if valueType == "string" then
        return encodeString(value)
    end

    if valueType == "number" or valueType == "boolean" then
        return tostring(value)
    end

    if valueType == "table" and isPrimitiveArray(value) then
        return encodeArray(value)
    end

    error("Unsupported TOML value type: " .. valueType)
end

local function sortedKeys(value)
    local keys = {}
    for key, _ in pairs(value) do
        keys[#keys + 1] = key
    end

    table.sort(keys, function(left, right)
        if type(left) == type(right) then
            return tostring(left) < tostring(right)
        end

        return type(left) < type(right)
    end)

    return keys
end

local function formatPathSegment(segment)
    local text = tostring(segment)
    if isIdentifier(text) then
        return text
    end

    return encodeString(text)
end

local function joinPath(path)
    local parts = {}

    for index, segment in ipairs(path or {}) do
        parts[index] = formatPathSegment(segment)
    end

    return table.concat(parts, ".")
end

local function clonePath(path)
    local copy = {}

    for index, segment in ipairs(path or {}) do
        copy[index] = segment
    end

    return copy
end

local function appendPath(path, segment)
    local nextPath = clonePath(path)
    nextPath[#nextPath + 1] = segment
    return nextPath
end

local function writeSection(lines, path, value)
    local primitiveAssignments = {}
    local nestedTables = {}

    if #path > 0 then
        lines[#lines + 1] = "[" .. joinPath(path) .. "]"
    end

    for _, key in ipairs(sortedKeys(value)) do
        local entry = value[key]
        local entryType = type(entry)

        if isPrimitive(entry) or isPrimitiveArray(entry) then
            primitiveAssignments[#primitiveAssignments + 1] = {
                key = key,
                value = entry,
            }
        elseif entryType == "table" then
            nestedTables[#nestedTables + 1] = {
                key = key,
                value = entry,
            }
        else
            error("Unsupported TOML section value type: " .. entryType)
        end
    end

    for _, assignment in ipairs(primitiveAssignments) do
        lines[#lines + 1] = string.format("%s = %s", formatPathSegment(assignment.key), toml.encodeValue(assignment.value))
    end

    for _, nested in ipairs(nestedTables) do
        local nextPath = appendPath(path, nested.key)
        if isArray(nested.value) and not isPrimitiveArray(nested.value) then
            for index, entry in ipairs(nested.value) do
                if type(entry) ~= "table" then
                    error("Complex TOML arrays must contain tables.")
                end
                writeSection(lines, appendPath(nextPath, index), entry)
            end
        else
            writeSection(lines, nextPath, nested.value)
        end
    end
end

function toml.stringify(value)
    if type(value) ~= "table" then
        error("TOML root value must be a table.")
    end

    local lines = {}
    writeSection(lines, {}, value)
    return table.concat(lines, LINE_BREAK) .. LINE_BREAK
end

local function stripComment(line)
    local inString = false
    local escaped = false

    for index = 1, #line do
        local character = line:sub(index, index)
        if inString then
            if escaped then
                escaped = false
            elseif character == "\\" then
                escaped = true
            elseif character == QUOTE then
                inString = false
            end
        elseif character == QUOTE then
            inString = true
        elseif character == "#" then
            return line:sub(1, index - 1)
        end
    end

    return line
end

local function decodeString(raw)
    if raw:sub(1, 1) ~= QUOTE or raw:sub(-1) ~= QUOTE then
        return nil, "Expected a quoted TOML string."
    end

    local out = {}
    local escaped = false

    for index = 2, #raw - 1 do
        local character = raw:sub(index, index)
        if escaped then
            local decoded = UNESCAPE_MAP[character]
            if not decoded then
                return nil, "Unsupported TOML escape \\" .. character
            end
            out[#out + 1] = decoded
            escaped = false
        elseif character == "\\" then
            escaped = true
        else
            out[#out + 1] = character
        end
    end

    if escaped then
        return nil, "Unterminated TOML escape sequence."
    end

    return table.concat(out)
end

local function splitArrayValues(body)
    local values = {}
    local buffer = {}
    local depth = 0
    local inString = false
    local escaped = false

    for index = 1, #body do
        local character = body:sub(index, index)
        if inString then
            buffer[#buffer + 1] = character
            if escaped then
                escaped = false
            elseif character == "\\" then
                escaped = true
            elseif character == QUOTE then
                inString = false
            end
        else
            if character == QUOTE then
                inString = true
                buffer[#buffer + 1] = character
            elseif character == "[" then
                depth = depth + 1
                buffer[#buffer + 1] = character
            elseif character == "]" then
                depth = math.max(0, depth - 1)
                buffer[#buffer + 1] = character
            elseif character == "," and depth == 0 then
                values[#values + 1] = trim(table.concat(buffer))
                buffer = {}
            else
                buffer[#buffer + 1] = character
            end
        end
    end

    if inString then
        return nil, "Unterminated string in TOML array."
    end

    local trailing = trim(table.concat(buffer))
    if trailing ~= "" then
        values[#values + 1] = trailing
    end

    return values
end

local function parseArray(raw)
    local body = trim(raw:sub(2, -2))
    if body == "" then
        return {}
    end

    local values, splitError = splitArrayValues(body)
    if not values then
        return nil, splitError
    end

    local array = {}
    for index, token in ipairs(values) do
        local parsedValue, parseError = toml.parseValue(token)
        if parseError then
            return nil, parseError
        end
        array[index] = parsedValue
    end

    return array
end

function toml.parseValue(raw)
    local value = trim(raw)
    if value:sub(1, 1) == QUOTE and value:sub(-1) == QUOTE then
        return decodeString(value)
    end

    if value:sub(1, 1) == "[" and value:sub(-1) == "]" then
        return parseArray(value)
    end

    if value == "true" then
        return true
    end

    if value == "false" then
        return false
    end

    local numberValue = tonumber(value)
    if numberValue ~= nil then
        return numberValue
    end

    return value
end

local function parsePath(path)
    local segments = {}
    local buffer = {}
    local inString = false
    local escaped = false

    for index = 1, #path do
        local character = path:sub(index, index)
        if inString then
            buffer[#buffer + 1] = character
            if escaped then
                escaped = false
            elseif character == "\\" then
                escaped = true
            elseif character == QUOTE then
                inString = false
            end
        else
            if character == QUOTE then
                inString = true
                buffer[#buffer + 1] = character
            elseif character == "." then
                local token = trim(table.concat(buffer))
                if token ~= "" then
                    if token:sub(1, 1) == QUOTE then
                        local decoded, decodeError = decodeString(token)
                        if not decoded then
                            return nil, decodeError
                        end
                        segments[#segments + 1] = decoded
                    else
                        segments[#segments + 1] = token
                    end
                end
                buffer = {}
            else
                buffer[#buffer + 1] = character
            end
        end
    end

    local trailing = trim(table.concat(buffer))
    if trailing ~= "" then
        if trailing:sub(1, 1) == QUOTE then
            local decoded, decodeError = decodeString(trailing)
            if not decoded then
                return nil, decodeError
            end
            segments[#segments + 1] = decoded
        else
            segments[#segments + 1] = trailing
        end
    end

    return segments
end

local function getContainerEntry(container, segment)
    local numericIndex = isIntegerString(segment) and tonumber(segment) or nil
    if numericIndex then
        return container[numericIndex], numericIndex
    end

    return container[segment], segment
end

local function setContainerEntry(container, segment, value)
    local numericIndex = isIntegerString(segment) and tonumber(segment) or nil
    if numericIndex then
        container[numericIndex] = value
        return
    end

    container[segment] = value
end

local function ensurePath(root, path)
    local current = root

    for _, segment in ipairs(path) do
        local existing, resolvedKey = getContainerEntry(current, segment)
        if type(existing) ~= "table" then
            existing = {}
            current[resolvedKey] = existing
        end
        current = existing
    end

    return current
end

function toml.parse(content)
    local result = {}
    local currentPath = {}
    local lineNumber = 0

    for line in (tostring(content or "") .. LINE_BREAK):gmatch("(.-)\n") do
        lineNumber = lineNumber + 1
        local cleaned = trim(stripComment(line))

        if cleaned ~= "" then
            local tablePath = cleaned:match("^%[(.+)%]$")
            if tablePath then
                local parsedPath, pathError = parsePath(trim(tablePath))
                if not parsedPath then
                    return nil, string.format("TOML parse error on line %d: %s", lineNumber, pathError)
                end
                ensurePath(result, parsedPath)
                currentPath = parsedPath
            else
                local key, rawValue = cleaned:match("^(.-)%s*=%s*(.+)$")
                if not key or not rawValue then
                    return nil, string.format("TOML parse error on line %d: %s", lineNumber, cleaned)
                end

                local parsedKey, keyError = parsePath(trim(key))
                if not parsedKey then
                    return nil, string.format("TOML parse error on line %d: %s", lineNumber, keyError)
                end

                local parsedValue, valueError = toml.parseValue(rawValue)
                if valueError then
                    return nil, string.format("TOML parse error on line %d: %s", lineNumber, valueError)
                end

                local fullPath = clonePath(currentPath)
                for _, segment in ipairs(parsedKey) do
                    fullPath[#fullPath + 1] = segment
                end

                local leaf = fullPath[#fullPath]
                fullPath[#fullPath] = nil
                local parent = ensurePath(result, fullPath)
                setContainerEntry(parent, leaf, parsedValue)
            end
        end
    end

    return result
end

function toml.parseFile(path)
    local data
    local readError

    if love and love.filesystem and love.filesystem.read then
        data, readError = love.filesystem.read(path)
    else
        local handle = io.open(path, "rb")
        if handle then
            data = handle:read("*a")
            handle:close()
        else
            readError = "Unable to open TOML file."
        end
    end

    if not data then
        return nil, readError or ("Unable to read TOML file: " .. tostring(path))
    end

    return toml.parse(data)
end

return toml
