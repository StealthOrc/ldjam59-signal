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

local function createBoostSignalShader()
    local shader = love.graphics.newShader([[
        extern number time;
        extern number phase;
        extern number pulse;

        float rectMask(vec2 uv, vec2 minCorner, vec2 maxCorner)
        {
            vec2 insideMin = step(minCorner, uv);
            vec2 insideMax = step(uv, maxCorner);
            return insideMin.x * insideMin.y * insideMax.x * insideMax.y;
        }

        float arrowMask(vec2 uv)
        {
            uv = fract(uv);
            uv = (uv - vec2(0.5)) / 0.58 + vec2(0.5);
            float shaft = rectMask(uv, vec2(0.44, 0.28), vec2(0.56, 0.86));

            vec2 headUv = vec2(uv.x - 0.5, (uv.y - 0.04) / 0.28);
            float headBand = step(0.0, headUv.y) * step(headUv.y, 1.0);
            float headWidth = headUv.y * 0.34 + 0.04;
            float head = headBand * step(abs(headUv.x), headWidth);

            return max(shaft, head);
        }

        vec4 effect(vec4 color, Image texture, vec2 tc, vec2 sc)
        {
            vec2 centered = tc - vec2(0.5);
            float circleMask = 1.0 - smoothstep(0.42, 0.5, length(centered));
            float arrowsA = arrowMask(vec2(tc.x * 1.2 + 0.08 + phase * 0.17, tc.y * 2.05 + time * 0.9));
            float arrowsB = arrowMask(vec2(tc.x * 1.0 + 0.54 + phase * 0.11, tc.y * 1.72 + time * 0.76 + 0.21)) * 0.9;

            float arrowsSmallA = arrowMask(vec2(tc.x * 1.95 + 0.36 + phase * 0.23, tc.y * 3.25 + time * 1.22 + 0.15)) * 0.92;
            float arrowsSmallB = arrowMask(vec2(tc.x * 2.2 + 0.74 + phase * 0.09, tc.y * 3.8 + time * 1.34 + 0.44)) * 0.86;
            float arrowsSmallC = arrowMask(vec2(tc.x * 1.8 + 0.92 + phase * 0.19, tc.y * 2.95 + time * 1.05 + 0.67)) * 0.8;

            float arrows = max(
                max(arrowsA, arrowsB),
                max(arrowsSmallA, max(arrowsSmallB, arrowsSmallC))
            );

            float glow = 1.0 - smoothstep(0.0, 0.5, length(centered * vec2(0.92, 1.05)));
            float alpha = circleMask * (arrows * (0.68 + pulse * 0.2) + glow * 0.04);

            return vec4(1.0, 1.0, 1.0, alpha) * color;
        }
    ]])
    return shader
end

local function createWhitePixelTexture()
    local imageData = love.image.newImageData(1, 1)
    imageData:setPixel(0, 0, 1, 1, 1, 1)

    local image = love.graphics.newImage(imageData)
    image:setFilter("nearest", "nearest")
    return image
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
    self.boostSignalsEnabled = false
    self.boostSignalShader = createBoostSignalShader()
    self.boostSignalTexture = createWhitePixelTexture()
    self.visibleTop = -720
    self.visibleBottom = 720
    self:reset(tuning, nil)
    return self
end

