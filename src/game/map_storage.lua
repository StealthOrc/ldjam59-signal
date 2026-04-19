local mapStorage = {}
local authoredMap = require("src.game.authored_map")
local uuid = require("src.game.uuid")

local USER_MAP_DIR = "maps/user"
local DOWNLOADED_MAP_DIR = "maps/downloaded"
local BUILTIN_MAP_DIR = "src/game/maps"
local BUILTIN_TUTORIAL_DIR = BUILTIN_MAP_DIR .. "/tutorial"
local BUILTIN_CAMPAIGN_DIR = BUILTIN_MAP_DIR .. "/campaign"
local IMPORT_DUPLICATE_START_INDEX = 2

local function ensureUserMapDirectory()
    if not love.filesystem.getInfo("maps", "directory") then
        love.filesystem.createDirectory("maps")
    end
    if not love.filesystem.getInfo(USER_MAP_DIR, "directory") then
        love.filesystem.createDirectory(USER_MAP_DIR)
    end
end

local function ensureDownloadedMapDirectory()
    if not love.filesystem.getInfo("maps", "directory") then
        love.filesystem.createDirectory("maps")
    end
    if not love.filesystem.getInfo(DOWNLOADED_MAP_DIR, "directory") then
        love.filesystem.createDirectory(DOWNLOADED_MAP_DIR)
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

local function splitFileName(fileName)
    local baseName, extension = tostring(fileName or ""):match("^(.*)(%.[^%.]+)$")
    if baseName then
        return baseName, extension
    end

    return tostring(fileName or ""), ""
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

local function writeMapFile(path, payload)
    local body = "return " .. serializeValue(payload) .. "\n"
    return love.filesystem.write(path, body)
end

local function getBuiltinDirectory(mapKind)
    if mapKind == "tutorial" then
        return BUILTIN_TUTORIAL_DIR
    end

    return BUILTIN_CAMPAIGN_DIR
end

local function getMapPath(source, fileName, directory)
    if source == "builtin" then
        return directory .. "/" .. fileName
    end

    -- For user maps, try downloaded first, then user
    if love.filesystem.getInfo(DOWNLOADED_MAP_DIR .. "/" .. fileName, "file") then
        return DOWNLOADED_MAP_DIR .. "/" .. fileName
    end

    if love.filesystem.getInfo(USER_MAP_DIR .. "/" .. fileName, "file") then
        return USER_MAP_DIR .. "/" .. fileName
    end

    -- Default to user directory if file doesn't exist yet
    return USER_MAP_DIR .. "/" .. fileName
end

local function buildPath(source, fileName, mapKind, directory, isRemoteImport)
    if source == "builtin" then
        local builtinDirectory = directory or getBuiltinDirectory(mapKind)
        return builtinDirectory .. "/" .. fileName
    end

    if isRemoteImport then
        ensureDownloadedMapDirectory()
        return DOWNLOADED_MAP_DIR .. "/" .. fileName
    end

    ensureUserMapDirectory()
    return USER_MAP_DIR .. "/" .. fileName
end

local function inferMapKind(source, data, directory)
    if source == "user" then
        return "user"
    end

    if directory == BUILTIN_TUTORIAL_DIR then
        return "tutorial"
    end

    if directory == BUILTIN_CAMPAIGN_DIR then
        return "campaign"
    end

    local description = string.lower(((data.level and data.level.description) or data.description or ""))
    if description:match("^tutorial:") then
        return "tutorial"
    end

    return "campaign"
end

local function buildDisplayName(name, fileName)
    local rawName = name or fileName:gsub("%.lua$", "")
    local cleanedName = rawName:gsub("^Map%s+%d+:%s*", "")
    if cleanedName == "" then
        return rawName
    end
    return cleanedName
end

