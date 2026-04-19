local json = require("src.game.json")

local REQUEST_CHANNEL_NAME = "signal_leaderboard_request"
local RESPONSE_CHANNEL_NAME = "signal_leaderboard_response"
local REQUEST_KIND_FETCH = "fetch"
local REQUEST_KIND_PREVIEW = "preview"
local REQUEST_KIND_MARKETPLACE = "marketplace"
local REQUEST_KIND_FAVORITE_MAP = "favorite_map"
local REQUEST_KIND_SCORE_SUBMIT = "score_submit"
local REQUEST_KIND_UPLOAD_MAP = "upload_map"
local CURL_STATUS_PREFIX = "__STATUS__"
local DEFAULT_LEADERBOARD_LIMIT = 50
local DEFAULT_PREVIEW_LIMIT = 5
local DEFAULT_MARKETPLACE_LIMIT = 10
local DEFAULT_REQUEST_TIMEOUT_SECONDS = 5
local MARKETPLACE_MODE_FAVORITES = "favorites"
local MARKETPLACE_MODE_SEARCH = "search"

local requestChannel = love.thread.getChannel(REQUEST_CHANNEL_NAME)
local responseChannel = love.thread.getChannel(RESPONSE_CHANNEL_NAME)
local POWERSHELL_POST_SCRIPT_FILE = "leaderboard_thread_post_request.ps1"
local DIRECTORY_SEPARATOR = package.config:sub(1, 1)

