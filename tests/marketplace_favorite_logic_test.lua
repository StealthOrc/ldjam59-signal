package.path = "./?.lua;./?/init.lua;" .. package.path

local marketplaceFavoriteLogic = require("src.game.network.marketplace_favorite_logic")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %s but got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

assertEqual(
    marketplaceFavoriteLogic.getTargetLikedByPlayer(nil),
    true,
    "favorite logic defaults to like when there is no previous state"
)

assertEqual(
    marketplaceFavoriteLogic.getTargetLikedByPlayer({ likedByPlayer = false }),
    true,
    "favorite logic turns an unliked state into a like request"
)

assertEqual(
    marketplaceFavoriteLogic.getTargetLikedByPlayer({ likedByPlayer = true }),
    false,
    "favorite logic turns a liked state into a remove request"
)

assertEqual(
    marketplaceFavoriteLogic.getRequestMethod(true),
    "POST",
    "favorite logic uses POST for like requests"
)

assertEqual(
    marketplaceFavoriteLogic.getRequestMethod(false),
    "DELETE",
    "favorite logic uses DELETE for remove requests"
)

local requestPayload = marketplaceFavoriteLogic.buildRequestPayload("player-1")
assertEqual(requestPayload.player_uuid, "player-1", "favorite logic builds the documented request payload")
assertEqual(requestPayload.liked, nil, "favorite logic does not send the legacy liked flag")

assertEqual(
    marketplaceFavoriteLogic.resolveLikedByPlayer({ liked_by_player = false }, true),
    false,
    "favorite logic uses the explicit liked_by_player value from the response"
)

assertEqual(
    marketplaceFavoriteLogic.resolveLikedByPlayer({}, true),
    true,
    "favorite logic falls back to the requested target state when liked_by_player is omitted"
)

assertEqual(
    marketplaceFavoriteLogic.wasMutationAccepted({ accepted = true, liked_by_player = true }, true),
    true,
    "favorite logic treats accepted responses as successful"
)

assertEqual(
    marketplaceFavoriteLogic.wasMutationAccepted({ accepted = false, liked_by_player = true }, true),
    false,
    "favorite logic preserves explicit non-accepted duplicate-like responses"
)

assertEqual(
    marketplaceFavoriteLogic.wasMutationAccepted({ liked_by_player = true }, true),
    true,
    "favorite logic accepts matching liked states when the API omits accepted"
)

assertEqual(
    marketplaceFavoriteLogic.wasMutationAccepted({ removed = true, liked_by_player = false }, false),
    true,
    "favorite logic accepts remove responses when the backend confirms removal"
)

assertEqual(
    marketplaceFavoriteLogic.wasMutationAccepted({ accepted = false, already_removed = true, liked_by_player = false }, false),
    false,
    "favorite logic preserves explicit non-accepted duplicate-remove responses"
)

assertEqual(
    marketplaceFavoriteLogic.wasAlreadyFavorited({ accepted = false, already_favorited = true, liked_by_player = true }, true),
    true,
    "favorite logic recognizes duplicate like responses"
)

assertEqual(
    marketplaceFavoriteLogic.wasAlreadyRemoved({ removed = false, liked_by_player = false }, false),
    true,
    "favorite logic recognizes no-op remove responses"
)

assertEqual(
    marketplaceFavoriteLogic.wasAlreadyRemoved({ accepted = false, already_removed = true, liked_by_player = false }, false),
    true,
    "favorite logic recognizes already-removed responses from the current backend"
)

print("marketplace favorite logic tests passed")




