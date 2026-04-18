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
        maxNorthDistance = 0,
        collisionRadius = 18,
        length = 58,
        width = 34,
        boostPadCooldown = 0,
        boostPadTimer = 0,
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
    self.maxNorthDistance = 0
    self.boostPadCooldown = 0
    self.boostPadTimer = 0
    self.skidMarks = {}
    self.skidTimer = 0
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

function car.update(self, intent, dt, tuning)
    updateSkidMarks(self, dt)
    self.boostPadCooldown = math.max(0, (self.boostPadCooldown or 0) - dt)
    self.boostPadTimer = math.max(0, (self.boostPadTimer or 0) - dt)

    local throttle = self.fuel > 0 and intent.throttle or 0
    local brake = intent.brake
    local steerTarget = intent.steer * tuning.maxSteerAngle

    self.steerAngle = approach(self.steerAngle, steerTarget, tuning.steerSpeed * dt)

    local forwardX, forwardY = car.getBasis(self.heading)
    local forwardSpeed = self.vx * forwardX + self.vy * forwardY

    local acceleration = 0
    if throttle > 0 then
        acceleration = acceleration + throttle * tuning.engineForce
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

    if self.boostPadTimer > 0 then
        forwardSpeed = math.min(
            forwardSpeed + tuning.boostPadAcceleration * dt,
            tuning.boostPadTargetSpeed
        )
    end

    local speedFactor = clamp(math.abs(forwardSpeed) / tuning.gripSpeedWindow, 0, 1)
    local rearGrip = tuning.rearGripLowSpeed
        + (tuning.rearGripHighSpeed - tuning.rearGripLowSpeed) * speedFactor

    if intent.handbrake then
        rearGrip = rearGrip * tuning.handbrakeGripMultiplier
    end

    local lateralBlend = math.min(rearGrip * dt, 0.96)
    lateralSpeed = lateralSpeed * (1 - lateralBlend)

    if math.abs(forwardSpeed) < tuning.turnSpeedFloor then
        self.angularVelocity = self.angularVelocity * math.max(0, 1 - tuning.angularDamping * dt)
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