function world:reset(tuning, progression)
    self.towers = {}
    self.nextTowerIndex = 1
    self.nextTowerY = -tuning.signalTowerFirstNorthOffset
    self.nextTowerGap = tuning.signalTowerFirstGap
    self.boostSignalsEnabled = progression
        and progression.upgrades
        and progression.upgrades.boost_pads == true
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
        touchRadius = tuning.signalTowerTouchRadius,
        fuelPerSecond = tuning.signalTowerFuelPerSecond,
        poleHeight = tuning.signalTowerPoleHeight,
        phase = pseudoRandom(index + 90),
        isBoostSignal = self.boostSignalsEnabled and index % tuning.boostSignalEveryNthTower == 0,
        fuelBoostCollected = false,
    }

    self.towers[#self.towers + 1] = tower

    self.nextTowerIndex = index + 1
    self.nextTowerY = self.nextTowerY - self.nextTowerGap
    self.nextTowerGap = self.nextTowerGap * tuning.signalTowerGapMultiplier
end

function world:update(carY, viewport, tuning, progression)
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

    self.boostSignalsEnabled = progression
        and progression.upgrades
        and progression.upgrades.boost_pads == true

    local towerGenerationLimit = top - viewport.h * 0.9
    while self.nextTowerY > towerGenerationLimit do
        self:spawnTower(self.nextTowerIndex, tuning)
    end

    while not self:getNextTowerAhead(carY) do
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

function world:getNextTowerAhead(carY)
    local nextTower
    local closestNorthDistance

    for _, tower in ipairs(self.towers) do
        local northDistance = carY - tower.y
        if northDistance > 0 and (not closestNorthDistance or northDistance < closestNorthDistance) then
            nextTower = tower
            closestNorthDistance = northDistance
        end
    end

    return nextTower, closestNorthDistance
end

function world:getBoostSignalAt(carX, carY)
    local bestTower
    local bestStrength = 0

    for _, tower in ipairs(self.towers) do
        if tower.isBoostSignal then
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
    end

    return bestTower, bestStrength
end

function world:resolveBoostSignals(carBody, tuning)
    if not self.boostSignalsEnabled then
        return nil
    end

    local tower = self:getBoostSignalAt(carBody.x, carBody.y)
    if not tower then
        carBody.boostSignalTowerIndex = nil
        return nil
    end

    if carBody.boostSignalTowerIndex ~= tower.index and (carBody.boostPadCooldown or 0) <= 0 then
            carBody.boostPadCooldown = tuning.boostPadCooldown
            carBody.boostPadTimer = tuning.boostPadDuration
            carBody.heading = 0
            carBody.steerAngle = 0
            carBody.angularVelocity = 0
        carBody.boostSignalTowerIndex = tower.index
    end

    return tower
end

function world:resolveTowerFuelBoost(carBody, tuning)
    for _, tower in ipairs(self.towers) do
        if not tower.fuelBoostCollected then
            local dx = carBody.x - tower.x
            local dy = carBody.y - tower.y
            local triggerRadius = (tower.touchRadius or tuning.signalTowerTouchRadius or 0) + carBody.collisionRadius

            if dx * dx + dy * dy <= triggerRadius * triggerRadius then
                tower.fuelBoostCollected = true
                return tower
            end
        end
    end

    return nil
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
        local fillColor = tower.isBoostSignal and { 0.24, 0.92, 0.36 } or { 0.18, 0.72, 0.84 }
        local lineColor = tower.isBoostSignal and { 0.82, 0.98, 0.54 } or { 0.5, 0.92, 0.98 }
        local alpha = tower.isBoostSignal and (0.05 + 0.04 * pulse) or (0.08 + 0.08 * pulse)
        graphics.setColor(fillColor[1], fillColor[2], fillColor[3], alpha)
        graphics.circle("fill", tower.x, tower.y, tower.radius)
        if tower.isBoostSignal and self.boostSignalShader then
            self.boostSignalShader:send("time", time)
            self.boostSignalShader:send("phase", tower.phase)
            self.boostSignalShader:send("pulse", pulse)
            graphics.setShader(self.boostSignalShader)
            graphics.setColor(1, 1, 1, 1)
            graphics.draw(
                self.boostSignalTexture,
                tower.x - tower.radius,
                tower.y - tower.radius,
                0,
                tower.radius * 2,
                tower.radius * 2
            )
            graphics.setShader()
        end
        graphics.setColor(lineColor[1], lineColor[2], lineColor[3], tower.isBoostSignal and (0.28 + 0.14 * pulse) or (0.18 + 0.1 * pulse))
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
        if tower.isBoostSignal then
            graphics.setColor(0.88, 0.98, 0.44, 0.95)
        else
            graphics.setColor(0.49, 0.95, 0.9, 0.9)
        end
        graphics.circle("fill", tower.x, tower.y - tower.poleHeight - 10, 8)
        if tower.isBoostSignal then
            graphics.setColor(0.98, 0.96, 0.62, 0.64)
        else
            graphics.setColor(0.82, 0.9, 0.97, 0.55)
        end
        graphics.circle("line", tower.x, tower.y - tower.poleHeight - 10, 12)
    end
end

return world
