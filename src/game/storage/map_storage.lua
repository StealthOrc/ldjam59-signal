local mapStorage = {}
local mapCompiler = require("src.game.map_compiler.map_compiler")
local mapHash = require("src.game.util.map_hash")
local mapRevision = require("src.game.util.map_revision")
local toml = require("src.game.util.toml")
local uuid = require("src.game.util.uuid")

local USER_MAP_DIR = "maps/user"
local DOWNLOADED_MAP_DIR = "maps/downloaded"
local BUILTIN_MAP_DIR = "src/game/data/maps"
local BUILTIN_TUTORIAL_DIR = BUILTIN_MAP_DIR .. "/tutorial"
local BUILTIN_CAMPAIGN_DIR = BUILTIN_MAP_DIR .. "/campaign"
local IMPORT_DUPLICATE_START_INDEX = 2
local MAP_FILE_EXTENSION = ".toml"
local MAP_FILE_PATTERN = "%.toml$"

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, entry in pairs(value) do
        copy[key] = deepCopy(entry)
    end

    return copy
end

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

local function stripFileExtension(fileName)
    return tostring(fileName or ""):gsub(MAP_FILE_PATTERN, "")
end

local function sanitizeFileName(name)
    local slug = string.lower(name or "")
    slug = slug:gsub("[^%w]+", "_")
    slug = slug:gsub("^_+", "")
    slug = slug:gsub("_+$", "")

    if slug == "" then
        slug = "map"
    end

    return slug .. MAP_FILE_EXTENSION
end

local function splitFileName(fileName)
    local baseName, extension = tostring(fileName or ""):match("^(.*)(%.[^%.]+)$")
    if baseName then
        return baseName, extension
    end

    return tostring(fileName or ""), ""
end

local function loadMapFile(path)
    return toml.parseFile(path)
end

local function writeMapFile(path, payload)
    return love.filesystem.write(path, toml.stringify(payload))
end

local function createPersistedPayload(payload)
    local persistedPayload = deepCopy(payload)
    persistedPayload.mapHash = nil
    return persistedPayload
end

local function attachComputedMapHash(data)
    if type(data) ~= "table" then
        return data
    end

    data.mapHash = mapHash.computeForLevel(data.level)
    return data
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

    if type(directory) == "string" and directory ~= "" then
        return directory .. "/" .. fileName
    end

    if love.filesystem.getInfo(DOWNLOADED_MAP_DIR .. "/" .. fileName, "file") then
        return DOWNLOADED_MAP_DIR .. "/" .. fileName
    end

    if love.filesystem.getInfo(USER_MAP_DIR .. "/" .. fileName, "file") then
        return USER_MAP_DIR .. "/" .. fileName
    end

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
    local rawName = name or stripFileExtension(fileName)
    local cleanedName = rawName:gsub("^Map%s+%d+:%s*", "")
    if cleanedName == "" then
        return rawName
    end

    return cleanedName
end

