local envLoader = require("src.game.network.env_loader")
local httpTransport = require("src.game.network.http_transport")
local marketplaceFavoriteLogic = require("src.game.network.marketplace_favorite_logic")

local leaderboardClient = {}

local MAP_CATEGORY_ONLINE = "online"
local DEFAULT_LEADERBOARD_LIMIT = 50
local DEFAULT_MARKETPLACE_LIMIT = 10
local DEFAULT_REPLAY_METADATA_LIMIT = 5

local function normalizeBaseUrl(baseUrl)
    return tostring(baseUrl or ""):gsub("/+$", "")
end

local function urlEncode(value)
    local text = tostring(value or "")
    return (text:gsub("([^%w%-_%.~])", function(character)
        return string.format("%%%02X", character:byte())
    end))
end

local function normalizeConfig(config)
    local resolvedConfig = config or envLoader.load()
    if not resolvedConfig.isConfigured then
        return nil, table.concat(resolvedConfig.errors or { "The online leaderboard is not configured." }, " ")
    end
    return resolvedConfig
end

local function getTimeoutSeconds(config)
    local timeoutSeconds = tonumber(config and config.timeoutSeconds)
    if timeoutSeconds ~= nil and timeoutSeconds > 0 then
        return timeoutSeconds
    end

    return nil
end

local function postJson(config, endpointPath, payload)
    return httpTransport.postJson({
        url = normalizeBaseUrl(config.apiBaseUrl) .. tostring(endpointPath or ""),
        apiKey = config.apiKey,
        hmacSecret = config.hmacSecret,
        payload = payload,
        timeoutSeconds = getTimeoutSeconds(config),
    })
end

local function getJson(config, endpointPath)
    return httpTransport.getJson({
        url = normalizeBaseUrl(config.apiBaseUrl) .. tostring(endpointPath or ""),
        apiKey = config.apiKey,
        timeoutSeconds = getTimeoutSeconds(config),
    })
end

local function deleteJson(config, endpointPath, payload)
    return httpTransport.deleteJson({
        url = normalizeBaseUrl(config.apiBaseUrl) .. tostring(endpointPath or ""),
        apiKey = config.apiKey,
        hmacSecret = config.hmacSecret,
        payload = payload,
        timeoutSeconds = getTimeoutSeconds(config),
    })
end

function leaderboardClient.getConfig()
    return envLoader.load()
end

function leaderboardClient.fetchLeaderboard(requestOptions, config)
    local resolvedConfig, configError = normalizeConfig(config)
    if not resolvedConfig then
        return nil, configError
    end

    local size = math.max(1, tonumber(requestOptions.size or requestOptions.limit or DEFAULT_LEADERBOARD_LIMIT) or DEFAULT_LEADERBOARD_LIMIT)
    local mapUuid = tostring(requestOptions.mapUuid or "")
    local endpointPath

    if mapUuid ~= "" then
        endpointPath = string.format("/api/maps/%s/leaderboard?size=%d", mapUuid, size)
        local playerUuid = tostring(requestOptions.player_uuid or "")
        if playerUuid ~= "" then
            endpointPath = endpointPath .. "&player_uuid=" .. urlEncode(playerUuid)
        end

        local mapHash = tostring(requestOptions.mapHash or requestOptions.map_hash or "")
        if mapHash ~= "" then
            endpointPath = endpointPath .. "&map_hash=" .. urlEncode(mapHash)
        end

        if requestOptions.includeReplay == true or requestOptions.include_replay == true then
            endpointPath = endpointPath .. "&include_replay=true"
        end
    else
        endpointPath = string.format("/api/leaderboard?size=%d", size)
        local playerUuid = tostring(requestOptions.player_uuid or "")
        if playerUuid ~= "" then
            endpointPath = endpointPath .. "&player_uuid=" .. urlEncode(playerUuid)
        end
    end

    return getJson(resolvedConfig, endpointPath)
end

