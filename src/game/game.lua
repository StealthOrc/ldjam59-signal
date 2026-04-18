local input = require("src.game.input")
local car = require("src.game.car")
local world = require("src.game.world")
local camera = require("src.game.camera")
local ui = require("src.game.ui")
local SpriteFont = require("src.game.sprite_font")
local Progression = require("src.game.progression")

local Game = {}
Game.__index = Game

local function stopSource(source)
    if source and source:isPlaying() then
        source:stop()
    end
end

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

local function shuffleInPlace(list)
    for index = #list, 2, -1 do
        local swapIndex = love.math.random(index)
        list[index], list[swapIndex] = list[swapIndex], list[index]
    end
end

local function buildTuning()
    return {
        maxSteerAngle = math.rad(34),
        carLengthMeters = 4,
        steerSpeed = math.rad(180),
        wheelBase = 52,
        baseEngineForce = 420,
        brakeForce = 520,
        baseReverseForce = 220,
        reverseThreshold = 26,
        baseMaxForwardSpeedKmh = 120,
        maxReverseSpeedKmh = 36,
        drag = 0.68,
        rollingResistance = 30,
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
        runTimeLimitSeconds = 30,
        lowFuelWarningThreshold = 0.2,
        fuelBurnThrottle = 10.5,
        fuelBurnRolling = 1.15,
        coastFuelThreshold = 18,
        lowFuelBeepInterval = 0.6,
        lowFuelBeepVolume = 0.55,
        emptyFuelAlarmVolume = 0.7,
        gearAudioVolume = 0.48,
        gearShiftVolume = 0.5,
        gearAudioThrottleFloor = 0.16,
        gearAudioMinSpeedKmh = 1,
        gearAccelLoopDuration = 0.2,
        gearAccelLoopGuard = 0.015,
        signalTowerRadiusMeters = 24,
        signalTowerFuelPerSecond = 18,
        signalTowerFirstNorthOffsetMeters = 60,
        signalTowerFirstGapMeters = 90,
        signalTowerGapMultiplier = 1.5,
        signalTowerScriptedCount = 5,
        signalTowerScriptedLaneRatios = { 0.38, 0.58, 0.42, 0.62, 0.46 },
        signalTowerLaneRatioMin = 0.34,
        signalTowerLaneRatioMax = 0.64,
        signalTowerPoleHeightMeters = 8,
        boostSignalEveryNthTower = 3,
        coinDistanceMeters = 100,
        boostPadCost = 2,
        accelerationUpgradeCost = 3,
        sixthGearCost = 6,
        closeRatiosCost = 7,
        sportTransmissionCost = 8,
        boostPadSpeedMultiplier = 1.2,
        boostPadDuration = 3,
        boostPadCooldown = 0.55,
        boostPadAccelerationSeconds = 0.3,
        shopHoldBaseInterval = 0.28,
        shopHoldMinInterval = 0.035,
        baseGearCount = 5,
        maxGearCount = 6,
        baseShiftDuration = 0.2,
        sportShiftDuration = 0.12,
        shiftDriveMultiplier = 0.26,
        shiftFlashDuration = 0.32,
        postShiftLockDuration = 0.42,
        upshiftThrottleThreshold = 0.3,
        throttleHoldGearThreshold = 0.55,
        downshiftHysteresisKmh = 8,
        throttleDownshiftSpanFactor = 0.32,
        upshiftBufferKmh = 0,
        sportUpshiftBufferKmh = 5,
        neutralReturnKmh = 2.5,
        stockTopWeight = 1.6,
        closeRatioTopWeight = 1.35,
        baseLowGearDriveMultiplier = 1.44,
        baseHighGearDriveMultiplier = 1.04,
        closeRatioHighGearDriveMultiplier = 0.92,
        sportDriveBonus = 0.06,
        finishSpeed = 16,
        stopSpeed = 5,
        skidThreshold = 44,
        skidMinSpeed = 70,
        skidInterval = 0.05,
        skidLife = 6.2,
        skidRadius = 5,
        cameraBaseZoom = 1,
        cameraMinZoom = 0.58,
        cameraMaxZoomOut = 0.42,
        cameraSpeedZoomFactor = 0.00045,
        cameraZoomLerp = 2.8,
        cameraAnchorStartRatio = 7 / 12,
        cameraAnchorEndRatio = 5 / 6,
        cameraAnchorSpeedFactor = 1 / 460,
        cameraLateralLerp = 4.8,
        cameraForwardLerp = 3.9,
    }
