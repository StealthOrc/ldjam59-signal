local json = require("src.game.json")

local REQUEST_CHANNEL_NAME = "signal_leaderboard_request"
local RESPONSE_CHANNEL_NAME = "signal_leaderboard_response"
local REQUEST_KIND_FETCH = "fetch"
local REQUEST_KIND_PREVIEW = "preview"
local REQUEST_KIND_MARKETPLACE = "marketplace"
local CURL_STATUS_PREFIX = "__STATUS__"
local DEFAULT_LEADERBOARD_LIMIT = 50
local DEFAULT_PREVIEW_LIMIT = 5
local DEFAULT_MARKETPLACE_LIMIT = 10
local DEFAULT_REQUEST_TIMEOUT_SECONDS = 5
local MARKETPLACE_MODE_FAVORITES = "favorites"
local MARKETPLACE_MODE_SEARCH = "search"
local LEADERBOARD_UNAVAILABLE_MESSAGE = "Leaderboard unavailable."

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

local function normalizeBaseUrl(baseUrl)
    return tostring(baseUrl or ""):gsub("/+$", "")
end

local function validateConfig(config)
    if tostring(config.apiKey or "") == "" then
        return nil, LEADERBOARD_UNAVAILABLE_MESSAGE
    end

    if normalizeBaseUrl(config.apiBaseUrl) == "" then
        return nil, LEADERBOARD_UNAVAILABLE_MESSAGE
    end

    return true
end

local function urlEncode(value)
    local text = tostring(value or "")
    return (text:gsub("([^%w%-_%.~])", function(character)
        return string.format("%%%02X", character:byte())
    end))
end

local function buildLeaderboardUri(baseUrl, mapUuid, limit)
    local resolvedBaseUrl = normalizeBaseUrl(baseUrl)
    local resolvedLimit = tonumber(limit) or DEFAULT_LEADERBOARD_LIMIT
    local resolvedMapUuid = tostring(mapUuid or "")

    if resolvedMapUuid ~= "" then
        return string.format("%s/api/maps/%s/leaderboard?limit=%d", resolvedBaseUrl, resolvedMapUuid, resolvedLimit)
    end

    return string.format("%s/api/leaderboard?limit=%d", resolvedBaseUrl, resolvedLimit)
end

local function buildMapAroundUri(baseUrl, mapUuid, playerUuid)
    return string.format(
        "%s/api/maps/%s/leaderboard/around/%s",
        normalizeBaseUrl(baseUrl),
        tostring(mapUuid or ""),
        tostring(playerUuid or "")
    )
end

local function buildMarketplaceFavoritesUri(baseUrl, limit)
    local resolvedLimit = tonumber(limit) or DEFAULT_MARKETPLACE_LIMIT
    return string.format("%s/api/maps/favorites?limit=%d", normalizeBaseUrl(baseUrl), resolvedLimit)
end

local function buildMarketplaceSearchUri(baseUrl, query, limit)
    local resolvedLimit = tonumber(limit) or DEFAULT_MARKETPLACE_LIMIT
    local queryParameter = urlEncode(tostring(query or ""))
    return string.format("%s/api/maps/search?q=%s&limit=%d", normalizeBaseUrl(baseUrl), queryParameter, resolvedLimit)
end

