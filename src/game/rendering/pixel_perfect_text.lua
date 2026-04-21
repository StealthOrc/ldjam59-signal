local pixelPerfectText = {}
pixelPerfectText.__index = pixelPerfectText

local function round(value)
    return math.floor((value or 0) + 0.5)
end

local function distance(x1, y1, x2, y2)
    local dx = (x2 or 0) - (x1 or 0)
    local dy = (y2 or 0) - (y1 or 0)
    return math.sqrt(dx * dx + dy * dy)
end

local function atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end

    if x == 0 then
        if y > 0 then
            return math.pi * 0.5
        elseif y < 0 then
            return -math.pi * 0.5
        end
        return 0
    end

    local angle = math.atan(y / x)
    if x < 0 then
        angle = angle + (y >= 0 and math.pi or -math.pi)
    end

    return angle
end

function pixelPerfectText.computeTextTransform(transformPoint, x, y)
    local originX, originY = transformPoint(x or 0, y or 0)
    local unitXX, unitXY = transformPoint((x or 0) + 1, y or 0)
    local unitYX, unitYY = transformPoint(x or 0, (y or 0) + 1)

    return {
        x = round(originX),
        y = round(originY),
        scaleX = distance(originX, originY, unitXX, unitXY),
        scaleY = distance(originX, originY, unitYX, unitYY),
        rotation = atan2(unitXY - originY, unitXX - originX),
    }
end

function pixelPerfectText.computeScissorRect(transformPoint, x, y, w, h)
    local x1, y1 = transformPoint(x, y)
    local x2, y2 = transformPoint(x + w, y + h)

    local left = math.min(x1, x2)
    local top = math.min(y1, y2)
    local right = math.max(x1, x2)
    local bottom = math.max(y1, y2)

    local snappedLeft = math.floor(left)
    local snappedTop = math.floor(top)
    local snappedRight = math.ceil(right)
    local snappedBottom = math.ceil(bottom)

    return snappedLeft, snappedTop, math.max(0, snappedRight - snappedLeft), math.max(0, snappedBottom - snappedTop)
end

local function defaultTransformPoint(x, y)
    return x, y
end

local function buildFont(graphics, spec, pixelSize)
    local font
    if spec.filename then
        font = graphics.newFont(spec.filename, pixelSize, spec.hinting)
    else
        font = graphics.newFont(pixelSize, spec.hinting)
    end

    font:setFilter("nearest", "nearest")
    return font
end

function pixelPerfectText.new(graphics)
    local self = setmetatable({}, pixelPerfectText)
    self.graphics = graphics
    self.fontSpecs = setmetatable({}, { __mode = "k" })
    self.fontCache = setmetatable({}, { __mode = "k" })
    self.currentBaseFont = graphics.getFont and graphics.getFont() or nil
    self.isActive = false
    self.original = {}

    return self
end

function pixelPerfectText:registerFont(font, spec)
    if not font or type(spec) ~= "table" or not spec.size then
        return
    end

    self.fontSpecs[font] = {
        filename = spec.filename,
        size = spec.size,
        hinting = spec.hinting,
    }
    font:setFilter("nearest", "nearest")
    if not self.currentBaseFont then
        self.currentBaseFont = font
    end
end

function pixelPerfectText:getScreenFont(baseFont, targetScale)
    local spec = self.fontSpecs[baseFont]
    if not spec then
        return nil
    end

    local pixelSize = math.max(1, round(spec.size * math.max(targetScale or 1, 0.01)))
    local cacheBySize = self.fontCache[baseFont]
    if not cacheBySize then
        cacheBySize = {}
        self.fontCache[baseFont] = cacheBySize
    end

    if not cacheBySize[pixelSize] then
        cacheBySize[pixelSize] = buildFont(self.graphics, spec, pixelSize)
    end

    return cacheBySize[pixelSize], pixelSize / spec.size
end

