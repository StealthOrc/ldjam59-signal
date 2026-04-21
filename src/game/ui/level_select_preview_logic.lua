local previewLogic = {}

function previewLogic.buildOpenStateOptions(isCacheFresh)
    if isCacheFresh then
        return {
            status = "ready",
            forceImmediateFetch = false,
            hasResolvedInitialRemoteAttempt = true,
        }
    end

    return {
        status = "loading",
        forceImmediateFetch = true,
        hasResolvedInitialRemoteAttempt = false,
    }
end

function previewLogic.shouldStartFetch(previewState, mapUuid, isRequestActive, isCacheFresh, isFetchAllowed)
    if not mapUuid or mapUuid == "" or isRequestActive then
        return false
    end

    local resolvedState = previewState or {}
    if resolvedState.mapUuid == mapUuid and resolvedState.forceImmediateFetch then
        return true
    end

    return (not isCacheFresh) and isFetchAllowed
end

function previewLogic.shouldShowCachedEntries(previewState, mapUuid, hasCache)
    if not hasCache then
        return false
    end

    local resolvedState = previewState or {}
    if resolvedState.mapUuid ~= mapUuid then
        return true
    end

    if resolvedState.clearVisibleEntries then
        return false
    end

    if resolvedState.status == "loading" and not resolvedState.showCachedWhileLoading then
        return false
    end

    return true
end

function previewLogic.getPayloadToPersistAfterFetch(payload, existingCacheEntry)
    local resolvedPayload = type(payload) == "table" and payload or {}
    local hasPayloadData = #(resolvedPayload.top_entries or {}) > 0 or type(resolvedPayload.player_entry) == "table"
    if hasPayloadData or type(existingCacheEntry) ~= "table" then
        return resolvedPayload
    end

    return {
        map_hash = resolvedPayload.map_hash,
        top_entries = type(existingCacheEntry.top_entries) == "table" and existingCacheEntry.top_entries or {},
        player_entry = type(existingCacheEntry.player_entry) == "table" and existingCacheEntry.player_entry or nil,
        target_rank = tonumber(existingCacheEntry.target_rank) or nil,
    }
end

return previewLogic
