package.path = "./?.lua;./?/init.lua;" .. package.path

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %s but got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local capturedRequest = nil

package.loaded["src.game.network.http_transport"] = {
    postJson = function(request)
        capturedRequest = request
        return {
            accepted = true,
        }, nil, 200
    end,
}

package.loaded["src.game.network.leaderboard_client"] = nil
local leaderboardClient = require("src.game.network.leaderboard_client")

local response, responseError = leaderboardClient.submitReplay({
    mapUuid = "map-1",
    mapHash = "hash-1",
    player_uuid = "player-1",
    playerDisplayName = "Player One",
    score = 77,
    replay = {
        version = 1,
        mapUuid = "map-1",
    },
}, {
    isConfigured = true,
    apiKey = "api-key",
    apiBaseUrl = "https://example.com",
    hmacSecret = "hmac-secret",
})

if not response then
    error(responseError or "submitReplay should succeed in the stubbed test", 2)
end

if type(capturedRequest) ~= "table" then
    error("submitReplay should call the transport layer", 2)
end

assertEqual(capturedRequest.url, "https://example.com/api/maps/map-1/replays", "submitReplay uses the replay endpoint")
assertEqual(capturedRequest.payload.map_hash, "hash-1", "submitReplay sends the map hash")
assertEqual(capturedRequest.payload.score, 77, "submitReplay sends the score")
assertEqual(capturedRequest.payload.replay.version, 1, "submitReplay sends the replay payload")

print("leaderboard client submit replay tests passed")
