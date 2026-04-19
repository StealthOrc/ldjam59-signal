local uuid = {}

local seeded = false

local function ensureSeeded()
    if seeded then
        return
    end

    local seed = os.time()
    if love and love.timer and love.timer.getTime then
        seed = seed + math.floor(love.timer.getTime() * 1000000)
    end

    math.randomseed(seed)
    math.random()
    math.random()
    math.random()
    seeded = true
end

local function randomHexDigit(maxValue)
    ensureSeeded()
    return string.format("%x", math.random(0, maxValue or 15))
end

function uuid.generateV4()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return (template:gsub("[xy]", function(token)
        if token == "x" then
            return randomHexDigit(15)
        end
        return string.format("%x", math.random(8, 11))
    end))
end

function uuid.generatePlayerUuid()
    return uuid.generateV4()
end

function uuid.generatePlayerId()
    return uuid.generatePlayerUuid()
end

return uuid

