package.path = "./?.lua;./?/init.lua;" .. package.path

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %s but got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local capturedRequest = nil

package.loaded["src.game.network.http_transport"] = {
    getJson = function(request)
        capturedRequest = request
        return {
            entries = {},
        }, nil, 200
    end,
}

package.loaded["src.game.network.leaderboard_client"] = nil
local leaderboardClient = require("src.game.network.leaderboard_client")

local payload, payloadError = leaderboardClient.fetchLeaderboard({
    includeReplay = true,
    mapHash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    mapUuid = "map-1",
    player_uuid = "player-1",
    size = 5,
}, {
    isConfigured = true,
    apiKey = "api-key",
    apiBaseUrl = "https://example.com",
})

if not payload then
    error(payloadError or "fetchLeaderboard should succeed in the stubbed test", 2)
end

assertEqual(
    capturedRequest.url,
    "https://example.com/api/maps/map-1/leaderboard?size=5&player_uuid=player-1&map_hash=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef&include_replay=true",
    "fetchLeaderboard builds the merged map leaderboard request"
)

print("leaderboard client fetch leaderboard tests passed")