function leaderboardClient.fetchMarketplace(requestOptions, config)
    local resolvedConfig, configError = normalizeConfig(config)
    if not resolvedConfig then
        return nil, configError
    end

    local mode = tostring(requestOptions.mode or "favorites")
    local limit = math.max(1, tonumber(requestOptions.limit or DEFAULT_MARKETPLACE_LIMIT) or DEFAULT_MARKETPLACE_LIMIT)
    local playerUuid = tostring(requestOptions.player_uuid or "")
    local endpointPath

    if mode == "search" then
        local query = tostring(requestOptions.query or ""):gsub("^%s+", ""):gsub("%s+$", "")
        endpointPath = string.format("/api/maps/search?q=%s&limit=%d", urlEncode(query), limit)
    else
        endpointPath = string.format("/api/maps/favorites?limit=%d", limit)
    end

    if playerUuid ~= "" then
        endpointPath = endpointPath .. "&player_uuid=" .. urlEncode(playerUuid)
    end

    return getJson(resolvedConfig, endpointPath)
end

function leaderboardClient.submitScore(submission, config)
    local resolvedConfig, configError = normalizeConfig(config)
    if not resolvedConfig then
        return nil, configError
    end

    local mapUuid = tostring(submission.mapUuid or "")
    if mapUuid == "" then
        return nil, "The score could not be uploaded because the map UUID is missing."
    end

    local endpointPath = string.format("/api/maps/%s/score", mapUuid)
    local payload = {
        player_uuid = tostring(submission.player_uuid or ""),
        display_name = tostring(submission.playerDisplayName or ""),
        score = tonumber(submission.score or 0) or 0,
    }
    local mapHash = tostring(submission.mapHash or submission.map_hash or "")
    if mapHash ~= "" then
        payload.map_hash = mapHash
    end

    return postJson(resolvedConfig, endpointPath, payload)
end

function leaderboardClient.submitReplay(submission, config)
    local resolvedConfig, configError = normalizeConfig(config)
    if not resolvedConfig then
        return nil, configError
    end

    local mapUuid = tostring(submission.mapUuid or "")
    if mapUuid == "" then
        return nil, "The replay could not be uploaded because the map UUID is missing."
    end

    local playerUuid = tostring(submission.player_uuid or "")
    if playerUuid == "" then
        return nil, "The replay could not be uploaded because the player UUID is missing."
    end

    local displayName = tostring(submission.playerDisplayName or "")
    if displayName == "" then
        return nil, "The replay could not be uploaded because the player display name is missing."
    end

    local mapHash = tostring(submission.mapHash or submission.map_hash or "")
    if mapHash == "" then
        return nil, "The replay could not be uploaded because the map hash is missing."
    end

    if type(submission.replay) ~= "table" then
        return nil, "The replay could not be uploaded because the replay payload is missing."
    end

    local endpointPath = string.format("/api/maps/%s/replays", mapUuid)
    local payload = {
        player_uuid = playerUuid,
        display_name = displayName,
        score = tonumber(submission.score or 0) or 0,
        map_hash = mapHash,
        replay = submission.replay,
    }

    return postJson(resolvedConfig, endpointPath, payload)
end

function leaderboardClient.recordMapPlay(submission, config)
    local resolvedConfig, configError = normalizeConfig(config)
    if not resolvedConfig then
        return nil, configError
    end

    local mapUuid = tostring(submission.mapUuid or "")
    if mapUuid == "" then
        return nil, "The play count could not be recorded because the map UUID is missing."
    end

    local mapHash = tostring(submission.mapHash or submission.map_hash or "")
    if mapHash == "" then
        return nil, "The play count could not be recorded because the map hash is missing."
    end

    return postJson(resolvedConfig, string.format("/api/maps/%s/plays", mapUuid), {
        display_name = tostring(submission.playerDisplayName or ""),
        map_hash = mapHash,
        player_uuid = tostring(submission.player_uuid or ""),
    })
end

