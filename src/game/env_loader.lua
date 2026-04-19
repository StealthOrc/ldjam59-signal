local envLoader = {}

local ENV_FILE = ".env"

local function trim(value)
    return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function stripQuotes(value)
    local trimmed = trim(value)
    local firstChar = trimmed:sub(1, 1)
    local lastChar = trimmed:sub(-1)
    if (#trimmed >= 2) and ((firstChar == '"' and lastChar == '"') or (firstChar == "'" and lastChar == "'")) then
        return trimmed:sub(2, -2)
    end
    return trimmed
end

local function readEnvFile()
    if love and love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(ENV_FILE, "file") then
        return love.filesystem.read(ENV_FILE)
    end

    local handle = io.open(ENV_FILE, "rb")
    if not handle then
        return nil, string.format("%s could not be read.", ENV_FILE)
    end

    local content = handle:read("*a")
    handle:close()
    return content
end

function envLoader.load()
    local content, readError = readEnvFile()
    local values = {}
    local errors = {}

    if not content then
        errors[#errors + 1] = readError or string.format("%s is missing.", ENV_FILE)
    else
        for line in content:gmatch("[^\r\n]+") do
            local trimmedLine = trim(line)
            if trimmedLine ~= "" and trimmedLine:sub(1, 1) ~= "#" then
                local key, value = trimmedLine:match("^([%w_]+)%s*=%s*(.*)$")
                if key then
                    values[key] = stripQuotes(value)
                end
            end
        end
    end

    local apiKey = values.API_KEY or ""
    local leaderboardId = values.LEADERBOARD_ID or ""

    if apiKey == "" then
        errors[#errors + 1] = "API_KEY is missing in .env."
    end
    if leaderboardId == "" then
        errors[#errors + 1] = "LEADERBOARD_ID is missing in .env."
    end

    return {
        values = values,
        apiKey = apiKey,
        leaderboardId = leaderboardId,
        isConfigured = #errors == 0,
        errors = errors,
    }
end

return envLoader

