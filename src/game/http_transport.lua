local json = require("src.game.json")
local nativeLoader = require("src.game.native_loader")

local httpTransport = {}

local DEFAULT_REQUEST_TIMEOUT_SECONDS = 5
local DEFAULT_REMOTE_ERROR_MESSAGE = "The online request failed."
local HTTP_METHOD_GET = "GET"
local HTTP_METHOD_POST = "POST"
local HTTP_METHOD_DELETE = "DELETE"
local HTTP_STATUS_MIN_SUCCESS = 200
local HTTP_STATUS_MAX_SUCCESS = 299
local HTTPS_MODULE_NAME = "https"
local LUASEC_HTTPS_MODULE_NAME = "ssl.https"
local SOCKET_HTTP_MODULE_NAME = "socket.http"
local SOCKET_MODULE_NAME = "socket"
local LTN12_MODULE_NAME = "ltn12"
local BIT_MODULE_NAME = "bit"
local HMAC_BLOCK_SIZE_BYTES = 64
local HMAC_INNER_PAD_BYTE = 54
local HMAC_OUTER_PAD_BYTE = 92
local HMAC_SIGNATURE_HEADER_NAME = "x-signature"
local HMAC_SIGNATURE_PREFIX = "sha256="

local function trim(value)
    return (tostring(value or "")):gsub("^%s+", ""):gsub("%s+$", "")
end

local function isHttpsUrl(url)
    return tostring(url or ""):match("^https://") ~= nil
end

local function normalizeRemoteErrorMessage(message)
    local normalizedMessage = trim(message)
    if normalizedMessage == "" then
        return DEFAULT_REMOTE_ERROR_MESSAGE
    end

    local decodedMessage = json.decode(normalizedMessage)
    if type(decodedMessage) == "table" then
        local decodedError = trim(decodedMessage.error)
        if decodedError ~= "" then
            return decodedError
        end

        local decodedMessageText = trim(decodedMessage.message)
        if decodedMessageText ~= "" then
            return decodedMessageText
        end
    end

    return normalizedMessage
end

local function getBitModule()
    if httpTransport._bitModule == nil then
        httpTransport._bitModule = require(BIT_MODULE_NAME)
    end

    return httpTransport._bitModule
end

local function repeatCharacter(character, count)
    return string.rep(character, count)
end

local function xorStrings(leftValue, rightValue)
    local bitModule = getBitModule()
    local bytes = {}

    for index = 1, #leftValue do
        bytes[index] = string.char(bitModule.bxor(leftValue:byte(index), rightValue:byte(index)))
    end

    return table.concat(bytes)
end

local function getSha256Binary(value)
    if not (love and love.data and love.data.hash) then
        return nil, "SHA-256 hashing is unavailable."
    end

    local digest = love.data.hash("sha256", tostring(value or ""))
    if type(digest) == "userdata" and digest.getString then
        return digest:getString(), nil
    end

    if type(digest) == "string" then
        return digest, nil
    end

    return nil, "SHA-256 hashing returned an unsupported value."
end

local function getSha256Hex(value)
    if not (love and love.data and love.data.hash and love.data.encode) then
        return nil, "SHA-256 hashing is unavailable."
    end

    local digest = love.data.hash("sha256", tostring(value or ""))
    return love.data.encode("string", "hex", digest), nil
end

