local envLoader = {}

local ENV_FILE = ".env"
local BUILD_ENV_FILE = "build.env"
local MIN_QUOTED_LENGTH = 2
local DIRECTORY_SEPARATOR = package.config:sub(1, 1)
local UTF8_BOM_FIRST_BYTE = 239
local UTF8_BOM_SECOND_BYTE = 187
local UTF8_BOM_THIRD_BYTE = 191
local REQUIRED_KEYS = {
    "API_KEY",
    "API_BASE_URL",
}
local OPTIONAL_KEYS = {
    "HMAC_SECRET",
}
local SOURCE_WORKING_DIRECTORY = "working directory .env"
local SOURCE_WORKING_DIRECTORY_BUILD = "working directory build.env"
local SOURCE_LOVE_FILESYSTEM = "project .env"
local SOURCE_LOVE_FILESYSTEM_BUILD = "project build.env"
local SOURCE_SOURCE_DIRECTORY = "source directory .env"
local SOURCE_SOURCE_DIRECTORY_BUILD = "source directory build.env"
local SOURCE_SAVE_DIRECTORY = "save directory .env"
local SOURCE_SAVE_DIRECTORY_BUILD = "save directory build.env"
local SOURCE_PROCESS_ENVIRONMENT = "process environment"
local LOCAL_CONFIG_SOURCES = {
    [SOURCE_WORKING_DIRECTORY] = true,
    [SOURCE_WORKING_DIRECTORY_BUILD] = true,
    [SOURCE_LOVE_FILESYSTEM] = true,
    [SOURCE_LOVE_FILESYSTEM_BUILD] = true,
    [SOURCE_SOURCE_DIRECTORY] = true,
    [SOURCE_SOURCE_DIRECTORY_BUILD] = true,
    [SOURCE_SAVE_DIRECTORY] = true,
    [SOURCE_SAVE_DIRECTORY_BUILD] = true,
}

