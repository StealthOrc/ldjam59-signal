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

local response, responseError = leaderboardClient.submitScore({
    mapUuid = "map-1",
    mapHash = "hash-1",
    player_uuid = "player-1",
    playerDisplayName = "Player One",
    score = 77,
}, {
    isConfigured = true,
    apiKey = "api-key",
    apiBaseUrl = "https://example.com",
    hmacSecret = "hmac-secret",
})

if not response then
    error(responseError or "submitScore should succeed in the stubbed test", 2)
end

if type(capturedRequest) ~= "table" then
    error("submitScore should call the transport layer", 2)
end

assertEqual(capturedRequest.url, "https://example.com/api/maps/map-1/score", "submitScore uses the score endpoint")
assertEqual(capturedRequest.payload.map_hash, "hash-1", "submitScore sends the map hash")
assertEqual(capturedRequest.payload.score, 77, "submitScore sends the score")

print("leaderboard client submit score tests passed")
