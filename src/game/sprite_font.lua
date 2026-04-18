local utf8 = require("utf8")

local SpriteFont = {}

local function pixelSnap(value)
    return math.floor((value or 0) + 0.5)
end

local function glyphRenderWidth(imageData, originX, originY, glyphWidth, glyphHeight)
    local rightmostOpaquePixel = nil

    for y = originY, originY + glyphHeight - 1 do
        for x = originX + glyphWidth - 1, originX, -1 do
            local _, _, _, alpha = imageData:getPixel(x, y)
            if alpha and alpha > 0 then
                local localX = x - originX
                if rightmostOpaquePixel == nil or localX > rightmostOpaquePixel then
                    rightmostOpaquePixel = localX
                end
                break
            end
        end
    end

    if rightmostOpaquePixel == nil then
        return glyphWidth
    end

    return rightmostOpaquePixel + 1
end

local function parseMetadata(rawText)
    local characterWidth = tonumber(rawText:match("Character width:%s*(%-?%d+)"))
    local characterHeight = tonumber(rawText:match("Character height:%s*(%-?%d+)"))
    local characterSpacing = tonumber(rawText:match("Character spacing:%s*(%-?%d+)"))
    local characterSet = rawText:match("Character set:%s*([%s%S]-)%s*Character spacing:")

    if not characterWidth or not characterHeight or not characterSpacing or not characterSet then
        error("Failed to parse sprite font metadata")
    end

    characterSet = characterSet:gsub("^%s+", ""):gsub("%s+$", "")

    return {
        characterWidth = characterWidth,
        characterHeight = characterHeight,
        characterSpacing = characterSpacing,
        characterSet = characterSet,
    }
end

local function iterateCharacters(text)
    local characters = {}
    if not text or text == "" then
        return characters
    end

    for _, codepoint in utf8.codes(text) do
        characters[#characters + 1] = utf8.char(codepoint)
    end

    return characters
end

local function glyphVisibleBounds(imageData, x0, y0, width, height)
    local left = width
    local right = -1

    for y = 0, height - 1 do
        for x = 0, width - 1 do
            local _, _, _, alpha = imageData:getPixel(x0 + x, y0 + y)
            if alpha and alpha > 0 then
                if x < left then
                    left = x
                end
                if x > right then
                    right = x
                end
            end
        end
    end

    if right < left then
        return 0, width - 1
    end

    return left, right
end

function SpriteFont.load(config)
    local metadataRaw, metadataError = love.filesystem.read(config.metricsPath)
    if not metadataRaw then
        error("Failed to load sprite font metadata: " .. tostring(metadataError))
    end

    local metadata = parseMetadata(metadataRaw)
    local imageData = love.image.newImageData(config.imagePath)
    local image = love.graphics.newImage(config.imagePath)
    image:setFilter("nearest", "nearest")

    local imageWidth, imageHeight = image:getDimensions()
    local columns = math.max(1, math.floor(imageWidth / metadata.characterWidth))
    local advance = metadata.characterWidth + metadata.characterSpacing
    local glyphs = {}

    for index, character in ipairs(iterateCharacters(metadata.characterSet)) do
        local glyphIndex = index - 1
        local column = glyphIndex % columns
        local row = math.floor(glyphIndex / columns)
        local glyphOriginX = column * metadata.characterWidth
        local glyphOriginY = row * metadata.characterHeight
        local visibleLeft, visibleRight = glyphVisibleBounds(
            imageData,
            glyphOriginX,
            glyphOriginY,
            metadata.characterWidth,
            metadata.characterHeight
        )

        glyphs[character] = {
            visibleLeft = visibleLeft,
            visibleRight = visibleRight,
            quad = love.graphics.newQuad(
                glyphOriginX,
                glyphOriginY,
                metadata.characterWidth,
                metadata.characterHeight,
                imageWidth,
                imageHeight
            ),
            width = metadata.characterWidth,
            height = metadata.characterHeight,
            advance = advance,
            renderWidth = glyphRenderWidth(
                imageData,
                glyphOriginX,
                glyphOriginY,
                metadata.characterWidth,
                metadata.characterHeight
            ),
        }
    end

    local spaceGlyph = glyphs[" "]
    local syntheticSpaceAdvance = math.max(1, pixelSnap(advance * 0.5))

    local font = {
        image = image,
        glyphs = glyphs,
        characterWidth = metadata.characterWidth,
        characterHeight = metadata.characterHeight,
        characterSpacing = metadata.characterSpacing,
        spaceAdvance = (spaceGlyph and spaceGlyph.advance) or syntheticSpaceAdvance,
        tabAdvance = ((spaceGlyph and spaceGlyph.advance) or syntheticSpaceAdvance) * 4,
        fallbackGlyph = glyphs["?"],
    }

    return setmetatable(font, { __index = SpriteFont })
end

function SpriteFont:scaleFor(value)
    return math.max(1, pixelSnap(value or 1))
end

function SpriteFont:glyphForCharacter(character)
    if character == " " or character == "\t" or character == "\n" then
        return nil
    end

    return self.glyphs[character] or self.fallbackGlyph
end

function SpriteFont:advanceForCharacter(character)
    if character == " " then
        return self.spaceAdvance
    end
    if character == "\t" then
        return self.tabAdvance
    end
    if character == "\n" then
        return 0
    end

    local glyph = self:glyphForCharacter(character)
    return glyph and glyph.advance or self.spaceAdvance
end

function SpriteFont:measureRunBounds(text, scale)
    local scaled = self:scaleFor(scale)
    local cursorX = 0
    local minLeft = nil
    local maxRight = 0

    for _, codepoint in utf8.codes(text or "") do
        local character = utf8.char(codepoint)
        local glyph = self:glyphForCharacter(character)
        local advance = self:advanceForCharacter(character) * scaled

        if glyph then
            local left = cursorX + ((glyph.visibleLeft or 0) * scaled)
            local right = cursorX + ((glyph.renderWidth or ((glyph.visibleRight or (glyph.width - 1)) + 1)) * scaled)
            minLeft = minLeft and math.min(minLeft, left) or left
            maxRight = math.max(maxRight, right)
        elseif character == " " or character == "\t" then
            maxRight = math.max(maxRight, cursorX + advance)
        end

        cursorX = cursorX + advance
    end

    if not minLeft then
        return {
            left = 0,
            right = 0,
            width = 0,
        }
    end

    return {
        left = minLeft,
        right = maxRight,
        width = maxRight - minLeft,
    }
end

function SpriteFont:measureRun(text, scale)
    return self:measureRunBounds(text, scale).width
end

function SpriteFont:drawRun(text, x, y, scale, color)
    local lg = love.graphics
    local scaled = self:scaleFor(scale)
    local cursorX = pixelSnap(x or 0)
    local drawY = pixelSnap(y or 0)
    local maxRight = cursorX

    lg.setColor(color or { 1, 1, 1, 1 })

    for _, codepoint in utf8.codes(text or "") do
        local character = utf8.char(codepoint)
        local glyph = self:glyphForCharacter(character)
        local advance = self:advanceForCharacter(character) * scaled

        if glyph then
            lg.draw(self.image, glyph.quad, cursorX, drawY, 0, scaled, scaled)
            maxRight = math.max(maxRight, cursorX + ((glyph.renderWidth or glyph.width) * scaled))
        elseif character == " " or character == "\t" then
            maxRight = math.max(maxRight, cursorX + advance)
        end

        cursorX = cursorX + advance
    end

    return maxRight - pixelSnap(x or 0)
end

return SpriteFont
