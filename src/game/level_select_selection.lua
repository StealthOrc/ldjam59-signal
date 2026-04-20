local levelSelectSelection = {}

local function toText(value)
    return tostring(value or "")
end

function levelSelectSelection.findIndex(maps, selectedId, selectedMapUuid)
    local resolvedMaps = type(maps) == "table" and maps or {}
    local resolvedSelectedId = selectedId
    local resolvedSelectedMapUuid = toText(selectedMapUuid)

    for index, descriptor in ipairs(resolvedMaps) do
        if descriptor.id == resolvedSelectedId then
            return index
        end
    end

    if resolvedSelectedMapUuid ~= "" then
        local matchedIndex = nil
        for index, descriptor in ipairs(resolvedMaps) do
            if toText(descriptor.mapUuid) == resolvedSelectedMapUuid then
                if matchedIndex ~= nil then
                    return nil
                end
                matchedIndex = index
            end
        end

        if matchedIndex ~= nil then
            return matchedIndex
        end
    end

    if #resolvedMaps > 0 then
        return 1
    end

    return nil
end

return levelSelectSelection