end

local function buildGearBands(maxSpeedKmh, gearCount, tuning, useCloseRatios, useSportTransmission)
    local topWeight = useCloseRatios and tuning.closeRatioTopWeight or tuning.stockTopWeight
    local highGearDrive = useCloseRatios and tuning.closeRatioHighGearDriveMultiplier or tuning.baseHighGearDriveMultiplier
    local sportDriveBonus = useSportTransmission and tuning.sportDriveBonus or 0
    local weights = {}
    local weightSum = 0

    for gearIndex = 1, gearCount do
        local ratio = gearCount == 1 and 1 or (gearIndex - 1) / (gearCount - 1)
        local weight = lerp(1, topWeight, ratio)
        weights[gearIndex] = weight
        weightSum = weightSum + weight
    end

    local bands = {}
    local cursor = 0
    for gearIndex = 1, gearCount do
        local width = maxSpeedKmh * (weights[gearIndex] / weightSum)
        local minKmh = cursor
        local maxKmh = gearIndex == gearCount and maxSpeedKmh or (cursor + width)
        local ratio = gearCount == 1 and 1 or (gearIndex - 1) / (gearCount - 1)
        local driveMultiplier = lerp(tuning.baseLowGearDriveMultiplier, highGearDrive, ratio) + sportDriveBonus

        bands[gearIndex] = {
            minKmh = minKmh,
            maxKmh = maxKmh,
            driveMultiplier = driveMultiplier,
        }

        cursor = cursor + width
    end

    return bands
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
    self.tuning.speedUnitsToKmhFactor = self.metersPerUnit * 3.6
    self.tuning.signalTowerRadius = self:metersToUnits(self.tuning.signalTowerRadiusMeters)
    self.tuning.signalTowerFirstNorthOffset = self:metersToUnits(self.tuning.signalTowerFirstNorthOffsetMeters)
    self.tuning.signalTowerFirstGap = self:metersToUnits(self.tuning.signalTowerFirstGapMeters)
    self.tuning.signalTowerPoleHeight = self:metersToUnits(self.tuning.signalTowerPoleHeightMeters)
    self.tuning.maxReverseSpeed = self:metersToUnits(self.tuning.maxReverseSpeedKmh / 3.6)

    self.world = world.new(self.tuning)
    self.camera = camera.new()
    self.progression = Progression.load()
    self.shopItems = {
        {
            id = "boost_pads",
            kind = "unlock",
            title = "Boost Signals",
            description = "Some radio towers turn into boost signals that snap the car upright before boosting it.",
            cost = self.tuning.boostPadCost,
        },
        {
            id = "double_acceleration",
            kind = "unlock",
            title = "Twin Turbo",
            description = "Doubles your acceleration so the car pulls much harder out of turns.",
            cost = self.tuning.accelerationUpgradeCost,
        },
        {
            id = "sixth_gear",
            kind = "unlock",
            title = "6th Gear",
            description = "Adds a sixth forward gear for a longer, calmer top end.",
            cost = self.tuning.sixthGearCost,
        },
        {
            id = "close_ratios",
            kind = "unlock",
            title = "Close Ratios",
            description = "Tightens the gear spread so the car stays in stronger pull more often.",
            cost = self.tuning.closeRatiosCost,
        },
        {
            id = "sport_transmission",
            kind = "unlock",
            title = "Sport Transmission",
            description = "Shifts faster and lets the car hold each gear a little longer.",
            cost = self.tuning.sportTransmissionCost,
        },
        {
            id = "top_speed_dump",
            kind = "dump",
            title = "Long Gears",
            description = "Spend coins for permanent top speed. One coin buys one extra km/h.",
            cost = 1,
        },
    }
    self.selectedShopIndex = 1
    self.shopHoldActive = false
    self.shopHoldItemId = nil
    self.shopHoldElapsed = 0
    self.shopHoldTimer = 0
    self.bestDistance = 0
    self.runDistance = 0
    self.lastRunCoinsEarned = 0
    self.lastRunMetersDriven = 0
    self.runTimeRemaining = self.tuning.runTimeLimitSeconds
    self.finishReason = nil
    self.state = "title"
    self.activeSignalTower = nil
    self.signalStrength = 0
    self.activeBoostSignal = nil
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

    self.gearAudioPairs = {
        {
            accel = love.audio.newSource("assets/sfx/car/accel1.wav", "static"),
            shift = love.audio.newSource("assets/sfx/car/shift1.wav", "static"),
        },
        {
            accel = love.audio.newSource("assets/sfx/car/accel2.wav", "static"),
            shift = love.audio.newSource("assets/sfx/car/shift2.wav", "static"),
        },
        {
            accel = love.audio.newSource("assets/sfx/car/accel3.wav", "static"),
            shift = love.audio.newSource("assets/sfx/car/shift3.wav", "static"),
        },
    }
    self.gearAudioOrder = {}
    self.gearAudioOrderIndex = 1
    self.activeGearAudio = nil
    self.queueNextGearAccel = false
    self.lastThrottleAudioActive = false

    for _, beep in ipairs(self.lowFuelBeeps) do
        beep:setVolume(self.tuning.lowFuelBeepVolume)
    end
    self.emptyFuelAlarm:setVolume(self.tuning.emptyFuelAlarmVolume)
    self.emptyFuelAlarmEnd:setVolume(self.tuning.emptyFuelAlarmVolume)

    for _, pair in ipairs(self.gearAudioPairs) do
        pair.accel:setVolume(self.tuning.gearAudioVolume)
        pair.shift:setVolume(self.tuning.gearShiftVolume)
    end

    self:refreshGearAudioOrder()
    self:refreshTuningFromProgression()
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

