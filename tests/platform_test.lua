local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local originalLove = love

love = {
    system = {
        getOS = function()
            return "Web"
        end,
    },
}

local platform = require("src.game.platform")
local webPlatform = platform.detect()

assertEqual(webPlatform.isWeb, true, "web detection recognizes the browser runtime")
assertEqual(webPlatform.supportsOnlineServices, false, "web builds disable desktop online services")
assertEqual(webPlatform.supportsThreadWorkers, false, "web builds disable worker threads")
assertEqual(webPlatform.onlineUnavailableReason, "Online features are disabled in the HTML5 build.", "web builds expose a clear reason")

love = {
    system = {
        getOS = function()
            return "Windows"
        end,
    },
    thread = {
        getChannel = function()
            return {}
        end,
        newThread = function()
            return {}
        end,
    },
}

local desktopPlatform = platform.detect()
assertEqual(desktopPlatform.isWeb, false, "desktop detection stays off the web path")
assertEqual(desktopPlatform.supportsOnlineServices, true, "desktop builds keep online services enabled")
assertEqual(desktopPlatform.supportsThreadWorkers, true, "desktop builds keep worker threads enabled when available")

love = originalLove
