local levels = require("src.game.levels")

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

function world.new(viewportW, viewportH, levelIndex)
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
    self.crossingRadius = 40
    self.collisionPoint = nil
    self.failureReason = nil
    self.timeRemaining = nil
    self.levelIndex = clamp(levelIndex or 1, 1, #levels)
    self.level = levels[self.levelIndex]
    self.junctions = {}
    self.junctionOrder = {}
    self.trains = {}

    self:initializeLevel()

    return self
end

function world:getLevelCount()
    return #levels
end

function world:getLevel()
    return self.level
end

function world:buildTrack(branchDef, mergeX, mergeY, exitY)
    local startY = -120
    local bendY = mergeY - self.viewport.h * 0.22
    local startX = self.viewport.w * branchDef.startX
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
        id = branchDef.id,
        label = branchDef.label,
        color = branchDef.color,
        darkColor = branchDef.darkColor,
        branchPath = branchPath,
        sharedPath = sharedPath,
        fullPath = fullPath,
        branchLength = branchPath.length,
        signalPoint = { x = signalX, y = signalY },
        stopDistance = stopDistance,
        stopPoint = { x = stopX, y = stopY },
    }
end

function world:buildJunction(definition, existing)
    local mergeX = self.viewport.w * definition.mergeX
    local mergeY = self.viewport.h * definition.mergeY
    local exitY = self.viewport.h * (definition.exitY or 1.25)
    local controlDefinition = definition.control or { type = "direct" }

    local junction = {
        id = definition.id,
        label = controlDefinition.label or "Control",
        mergePoint = { x = mergeX, y = mergeY },
        crossingRadius = self.crossingRadius,
        activeBranch = existing and existing.activeBranch or definition.activeBranch or 1,
        control = {
            type = controlDefinition.type or "direct",
            delay = controlDefinition.delay or 0,
            target = controlDefinition.target or 0,
            decayDelay = controlDefinition.decayDelay or 0,
            decayInterval = controlDefinition.decayInterval or 0,
            armed = existing and existing.control.armed or false,
            remainingDelay = existing and existing.control.remainingDelay or 0,
            pumpCount = existing and existing.control.pumpCount or 0,
            decayHold = existing and existing.control.decayHold or 0,
            decayTimer = existing and existing.control.decayTimer or 0,
        },
        branches = {},
    }

    for branchIndex, branchDefinition in ipairs(definition.branches) do
        junction.branches[branchIndex] = self:buildTrack(branchDefinition, mergeX, mergeY, exitY)
    end

    return junction
end