function Game:getMaxSpeedBonusKmh()
    return self.progression.max_speed_bonus_kmh or 0
end

function Game:refreshGearAudioOrder()
    self.gearAudioOrder = { 1, 2, 3 }
    shuffleInPlace(self.gearAudioOrder)
    self.gearAudioOrderIndex = 1
end

function Game:pickNextGearAudioPairIndex()
    if self.gearAudioOrderIndex > #self.gearAudioOrder then
        self:refreshGearAudioOrder()
    end

    local pairIndex = self.gearAudioOrder[self.gearAudioOrderIndex]
    self.gearAudioOrderIndex = self.gearAudioOrderIndex + 1
    return pairIndex
end

function Game:stopGearAudio()
    if self.activeGearAudio and self.activeGearAudio.source then
        stopSource(self.activeGearAudio.source)
    end

    self.activeGearAudio = nil
    self.queueNextGearAccel = false
    self.lastThrottleAudioActive = false
end

function Game:playGearAccel(pairIndex)
    local pair = self.gearAudioPairs[pairIndex]
    if not pair then
        return
    end

    if self.activeGearAudio and self.activeGearAudio.source then
        stopSource(self.activeGearAudio.source)
    end

    pair.accel:stop()
    pair.accel:play()
    local duration = pair.accel:getDuration("seconds")
    local loopDuration = math.min(self.tuning.gearAccelLoopDuration, math.max(duration * 0.5, 0))
    local loopStart = math.max(0, duration - loopDuration)
    self.activeGearAudio = {
        phase = "accel",
        pairIndex = pairIndex,
        source = pair.accel,
        loopStart = loopStart,
        loopEnd = duration,
    }
end

function Game:playGearShift(pairIndex, queueNextAccel)
    local pair = self.gearAudioPairs[pairIndex]
    if not pair then
        return
    end

    if self.activeGearAudio and self.activeGearAudio.source then
        stopSource(self.activeGearAudio.source)
    end

    pair.shift:stop()
    pair.shift:play()
    self.activeGearAudio = {
        phase = "shift",
        pairIndex = pairIndex,
        source = pair.shift,
    }
    self.queueNextGearAccel = queueNextAccel == true
end

