local json = require("src.game.util.json")
local httpTransport = require("src.game.network.http_transport")
local marketplaceFavoriteLogic = require("src.game.network.marketplace_favorite_logic")

local REQUEST_CHANNEL_NAME = "signal_leaderboard_request"
local RESPONSE_CHANNEL_NAME = "signal_leaderboard_response"
local DEBUG_CHANNEL_NAME = "signal_network_request_debug"
local REQUEST_KIND_FETCH = "fetch"
local REQUEST_KIND_PREVIEW = "preview"
local REQUEST_KIND_MARKETPLACE = "marketplace"
local REQUEST_KIND_FAVORITE_MAP = "favorite_map"
local REQUEST_KIND_MAP_PLAY = "map_play"
local REQUEST_KIND_REPLAY_SUBMIT = "replay_submit"
local REQUEST_KIND_SCORE_SUBMIT = "score_submit"
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
local debugChannel = love.thread.getChannel(DEBUG_CHANNEL_NAME)

httpTransport.setDebugRecorder(function(event)
    debugChannel:push(json.encode(event))
end)

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

local function buildLeaderboardUri(baseUrl, mapUuid, size, playerUuid, mapHash, includeReplay)
    local resolvedBaseUrl = normalizeBaseUrl(baseUrl)
    local resolvedSize = tonumber(size) or DEFAULT_LEADERBOARD_LIMIT
    local resolvedMapUuid = tostring(mapUuid or "")
    local resolvedPlayerUuid = tostring(playerUuid or "")
    local resolvedMapHash = tostring(mapHash or "")
    local uri

    if resolvedMapUuid ~= "" then
        uri = string.format("%s/api/maps/%s/leaderboard?size=%d", resolvedBaseUrl, resolvedMapUuid, resolvedSize)
        if resolvedPlayerUuid ~= "" then
            uri = uri .. "&player_uuid=" .. urlEncode(resolvedPlayerUuid)
        end
        if resolvedMapHash ~= "" then
            uri = uri .. "&map_hash=" .. urlEncode(resolvedMapHash)
        end
        if includeReplay == true then
            uri = uri .. "&include_replay=true"
        end
        return uri
    end

    uri = string.format("%s/api/leaderboard?size=%d", resolvedBaseUrl, resolvedSize)
    if resolvedPlayerUuid ~= "" then
        uri = uri .. "&player_uuid=" .. urlEncode(resolvedPlayerUuid)
    end
    return uri
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

local function fetchJson(uri, apiKey, requestKind, flowRequestId)
    return httpTransport.getJson({
        url = uri,
        apiKey = apiKey,
        timeoutSeconds = DEFAULT_REQUEST_TIMEOUT_SECONDS,
        debugContext = {
            requestKind = requestKind,
            flowRequestId = flowRequestId,
        },
    })
end

local function runJsonPost(config, endpointPath, payload, requestKind, requestId)
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
        debugContext = {
            requestKind = requestKind,
            flowRequestId = requestId,
        },
    })
end

local function runJsonDelete(config, endpointPath, payload, requestKind, requestId)
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
        debugContext = {
            requestKind = requestKind,
            flowRequestId = requestId,
        },
    })
end

local function fetchLeaderboardEntries(config)
    local _, validationError = validateConfig(config)
    if validationError then
        return nil, validationError
    end

    local uri = buildLeaderboardUri(
        config.apiBaseUrl,
        config.mapUuid,
        config.size or config.limit,
        config.player_uuid,
        config.mapHash or config.map_hash,
        config.include_replay == true or config.includeReplay == true
    )
    return fetchJson(uri, config.apiKey, REQUEST_KIND_FETCH, config.requestId)
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
        buildLeaderboardUri(
            config.apiBaseUrl,
            mapUuid,
            config.size or config.limit or DEFAULT_PREVIEW_LIMIT,
            config.player_uuid,
            mapHash,
            true
        ),
        config.apiKey,
        REQUEST_KIND_PREVIEW,
        config.requestId
    )
    if not topPayload then
        return nil, topError
    end

    return {
        map_uuid = mapUuid,
        map_hash = mapHash,
        top_entries = type(topPayload.entries) == "table" and topPayload.entries or {},
        player_entry = type(topPayload.player_entry) == "table" and topPayload.player_entry or nil,
        target_rank = tonumber(topPayload.target_rank) or nil,
    }
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

    return fetchJson(uri, config.apiKey, REQUEST_KIND_MARKETPLACE, config.requestId)
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
        return runJsonPost(config, endpointPath, payload, REQUEST_KIND_FAVORITE_MAP, requestId)
    end

    return runJsonDelete(config, endpointPath, payload, REQUEST_KIND_FAVORITE_MAP, requestId)
