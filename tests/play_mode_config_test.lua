package.path = "./?.lua;./?/init.lua;" .. package.path

local installRemoteServices = require("src.game.app.game_remote_services")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %q but got %q", label, expected, actual), 2)
    end
end

local function assertFalse(value, label)
    if value then
        error(label, 2)
    end
end

local Game = {}

installRemoteServices(Game, {
    PLAY_MODE_ONLINE = "online",
    PLAY_MODE_OFFLINE = "offline",
    LEVEL_SELECT_MODE_LIBRARY = "library",
    getProfilePlayMode = function(profile)
        return type(profile) == "table" and tostring(profile.playMode or "") or ""
    end,
})

local saveCallCount = 0
local game = setmetatable({
    profile = {
        playMode = "offline",
    },
    profileModeSelection = "offline",
    levelSelectMode = "library",
    saveProfile = function(self)
        saveCallCount = saveCallCount + 1
        return true
    end,
    reloadOnlineConfig = function(self)
        return self.onlineConfig
    end,
    clearOnlineRequestState = function()
    end,
    clearLevelSelectLeaderboardFlip = function()
    end,
}, { __index = Game })

game.onlineConfig = {
    isConfigured = false,
    errors = {
        "API_KEY is missing. Set it in the process environment or in .env.",
    },
}

local blockedOk, blockedError = game:setPlayMode("online")
assertFalse(blockedOk, "setPlayMode should reject online mode without configuration")
assertEqual(
    blockedError,
    "API_KEY is missing. Set it in the process environment or in .env.",
    "setPlayMode returns the configuration error"
)
assertEqual(game.profile.playMode, "offline", "setPlayMode keeps the previous play mode when online setup is missing")
assertEqual(game.profileModeSelection, "offline", "setPlayMode keeps the selection offline when online setup is missing")
assertEqual(saveCallCount, 0, "setPlayMode should not save the profile when online setup is missing")

game.onlineConfig = {
    isConfigured = true,
    errors = {},
}

local enabledOk, enabledError = game:setPlayMode("online")
assertEqual(enabledOk, true, "setPlayMode should allow online mode when configuration is present")
assertEqual(enabledError, nil, "setPlayMode should not return an error when configuration is present")
assertEqual(game.profile.playMode, "online", "setPlayMode updates the play mode after a valid online switch")
assertEqual(game.profileModeSelection, "online", "setPlayMode updates the selected play mode after a valid online switch")
assertEqual(saveCallCount, 1, "setPlayMode saves the profile exactly once after a valid online switch")

print("play mode config tests passed")
