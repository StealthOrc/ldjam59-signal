local refreshIndicatorLogic = {}

function refreshIndicatorLogic.getDisplayNextRefreshAt(fetchedAt, scheduledNextRefreshAt, cacheDurationSeconds)
    if type(fetchedAt) == "number" then
        return fetchedAt + (cacheDurationSeconds or 0)
    end

    return scheduledNextRefreshAt
end

return refreshIndicatorLogic
