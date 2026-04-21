local json = require("src.game.util.json")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local updateCallCount = 0

package.loaded["src.game.network.http_transport"] = {
    getJsonAsync = function(options, callback)
        callback({
            entries = {
                {
                    display_name = "Browser Tester",
                    player_uuid = "player-1",
                    score = 42,
                    rank = 1,
                },
            },
        }, nil, 200)
        return "fetch-handle"
    end,
    postJsonAsync = function(options, callback)
        callback({
            ok = true,
            map_uuid = options.payload and options.payload.map_uuid,
        }, nil, 201)
        return "post-handle"
    end,
    deleteJsonAsync = function(options, callback)
        callback({
            ok = true,
        }, nil, 200)
        return "delete-handle"
    end,
    updateAsyncRequests = function()
        updateCallCount = updateCallCount + 1
    end,
}
package.loaded["src.game.network.web_request_worker"] = nil

local webRequestWorker = require("src.game.network.web_request_worker")
local worker = webRequestWorker.new()
local requestChannel = worker:getRequestChannel()
local responseChannel = worker:getResponseChannel()

requestChannel:push(json.encode({
    kind = "fetch",
    requestId = 7,
    config = {
        apiKey = "jam-key",
        apiBaseUrl = "https://example.com",
    },
}))

local fetchResponse = json.decode(responseChannel:pop())
assertEqual(fetchResponse.kind, "fetch", "fetch response preserves the request kind")
assertEqual(fetchResponse.requestId, 7, "fetch response preserves the request id")
assertEqual(fetchResponse.ok, true, "fetch response reports success")
assertEqual(fetchResponse.payload.entries[1].display_name, "Browser Tester", "fetch payload round-trips through the response queue")

requestChannel:push(json.encode({
    kind = "upload_map",
    requestId = 8,
    config = {
        apiKey = "jam-key",
        apiBaseUrl = "https://example.com",
        mapUuid = "map-123",
        map = {
            tracks = {},
        },
    },
}))

local uploadResponse = json.decode(responseChannel:pop())
assertEqual(uploadResponse.kind, "upload_map", "upload response preserves the request kind")
assertEqual(uploadResponse.requestId, 8, "upload response preserves the request id")
assertEqual(uploadResponse.status, 201, "upload response preserves HTTP status codes")
assertEqual(uploadResponse.payload.map_uuid, "map-123", "upload payload flows through the async worker")

worker:update()
assertEqual(updateCallCount, 1, "worker updates pending async fetch requests")