function world:initializeLevel()
    local previousJunctions = self.junctions
    self.junctions = {}
    self.junctionOrder = {}

    for _, junctionDefinition in ipairs(self.level.junctions) do
        local existing = previousJunctions[junctionDefinition.id]
        local junction = self:buildJunction(junctionDefinition, existing)
        self.junctions[junction.id] = junction
        self.junctionOrder[#self.junctionOrder + 1] = junction
    end

    if #self.trains == 0 then
        for _, trainDefinition in ipairs(self.level.trains) do
            local junction = self.junctions[trainDefinition.junctionId]
            local branch = junction.branches[trainDefinition.branchIndex]
            self.trains[#self.trains + 1] = {
                id = trainDefinition.id,
                junctionId = trainDefinition.junctionId,
                branchIndex = trainDefinition.branchIndex,
                track = branch,
                progress = trainDefinition.progress,
                speed = self.trainSpeed * (trainDefinition.speedScale or 1),
                currentSpeed = 0,
                color = branch.color,
                darkColor = branch.darkColor,
                completed = false,
            }
        end
    else
        for _, train in ipairs(self.trains) do
            local junction = self.junctions[train.junctionId]
            local branch = junction.branches[train.branchIndex]
            train.track = branch
            train.color = branch.color
            train.darkColor = branch.darkColor
        end
    end

    self.timeRemaining = self.level.timeLimit
    self.collisionPoint = nil
    self.failureReason = nil
end

function world:resize(viewportW, viewportH)
    self.viewport.w = viewportW
    self.viewport.h = viewportH
    self.crossingRadius = math.max(34, math.min(viewportW, viewportH) * 0.045)
    self:initializeLevel()
end

function world:toggleJunction(junction)
    if junction.activeBranch == 1 then
        junction.activeBranch = 2
    else
        junction.activeBranch = 1
    end
end

function world:activateControl(junction)
    local control = junction.control

    if control.type == "direct" then
        self:toggleJunction(junction)
        return
    end

    if control.type == "delayed" then
        control.armed = true
        control.remainingDelay = control.delay
        return
    end

    if control.type == "pump" then
        control.pumpCount = math.min(control.target, control.pumpCount + 1)
        control.decayHold = control.decayDelay
        control.decayTimer = control.decayInterval

        if control.pumpCount >= control.target then
            self:toggleJunction(junction)
            control.pumpCount = 0
            control.decayHold = 0
            control.decayTimer = 0
        end
    end
end

function world:isCrossingHit(junction, x, y)
    return distanceSquared(x, y, junction.mergePoint.x, junction.mergePoint.y)
        <= junction.crossingRadius * junction.crossingRadius
end

function world:handleClick(x, y)
    for _, junction in ipairs(self.junctionOrder) do
        if self:isCrossingHit(junction, x, y) then
            self:activateControl(junction)
            return true
        end
    end

    return false
end

function world:updateControlState(junction, dt)
    local control = junction.control

    if control.type == "delayed" and control.armed then
        control.remainingDelay = math.max(0, control.remainingDelay - dt)
        if control.remainingDelay <= 0 then
            control.armed = false
            self:toggleJunction(junction)
        end
        return
    end

    if control.type == "pump" and control.pumpCount > 0 then
        if control.decayHold > 0 then
            control.decayHold = math.max(0, control.decayHold - dt)
            return
        end

        control.decayTimer = control.decayTimer - dt
        while control.decayTimer <= 0 and control.pumpCount > 0 do
            control.pumpCount = control.pumpCount - 1
            control.decayTimer = control.decayTimer + control.decayInterval
        end
    end
end

function world:getDesiredLeadDistance(train)
    if train.completed or train.progress >= train.track.branchLength then
        return nil
    end

    local junction = self.junctions[train.junctionId]
    if train.branchIndex ~= junction.activeBranch then
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

    for firstIndex = 1, #self.trains - 1 do
        local firstTrain = self.trains[firstIndex]
        local firstCars = self:getTrainCarriagePositions(firstTrain)

        for secondIndex = firstIndex + 1, #self.trains do
            local secondTrain = self.trains[secondIndex]
            local secondCars = self:getTrainCarriagePositions(secondTrain)

            for _, firstCar in ipairs(firstCars) do
                for _, secondCar in ipairs(secondCars) do
                    if distanceSquared(firstCar.x, firstCar.y, secondCar.x, secondCar.y) <= collisionRadiusSquared then
                        self.failureReason = "collision"
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
    if self.failureReason or self:isLevelComplete() then
        return
    end

    if self.timeRemaining then
        self.timeRemaining = math.max(0, self.timeRemaining - dt)
    end

    for _, junction in ipairs(self.junctionOrder) do
        self:updateControlState(junction, dt)
    end

    for _, train in ipairs(self.trains) do
        local junction = self.junctions[train.junctionId]
        train.track = junction.branches[train.branchIndex]
        self:updateTrain(train, dt)
    end

    self:updateCollisionState()

    if not self.failureReason and self.timeRemaining and self.timeRemaining <= 0 and not self:isLevelComplete() then
        self.failureReason = "timeout"
    end
end

function world:getFailureReason()
    return self.failureReason
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

function world:getActiveRouteSummary()
    local segments = {}

    for _, junction in ipairs(self.junctionOrder) do
        local activeBranch = junction.branches[junction.activeBranch]
        segments[#segments + 1] = string.format("%s: %s", junction.label, activeBranch.label)
    end

    return table.concat(segments, "  |  ")
end

function world:drawBranch(track, isActive)
    local graphics = love.graphics
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

function world:drawSharedTrack(junction)
    local graphics = love.graphics
    local activeTrack = junction.branches[junction.activeBranch]
    local sharedPoints = activeTrack.sharedPath.points

    graphics.setColor(0.17, 0.21, 0.24, 0.95)
    graphics.setLineWidth(self.sharedWidth + 10)
    graphics.line(sharedPoints[1].x, sharedPoints[1].y, sharedPoints[2].x, sharedPoints[2].y)

    graphics.setColor(activeTrack.color[1], activeTrack.color[2], activeTrack.color[3], 0.98)
    graphics.setLineWidth(self.sharedWidth)
    graphics.line(sharedPoints[1].x, sharedPoints[1].y, sharedPoints[2].x, sharedPoints[2].y)
end

function world:drawControlOverlay(junction)
    local graphics = love.graphics
    local control = junction.control
    local centerX = junction.mergePoint.x
    local centerY = junction.mergePoint.y
    local innerRadius = junction.crossingRadius - 10

    if control.type == "delayed" then
        local ratio = 0
        if control.armed and control.delay > 0 then
            ratio = 1 - (control.remainingDelay / control.delay)
        end

        graphics.setColor(0.99, 0.77, 0.32, 0.24)
        graphics.circle("fill", centerX, centerY, innerRadius)
        graphics.setColor(0.99, 0.77, 0.32, 1)
        graphics.setLineWidth(5)
        graphics.arc(
            "line",
            centerX,
            centerY,
            innerRadius + 4,
            -math.pi * 0.5,
            -math.pi * 0.5 + math.pi * 2 * ratio
        )

        love.graphics.setColor(0.05, 0.06, 0.08, 1)
        love.graphics.printf(
            control.armed and string.format("%.1f", control.remainingDelay) or "D",
            centerX - 20,
            centerY - 9,
            40,
            "center"
        )
        return
    end

    if control.type == "pump" then
        local ratio = control.target > 0 and (control.pumpCount / control.target) or 0
        local startAngle = math.pi * 1.16
        local endAngle = math.pi * 1.84
        local outerRadius = innerRadius + 10
        local cutoutRadius = innerRadius + 2
        local railRadius = (outerRadius + cutoutRadius) * 0.5
        local capRadius = (outerRadius - cutoutRadius) * 0.5
        local fillEndAngle = startAngle + (endAngle - startAngle) * ratio
        local startCapX = centerX + math.cos(startAngle) * railRadius
        local startCapY = centerY + math.sin(startAngle) * railRadius
        local endCapX = centerX + math.cos(endAngle) * railRadius
        local endCapY = centerY + math.sin(endAngle) * railRadius

        graphics.setColor(0.86, 0.16, 0.82, 0.22)
        graphics.arc("fill", centerX, centerY, outerRadius, startAngle, endAngle)
        graphics.setColor(0.06, 0.08, 0.1, 1)
        graphics.arc("fill", centerX, centerY, cutoutRadius, startAngle, endAngle)
        graphics.setColor(0.86, 0.16, 0.82, 0.22)
        graphics.circle("fill", startCapX, startCapY, capRadius)
        graphics.circle("fill", endCapX, endCapY, capRadius)

        if ratio > 0 then
            local fillCapX = centerX + math.cos(fillEndAngle) * railRadius
            local fillCapY = centerY + math.sin(fillEndAngle) * railRadius

            graphics.setColor(0.95, 0.12, 0.88, 1)
            graphics.arc("fill", centerX, centerY, outerRadius, startAngle, fillEndAngle)
            graphics.setColor(0.06, 0.08, 0.1, 1)
            graphics.arc("fill", centerX, centerY, cutoutRadius, startAngle, fillEndAngle)
            graphics.setColor(0.95, 0.12, 0.88, 1)
            graphics.circle("fill", startCapX, startCapY, capRadius)
            graphics.circle("fill", fillCapX, fillCapY, capRadius)
        end

        love.graphics.setColor(0.05, 0.06, 0.08, 1)
        love.graphics.printf(
            string.format("%d", control.pumpCount),
            centerX - 20,
            centerY - 9,
            40,
            "center"
        )
    end
end

function world:drawCrossing(junction)
    local graphics = love.graphics
    local activeTrack = junction.branches[junction.activeBranch]
    local pulse = 0.75 + 0.22 * math.sin(love.timer.getTime() * 4.2)
    local outerRadius = junction.crossingRadius + pulse * 4
    local x = junction.mergePoint.x
    local y = junction.mergePoint.y

    graphics.setColor(0.06, 0.08, 0.1, 1)
    graphics.circle("fill", x, y, junction.crossingRadius + 18)

    graphics.setColor(activeTrack.color[1], activeTrack.color[2], activeTrack.color[3], 0.18)
    graphics.circle("fill", x, y, outerRadius)

    graphics.setColor(activeTrack.color[1], activeTrack.color[2], activeTrack.color[3], 1)
    graphics.setLineWidth(4)
    graphics.circle("line", x, y, junction.crossingRadius)

    graphics.push()
    graphics.translate(x, y)
    graphics.rotate(junction.activeBranch == 1 and -0.78 or 0.78)
    graphics.setColor(0.98, 0.99, 1, 1)
    graphics.rectangle("fill", -8, -26, 16, 52, 6, 6)
    graphics.setColor(activeTrack.color[1], activeTrack.color[2], activeTrack.color[3], 1)
    graphics.circle("fill", 0, -28, 11)
    graphics.pop()

    self:drawControlOverlay(junction)
end

function world:drawTrackSignal(junction, branchIndex)
    local graphics = love.graphics
    local track = junction.branches[branchIndex]
    local signalPoint = track.signalPoint
    local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 6 + branchIndex)
    local signalRadius = 12 + pulse * 3

    graphics.setLineWidth(6)
    if branchIndex == junction.activeBranch then
        graphics.setColor(0.42, 0.92, 0.54, 1)
    else
        graphics.setColor(0.92, 0.26, 0.2, 1)
    end
    graphics.circle("fill", signalPoint.x, signalPoint.y, signalRadius)
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

    for _, junction in ipairs(self.junctionOrder) do
        self:drawSharedTrack(junction)
        self:drawBranch(junction.branches[1], junction.activeBranch == 1)
        self:drawBranch(junction.branches[2], junction.activeBranch == 2)
        self:drawCrossing(junction)
        self:drawTrackSignal(junction, 1)
        self:drawTrackSignal(junction, 2)
    end

    for _, train in ipairs(self.trains) do
        self:drawTrain(train)
    end

    self:drawCollisionMarker()
end

return world
