local envLoader = require("src.game.network.env_loader")
local httpTransport = require("src.game.network.http_transport")
local marketplaceFavoriteLogic = require("src.game.network.marketplace_favorite_logic")

local leaderboardClient = {}

local MAP_CATEGORY_ONLINE = "online"

local function normalizeBaseUrl(baseUrl)
    return tostring(baseUrl or ""):gsub("/+$", "")
end

local function normalizeConfig(config)
    local resolvedConfig = config or envLoader.load()
    if not resolvedConfig.isConfigured then
        return nil, table.concat(resolvedConfig.errors or { "The online leaderboard is not configured." }, " ")
    end
    return resolvedConfig
end

local function postJson(config, endpointPath, payload)
    return httpTransport.postJson({
        url = normalizeBaseUrl(config.apiBaseUrl) .. tostring(endpointPath or ""),
        apiKey = config.apiKey,
        hmacSecret = config.hmacSecret,
        payload = payload,
    })
end

local function getJson(config, endpointPath)
    return httpTransport.getJson({
        url = normalizeBaseUrl(config.apiBaseUrl) .. tostring(endpointPath or ""),
        apiKey = config.apiKey,
    })
end

function leaderboardClient.getConfig()
    return envLoader.load()
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

    local limit = math.max(1, tonumber(requestOptions.limit or 5) or 5)
    local endpointPath = string.format("/api/maps/%s/replays?map_hash=%s&limit=%d", mapUuid, mapHash, limit)
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

    return httpTransport.deleteJson({
        url = normalizeBaseUrl(resolvedConfig.apiBaseUrl) .. endpointPath,
        apiKey = resolvedConfig.apiKey,
        hmacSecret = resolvedConfig.hmacSecret,
        payload = payload,
    })
end

return leaderboardClient
