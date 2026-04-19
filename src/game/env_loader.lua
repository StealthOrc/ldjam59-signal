local envLoader = {}

local ENV_FILE = ".env"
local DEFAULT_API_BASE_URL = "https://signal-leaderboard.just2dev-signal.workers.dev"
local MIN_QUOTED_LENGTH = 2
local DIRECTORY_SEPARATOR = package.config:sub(1, 1)
local REQUIRED_KEYS = {
    "API_KEY",
}
local OPTIONAL_KEYS = {
    "API_BASE_URL",
    "HMAC_SECRET",
}
local SOURCE_WORKING_DIRECTORY = "working directory .env"
local SOURCE_LOVE_FILESYSTEM = "project .env"
local SOURCE_SAVE_DIRECTORY = "save directory .env"
local SOURCE_PROCESS_ENVIRONMENT = "process environment"
local SOURCE_DEFAULT = "built-in default"

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

    for line in content:gmatch("[^\r\n]+") do
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

local function readLoveEnvFile()
    if not (love and love.filesystem and love.filesystem.getInfo) then
        return nil
    end

    if not love.filesystem.getInfo(ENV_FILE, "file") then
        return nil
    end

    return love.filesystem.read(ENV_FILE)
end

local function readSaveDirectoryEnvFile()
    if not (love and love.filesystem and love.filesystem.getSaveDirectory) then
        return nil
    end

    local saveDirectory = love.filesystem.getSaveDirectory()
    if not saveDirectory or saveDirectory == "" then
        return nil
    end

    return readFile(saveDirectory .. DIRECTORY_SEPARATOR .. ENV_FILE)
end

local function readEnvValues()
    local values = {}
    local sourceByKey = {}
    local loadedSourceCount = 0

    local loveContent = readLoveEnvFile()
    if loveContent then
        mergeValues(values, sourceByKey, parseEnvContent(loveContent), SOURCE_LOVE_FILESYSTEM)
        loadedSourceCount = loadedSourceCount + 1
    end

    local workingDirectoryContent = readFile(ENV_FILE)
    if workingDirectoryContent then
        mergeValues(values, sourceByKey, parseEnvContent(workingDirectoryContent), SOURCE_WORKING_DIRECTORY)
        loadedSourceCount = loadedSourceCount + 1
    end

    local saveDirectoryContent = readSaveDirectoryEnvFile()
    if saveDirectoryContent then
        mergeValues(values, sourceByKey, parseEnvContent(saveDirectoryContent), SOURCE_SAVE_DIRECTORY)
        loadedSourceCount = loadedSourceCount + 1
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

function envLoader.load()
    local values, sourceByKey, loadedSourceCount = readEnvValues()
    local errors = {}

    applyProcessEnvironment(values, sourceByKey)

    if loadedSourceCount == 0 and not os.getenv("API_KEY") and not os.getenv("API_BASE_URL") then
        errors[#errors + 1] = string.format("%s was not found. Set API_KEY in process environment variables or a local %s file.", ENV_FILE, ENV_FILE)
    end

    local apiKey = values.API_KEY or ""
    local apiBaseUrl = values.API_BASE_URL or DEFAULT_API_BASE_URL
    local hmacSecret = values.HMAC_SECRET or ""

    if apiBaseUrl == DEFAULT_API_BASE_URL and not sourceByKey.API_BASE_URL then
        sourceByKey.API_BASE_URL = SOURCE_DEFAULT
    end

    if apiKey == "" then
        errors[#errors + 1] = "API_KEY is missing. Set it in the process environment or in .env."
    end

    return {
        values = values,
        apiKey = apiKey,
        apiBaseUrl = apiBaseUrl,
        hmacSecret = hmacSecret,
        sourceByKey = sourceByKey,
        isConfigured = #errors == 0,
        errors = errors,
    }
end

return envLoader