function Game:keepGearAccelLoopAlive()
    if not self.activeGearAudio or self.activeGearAudio.phase ~= "accel" then
        return
    end

    local source = self.activeGearAudio.source
    local loopEnd = self.activeGearAudio.loopEnd or 0
    local loopStart = self.activeGearAudio.loopStart or 0

    if loopEnd <= 0 or loopStart >= loopEnd then
        return
    end

    local playbackPosition = source:tell("seconds")
    if playbackPosition >= loopEnd - self.tuning.gearAccelLoopGuard then
        source:seek(loopStart, "seconds")
    end
end

function Game:resolveCurrentGearAudioToShift(queueNextAccel)
    if self.activeGearAudio and self.activeGearAudio.phase == "accel" then
        self:playGearShift(self.activeGearAudio.pairIndex, queueNextAccel)
        return
    end

    if not self.activeGearAudio then
        self:playGearShift(self:pickNextGearAudioPairIndex(), queueNextAccel)
        return
    end

    self.queueNextGearAccel = queueNextAccel == true
end

function Game:canRunGearAudio(intent)
    return self.state == "running"
        and self.car.fuel > 0
        and intent.throttle >= self.tuning.gearAudioThrottleFloor
        and self.car.forwardSpeedKmh >= self.tuning.gearAudioMinSpeedKmh
end

function Game:updateGearAudio(intent)
    local throttleAudioActive = self:canRunGearAudio(intent)

    if not throttleAudioActive then
        self:stopGearAudio()
        return
    end

    self:keepGearAccelLoopAlive()

    if self.activeGearAudio and not self.activeGearAudio.source:isPlaying() then
        self.activeGearAudio = nil
    end

    if self.car.shiftStartedThisFrame then
        if self.activeGearAudio and self.activeGearAudio.phase == "accel" then
            self:playGearShift(self.activeGearAudio.pairIndex, true)
        elseif not self.activeGearAudio then
            self:playGearShift(self:pickNextGearAudioPairIndex(), true)
        else
            self.queueNextGearAccel = true
        end
    elseif self.car.isShifting and not self.activeGearAudio then
        self:playGearShift(self:pickNextGearAudioPairIndex(), true)
    elseif not self.car.isShifting and not self.activeGearAudio then
        if self.queueNextGearAccel or self.car.shiftFinishedThisFrame or not self.lastThrottleAudioActive then
            self.queueNextGearAccel = false
            self:playGearAccel(self:pickNextGearAudioPairIndex())
        end
    end

    self.lastThrottleAudioActive = throttleAudioActive
end

function Game:refreshTuningFromProgression()
    local accelerationMultiplier = self:hasUpgrade("double_acceleration") and 2 or 1
    local topSpeedBonus = self:getMaxSpeedBonusKmh()
    local gearCount = self:hasUpgrade("sixth_gear") and self.tuning.maxGearCount or self.tuning.baseGearCount
    local useCloseRatios = self:hasUpgrade("close_ratios")
    local useSportTransmission = self:hasUpgrade("sport_transmission")

    self.tuning.engineForce = self.tuning.baseEngineForce * accelerationMultiplier
    self.tuning.reverseForce = self.tuning.baseReverseForce * accelerationMultiplier
    self.tuning.maxForwardSpeedKmh = self.tuning.baseMaxForwardSpeedKmh + topSpeedBonus
    self.tuning.maxForwardSpeed = self:metersToUnits(self.tuning.maxForwardSpeedKmh / 3.6)
    self.tuning.maxReverseSpeed = self:metersToUnits(self.tuning.maxReverseSpeedKmh / 3.6)
    self.tuning.boostPadTargetSpeed = self:metersToUnits(
        (self.tuning.maxForwardSpeedKmh * self.tuning.boostPadSpeedMultiplier) / 3.6
    )
    self.tuning.boostPadAcceleration = self.tuning.boostPadTargetSpeed / self.tuning.boostPadAccelerationSeconds
    self.tuning.gearCount = gearCount
    self.tuning.shiftDuration = useSportTransmission and self.tuning.sportShiftDuration or self.tuning.baseShiftDuration
    self.tuning.upshiftBufferKmh = useSportTransmission and self.tuning.sportUpshiftBufferKmh or 0
    self.tuning.gearBands = buildGearBands(
        self.tuning.maxForwardSpeedKmh,
        gearCount,
        self.tuning,
        useCloseRatios,
        useSportTransmission
    )