local function fetchJson(uri, apiKey)
    local header = string.format("x-api-key: %s", tostring(apiKey or ""))
    local command = table.concat({
        "curl.exe",
        "-sS",
        "--max-time",
        tostring(DEFAULT_REQUEST_TIMEOUT_SECONDS),
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
        return nil, (body and body ~= "") and body or string.format("Leaderboard request failed with status %d.", statusCode), statusCode
    end

    local decodedPayload = json.decode(body)
    if type(decodedPayload) ~= "table" then
        return nil, "Leaderboard response was not valid JSON."
    end

    return decodedPayload, nil, statusCode
end

local function fetchLeaderboardEntries(config)
    local _, validationError = validateConfig(config)
    if validationError then
        return nil, validationError
    end

    local uri = buildLeaderboardUri(config.apiBaseUrl, config.mapUuid, config.limit)
    return fetchJson(uri, config.apiKey)
end

local function extractPlayerPreviewEntry(aroundPayload, playerUuid)
    local entries = type(aroundPayload) == "table" and aroundPayload.entries or nil
    if type(entries) ~= "table" then
        return nil
    end

    local resolvedPlayerUuid = tostring(playerUuid or "")
    for _, entry in ipairs(entries) do
        if tostring(entry.player_uuid or entry.playerUuid or "") == resolvedPlayerUuid then
            return entry
        end
    end

    return entries[1]
end

local function fetchLeaderboardPreview(config)
    local _, validationError = validateConfig(config)
    if validationError then
        return nil, validationError
    end

    local mapUuid = tostring(config.mapUuid or "")
    if mapUuid == "" then
        return nil, "Leaderboard preview could not be loaded because the map UUID is missing."
    end

    local topPayload, topError = fetchJson(
        buildLeaderboardUri(config.apiBaseUrl, mapUuid, tonumber(config.limit) or DEFAULT_PREVIEW_LIMIT),
        config.apiKey
    )
    if not topPayload then
        return nil, topError
    end

    local previewPayload = {
        map_uuid = mapUuid,
        top_entries = type(topPayload.entries) == "table" and topPayload.entries or {},
        player_entry = nil,
        target_rank = nil,
    }

    local playerUuid = tostring(config.playerUuid or "")
    if playerUuid == "" then
        return previewPayload
    end

    local aroundPayload, aroundError, aroundStatus = fetchJson(
        buildMapAroundUri(config.apiBaseUrl, mapUuid, playerUuid),
        config.apiKey
    )
    if not aroundPayload then
        if aroundStatus == 404 then
            return previewPayload
        end
        return nil, aroundError
    end

    previewPayload.player_entry = extractPlayerPreviewEntry(aroundPayload, playerUuid)
    previewPayload.target_rank = tonumber(aroundPayload.target_rank) or nil
    return previewPayload
end

local function fetchMarketplaceEntries(config)
    local _, validationError = validateConfig(config)
    if validationError then
        return nil, validationError
    end

    local mode = tostring(config.mode or MARKETPLACE_MODE_FAVORITES)
    local uri

    if mode == MARKETPLACE_MODE_SEARCH then
        uri = buildMarketplaceSearchUri(config.apiBaseUrl, config.query, config.limit)
    else
        uri = buildMarketplaceFavoritesUri(config.apiBaseUrl, config.limit)
    end

    return fetchJson(uri, config.apiKey)
end

while true do
    local encodedRequest = requestChannel:demand()
    local request = json.decode(encodedRequest)

    if type(request) == "table" and request.kind == REQUEST_KIND_FETCH then
        local payload, fetchError = fetchLeaderboardEntries(request.config or {})
        responseChannel:push(json.encode({
            kind = REQUEST_KIND_FETCH,
            requestId = request.requestId,
            ok = payload ~= nil,
            payload = payload,
            error = fetchError,
        }))
    elseif type(request) == "table" and request.kind == REQUEST_KIND_PREVIEW then
        local payload, fetchError = fetchLeaderboardPreview(request.config or {})
        responseChannel:push(json.encode({
            kind = REQUEST_KIND_PREVIEW,
            requestId = request.requestId,
            ok = payload ~= nil,
            payload = payload,
            error = fetchError,
        }))
    elseif type(request) == "table" and request.kind == REQUEST_KIND_MARKETPLACE then
        local payload, fetchError = fetchMarketplaceEntries(request.config or {})
        responseChannel:push(json.encode({
            kind = REQUEST_KIND_MARKETPLACE,
            requestId = request.requestId,
            ok = payload ~= nil,
            payload = payload,
            error = fetchError,
        }))
    end
end
