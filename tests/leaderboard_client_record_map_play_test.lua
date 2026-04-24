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
            ok = true,
        }, nil, 200
    end,
}

package.loaded["src.game.network.leaderboard_client"] = nil
local leaderboardClient = require("src.game.network.leaderboard_client")

local response, responseError = leaderboardClient.recordMapPlay({
    mapUuid = "map-1",
    mapHash = "hash-1",
    playerDisplayName = "Player One",
    player_uuid = "player-1",
}, {
    isConfigured = true,
    apiKey = "api-key",
    apiBaseUrl = "https://example.com",
    hmacSecret = "hmac-secret",
})

if not response then
    error(responseError or "recordMapPlay should succeed in the stubbed test", 2)
end

if type(capturedRequest) ~= "table" then
    error("recordMapPlay should call the transport layer", 2)
end

assertEqual(capturedRequest.url, "https://example.com/api/maps/map-1/plays", "recordMapPlay uses the play endpoint")
assertEqual(capturedRequest.payload.display_name, "Player One", "recordMapPlay sends the display name")
assertEqual(capturedRequest.payload.map_hash, "hash-1", "recordMapPlay sends the map hash")
assertEqual(capturedRequest.payload.player_uuid, "player-1", "recordMapPlay sends the player uuid")

print("leaderboard client record map play tests passed")