function leaderboardClient.fetchReplayMetadata(requestOptions, config)
    local resolvedConfig, configError = normalizeConfig(config)
    if not resolvedConfig then
        return nil, configError
    end

    local mapUuid = tostring(requestOptions.mapUuid or "")
    if mapUuid == "" then
        return nil, "Replay metadata could not be loaded because the map UUID is missing."
    end

    local mapHash = tostring(requestOptions.mapHash or requestOptions.map_hash or "")
    if mapHash == "" then
        return nil, "Replay metadata could not be loaded because the map hash is missing."
    end

    local limit = math.max(1, tonumber(requestOptions.limit or DEFAULT_REPLAY_METADATA_LIMIT) or DEFAULT_REPLAY_METADATA_LIMIT)
    local endpointPath = string.format("/api/maps/%s/replays?map_hash=%s&limit=%d", mapUuid, urlEncode(mapHash), limit)
    local playerUuid = tostring(requestOptions.player_uuid or "")
    if playerUuid ~= "" then
        endpointPath = endpointPath .. "&player_uuid=" .. urlEncode(playerUuid)
    end
    return getJson(resolvedConfig, endpointPath)
end

function leaderboardClient.fetchReplay(replayUuid, mapUuid, config)
    local resolvedConfig, configError = normalizeConfig(config)
    if not resolvedConfig then
        return nil, configError
    end

    local resolvedReplayUuid = tostring(replayUuid or "")
    local resolvedMapUuid = tostring(mapUuid or "")
    if resolvedMapUuid == "" then
        return nil, "Replay download could not start because the map UUID is missing."
    end
    if resolvedReplayUuid == "" then
        return nil, "Replay download could not start because the replay UUID is missing."
    end

    local endpointPath = string.format("/api/maps/%s/replays/%s", resolvedMapUuid, resolvedReplayUuid)
    return getJson(resolvedConfig, endpointPath)
end

function leaderboardClient.uploadMap(submission, config)
    local resolvedConfig, configError = normalizeConfig(config)
    if not resolvedConfig then
        return nil, configError
    end

    local mapUuid = tostring(submission.mapUuid or "")
    if mapUuid == "" then
        return nil, "The map could not be uploaded because the map UUID is missing."
    end

    local creatorUuid = tostring(submission.creator_uuid or "")
    if creatorUuid == "" then
        return nil, "The map could not be uploaded because the creator UUID is missing."
    end

    local mapName = tostring(submission.mapName or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if mapName == "" then
        mapName = "Untitled Map"
    end

    local display_name = tostring(submission.playerDisplayName or "")
    if display_name == "" then
        return nil, "The map could not be uploaded because the player display name is missing."
    end


    if type(submission.map) ~= "table" then
        return nil, "The map could not be uploaded because its level data is missing."
    end

    local payload = {
        map_uuid = mapUuid,
        map_name = mapName,
        map_category = tostring(submission.mapCategory or MAP_CATEGORY_ONLINE),
        creator_uuid = creatorUuid,
        display_name = display_name,
        map = submission.map,
    }
    local mapHash = tostring(submission.mapHash or submission.map_hash or "")
    if mapHash ~= "" then
        payload.map_hash = mapHash
    end

    return postJson(resolvedConfig, "/api/maps", payload)
end

function leaderboardClient.favoriteMap(submission, config)
    local resolvedConfig, configError = normalizeConfig(config)
    if not resolvedConfig then
        return nil, configError
    end

    local mapUuid = tostring(submission.mapUuid or "")
    if mapUuid == "" then
        return nil, "The map could not be liked because the map UUID is missing."
    end

    local playerUuid = tostring(submission.player_uuid or "")
    if playerUuid == "" then
        return nil, "The map could not be liked because the player UUID is missing."
    end

    local endpointPath = string.format("/api/maps/%s/favorites", mapUuid)
    local payload = marketplaceFavoriteLogic.buildRequestPayload(playerUuid)
    if submission.liked == true then
        return postJson(resolvedConfig, endpointPath, payload)
    end

    return deleteJson(resolvedConfig, endpointPath, payload)
end

return leaderboardClient
