local car = {}

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function approach(current, target, amount)
    if current < target then
        return math.min(current + amount, target)
    end
    return math.max(current - amount, target)
end

local function length(x, y)
    return math.sqrt(x * x + y * y)
end

local function wrapAngle(angle)
    if angle > math.pi then
        angle = angle - math.pi * 2
    elseif angle < -math.pi then
        angle = angle + math.pi * 2
    end
    return angle
end

local function getGearBand(tuning, gear)
    local bands = tuning.gearBands or {}
    local safeGear = clamp(gear or 1, 1, math.max(#bands, 1))
    return bands[safeGear] or {
        minKmh = 0,
        maxKmh = tuning.maxForwardSpeedKmh or 120,
        driveMultiplier = 1,
    }
end

local function syncGearMetrics(self, tuning)
    local gearBand = getGearBand(tuning, self.currentGear)
    local span = math.max(gearBand.maxKmh - gearBand.minKmh, 0.01)

    self.currentGearMinKmh = gearBand.minKmh
    self.currentGearMaxKmh = gearBand.maxKmh
    self.currentGearDriveMultiplier = gearBand.driveMultiplier
    self.gearProgress = clamp((self.forwardSpeedKmh - gearBand.minKmh) / span, 0, 1)
end

local function beginShift(self, targetGear, tuning)
    if targetGear == self.currentGear then
        return
    end

    self.isShifting = true
    self.targetGear = clamp(targetGear, 1, self.gearCount)
    self.shiftTimer = tuning.shiftDuration
    self.shiftStartedThisFrame = true
end

function car.getBasis(heading)
    local forwardX = math.sin(heading)
    local forwardY = -math.cos(heading)
    local rightX = math.cos(heading)
    local rightY = math.sin(heading)
    return forwardX, forwardY, rightX, rightY
end

function car.new(tuning)
    return {
        x = 0,
        y = 0,
        vx = 0,
        vy = 0,
        heading = 0,
        steerAngle = 0,
        angularVelocity = 0,
        fuel = tuning.fuelCapacity,
        speed = 0,
        slip = 0,
        driftActive = false,
        maxNorthDistance = 0,
        collisionRadius = 18,
        length = 58,
        width = 34,
        boostPadCooldown = 0,
        boostPadTimer = 0,
        boostSignalTowerIndex = nil,
        gearCount = tuning.gearCount or tuning.baseGearCount or 5,
        currentGear = 1,
        targetGear = 1,
        isShifting = false,
        shiftTimer = 0,
        shiftLockTimer = 0,
        shiftStartedThisFrame = false,
        shiftFinishedThisFrame = false,
        shiftFlashTimer = 0,
        gearProgress = 0,
        currentGearMinKmh = 0,
        currentGearMaxKmh = 0,
        currentGearDriveMultiplier = 1,
        forwardSpeedKmh = 0,
        throttleDemand = 0,
        skidMarks = {},
        skidTimer = 0,
    }
end

function car.reset(self, tuning)
    self.x = 0
    self.y = 0
    self.vx = 0
    self.vy = 0
    self.heading = 0
    self.steerAngle = 0
    self.angularVelocity = 0
    self.fuel = tuning.fuelCapacity
    self.speed = 0
    self.slip = 0
    self.driftActive = false
    self.maxNorthDistance = 0
    self.boostPadCooldown = 0
    self.boostPadTimer = 0
    self.boostSignalTowerIndex = nil
    self.gearCount = tuning.gearCount or tuning.baseGearCount or 5
    self.currentGear = 1
    self.targetGear = 1
    self.isShifting = false
    self.shiftTimer = 0
    self.shiftLockTimer = 0
    self.shiftStartedThisFrame = false
    self.shiftFinishedThisFrame = false
    self.shiftFlashTimer = 0
    self.gearProgress = 0
    self.currentGearMinKmh = 0
    self.currentGearMaxKmh = 0
    self.currentGearDriveMultiplier = 1
    self.forwardSpeedKmh = 0
    self.throttleDemand = 0
    self.skidMarks = {}
    self.skidTimer = 0
    syncGearMetrics(self, tuning)
end

local function updateSkidMarks(self, dt)
    for index = #self.skidMarks, 1, -1 do
        local mark = self.skidMarks[index]
        mark.life = mark.life - dt
        if mark.life <= 0 then
            table.remove(self.skidMarks, index)
        end
    end
end

local function addSkidMarks(self, tuning, forwardX, forwardY, rightX, rightY)
    local rearX = self.x - forwardX * (self.length * 0.24)
    local rearY = self.y - forwardY * (self.length * 0.24)
    local offsetX = rightX * (self.width * 0.22)
    local offsetY = rightY * (self.width * 0.22)

    table.insert(self.skidMarks, {
        x = rearX - offsetX,
        y = rearY - offsetY,
        size = tuning.skidRadius,
        life = tuning.skidLife,
        maxLife = tuning.skidLife,
    })

    table.insert(self.skidMarks, {
        x = rearX + offsetX,
        y = rearY + offsetY,
        size = tuning.skidRadius,
        life = tuning.skidLife,
        maxLife = tuning.skidLife,
    })
end

local function updateGearbox(self, throttle, brake, forwardSpeedKmh, dt, tuning)
    self.shiftStartedThisFrame = false
    self.shiftFinishedThisFrame = false
    self.shiftFlashTimer = math.max(0, (self.shiftFlashTimer or 0) - dt)
    self.shiftLockTimer = math.max(0, (self.shiftLockTimer or 0) - dt)
    self.gearCount = tuning.gearCount or self.gearCount
    self.currentGear = clamp(self.currentGear, 1, self.gearCount)
    self.targetGear = clamp(self.targetGear, 1, self.gearCount)
    self.forwardSpeedKmh = math.max(0, forwardSpeedKmh)
    self.throttleDemand = throttle

    if self.isShifting then
        self.shiftTimer = math.max(0, self.shiftTimer - dt)
        if self.shiftTimer <= 0 then
            self.isShifting = false
            self.currentGear = self.targetGear
            self.shiftFinishedThisFrame = true
            self.shiftFlashTimer = tuning.shiftFlashDuration
            self.shiftLockTimer = tuning.postShiftLockDuration
        end
        syncGearMetrics(self, tuning)
        return
    end

    if self.forwardSpeedKmh <= tuning.neutralReturnKmh and throttle <= 0 and brake <= 0 then
        self.currentGear = 1
        self.targetGear = 1
        syncGearMetrics(self, tuning)
        return
    end

    syncGearMetrics(self, tuning)

    if self.shiftLockTimer <= 0
        and throttle >= tuning.upshiftThrottleThreshold
        and self.currentGear < self.gearCount
        and self.forwardSpeedKmh >= self.currentGearMaxKmh + tuning.upshiftBufferKmh then
        beginShift(self, self.currentGear + 1, tuning)
        syncGearMetrics(self, tuning)
        return
    end

    local currentGearSpan = math.max(self.currentGearMaxKmh - self.currentGearMinKmh, 0)
    local downshiftMargin = tuning.downshiftHysteresisKmh
    if throttle >= tuning.throttleHoldGearThreshold then
        downshiftMargin = math.max(downshiftMargin, currentGearSpan * tuning.throttleDownshiftSpanFactor)
    end

    if self.currentGear > 1
        and self.shiftLockTimer <= 0
        and self.forwardSpeedKmh <= math.max(0, self.currentGearMinKmh - downshiftMargin) then
        beginShift(self, self.currentGear - 1, tuning)
        syncGearMetrics(self, tuning)
        return
    end

    syncGearMetrics(self, tuning)
end

local function shouldEnterDrift(self, intent, forwardSpeedKmh, tuning)
    if forwardSpeedKmh < tuning.driftMinSpeedKmh then
        return false
    end

    if not intent.handbrake then
        return false
    end

    local steerAmount = math.abs(intent.steer)
    return steerAmount >= tuning.driftHandbrakeSteerThreshold
end

function car.update(self, intent, dt, tuning)
    updateSkidMarks(self, dt)
    self.boostPadCooldown = math.max(0, (self.boostPadCooldown or 0) - dt)
    self.boostPadTimer = math.max(0, (self.boostPadTimer or 0) - dt)

    local throttle = self.fuel > 0 and intent.throttle or 0
    local brake = intent.brake
    local currentSpeedKmh = self.speed * tuning.speedUnitsToKmhFactor
    local speedSteerBlend = clamp(
        (currentSpeedKmh - tuning.highSpeedSteerStartKmh)
            / math.max(1, tuning.highSpeedSteerEndKmh - tuning.highSpeedSteerStartKmh),
        0,
        1
    )
    local steerAngleFactor = 1 + (tuning.highSpeedSteerAngleFactor - 1) * speedSteerBlend
    local steerSpeedFactor = 1 + (tuning.highSpeedSteerSpeedFactor - 1) * speedSteerBlend
    local steerInput = intent.steer
    local steerSpeed = tuning.steerSpeed
    if intent.usingMouse then
        steerSpeed = tuning.mouseSteerSpeed
    elseif not intent.usingController then
        steerInput = steerInput * tuning.keyboardSteerLimit
        steerSpeed = tuning.keyboardSteerSpeed
    end
    local steerTarget = steerInput * tuning.maxSteerAngle * steerAngleFactor
    steerSpeed = steerSpeed * steerSpeedFactor

    self.steerAngle = approach(self.steerAngle, steerTarget, steerSpeed * dt)

    local forwardX, forwardY = car.getBasis(self.heading)
    local forwardSpeed = self.vx * forwardX + self.vy * forwardY
    local forwardSpeedKmh = math.max(0, forwardSpeed * tuning.speedUnitsToKmhFactor)

    updateGearbox(self, throttle, brake, forwardSpeedKmh, dt, tuning)

    local driveMultiplier = self.currentGearDriveMultiplier
    if self.isShifting then
        driveMultiplier = driveMultiplier * tuning.shiftDriveMultiplier
    end

    local acceleration = 0
    if throttle > 0 then
        acceleration = acceleration + throttle * tuning.engineForce * driveMultiplier
    end

    if brake > 0 then
        if forwardSpeed > tuning.reverseThreshold then
            acceleration = acceleration - brake * tuning.brakeForce
        else
            acceleration = acceleration - brake * tuning.reverseForce
        end
    end

    self.vx = self.vx + forwardX * acceleration * dt
    self.vy = self.vy + forwardY * acceleration * dt

    local rawSpeed = length(self.vx, self.vy)
    if rawSpeed > 0 then
        local drag = tuning.rollingResistance + rawSpeed * tuning.drag
        if intent.handbrake then
            drag = drag + tuning.handbrakeDrag
        end

        local dragStep = math.min(drag * dt, rawSpeed)
        self.vx = self.vx - (self.vx / rawSpeed) * dragStep
        self.vy = self.vy - (self.vy / rawSpeed) * dragStep
    end

    if throttle > 0 then
        self.fuel = self.fuel - throttle * tuning.fuelBurnThrottle * dt
    end

    if rawSpeed > tuning.coastFuelThreshold then
        self.fuel = self.fuel - tuning.fuelBurnRolling * dt
    end

    self.fuel = clamp(self.fuel, 0, tuning.fuelCapacity)

    forwardX, forwardY = car.getBasis(self.heading)
    forwardSpeed = self.vx * forwardX + self.vy * forwardY

    local desiredYaw = 0
    if math.abs(forwardSpeed) > tuning.turnSpeedFloor then
        desiredYaw = (forwardSpeed / tuning.wheelBase) * math.tan(self.steerAngle)
    end

    local yawBlend = math.min(tuning.yawResponse * dt, 1)
    self.angularVelocity = self.angularVelocity + (desiredYaw - self.angularVelocity) * yawBlend
    self.heading = wrapAngle(self.heading + self.angularVelocity * dt)

    local newForwardX, newForwardY, rightX, rightY = car.getBasis(self.heading)
    forwardSpeed = self.vx * newForwardX + self.vy * newForwardY
    local lateralSpeed = self.vx * rightX + self.vy * rightY

    if not self.driftActive and shouldEnterDrift(self, intent, self.forwardSpeedKmh, tuning) then
        self.driftActive = true
    end

    if self.boostPadTimer > 0 then
        forwardSpeed = math.min(
            forwardSpeed + tuning.boostPadAcceleration * dt,
            tuning.boostPadTargetSpeed
        )
    end

    local speedFactor = clamp(math.abs(forwardSpeed) / tuning.gripSpeedWindow, 0, 1)
    local rearGripLow = self.driftActive and tuning.rearGripLowSpeed or tuning.plantedRearGripLowSpeed
    local rearGripHigh = self.driftActive and tuning.rearGripHighSpeed or tuning.plantedRearGripHighSpeed
    local rearGrip = rearGripLow + (rearGripHigh - rearGripLow) * speedFactor

    if intent.handbrake then
        rearGrip = rearGrip * tuning.handbrakeGripMultiplier
    end

    local lateralBlend = math.min(rearGrip * dt, 0.96)
    lateralSpeed = lateralSpeed * (1 - lateralBlend)

    if math.abs(forwardSpeed) < tuning.turnSpeedFloor then
        self.angularVelocity = self.angularVelocity * math.max(0, 1 - tuning.angularDamping * dt)
    end

    if self.driftActive then
        local steerRecovered = math.abs(intent.steer) <= tuning.driftRecoverSteerThreshold
        local slipRecovered = math.abs(lateralSpeed) <= tuning.driftRecoverSlipThreshold
        local yawRecovered = math.abs(self.angularVelocity) <= tuning.driftRecoverAngularVelocity
        if not intent.handbrake and steerRecovered and slipRecovered and yawRecovered then
            self.driftActive = false
        end
    end

    local forwardSpeedCap = tuning.maxForwardSpeed
    if self.boostPadTimer > 0 then
        forwardSpeedCap = tuning.boostPadTargetSpeed
    end

    forwardSpeed = clamp(forwardSpeed, -tuning.maxReverseSpeed, forwardSpeedCap)
    self.vx = newForwardX * forwardSpeed + rightX * lateralSpeed
    self.vy = newForwardY * forwardSpeed + rightY * lateralSpeed

    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    self.speed = length(self.vx, self.vy)
    self.forwardSpeedKmh = math.max(0, (self.vx * newForwardX + self.vy * newForwardY) * tuning.speedUnitsToKmhFactor)
    syncGearMetrics(self, tuning)
    self.slip = math.abs(lateralSpeed)
    self.maxNorthDistance = math.max(self.maxNorthDistance, -self.y)

    if self.slip > tuning.skidThreshold and self.speed > tuning.skidMinSpeed then
        self.skidTimer = self.skidTimer - dt
        if self.skidTimer <= 0 then
            addSkidMarks(self, tuning, newForwardX, newForwardY, rightX, rightY)
            self.skidTimer = tuning.skidInterval
        end
    else
        self.skidTimer = 0
    end
end

function car.drawSkids(self)
    local graphics = love.graphics

    for _, mark in ipairs(self.skidMarks) do
        local alpha = 0.16 * (mark.life / mark.maxLife)
        graphics.setColor(0.03, 0.03, 0.03, alpha)
        graphics.circle("fill", mark.x, mark.y, mark.size)
    end
end

function car.draw(self)
    local graphics = love.graphics

    graphics.push()
    graphics.translate(self.x, self.y)
    graphics.rotate(self.heading)

    graphics.setColor(0.14, 0.14, 0.16, 0.75)
    graphics.rectangle("fill", -self.width * 0.42, -self.length * 0.42, self.width * 0.84, self.length * 0.9, 12, 12)

    graphics.setColor(0.87, 0.21, 0.14)
    graphics.polygon(
        "fill",
        -self.width * 0.48, self.length * 0.42,
        -self.width * 0.56, -self.length * 0.12,
        -self.width * 0.34, -self.length * 0.52,
        self.width * 0.34, -self.length * 0.52,
        self.width * 0.56, -self.length * 0.12,
        self.width * 0.48, self.length * 0.42
    )

    graphics.setColor(0.97, 0.64, 0.2)
    graphics.polygon(
        "fill",
        -self.width * 0.24, -self.length * 0.16,
        -self.width * 0.18, -self.length * 0.44,
        self.width * 0.18, -self.length * 0.44,
        self.width * 0.24, -self.length * 0.16
    )

    graphics.setColor(0.08, 0.08, 0.09)
    graphics.rectangle("fill", -self.width * 0.36, self.length * 0.08, self.width * 0.18, self.length * 0.22, 4, 4)
    graphics.rectangle("fill", self.width * 0.18, self.length * 0.08, self.width * 0.18, self.length * 0.22, 4, 4)

    graphics.push()
    graphics.translate(-self.width * 0.3, -self.length * 0.23)
    graphics.rotate(self.steerAngle)
    graphics.rectangle("fill", -self.width * 0.08, -self.length * 0.11, self.width * 0.16, self.length * 0.22, 4, 4)
    graphics.pop()

    graphics.push()
    graphics.translate(self.width * 0.3, -self.length * 0.23)
    graphics.rotate(self.steerAngle)
    graphics.rectangle("fill", -self.width * 0.08, -self.length * 0.11, self.width * 0.16, self.length * 0.22, 4, 4)
    graphics.pop()

    graphics.setColor(1, 0.93, 0.68, 0.9)
    graphics.circle("fill", -self.width * 0.23, -self.length * 0.5, 3.5)
    graphics.circle("fill", self.width * 0.23, -self.length * 0.5, 3.5)

    graphics.setColor(0.9, 0.18, 0.1, 0.9)
    graphics.circle("fill", -self.width * 0.21, self.length * 0.45, 3)
    graphics.circle("fill", self.width * 0.21, self.length * 0.45, 3)

    graphics.pop()
end

return car