local function buildDescriptor(source, fileName, data, options)
     local name = data.name or fileName:gsub("%.lua$", "")
     local descriptorOptions = options or {}
     local mapKind = descriptorOptions.mapKind or inferMapKind(source, data, descriptorOptions.directory)
     local isRemoteImport = type(data.remoteSource) == "table" or descriptorOptions.isFromDownloadedDir
     return {
         id = source .. ":" .. fileName,
         mapUuid = data.mapUuid,
         source = source,
         name = name,
         displayName = buildDisplayName(name, fileName),
         mapKind = mapKind,
         fileName = fileName,
         path = buildPath(source, fileName, mapKind, descriptorOptions.directory, isRemoteImport),
         builtinDirectory = descriptorOptions.directory,
         savedAt = data.savedAt,
         hasEditor = data.editor ~= nil,
         hasLevel = data.level ~= nil,
         hasErrors = #((data.validationErrors) or {}) > 0,
         isTemplate = source == "builtin" and data.template == true,
         previewLevel = data.level,
         previewDescription = data.previewDescription or (data.level and (data.level.previewDescription or data.level.description)) or nil,
         isRemoteImport = isRemoteImport,
         remoteSource = data.remoteSource,
     }
 end

local function findUserMapFileNameByUuid(mapUuid)
    if type(mapUuid) ~= "string" or mapUuid == "" then
        return nil
    end

    ensureUserMapDirectory()
    for _, fileName in ipairs(love.filesystem.getDirectoryItems(USER_MAP_DIR)) do
        if fileName:sub(-4) == ".lua" then
            local data = mapStorage.loadMap(fileName, "user")
            if data and data.mapUuid == mapUuid then
                return fileName
            end
        end
    end

    ensureDownloadedMapDirectory()
    for _, fileName in ipairs(love.filesystem.getDirectoryItems(DOWNLOADED_MAP_DIR)) do
        if fileName:sub(-4) == ".lua" then
            local data = mapStorage.loadMap(fileName, "user")
            if data and data.mapUuid == mapUuid then
                return fileName
            end
        end
    end

    return nil
end

local function resolveImportedFileName(name, payload)
    local mapUuid = type(payload) == "table" and payload.mapUuid or nil
    local existingFileName = findUserMapFileNameByUuid(mapUuid)
    if existingFileName then
        return existingFileName
    end

    local baseFileName = sanitizeFileName(name)
    local baseName, extension = splitFileName(baseFileName)
    local candidateFileName = baseFileName
    local duplicateIndex = IMPORT_DUPLICATE_START_INDEX

    while love.filesystem.getInfo(USER_MAP_DIR .. "/" .. candidateFileName, "file") or
          love.filesystem.getInfo(DOWNLOADED_MAP_DIR .. "/" .. candidateFileName, "file") do
        candidateFileName = string.format("%s_%d%s", baseName, duplicateIndex, extension)
        duplicateIndex = duplicateIndex + 1
    end

    return candidateFileName
end

local function listSourceMaps(source, directory, mapKind)
     local maps = {}
     if not love.filesystem.getInfo(directory, "directory") then
         return maps
     end

     local fileNames = love.filesystem.getDirectoryItems(directory)
     table.sort(fileNames)

     -- Normalize directory path for comparison
     local normalizedDir = (directory or ""):gsub("\\", "/")
     local normalizedDownloadedDir = DOWNLOADED_MAP_DIR:gsub("\\", "/")
     local isDownloadedDir = normalizedDir == normalizedDownloadedDir

     for _, fileName in ipairs(fileNames) do
         if fileName:sub(-4) == ".lua" then
             local data = mapStorage.loadMap(fileName, source, mapKind, directory)
             if data then
                 maps[#maps + 1] = buildDescriptor(source, fileName, data, {
                     mapKind = mapKind,
                     directory = directory,
                     isFromDownloadedDir = isDownloadedDir,
                 })
             end
         end
     end

     return maps
 end

function mapStorage.saveMap(name, payload)
    ensureUserMapDirectory()

    local fileName = sanitizeFileName(name)
    local path = USER_MAP_DIR .. "/" .. fileName
    payload.mapUuid = payload.mapUuid or uuid.generateV4()
    if payload.level then
        payload.level.id = payload.mapUuid
        payload.level.mapUuid = payload.mapUuid
    end

    local ok, writeError = writeMapFile(path, payload)
    if not ok then
        return nil, writeError
    end

    return buildDescriptor("user", fileName, payload)
end

