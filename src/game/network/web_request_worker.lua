local json = require("src.game.util.json")
local httpTransport = require("src.game.network.http_transport")
local marketplaceFavoriteLogic = require("src.game.network.marketplace_favorite_logic")

local webRequestWorker = {}

local REQUEST_KIND_FETCH = "fetch"
local REQUEST_KIND_PREVIEW = "preview"
local REQUEST_KIND_MARKETPLACE = "marketplace"
local REQUEST_KIND_FAVORITE_MAP = "favorite_map"
local REQUEST_KIND_SCORE_SUBMIT = "score_submit"
local REQUEST_KIND_UPLOAD_MAP = "upload_map"
local DEFAULT_LEADERBOARD_LIMIT = 50
local DEFAULT_PREVIEW_LIMIT = 5
local DEFAULT_MARKETPLACE_LIMIT = 10
local DEFAULT_REQUEST_TIMEOUT_SECONDS = 5
local MARKETPLACE_MODE_FAVORITES = "favorites"
local MARKETPLACE_MODE_SEARCH = "search"
local LEADERBOARD_UNAVAILABLE_MESSAGE = "Leaderboard unavailable."
local MAP_CATEGORY_ONLINE = "online"

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

local function fetchJsonAsync(uri, apiKey, callback)
    return httpTransport.getJsonAsync({
        url = uri,
        apiKey = apiKey,
        timeoutSeconds = DEFAULT_REQUEST_TIMEOUT_SECONDS,
    }, callback)
end

local function runJsonPostAsync(config, endpointPath, payload, callback)
    local _, validationError = validateConfig(config)
    if validationError then
        callback(nil, validationError)
        return nil
    end

    return httpTransport.postJsonAsync({
        url = normalizeBaseUrl(config.apiBaseUrl) .. tostring(endpointPath or ""),
        apiKey = config.apiKey,
        hmacSecret = config.hmacSecret,
        payload = payload,
        timeoutSeconds = DEFAULT_REQUEST_TIMEOUT_SECONDS,
    }, callback)
end

local function runJsonDeleteAsync(config, endpointPath, payload, callback)
    local _, validationError = validateConfig(config)
    if validationError then
        callback(nil, validationError)
        return nil
    end

    return httpTransport.deleteJsonAsync({
        url = normalizeBaseUrl(config.apiBaseUrl) .. tostring(endpointPath or ""),
        apiKey = config.apiKey,
        hmacSecret = config.hmacSecret,
        payload = payload,
        timeoutSeconds = DEFAULT_REQUEST_TIMEOUT_SECONDS,
    }, callback)
end

local function fetchLeaderboardEntriesAsync(config, callback)
    local _, validationError = validateConfig(config)
    if validationError then
        callback(nil, validationError)
        return nil
    end

    local uri = buildLeaderboardUri(config.apiBaseUrl, config.mapUuid, config.limit)
    return fetchJsonAsync(uri, config.apiKey, callback)
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

local function fetchLeaderboardPreviewAsync(config, callback)
    local _, validationError = validateConfig(config)
    if validationError then
        callback(nil, validationError)
        return nil
    end

    local mapUuid = tostring(config.mapUuid or "")
    if mapUuid == "" then
        callback(nil, "Leaderboard preview could not be loaded because the map UUID is missing.")
        return nil
    end

    return fetchJsonAsync(
        buildLeaderboardUri(config.apiBaseUrl, mapUuid, tonumber(config.limit) or DEFAULT_PREVIEW_LIMIT),
        config.apiKey,
        function(topPayload, topError)
            if not topPayload then
                callback(nil, topError)
                return
            end

            local previewPayload = {
                map_uuid = mapUuid,
                top_entries = type(topPayload.entries) == "table" and topPayload.entries or {},
                player_entry = nil,
                target_rank = nil,
            }

            local playerUuid = tostring(config.player_uuid or "")
            if playerUuid == "" then
                callback(previewPayload, nil)
                return
            end

            fetchJsonAsync(
                buildMapAroundUri(config.apiBaseUrl, mapUuid, playerUuid),
                config.apiKey,
                function(aroundPayload, aroundError, aroundStatus)
                    if not aroundPayload then
                        if aroundStatus == 404 then
                            callback(previewPayload, nil)
                            return
                        end

                        callback(nil, aroundError, aroundStatus)
                        return
                    end

                    previewPayload.player_entry = extractPlayerPreviewEntry(aroundPayload, playerUuid)
                    previewPayload.target_rank = tonumber(aroundPayload.target_rank) or nil
                    callback(previewPayload, nil, aroundStatus)
                end
            )
        end
    )
end

local function fetchMarketplaceEntriesAsync(config, callback)
    local _, validationError = validateConfig(config)
    if validationError then
        callback(nil, validationError)
        return nil
    end

    local mode = tostring(config.mode or MARKETPLACE_MODE_FAVORITES)
    local uri

    if mode == MARKETPLACE_MODE_SEARCH then
        uri = buildMarketplaceSearchUri(config.apiBaseUrl, config.query, config.limit, config.player_uuid)
    else
        uri = buildMarketplaceFavoritesUri(config.apiBaseUrl, config.limit, config.player_uuid)
    end

    return fetchJsonAsync(uri, config.apiKey, callback)
end