local POWERSHELL_POST_SCRIPT = [[
param(
    [string]$ApiKey,
    [string]$Uri,
    [string]$BodyPath,
    [string]$HmacSecret
)

$ErrorActionPreference = 'Stop'
$headers = @{ 'x-api-key' = $ApiKey }

try {
    $body = Get-Content -Raw -Path $BodyPath
    if ($HmacSecret -and $HmacSecret.Trim().Length -gt 0) {
        $encoding = [System.Text.Encoding]::UTF8
        $hmac = [System.Security.Cryptography.HMACSHA256]::new($encoding.GetBytes($HmacSecret))
        try {
            $signatureBytes = $hmac.ComputeHash($encoding.GetBytes($body))
        }
        finally {
            $hmac.Dispose()
        }
        $signature = [System.BitConverter]::ToString($signatureBytes).Replace('-', '').ToLowerInvariant()
        $headers['x-signature'] = 'sha256=' + $signature
    }

    $response = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $Uri -Headers $headers -ContentType 'application/json' -Body $body
    $data = $null
    if ($response.Content -and $response.Content.Trim().Length -gt 0) {
        $data = $response.Content | ConvertFrom-Json
    }

    @{ ok = $true; status = [int]$response.StatusCode; data = $data } | ConvertTo-Json -Depth 12 -Compress
}
catch {
    $detail = ''
    $statusCode = $null
    if ($_.Exception.Response) {
        try {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        catch {
            $statusCode = $null
        }

        try {
            $stream = $_.Exception.Response.GetResponseStream()
            if ($stream) {
                $reader = New-Object System.IO.StreamReader($stream)
                $detail = $reader.ReadToEnd()
            }
        }
        catch {
            $detail = ''
        }
    }

    $message = $_.Exception.Message
    if ($detail -and $detail.Trim().Length -gt 0) {
        $message = $detail.Trim()
    }

    @{ ok = $false; status = $statusCode; error = $message } | ConvertTo-Json -Depth 8 -Compress
    exit 1
}
]]

local function quoteArgument(value)
    return '"' .. tostring(value or ""):gsub('"', '\\"') .. '"'
end

local function absoluteSavePath(relativePath)
    return love.filesystem.getSaveDirectory() .. DIRECTORY_SEPARATOR .. relativePath:gsub("/", DIRECTORY_SEPARATOR)
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

local function ensurePowerShellPostScript()
    local existingScript = nil
    if love.filesystem.getInfo(POWERSHELL_POST_SCRIPT_FILE, "file") then
        existingScript = love.filesystem.read(POWERSHELL_POST_SCRIPT_FILE)
    end

    if existingScript ~= POWERSHELL_POST_SCRIPT then
        local ok, writeError = love.filesystem.write(POWERSHELL_POST_SCRIPT_FILE, POWERSHELL_POST_SCRIPT)
        if not ok then
            return nil, writeError or "The online request helper could not be written."
        end
    end

    return absoluteSavePath(POWERSHELL_POST_SCRIPT_FILE)
end

local function validateConfig(config)
    if tostring(config.apiKey or "") == "" then
        return nil, "API_KEY is missing."
    end

    if normalizeBaseUrl(config.apiBaseUrl) == "" then
        return nil, "API_BASE_URL is missing."
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

local function runJsonPost(config, endpointPath, payload, requestId)
    local _, validationError = validateConfig(config)
    if validationError then
        return nil, validationError
    end

    local scriptPath, scriptError = ensurePowerShellPostScript()
    if not scriptPath then
        return nil, scriptError
    end

    local bodyText = json.encode(payload)
    local requestFile = string.format("leaderboard_thread_request_%s_%s.json", tostring(requestId or "0"), tostring(config.mode or "post"))
    local ok, writeError = love.filesystem.write(requestFile, bodyText)
    if not ok then
        return nil, writeError or "The online request payload could not be written."
    end

    local uri = normalizeBaseUrl(config.apiBaseUrl) .. tostring(endpointPath or "")
    local command = table.concat({
        "powershell.exe -NoProfile -ExecutionPolicy Bypass -File",
        quoteArgument(scriptPath),
        "-ApiKey",
        quoteArgument(config.apiKey),
        "-Uri",
        quoteArgument(uri),
        "-BodyPath",
        quoteArgument(absoluteSavePath(requestFile)),
        "-HmacSecret",
        quoteArgument(config.hmacSecret),
    }, " ")

    local output = runCommand(command)
    love.filesystem.remove(requestFile)
    if not output then
        return nil, "The online request could not be started."
    end

    local response, decodeError = json.decode(output)
    if type(response) ~= "table" then
        return nil, decodeError or "The online response could not be parsed."
    end

    if response.ok ~= true then
        return nil, tostring(response.error or "The online request failed."), response.status
    end

    return response.data, nil, response.status
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

    local playerUuid = tostring(config.player_uuid or config.playerUuid or "")
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
        uri = buildMarketplaceSearchUri(config.apiBaseUrl, config.query, config.limit, config.player_uuid or config.playerUuid)
    else
        uri = buildMarketplaceFavoritesUri(config.apiBaseUrl, config.limit, config.player_uuid or config.playerUuid)
    end

    return fetchJson(uri, config.apiKey)
end

local function favoriteMarketplaceMap(config, requestId)
    local mapUuid = tostring(config.mapUuid or "")
    if mapUuid == "" then
        return nil, "The selected online map is missing its map UUID."
    end

    local playerUuid = tostring(config.player_uuid or config.playerUuid or "")
    if playerUuid == "" then
        return nil, "The current player UUID is missing."
    end

    return runJsonPost(config, string.format("/api/maps/%s/favorites", mapUuid), {
        player_uuid = playerUuid,
    }, requestId)
end

local function submitScore(config, requestId)
    local mapUuid = tostring(config.mapUuid or "")
    if mapUuid == "" then
        return nil, "The score could not be uploaded because the map UUID is missing."
    end

    return runJsonPost(config, string.format("/api/maps/%s/score", mapUuid), {
        player_uuid = tostring(config.player_uuid or config.playerUuid or ""),
        display_name = tostring(config.playerDisplayName or ""),
        score = tonumber(config.score or 0) or 0,
    }, requestId)
end

local function uploadMap(config, requestId)
    local mapUuid = tostring(config.mapUuid or "")
    if mapUuid == "" then
        return nil, "The map could not be uploaded because the map UUID is missing."
    end

    return runJsonPost(config, "/api/maps", {
        map_uuid = mapUuid,
        map_name = tostring(config.mapName or ""),
        creator_uuid = tostring(config.creator_uuid or config.creatorUuid or ""),
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