local function trim(value)
    return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function stripQuotes(value)
    local trimmed = trim(value)
    local firstChar = trimmed:sub(1, 1)
    local lastChar = trimmed:sub(-1)
    if (#trimmed >= MIN_QUOTED_LENGTH) and ((firstChar == '"' and lastChar == '"') or (firstChar == "'" and lastChar == "'")) then
        return trimmed:sub(2, -2)
    end
    return trimmed
end

local function stripUtf8Bom(value)
    if type(value) ~= "string" then
        return value
    end

    if value:byte(1) == UTF8_BOM_FIRST_BYTE
        and value:byte(2) == UTF8_BOM_SECOND_BYTE
        and value:byte(3) == UTF8_BOM_THIRD_BYTE then
        return value:sub(4)
    end

    return value
end

local function readFile(path)
    local handle = io.open(path, "rb")
    if not handle then
        return nil
    end

    local content = handle:read("*a")
    handle:close()
    return content
end

local function parseEnvContent(content)
    local values = {}

    if not content then
        return values
    end

    local normalizedContent = stripUtf8Bom(content)

    for line in normalizedContent:gmatch("[^\r\n]+") do
        local trimmedLine = trim(line)
        if trimmedLine ~= "" and trimmedLine:sub(1, 1) ~= "#" then
            local key, value = trimmedLine:match("^([%w_]+)%s*=%s*(.*)$")
            if key then
                values[key] = stripQuotes(value)
            end
        end
    end

    return values
end

local function setValue(target, sourceByKey, key, value, sourceName, shouldOverride)
    local canAssign = shouldOverride or target[key] == nil or target[key] == ""
    if canAssign then
        target[key] = value
        sourceByKey[key] = sourceName
    end
end

local function mergeValues(target, sourceByKey, source, sourceName)
    for key, value in pairs(source or {}) do
        setValue(target, sourceByKey, key, value, sourceName, false)
    end
end

local function readLoveProjectFile(fileName)
    if not (love and love.filesystem and love.filesystem.getInfo) then
        return nil
    end

    if not love.filesystem.getInfo(fileName, "file") then
        return nil
    end

    return love.filesystem.read(fileName)
end

local function readLoveEnvFile()
    return readLoveProjectFile(ENV_FILE), SOURCE_LOVE_FILESYSTEM
end

local function readLoveBuildEnvFile()
    return readLoveProjectFile(BUILD_ENV_FILE), SOURCE_LOVE_FILESYSTEM_BUILD
end

local function readSourceDirectoryFile(fileName)
    if not (love and love.filesystem and love.filesystem.getSourceBaseDirectory and love.filesystem.getSource) then
        return nil
    end

    local sourceBaseDirectory = love.filesystem.getSourceBaseDirectory()
    local sourceName = love.filesystem.getSource()
    if not sourceBaseDirectory or sourceBaseDirectory == "" or not sourceName or sourceName == "" then
        return nil
    end

    local sourceFilePath = sourceBaseDirectory .. DIRECTORY_SEPARATOR .. sourceName .. DIRECTORY_SEPARATOR .. fileName
    return readFile(sourceFilePath)
end

local function readSourceDirectoryEnvFile()
    return readSourceDirectoryFile(ENV_FILE), SOURCE_SOURCE_DIRECTORY
end

local function readSourceDirectoryBuildEnvFile()
    return readSourceDirectoryFile(BUILD_ENV_FILE), SOURCE_SOURCE_DIRECTORY_BUILD
end

local function readSaveDirectoryFile(fileName)
    if not (love and love.filesystem and love.filesystem.getSaveDirectory) then
        return nil
    end

    local saveDirectory = love.filesystem.getSaveDirectory()
    if not saveDirectory or saveDirectory == "" then
        return nil
    end

    return readFile(saveDirectory .. DIRECTORY_SEPARATOR .. fileName)
end

local function readSaveDirectoryEnvFile()
    return readSaveDirectoryFile(ENV_FILE), SOURCE_SAVE_DIRECTORY
end

local function readSaveDirectoryBuildEnvFile()
    return readSaveDirectoryFile(BUILD_ENV_FILE), SOURCE_SAVE_DIRECTORY_BUILD
end

local function readEnvValues()
    local values = {}
    local sourceByKey = {}
    local loadedSourceCount = 0

    local fileReaders = {
        {
            read = readLoveBuildEnvFile,
        },
        {
            read = readLoveEnvFile,
        },
        {
            read = function()
                return readFile(BUILD_ENV_FILE), SOURCE_WORKING_DIRECTORY_BUILD
            end,
        },
        {
            read = function()
                return readFile(ENV_FILE), SOURCE_WORKING_DIRECTORY
            end,
        },
        {
            read = readSourceDirectoryBuildEnvFile,
        },
        {
            read = readSourceDirectoryEnvFile,
        },
        {
            read = readSaveDirectoryBuildEnvFile,
        },
        {
            read = readSaveDirectoryEnvFile,
        },
    }

    for _, fileReader in ipairs(fileReaders) do
        local content, sourceName = fileReader.read()
        if content then
            mergeValues(values, sourceByKey, parseEnvContent(content), sourceName)
            loadedSourceCount = loadedSourceCount + 1
        end
    end

    return values, sourceByKey, loadedSourceCount
end

local function applyProcessEnvironment(values, sourceByKey)
    for _, key in ipairs(REQUIRED_KEYS) do
        local environmentValue = os.getenv(key)
        if environmentValue and trim(environmentValue) ~= "" then
            setValue(values, sourceByKey, key, stripQuotes(environmentValue), SOURCE_PROCESS_ENVIRONMENT, true)
        end
    end

    for _, key in ipairs(OPTIONAL_KEYS) do
        local environmentValue = os.getenv(key)
        if environmentValue and trim(environmentValue) ~= "" then
            setValue(values, sourceByKey, key, stripQuotes(environmentValue), SOURCE_PROCESS_ENVIRONMENT, true)
        end
    end
end

local function hasLocalRequiredKeys(sourceByKey)
    for _, key in ipairs(REQUIRED_KEYS) do
        if not LOCAL_CONFIG_SOURCES[sourceByKey[key]] then
            return false
        end
    end

    return true
end

function envLoader.load()
    local values, sourceByKey, loadedSourceCount = readEnvValues()
    local errors = {}

    applyProcessEnvironment(values, sourceByKey)

    if loadedSourceCount == 0 and not os.getenv("API_KEY") and not os.getenv("API_BASE_URL") then
        errors[#errors + 1] = string.format("%s was not found. Set API_KEY and API_BASE_URL in process environment variables or a local %s file.", ENV_FILE, ENV_FILE)
    end

    local apiKey = values.API_KEY or ""
    local apiBaseUrl = values.API_BASE_URL or ""
    local hmacSecret = values.HMAC_SECRET or ""
    local hasLocalConfigFile = loadedSourceCount > 0
    local hasLocalRequiredConfig = hasLocalConfigFile and hasLocalRequiredKeys(sourceByKey)

    if apiKey == "" then
        errors[#errors + 1] = "API_KEY is missing. Set it in the process environment or in .env."
    end

    if apiBaseUrl == "" then
        errors[#errors + 1] = "API_BASE_URL is missing. Set it in the process environment or in .env."
    end

    return {
        values = values,
        apiKey = apiKey,
        apiBaseUrl = apiBaseUrl,
        hmacSecret = hmacSecret,
        sourceByKey = sourceByKey,
        hasLocalConfigFile = hasLocalConfigFile,
        hasLocalRequiredConfig = hasLocalRequiredConfig,
        isConfigured = #errors == 0,
        errors = errors,
    }
end

return envLoader

