local json = require("src.game.json")

local REQUEST_CHANNEL_NAME = "signal_leaderboard_request"
local RESPONSE_CHANNEL_NAME = "signal_leaderboard_response"
local REQUEST_KIND_FETCH = "fetch"
local CURL_STATUS_PREFIX = "__STATUS__"
local DEFAULT_API_BASE_URL = "https://signal-leaderboard.just2dev-signal.workers.dev"
local DEFAULT_LEADERBOARD_LIMIT = 50

local requestChannel = love.thread.getChannel(REQUEST_CHANNEL_NAME)
local responseChannel = love.thread.getChannel(RESPONSE_CHANNEL_NAME)

local function quoteArgument(value)
    return '"' .. tostring(value or ""):gsub('"', '\\"') .. '"'
end

local function runCommand(command)
    local handle = io.popen(command .. " 2>&1")
    if not handle then
        return nil
    end

    local output = handle:read("*a") or ""
    handle:close()
    return output
end

local function splitCurlOutput(output)
    local text = tostring(output or "")
    local statusLineStart, statusLineEnd, statusCode = text:find("\r?\n" .. CURL_STATUS_PREFIX .. "(%d%d%d)%s*$")
    if not statusCode then
        return nil, nil, text
    end

    local body = text:sub(1, statusLineStart - 1)
    return tonumber(statusCode), body, nil
end

local function buildLeaderboardUri(config)
    local baseUrl = tostring(config.apiBaseUrl or DEFAULT_API_BASE_URL):gsub("/+$", "")
    local limit = tonumber(config.limit) or DEFAULT_LEADERBOARD_LIMIT
    local mapUuid = tostring(config.mapUuid or "")

    if mapUuid ~= "" then
        return string.format("%s/api/maps/%s/leaderboard?limit=%d", baseUrl, mapUuid, limit)
    end

    return string.format("%s/api/leaderboard?limit=%d", baseUrl, limit)
end

local function fetchLeaderboardEntries(config)
    local uri = buildLeaderboardUri(config)
    local header = string.format("x-api-key: %s", tostring(config.apiKey or ""))
    local command = table.concat({
        "curl.exe",
        "-sS",
        quoteArgument(uri),
        "-H",
        quoteArgument(header),
        "-w",
        quoteArgument("\\n" .. CURL_STATUS_PREFIX .. "%{http_code}"),
    }, " ")

    local output = runCommand(command)
    if not output then
        return nil, "Leaderboard request could not be started."
    end

    local statusCode, body, splitError = splitCurlOutput(output)
    if not statusCode then
        return nil, splitError or "Leaderboard response could not be parsed."
    end

    if statusCode ~= 200 then
        return nil, (body and body ~= "") and body or string.format("Leaderboard request failed with status %d.", statusCode)
    end

    local decodedEntries = json.decode(body)
    if type(decodedEntries) ~= "table" then
        return nil, "Leaderboard response was not valid JSON."
    end

    return decodedEntries
end

while true do
    local encodedRequest = requestChannel:demand()
    local request = json.decode(encodedRequest)

    if type(request) == "table" and request.kind == REQUEST_KIND_FETCH then
        local payload, fetchError = fetchLeaderboardEntries(request.config or {})
        responseChannel:push(json.encode({
            requestId = request.requestId,
            ok = payload ~= nil,
            payload = payload,
            error = fetchError,
        }))
    end
end
