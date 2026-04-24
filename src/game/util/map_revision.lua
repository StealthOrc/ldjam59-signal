local mapRevision = {}

local DEFAULT_REVISION_NUMBER = 1
local REVISION_BASE = 10
local REVISION_PATCH_DIVISOR = 1
local REVISION_MINOR_DIVISOR = 10
local REVISION_MAJOR_DIVISOR = 100

local function sanitizeRevisionNumber(value)
    local revisionNumber = math.floor(tonumber(value) or DEFAULT_REVISION_NUMBER)
    if revisionNumber < DEFAULT_REVISION_NUMBER then
        return DEFAULT_REVISION_NUMBER
    end

    return revisionNumber
end

function mapRevision.sanitizeRevisionNumber(value)
    return sanitizeRevisionNumber(value)
end

function mapRevision.formatRevisionLabel(value)
    local revisionNumber = sanitizeRevisionNumber(value)
    local patchNumber = math.floor(revisionNumber / REVISION_PATCH_DIVISOR) % REVISION_BASE
    local minorNumber = math.floor(revisionNumber / REVISION_MINOR_DIVISOR) % REVISION_BASE
    local majorNumber = math.floor(revisionNumber / REVISION_MAJOR_DIVISOR)

    return string.format("v%d.%d.%d", majorNumber, minorNumber, patchNumber)
end

return mapRevision
