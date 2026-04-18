local world = {}
world.__index = world

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function pseudoRandom(index)
    local value = math.sin(index * 12.9898 + 78.233) * 43758.5453
    return value - math.floor(value)
end

function world.new(tuning)
    local self = setmetatable({}, world)
    self.left = -tuning.corridorHalfWidth
    self.right = tuning.corridorHalfWidth
    self.barrierThickness = tuning.barrierThickness
    self.segmentHeight = tuning.segmentHeight
    self.drawPadding = tuning.worldDrawPadding
    self.segments = {}
    self.towers = {}
    self.visibleTop = -720
    self.visibleBottom = 720
    self:reset(tuning)
    return self
end

function world:reset(tuning)
    self.towers = {}
    self.nextTowerIndex = 1
    self.nextTowerY = -tuning.signalTowerFirstNorthOffset
end

local function laneRatioForTower(index, tuning)
    if index <= tuning.signalTowerScriptedCount then
        return tuning.signalTowerScriptedLaneRatios[index]
    end

    return tuning.signalTowerLaneRatioMin
        + (tuning.signalTowerLaneRatioMax - tuning.signalTowerLaneRatioMin) * pseudoRandom(index)
end

function world:spawnTower(index, tuning)
    local side = (index % 2 == 1) and -1 or 1
    local laneRatio = clamp(laneRatioForTower(index, tuning), 0.1, 0.9)
    local tower = {
        index = index,
        x = side * tuning.corridorHalfWidth * laneRatio,
        y = self.nextTowerY,
        radius = tuning.signalTowerRadius,
        fuelPerSecond = tuning.signalTowerFuelPerSecond,
        poleHeight = tuning.signalTowerPoleHeight,
        phase = pseudoRandom(index + 90),
    }

    self.towers[#self.towers + 1] = tower

    local spacing = (index < tuning.signalTowerScriptedCount)
        and tuning.signalTowerReachSpacing
        or tuning.signalTowerLaterSpacing
    self.nextTowerIndex = index + 1
    self.nextTowerY = self.nextTowerY - spacing
end

function world:update(carY, viewport, tuning)
    local top = carY - viewport.h * 1.65
    local bottom = carY + viewport.h * 1.3
    local firstIndex = math.floor(top / self.segmentHeight) - 1
    local lastIndex = math.ceil(bottom / self.segmentHeight) + 1

    self.segments = {}
    for index = firstIndex, lastIndex do
        table.insert(self.segments, {
            index = index,
            y = index * self.segmentHeight,
        })
    end

    self.visibleTop = top
    self.visibleBottom = bottom

    local towerGenerationLimit = top - viewport.h * 0.9
    while self.nextTowerY > towerGenerationLimit do
        self:spawnTower(self.nextTowerIndex, tuning)
    end

    for index = #self.towers, 1, -1 do
        if self.towers[index].y > bottom + viewport.h * 0.7 then
            table.remove(self.towers, index)
        end
    end
end

function world:resolveBarriers(carBody, tuning)
    local hitSide
    local minX = self.left + carBody.collisionRadius
    local maxX = self.right - carBody.collisionRadius

    if carBody.x < minX then
        carBody.x = minX
        if carBody.vx < 0 then
            carBody.vx = -carBody.vx * tuning.wallBounce
        end
        carBody.vy = carBody.vy * (1 - tuning.wallSpeedScrub)
        carBody.angularVelocity = carBody.angularVelocity + math.max(0.3, math.abs(carBody.vy) * tuning.wallSpinImpulse)
        carBody.heading = carBody.heading + tuning.wallHeadingKick
        hitSide = "left"
    elseif carBody.x > maxX then
        carBody.x = maxX
        if carBody.vx > 0 then
            carBody.vx = -carBody.vx * tuning.wallBounce
        end
        carBody.vy = carBody.vy * (1 - tuning.wallSpeedScrub)
        carBody.angularVelocity = carBody.angularVelocity - math.max(0.3, math.abs(carBody.vy) * tuning.wallSpinImpulse)
        carBody.heading = carBody.heading - tuning.wallHeadingKick
        hitSide = "right"
    end

    if hitSide then
        carBody.slip = math.max(carBody.slip, tuning.wallSlipKick)
    end

    return hitSide
end

function world:getSignalAt(carX, carY)
    local bestTower
    local bestStrength = 0

    for _, tower in ipairs(self.towers) do
        local dx = carX - tower.x
        local dy = carY - tower.y
        local distanceSquared = dx * dx + dy * dy
        local radiusSquared = tower.radius * tower.radius

        if distanceSquared <= radiusSquared then
            local distance = math.sqrt(distanceSquared)
            local strength = 1 - (distance / tower.radius)
            if strength > bestStrength then
                bestTower = tower
                bestStrength = strength
            end
        end
    end

    return bestTower, bestStrength
end

function world:draw()
    local graphics = love.graphics
    local spanTop = self.visibleTop - self.drawPadding
    local spanHeight = (self.visibleBottom - self.visibleTop) + self.drawPadding * 2
    local shoulderWidth = self.barrierThickness + 380

    graphics.setColor(0.08, 0.1, 0.09)
    graphics.rectangle("fill", self.left - shoulderWidth, spanTop, shoulderWidth, spanHeight)
    graphics.rectangle("fill", self.right, spanTop, shoulderWidth, spanHeight)

    graphics.setColor(0.13, 0.14, 0.15)
    graphics.rectangle("fill", self.left, spanTop, self.right - self.left, spanHeight)

    local time = love.timer.getTime()
    graphics.setLineWidth(4)
    for _, tower in ipairs(self.towers) do
        local pulse = 0.5 + 0.5 * math.sin(time * 1.8 + tower.phase * math.pi * 2)
        local alpha = 0.08 + 0.08 * pulse
        graphics.setColor(0.18, 0.72, 0.84, alpha)
        graphics.circle("fill", tower.x, tower.y, tower.radius)
        graphics.setColor(0.5, 0.92, 0.98, 0.18 + 0.1 * pulse)
        graphics.circle("line", tower.x, tower.y, tower.radius)
    end
    graphics.setLineWidth(1)

    graphics.setColor(0.42, 0.09, 0.08)
    graphics.rectangle("fill", self.left - self.barrierThickness, spanTop, self.barrierThickness, spanHeight)
    graphics.rectangle("fill", self.right, spanTop, self.barrierThickness, spanHeight)

    graphics.setColor(0.86, 0.74, 0.52, 0.85)
    graphics.rectangle("fill", self.left - 5, spanTop, 10, spanHeight)
    graphics.rectangle("fill", self.right - 5, spanTop, 10, spanHeight)

    for _, segment in ipairs(self.segments) do
        local phase = segment.index % 2
        local centerY = segment.y + self.segmentHeight * 0.18

        graphics.setColor(0.88, 0.86, 0.74, 0.78)
        if phase == 0 then
            graphics.rectangle("fill", -4, centerY, 8, self.segmentHeight * 0.36, 2, 2)
        end

        graphics.setColor(0.2, 0.21, 0.23, 0.55)
        graphics.rectangle("fill", self.left + 24, segment.y + self.segmentHeight * 0.08, self.right - self.left - 48, 6)

        graphics.setColor(0.89, 0.35, 0.22, 0.75)
        local panelHeight = self.segmentHeight * 0.44
        local panelY = segment.y + self.segmentHeight * 0.28
        if phase == 0 then
            graphics.rectangle("fill", self.left - self.barrierThickness, panelY, self.barrierThickness, panelHeight)
        else
            graphics.rectangle("fill", self.right, panelY, self.barrierThickness, panelHeight)
        end
    end

    for _, tower in ipairs(self.towers) do
        graphics.setColor(0.1, 0.12, 0.15)
        graphics.rectangle("fill", tower.x - 10, tower.y - tower.poleHeight, 20, tower.poleHeight + 8, 4, 4)
        graphics.setColor(0.94, 0.96, 0.98)
        graphics.rectangle("fill", tower.x - 3, tower.y - tower.poleHeight - 12, 6, tower.poleHeight + 20, 2, 2)
        graphics.setColor(0.49, 0.95, 0.9, 0.9)
        graphics.circle("fill", tower.x, tower.y - tower.poleHeight - 10, 8)
        graphics.setColor(0.82, 0.9, 0.97, 0.55)
        graphics.circle("line", tower.x, tower.y - tower.poleHeight - 10, 12)
    end
end

return world
