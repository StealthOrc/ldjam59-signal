local Progression = {}

local SAVE_PATH = "progression.lua"

local function defaultData()
    return {
        coins = 0,
        max_speed_bonus_kmh = 0,
        upgrades = {
            boost_pads = false,
            double_acceleration = false,
            sixth_gear = false,
            close_ratios = false,
            sport_transmission = false,
        },
    }
end

local function sanitize(data)
    local safe = defaultData()
    if type(data) ~= "table" then
        return safe
    end

    if type(data.coins) == "number" and data.coins >= 0 then
        safe.coins = math.floor(data.coins)
    end

    if type(data.max_speed_bonus_kmh) == "number" and data.max_speed_bonus_kmh >= 0 then
        safe.max_speed_bonus_kmh = math.floor(data.max_speed_bonus_kmh)
    end

    if type(data.upgrades) == "table" then
        safe.upgrades.boost_pads = data.upgrades.boost_pads == true
        safe.upgrades.double_acceleration = data.upgrades.double_acceleration == true
        safe.upgrades.sixth_gear = data.upgrades.sixth_gear == true
        safe.upgrades.close_ratios = data.upgrades.close_ratios == true
        safe.upgrades.sport_transmission = data.upgrades.sport_transmission == true
        if safe.max_speed_bonus_kmh == 0 and data.upgrades.top_speed_plus_20 == true then
            safe.max_speed_bonus_kmh = 24
        end
    end

    return safe
end

local function serialize(data)
    return table.concat({
        "return {",
        string.format("  coins = %d,", math.max(0, math.floor(data.coins or 0))),
        string.format("  max_speed_bonus_kmh = %d,", math.max(0, math.floor(data.max_speed_bonus_kmh or 0))),
        "  upgrades = {",
        string.format("    boost_pads = %s,", data.upgrades and data.upgrades.boost_pads and "true" or "false"),
        string.format("    double_acceleration = %s,", data.upgrades and data.upgrades.double_acceleration and "true" or "false"),
        string.format("    sixth_gear = %s,", data.upgrades and data.upgrades.sixth_gear and "true" or "false"),
        string.format("    close_ratios = %s,", data.upgrades and data.upgrades.close_ratios and "true" or "false"),
        string.format("    sport_transmission = %s,", data.upgrades and data.upgrades.sport_transmission and "true" or "false"),
        "  },",
        "}",
        "",
    }, "\n")
end

function Progression.load()
    if not love.filesystem.getInfo(SAVE_PATH) then
        return defaultData()
    end

    local chunk, loadError = love.filesystem.load(SAVE_PATH)
    if not chunk then
        return defaultData(), loadError
    end

    local ok, data = pcall(chunk)
    if not ok then
        return defaultData(), data
    end

    return sanitize(data)
end

function Progression.save(data)
    local ok, err = love.filesystem.write(SAVE_PATH, serialize(sanitize(data)))
    return ok, err
end

return Progression
