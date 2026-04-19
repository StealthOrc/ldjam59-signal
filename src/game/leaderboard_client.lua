local envLoader = require("src.game.env_loader")
local json = require("src.game.json")

local leaderboardClient = {}

local SCRIPT_FILE = "leaderboard_request.ps1"
local REQUEST_FILE = "leaderboard_request.json"
local REQUEST_MODE_SUBMIT = "submit"
local REQUEST_MODE_UPLOAD_MAP = "upload_map"
local REQUEST_MODE_FAVORITE_MAP = "favorite_map"

local POWERSHELL_SCRIPT = [[
param(
    [string]$Mode,
    [string]$ApiKey,
    [string]$ApiBaseUrl,
    [string]$EndpointPath,
    [string]$BodyPath,
    [string]$HmacSecret
)

$ErrorActionPreference = 'Stop'
$headers = @{ 'x-api-key' = $ApiKey }
$uri = $ApiBaseUrl.TrimEnd('/') + $EndpointPath

try {
    if ($Mode -eq 'submit' -or $Mode -eq 'upload_map' -or $Mode -eq 'favorite_map') {
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
        $response = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $uri -Headers $headers -ContentType 'application/json' -Body $body
    }
    else {
        throw ('Unsupported mode: ' + $Mode)
    }

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

local function isWindows()
    return package.config:sub(1, 1) == "\\"
end

local function absoluteSavePath(relativePath)
    local separator = package.config:sub(1, 1)
    return love.filesystem.getSaveDirectory() .. separator .. relativePath:gsub("/", separator)
end

local function quoteArgument(value)
    return '"' .. tostring(value or ""):gsub('"', '""') .. '"'
end

local function ensurePowerShellScript()
    local existingScript = nil
    if love.filesystem.getInfo(SCRIPT_FILE, "file") then
        existingScript = love.filesystem.read(SCRIPT_FILE)
    end

    if existingScript ~= POWERSHELL_SCRIPT then
        local ok, writeError = love.filesystem.write(SCRIPT_FILE, POWERSHELL_SCRIPT)
        if not ok then
            return nil, writeError or "The leaderboard helper script could not be written."
        end
    end

    return absoluteSavePath(SCRIPT_FILE)
end

local function runCommand(command)
    local handle = io.popen(command .. " 2>&1")
    if not handle then
        return nil, "PowerShell could not be started."
    end

    local output = handle:read("*a") or ""
    handle:close()
    return output
end

local function extractJsonError(message)
    local decoded = json.decode(tostring(message or ""))
    if type(decoded) == "table" and type(decoded.error) == "string" and decoded.error ~= "" then
        return decoded.error
    end

    return tostring(message or "")
end

local function normalizeRemoteErrorMessage(message)
    local text = extractJsonError(message)
    return text ~= "" and text or "The online request failed."
end

local function runPowerShell(mode, config, endpointPath, payload)
    if not isWindows() then
        return nil, "Online score sync currently requires Windows PowerShell."
    end

    local scriptPath, scriptError = ensurePowerShellScript()
    if not scriptPath then
        return nil, scriptError
    end

    local requestBody = json.encode(payload)
    local ok, writeError = love.filesystem.write(REQUEST_FILE, requestBody)
    if not ok then
        return nil, writeError or "The score payload could not be written."
    end

    local command = table.concat({
        "powershell.exe -NoProfile -ExecutionPolicy Bypass -File",
        quoteArgument(scriptPath),
        "-Mode",
        quoteArgument(mode),
        "-ApiKey",
        quoteArgument(config.apiKey),
        "-ApiBaseUrl",
        quoteArgument(config.apiBaseUrl),
        "-EndpointPath",
        quoteArgument(endpointPath),
        "-BodyPath",
        quoteArgument(absoluteSavePath(REQUEST_FILE)),
        "-HmacSecret",
        quoteArgument(config.hmacSecret),
    }, " ")

    local output, runError = runCommand(command)
    if not output then
        return nil, runError
    end

    local response, decodeError = json.decode(output)
    if not response then
        return nil, normalizeRemoteErrorMessage(decodeError or output)
    end

    if response.ok ~= true then
        return nil, normalizeRemoteErrorMessage(response.error)
    end

    return response.data, nil, response.status
end

local function normalizeConfig(config)
    local resolvedConfig = config or envLoader.load()
    if not resolvedConfig.isConfigured then
        return nil, table.concat(resolvedConfig.errors or { "The online leaderboard is not configured." }, " ")
    end
    return resolvedConfig
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
        player_uuid = tostring(submission.player_uuid or submission.playerUuid or ""),
        display_name = tostring(submission.playerDisplayName or ""),
        score = tonumber(submission.score or 0) or 0,
    }

    return runPowerShell(REQUEST_MODE_SUBMIT, resolvedConfig, endpointPath, payload)
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

    local creatorUuid = tostring(submission.creator_uuid or submission.creatorUuid or "")
    if creatorUuid == "" then
        return nil, "The map could not be uploaded because the creator UUID is missing."
    end

    local mapName = tostring(submission.mapName or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if mapName == "" then
        mapName = "Untitled Map"
    end

    if type(submission.map) ~= "table" then
        return nil, "The map could not be uploaded because its level data is missing."
    end

    local payload = {
        map_uuid = mapUuid,
        map_name = mapName,
        creator_uuid = creatorUuid,
        map = submission.map,
    }

    return runPowerShell(REQUEST_MODE_UPLOAD_MAP, resolvedConfig, "/api/maps", payload)
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

    local playerUuid = tostring(submission.player_uuid or submission.playerUuid or "")
    if playerUuid == "" then
        return nil, "The map could not be liked because the player UUID is missing."
    end

    local endpointPath = string.format("/api/maps/%s/favorites", mapUuid)
    local payload = {
        player_uuid = playerUuid,
    }

    return runPowerShell(REQUEST_MODE_FAVORITE_MAP, resolvedConfig, endpointPath, payload)
end

return leaderboardClient
