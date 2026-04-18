local input = require("src.game.input")
local car = require("src.game.car")
local world = require("src.game.world")
local camera = require("src.game.camera")
local ui = require("src.game.ui")
local SpriteFont = require("src.game.sprite_font")

local Game = {}
Game.__index = Game

local function buildTuning()
    return {
        maxSteerAngle = math.rad(34),
        carLengthMeters = 4,
        steerSpeed = math.rad(180),
        wheelBase = 52,
        engineForce = 420,
        brakeForce = 520,
        reverseForce = 220,
        reverseThreshold = 26,
        maxForwardSpeed = 620,
        maxReverseSpeed = 150,
        drag = 0.78,
        rollingResistance = 38,
        yawResponse = 7.5,
        angularDamping = 5.2,
        turnSpeedFloor = 8,
        rearGripLowSpeed = 13.5,
        rearGripHighSpeed = 4.2,
        gripSpeedWindow = 360,
        handbrakeGripMultiplier = 0.26,
        handbrakeDrag = 22,
        corridorHalfWidth = 1040,
        barrierThickness = 56,
        segmentHeight = 160,
        worldDrawPadding = 220,
        wallBounce = 0.22,
        wallSpeedScrub = 0.34,
        wallSpinImpulse = 0.0028,
        wallHeadingKick = math.rad(3.5),
        wallSlipKick = 110,
        fuelCapacity = 100,
        fuelBurnThrottle = 10.5,
        fuelBurnRolling = 1.15,
        coastFuelThreshold = 18,
        finishSpeed = 16,
        stopSpeed = 5,
        skidThreshold = 44,
        skidMinSpeed = 70,
        skidInterval = 0.05,
        skidLife = 6.2,
        skidRadius = 5,
        cameraBaseZoom = 1,
        cameraMinZoom = 0.72,
        cameraMaxZoomOut = 0.28,
        cameraSpeedZoomFactor = 0.00045,
        cameraZoomLerp = 2.8,
        cameraAnchorStartRatio = 7 / 12,
        cameraAnchorEndRatio = 5 / 6,
        cameraAnchorSpeedFactor = 1 / 460,
        cameraLateralLerp = 4.8,
        cameraForwardLerp = 3.9,
    }
end

function Game.new()
    local self = setmetatable({}, Game)

    self.tuning = buildTuning()
    self.viewport = {
        w = love.graphics.getWidth(),
        h = love.graphics.getHeight(),
    }

    self.car = car.new(self.tuning)
    self.world = world.new(self.tuning)
    self.camera = camera.new()
    self.metersPerUnit = self.tuning.carLengthMeters / self.car.length
    self.bestDistance = 0
    self.runDistance = 0
    self.state = "title"
    self.uiFont = SpriteFont.load({
        imagePath = "assets/fonts/awesome_9_v3/awesome_9.png",
        metricsPath = "assets/fonts/awesome_9_v3/awesome_9.txt",
    })

    self:resetRun()
    self.state = "title"

    return self
end

function Game:unitsToMeters(units)
    return units * self.metersPerUnit
end

function Game:speedUnitsToKmh(unitsPerSecond)
    return self:unitsToMeters(unitsPerSecond) * 3.6
end

function Game:resetRun()
    car.reset(self.car, self.tuning)
    self.runDistance = 0
    self.camera:snap(self.car, self.viewport, self.tuning)
    self.world:update(self.car.y, self.camera:getViewportForZoom(self.viewport))
end

function Game:beginRun()
    self:resetRun()
    self.state = "running"
end

function Game:update(dt)
    if self.state ~= "running" and self.state ~= "coasting" then
        return
    end

    local intent = input.getDriveIntent()
    car.update(self.car, intent, dt, self.tuning)
    self.world:resolveBarriers(self.car, self.tuning)
    self.camera:update(self.car, dt, self.viewport, self.tuning)
    self.world:update(self.car.y, self.camera:getViewportForZoom(self.viewport))

    self.runDistance = self.car.maxNorthDistance
    self.bestDistance = math.max(self.bestDistance, self.runDistance)

    if self.state == "running" and self.car.fuel <= 0 then
        self.state = "coasting"
    end

    if self.state == "coasting" and self.car.speed <= self.tuning.finishSpeed then
        self.state = "finished"
    end
end

function Game:draw()
    local graphics = love.graphics

    graphics.clear(0.04, 0.05, 0.06)

    graphics.push()
    graphics.translate(self.viewport.w * 0.5, self.viewport.h * 0.5)
    graphics.scale(self.camera.zoom, self.camera.zoom)
    graphics.translate(-math.floor(self.camera.x), -math.floor(self.camera.y))
    self.world:draw()
    car.drawSkids(self.car)
    car.draw(self.car)
    graphics.pop()

    ui.draw(self)
end

function Game:resize(w, h)
    self.viewport.w = w
    self.viewport.h = h
    self.camera:snap(self.car, self.viewport, self.tuning)
    self.world:update(self.car.y, self.camera:getViewportForZoom(self.viewport))
end

function Game:keypressed(key)
    if key == "escape" then
        love.event.quit()
        return
    end

    if key == "r" and self.state ~= "title" then
        self:beginRun()
        return
    end

    if self.state == "title" or self.state == "finished" then
        self:beginRun()
    end
end

function Game:gamepadpressed(_, button)
    if button == "start" and self.state ~= "title" then
        self:beginRun()
        return
    end

    if self.state == "title" or self.state == "finished" then
        self:beginRun()
    end
end

return Game