function mapStorage.importMap(name, payload)
    local resolvedPayload = payload or {}
    local isRemoteImport = type(resolvedPayload.remoteSource) == "table"

    if isRemoteImport then
        ensureDownloadedMapDirectory()
    else
        ensureUserMapDirectory()
    end

    local fileName = resolveImportedFileName(name, payload or {})
    local directory = isRemoteImport and DOWNLOADED_MAP_DIR or USER_MAP_DIR
    local path = directory .. "/" .. fileName

    resolvedPayload.mapUuid = resolvedPayload.mapUuid or uuid.generateV4()
    if resolvedPayload.level then
        resolvedPayload.level.id = resolvedPayload.mapUuid
        resolvedPayload.level.mapUuid = resolvedPayload.mapUuid
    end

    local ok, writeError = writeMapFile(path, resolvedPayload)
    if not ok then
        return nil, writeError
    end

    return buildDescriptor("user", fileName, resolvedPayload)
end

function mapStorage.loadMap(fileNameOrDescriptor, source, mapKind, directory)
    local fileName = fileNameOrDescriptor
    local resolvedSource = source or "user"
    local resolvedMapKind = mapKind
    local resolvedDirectory = directory

    if type(fileNameOrDescriptor) == "table" then
        fileName = fileNameOrDescriptor.fileName
        resolvedSource = fileNameOrDescriptor.source or resolvedSource
        resolvedMapKind = fileNameOrDescriptor.mapKind or resolvedMapKind
        resolvedDirectory = fileNameOrDescriptor.builtinDirectory or resolvedDirectory
    end

    if not fileName then
        return nil, "map file name missing"
    end

    local path = getMapPath(resolvedSource, fileName, resolvedDirectory)
    local data, loadError = loadMapFile(path)
    if not data then
        return nil, loadError
    end

    if type(data.mapUuid) ~= "string" or data.mapUuid == "" then
        if resolvedSource == "user" then
            data.mapUuid = uuid.generateV4()
            writeMapFile(path, data)
        elseif type(data.level) == "table" and type(data.level.id) == "string" and data.level.id ~= "" then
            data.mapUuid = data.level.id
        else
            data.mapUuid = "builtin-" .. fileName:gsub("%.lua$", "")
        end
    end

    if data.level then
        data.level.id = data.mapUuid
        data.level.mapUuid = data.mapUuid
    end

    data.fileName = fileName
    data.path = path
    data.source = resolvedSource
    data.mapKind = inferMapKind(resolvedSource, data, resolvedDirectory)
    data.builtinDirectory = resolvedDirectory
    data.isTemplate = resolvedSource == "builtin" and data.template == true
    data.validationErrors = {}
    data.validationErrorText = nil
    if data.editor then
        local existingLevel = data.level
        local level, errorText, errors = authoredMap.buildPlayableLevel(data.name or fileName:gsub("%.lua$", ""), data.editor, data.mapUuid)
        data.validationErrors = errors or {}
        data.validationErrorText = errorText
        if level then
            if existingLevel then
                level.title = existingLevel.title or level.title
                level.description = existingLevel.description or level.description
                level.hint = existingLevel.hint or level.hint
                level.footer = existingLevel.footer or level.footer
                if existingLevel.timeLimit ~= nil then
                    level.timeLimit = existingLevel.timeLimit
                end
            end
            data.level = level
        end
    end
    return data
end

function mapStorage.listMaps()
     local maps = {}

     for _, descriptor in ipairs(listSourceMaps("builtin", BUILTIN_TUTORIAL_DIR, "tutorial")) do
         maps[#maps + 1] = descriptor
     end

     for _, descriptor in ipairs(listSourceMaps("builtin", BUILTIN_CAMPAIGN_DIR, "campaign")) do
         maps[#maps + 1] = descriptor
     end

     for _, descriptor in ipairs(listSourceMaps("user", USER_MAP_DIR, "user")) do
         maps[#maps + 1] = descriptor
     end

     for _, descriptor in ipairs(listSourceMaps("user", DOWNLOADED_MAP_DIR, "user")) do
         maps[#maps + 1] = descriptor
     end

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
