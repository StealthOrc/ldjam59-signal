local json = require("src.game.util.json")
local httpTransport = require("src.game.network.http_transport")
local marketplaceFavoriteLogic = require("src.game.network.marketplace_favorite_logic")

local REQUEST_CHANNEL_NAME = "signal_leaderboard_request"
local RESPONSE_CHANNEL_NAME = "signal_leaderboard_response"
local REQUEST_KIND_FETCH = "fetch"
local REQUEST_KIND_PREVIEW = "preview"
local REQUEST_KIND_MARKETPLACE = "marketplace"
local REQUEST_KIND_FAVORITE_MAP = "favorite_map"
local REQUEST_KIND_REPLAY_SUBMIT = "replay_submit"
local REQUEST_KIND_REPLAY_FETCH = "replay_fetch"
local REQUEST_KIND_UPLOAD_MAP = "upload_map"
local DEFAULT_LEADERBOARD_LIMIT = 50
local DEFAULT_PREVIEW_LIMIT = 5
local DEFAULT_MARKETPLACE_LIMIT = 10
local DEFAULT_REQUEST_TIMEOUT_SECONDS = 5
local MARKETPLACE_MODE_FAVORITES = "favorites"
local MARKETPLACE_MODE_SEARCH = "search"
local LEADERBOARD_UNAVAILABLE_MESSAGE = "Leaderboard unavailable."
local MAP_CATEGORY_ONLINE = "online"

local requestChannel = love.thread.getChannel(REQUEST_CHANNEL_NAME)
local responseChannel = love.thread.getChannel(RESPONSE_CHANNEL_NAME)

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

local function buildReplayMetadataUri(baseUrl, mapUuid, mapHash, limit)
    return string.format(
        "%s/api/maps/%s/replays?map_hash=%s&limit=%d",
        normalizeBaseUrl(baseUrl),
        tostring(mapUuid or ""),
        urlEncode(tostring(mapHash or "")),
        tonumber(limit) or DEFAULT_PREVIEW_LIMIT
    )
end

local function buildReplayUri(baseUrl, mapUuid, replayUuid)
    return string.format(
        "%s/api/maps/%s/replays/%s",
        normalizeBaseUrl(baseUrl),
        tostring(mapUuid or ""),
        tostring(replayUuid or "")
    )
end

local function buildMarketplaceFavoritesUri(baseUrl, limit, playerUuid)
    local resolvedLimit = tonumber(limit) or DEFAULT_MARKETPLACE_LIMIT
    local uri = string.format("%s/api/maps/favorites?limit=%d", normalizeBaseUrl(baseUrl), resolvedLimit)
    local normalizedPlayerUuid = tostring(playerUuid or "")
    if normalizedPlayerUuid ~= "" then
        uri = uri .. "&player_uuid=" .. urlEncode(normalizedPlayerUuid)
    end
    return uri
end

local function buildMarketplaceSearchUri(baseUrl, query, limit, playerUuid)
    local resolvedLimit = tonumber(limit) or DEFAULT_MARKETPLACE_LIMIT
    local queryParameter = urlEncode(tostring(query or ""))
    local uri = string.format("%s/api/maps/search?q=%s&limit=%d", normalizeBaseUrl(baseUrl), queryParameter, resolvedLimit)
    local normalizedPlayerUuid = tostring(playerUuid or "")
    if normalizedPlayerUuid ~= "" then
        uri = uri .. "&player_uuid=" .. urlEncode(normalizedPlayerUuid)
    end
    return uri
end

local function fetchJson(uri, apiKey)
    return httpTransport.getJson({
        url = uri,
        apiKey = apiKey,
        timeoutSeconds = DEFAULT_REQUEST_TIMEOUT_SECONDS,
    })
end

local function runJsonPost(config, endpointPath, payload, requestId)
    local _, validationError = validateConfig(config)
    if validationError then
        return nil, validationError
    end

    return httpTransport.postJson({
        url = normalizeBaseUrl(config.apiBaseUrl) .. tostring(endpointPath or ""),
        apiKey = config.apiKey,
        hmacSecret = config.hmacSecret,
        payload = payload,
        timeoutSeconds = DEFAULT_REQUEST_TIMEOUT_SECONDS,
    })
end

local function runJsonDelete(config, endpointPath, payload, requestId)
    local _, validationError = validateConfig(config)
    if validationError then
        return nil, validationError
    end

    return httpTransport.deleteJson({
        url = normalizeBaseUrl(config.apiBaseUrl) .. tostring(endpointPath or ""),
        apiKey = config.apiKey,
        hmacSecret = config.hmacSecret,
        payload = payload,
        timeoutSeconds = DEFAULT_REQUEST_TIMEOUT_SECONDS,
    })
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
        if tostring(entry.player_uuid or "") == resolvedPlayerUuid then
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

    local mapHash = tostring(config.mapHash or config.map_hash or "")
    if mapHash == "" then
        return nil, "Leaderboard preview could not be loaded because the map hash is missing."
    end

    local topPayload, topError = fetchJson(
        buildReplayMetadataUri(config.apiBaseUrl, mapUuid, mapHash, tonumber(config.limit) or DEFAULT_PREVIEW_LIMIT),
        config.apiKey
    )
    if not topPayload then
        return nil, topError
    end

    local previewPayload = {
        map_uuid = mapUuid,
        map_hash = mapHash,
        top_entries = type(topPayload.entries) == "table" and topPayload.entries or {},
        player_entry = nil,
        target_rank = nil,
    }
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
        uri = buildMarketplaceSearchUri(config.apiBaseUrl, config.query, config.limit, config.player_uuid)
    else
        uri = buildMarketplaceFavoritesUri(config.apiBaseUrl, config.limit, config.player_uuid)
    end

    return fetchJson(uri, config.apiKey)
