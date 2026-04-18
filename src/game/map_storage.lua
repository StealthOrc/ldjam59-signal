local mapStorage = {}
local authoredMap = require("src.game.authored_map")

local USER_MAP_DIR = "maps"
local BUILTIN_MAP_DIR = "src/game/maps"

local function ensureUserMapDirectory()
    if not love.filesystem.getInfo(USER_MAP_DIR, "directory") then
        love.filesystem.createDirectory(USER_MAP_DIR)
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
        return nil, "map file did not return a table"
    end

    return data
end

local function buildPath(source, fileName)
    if source == "builtin" then
        return BUILTIN_MAP_DIR .. "/" .. fileName
    end

    ensureUserMapDirectory()
    return USER_MAP_DIR .. "/" .. fileName
end

local function buildDescriptor(source, fileName, data)
    return {
        id = source .. ":" .. fileName,
        source = source,
        name = data.name or fileName:gsub("%.lua$", ""),
        fileName = fileName,
        path = buildPath(source, fileName),
        savedAt = data.savedAt,
        hasEditor = data.editor ~= nil,
        hasLevel = data.level ~= nil,
        hasErrors = #((data.validationErrors) or {}) > 0,
        isTemplate = source == "builtin" and data.template == true,
        previewLevel = data.level,
        previewDescription = data.previewDescription or (data.level and (data.level.previewDescription or data.level.description)) or nil,
    }
end

local function listSourceMaps(source, directory)
    local maps = {}
    if not love.filesystem.getInfo(directory, "directory") then
        return maps
    end

    local fileNames = love.filesystem.getDirectoryItems(directory)
    table.sort(fileNames)

    for _, fileName in ipairs(fileNames) do
        if fileName:sub(-4) == ".lua" then
            local data = mapStorage.loadMap(fileName, source)
            if data then
                maps[#maps + 1] = buildDescriptor(source, fileName, data)
            end
        end
    end

    return maps
end

function mapStorage.saveMap(name, payload)
    ensureUserMapDirectory()

    local fileName = sanitizeFileName(name)
    local path = USER_MAP_DIR .. "/" .. fileName
    local body = "return " .. serializeValue(payload) .. "\n"
    local ok, writeError = love.filesystem.write(path, body)
    if not ok then
        return nil, writeError
    end

    return buildDescriptor("user", fileName, payload)
end

function mapStorage.loadMap(fileNameOrDescriptor, source)
    local fileName = fileNameOrDescriptor
    local resolvedSource = source or "user"

    if type(fileNameOrDescriptor) == "table" then
        fileName = fileNameOrDescriptor.fileName
        resolvedSource = fileNameOrDescriptor.source or resolvedSource
    end

    if not fileName then
        return nil, "map file name missing"
    end

    local path = buildPath(resolvedSource, fileName)
    local data, loadError = loadMapFile(path)
    if not data then
        return nil, loadError
    end

    data.fileName = fileName
    data.path = path
    data.source = resolvedSource
    data.isTemplate = resolvedSource == "builtin" and data.template == true
    data.validationErrors = {}
    data.validationErrorText = nil
    if data.editor then
        local level, errorText, errors = authoredMap.buildPlayableLevel(data.name or fileName:gsub("%.lua$", ""), data.editor)
        data.validationErrors = errors or {}
        data.validationErrorText = errorText
        if level then
            data.level = level
        end
    end
    return data
end

function mapStorage.listMaps()
    local maps = {}

    for _, descriptor in ipairs(listSourceMaps("builtin", BUILTIN_MAP_DIR)) do
        maps[#maps + 1] = descriptor
    end

    for _, descriptor in ipairs(listSourceMaps("user", USER_MAP_DIR)) do
        maps[#maps + 1] = descriptor
    end

    table.sort(maps, function(a, b)
        if a.source ~= b.source then
            return a.source == "builtin"
        end
        return string.lower(a.name) < string.lower(b.name)
    end)

    return maps
end

function mapStorage.getSaveDirectory()
    ensureUserMapDirectory()
    return love.filesystem.getSaveDirectory() .. "/" .. USER_MAP_DIR
end

function mapStorage.getBuiltinDirectory()
    return BUILTIN_MAP_DIR
end

return mapStorage
