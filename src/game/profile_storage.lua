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

    if loadedProfile == nil then
        local savedProfile = profileStorage.save(sanitized)
        if savedProfile then
            sanitized = savedProfile
        end
    end

    return sanitized
end

return profileStorage
