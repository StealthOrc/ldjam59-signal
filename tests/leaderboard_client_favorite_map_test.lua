package.path = "./?.lua;./?/init.lua;" .. package.path

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %s but got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local capturedPostRequest
local capturedDeleteRequest
local postRequestCount = 0
local deleteRequestCount = 0

package.loaded["src.game.http_transport"] = {
    postJson = function(request)
        capturedPostRequest = request
        postRequestCount = postRequestCount + 1
        return {
            accepted = true,
            liked_by_player = true,
        }, nil, 200
    end,
    deleteJson = function(request)
        capturedDeleteRequest = request
        deleteRequestCount = deleteRequestCount + 1
        return {
            removed = true,
            favorite_count = 11,
            liked_by_player = false,
        }, nil, 200
    end,
}

package.loaded["src.game.marketplace_favorite_logic"] = nil
package.loaded["src.game.leaderboard_client"] = nil
local leaderboardClient = require("src.game.leaderboard_client")

local config = {
    isConfigured = true,
    apiKey = "api-key",
    apiBaseUrl = "https://example.com",
    hmacSecret = "hmac-secret",
}

local likeResponse, likeError = leaderboardClient.favoriteMap({
    mapUuid = "map-1",
    player_uuid = "player-1",
    liked = true,
}, config)

if not likeResponse then
    error(likeError or "favoriteMap like request should succeed in the stubbed test", 2)
end

if type(capturedPostRequest) ~= "table" then
    error("favoriteMap should call postJson when liking a map", 2)
end

assertEqual(capturedPostRequest.url, "https://example.com/api/maps/map-1/favorites", "favoriteMap like request uses the favorites endpoint")
assertEqual(capturedPostRequest.payload.player_uuid, "player-1", "favoriteMap like request sends the player UUID")
assertEqual(capturedPostRequest.payload.liked, nil, "favoriteMap like request omits the legacy liked flag")

local unlikeResponse, unlikeError = leaderboardClient.favoriteMap({
    mapUuid = "map-1",
    player_uuid = "player-1",
    liked = false,
}, config)

if not unlikeResponse then
    error(unlikeError or "favoriteMap unlike request should succeed in the stubbed test", 2)
end

assertEqual(postRequestCount, 1, "favoriteMap sends exactly one POST request for the like action")
assertEqual(deleteRequestCount, 1, "favoriteMap sends one DELETE request for the remove action")
assertEqual(capturedDeleteRequest.url, "https://example.com/api/maps/map-1/favorites", "favoriteMap remove request uses the favorites endpoint")
assertEqual(capturedDeleteRequest.payload.player_uuid, "player-1", "favoriteMap remove request sends the player UUID")
assertEqual(capturedDeleteRequest.payload.liked, nil, "favoriteMap remove request omits the legacy liked flag")

print("leaderboard client favorite map tests passed")




