local uiControls = {}

local function rectWidth(rect)
    return rect.w or rect.width or 0
end

local function rectHeight(rect)
    return rect.h or rect.height or 0
end

local function selectedIndex(segments, selectedId)
    for index, segment in ipairs(segments or {}) do
        if segment.id == selectedId then
            return index
        end
    end
    return 1
end

function uiControls.segmentRect(rect, index, count)
    local width = rectWidth(rect)
    local height = rectHeight(rect)
    local segmentWidth = width / math.max(1, count)

    return {
        x = rect.x + ((index - 1) * segmentWidth),
        y = rect.y,
        w = segmentWidth,
        h = height,
    }
end

function uiControls.drawSegmentedToggle(rect, segments, selectedId, hoveredId, font, options)
    local graphics = love.graphics
    local drawOptions = options or {}
    local count = math.max(1, #(segments or {}))
    local width = rectWidth(rect)
    local height = rectHeight(rect)
    local cornerRadius = drawOptions.cornerRadius or 18
    local activeIndex = drawOptions.activeIndex or selectedIndex(segments, selectedId)
    local segmentWidth = width / count

    local backgroundColor = drawOptions.backgroundColor or { 0.08, 0.1, 0.14, 0.98 }
    local activeFillColor = drawOptions.activeFillColor or { 0.98, 0.88, 0.34, 0.96 }
    local hoverColor = drawOptions.hoverColor or { 0.28, 0.36, 0.44, 0.22 }
    local outlineColor = drawOptions.outlineColor or { 0.28, 0.4, 0.52, 1 }
    local innerOutlineColor = drawOptions.innerOutlineColor or { 0.46, 0.66, 0.82, 0.45 }
    local selectedTextColor = drawOptions.selectedTextColor or { 0.08, 0.1, 0.14, 1 }
    local textColor = drawOptions.textColor or { 0.9, 0.93, 0.97, 1 }

    graphics.setColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4] or 1)
    graphics.rectangle("fill", rect.x, rect.y, width, height, cornerRadius, cornerRadius)

    graphics.setColor(activeFillColor[1], activeFillColor[2], activeFillColor[3], activeFillColor[4] or 1)
    graphics.rectangle(
        "fill",
        rect.x + 2 + ((activeIndex - 1) * segmentWidth),
        rect.y + 2,
        segmentWidth - 4,
        height - 4,
        cornerRadius - 2,
        cornerRadius - 2
    )

    love.graphics.setFont(font)
    local textY = rect.y + math.floor((height - font:getHeight()) * 0.5 + 0.5)

    for index, segment in ipairs(segments or {}) do
        local segmentRect = uiControls.segmentRect(rect, index, #segments)
        local selected = segment.id == selectedId
        local hovered = segment.id == hoveredId

        if hovered and not selected then
            graphics.setColor(hoverColor[1], hoverColor[2], hoverColor[3], hoverColor[4] or 1)
            graphics.rectangle("fill", segmentRect.x + 2, segmentRect.y + 2, segmentRect.w - 4, segmentRect.h - 4, cornerRadius - 2, cornerRadius - 2)
        end

        local color = selected and selectedTextColor or textColor
        graphics.setColor(color[1], color[2], color[3], color[4] or 1)
        graphics.printf(segment.label or segment.id or tostring(index), segmentRect.x, textY, segmentRect.w, "center")
    end

    graphics.setLineWidth(2)
    graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4] or 1)
    graphics.rectangle("line", rect.x, rect.y, width, height, cornerRadius, cornerRadius)
    graphics.setColor(innerOutlineColor[1], innerOutlineColor[2], innerOutlineColor[3], innerOutlineColor[4] or 1)
    graphics.rectangle("line", rect.x + 3, rect.y + 3, width - 6, height - 6, cornerRadius - 3, cornerRadius - 3)
    graphics.setLineWidth(1)
end

return uiControls
