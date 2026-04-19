local envLoader = require("src.game.env_loader")
local json = require("src.game.json")

local simpleboardsClient = {}

local SCRIPT_FILE = "simpleboards_request.ps1"
local REQUEST_FILE = "simpleboards_request.json"

local POWERSHELL_SCRIPT = [[
param(
    [string]$Mode,
    [string]$ApiKey,
    [string]$LeaderboardId,
    [string]$BodyPath
)

$ErrorActionPreference = 'Stop'
$headers = @{ 'x-api-key' = $ApiKey }

try {
    if ($Mode -eq 'submit') {
        $body = Get-Content -Raw -Path $BodyPath
        $result = Invoke-RestMethod -Method Post -Uri 'https://api.simpleboards.dev/api/entries' -Headers $headers -ContentType 'application/json' -Body $body
    }
    elseif ($Mode -eq 'fetch') {
        $uri = ('https://api.simpleboards.dev/api/leaderboards/{0}/entries' -f $LeaderboardId)
        $result = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
    }
    else {
        throw ('Unsupported mode: ' + $Mode)
    }

    @{ ok = $true; data = $result } | ConvertTo-Json -Depth 12 -Compress
}
catch {
    $detail = ''
    if ($_.Exception.Response) {
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
        $message = $message + ' | ' + $detail.Trim()
    }

    @{ ok = $false; error = $message } | ConvertTo-Json -Depth 6 -Compress
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
    if not love.filesystem.getInfo(SCRIPT_FILE, "file") then
        local ok, writeError = love.filesystem.write(SCRIPT_FILE, POWERSHELL_SCRIPT)
        if not ok then
            return nil, writeError or "The SimpleBoards helper script could not be written."
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

local function normalizeRemoteErrorMessage(message)
    local text = tostring(message or "")
    local lowerText = string.lower(text)

    if lowerText:find("key not found", 1, true) then
        return "SimpleBoards could not find this key. Check whether API_KEY and LEADERBOARD_ID are correct and belong to the same leaderboard."
    end

    return text ~= "" and text or "The online request failed."
end

local function runPowerShell(mode, config, payload)
    if not isWindows() then
        return nil, "Online score sync currently requires Windows PowerShell."
    end

    local scriptPath, scriptError = ensurePowerShellScript()
    if not scriptPath then
        return nil, scriptError
    end

    local requestPath
    if payload ~= nil then
        local requestBody = json.encode(payload)
        local ok, writeError = love.filesystem.write(REQUEST_FILE, requestBody)
        if not ok then
            return nil, writeError or "The score payload could not be written."
        end
        requestPath = absoluteSavePath(REQUEST_FILE)
    end

    local command = table.concat({
        "powershell.exe -NoProfile -ExecutionPolicy Bypass -File",
        quoteArgument(scriptPath),
        "-Mode",
        quoteArgument(mode),
        "-ApiKey",
        quoteArgument(config.apiKey),
        "-LeaderboardId",
        quoteArgument(config.leaderboardId),
        "-BodyPath",
        quoteArgument(requestPath or ""),
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

    return response.data
end

local function normalizeConfig(config)
    local resolvedConfig = config or envLoader.load()
    if not resolvedConfig.isConfigured then
        return nil, table.concat(resolvedConfig.errors or { "SimpleBoards is not configured." }, " ")
    end
    return resolvedConfig
end

function simpleboardsClient.getConfig()
    return envLoader.load()
end

function simpleboardsClient.submitScore(submission, config)
    local resolvedConfig, configError = normalizeConfig(config)
    if not resolvedConfig then
        return nil, configError
    end

    local payload = {
        leaderboardId = resolvedConfig.leaderboardId,
        playerId = submission.playerId,
        playerDisplayName = submission.playerDisplayName,
        score = tostring(submission.score or "0"),
        metadata = submission.metadata or "",
    }

    return runPowerShell("submit", resolvedConfig, payload)
end

function simpleboardsClient.fetchLeaderboard(config)
    local resolvedConfig, configError = normalizeConfig(config)
    if not resolvedConfig then
        return nil, configError
    end

    local response, fetchError = runPowerShell("fetch", resolvedConfig)
    if not response then
        return nil, fetchError or "The leaderboard could not be loaded."
    end

    if type(response) == "table" and type(response.entries) == "table" then
        return response.entries
    end

    return response
end

return simpleboardsClient


