local json = require("src.game.util.json")

local requestInspector = {}

local DEFAULT_METHOD = "GET"
local MAX_SANITIZE_DEPTH = 4
local MAX_SANITIZED_STRING_LENGTH = 280
local MAX_TABLE_ENTRY_COUNT = 18
local REDACTED_VALUE = "[redacted]"
local TRUNCATED_SUFFIX = "..."

local SENSITIVE_TOKENS = {
    authorization = true,
    hmac = true,
    key = true,
    keys = true,
    secret = true,
    secrets = true,
    signature = true,
    signatures = true,
    token = true,
    tokens = true,
}

local function getNowSeconds()
    if love and love.timer and love.timer.getTime then
        return love.timer.getTime()
    end

    return os.clock()
end

local function sanitizeString(value)
    local text = tostring(value or "")
    if #text <= MAX_SANITIZED_STRING_LENGTH then
        return text
    end

    return text:sub(1, MAX_SANITIZED_STRING_LENGTH - #TRUNCATED_SUFFIX) .. TRUNCATED_SUFFIX
end

local function looksLikeJson(text)
    local firstCharacter = tostring(text or ""):match("^%s*(.)")
    return firstCharacter == "{" or firstCharacter == "[" or firstCharacter == "\""
end

local function normalizeKeyText(value)
    return tostring(value or "")
        :gsub("(%l)(%u)", "%1_%2")
        :gsub("[^%w]+", "_")
        :lower()
end

local function getKeyTokens(value)
    local normalizedValue = normalizeKeyText(value)
    local tokens = {}

    for token in normalizedValue:gmatch("[^_]+") do
        tokens[#tokens + 1] = token
    end

    return tokens
end

local function isSensitiveKey(key)
    for _, token in ipairs(getKeyTokens(key)) do
        if SENSITIVE_TOKENS[token] then
            return true
        end
    end

    return false
end

local function sortKeys(leftValue, rightValue)
    local leftIsNumber = type(leftValue) == "number"
    local rightIsNumber = type(rightValue) == "number"

    if leftIsNumber and rightIsNumber then
        return leftValue < rightValue
    end

    if leftIsNumber ~= rightIsNumber then
        return leftIsNumber
    end

    return tostring(leftValue) < tostring(rightValue)
end

local function isArrayLike(value)
    if type(value) ~= "table" then
        return false
    end

    local maxIndex = 0
    local itemCount = 0
    for key, _ in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end

        itemCount = itemCount + 1
        if key > maxIndex then
            maxIndex = key
        end
    end

    return maxIndex == itemCount
end

local function sanitizeValue(key, value, depth, visitedTables)
    if isSensitiveKey(key) then
        return REDACTED_VALUE
    end

    local valueType = type(value)
    if valueType == "nil" or valueType == "boolean" or valueType == "number" then
        return value
    end

    if valueType == "string" then
        if looksLikeJson(value) then
            local decodedValue = json.decode(value)
            if type(decodedValue) == "table" then
                return sanitizeValue(key, decodedValue, depth, visitedTables)
            end
        end

        return sanitizeString(value)
    end

    if valueType ~= "table" then
        return sanitizeString(value)
    end

    if visitedTables[value] then
        return "[circular]"
    end

    if depth >= MAX_SANITIZE_DEPTH then
        return "[depth limit]"
    end

    visitedTables[value] = true

    local sanitizedTable
    local sortedKeys = {}
    for currentKey, _ in pairs(value) do
        sortedKeys[#sortedKeys + 1] = currentKey
    end
    table.sort(sortedKeys, sortKeys)

    if isArrayLike(value) then
        sanitizedTable = {}
        local visibleCount = math.min(#sortedKeys, MAX_TABLE_ENTRY_COUNT)
        for index = 1, visibleCount do
            local currentKey = sortedKeys[index]
            sanitizedTable[#sanitizedTable + 1] = sanitizeValue(currentKey, value[currentKey], depth + 1, visitedTables)
        end
        if #sortedKeys > visibleCount then
            sanitizedTable[#sanitizedTable + 1] = string.format("[+%d more item(s)]", #sortedKeys - visibleCount)
        end
    else
        sanitizedTable = {}
        local visibleCount = math.min(#sortedKeys, MAX_TABLE_ENTRY_COUNT)
        for index = 1, visibleCount do
            local currentKey = sortedKeys[index]
            sanitizedTable[tostring(currentKey)] = sanitizeValue(currentKey, value[currentKey], depth + 1, visitedTables)
        end
        if #sortedKeys > visibleCount then
            sanitizedTable["..."] = string.format("%d more field(s)", #sortedKeys - visibleCount)
        end
    end

    visitedTables[value] = nil
    return sanitizedTable
end

local function sanitizeUrl(url)
    local normalizedUrl = tostring(url or "")
    local queryStart = normalizedUrl:find("?", 1, true)
    if not queryStart then
        return sanitizeString(normalizedUrl)
    end

    local baseUrl = normalizedUrl:sub(1, queryStart - 1)
    local queryString = normalizedUrl:sub(queryStart + 1)
    local sanitizedParameters = {}

    for parameter in queryString:gmatch("[^&]+") do
        local separatorIndex = parameter:find("=", 1, true)
        if separatorIndex then
            local key = parameter:sub(1, separatorIndex - 1)
            local value = parameter:sub(separatorIndex + 1)
            if isSensitiveKey(key) then
                sanitizedParameters[#sanitizedParameters + 1] = key .. "=" .. REDACTED_VALUE
            else
                sanitizedParameters[#sanitizedParameters + 1] = key .. "=" .. sanitizeString(value)
            end
        else
            sanitizedParameters[#sanitizedParameters + 1] = parameter
        end
    end

    return sanitizeString(baseUrl .. "?" .. table.concat(sanitizedParameters, "&"))
end

local function getRouteLabel(url)
    local sanitizedUrl = sanitizeUrl(url)
    local route = sanitizedUrl:match("^https?://[^/]+(/.*)$") or sanitizedUrl
    route = route:gsub("%?.*$", "")
    if route == "" then
        return "/"
    end

    return route
end

function requestInspector.beginRequest(options)
    requestInspector._requestSequence = (requestInspector._requestSequence or 0) + 1

    local resolvedMethod = tostring(options.method or DEFAULT_METHOD)
    return {
        eventKind = "network_request_debug",
        phase = "started",
        requestDebugId = requestInspector._requestSequence,
        requestKind = sanitizeString(tostring(options.requestKind or "")),
        flowRequestId = tonumber(options.flowRequestId),
        method = resolvedMethod,
        url = sanitizeUrl(options.url),
        route = getRouteLabel(options.url),
        headers = sanitizeValue("headers", options.headers or {}, 0, {}),
        requestBody = sanitizeValue("request_body", options.requestBody, 0, {}),
        timeoutSeconds = tonumber(options.timeoutSeconds or 0) or 0,
        startedAtSeconds = getNowSeconds(),
        startedAtUnixSeconds = os.time and os.time() or nil,
    }
end

function requestInspector.finishRequest(entry, result)
    local finishedAtSeconds = getNowSeconds()
    local completedEntry = {}

    for key, value in pairs(entry or {}) do
        completedEntry[key] = value
    end

    completedEntry.eventKind = "network_request_debug"
    completedEntry.phase = "finished"
    completedEntry.ok = result and result.ok == true or false
    completedEntry.status = tonumber(result and result.status)
    completedEntry.error = sanitizeString(tostring(result and result.error or ""))
    if completedEntry.error == "" then
        completedEntry.error = nil
    end
    completedEntry.responseBody = sanitizeValue("response_body", result and result.responseBody, 0, {})
    completedEntry.finishedAtSeconds = finishedAtSeconds
    completedEntry.finishedAtUnixSeconds = os.time and os.time() or nil
    completedEntry.durationMilliseconds = math.max(
        0,
        math.floor(((finishedAtSeconds - tonumber(entry and entry.startedAtSeconds or finishedAtSeconds)) * 1000) + 0.5)
    )

    return completedEntry
end

function requestInspector.sanitizeValueForDisplay(key, value)
    return sanitizeValue(key, value, 0, {})
end

function requestInspector.sanitizeUrl(url)
    return sanitizeUrl(url)
end

function requestInspector.isSensitiveKey(key)
    return isSensitiveKey(key)
end

return requestInspector
