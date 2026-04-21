local refreshIndicatorLogic = {}

function refreshIndicatorLogic.getDisplayNextRefreshAt(fetchedAt, scheduledNextRefreshAt, cacheDurationSeconds)
    if type(fetchedAt) == "number" then
        return fetchedAt + (cacheDurationSeconds or 0)
    end

    return scheduledNextRefreshAt
end

function refreshIndicatorLogic.getDisplayNextRefreshAtForVisibleData(hasVisibleData, fetchedAt, scheduledNextRefreshAt, cacheDurationSeconds)
    if not hasVisibleData then
        local emptyStateRefreshAt = refreshIndicatorLogic.getDisplayNextRefreshAt(
            fetchedAt,
            scheduledNextRefreshAt,
            cacheDurationSeconds
        )
        if type(scheduledNextRefreshAt) == "number"
            and (type(emptyStateRefreshAt) ~= "number" or scheduledNextRefreshAt > emptyStateRefreshAt)
        then
            return scheduledNextRefreshAt
        end

        return emptyStateRefreshAt
    end

    return refreshIndicatorLogic.getDisplayNextRefreshAt(fetchedAt, scheduledNextRefreshAt, cacheDurationSeconds)
end

return refreshIndicatorLogic
