package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}
love.timer = love.timer or {
    getTime = function()
        return 0
    end,
}
love.filesystem = love.filesystem or {}

local mapEditor = require("src.game.editor.map_editor")

local DEFAULT_MAP_WIDTH = 1920
local DEFAULT_MAP_HEIGHT = 1080
local CHANGED_TIME_LIMIT = 30

local function assertTrue(value, label)
    if not value then
        error(label, 2)
    end
end

local function assertFalse(value, label)
    if value then
        error(label, 2)
    end
end

local savedMapData = {
    name = "Saved Map",
    mapUuid = "saved-map-uuid",
    editor = {
        mapSize = {
            w = DEFAULT_MAP_WIDTH,
            h = DEFAULT_MAP_HEIGHT,
        },
        timeLimit = nil,
        endpoints = {},
        routes = {},
        junctions = {},
        trains = {},
    },
    level = {
        title = "Saved Map",
        edges = {
            {
                id = "edge_1",
                colors = { "blue" },
            },
        },
        trains = {
            {
                id = "train_1",
                edgeId = "edge_1",
                goalColor = "blue",
            },
        },
    },
}

local savedDescriptor = {
    source = "user",
    isRemoteImport = false,
    hasLevel = true,
    mapUuid = savedMapData.mapUuid,
}

local editor = mapEditor.new(DEFAULT_MAP_WIDTH, DEFAULT_MAP_HEIGHT, nil)
editor:resetFromMap(savedMapData, savedDescriptor)
editor:setSavedMapUploadState(true, false)

assertFalse(editor:hasUnsavedChanges(), "freshly loaded saved maps should start clean")
assertTrue(editor:canPlaySavedMap(), "clean saved maps should be playable")
assertTrue(editor:canUploadSavedMap(), "clean saved maps should be uploadable when upload is available")

editor:resetFromMap(savedMapData, savedDescriptor)

assertFalse(editor:hasUnsavedChanges(), "reloading the same saved map should stay clean after editor state reconstruction")

editor.timeLimit = CHANGED_TIME_LIMIT

assertTrue(editor:hasUnsavedChanges(), "editor changes should mark the saved map state dirty")
assertFalse(editor:canPlaySavedMap(), "dirty saved maps should not be playable until saved again")
assertFalse(editor:canUploadSavedMap(), "dirty saved maps should not be uploadable until saved again")
assertFalse(editor:requestUploadFromSavedMap(), "upload requests should be rejected for dirty saved maps")

editor:resetFromMap(savedMapData, savedDescriptor)
editor:setSavedMapUploadState(false, false)

assertFalse(editor:requestUploadFromSavedMap(), "upload requests should be rejected when upload is unavailable")
assertTrue(editor.statusText == "Uploading is currently not possible.", "upload unavailability should use the generic status message")

editor:resetFromMap(savedMapData, {
    source = "builtin",
    isRemoteImport = false,
    hasLevel = true,
    mapUuid = savedMapData.mapUuid,
})
editor:setSavedMapUploadState(true, false)

assertFalse(editor:canPlaySavedMap(), "builtin maps should not count as playable saved maps in the editor")
assertFalse(editor:canUploadSavedMap(), "builtin maps should not count as uploadable saved maps in the editor")

print("map editor saved map action tests passed")