end

local function recordMapPlay(config, requestId)
    local mapUuid = tostring(config.mapUuid or "")
    if mapUuid == "" then
        return nil, "The play count could not be recorded because the map UUID is missing."
    end

    local mapHash = tostring(config.mapHash or config.map_hash or "")
    if mapHash == "" then
        return nil, "The play count could not be recorded because the map hash is missing."
    end

    return runJsonPost(config, string.format("/api/maps/%s/plays", mapUuid), {
        display_name = tostring(config.playerDisplayName or ""),
        map_hash = mapHash,
        player_uuid = tostring(config.player_uuid or ""),
    }, REQUEST_KIND_MAP_PLAY, requestId)
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
    }, REQUEST_KIND_REPLAY_SUBMIT, requestId)
end

local function submitScore(config, requestId)
    local mapUuid = tostring(config.mapUuid or "")
    if mapUuid == "" then
        return nil, "The score could not be uploaded because the map UUID is missing."
    end

    local payload = {
        player_uuid = tostring(config.player_uuid or ""),
        display_name = tostring(config.playerDisplayName or ""),
        score = tonumber(config.score or 0) or 0,
    }
    local mapHash = tostring(config.mapHash or config.map_hash or "")
    if mapHash ~= "" then
        payload.map_hash = mapHash
    end

    return runJsonPost(config, string.format("/api/maps/%s/score", mapUuid), payload, REQUEST_KIND_SCORE_SUBMIT, requestId)
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

    return fetchJson(buildReplayUri(config.apiBaseUrl, mapUuid, replayUuid), config.apiKey, REQUEST_KIND_REPLAY_FETCH, config.requestId)
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
    }, REQUEST_KIND_UPLOAD_MAP, requestId)
end

while true do
    local encodedRequest = requestChannel:demand()
    local request = json.decode(encodedRequest)

    if type(request) == "table" and request.kind == REQUEST_KIND_FETCH then
        local requestConfig = request.config or {}
        requestConfig.requestId = request.requestId
        local payload, fetchError = fetchLeaderboardEntries(requestConfig)
        responseChannel:push(json.encode({
            kind = REQUEST_KIND_FETCH,
            requestId = request.requestId,
            ok = payload ~= nil,
            payload = payload,
            error = fetchError,
        }))
    elseif type(request) == "table" and request.kind == REQUEST_KIND_PREVIEW then
        local requestConfig = request.config or {}
        requestConfig.requestId = request.requestId
        local payload, fetchError = fetchLeaderboardPreview(requestConfig)
        responseChannel:push(json.encode({
            kind = REQUEST_KIND_PREVIEW,
            requestId = request.requestId,
            ok = payload ~= nil,
            payload = payload,
            error = fetchError,
        }))
    elseif type(request) == "table" and request.kind == REQUEST_KIND_MARKETPLACE then
        local requestConfig = request.config or {}
        requestConfig.requestId = request.requestId
        local payload, fetchError = fetchMarketplaceEntries(requestConfig)
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
    elseif type(request) == "table" and request.kind == REQUEST_KIND_MAP_PLAY then
        local payload, requestError, statusCode = recordMapPlay(request.config or {}, request.requestId)
        responseChannel:push(json.encode({
            kind = REQUEST_KIND_MAP_PLAY,
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
    elseif type(request) == "table" and request.kind == REQUEST_KIND_SCORE_SUBMIT then
        local payload, requestError, statusCode = submitScore(request.config or {}, request.requestId)
        responseChannel:push(json.encode({
            kind = REQUEST_KIND_SCORE_SUBMIT,
            requestId = request.requestId,
            ok = payload ~= nil,
            payload = payload,
            error = requestError,
            status = statusCode,
        }))
    elseif type(request) == "table" and request.kind == REQUEST_KIND_REPLAY_FETCH then
        local requestConfig = request.config or {}
        requestConfig.requestId = request.requestId
        local payload, fetchError, statusCode = fetchReplayRecord(requestConfig)
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
