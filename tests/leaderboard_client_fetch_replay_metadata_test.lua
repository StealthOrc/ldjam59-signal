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
            player_entry = nil,
            target_rank = nil,
        }, nil, 200
    end,
}

package.loaded["src.game.network.leaderboard_client"] = nil
local leaderboardClient = require("src.game.network.leaderboard_client")

local response, responseError = leaderboardClient.fetchReplayMetadata({
    mapUuid = "map-1",
    mapHash = "hash 1",
    limit = 5,
    player_uuid = "player-1",
}, {
    isConfigured = true,
    apiKey = "api-key",
    apiBaseUrl = "https://example.com",
    timeoutSeconds = 5,
})

if not response then
    error(responseError or "fetchReplayMetadata should succeed in the stubbed test", 2)
end

if type(capturedRequest) ~= "table" then
    error("fetchReplayMetadata should call the transport layer", 2)
end

assertEqual(
    capturedRequest.url,
    "https://example.com/api/maps/map-1/replays?map_hash=hash%201&limit=5&player_uuid=player-1",
    "fetchReplayMetadata forwards map hash, limit, and player UUID in the query string"
)

assertEqual(capturedRequest.timeoutSeconds, 5, "fetchReplayMetadata forwards the timeout to the transport")

print("leaderboard client fetch replay metadata tests passed")
