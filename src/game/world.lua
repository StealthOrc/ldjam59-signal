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

local function copyPoint(point)
    return { x = point.x, y = point.y }
end

local function copyColor(color)
    if not color then
        return { 0.8, 0.8, 0.8 }
    end

    return { color[1], color[2], color[3] }
end

local function darkerColor(color)
    return {
        color[1] * 0.42,
        color[2] * 0.42,
        color[3] * 0.42,
    }
end

local function denormalizePoints(points, viewportW, viewportH)
    local denormalized = {}

    for _, point in ipairs(points or {}) do
        denormalized[#denormalized + 1] = {
            x = viewportW * point.x,
            y = viewportH * point.y,
        }
    end

    return denormalized
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

    if not first then
        local point = path.points[1] or { x = 0, y = 0 }
        return point.x, point.y, 0
    end

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

local function flattenPoints(points)
    local flattened = {}
    for _, point in ipairs(points or {}) do
        flattened[#flattened + 1] = point.x
        flattened[#flattened + 1] = point.y
    end
    return flattened
end

local function combinePointLists(firstPoints, secondPoints)
    local combined = {}

    for _, point in ipairs(firstPoints or {}) do
        combined[#combined + 1] = copyPoint(point)
    end

    for pointIndex, point in ipairs(secondPoints or {}) do
        if pointIndex > 1 or #combined == 0 then
            combined[#combined + 1] = copyPoint(point)
        end
    end

    return combined
end

function world.new(viewportW, viewportH, levelSource)
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

    self.level = self:normalizeLevel(levelSource or {})

    self.junctions = {}
    self.junctionOrder = {}
    self.trains = {}

    self:initializeLevel()

    return self
end

function world:getLevelCount()
    return 0
end

function world:getLevel()
    return self.level
end

function world:normalizeJunctionDefinition(definition)
    if definition.inputs and definition.outputs then
        return definition
    end

    local mergeX = definition.mergeX or 0.5
    local mergeY = definition.mergeY or 0.5
    local exitY = definition.exitY or 1.25
    local startY = -120 / self.viewport.h
    local bendY = mergeY - 0.22
    local inputs = {}
    local outputs = {}

    for branchIndex, branch in ipairs(definition.branches or {}) do
        local color = copyColor(branch.color)
        inputs[#inputs + 1] = {
            id = branch.id or ("input_" .. branchIndex),
            label = branch.label or ("Input " .. branchIndex),
            color = color,
            darkColor = copyColor(branch.darkColor or darkerColor(color)),
            colors = { branch.id or ("input_" .. branchIndex) },
            inputPoints = branch.branchPoints or {
                { x = branch.startX or 0.5, y = startY },
                { x = branch.startX or 0.5, y = bendY },
                { x = mergeX, y = mergeY },
            },
        }
    end

    local firstBranch = (definition.branches or {})[1] or {}
    local outputColor = copyColor(firstBranch.color)
    outputs[1] = {
        id = firstBranch.id and (firstBranch.id .. "_output") or ((definition.id or "junction") .. "_output"),
        label = "Output 1",
        color = outputColor,
        darkColor = copyColor(firstBranch.darkColor or darkerColor(outputColor)),
        colors = {},
        adoptInputColor = true,
        outputPoints = firstBranch.sharedPoints or {
            { x = mergeX, y = mergeY },
            { x = mergeX, y = exitY },
        },
    }

    return {
        id = definition.id,
        label = definition.label,
        activeInputIndex = definition.activeBranch or 1,
        activeOutputIndex = 1,
        control = definition.control,
        inputs = inputs,
        outputs = outputs,
    }
end

function world:normalizeLevel(sourceLevel)
    local normalized = {
        id = sourceLevel.id,
        title = sourceLevel.title,
        description = sourceLevel.description,
        hint = sourceLevel.hint,
        footer = sourceLevel.footer,
        timeLimit = sourceLevel.timeLimit,
        junctions = {},
        trains = {},
    }

    for _, junctionDefinition in ipairs(sourceLevel.junctions or {}) do
        normalized.junctions[#normalized.junctions + 1] = self:normalizeJunctionDefinition(junctionDefinition)
    end

    for _, trainDefinition in ipairs(sourceLevel.trains or {}) do
        normalized.trains[#normalized.trains + 1] = {
            id = trainDefinition.id,
            junctionId = trainDefinition.junctionId,
            inputIndex = trainDefinition.inputIndex or trainDefinition.branchIndex or 1,
            selectedOutputIndex = trainDefinition.selectedOutputIndex,
            progress = trainDefinition.progress or 0,
            speedScale = trainDefinition.speedScale or 1,
            color = trainDefinition.color and copyColor(trainDefinition.color) or nil,
        }
    end

    return normalized
end

function world:buildInputTrack(trackDefinition)
    local color = copyColor(trackDefinition.color)
    local path = buildPolyline(denormalizePoints(trackDefinition.inputPoints, self.viewport.w, self.viewport.h))
    local signalDistance = math.max(path.length - (self.crossingRadius + 10), 0)
    local stopDistance = math.max(signalDistance - (self.carriageLength + 12), 0)
    local stopX, stopY = pointOnPath(path, stopDistance)
    local signalX, signalY = pointOnPath(path, signalDistance)

    return {
        id = trackDefinition.id,
        label = trackDefinition.label,
        colors = trackDefinition.colors or {},
        color = color,
        darkColor = copyColor(trackDefinition.darkColor or darkerColor(color)),
        path = path,
        signalPoint = { x = signalX, y = signalY },
        stopDistance = stopDistance,
        stopPoint = { x = stopX, y = stopY },
    }
end

function world:buildOutputTrack(trackDefinition)
    local color = copyColor(trackDefinition.color)
    return {
        id = trackDefinition.id,
        label = trackDefinition.label,
        colors = trackDefinition.colors or {},
        color = color,
        darkColor = copyColor(trackDefinition.darkColor or darkerColor(color)),
        adoptInputColor = trackDefinition.adoptInputColor == true,
        path = buildPolyline(denormalizePoints(trackDefinition.outputPoints, self.viewport.w, self.viewport.h)),
    }
end

function world:buildJunction(definition, existing)
    local controlDefinition = definition.control or { type = "direct" }
    local inputs = {}
    local outputs = {}

    for _, inputDefinition in ipairs(definition.inputs or {}) do
        inputs[#inputs + 1] = self:buildInputTrack(inputDefinition)
    end

    for _, outputDefinition in ipairs(definition.outputs or {}) do
        outputs[#outputs + 1] = self:buildOutputTrack(outputDefinition)
    end

    local mergePoint = { x = self.viewport.w * 0.5, y = self.viewport.h * 0.5 }
    if #inputs > 0 and #inputs[1].path.points > 0 then
        local lastPoint = inputs[1].path.points[#inputs[1].path.points]
        mergePoint = copyPoint(lastPoint)
    elseif #outputs > 0 and #outputs[1].path.points > 0 then
        mergePoint = copyPoint(outputs[1].path.points[1])
    end

    local junction = {
        id = definition.id,
        label = controlDefinition.label or definition.label or "Control",
        mergePoint = mergePoint,
        crossingRadius = self.crossingRadius,
        activeInputIndex = clamp(existing and existing.activeInputIndex or definition.activeInputIndex or 1, 1, math.max(1, #inputs)),
        activeOutputIndex = clamp(existing and existing.activeOutputIndex or definition.activeOutputIndex or 1, 1, math.max(1, #outputs)),
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
        inputs = inputs,
        outputs = outputs,
        fullTrackCache = {},
    }

    return junction
end

function world:getCombinedTrack(junction, inputIndex, outputIndex)
    inputIndex = clamp(inputIndex or 1, 1, math.max(1, #junction.inputs))
    outputIndex = clamp(outputIndex or 1, 1, math.max(1, #junction.outputs))

    junction.fullTrackCache[inputIndex] = junction.fullTrackCache[inputIndex] or {}
    local cached = junction.fullTrackCache[inputIndex][outputIndex]
    if cached then
        return cached
    end

    local inputTrack = junction.inputs[inputIndex]
    local outputTrack = junction.outputs[outputIndex]
    local fullPath = buildPolyline(combinePointLists(inputTrack.path.points, outputTrack.path.points))

    cached = {
        fullPath = fullPath,
        inputTrack = inputTrack,
        outputTrack = outputTrack,
    }
    junction.fullTrackCache[inputIndex][outputIndex] = cached
    return cached
end

function world:initializeLevel()
    local previousJunctions = self.junctions
    self.junctions = {}
    self.junctionOrder = {}

    for _, junctionDefinition in ipairs(self.level.junctions or {}) do
        local existing = previousJunctions[junctionDefinition.id]
        local junction = self:buildJunction(junctionDefinition, existing)
        self.junctions[junction.id] = junction
        self.junctionOrder[#self.junctionOrder + 1] = junction
    end

    if #self.trains == 0 then
        for _, trainDefinition in ipairs(self.level.trains or {}) do
            local junction = self.junctions[trainDefinition.junctionId]
            if junction then
                local inputIndex = clamp(trainDefinition.inputIndex or 1, 1, math.max(1, #junction.inputs))
                local selectedOutputIndex = trainDefinition.selectedOutputIndex
                local baseColor = trainDefinition.color or junction.inputs[inputIndex].color

                self.trains[#self.trains + 1] = {
                    id = trainDefinition.id,
                    junctionId = trainDefinition.junctionId,
                    inputIndex = inputIndex,
                    selectedOutputIndex = selectedOutputIndex and clamp(selectedOutputIndex, 1, math.max(1, #junction.outputs)) or nil,
                    progress = trainDefinition.progress,
                    speed = self.trainSpeed * (trainDefinition.speedScale or 1),
                    currentSpeed = 0,
                    color = copyColor(baseColor),
                    darkColor = darkerColor(baseColor),
                    completed = false,
                    track = self:getCombinedTrack(junction, inputIndex, selectedOutputIndex or junction.activeOutputIndex),
                }
            end
        end
    else
        for _, train in ipairs(self.trains) do
            local junction = self.junctions[train.junctionId]
            if junction then
                train.inputIndex = clamp(train.inputIndex or 1, 1, math.max(1, #junction.inputs))
                if train.selectedOutputIndex then
                    train.selectedOutputIndex = clamp(train.selectedOutputIndex, 1, math.max(1, #junction.outputs))
                end
                train.track = self:getCombinedTrack(junction, train.inputIndex, train.selectedOutputIndex or junction.activeOutputIndex)
            end
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
    self.level = self:normalizeLevel(self.level)
    self:initializeLevel()
end

function world:cycleInput(junction)
    if #junction.inputs <= 1 then
        junction.activeInputIndex = 1
        return
    end

    junction.activeInputIndex = junction.activeInputIndex + 1
    if junction.activeInputIndex > #junction.inputs then
        junction.activeInputIndex = 1
    end
end

function world:cycleOutput(junction, direction)
    if #junction.outputs <= 1 then
        junction.activeOutputIndex = 1
        return
    end

    junction.activeOutputIndex = junction.activeOutputIndex + direction
    if junction.activeOutputIndex < 1 then
        junction.activeOutputIndex = #junction.outputs
    elseif junction.activeOutputIndex > #junction.outputs then
        junction.activeOutputIndex = 1
    end
end

function world:activateControl(junction)
    local control = junction.control

    if control.type == "direct" then
        self:cycleInput(junction)
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
            self:cycleInput(junction)
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

function world:isOutputSelectorHit(junction, x, y)
    if #junction.outputs <= 1 then
        return false
    end

    return distanceSquared(x, y, junction.mergePoint.x, junction.mergePoint.y + 36) <= 15 * 15
end

function world:handleClick(x, y, button)
    for _, junction in ipairs(self.junctionOrder) do
        if self:isOutputSelectorHit(junction, x, y) then
            if button == 2 then
                self:cycleOutput(junction, -1)
            else
                self:cycleOutput(junction, 1)
            end
            return true
        end

        if button == 1 and self:isCrossingHit(junction, x, y) then
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
            self:cycleInput(junction)
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
    local junction = self.junctions[train.junctionId]
    if not junction or train.completed then
        return nil
    end

    local inputTrack = junction.inputs[train.inputIndex]
    if not inputTrack or train.progress >= inputTrack.path.length then
        return nil
    end

    if train.inputIndex ~= junction.activeInputIndex then
        return inputTrack.stopDistance
    end

    return nil
end

function world:latchTrainOutput(train)
    if train.selectedOutputIndex then
        return
    end

    local junction = self.junctions[train.junctionId]
    if not junction then
        return
    end

    train.selectedOutputIndex = clamp(junction.activeOutputIndex, 1, math.max(1, #junction.outputs))
end

function world:getTrainTrack(train)
    local junction = self.junctions[train.junctionId]
    if not junction then
        return nil
    end

    return self:getCombinedTrack(junction, train.inputIndex, train.selectedOutputIndex or junction.activeOutputIndex)
end

function world:updateTrain(train, dt)
    if train.completed then
        return
    end

    local junction = self.junctions[train.junctionId]
    local inputTrack = junction and junction.inputs[train.inputIndex] or nil
    if not junction or not inputTrack then
        train.completed = true
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

    if not train.selectedOutputIndex and nextProgress >= inputTrack.path.length and train.inputIndex == junction.activeInputIndex then
        self:latchTrainOutput(train)
    end

    train.progress = nextProgress
    train.track = self:getTrainTrack(train)

    if not train.track then
        train.completed = true
        return
    end

    local tailDistance = train.progress - (self.carriageCount - 1) * (self.carriageLength + self.carriageGap)
    if tailDistance > train.track.fullPath.length + self.exitPadding then
        train.completed = true
        train.currentSpeed = 0
    end
end

function world:getTrainCarriagePositions(train)
    local positions = {}
    local carriageSpacing = self.carriageLength + self.carriageGap
    local track = train.track or self:getTrainTrack(train)

    if train.completed or not track then
        return positions
    end

    for carriageIndex = 1, self.carriageCount do
        local carriageDistance = train.progress - (carriageIndex - 1) * carriageSpacing
        local x, y, angle = pointOnPath(track.fullPath, carriageDistance)
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
        local activeInput = junction.inputs[junction.activeInputIndex]
        local activeOutput = junction.outputs[junction.activeOutputIndex]
        segments[#segments + 1] = string.format(
            "%s: %s -> %s",
            junction.label,
            activeInput and activeInput.label or ("Input " .. tostring(junction.activeInputIndex)),
            activeOutput and activeOutput.label or ("Output " .. tostring(junction.activeOutputIndex))
        )
    end

    return table.concat(segments, "  |  ")
end

function world:getOutputDisplayColor(junction, outputIndex, isActive)
    local outputTrack = junction.outputs[outputIndex]
    if not outputTrack then
        return { 0.4, 0.4, 0.4 }, { 0.18, 0.18, 0.18 }
    end

    if outputTrack.adoptInputColor then
        local inputTrack = junction.inputs[junction.activeInputIndex]
        if inputTrack then
            return isActive and inputTrack.color or inputTrack.darkColor, inputTrack.darkColor
        end
    end

    return isActive and outputTrack.color or outputTrack.darkColor, outputTrack.darkColor
end

function world:drawInputTrack(track, isActive)
    local graphics = love.graphics
    local trackColor = isActive and track.color or track.darkColor
    local trackAlpha = isActive and 0.96 or 0.72
    local points = flattenPoints(track.path.points)

    graphics.setLineStyle("rough")
    graphics.setColor(0.17, 0.21, 0.24, 0.95)
    graphics.setLineWidth(self.trackWidth + 10)
    graphics.line(points)

    graphics.setColor(trackColor[1], trackColor[2], trackColor[3], trackAlpha)
    graphics.setLineWidth(self.trackWidth)
    graphics.line(points)
end

function world:drawOutputTrack(junction, outputIndex, isActive)
    local graphics = love.graphics
    local outputTrack = junction.outputs[outputIndex]
    local color = self:getOutputDisplayColor(junction, outputIndex, isActive)
    local points = flattenPoints(outputTrack.path.points)

    graphics.setColor(0.17, 0.21, 0.24, 0.95)
    graphics.setLineWidth(self.sharedWidth + 10)
    graphics.line(points)

    graphics.setColor(color[1], color[2], color[3], isActive and 0.98 or 0.7)
    graphics.setLineWidth(self.sharedWidth)
    graphics.line(points)
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
        local outerRadius = innerRadius + 12
        local cutoutRadius = innerRadius + 1
        local railRadius = (outerRadius + cutoutRadius) * 0.5
        local capRadius = (outerRadius - cutoutRadius) * 0.5
        local fillEndAngle = startAngle + (endAngle - startAngle) * ratio

        local function drawPumpBand(segmentStart, segmentEnd, color)
            local segmentStartCapX = centerX + math.cos(segmentStart) * railRadius
            local segmentStartCapY = centerY + math.sin(segmentStart) * railRadius
            local segmentEndCapX = centerX + math.cos(segmentEnd) * railRadius
            local segmentEndCapY = centerY + math.sin(segmentEnd) * railRadius

            graphics.stencil(function()
                graphics.arc("fill", centerX, centerY, outerRadius, segmentStart, segmentEnd)
                graphics.circle("fill", segmentStartCapX, segmentStartCapY, capRadius)
                graphics.circle("fill", segmentEndCapX, segmentEndCapY, capRadius)
            end, "replace", 1)

            graphics.stencil(function()
                graphics.arc("fill", centerX, centerY, cutoutRadius, segmentStart, segmentEnd)
            end, "replace", 0, true)

            graphics.setStencilTest("greater", 0)
            graphics.setColor(color[1], color[2], color[3], color[4])
            graphics.circle("fill", centerX, centerY, outerRadius + capRadius)
            graphics.setStencilTest()
        end

        drawPumpBand(startAngle, endAngle, { 0.86, 0.16, 0.82, 0.22 })

        if ratio > 0 then
            drawPumpBand(startAngle, fillEndAngle, { 0.95, 0.12, 0.88, 1 })
        end

        love.graphics.setColor(0.05, 0.06, 0.08, 1)
        love.graphics.printf(
            string.format("%d%%", math.floor(ratio * 100 + 0.5)),
            centerX - 24,
            centerY - 9,
            48,
            "center"
        )
    end
end

function world:drawCrossing(junction)
    local graphics = love.graphics
    local activeInput = junction.inputs[junction.activeInputIndex]
    local activeOutputColor = self:getOutputDisplayColor(junction, junction.activeOutputIndex, true)
    local pulse = 0.75 + 0.22 * math.sin(love.timer.getTime() * 4.2)
    local outerRadius = junction.crossingRadius + pulse * 4
    local x = junction.mergePoint.x
    local y = junction.mergePoint.y

    graphics.setColor(0.06, 0.08, 0.1, 1)
    graphics.circle("fill", x, y, junction.crossingRadius + 18)

    graphics.setColor(activeOutputColor[1], activeOutputColor[2], activeOutputColor[3], 0.18)
    graphics.circle("fill", x, y, outerRadius)

    graphics.setColor(activeOutputColor[1], activeOutputColor[2], activeOutputColor[3], 1)
    graphics.setLineWidth(4)
    graphics.circle("line", x, y, junction.crossingRadius)

    if activeInput and #activeInput.path.points >= 2 then
        local points = activeInput.path.points
        local angle = angleBetweenPoints(points[#points - 1], points[#points]) - math.pi * 0.5

        graphics.push()
        graphics.translate(x, y)
        graphics.rotate(angle)
        graphics.setColor(0.98, 0.99, 1, 1)
        graphics.rectangle("fill", -8, -26, 16, 52, 6, 6)
        graphics.setColor(activeInput.color[1], activeInput.color[2], activeInput.color[3], 1)
        graphics.circle("fill", 0, -28, 11)
        graphics.pop()
    end

    if #junction.outputs > 1 then
        local selectorY = y + 36
        graphics.setColor(0.08, 0.1, 0.13, 1)
        graphics.circle("fill", x, selectorY, 15)
        graphics.setColor(0.99, 0.78, 0.32, 1)
        graphics.circle("line", x, selectorY, 15)
        graphics.setColor(0.97, 0.98, 1, 1)
        graphics.printf(tostring(junction.activeOutputIndex), x - 14, selectorY - 7, 28, "center")
    end

    self:drawControlOverlay(junction)
end

function world:drawTrackSignal(junction, inputIndex)
    local graphics = love.graphics
    local track = junction.inputs[inputIndex]
    local signalPoint = track.signalPoint
    local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 6 + inputIndex)
    local signalRadius = 12 + pulse * 3

    graphics.setLineWidth(6)
    if inputIndex == junction.activeInputIndex then
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
        for outputIndex = 1, #junction.outputs do
            self:drawOutputTrack(junction, outputIndex, outputIndex == junction.activeOutputIndex)
        end

        for inputIndex = 1, #junction.inputs do
            self:drawInputTrack(junction.inputs[inputIndex], inputIndex == junction.activeInputIndex)
        end

        self:drawCrossing(junction)

        for inputIndex = 1, #junction.inputs do
            self:drawTrackSignal(junction, inputIndex)
        end
    end

    for _, train in ipairs(self.trains) do
        self:drawTrain(train)
    end

    self:drawCollisionMarker()
end

return world
