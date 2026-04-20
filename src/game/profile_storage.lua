local profileStorage = {}
local uuid = require("src.game.uuid")

local PROFILE_FILE = "profile.lua"
local PROFILE_VERSION = 3
local PLAYER_ID_PREFIX = "player-"
local UUID_PATTERN = "^[0-9a-fA-F]+%-[0-9a-fA-F]+%-[0-9a-fA-F]+%-[0-9a-fA-F]+%-[0-9a-fA-F]+$"
local DEFAULT_EDITOR_GRID_STEP = 64
local PLAY_MODE_ONLINE = "online"
local PLAY_MODE_OFFLINE = "offline"

local function normalizeDismissedMapGuides(value)
    local normalized = {}

    if type(value) ~= "table" then
        return normalized
    end

    for key, entry in pairs(value) do
        if type(key) == "string" and entry == true then
            normalized[key] = true
        end
    end

    return normalized
end

local function sameBooleanKeySet(firstValue, secondValue)
    local seen = {}

    for key, entry in pairs(firstValue or {}) do
        seen[key] = true
        if secondValue[key] ~= entry then
            return false
        end
    end

    for key, entry in pairs(secondValue or {}) do
        if not seen[key] and firstValue[key] ~= entry then
            return false
        end
    end

    return true
end

local function normalizePlayMode(value)
    if value == PLAY_MODE_ONLINE or value == PLAY_MODE_OFFLINE then
        return value
    end

    return ""
end

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

local function normalizePlayerUuid(value)
    if type(value) ~= "string" then
        return ""
    end

    local normalizedValue = value:gsub("^" .. PLAYER_ID_PREFIX, "")
    if normalizedValue:match(UUID_PATTERN) then
        return string.lower(normalizedValue)
    end

    return ""
end

local function sanitizeProfile(profile)
    local resolvedPlayerUuid = normalizePlayerUuid(profile.player_uuid)
    if resolvedPlayerUuid == "" then
        resolvedPlayerUuid = normalizePlayerUuid(profile.playerId)
    end
    if resolvedPlayerUuid == "" then
        resolvedPlayerUuid = normalizePlayerUuid(profile.playerUuid)
    end

    local sanitized = {
        version = PROFILE_VERSION,
        player_uuid = resolvedPlayerUuid,
        playerDisplayName = type(profile.playerDisplayName) == "string" and profile.playerDisplayName or "",
        playMode = normalizePlayMode(profile.playMode),
        debugMode = profile.debugMode == true,
        editor = {
            gridVisible = not (type(profile.editor) == "table" and profile.editor.gridVisible == false),
            gridStep = math.max(16, math.min(256, math.floor(tonumber(type(profile.editor) == "table" and profile.editor.gridStep) or DEFAULT_EDITOR_GRID_STEP))),
        },
        tutorials = {
            dismissedMapGuides = normalizeDismissedMapGuides(type(profile.tutorials) == "table" and profile.tutorials.dismissedMapGuides or nil),
        },
    }

    if sanitized.player_uuid == "" then
        sanitized.player_uuid = uuid.generatePlayerUuid()
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
        or loadedProfile.player_uuid ~= sanitized.player_uuid
        or loadedProfile.playerId ~= nil
        or loadedProfile.playerUuid ~= nil
        or loadedProfile.playerDisplayName ~= sanitized.playerDisplayName
        or loadedProfile.playMode ~= sanitized.playMode
        or loadedProfile.debugMode ~= sanitized.debugMode
        or type(loadedProfile.editor) ~= "table"
        or loadedProfile.editor.gridVisible ~= sanitized.editor.gridVisible
        or loadedProfile.editor.gridStep ~= sanitized.editor.gridStep
        or type(loadedProfile.tutorials) ~= "table"
        or not sameBooleanKeySet(
            normalizeDismissedMapGuides(type(loadedProfile.tutorials) == "table" and loadedProfile.tutorials.dismissedMapGuides or nil),
            sanitized.tutorials.dismissedMapGuides
        )

    if needsSave then
        local savedProfile = profileStorage.save(sanitized)
        if savedProfile then
            sanitized = savedProfile
        end
    end

    return sanitized
end

return profileStorage