local function createHmacSha256Signature(secret, payload)
    local normalizedSecret = tostring(secret or "")
    if normalizedSecret == "" then
        return nil, nil
    end

    local key = normalizedSecret
    if #key > HMAC_BLOCK_SIZE_BYTES then
        local compactKey, compactKeyError = getSha256Binary(key)
        if not compactKey then
            return nil, compactKeyError
        end
        key = compactKey
    end

    if #key < HMAC_BLOCK_SIZE_BYTES then
        key = key .. repeatCharacter("\0", HMAC_BLOCK_SIZE_BYTES - #key)
    end

    local innerPad = xorStrings(key, repeatCharacter(string.char(HMAC_INNER_PAD_BYTE), HMAC_BLOCK_SIZE_BYTES))
    local outerPad = xorStrings(key, repeatCharacter(string.char(HMAC_OUTER_PAD_BYTE), HMAC_BLOCK_SIZE_BYTES))
    local innerDigest, innerDigestError = getSha256Binary(innerPad .. tostring(payload or ""))
    if not innerDigest then
        return nil, innerDigestError
    end

    local signatureHex, signatureError = getSha256Hex(outerPad .. innerDigest)
    if not signatureHex then
        return nil, signatureError
    end

    return HMAC_SIGNATURE_PREFIX .. signatureHex, nil
end

local function decodeResponseBody(bodyText, statusCode)
    local normalizedBody = trim(bodyText)
    if normalizedBody == "" then
        return nil, nil, statusCode
    end

    local decodedBody, decodeError = json.decode(normalizedBody)
    if type(decodedBody) ~= "table" then
        return nil, decodeError or "The online response was not valid JSON.", statusCode
    end

    return decodedBody, nil, statusCode
end

local function getSocketHttpModules()
    if httpTransport._socketHttp == nil or httpTransport._ltn12 == nil then
        httpTransport._socketHttp = require(SOCKET_HTTP_MODULE_NAME)
        httpTransport._ltn12 = require(LTN12_MODULE_NAME)
    end

    return httpTransport._socketHttp, httpTransport._ltn12
end

local function getSocketModule()
    if httpTransport._socketModule == nil then
        httpTransport._socketModule = require(SOCKET_MODULE_NAME)
    end

    return httpTransport._socketModule
end

local function getSecureClient()
    if httpTransport._secureClient ~= nil or httpTransport._secureClientError ~= nil then
        return httpTransport._secureClient, httpTransport._secureClientError
    end

    nativeLoader.configure()

    local okHttps, httpsClient = pcall(require, HTTPS_MODULE_NAME)
    if okHttps then
        httpTransport._secureClient = httpsClient
        httpTransport._secureClientKind = HTTPS_MODULE_NAME
        return httpTransport._secureClient, nil
    end

    local okLuaSec, luaSecHttpsClient = pcall(require, LUASEC_HTTPS_MODULE_NAME)
    if okLuaSec then
        httpTransport._secureClient = luaSecHttpsClient
        httpTransport._secureClientKind = LUASEC_HTTPS_MODULE_NAME
        return httpTransport._secureClient, nil
    end

    httpTransport._secureClientError = "HTTPS support is unavailable. Build and ship the native https module for LÖVE 11.5."
    return nil, httpTransport._secureClientError
end

local function requestWithSocketHttp(options)
    local socketModule = getSocketModule()
    local socketHttp, ltn12 = getSocketHttpModules()
    local timeoutSeconds = tonumber(options.timeoutSeconds or DEFAULT_REQUEST_TIMEOUT_SECONDS) or DEFAULT_REQUEST_TIMEOUT_SECONDS
    local responseChunks = {}
    local bodyText = tostring(options.body or "")

    socketModule.TIMEOUT = timeoutSeconds
    socketHttp.TIMEOUT = timeoutSeconds

    local _, statusCode, _, statusLine = socketHttp.request({
        url = tostring(options.url or ""),
        method = tostring(options.method or HTTP_METHOD_GET),
        headers = options.headers or {},
        source = bodyText ~= "" and ltn12.source.string(bodyText) or nil,
        sink = ltn12.sink.table(responseChunks),
    })

    local responseBody = table.concat(responseChunks)
    local numericStatusCode = tonumber(statusCode)
    if not numericStatusCode then
        return nil, normalizeRemoteErrorMessage(statusLine or responseBody)
    end

    if numericStatusCode < HTTP_STATUS_MIN_SUCCESS or numericStatusCode > HTTP_STATUS_MAX_SUCCESS then
        return nil, normalizeRemoteErrorMessage(responseBody), numericStatusCode
    end

    return decodeResponseBody(responseBody, numericStatusCode)
end

local function requestWithSecureClient(options)
    local secureClient, secureClientError = getSecureClient()
    if not secureClient then
        return nil, secureClientError
    end

    local requestBody = tostring(options.body or "")
    local statusCode
    local responseBody

    if httpTransport._secureClientKind == HTTPS_MODULE_NAME then
        statusCode, responseBody = secureClient.request(tostring(options.url or ""), {
            method = tostring(options.method or HTTP_METHOD_GET),
            data = requestBody ~= "" and requestBody or nil,
            headers = options.headers or {},
        })
    else
        local _, ltn12 = getSocketHttpModules()
        local responseChunks = {}
        local _, secureStatusCode, _, statusLine = secureClient.request({
            url = tostring(options.url or ""),
            method = tostring(options.method or HTTP_METHOD_GET),
            headers = options.headers or {},
            source = requestBody ~= "" and ltn12.source.string(requestBody) or nil,
            sink = ltn12.sink.table(responseChunks),
        })
        statusCode = secureStatusCode
        responseBody = table.concat(responseChunks)
        if not statusCode then
            return nil, normalizeRemoteErrorMessage(statusLine or responseBody)
        end
    end

    local numericStatusCode = tonumber(statusCode)
    if not numericStatusCode or numericStatusCode == 0 then
        return nil, normalizeRemoteErrorMessage(responseBody)
    end

    if numericStatusCode < HTTP_STATUS_MIN_SUCCESS or numericStatusCode > HTTP_STATUS_MAX_SUCCESS then
        return nil, normalizeRemoteErrorMessage(responseBody), numericStatusCode
    end

    return decodeResponseBody(responseBody, numericStatusCode)
end

function httpTransport.requestJson(options)
    local requestBody = tostring(options.body or "")
    local headers = {
        ["x-api-key"] = tostring(options.apiKey or ""),
    }

    if requestBody ~= "" then
        headers["content-type"] = "application/json"
        headers["content-length"] = tostring(#requestBody)
    end

    local signatureValue, signatureError = createHmacSha256Signature(options.hmacSecret, requestBody)
    if signatureError then
        return nil, signatureError
    end

    if signatureValue then
        headers[HMAC_SIGNATURE_HEADER_NAME] = signatureValue
    end

    if isHttpsUrl(options.url) then
        return requestWithSecureClient({
            url = options.url,
            method = options.method,
            headers = headers,
            body = requestBody,
            timeoutSeconds = options.timeoutSeconds,
        })
    end

    return requestWithSocketHttp({
        url = options.url,
        method = options.method,
        headers = headers,
        body = requestBody,
        timeoutSeconds = options.timeoutSeconds,
    })
end

function httpTransport.getJson(options)
    return httpTransport.requestJson({
        method = HTTP_METHOD_GET,
        url = options.url,
        apiKey = options.apiKey,
        hmacSecret = "",
        timeoutSeconds = options.timeoutSeconds,
        body = "",
    })
end

function httpTransport.postJson(options)
    return httpTransport.requestJson({
        method = HTTP_METHOD_POST,
        url = options.url,
        apiKey = options.apiKey,
        hmacSecret = options.hmacSecret,
        timeoutSeconds = options.timeoutSeconds,
        body = json.encode(options.payload or {}),
    })
end

function httpTransport.deleteJson(options)
    return httpTransport.requestJson({
        method = HTTP_METHOD_DELETE,
        url = options.url,
        apiKey = options.apiKey,
        hmacSecret = options.hmacSecret,
        timeoutSeconds = options.timeoutSeconds,
        body = json.encode(options.payload or {}),
    })
end

return httpTransport
