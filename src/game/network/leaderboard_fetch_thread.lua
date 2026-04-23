local json = require("src.game.util.json")
local leaderboardClient = require("src.game.network.leaderboard_client")

local REQUEST_CHANNEL_NAME = "signal_leaderboard_request"
local RESPONSE_CHANNEL_NAME = "signal_leaderboard_response"
local REQUEST_KIND_FETCH = "fetch"
local REQUEST_KIND_PREVIEW = "preview"
local REQUEST_KIND_MARKETPLACE = "marketplace"
local REQUEST_KIND_FAVORITE_MAP = "favorite_map"
local REQUEST_KIND_REPLAY_SUBMIT = "replay_submit"
local REQUEST_KIND_SCORE_SUBMIT = "score_submit"
local REQUEST_KIND_REPLAY_FETCH = "replay_fetch"
local REQUEST_KIND_UPLOAD_MAP = "upload_map"

local requestChannel = love.thread.getChannel(REQUEST_CHANNEL_NAME)
local responseChannel = love.thread.getChannel(RESPONSE_CHANNEL_NAME)

local function fetchLeaderboardEntries(config)
    return leaderboardClient.fetchLeaderboard(config, config)
end

local function fetchLeaderboardPreview(config)
    local topPayload, topError = leaderboardClient.fetchLeaderboard({
        include_replay = true,
        mapHash = config.mapHash or config.map_hash,
        mapUuid = config.mapUuid,
        player_uuid = config.player_uuid,
        size = config.size or config.limit,
    }, config)
    if not topPayload then
        return nil, topError
    end

    local mapUuid = tostring(config.mapUuid or "")
    local mapHash = tostring(config.mapHash or config.map_hash or "")

    local previewPayload = {
        map_uuid = mapUuid,
        map_hash = mapHash,
        top_entries = type(topPayload.entries) == "table" and topPayload.entries or {},
        player_entry = type(topPayload.player_entry) == "table" and topPayload.player_entry or nil,
        target_rank = tonumber(topPayload.target_rank) or nil,
    }
    return previewPayload
end

local function fetchMarketplaceEntries(config)
    return leaderboardClient.fetchMarketplace(config, config)
end

local function favoriteMarketplaceMap(config, requestId)
    return leaderboardClient.favoriteMap(config, config)
end

local function submitReplay(config, requestId)
    return leaderboardClient.submitReplay(config, config)
end

local function submitScore(config, requestId)
    return leaderboardClient.submitScore(config, config)
end

local function fetchReplayRecord(config)
    return leaderboardClient.fetchReplay(
        config.replayUuid or config.replay_uuid,
        config.mapUuid,
        config
    )
end

local function uploadMap(config, requestId)
    return leaderboardClient.uploadMap(config, config)
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
