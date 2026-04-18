local input = require("src.game.input")
local car = require("src.game.car")
local world = require("src.game.world")
local camera = require("src.game.camera")
local ui = require("src.game.ui")
local SpriteFont = require("src.game.sprite_font")

local Game = {}
Game.__index = Game

local function stopSource(source)
    if source and source:isPlaying() then
        source:stop()
    end
end

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
        lowFuelWarningThreshold = 0.2,
        fuelBurnThrottle = 10.5,
        fuelBurnRolling = 1.15,
        coastFuelThreshold = 18,
        lowFuelBeepInterval = 0.6,
        lowFuelBeepVolume = 0.55,
        emptyFuelAlarmVolume = 0.7,
        signalTowerRadiusMeters = 24,
        signalTowerFuelPerSecond = 18,
        signalTowerFirstNorthOffsetMeters = 68,
        signalTowerReachSpeedKmh = 100,
        signalTowerReachCadenceSeconds = 3.2,
        signalTowerLaterCadenceSeconds = 4.4,
        signalTowerScriptedCount = 5,
        signalTowerScriptedLaneRatios = { 0.38, 0.58, 0.42, 0.62, 0.46 },
        signalTowerLaneRatioMin = 0.34,
        signalTowerLaneRatioMax = 0.64,
        signalTowerPoleHeightMeters = 8,
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
    self.metersPerUnit = self.tuning.carLengthMeters / self.car.length
    self.tuning.signalTowerRadius = self:metersToUnits(self.tuning.signalTowerRadiusMeters)
    self.tuning.signalTowerFirstNorthOffset = self:metersToUnits(self.tuning.signalTowerFirstNorthOffsetMeters)
    self.tuning.signalTowerReachSpacing = self:metersToUnits(
        (self.tuning.signalTowerReachSpeedKmh / 3.6) * self.tuning.signalTowerReachCadenceSeconds
    )
    self.tuning.signalTowerLaterSpacing = self:metersToUnits(
        (self.tuning.signalTowerReachSpeedKmh / 3.6) * self.tuning.signalTowerLaterCadenceSeconds
    )
    self.tuning.signalTowerPoleHeight = self:metersToUnits(self.tuning.signalTowerPoleHeightMeters)
    self.world = world.new(self.tuning)
    self.camera = camera.new()
    self.bestDistance = 0
    self.runDistance = 0
    self.state = "title"
    self.activeSignalTower = nil
    self.signalStrength = 0
    self.lowFuelBeepTimer = 0
    self.lowFuelBeepIndex = 1
    self.lowFuelBeepWaitingForGap = false
    self.emptyFuelAlarmActive = false
    self.uiFont = SpriteFont.load({
        imagePath = "assets/fonts/awesome_9_v3/awesome_9.png",
        metricsPath = "assets/fonts/awesome_9_v3/awesome_9.txt",
    })
    self.lowFuelBeeps = {
        love.audio.newSource("assets/sfx/car/bip1.wav", "static"),
        love.audio.newSource("assets/sfx/car/bip2.wav", "static"),
        love.audio.newSource("assets/sfx/car/bip3.wav", "static"),
    }
    self.emptyFuelAlarm = love.audio.newSource("assets/sfx/car/beeeeep.wav", "static")
    self.emptyFuelAlarmEnd = love.audio.newSource("assets/sfx/car/beeeeep_end.wav", "static")
    self.emptyFuelAlarm:setLooping(true)

    for _, beep in ipairs(self.lowFuelBeeps) do
        beep:setVolume(self.tuning.lowFuelBeepVolume)
    end
    self.emptyFuelAlarm:setVolume(self.tuning.emptyFuelAlarmVolume)
    self.emptyFuelAlarmEnd:setVolume(self.tuning.emptyFuelAlarmVolume)

    self:resetRun()
    self.state = "title"

    return self
end

function Game:unitsToMeters(units)
    return units * self.metersPerUnit
end

function Game:metersToUnits(meters)
    return meters / self.metersPerUnit
end

function Game:speedUnitsToKmh(unitsPerSecond)
    return self:unitsToMeters(unitsPerSecond) * 3.6
end

function Game:getFuelRatio()
    return self.car.fuel / self.tuning.fuelCapacity
end

