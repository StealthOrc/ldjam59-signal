package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}
love.graphics = love.graphics or {}
love.filesystem = love.filesystem or {}

love.filesystem.getInfo = function()
    return false
end

local world = require("src.game.gameplay.railway_world")

local function assertTrue(value, label)
    if not value then
        error(label, 2)
    end
end

local simulation = world.new(100, 100, {
    edges = {},
    junctions = {},
    trains = {},
})

simulation.trains = {
    {
        id = "first",
        spawned = true,
        completed = false,
    },
    {
        id = "second",
        spawned = true,
        completed = false,
    },
}

simulation.getTrainCarriagePositions = function(_, train)
    if train.id == "first" then
        return {
            {
                x = 10,
                y = 10,
                angle = 0,
                collidable = true,
            },
        }
    end

    return {
        {
            x = 40,
            y = 10,
            angle = 0,
            collidable = true,
        },
    }
end

simulation:updateCollisionState()

assertTrue(simulation.failureReason == "collision", "wagon collisions should use the full wagon body, not just the inner window area")
assertTrue(simulation.collisionPoint ~= nil, "wagon body collisions should record a collision point")

print("world wagon collision hitbox tests passed")
