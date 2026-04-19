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

return previewLogic
