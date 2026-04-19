local roadTypes = {}

roadTypes.DEFAULT_ID = "normal"
roadTypes.ORDER = {
    "normal",
    "fast",
    "slow",
}

local ROAD_TYPE_LOOKUP = {
    normal = {
        id = "normal",
        label = "Normal",
        shortLabel = "N",
        speedScale = 1.0,
        pattern = "plain",
        markerSpacing = 0,
        markerSize = 0,
        markerWidth = 0,
    },
    fast = {
        id = "fast",
        label = "Fast",
        shortLabel = "F",
        speedScale = 1.35,
        pattern = "chevron",
        markerSpacing = 42,
        markerSize = 10,
        markerWidth = 3.5,
    },
    slow = {
        id = "slow",
        label = "Slow",
        shortLabel = "S",
        speedScale = 0.72,
        pattern = "crossbar",
        markerSpacing = 24,
        markerSize = 10,
        markerWidth = 3.5,
    },
}

function roadTypes.normalizeRoadType(roadType)
    if ROAD_TYPE_LOOKUP[roadType] then
        return roadType
    end

    return roadTypes.DEFAULT_ID
end

function roadTypes.getConfig(roadType)
    return ROAD_TYPE_LOOKUP[roadTypes.normalizeRoadType(roadType)]
end

function roadTypes.getOrderedOptions()
    local options = {}

    for _, roadTypeId in ipairs(roadTypes.ORDER) do
        options[#options + 1] = ROAD_TYPE_LOOKUP[roadTypeId]
    end

    return options
end

return roadTypes
