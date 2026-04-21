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
            saved = true,
        }, nil, 200
    end,
}

package.loaded["src.game.network.leaderboard_client"] = nil
local leaderboardClient = require("src.game.network.leaderboard_client")

local response, responseError = leaderboardClient.uploadMap({
    mapUuid = "map-1",
    creator_uuid = "creator-1",
    mapHash = "hash-1",
    mapName = "Test Map",
    playerDisplayName = "Player One",
    map = {
        nodes = {},
    },
}, {
    isConfigured = true,
    apiKey = "api-key",
    apiBaseUrl = "https://example.com",
    hmacSecret = "hmac-secret",
})

if not response then
    error(responseError or "uploadMap should succeed in the stubbed test", 2)
end

if type(capturedRequest) ~= "table" then
    error("uploadMap should call the transport layer", 2)
end

assertEqual(capturedRequest.url, "https://example.com/api/maps", "uploadMap uses the correct endpoint")
assertEqual(capturedRequest.payload.map_category, "online", "uploadMap keeps the default map category contract")
assertEqual(capturedRequest.payload.display_name, "Player One", "uploadMap includes the player display name in the payload")
assertEqual(capturedRequest.payload.map_hash, "hash-1", "uploadMap includes the computed map hash in the payload")

print("leaderboard client upload map category tests passed")
