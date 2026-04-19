local profileStorage = {}
local uuid = require("src.game.uuid")

local PROFILE_FILE = "profile.lua"

local function isIdentifier(value)
    return type(value) == "string" and value:match("^[%a_][%w_]*$") ~= nil
end

local function isArray(value)
    if type(value) ~= "table" then
        return false
    end

    local count = 0
    local maxIndex = 0
    for key, _ in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end
        count = count + 1
        if key > maxIndex then
            maxIndex = key
        end
    end

    return count == maxIndex
end

local function sortedKeys(value)
    local keys = {}
    for key, _ in pairs(value) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then
            return a < b
        end
        return tostring(a) < tostring(b)
    end)
    return keys
end

local function serializeValue(value, indent)
    local valueType = type(value)
    indent = indent or 0

    if valueType == "nil" then
        return "nil"
    end
    if valueType == "number" or valueType == "boolean" then
        return tostring(value)
    end
    if valueType == "string" then
        return string.format("%q", value)
    end
    if valueType ~= "table" then
        error("Unsupported profile value type: " .. valueType)
    end

    local nextIndent = indent + 4
    local prefix = string.rep(" ", nextIndent)
    local closingIndent = string.rep(" ", indent)
    local lines = { "{" }

    if isArray(value) then
        for _, entry in ipairs(value) do
            lines[#lines + 1] = prefix .. serializeValue(entry, nextIndent) .. ","
        end
    else
        for _, key in ipairs(sortedKeys(value)) do
            local keyText = isIdentifier(key) and key or ("[" .. serializeValue(key, nextIndent) .. "]")
            lines[#lines + 1] = prefix .. keyText .. " = " .. serializeValue(value[key], nextIndent) .. ","
        end
    end

    lines[#lines + 1] = closingIndent .. "}"
    return table.concat(lines, "\n")
end

local function sanitizeProfile(profile)
    local sanitized = {
        version = 1,
        playerId = type(profile.playerId) == "string" and profile.playerId or "",
        playerDisplayName = type(profile.playerDisplayName) == "string" and profile.playerDisplayName or "",
        debugMode = profile.debugMode == true,
    }

    if sanitized.playerId == "" then
        sanitized.playerId = uuid.generatePlayerId()
    end

    return sanitized
end

function profileStorage.save(profile)
    local sanitized = sanitizeProfile(profile or {})
    local body = "return " .. serializeValue(sanitized) .. "\n"
    local ok, writeError = love.filesystem.write(PROFILE_FILE, body)
    if not ok then
        return nil, writeError or "Profile could not be saved."
    end
    return sanitized
end

function profileStorage.load()
    local loadedProfile

    if love.filesystem.getInfo(PROFILE_FILE, "file") then
        local chunk, loadError = love.filesystem.load(PROFILE_FILE)
        if chunk then
            local ok, result = pcall(chunk)
            if ok and type(result) == "table" then
                loadedProfile = result
            end
        elseif loadError then
            loadedProfile = nil
        end
    end

    local sanitized = sanitizeProfile(loadedProfile or {})
    local needsSave = loadedProfile == nil
        or loadedProfile.playerId ~= sanitized.playerId
        or loadedProfile.playerDisplayName ~= sanitized.playerDisplayName
        or loadedProfile.debugMode ~= sanitized.debugMode

    if needsSave then
        local savedProfile = profileStorage.save(sanitized)
        if savedProfile then
            sanitized = savedProfile
        end
    end

    return sanitized
end

return profileStorage