end

local function favoriteMarketplaceMap(config, requestId)
    local mapUuid = tostring(config.mapUuid or "")
    if mapUuid == "" then
        return nil, "The selected online map is missing its map UUID."
    end

    local playerUuid = tostring(config.player_uuid or "")
    if playerUuid == "" then
        return nil, "The current player UUID is missing."
    end

    local endpointPath = string.format("/api/maps/%s/favorites", mapUuid)
    local payload = marketplaceFavoriteLogic.buildRequestPayload(playerUuid)
    if config.liked == true then
        return runJsonPost(config, endpointPath, payload, requestId)
    end

    return runJsonDelete(config, endpointPath, payload, requestId)
end

local function submitReplay(config, requestId)
    local mapUuid = tostring(config.mapUuid or "")
    if mapUuid == "" then
        return nil, "The replay could not be uploaded because the map UUID is missing."
    end

    return runJsonPost(config, string.format("/api/maps/%s/replays", mapUuid), {
        player_uuid = tostring(config.player_uuid or ""),
        display_name = tostring(config.playerDisplayName or ""),
        score = tonumber(config.score or 0) or 0,
        map_hash = tostring(config.mapHash or config.map_hash or ""),
        replay = config.replay,
    }, requestId)
end

local function fetchReplayRecord(config)
    local _, validationError = validateConfig(config)
    if validationError then
        return nil, validationError
    end

    local mapUuid = tostring(config.mapUuid or "")
    local replayUuid = tostring(config.replayUuid or config.replay_uuid or "")
    if mapUuid == "" then
        return nil, "Replay download could not start because the map UUID is missing."
    end
    if replayUuid == "" then
        return nil, "Replay download could not start because the replay UUID is missing."
    end

    return fetchJson(buildReplayUri(config.apiBaseUrl, mapUuid, replayUuid), config.apiKey)
end

local function uploadMap(config, requestId)
    local mapUuid = tostring(config.mapUuid or "")
    if mapUuid == "" then
        return nil, "The map could not be uploaded because the map UUID is missing."
    end

    return runJsonPost(config, "/api/maps", {
        map_uuid = mapUuid,
        map_name = tostring(config.mapName or ""),
        map_category = tostring(config.mapCategory or MAP_CATEGORY_ONLINE),
        creator_uuid = tostring(config.creator_uuid or config.creatorUuid or ""),
        display_name = tostring(config.playerDisplayName or ""),
        map_hash = tostring(config.mapHash or config.map_hash or ""),
        map = config.map,
    }, requestId)
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
    elseif type(request) == "table" and request.kind == REQUEST_KIND_FAVORITE_MAP then
        local payload, requestError, statusCode = favoriteMarketplaceMap(request.config or {}, request.requestId)
        responseChannel:push(json.encode({
            kind = REQUEST_KIND_FAVORITE_MAP,
            requestId = request.requestId,
            ok = payload ~= nil,
            payload = payload,
            error = requestError,
            status = statusCode,
        }))
    elseif type(request) == "table" and request.kind == REQUEST_KIND_REPLAY_SUBMIT then
        local payload, requestError, statusCode = submitReplay(request.config or {}, request.requestId)
        responseChannel:push(json.encode({
            kind = REQUEST_KIND_REPLAY_SUBMIT,
            requestId = request.requestId,
            ok = payload ~= nil,
            payload = payload,
            error = requestError,
            status = statusCode,
        }))
    elseif type(request) == "table" and request.kind == REQUEST_KIND_REPLAY_FETCH then
        local payload, fetchError, statusCode = fetchReplayRecord(request.config or {})
        responseChannel:push(json.encode({
            kind = REQUEST_KIND_REPLAY_FETCH,
            requestId = request.requestId,
            ok = payload ~= nil,
            payload = payload,
            error = fetchError,
            status = statusCode,
        }))
    elseif type(request) == "table" and request.kind == REQUEST_KIND_UPLOAD_MAP then
        local payload, requestError, statusCode = uploadMap(request.config or {}, request.requestId)
        responseChannel:push(json.encode({
            kind = REQUEST_KIND_UPLOAD_MAP,
            requestId = request.requestId,
            ok = payload ~= nil,
            payload = payload,
            error = requestError,
            status = statusCode,
        }))
    end
end