end

function Game:getCoinRewardForDistance(distanceUnits)
    return math.floor(self:unitsToMeters(distanceUnits) / self.tuning.coinDistanceMeters)
end

function Game:hasUpgrade(upgradeId)
    return self.progression.upgrades[upgradeId] == true
end

function Game:saveProgression()
    Progression.save(self.progression)
end

function Game:awardRunCoins()
    self.lastRunMetersDriven = self:unitsToMeters(self.runDistance)
    self.lastRunCoinsEarned = self:getCoinRewardForDistance(self.runDistance)
    self.progression.coins = self.progression.coins + self.lastRunCoinsEarned
    self:saveProgression()
end

function Game:finishRun(reason)
    self:stopShopHold()
    self:updateEmptyFuelAlarm(false)
    self.finishReason = reason or self.finishReason or "fuel"
    self.state = "finished"
    self:awardRunCoins()
    for _, beep in ipairs(self.lowFuelBeeps) do
        stopSource(beep)
    end
    self:stopGearAudio()
end

function Game:openShop()
    self:stopShopHold()
    self.selectedShopIndex = 1
    self.state = "shop"
    self:stopGearAudio()
end

function Game:isDumpShopItem(itemOrId)
    local item = itemOrId
    if type(itemOrId) == "string" then
        item = self:getShopItemById(itemOrId)
    end

    return item and item.kind == "dump" or false
end

function Game:getShopItemById(itemId)
    for _, item in ipairs(self.shopItems) do
        if item.id == itemId then
            return item
        end
    end
    return nil
end

function Game:getSelectedShopItem()
    return self.shopItems[self.selectedShopIndex]
end

function Game:moveShopSelection(direction)
    self:stopShopHold()
    local itemCount = #self.shopItems
    self.selectedShopIndex = ((self.selectedShopIndex - 1 + direction) % itemCount) + 1
end

function Game:getShopHoldInterval()
    local intervalScale = 2 ^ math.floor(self.shopHoldElapsed)
    local interval = self.tuning.shopHoldBaseInterval / intervalScale
    return math.max(self.tuning.shopHoldMinInterval, interval)
end

function Game:startShopHold(itemId)
    if not self:isDumpShopItem(itemId) then
        return
    end

    self.shopHoldActive = true
    self.shopHoldItemId = itemId
    self.shopHoldElapsed = 0
    self.shopHoldTimer = self:getShopHoldInterval()
end

function Game:stopShopHold()
    self.shopHoldActive = false
    self.shopHoldItemId = nil
    self.shopHoldElapsed = 0
    self.shopHoldTimer = 0
end

function Game:updateShopHold(dt)
    if not self.shopHoldActive then
        return
    end

    local selectedItem = self:getSelectedShopItem()
    if not selectedItem or selectedItem.id ~= self.shopHoldItemId or not self:isDumpShopItem(selectedItem) then
        self:stopShopHold()
        return
    end

    if self.progression.coins <= 0 then
        self:stopShopHold()
        return
    end

    self.shopHoldElapsed = self.shopHoldElapsed + dt
    self.shopHoldTimer = self.shopHoldTimer - dt

    while self.shopHoldTimer <= 0 do
        if not self:buyUpgrade(self.shopHoldItemId) then
            self:stopShopHold()
            return
        end

        self.shopHoldTimer = self.shopHoldTimer + self:getShopHoldInterval()
    end
end

function Game:buyUpgrade(upgradeId)
    local item = self:getShopItemById(upgradeId)
    if not item then
        return false
    end

    local cost = item.cost or 0
    if item.kind == "unlock" and self:hasUpgrade(upgradeId) then
        return false
    end

    if self.progression.coins < cost then
        return false
    end

    self.progression.coins = self.progression.coins - cost

    if item.kind == "unlock" then
        self.progression.upgrades[upgradeId] = true
    elseif item.kind == "dump" then
        self.progression.max_speed_bonus_kmh = self:getMaxSpeedBonusKmh() + cost
    else
        return false
    end

    self:refreshTuningFromProgression()
    self:saveProgression()
    return true
end

