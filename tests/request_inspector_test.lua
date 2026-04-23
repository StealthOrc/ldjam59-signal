package.path = "./?.lua;./?/init.lua;" .. package.path

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %s but got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local function assertTrue(value, label)
    if not value then
        error(label, 2)
    end
end

local requestInspector = require("src.game.network.request_inspector")

local startedEntry = requestInspector.beginRequest({
    requestKind = "upload_map",
    flowRequestId = 17,
    method = "POST",
    url = "https://example.com/api/maps?api_key=secret-value&map_uuid=map-1",
    headers = {
        ["x-api-key"] = "super-secret",
        ["content-type"] = "application/json",
        ["x-signature"] = "signature-value",
    },
    requestBody = {
        map_uuid = "map-1",
        api_key = "body-secret",
        key_list = {
            "key-a",
            "key-b",
        },
        replay = {
            token = "token-secret",
            version = 1,
        },
    },
    timeoutSeconds = 5,
})

assertEqual(startedEntry.method, "POST", "beginRequest keeps the HTTP method")
assertEqual(startedEntry.route, "/api/maps", "beginRequest derives the route from the URL")
assertEqual(startedEntry.headers["x-api-key"], "[redacted]", "beginRequest redacts the x-api-key header")
assertEqual(startedEntry.headers["x-signature"], "[redacted]", "beginRequest redacts the signature header")
assertEqual(startedEntry.requestBody.api_key, "[redacted]", "beginRequest redacts api_key request payload fields")
assertEqual(startedEntry.requestBody.key_list, "[redacted]", "beginRequest redacts key list payload fields")
assertEqual(startedEntry.requestBody.replay.token, "[redacted]", "beginRequest redacts nested token fields")
assertTrue(startedEntry.url:find("api_key=%[redacted%]", 1) ~= nil, "beginRequest redacts sensitive query parameter values")

local finishedEntry = requestInspector.finishRequest(startedEntry, {
    ok = true,
    status = 201,
    responseBody = {
        accepted = true,
        authorization = "server-secret",
        map_uuid = "map-1",
    },
})

assertEqual(finishedEntry.phase, "finished", "finishRequest marks the event as finished")
assertEqual(finishedEntry.status, 201, "finishRequest keeps the HTTP status code")
assertEqual(finishedEntry.responseBody.authorization, "[redacted]", "finishRequest redacts sensitive response fields")
assertTrue(type(finishedEntry.durationMilliseconds) == "number", "finishRequest records a numeric duration")

print("request inspector tests passed")
