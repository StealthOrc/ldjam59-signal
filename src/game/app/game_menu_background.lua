local mapPresentation = require("src.game.app.map_presentation")

return function(Game, shared)
    setfenv(1, setmetatable({ Game = Game }, {
        __index = function(_, key)
            local sharedValue = shared[key]
            if sharedValue ~= nil then
                return sharedValue
            end

            return _G[key]
        end,
    }))

local MENU_BACKGROUND_BUILTIN_REPLAY_DIR = "src/game/data/replays/campaign"
local MENU_BACKGROUND_LOCAL_REPLAY_DIR = "cache/replays"
local MENU_BACKGROUND_OUTRO_DURATION = 0.56
local MENU_BACKGROUND_REPLAY_END_EPSILON = 0.0005

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function isTomlReplayFile(fileName)
    return type(fileName) == "string" and fileName:match("%.toml$") ~= nil
end

local function listReplayPathsInDirectory(directoryPath, source)
    local candidates = {}
    if not love.filesystem.getInfo(directoryPath, "directory") then
        return candidates
    end

    local fileNames = love.filesystem.getDirectoryItems(directoryPath)
    table.sort(fileNames)
    for _, fileName in ipairs(fileNames) do
        if isTomlReplayFile(fileName) then
            candidates[#candidates + 1] = {
                path = directoryPath .. "/" .. fileName,
                source = source,
            }
        end
    end

    return candidates
end

local function getRandomIndex(count)
    if count <= 0 then
        return nil
    end

    if love and love.math and love.math.random then
        return love.math.random(count)
    end

    return math.random(count)
end

function Game:getMenuBackgroundReplayCandidates()
    local candidates = {}

    for _, candidate in ipairs(listReplayPathsInDirectory(MENU_BACKGROUND_LOCAL_REPLAY_DIR, "local")) do
        candidates[#candidates + 1] = candidate
    end

    for _, candidate in ipairs(listReplayPathsInDirectory(MENU_BACKGROUND_BUILTIN_REPLAY_DIR, "builtin")) do
        candidates[#candidates + 1] = candidate
    end

    return candidates
end

function Game:buildMenuBackgroundReplayState(candidate)
    local resolvedCandidate = type(candidate) == "table" and candidate or nil
    local replayPath = tostring(resolvedCandidate and resolvedCandidate.path or "")
    if replayPath == "" then
        return nil
    end

    local replayRecord = replayStorage.load(replayPath)
    if type(replayRecord) ~= "table" then
        return nil
    end

    local mapDescriptor = self:getMapDescriptorByUuid(
        tostring(replayRecord.mapUuid or ""),
        tostring(replayRecord.mapHash or "")
    )
    if not mapDescriptor then
        return nil
    end

    local replayLevelSource = self:getReplayLevelSourceForDescriptor(mapDescriptor)
    if type(replayLevelSource) ~= "table" then
        return nil
    end

    local runtime = replayRuntime.new(
        replayLevelSource,
        replayRecord,
        self.viewport.w,
        self.viewport.h
    )
    local presentation = mapPresentation.buildState(runtime.playbackWorld, mapDescriptor, self.profile)
    if not presentation then
        return nil
    end

    return {
        candidatePath = replayPath,
        source = resolvedCandidate.source or "unknown",
        replayRecord = replayRecord,
        mapDescriptor = mapDescriptor,
        replayLevelSource = replayLevelSource,
        replayRuntime = runtime,
        presentation = presentation,
        phase = "intro",
        outroElapsed = 0,
    }
end

function Game:startMenuBackgroundReplayLoop()
    local candidates = self:getMenuBackgroundReplayCandidates()
    local skippedLastPath = false

    while #candidates > 0 do
        local candidateIndex = getRandomIndex(#candidates) or 1
        local candidate = table.remove(candidates, candidateIndex)
        if #candidates > 0
            and not skippedLastPath
            and candidate.path == self.menuBackgroundReplayLastPath then
            skippedLastPath = true
            candidates[#candidates + 1] = candidate
        else
            local replayState = self:buildMenuBackgroundReplayState(candidate)
            if replayState then
                self.menuBackgroundReplay = replayState
                return replayState
            end
        end
    end

    self.menuBackgroundReplay = nil
    return nil
end

function Game:resetMenuBackgroundReplayLoop()
    self.menuBackgroundReplay = nil
    return self:startMenuBackgroundReplayLoop()
end

function Game:updateMenuBackgroundReplay(dt)
    if self.screen ~= "menu" then
        return false
    end

    if not self.menuBackgroundReplay then
        return self:startMenuBackgroundReplayLoop() ~= nil
    end

    local replayState = self.menuBackgroundReplay
    if replayState.phase == "intro" then
        if mapPresentation.update(replayState.presentation, dt) then
            replayState.phase = "replay"
            replayState.replayRuntime:seek(0)
            replayState.replayRuntime:setPlaying(true)
        end
        return true
    end

    if replayState.phase == "replay" then
        replayState.replayRuntime:update(dt)
        if replayState.replayRuntime.isPlaying ~= true
            and (replayState.replayRuntime.currentTime or 0) >= ((replayState.replayRuntime.duration or 0) - MENU_BACKGROUND_REPLAY_END_EPSILON) then
            replayState.phase = "outro"
            replayState.outroElapsed = 0
        end
        return true
    end

    if replayState.phase == "outro" then
        replayState.outroElapsed = math.max(0, (replayState.outroElapsed or 0) + math.max(0, dt or 0))
        if replayState.outroElapsed >= MENU_BACKGROUND_OUTRO_DURATION then
            self.menuBackgroundReplayLastPath = replayState.candidatePath
            self:startMenuBackgroundReplayLoop()
        end
        return true
    end

    return false
end

function Game:hasMenuBackgroundReplay()
    return self.screen == "menu"
        and self.menuBackgroundReplay ~= nil
        and self.menuBackgroundReplay.replayRuntime ~= nil
        and self.menuBackgroundReplay.replayRuntime.playbackWorld ~= nil
end

function Game:getMenuBackgroundReplayTitleState()
    local replayState = self.menuBackgroundReplay
    if not replayState or replayState.phase ~= "intro" then
        return nil
    end

    local titleEndTime = replayState.presentation
        and replayState.presentation.titleSequence
        and replayState.presentation.titleSequence.endTime
        or 0
    if (replayState.presentation and replayState.presentation.elapsed or 0) >= titleEndTime then
        return nil
    end

    return replayState.presentation
end

function Game:getMenuBackgroundReplayDrawOptions()
    local replayState = self.menuBackgroundReplay
    if not replayState then
        return nil
    end

    if replayState.phase == "intro" then
        return {
            presentation = replayState.presentation,
            drawTrains = false,
            drawCollision = false,
        }
    end

    if replayState.phase == "outro" then
        return {
            drawTrains = false,
            drawCollision = false,
            outro = {
                progress = clamp((replayState.outroElapsed or 0) / MENU_BACKGROUND_OUTRO_DURATION, 0, 1),
                presentation = replayState.presentation,
            },
        }
    end

    return {
        drawCollision = false,
    }
end

end
