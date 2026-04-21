local marketplaceFavoriteLogic = {}

function marketplaceFavoriteLogic.getTargetLikedByPlayer(previousState)
    if type(previousState) ~= "table" then
        return true
    end

    return previousState.likedByPlayer ~= true
end

function marketplaceFavoriteLogic.getRequestMethod(targetLikedByPlayer)
    return targetLikedByPlayer == true and "POST" or "DELETE"
end

function marketplaceFavoriteLogic.buildRequestPayload(playerUuid)
    return {
        player_uuid = tostring(playerUuid or ""),
    }
end

function marketplaceFavoriteLogic.resolveLikedByPlayer(payload, targetLikedByPlayer)
    if type(payload) == "table" and payload.liked_by_player ~= nil then
        return payload.liked_by_player == true
    end

    return targetLikedByPlayer == true
end

function marketplaceFavoriteLogic.wasMutationAccepted(payload, targetLikedByPlayer)
    if type(payload) ~= "table" then
        return false
    end

    if targetLikedByPlayer == true and payload.accepted ~= nil then
        return payload.accepted == true
    end

    if targetLikedByPlayer ~= true and payload.removed ~= nil then
        return payload.removed == true
    end

    return marketplaceFavoriteLogic.resolveLikedByPlayer(payload, targetLikedByPlayer) == (targetLikedByPlayer == true)
end

function marketplaceFavoriteLogic.wasAlreadyFavorited(payload, targetLikedByPlayer)
    if type(payload) ~= "table" then
        return false
    end

    if targetLikedByPlayer ~= true then
        return false
    end

    if payload.already_favorited ~= nil then
        return payload.already_favorited == true
    end

    return payload.accepted == false and payload.liked_by_player == true
end

function marketplaceFavoriteLogic.wasAlreadyRemoved(payload, targetLikedByPlayer)
    if type(payload) ~= "table" then
        return false
    end

    if targetLikedByPlayer == true then
        return false
    end

    if payload.removed ~= nil then
        return payload.removed == false and payload.liked_by_player == false
    end

    return payload.accepted == false and payload.liked_by_player == false
end

return marketplaceFavoriteLogic




