-- One tooltip per rendered grid, created last to draw above the tiles.
local tooltip = {}

local function textMeasurer(config, fontID)
    local font
    if config and config.Font and config.Font.FromID then
        local ok, result = pcall(config.Font.FromID, fontID)
        if ok then font = result end
    end
    return function(value)
        if font then
            local ok, result = pcall(function() return font:GetStringWidth(value, true) end)
            if ok and type(result) == "number" then return result end
        end
        return #value * 8
    end
end

local function wrappedLines(label, width, measure)
    local lines, line = 1, ""
    for word in label:gmatch("%S+") do
        local nextLine = line == "" and word or line .. " " .. word
        if line ~= "" and measure(nextLine) > width then
            lines, line = lines + 1, word
        else
            line = nextLine
        end
    end
    return lines
end

function tooltip.new(root, ui, controls, theme, config)
    local layer = ui.Layer.new(root)
    layer.clickthrough = true
    local border = controls.rectangle(layer, 0, 0, 60, 26, true, theme.border)
    local background = controls.rectangle(layer, 1, 1, 58, 24, true, theme.background)
    border.clickthrough, background.clickthrough = true, true
    local text = controls.text(layer, 6, 1, 48, "")
    text.alignVertical = ui.AlignMode.CENTRE
    layer.hidden = true
    local view = {}

    function view:show(label, x, y, gridY, scrollY)
        local measure = textMeasurer(config, text.font)
        local width = math.min(root.width - 8, math.max(60, measure(label) + 16))
        local textWidth = math.max(1, width - 12)
        local lines = wrappedLines(label, textWidth, measure)
        local height = math.max(26, lines * 18 + 8)
        local tooltipX = math.max(4, math.min(12 + x, root.width - width - 4))
        local tooltipY = gridY + y - scrollY - height - 2
        if tooltipY < gridY then tooltipY = gridY + y - scrollY + 40 end
        tooltipY = math.max(0, math.min(tooltipY, root.height - height))
        layer:SetPos(tooltipX, tooltipY)
        layer:SetSize(width, height)
        border:SetSize(width, height)
        background:SetSize(width - 2, height - 2)
        text:SetSize(textWidth, height - 2)
        text.maxLines = lines
        text.content = label
        layer.hidden = false
    end

    function view:hide() layer.hidden = true end
    function view:Destroy() layer:Destroy() end
    return view
end

return tooltip
