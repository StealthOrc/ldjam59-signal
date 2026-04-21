local platform = {}

local WEB_OS_NAMES = {
    Web = true,
    HTML5 = true,
}

local function getOsName()
    if not (love and love.system and love.system.getOS) then
        return nil
    end

    local ok, osName = pcall(love.system.getOS)
    if not ok then
        return nil
    end

    return osName
end

function platform.detect()
    local osName = getOsName()
    local isWeb = WEB_OS_NAMES[tostring(osName or "")] == true

    return {
        os = osName,
        isWeb = isWeb,
        supportsOnlineServices = not isWeb,
        supportsThreadWorkers = not isWeb and love and love.thread and love.thread.getChannel and love.thread.newThread and true or false,
        supportsClipboard = not isWeb and love and love.system and love.system.setClipboardText and true or false,
        supportsFileManagerReveal = not isWeb and love and love.system and love.system.openURL and true or false,
        onlineUnavailableReason = isWeb and "Online features are disabled in the HTML5 build." or nil,
    }
end

return platform
