local camera = {}
camera.__index = camera

function camera.new()
    return setmetatable({
        x = 0,
        y = 0,
        zoom = 1,
    }, camera)
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

function camera:getViewportForZoom(viewport)
    return {
        w = viewport.w / self.zoom,
        h = viewport.h / self.zoom,
    }
end

local function getAnchorRatio(carBody, tuning)
    local anchorProgress = math.min(carBody.speed * tuning.cameraAnchorSpeedFactor, 1)
    return tuning.cameraAnchorStartRatio
        + (tuning.cameraAnchorEndRatio - tuning.cameraAnchorStartRatio) * anchorProgress
end

function camera:snap(carBody, viewport, tuning)
    local zoomOut = math.min(carBody.speed * tuning.cameraSpeedZoomFactor, tuning.cameraMaxZoomOut)
    self.zoom = clamp(tuning.cameraBaseZoom - zoomOut, tuning.cameraMinZoom, tuning.cameraBaseZoom)

    local anchorRatio = getAnchorRatio(carBody, tuning)
    local anchorOffset = viewport.h * (anchorRatio - 0.5) / self.zoom
    self.x = carBody.x
    self.y = carBody.y - anchorOffset
end

function camera:update(carBody, dt, viewport, tuning)
    local zoomOut = math.min(carBody.speed * tuning.cameraSpeedZoomFactor, tuning.cameraMaxZoomOut)
    local targetZoom = clamp(tuning.cameraBaseZoom - zoomOut, tuning.cameraMinZoom, tuning.cameraBaseZoom)
    local zoomBlend = math.min(tuning.cameraZoomLerp * dt, 1)
    self.zoom = self.zoom + (targetZoom - self.zoom) * zoomBlend

    -- Keep the car locked to a deliberate screen composition band instead of a loose look-ahead offset.
    local anchorRatio = getAnchorRatio(carBody, tuning)
    local anchorOffset = viewport.h * (anchorRatio - 0.5) / self.zoom

    local targetX = carBody.x
    local targetY = carBody.y - anchorOffset

    self.x = self.x + (targetX - self.x) * math.min(tuning.cameraLateralLerp * dt, 1)
    self.y = self.y + (targetY - self.y) * math.min(tuning.cameraForwardLerp * dt, 1)
end

return camera
