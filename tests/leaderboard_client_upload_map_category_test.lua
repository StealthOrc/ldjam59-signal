package.path = "./?.lua;./?/init.lua;" .. package.path

local json = require("src.game.json")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s expected %s but got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local writes = {}
local commands = {}
local originalLove = love
local originalIoPopen = io.popen

love = {
    filesystem = {
        getInfo = function()
            return false
        end,
        read = function(path)
            return writes[path]
        end,
        write = function(path, content)
            writes[path] = content
            return true
        end,
        getSaveDirectory = function()
            return "C:\\temp\\signal-tests"
        end,
    },
}

io.popen = function(command)
    commands[#commands + 1] = command
    return {
        read = function()
            return '{"ok":true,"status":200,"data":{"saved":true}}'
        end,
        close = function()
            return true
        end,
    }
end

package.loaded["src.game.leaderboard_client"] = nil
local leaderboardClient = require("src.game.leaderboard_client")

local response, responseError = leaderboardClient.uploadMap({
    mapUuid = "map-1",
    creator_uuid = "creator-1",
    mapName = "Test Map",
    map = {
        nodes = {},
    },
}, {
    isConfigured = true,
    apiKey = "api-key",
    apiBaseUrl = "https://example.com",
    hmacSecret = "hmac-secret",
})

io.popen = originalIoPopen
love = originalLove

if not response then
    error(responseError or "uploadMap should succeed in the stubbed test", 2)
end

assertEqual(#commands, 1, "uploadMap runs exactly one PowerShell command")

local encodedRequest = writes["leaderboard_request.json"]
if type(encodedRequest) ~= "string" or encodedRequest == "" then
    error("uploadMap should write the request payload", 2)
end

local payload, decodeError = json.decode(encodedRequest)
if type(payload) ~= "table" then
    error(decodeError or "uploadMap request payload should decode", 2)
end

assertEqual(payload.map_category, "online", "uploadMap sends the default map category")

print("leaderboard client upload map category tests passed")