local function favoriteMarketplaceMapAsync(config, callback)
    local mapUuid = tostring(config.mapUuid or "")
    if mapUuid == "" then
        callback(nil, "The selected online map is missing its map UUID.")
        return nil
    end

    local playerUuid = tostring(config.player_uuid or "")
    if playerUuid == "" then
        callback(nil, "The current player UUID is missing.")
        return nil
    end

    local endpointPath = string.format("/api/maps/%s/favorites", mapUuid)
    local payload = marketplaceFavoriteLogic.buildRequestPayload(playerUuid)
    if config.liked == true then
        return runJsonPostAsync(config, endpointPath, payload, callback)
    end

    return runJsonDeleteAsync(config, endpointPath, payload, callback)
end

local function submitScoreAsync(config, callback)
    local mapUuid = tostring(config.mapUuid or "")
    if mapUuid == "" then
        callback(nil, "The score could not be uploaded because the map UUID is missing.")
        return nil
    end

    return runJsonPostAsync(config, string.format("/api/maps/%s/score", mapUuid), {
        player_uuid = tostring(config.player_uuid or ""),
        display_name = tostring(config.playerDisplayName or ""),
        score = tonumber(config.score or 0) or 0,
    }, callback)
end

local function uploadMapAsync(config, callback)
    local mapUuid = tostring(config.mapUuid or "")
    if mapUuid == "" then
        callback(nil, "The map could not be uploaded because the map UUID is missing.")
        return nil
    end

    return runJsonPostAsync(config, "/api/maps", {
        map_uuid = mapUuid,
        map_name = tostring(config.mapName or ""),
        map_category = tostring(config.mapCategory or MAP_CATEGORY_ONLINE),
        creator_uuid = tostring(config.creator_uuid or config.creatorUuid or ""),
        display_name = tostring(config.playerDisplayName or ""),
        map = config.map,
    }, callback)
end

local function createResponse(kind, requestId, payload, requestError, statusCode)
    return {
        kind = kind,
        requestId = requestId,
        ok = payload ~= nil,
        payload = payload,
        error = requestError,
        status = statusCode,
    }
end

local function dispatchRequestAsync(request, callback)
    local resolvedRequest = type(request) == "table" and request or {}
    local config = resolvedRequest.config or {}
    local kind = resolvedRequest.kind
    local requestId = resolvedRequest.requestId

    if kind == REQUEST_KIND_FETCH then
        return fetchLeaderboardEntriesAsync(config, function(payload, requestError, statusCode)
            callback(createResponse(REQUEST_KIND_FETCH, requestId, payload, requestError, statusCode))
        end)
    end

    if kind == REQUEST_KIND_PREVIEW then
        return fetchLeaderboardPreviewAsync(config, function(payload, requestError, statusCode)
            callback(createResponse(REQUEST_KIND_PREVIEW, requestId, payload, requestError, statusCode))
        end)
    end

    if kind == REQUEST_KIND_MARKETPLACE then
        return fetchMarketplaceEntriesAsync(config, function(payload, requestError, statusCode)
            callback(createResponse(REQUEST_KIND_MARKETPLACE, requestId, payload, requestError, statusCode))
        end)
    end

    if kind == REQUEST_KIND_FAVORITE_MAP then
        return favoriteMarketplaceMapAsync(config, function(payload, requestError, statusCode)
            callback(createResponse(REQUEST_KIND_FAVORITE_MAP, requestId, payload, requestError, statusCode))
        end)
    end

    if kind == REQUEST_KIND_SCORE_SUBMIT then
        return submitScoreAsync(config, function(payload, requestError, statusCode)
            callback(createResponse(REQUEST_KIND_SCORE_SUBMIT, requestId, payload, requestError, statusCode))
        end)
    end

    if kind == REQUEST_KIND_UPLOAD_MAP then
        return uploadMapAsync(config, function(payload, requestError, statusCode)
            callback(createResponse(REQUEST_KIND_UPLOAD_MAP, requestId, payload, requestError, statusCode))
        end)
    end

    callback(createResponse(kind or "", requestId, nil, "The online request kind is not supported."))
    return nil
end

local function createResponseChannel()
    local channel = {
        queue = {},
    }

    function channel:push(value)
        self.queue[#self.queue + 1] = value
        return true
    end

    function channel:pop()
        if #self.queue == 0 then
            return nil
        end

        return table.remove(self.queue, 1)
    end

    return channel
end

function webRequestWorker.new()
    local responseChannel = createResponseChannel()
    local worker = {
        requestChannel = nil,
        responseChannel = responseChannel,
        lastError = nil,
    }

    local requestChannel = {}

    function requestChannel:push(encodedRequest)
        local okDecode, decodedRequest = pcall(json.decode, encodedRequest)
        if not okDecode or type(decodedRequest) ~= "table" then
            worker.lastError = okDecode and "The online request payload was invalid JSON." or tostring(decodedRequest)
            return false
        end

        local okDispatch, dispatchError = pcall(dispatchRequestAsync, decodedRequest, function(response)
            responseChannel:push(json.encode(response))
        end)

        if not okDispatch then
            worker.lastError = tostring(dispatchError)
            return false
        end

        return true
    end

    function requestChannel:pop()
        return nil
    end

    worker.requestChannel = requestChannel

    function worker:getRequestChannel()
        return self.requestChannel
    end

    function worker:getResponseChannel()
        return self.responseChannel
    end

    function worker:isRunning()
        return self.lastError == nil
    end

    function worker:getError()
        return self.lastError
    end

    function worker:update()
        httpTransport.updateAsyncRequests()
    end

    return worker
end

return webRequestWorker
