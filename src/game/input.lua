local input = {
    deadzone = 0.2,
}

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function applyDeadzone(value, deadzone)
    local magnitude = math.abs(value)
    if magnitude <= deadzone then
        return 0
    end

    local normalized = (magnitude - deadzone) / (1 - deadzone)
    return normalized * (value < 0 and -1 or 1)
end

function input.getActiveJoystick()
    local joysticks = love.joystick.getJoysticks()
    for _, joystick in ipairs(joysticks) do
        if joystick:isGamepad() then
            return joystick
        end
    end
    return joysticks[1]
end

function input.getDriveIntent()
    local steer = 0
    local throttle = 0
    local brake = 0
    local handbrake = false
    local joystick = input.getActiveJoystick()
    local usingController = false

    if joystick and joystick:isGamepad() then
        local stickX = applyDeadzone(joystick:getGamepadAxis("leftx"), input.deadzone)
        local rightTrigger = applyDeadzone(joystick:getGamepadAxis("triggerright"), input.deadzone)
        local leftTrigger = applyDeadzone(joystick:getGamepadAxis("triggerleft"), input.deadzone)

        steer = stickX
        throttle = math.max(0, rightTrigger)
        brake = math.max(0, leftTrigger)

        handbrake = joystick:isGamepadDown("x")
        usingController = math.abs(stickX) > 0 or throttle > 0 or brake > 0 or handbrake
    end

    if love.keyboard.isDown("w", "up") then
        throttle = 1
    end

    if love.keyboard.isDown("s", "down") then
        brake = 1
    end

    if love.keyboard.isDown("space", "lshift", "rshift") then
        handbrake = true
    end

    return {
        steer = clamp(steer, -1, 1),
        throttle = clamp(throttle, 0, 1),
        brake = clamp(brake, 0, 1),
        handbrake = handbrake,
        anyInput = math.abs(steer) > 0 or throttle > 0 or brake > 0 or handbrake,
        joystick = joystick,
        usingController = usingController,
        usingMouse = false,
        mouseX = love.mouse.getX(),
        mouseY = love.mouse.getY(),
    }
end

return input
