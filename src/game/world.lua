local world = {}
world.__index = world

function world.new(tuning)
    local self = setmetatable({}, world)
    self.left = -tuning.corridorHalfWidth
    self.right = tuning.corridorHalfWidth
    self.barrierThickness = tuning.barrierThickness
    self.segmentHeight = tuning.segmentHeight
    self.drawPadding = tuning.worldDrawPadding
    self.segments = {}
    self.visibleTop = -720
    self.visibleBottom = 720
    return self
end

function world:update(carY, viewport)
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
end

return world