function Game:buySelectedShopUpgrade()
    local selectedItem = self:getSelectedShopItem()
    if not selectedItem then
        return false
    end

    return self:buyUpgrade(selectedItem.id)
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
    self:stopShopHold()
    self:refreshTuningFromProgression()
    car.reset(self.car, self.tuning)
    self.runDistance = 0
    self.lastRunMetersDriven = 0
    self.runTimeRemaining = self.tuning.runTimeLimitSeconds
    self.finishReason = nil
    self.activeSignalTower = nil
    self.signalStrength = 0
    self.activeBoostSignal = nil
    self.lowFuelBeepTimer = 0
    self.lowFuelBeepIndex = 1
    self.lowFuelBeepWaitingForGap = false
    self.emptyFuelAlarmActive = false
    self:stopWarningAudio()
    self:stopGearAudio()
    self.world:reset(self.tuning, self.progression)
    self.camera:snap(self.car, self.viewport, self.tuning)
    self.world:update(self.car.y, self.camera:getViewportForZoom(self.viewport), self.tuning, self.progression)
end

function Game:beginRun()
    self:stopShopHold()
    self:resetRun()
    self.state = "running"
end

function Game:update(dt)
    if self.state == "shop" then
        self:updateShopHold(dt)
        return
    end

    if self.state ~= "running" and self.state ~= "coasting" then
        return
    end

    local intent = input.getDriveIntent()
    car.update(self.car, intent, dt, self.tuning)
    self.runTimeRemaining = math.max(0, self.runTimeRemaining - dt)
    self.world:resolveBarriers(self.car, self.tuning)
    self.camera:update(self.car, dt, self.viewport, self.tuning)
    self.world:update(self.car.y, self.camera:getViewportForZoom(self.viewport), self.tuning, self.progression)
    self.activeBoostSignal = self.world:resolveBoostSignals(self.car, self.tuning)

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
    self:updateGearAudio(intent)

    if self.runTimeRemaining <= 0 then
        self:finishRun("time")
        return
    end

    if self.car.fuel <= 0 then
        self:finishRun("fuel")
        return
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
    self.world:update(self.car.y, self.camera:getViewportForZoom(self.viewport), self.tuning, self.progression)
end

function Game:keypressed(key)
    if key == "escape" then
        love.event.quit()
        return
    end

    if key == "r" and self.state == "shop" then
        self:stopShopHold()
        self:beginRun()
        return
    end

    if self.state == "title" then
        self:beginRun()
        return
    end

    if self.state == "finished" then
        self:openShop()
        return
    end

    if self.state == "shop" then
        if key == "up" or key == "w" then
            self:moveShopSelection(-1)
            return
        end

        if key == "down" or key == "s" then
            self:moveShopSelection(1)
            return
        end

        if key == "space" or key == "b" then
            local selectedItem = self:getSelectedShopItem()
            local purchased = self:buySelectedShopUpgrade()
            if purchased and self:isDumpShopItem(selectedItem) then
                self:startShopHold(selectedItem.id)
            end
            return
        end

        if key == "return" or key == "kpenter" or key == "r" then
            self:stopShopHold()
            self:beginRun()
            return
        end
    end
end

function Game:gamepadpressed(_, button)
    if button == "start" and self.state == "shop" then
        self:stopShopHold()
        self:beginRun()
        return
    end

    if self.state == "title" then
        self:beginRun()
        return
    end

    if self.state == "finished" then
        self:openShop()
        return
    end

    if self.state == "shop" then
        if button == "dpup" then
            self:moveShopSelection(-1)
            return
        end

        if button == "dpdown" then
            self:moveShopSelection(1)
            return
        end

        if button == "a" then
            local selectedItem = self:getSelectedShopItem()
            local purchased = self:buySelectedShopUpgrade()
            if purchased and self:isDumpShopItem(selectedItem) then
                self:startShopHold(selectedItem.id)
            end
            return
        end

        if button == "start" or button == "b" then
            self:stopShopHold()
            self:beginRun()
            return
        end
    end
end

function Game:keyreleased(key)
    if self.state == "shop" and (key == "space" or key == "b") then
        self:stopShopHold()
    end
end

function Game:gamepadreleased(_, button)
    if self.state == "shop" and button == "a" then
        self:stopShopHold()
    end
end

return Game
