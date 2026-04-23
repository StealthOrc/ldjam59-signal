package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}

local inMemoryFiles = {}

love.filesystem = {
    write = function(path, body)
        inMemoryFiles[path] = body
        return true
    end,
    read = function(path)
        local body = inMemoryFiles[path]
        if not body then
            return nil, "missing"
        end
        return body
    end,
    getInfo = function(path, kind)
        if kind == "file" and inMemoryFiles[path] then
            return { type = "file" }
        end
        return nil
    end,
    load = function(path)
        local body = inMemoryFiles[path]
        if not body then
            return nil, "missing"
        end
        return load(body, "@" .. path)
    end,
}

package.loaded["src.game.storage.profile_storage"] = nil
local profileStorage = require("src.game.storage.profile_storage")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %s but got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local savedProfile = profileStorage.save({
    player_uuid = "11111111-2222-3333-4444-555555555555",
    playerDisplayName = "Signal Tester",
    playMode = "offline",
    tutorials = {
        dismissedMapGuides = {
            ["map-alpha"] = true,
            ["map-beta"] = false,
            [7] = true,
        },
    },
})

assert(savedProfile ~= nil, "profile save should succeed")
assertEqual(
    savedProfile.tutorials.dismissedMapGuides["map-alpha"],
    true,
    "profile save keeps valid dismissed guide ids"
)
assertEqual(
    savedProfile.tutorials.dismissedMapGuides["map-beta"],
    nil,
    "profile save strips false dismissed guide entries"
)

local loadedProfile = profileStorage.load()
assertEqual(
    loadedProfile.tutorials.dismissedMapGuides["map-alpha"],
    true,
    "profile load keeps dismissed guide ids"
)
assertEqual(
    loadedProfile.tutorials.dismissedMapGuides["map-beta"],
    nil,
    "profile load keeps invalid dismissed guide ids removed"
)

inMemoryFiles["profile.toml"] = [[
version = 1
player_uuid = "11111111-2222-3333-4444-555555555555"
playerDisplayName = "Signal Tester"
playMode = "offline"
debugMode = false

[editor]
gridVisible = true
gridSnapEnabled = true
gridStep = 64

[tutorials.dismissedMapGuides]
map-keep = true
map-drop = "yes"
]]

local sanitizedProfile = profileStorage.load()
assertEqual(
    sanitizedProfile.tutorials.dismissedMapGuides["map-keep"],
    true,
    "profile load preserves valid tutorial dismissal flags from disk"
)
assertEqual(
    sanitizedProfile.tutorials.dismissedMapGuides["map-drop"],
    nil,
    "profile load removes invalid tutorial dismissal flags from disk"
)
assertEqual(
    sanitizedProfile.editor.gridSnapEnabled,
    true,
    "profile load preserves the snap-to-grid toggle"
)

print("profile storage tests passed")