function Game:isLowFuel()
    return self:getFuelRatio() <= self.tuning.lowFuelWarningThreshold
end

function Game:playNextLowFuelBeep()
    local source = self.lowFuelBeeps[self.lowFuelBeepIndex]
    source:stop()
    source:play()
    self.lowFuelBeepIndex = (self.lowFuelBeepIndex % #self.lowFuelBeeps) + 1
    self.lowFuelBeepWaitingForGap = true
end

function Game:getCurrentLowFuelBeep()
    for _, beep in ipairs(self.lowFuelBeeps) do
        if beep:isPlaying() then
            return beep
        end
    end
    return nil
end

function Game:updateLowFuelAudio(dt)
    if self.car.fuel <= 0 or self.emptyFuelAlarmActive then
        return
    end

    if self:isLowFuel() and self.car.fuel > 0 then
        local activeBeep = self:getCurrentLowFuelBeep()
        if activeBeep then
            return
        end

        if self.lowFuelBeepWaitingForGap then
            self.lowFuelBeepTimer = self.lowFuelBeepTimer - dt
            if self.lowFuelBeepTimer > 0 then
                return
            end
            self.lowFuelBeepWaitingForGap = false
        end

        if self.lowFuelBeepTimer <= 0 then
            self:playNextLowFuelBeep()
            self.lowFuelBeepTimer = self.tuning.lowFuelBeepInterval
        end
    else
        self.lowFuelBeepTimer = 0
        self.lowFuelBeepWaitingForGap = false
    end
end

function Game:updateEmptyFuelAlarm(shouldHold)
    if shouldHold then
        if self.emptyFuelAlarmEnd:isPlaying() then
            self.emptyFuelAlarmEnd:stop()
        end

        if not self.emptyFuelAlarm:isPlaying() then
            self.emptyFuelAlarm:stop()
            self.emptyFuelAlarm:play()
        end

        self.emptyFuelAlarmActive = true
        return
    end

    if self.emptyFuelAlarm:isPlaying() then
        self.emptyFuelAlarm:stop()
        self.emptyFuelAlarmEnd:stop()
        self.emptyFuelAlarmEnd:play()
    end

    self.emptyFuelAlarmActive = false
end

function Game:stopWarningAudio()
    stopSource(self.emptyFuelAlarm)
    stopSource(self.emptyFuelAlarmEnd)
    for _, beep in ipairs(self.lowFuelBeeps) do
        stopSource(beep)
    end
end

function Game:resetRun()
    car.reset(self.car, self.tuning)
    self.runDistance = 0
    self.activeSignalTower = nil
    self.signalStrength = 0
    self.lowFuelBeepTimer = 0
    self.lowFuelBeepIndex = 1
    self.lowFuelBeepWaitingForGap = false
    self.emptyFuelAlarmActive = false
    self:stopWarningAudio()
    self.world:reset(self.tuning)
    self.camera:snap(self.car, self.viewport, self.tuning)
    self.world:update(self.car.y, self.camera:getViewportForZoom(self.viewport), self.tuning)
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
    self.world:update(self.car.y, self.camera:getViewportForZoom(self.viewport), self.tuning)

    local signalTower, signalStrength = self.world:getSignalAt(self.car.x, self.car.y)
    self.activeSignalTower = signalTower
    self.signalStrength = signalStrength or 0

    if signalTower then
        self.car.fuel = math.min(self.tuning.fuelCapacity, self.car.fuel + signalTower.fuelPerSecond * dt)
        if self.state == "coasting" and self.car.fuel > 0 then
            self.state = "running"
        end
    end

    self.runDistance = self.car.maxNorthDistance
    self.bestDistance = math.max(self.bestDistance, self.runDistance)
    self:updateEmptyFuelAlarm(self.car.fuel <= 0)
    self:updateLowFuelAudio(dt)

    if self.state == "running" and self.car.fuel <= 0 then
        self.state = "coasting"
    end

    if self.state == "coasting" and self.car.speed <= self.tuning.finishSpeed then
        self:updateEmptyFuelAlarm(false)
        self.state = "finished"
        for _, beep in ipairs(self.lowFuelBeeps) do
            stopSource(beep)
        end
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
    self.world:update(self.car.y, self.camera:getViewportForZoom(self.viewport), self.tuning)
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