function pixelPerfectText:getTransformPoint()
    local graphics = self.graphics
    if self.isActive and graphics.transformPoint then
        return function(x, y)
            return graphics.transformPoint(x, y)
        end
    end

    return defaultTransformPoint
end

function pixelPerfectText:beginFrame()
    self.isActive = true
end

function pixelPerfectText:endFrame()
    self.isActive = false
end

function pixelPerfectText:install()
    if self.isInstalled then
        return
    end

    local graphics = self.graphics
    local original = self.original

    original.getFont = graphics.getFont
    original.setFont = graphics.setFont
    original.print = graphics.print
    original.printf = graphics.printf
    original.push = graphics.push
    original.pop = graphics.pop
    original.origin = graphics.origin
    original.setScissor = graphics.setScissor

    local context = self

    graphics.getFont = function()
        if context.isActive and context.currentBaseFont then
            return context.currentBaseFont
        end

        return original.getFont()
    end

    graphics.setFont = function(font)
        context.currentBaseFont = font or context.currentBaseFont
        if context.isActive then
            return
        end

        return original.setFont(font)
    end

    graphics.setScissor = function(x, y, w, h)
        if not context.isActive or x == nil then
            return original.setScissor(x, y, w, h)
        end

        local transformPoint = context:getTransformPoint()
        local scissorX, scissorY, scissorW, scissorH = pixelPerfectText.computeScissorRect(transformPoint, x, y, w, h)
        return original.setScissor(scissorX, scissorY, scissorW, scissorH)
    end

    graphics.print = function(text, x, y, r, sx, sy, ox, oy, kx, ky)
        if not context.isActive then
            return original.print(text, x, y, r, sx, sy, ox, oy, kx, ky)
        end

        local baseFont = context.currentBaseFont or original.getFont()
        local transformPoint = context:getTransformPoint()
        local transform = pixelPerfectText.computeTextTransform(transformPoint, x or 0, y or 0)
        local targetScaleX = (sx or 1) * transform.scaleX
        local targetScaleY = (sy or sx or 1) * transform.scaleY
        local fontScale = math.max(transform.scaleY, 0.01)
        local screenFont, cachedScale = context:getScreenFont(baseFont, fontScale)

        if not screenFont or not cachedScale then
            return original.print(text, x, y, r, sx, sy, ox, oy, kx, ky)
        end

        original.push("all")
        original.origin()
        original.setFont(screenFont)
        original.print(
            text,
            transform.x,
            transform.y,
            (r or 0) + transform.rotation,
            targetScaleX / cachedScale,
            targetScaleY / cachedScale,
            ox or 0,
            oy or 0,
            kx or 0,
            ky or 0
        )
        original.pop()
    end

    graphics.printf = function(text, x, y, limit, align, r, sx, sy, ox, oy, kx, ky)
        if not context.isActive then
            return original.printf(text, x, y, limit, align, r, sx, sy, ox, oy, kx, ky)
        end

        local baseFont = context.currentBaseFont or original.getFont()
        local transformPoint = context:getTransformPoint()
        local transform = pixelPerfectText.computeTextTransform(transformPoint, x or 0, y or 0)
        local targetScaleX = (sx or 1) * transform.scaleX
        local targetScaleY = (sy or sx or 1) * transform.scaleY
        local fontScale = math.max(transform.scaleY, 0.01)
        local screenFont, cachedScale = context:getScreenFont(baseFont, fontScale)

        if not screenFont or not cachedScale then
            return original.printf(text, x, y, limit, align, r, sx, sy, ox, oy, kx, ky)
        end

        original.push("all")
        original.origin()
        original.setFont(screenFont)
        original.printf(
            text,
            transform.x,
            transform.y,
            (limit or 0) * transform.scaleX / math.max(targetScaleX / cachedScale, 0.01),
            align,
            (r or 0) + transform.rotation,
            targetScaleX / cachedScale,
            targetScaleY / cachedScale,
            ox or 0,
            oy or 0,
            kx or 0,
            ky or 0
        )
        original.pop()
    end

    self.isInstalled = true
end

return pixelPerfectText
