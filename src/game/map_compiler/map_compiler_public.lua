return function(mapCompiler, shared)
    local moduleEnvironment = setmetatable({ mapCompiler = mapCompiler }, {
        __index = function(_, key)
            local sharedValue = shared[key]
            if sharedValue ~= nil then
                return sharedValue
            end

            return _G[key]
        end,
        __newindex = shared,
    })

    setfenv(1, moduleEnvironment)

function mapCompiler.validateEditorMap(mapName, editorData)
    local level, errors, errorText, diagnostics = buildCompiledLevel(mapName, editorData)
    if #errors > 0 then
        return nil, errors, errorText, diagnostics
    end

    return level, {}, nil, diagnostics
end

function mapCompiler.buildPlayableLevel(mapName, editorData, mapUuid)
    local level, errors, errorText, diagnostics = mapCompiler.validateEditorMap(mapName, editorData)
    if level then
        level.id = mapUuid or level.id
        level.mapUuid = mapUuid or level.mapUuid
    end
    return level, errorText, errors, diagnostics
end

function mapCompiler.buildEditorPreviewBundle(mapName, editorData, mapUuid)
    local compiledLevel, errors, errorText, diagnostics = buildCompiledLevel(mapName, editorData)
    compiledLevel = compiledLevel or {
        title = mapName,
        description = "Custom map loaded from the editor.",
        junctions = {},
        edges = {},
        trains = {},
    }
    local playableLevel = nil
    local previewLevel = deepCopy(compiledLevel)

    if #errors == 0 then
        playableLevel = deepCopy(compiledLevel)
        playableLevel.id = mapUuid or playableLevel.id
        playableLevel.mapUuid = mapUuid or playableLevel.mapUuid
    end

    previewLevel.id = mapUuid or previewLevel.id
    previewLevel.mapUuid = mapUuid or previewLevel.mapUuid
    previewLevel.trains = {}

    return playableLevel, previewLevel, errorText, errors, diagnostics
end

function mapCompiler.buildEditorPreviewLevel(mapName, editorData, mapUuid)
    local _, previewLevel, errorText, errors, diagnostics = mapCompiler.buildEditorPreviewBundle(mapName, editorData, mapUuid)
    return previewLevel, errorText, errors, diagnostics
end

end
