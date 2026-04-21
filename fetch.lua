local json = require("src.game.util.json")

local fetch = {}

local REQUEST_DIRECTORY = ".web_fetch_bridge/requests"
local RESPONSE_DIRECTORY = ".web_fetch_bridge/responses"
local RESPONSE_STATUS_ERROR = 0

local nextRequestNumber = 0
local pendingCallbacksByRequestId = {}

local function trim(value)
    return (tostring(value or "")):gsub("^%s+", ""):gsub("%s+$", "")
end

local function ensureBridgeDirectories()
    if not (love and love.filesystem and love.filesystem.createDirectory) then
        return false, "The HTML5 fetch bridge is unavailable."
    end

    love.filesystem.createDirectory(REQUEST_DIRECTORY)
    love.filesystem.createDirectory(RESPONSE_DIRECTORY)
    return true
end

local function normalizeRequestOptions(options)
    local normalized = {
        method = "GET",
        headers = {},
        body = "",
    }

    if type(options) ~= "table" then
        return normalized
    end

    local method = trim(options.method)
    if method ~= "" then
        normalized.method = string.upper(method)
    end

    if type(options.headers) == "table" then
        for key, value in pairs(options.headers) do
            local normalizedKey = trim(key)
            if normalizedKey ~= "" then
                normalized.headers[normalizedKey] = tostring(value or "")
            end
        end
    end

    if options.body ~= nil then
        normalized.body = tostring(options.body)
    end

    return normalized
end

local function getRequestPath(requestId)
    return string.format("%s/%s.json", REQUEST_DIRECTORY, requestId)
end

local function getResponsePath(requestId)
    return string.format("%s/%s.json", RESPONSE_DIRECTORY, requestId)
end

local function buildRequestId()
    nextRequestNumber = nextRequestNumber + 1
    return string.format("%d_%d", os.time(), nextRequestNumber)
end

local function completeWithError(requestId, callback, message)
    pendingCallbacksByRequestId[requestId] = nil
    if callback then
        callback(RESPONSE_STATUS_ERROR, tostring(message or "The web request failed."))
    end
end

function fetch.request(url, options, callback)
    local resolvedOptions = options
    local resolvedCallback = callback

    if type(options) == "function" and callback == nil then
        resolvedCallback = options
        resolvedOptions = {}
    end

    local requestId = buildRequestId()
    local okDirectories, directoryError = ensureBridgeDirectories()
    if not okDirectories then
        completeWithError(requestId, resolvedCallback, directoryError)
        return nil
    end

    pendingCallbacksByRequestId[requestId] = resolvedCallback
    local normalizedOptions = normalizeRequestOptions(resolvedOptions)
    local payload = {
        url = tostring(url or ""),
        method = normalizedOptions.method,
        headers = normalizedOptions.headers,
        body = normalizedOptions.body,
    }

    local writeOk, writeError = love.filesystem.write(getRequestPath(requestId), json.encode(payload))
    if not writeOk then
        completeWithError(requestId, resolvedCallback, writeError or "The request could not be sent to the browser bridge.")
        return nil
    end

    return requestId
end

function fetch.update()
    if not (love and love.filesystem and love.filesystem.getInfo and love.filesystem.read and love.filesystem.remove) then
        return
    end

    for requestId, callback in pairs(pendingCallbacksByRequestId) do
        local responsePath = getResponsePath(requestId)
        if love.filesystem.getInfo(responsePath, "file") then
            local responseContent, readError = love.filesystem.read(responsePath)
            love.filesystem.remove(responsePath)
            pendingCallbacksByRequestId[requestId] = nil

            if not responseContent then
                if callback then
                    callback(RESPONSE_STATUS_ERROR, tostring(readError or "The browser response could not be read."))
                end
            else
                local decodedResponse, decodeError = json.decode(responseContent)
                if type(decodedResponse) ~= "table" then
                    if callback then
                        callback(RESPONSE_STATUS_ERROR, tostring(decodeError or "The browser response was invalid."))
                    end
                elseif callback then
                    callback(tonumber(decodedResponse.status) or RESPONSE_STATUS_ERROR, tostring(decodedResponse.body or ""))
                end
            end
        end
    end
end

return fetch
