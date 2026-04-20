local profileStorage = {}
local toml = require("src.game.toml")
local uuid = require("src.game.uuid")

local PROFILE_FILE = "profile.toml"
local PROFILE_VERSION = 3
local PLAYER_ID_PREFIX = "player-"
local UUID_PATTERN = "^[0-9a-fA-F]+%-[0-9a-fA-F]+%-[0-9a-fA-F]+%-[0-9a-fA-F]+%-[0-9a-fA-F]+$"
local DEFAULT_EDITOR_GRID_STEP = 64
local MIN_EDITOR_GRID_STEP = 16
local MAX_EDITOR_GRID_STEP = 256
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
    local source = type(profile) == "table" and profile or {}
    local editor = type(source.editor) == "table" and source.editor or {}

    local sanitized = {
        version = PROFILE_VERSION,
        player_uuid = normalizePlayerUuid(source.player_uuid),
        playerDisplayName = type(source.playerDisplayName) == "string" and source.playerDisplayName or "",
        playMode = normalizePlayMode(source.playMode),
        debugMode = source.debugMode == true,
        editor = {
            gridVisible = editor.gridVisible ~= false,
            gridStep = math.max(
                MIN_EDITOR_GRID_STEP,
                math.min(
                    MAX_EDITOR_GRID_STEP,
                    math.floor(tonumber(editor.gridStep) or DEFAULT_EDITOR_GRID_STEP)
                )
            ),
        },
        tutorials = {
            dismissedMapGuides = normalizeDismissedMapGuides(
                type(source.tutorials) == "table" and source.tutorials.dismissedMapGuides or nil
            ),
        },
    }

    if sanitized.player_uuid == "" then
        sanitized.player_uuid = uuid.generatePlayerUuid()
    end

    return sanitized
end

local function readProfileFile()
    if not love.filesystem.getInfo(PROFILE_FILE, "file") then
        return nil
    end

    local decoded = toml.parseFile(PROFILE_FILE)
    if type(decoded) ~= "table" then
        return nil
    end

    return decoded
end

function profileStorage.save(profile)
    local sanitized = sanitizeProfile(profile)
    local body = toml.stringify(sanitized)
    local ok, writeError = love.filesystem.write(PROFILE_FILE, body)
    if not ok then
        return nil, writeError or "Profile could not be saved."
    end

    return sanitized
end

function profileStorage.load()
    local loadedProfile = readProfileFile()
    local sanitized = sanitizeProfile(loadedProfile)
    local loadedEditor = type(loadedProfile) == "table" and type(loadedProfile.editor) == "table" and loadedProfile.editor or nil
    local loadedTutorials = type(loadedProfile) == "table" and type(loadedProfile.tutorials) == "table" and loadedProfile.tutorials or nil

    local needsSave = loadedProfile == nil
        or loadedProfile.player_uuid ~= sanitized.player_uuid
        or loadedProfile.playerDisplayName ~= sanitized.playerDisplayName
        or loadedProfile.playMode ~= sanitized.playMode
        or loadedProfile.debugMode ~= sanitized.debugMode
        or loadedEditor == nil
        or loadedEditor.gridVisible ~= sanitized.editor.gridVisible
        or loadedEditor.gridStep ~= sanitized.editor.gridStep
        or loadedTutorials == nil
        or not sameBooleanKeySet(
            normalizeDismissedMapGuides(loadedTutorials and loadedTutorials.dismissedMapGuides or nil),
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
