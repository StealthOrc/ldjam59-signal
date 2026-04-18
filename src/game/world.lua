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

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function segmentLength(a, b)
    local dx = b.x - a.x
    local dy = b.y - a.y
    return math.sqrt(dx * dx + dy * dy)
end

local function normalize(dx, dy)
    local length = math.sqrt(dx * dx + dy * dy)
    if length <= 0.0001 then
        return 0, 1
    end
    return dx / length, dy / length
end

local function distanceSquared(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by
    return dx * dx + dy * dy
end

local function buildPolyline(points)
    local segments = {}
    local totalLength = 0

    for index = 1, #points - 1 do
        local startPoint = points[index]
        local endPoint = points[index + 1]
        local length = segmentLength(startPoint, endPoint)
        segments[#segments + 1] = {
            a = startPoint,
            b = endPoint,
            startDistance = totalLength,
            length = length,
        }
        totalLength = totalLength + length
    end

    return {
        points = points,
        segments = segments,
        length = totalLength,
    }
end

local function angleBetweenPoints(a, b)
    local dx = b.x - a.x
    local dy = b.y - a.y

    if math.atan2 then
        return math.atan2(dy, dx)
    end

    if dx == 0 then
        if dy >= 0 then
            return math.pi * 0.5
        end
        return -math.pi * 0.5
    end

    local angle = math.atan(dy / dx)
    if dx < 0 then
        angle = angle + math.pi
    end
    return angle
end

local function pointOnPath(path, distance)
    local segments = path.segments
    local first = segments[1]
    local last = segments[#segments]

    if distance <= 0 then
        local dirX, dirY = normalize(first.b.x - first.a.x, first.b.y - first.a.y)
        return first.a.x + dirX * distance, first.a.y + dirY * distance, angleBetweenPoints(first.a, first.b)
    end

    if distance >= path.length then
        local overflow = distance - path.length
        local dirX, dirY = normalize(last.b.x - last.a.x, last.b.y - last.a.y)
        return last.b.x + dirX * overflow, last.b.y + dirY * overflow, angleBetweenPoints(last.a, last.b)
    end

    for _, segment in ipairs(segments) do
        local endDistance = segment.startDistance + segment.length
        if distance <= endDistance then
            local t = (distance - segment.startDistance) / segment.length
            local x = lerp(segment.a.x, segment.b.x, t)
            local y = lerp(segment.a.y, segment.b.y, t)
            return x, y, angleBetweenPoints(segment.a, segment.b)
        end
    end

    return last.b.x, last.b.y, angleBetweenPoints(last.a, last.b)
end

local function trackLabel(trackId)
    if trackId == 1 then
        return "Blue"
    end
    return "Amber"
end

function world.new(viewportW, viewportH)
    local self = setmetatable({}, world)

    self.viewport = { w = viewportW, h = viewportH }
    self.trackWidth = 14
    self.sharedWidth = 18
    self.trainSpeed = 168
    self.trainAcceleration = 260
    self.carriageLength = 34
    self.carriageGap = 12
    self.carriageCount = 4
    self.exitPadding = 220
    self.activeTrackId = 1
    self.switchPulse = 0
    self.tracks = {}
    self.trains = {}
    self.crossingRadius = 40
    self.collisionPoint = nil
    self.failed = false

    self:resize(viewportW, viewportH)

    return self
end

function world:buildTrack(trackId, startX, mergeX, mergeY, exitY, color, darkColor)
    local startY = -120
    local bendY = mergeY - self.viewport.h * 0.22
    local branchPath = buildPolyline({
        { x = startX, y = startY },
        { x = startX, y = bendY },
        { x = mergeX, y = mergeY },
    })

    local sharedPath = buildPolyline({
        { x = mergeX, y = mergeY },
        { x = mergeX, y = exitY },
    })

    local fullPath = buildPolyline({
        { x = startX, y = startY },
        { x = startX, y = bendY },
        { x = mergeX, y = mergeY },
        { x = mergeX, y = exitY },
    })

    local signalDistance = math.max(branchPath.length - (self.crossingRadius + 10), 0)
    local stopDistance = math.max(signalDistance - (self.carriageLength + 12), 0)
    local stopX, stopY = pointOnPath(fullPath, stopDistance)
    local signalX, signalY = pointOnPath(fullPath, signalDistance)

    return {
        id = trackId,
        label = trackLabel(trackId),
        color = color,
        darkColor = darkColor,
        branchPath = branchPath,
        sharedPath = sharedPath,
        fullPath = fullPath,
        branchLength = branchPath.length,
        signalDistance = signalDistance,
        signalPoint = { x = signalX, y = signalY },
        stopDistance = stopDistance,
        stopPoint = { x = stopX, y = stopY },
    }
end

function world:createTrain(track, initialProgress, speedScale)
    return {
        trackId = track.id,
        track = track,
        progress = initialProgress,
        speed = self.trainSpeed * speedScale,
        currentSpeed = 0,
        color = track.color,
        darkColor = track.darkColor,
        completed = false,
    }
end

function world:resize(viewportW, viewportH)
    self.viewport.w = viewportW
    self.viewport.h = viewportH

    local mergeX = viewportW * 0.5
    local mergeY = viewportH * 0.48
    local exitY = viewportH + 180
    self.mergePoint = { x = mergeX, y = mergeY }
    self.crossingRadius = math.max(34, math.min(viewportW, viewportH) * 0.045)

    self.tracks = {
        self:buildTrack(1, viewportW * 0.33, mergeX, mergeY, exitY, { 0.33, 0.8, 0.98 }, { 0.12, 0.32, 0.44 }),
        self:buildTrack(2, viewportW * 0.67, mergeX, mergeY, exitY, { 0.96, 0.7, 0.28 }, { 0.42, 0.24, 0.08 }),
    }

    if #self.trains == 0 then
        self.trains = {
            self:createTrain(self.tracks[1], -70, 1),
            self:createTrain(self.tracks[2], -210, 0.93),
        }
    else
        for _, train in ipairs(self.trains) do
            train.track = self.tracks[train.trackId]
            train.color = train.track.color
            train.darkColor = train.track.darkColor
        end
    end
end

function world:setActiveTrack(trackId)
    local nextTrackId = clamp(trackId, 1, #self.tracks)
    if nextTrackId ~= self.activeTrackId then
        self.activeTrackId = nextTrackId
        self.switchPulse = 0.22
    end
end

function world:toggleTrack()
    if self.activeTrackId == 1 then
        self:setActiveTrack(2)
    else
        self:setActiveTrack(1)
    end
end

function world:isCrossingHit(x, y)
    return distanceSquared(x, y, self.mergePoint.x, self.mergePoint.y) <= self.crossingRadius * self.crossingRadius
end

function world:getDesiredLeadDistance(train)
    if train.completed or train.progress >= train.track.branchLength then
        return nil
    end

    if train.trackId ~= self.activeTrackId then
        return train.track.stopDistance
    end

    return nil
end

function world:updateTrain(train, dt)
    if train.completed then
        return
    end

    local desiredStopDistance = self:getDesiredLeadDistance(train)
    local targetSpeed = train.speed

    if desiredStopDistance then
        local brakingWindow = 110
        local remainingDistance = desiredStopDistance - train.progress

        if remainingDistance <= 0 then
            targetSpeed = 0
            train.progress = desiredStopDistance
        else
            targetSpeed = train.speed * clamp(remainingDistance / brakingWindow, 0, 1)
        end
    end

    if train.currentSpeed < targetSpeed then
        train.currentSpeed = math.min(targetSpeed, train.currentSpeed + self.trainAcceleration * dt)
    else
        train.currentSpeed = math.max(targetSpeed, train.currentSpeed - self.trainAcceleration * 1.2 * dt)
    end

    local nextProgress = train.progress + train.currentSpeed * dt

    if desiredStopDistance and nextProgress > desiredStopDistance then
        nextProgress = desiredStopDistance
        train.currentSpeed = 0
    end

    train.progress = nextProgress

    local tailDistance = train.progress - (self.carriageCount - 1) * (self.carriageLength + self.carriageGap)
    if tailDistance > train.track.fullPath.length + self.exitPadding then
        train.completed = true
        train.currentSpeed = 0
    end
end

function world:getTrainCarriagePositions(train)
    local positions = {}
    local carriageSpacing = self.carriageLength + self.carriageGap

    if train.completed then
        return positions
    end

    for carriageIndex = 1, self.carriageCount do
        local carriageDistance = train.progress - (carriageIndex - 1) * carriageSpacing
        local x, y, angle = pointOnPath(train.track.fullPath, carriageDistance)
        positions[#positions + 1] = {
            x = x,
            y = y,
            angle = angle,
        }
    end

    return positions
end

function world:updateCollisionState()
    local collisionRadius = math.min(self.carriageLength, 24)
    local collisionRadiusSquared = collisionRadius * collisionRadius

    self.collisionPoint = nil
    self.failed = false

    for firstIndex = 1, #self.trains - 1 do
        local firstTrain = self.trains[firstIndex]
        local firstCars = self:getTrainCarriagePositions(firstTrain)

        for secondIndex = firstIndex + 1, #self.trains do
            local secondTrain = self.trains[secondIndex]
            local secondCars = self:getTrainCarriagePositions(secondTrain)

            for _, firstCar in ipairs(firstCars) do
                for _, secondCar in ipairs(secondCars) do
                    if distanceSquared(firstCar.x, firstCar.y, secondCar.x, secondCar.y) <= collisionRadiusSquared then
                        self.failed = true
                        self.collisionPoint = {
                            x = (firstCar.x + secondCar.x) * 0.5,
                            y = (firstCar.y + secondCar.y) * 0.5,
                        }
                        return
                    end
                end
            end
        end
    end
end

function world:update(dt)
    if self.failed then
        return
    end

    self.switchPulse = math.max(0, self.switchPulse - dt)

    for _, train in ipairs(self.trains) do
        train.track = self.tracks[train.trackId]
        self:updateTrain(train, dt)
    end

    self:updateCollisionState()
end

function world:hasCollision()
    return self.failed
end

function world:isLevelComplete()
    for _, train in ipairs(self.trains) do
        if not train.completed then
            return false
        end
    end
    return true
end

function world:countCompletedTrains()
    local completedCount = 0
    for _, train in ipairs(self.trains) do
        if train.completed then
            completedCount = completedCount + 1
        end
    end
    return completedCount
end

function world:getActiveTrack()
    return self.tracks[self.activeTrackId]
end

function world:drawBranch(track)
    local graphics = love.graphics
    local isActive = track.id == self.activeTrackId
    local branchColor = isActive and track.color or track.darkColor
    local branchAlpha = isActive and 0.96 or 0.72
    local branchPoints = track.branchPath.points

    graphics.setLineStyle("rough")
    graphics.setColor(0.17, 0.21, 0.24, 0.95)
    graphics.setLineWidth(self.trackWidth + 10)
    graphics.line(
        branchPoints[1].x, branchPoints[1].y,
        branchPoints[2].x, branchPoints[2].y,
        branchPoints[3].x, branchPoints[3].y
    )

    graphics.setColor(branchColor[1], branchColor[2], branchColor[3], branchAlpha)
    graphics.setLineWidth(self.trackWidth)
    graphics.line(
        branchPoints[1].x, branchPoints[1].y,
        branchPoints[2].x, branchPoints[2].y,
        branchPoints[3].x, branchPoints[3].y
    )
end

function world:drawTrackSignal(track)
    local graphics = love.graphics
    local signalPoint = track.signalPoint
    local pulse = 0.5 + self.switchPulse * 2.5
    local signalRadius = 13 + pulse * 6

    graphics.setLineWidth(6)
    if track.id == self.activeTrackId then
        graphics.setColor(0.42, 0.92, 0.54, 1)
    else
        graphics.setColor(0.92, 0.26, 0.2, 1)
    end
    graphics.circle("fill", signalPoint.x, signalPoint.y, signalRadius)
end

function world:drawSharedTrack()
    local graphics = love.graphics
    local activeTrack = self:getActiveTrack()
    local sharedPoints = activeTrack.sharedPath.points

    graphics.setColor(0.17, 0.21, 0.24, 0.95)
    graphics.setLineWidth(self.sharedWidth + 10)
    graphics.line(sharedPoints[1].x, sharedPoints[1].y, sharedPoints[2].x, sharedPoints[2].y)

    graphics.setColor(activeTrack.color[1], activeTrack.color[2], activeTrack.color[3], 0.98)
    graphics.setLineWidth(self.sharedWidth)
    graphics.line(sharedPoints[1].x, sharedPoints[1].y, sharedPoints[2].x, sharedPoints[2].y)
end

function world:drawCrossing()
    local graphics = love.graphics
    local activeTrack = self:getActiveTrack()
    local pulse = 0.75 + self.switchPulse * 3
    local outerRadius = self.crossingRadius + pulse * 5
    local x = self.mergePoint.x
    local y = self.mergePoint.y

    graphics.setColor(0.06, 0.08, 0.1, 1)
    graphics.circle("fill", x, y, self.crossingRadius + 18)

    graphics.setColor(activeTrack.color[1], activeTrack.color[2], activeTrack.color[3], 0.18)
    graphics.circle("fill", x, y, outerRadius)

    graphics.setColor(activeTrack.color[1], activeTrack.color[2], activeTrack.color[3], 1)
    graphics.setLineWidth(4)
    graphics.circle("line", x, y, self.crossingRadius)

    graphics.push()
    graphics.translate(x, y)
    graphics.rotate(self.activeTrackId == 1 and -0.78 or 0.78)
    graphics.setColor(0.98, 0.99, 1, 1)
    graphics.rectangle("fill", -8, -26, 16, 52, 6, 6)
    graphics.setColor(activeTrack.color[1], activeTrack.color[2], activeTrack.color[3], 1)
    graphics.circle("fill", 0, -28, 11)
    graphics.pop()
end

function world:drawTrain(train)
    if train.completed then
        return
    end

    local graphics = love.graphics
    local carriages = self:getTrainCarriagePositions(train)
    local width = self.carriageLength
    local height = 18

    for carriageIndex = #carriages, 1, -1 do
        local carriage = carriages[carriageIndex]

        graphics.push()
        graphics.translate(carriage.x, carriage.y)
        graphics.rotate(carriage.angle)
        graphics.setColor(train.darkColor[1], train.darkColor[2], train.darkColor[3], 0.95)
        graphics.rectangle("fill", -width * 0.5, -height * 0.5, width, height, 5, 5)
        graphics.setColor(train.color[1], train.color[2], train.color[3], 1)
        graphics.rectangle("line", -width * 0.5, -height * 0.5, width, height, 5, 5)
        graphics.setColor(0.94, 0.96, 0.98, 0.9)
        graphics.rectangle("fill", -width * 0.22, -height * 0.28, width * 0.44, height * 0.56, 3, 3)
        graphics.pop()
    end
end

function world:drawCollisionMarker()
    if not self.collisionPoint then
        return
    end

    local graphics = love.graphics
    local x = self.collisionPoint.x
    local y = self.collisionPoint.y

    graphics.setColor(0.98, 0.28, 0.22, 0.95)
    graphics.setLineWidth(6)
    graphics.line(x - 24, y - 24, x + 24, y + 24)
    graphics.line(x - 24, y + 24, x + 24, y - 24)
    graphics.circle("line", x, y, 30)
end

function world:draw()
    local graphics = love.graphics

    graphics.setColor(0.08, 0.1, 0.12, 1)
    graphics.rectangle("fill", 0, 0, self.viewport.w, self.viewport.h)

    self:drawSharedTrack()
    self:drawBranch(self.tracks[1])
    self:drawBranch(self.tracks[2])
    self:drawCrossing()
    self:drawTrackSignal(self.tracks[1])
    self:drawTrackSignal(self.tracks[2])

    for _, train in ipairs(self.trains) do
        self:drawTrain(train)
    end

    self:drawCollisionMarker()
end

function world:getActiveTrackLabel()
    return self:getActiveTrack().label
end

return world
