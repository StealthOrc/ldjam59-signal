local mapStorage = {}

local MAP_DIR = "maps"

local function ensureMapDirectory()
    if not love.filesystem.getInfo(MAP_DIR, "directory") then
        love.filesystem.createDirectory(MAP_DIR)
    end
end

local function sanitizeFileName(name)
    local slug = string.lower(name or "")
    slug = slug:gsub("[^%w]+", "_")
    slug = slug:gsub("^_+", "")
    slug = slug:gsub("_+$", "")

    if slug == "" then
        slug = "map"
    end

    return slug .. ".lua"
end

local function isIdentifier(value)
    return type(value) == "string" and value:match("^[%a_][%w_]*$") ~= nil
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

local function sortedKeys(value)
    local keys = {}
    for key, _ in pairs(value) do
        keys[#keys + 1] = key
    end

    table.sort(keys, function(a, b)
        if type(a) == type(b) then
            return a < b
        end
        return tostring(a) < tostring(b)
    end)

    return keys
end

local function serializeValue(value, indent)
    local valueType = type(value)
    indent = indent or 0

    if valueType == "nil" then
        return "nil"
    end

    if valueType == "number" or valueType == "boolean" then
        return tostring(value)
    end

    if valueType == "string" then
        return string.format("%q", value)
    end

    if valueType ~= "table" then
        error("Unsupported map save value type: " .. valueType)
    end

    local nextIndent = indent + 4
    local prefix = string.rep(" ", nextIndent)
    local closingIndent = string.rep(" ", indent)
    local lines = { "{" }

    if isArray(value) then
        for _, entry in ipairs(value) do
            lines[#lines + 1] = prefix .. serializeValue(entry, nextIndent) .. ","
        end
    else
        for _, key in ipairs(sortedKeys(value)) do
            local keyText
            if isIdentifier(key) then
                keyText = key
            else
                keyText = "[" .. serializeValue(key, nextIndent) .. "]"
            end
            lines[#lines + 1] = prefix .. keyText .. " = " .. serializeValue(value[key], nextIndent) .. ","
        end
    end

    lines[#lines + 1] = closingIndent .. "}"
    return table.concat(lines, "\n")
end

local function loadMapFile(path)
    local chunk, loadError = love.filesystem.load(path)
    if not chunk then
        return nil, loadError
    end

    local ok, data = pcall(chunk)
    if not ok then
        return nil, data
    end

    if type(data) ~= "table" then
        return nil, "saved map did not return a table"
    end

    return data
end

function mapStorage.saveMap(name, payload)
    ensureMapDirectory()

    local fileName = sanitizeFileName(name)
    local path = MAP_DIR .. "/" .. fileName
    local body = "return " .. serializeValue(payload) .. "\n"
    local ok, writeError = love.filesystem.write(path, body)
    if not ok then
        return nil, writeError
    end

    return {
        name = payload.name or name,
        fileName = fileName,
        path = path,
    }
end

function mapStorage.loadMap(fileName)
    ensureMapDirectory()
    local path = MAP_DIR .. "/" .. fileName
    local data, loadError = loadMapFile(path)
    if not data then
        return nil, loadError
    end

    data.fileName = fileName
    data.path = path
    return data
end

function mapStorage.listMaps()
    ensureMapDirectory()

    local maps = {}
    for _, fileName in ipairs(love.filesystem.getDirectoryItems(MAP_DIR)) do
        if fileName:sub(-4) == ".lua" then
            local data = mapStorage.loadMap(fileName)
            if data then
                maps[#maps + 1] = {
                    name = data.name or fileName:gsub("%.lua$", ""),
                    fileName = fileName,
                    savedAt = data.savedAt,
                    hasEditor = data.editor ~= nil,
                    hasLevel = data.level ~= nil,
                    level = data.level,
                }
            end
        end
    end

    table.sort(maps, function(a, b)
        return string.lower(a.name) < string.lower(b.name)
    end)

    return maps
end

function mapStorage.getSaveDirectory()
    ensureMapDirectory()
    return love.filesystem.getSaveDirectory() .. "/" .. MAP_DIR
end

return mapStorage
