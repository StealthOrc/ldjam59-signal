local toml = require("src.game.util.toml")
local storagePaths = require("src.game.storage.storage_paths")

local mapReplayIndexStorage = {}

local REPLAY_INDEX_FILE = storagePaths.getCacheFilePath("map_replays_cache.toml")
local REPLAYS_PER_MAP_REVISION_LIMIT = 5
local STORAGE_VERSION = 1

local function sanitizeReplayEntry(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local replayUuid = tostring(entry.replayUuid or entry.replay_uuid or "")
    local mapUuid = tostring(entry.mapUuid or entry.map_uuid or "")
    local mapHash = tostring(entry.mapHash or entry.map_hash or "")
    local replayFilePath = tostring(entry.replayFilePath or entry.replay_file_path or "")

    if replayUuid == "" or mapUuid == "" or mapHash == "" or replayFilePath == "" then
        return nil
    end

    return {
        replayUuid = replayUuid,
        mapUuid = mapUuid,
        mapHash = mapHash,
        score = tonumber(entry.score or 0) or 0,
        recordedAt = tonumber(entry.recordedAt or entry.recorded_at or 0) or 0,
        replayFilePath = replayFilePath,
        duration = tonumber(entry.duration or entry.durationSeconds or entry.duration_seconds or 0) or 0,
        endReason = tostring(entry.endReason or entry.end_reason or ""),
        mapTitle = tostring(entry.mapTitle or entry.map_title or ""),
    }
end

local function sanitizeStore(store)
    local sanitized = {
        version = STORAGE_VERSION,
        replays = {},
    }

    local sourceReplays = type(store) == "table" and store.replays or nil
    if type(sourceReplays) ~= "table" then
        return sanitized
    end

    for _, entry in ipairs(sourceReplays) do
        local sanitizedEntry = sanitizeReplayEntry(entry)
        if sanitizedEntry then
            sanitized.replays[#sanitized.replays + 1] = sanitizedEntry
        end
    end

    return sanitized
end

local function readStoreFile()
    if not love.filesystem.getInfo(REPLAY_INDEX_FILE, "file") then
        return nil
    end

    local decoded = toml.parseFile(REPLAY_INDEX_FILE)
    if type(decoded) ~= "table" then
        return nil
    end

    return decoded
end

local function buildReplayEntry(replayRecord, summary)
    local resolvedReplayRecord = type(replayRecord) == "table" and replayRecord or {}
    local resolvedSummary = type(summary) == "table" and summary or {}
    local replayFilePath = tostring(resolvedReplayRecord.localFilePath or "")
    local replayUuid = tostring(resolvedReplayRecord.replayId or resolvedReplayRecord.replayUuid or "")
    local mapUuid = tostring(resolvedReplayRecord.mapUuid or resolvedSummary.mapUuid or "")
    local mapHash = tostring(resolvedReplayRecord.mapHash or "")

    if replayFilePath == "" or replayUuid == "" or mapUuid == "" or mapHash == "" then
        return nil, "Replay metadata is incomplete."
    end

    local recordedAt = tonumber(resolvedSummary.recorded_at or resolvedReplayRecord.createdAt or 0) or 0
    if recordedAt <= 0 then
        recordedAt = os.time() or 0
    end

    return {
        replayUuid = replayUuid,
        mapUuid = mapUuid,
        mapHash = mapHash,
        score = tonumber(resolvedSummary.finalScore or resolvedSummary.score or 0) or 0,
        recordedAt = recordedAt,
        replayFilePath = replayFilePath,
        duration = tonumber(resolvedReplayRecord.duration or 0) or 0,
        endReason = tostring(resolvedSummary.endReason or resolvedReplayRecord.endReason or ""),
        mapTitle = tostring(resolvedReplayRecord.mapTitle or resolvedSummary.mapTitle or ""),
    }
end

local function isSameReplay(left, right)
    return tostring(left and left.replayUuid or "") == tostring(right and right.replayUuid or "")
end

local function isSameMapRevision(left, right)
    return tostring(left and left.mapUuid or "") == tostring(right and right.mapUuid or "")
        and tostring(left and left.mapHash or "") == tostring(right and right.mapHash or "")
end

local function compareReplayEntries(left, right)
    local leftScore = tonumber(left and left.score or 0) or 0
    local rightScore = tonumber(right and right.score or 0) or 0
    if leftScore ~= rightScore then
        return leftScore > rightScore
    end

    local leftRecordedAt = tonumber(left and left.recordedAt or 0) or 0
    local rightRecordedAt = tonumber(right and right.recordedAt or 0) or 0
    if leftRecordedAt ~= rightRecordedAt then
        return leftRecordedAt < rightRecordedAt
    end

    return tostring(left and left.replayUuid or "") < tostring(right and right.replayUuid or "")
end

local function sortEntriesForPersistence(entries)
    table.sort(entries, function(left, right)
        local leftMapUuid = tostring(left and left.mapUuid or "")
        local rightMapUuid = tostring(right and right.mapUuid or "")
        if leftMapUuid ~= rightMapUuid then
            return leftMapUuid < rightMapUuid
        end

        local leftMapHash = tostring(left and left.mapHash or "")
        local rightMapHash = tostring(right and right.mapHash or "")
        if leftMapHash ~= rightMapHash then
            return leftMapHash < rightMapHash
        end

        return compareReplayEntries(left, right)
    end)
end

function mapReplayIndexStorage.save(store)
    storagePaths.ensureCacheDirectory()
    local sanitized = sanitizeStore(store)
    sortEntriesForPersistence(sanitized.replays)
    local encodedStore = toml.stringify(sanitized)
    local ok, writeError = love.filesystem.write(REPLAY_INDEX_FILE, encodedStore)
    if not ok then
        return nil, writeError or "The local replay index could not be saved."
    end

    return sanitized
end

function mapReplayIndexStorage.load()
    local loadedStore = readStoreFile()
    local sanitized = sanitizeStore(loadedStore)

    if loadedStore == nil then
        local savedStore = mapReplayIndexStorage.save(sanitized)
        if savedStore then
            sanitized = savedStore
        end
    end

    return sanitized
end

function mapReplayIndexStorage.updateReplayIndex(store, replayRecord, summary)
    local sanitized = sanitizeStore(store)
    local replayEntry, replayEntryError = buildReplayEntry(replayRecord, summary)
    if not replayEntry then
        return nil, replayEntryError
    end

    local nonBucketEntries = {}
    local bucketEntries = {}

    for _, existingEntry in ipairs(sanitized.replays) do
        if not isSameReplay(existingEntry, replayEntry) and isSameMapRevision(existingEntry, replayEntry) then
            bucketEntries[#bucketEntries + 1] = existingEntry
        elseif not isSameReplay(existingEntry, replayEntry) then
            nonBucketEntries[#nonBucketEntries + 1] = existingEntry
        end
    end

    bucketEntries[#bucketEntries + 1] = replayEntry
    table.sort(bucketEntries, compareReplayEntries)

    local keptEntries = {}
    local prunedEntries = {}

    for index, entry in ipairs(bucketEntries) do
        if index <= REPLAYS_PER_MAP_REVISION_LIMIT then
            keptEntries[#keptEntries + 1] = entry
        else
            prunedEntries[#prunedEntries + 1] = entry
        end
    end

    sanitized.replays = {}
    for _, entry in ipairs(nonBucketEntries) do
        sanitized.replays[#sanitized.replays + 1] = entry
    end
    for _, entry in ipairs(keptEntries) do
        sanitized.replays[#sanitized.replays + 1] = entry
    end

    sortEntriesForPersistence(sanitized.replays)

    local keptReplay = false
    for _, entry in ipairs(keptEntries) do
        if isSameReplay(entry, replayEntry) then
            keptReplay = true
            break
        end
    end

    return sanitized, {
        entry = replayEntry,
        keptReplay = keptReplay,
        prunedEntries = prunedEntries,
    }
end

function mapReplayIndexStorage.listReplaysForMapRevision(store, mapUuid, mapHash)
    local sanitized = sanitizeStore(store)
    local resolvedMapUuid = tostring(mapUuid or "")
    local resolvedMapHash = tostring(mapHash or "")
    local matchingEntries = {}

    if resolvedMapUuid == "" or resolvedMapHash == "" then
        return matchingEntries
    end

    for _, entry in ipairs(sanitized.replays) do
        if entry.mapUuid == resolvedMapUuid and entry.mapHash == resolvedMapHash then
            matchingEntries[#matchingEntries + 1] = entry
        end
    end

    table.sort(matchingEntries, compareReplayEntries)
    return matchingEntries
end

function mapReplayIndexStorage.getReplayByUuid(store, replayUuid)
    local sanitized = sanitizeStore(store)
    local resolvedReplayUuid = tostring(replayUuid or "")
    if resolvedReplayUuid == "" then
        return nil
    end

    for _, entry in ipairs(sanitized.replays) do
        if entry.replayUuid == resolvedReplayUuid then
            return entry
        end
    end

    return nil
end

return mapReplayIndexStorage