local function buildDescriptor(source, fileName, data, options)
    local name = data.name or stripFileExtension(fileName)
    local descriptorOptions = options or {}
    local mapKind = descriptorOptions.mapKind or inferMapKind(source, data, descriptorOptions.directory)
    local isRemoteImport = type(data.remoteSource) == "table" or descriptorOptions.isFromDownloadedDir
    local revisionNumber = mapRevision.sanitizeRevisionNumber(
        data.revisionNumber
            or data.revision_number
            or data.remoteSource and (data.remoteSource.revisionNumber or data.remoteSource.revision_number)
            or nil
    )
    local totalPlayCount = tonumber(
        data.totalPlayCount
            or data.total_play_count
            or data.remoteSource and (data.remoteSource.totalPlayCount or data.remoteSource.total_play_count)
            or 0
    ) or 0
    local playerTotalPlayCount = tonumber(
        data.playerTotalPlayCount
            or data.player_total_play_count
            or data.remoteSource and (data.remoteSource.playerTotalPlayCount or data.remoteSource.player_total_play_count)
            or 0
    ) or 0
    local revisionPlayCount = tonumber(
        data.revisionPlayCount
            or data.revision_play_count
            or data.remoteSource and (data.remoteSource.revisionPlayCount or data.remoteSource.revision_play_count)
            or 0
    ) or 0
    local playerRevisionPlayCount = tonumber(
        data.playerRevisionPlayCount
            or data.player_revision_play_count
            or data.remoteSource and (data.remoteSource.playerRevisionPlayCount or data.remoteSource.player_revision_play_count)
            or 0
    ) or 0
    local hasRemotePlayStats = type(data.remoteSource) == "table"
    local descriptorSourceId = source == "builtin"
        and source
        or (isRemoteImport and "downloaded" or "user")
    return {
        id = descriptorSourceId .. ":" .. fileName,
        mapUuid = data.mapUuid,
        source = source,
        name = name,
        displayName = buildDisplayName(name, fileName),
        mapKind = mapKind,
        fileName = fileName,
        path = buildPath(source, fileName, mapKind, descriptorOptions.directory, isRemoteImport),
        storageDirectory = descriptorOptions.directory,
        builtinDirectory = descriptorOptions.directory,
        savedAt = data.savedAt,
        mapHash = data.mapHash,
        revisionNumber = revisionNumber,
        revisionLabel = mapRevision.formatRevisionLabel(revisionNumber),
        totalPlayCount = totalPlayCount,
        playerTotalPlayCount = playerTotalPlayCount,
        revisionPlayCount = revisionPlayCount,
        playerRevisionPlayCount = playerRevisionPlayCount,
        hasRemotePlayStats = hasRemotePlayStats,
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
        if fileName:match(MAP_FILE_PATTERN) then
            local data = mapStorage.loadMap(fileName, "user", "user", USER_MAP_DIR)
            if data and data.mapUuid == mapUuid then
                return fileName
            end
        end
    end

    ensureDownloadedMapDirectory()
    for _, fileName in ipairs(love.filesystem.getDirectoryItems(DOWNLOADED_MAP_DIR)) do
        if fileName:match(MAP_FILE_PATTERN) then
            local data = mapStorage.loadMap(fileName, "user", "user", DOWNLOADED_MAP_DIR)
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

    while love.filesystem.getInfo(USER_MAP_DIR .. "/" .. candidateFileName, "file")
        or love.filesystem.getInfo(DOWNLOADED_MAP_DIR .. "/" .. candidateFileName, "file") do
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

    local normalizedDir = (directory or ""):gsub("\\", "/")
    local normalizedDownloadedDir = DOWNLOADED_MAP_DIR:gsub("\\", "/")
    local isDownloadedDir = normalizedDir == normalizedDownloadedDir

    for _, fileName in ipairs(fileNames) do
        if fileName:match(MAP_FILE_PATTERN) then
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

local function ensureMapPayload(payload)
    local resolvedPayload = type(payload) == "table" and payload or {}
    resolvedPayload.mapUuid = resolvedPayload.mapUuid or uuid.generateV4()
    if resolvedPayload.level then
        resolvedPayload.level.id = resolvedPayload.mapUuid
        resolvedPayload.level.mapUuid = resolvedPayload.mapUuid
    end

    return resolvedPayload
end

function mapStorage.saveMap(name, payload)
    ensureUserMapDirectory()

    local fileName = sanitizeFileName(name)
    local path = USER_MAP_DIR .. "/" .. fileName
    local resolvedPayload = ensureMapPayload(payload)
    attachComputedMapHash(resolvedPayload)
    resolvedPayload.revisionNumber = mapRevision.sanitizeRevisionNumber(
        resolvedPayload.revisionNumber
            or resolvedPayload.revision_number
    )

    local ok, writeError = writeMapFile(path, createPersistedPayload(resolvedPayload))
    if not ok then
        return nil, writeError
    end

    return buildDescriptor("user", fileName, resolvedPayload, {
        mapKind = "user",
        directory = USER_MAP_DIR,
    })
end

function mapStorage.importMap(name, payload)
    local resolvedPayload = ensureMapPayload(payload)
    attachComputedMapHash(resolvedPayload)
    local isRemoteImport = type(resolvedPayload.remoteSource) == "table"

    if isRemoteImport then
        ensureDownloadedMapDirectory()
    else
        ensureUserMapDirectory()
    end

    local fileName = resolveImportedFileName(name, resolvedPayload)
    local directory = isRemoteImport and DOWNLOADED_MAP_DIR or USER_MAP_DIR
    local path = directory .. "/" .. fileName

    local ok, writeError = writeMapFile(path, createPersistedPayload(resolvedPayload))
    if not ok then
        return nil, writeError
    end

    return buildDescriptor("user", fileName, resolvedPayload, {
        mapKind = "user",
        directory = directory,
        isFromDownloadedDir = isRemoteImport,
    })
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
        resolvedDirectory = fileNameOrDescriptor.storageDirectory
            or fileNameOrDescriptor.builtinDirectory
            or resolvedDirectory
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
            data.mapUuid = "builtin-" .. stripFileExtension(fileName)
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
        local level, errorText, errors = mapCompiler.buildPlayableLevel(
            data.name or stripFileExtension(fileName),
            data.editor,
            data.mapUuid
        )
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
    attachComputedMapHash(data)
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
