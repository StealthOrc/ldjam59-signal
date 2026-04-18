local Progression = {}

local SAVE_PATH = "progression.lua"

local function defaultData()
    return {
        coins = 0,
        max_speed_bonus_kmh = 0,
        signal_fuel_bonus_per_second = 0,
        upgrades = {
            boost_pads = false,
            double_acceleration = false,
            tower_fuel_boost = false,
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

    if type(data.signal_fuel_bonus_per_second) == "number" and data.signal_fuel_bonus_per_second >= 0 then
        safe.signal_fuel_bonus_per_second = math.floor(data.signal_fuel_bonus_per_second)
    end

    if type(data.upgrades) == "table" then
        safe.upgrades.boost_pads = data.upgrades.boost_pads == true
        safe.upgrades.double_acceleration = data.upgrades.double_acceleration == true
        safe.upgrades.tower_fuel_boost = data.upgrades.tower_fuel_boost == true
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
        string.format(
            "  signal_fuel_bonus_per_second = %d,",
            math.max(0, math.floor(data.signal_fuel_bonus_per_second or 0))
        ),
        "  upgrades = {",
        string.format("    boost_pads = %s,", data.upgrades and data.upgrades.boost_pads and "true" or "false"),
        string.format("    double_acceleration = %s,", data.upgrades and data.upgrades.double_acceleration and "true" or "false"),
        string.format("    tower_fuel_boost = %s,", data.upgrades and data.upgrades.tower_fuel_boost and "true" or "false"),
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
