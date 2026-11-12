-- Continuous hue/shade canvas, pointer interaction and selection marker.
local colourValue = require("components/colour_picker/value")
local spectrum = {}
local x, y, width, height = 12, 36, 264, 182

local function draw(root, ui)
    local canvas = ui.Canvas.new(root)
    canvas:SetPos(x, y)
    canvas:SetSize(width, height)
    canvas.clickthrough = true
    -- Native gradients avoid a grid of individual coloured components.
    for sector = 0, 5 do
        canvas:AddGradientH(sector * 44, 0, 44, height,
            colourValue.rgba(colourValue.fromHSV(sector / 6, 1, 1)),
            colourValue.rgba(colourValue.fromHSV((sector + 1) / 6, 1, 1)))
    end
    canvas:AddGradientV(0, 0, width, 91, 0xFFFFFFFF, 0xFFFFFF00)
    canvas:AddGradientV(0, 91, width, 91, 0x00000000, 0x000000FF)
end

function spectrum.new(root, ui, controls, isClosed, onSelect)
    draw(root, ui)
    -- Pointer coordinates are component-local interface units, also at UI scale.
    local area = ui.Layer.new(root)
    area:SetPos(x, y)
    area:SetSize(width, height)
    area.clickthrough = false
    local function select(_, mx, my)
        if isClosed() or type(mx) ~= "number" or type(my) ~= "number" then return false end
        local hue = math.max(0, math.min(1, mx / (width - 1)))
        local shade = math.max(0, math.min(1, my / (height - 1)))
        local saturation, value = math.min(1, shade * 2), math.min(1, (1 - shade) * 2)
        onSelect(colourValue.fromHSV(hue, saturation, value), hue, saturation, value)
        return true
    end
    area:Subscribe(ui.Hook.ONCLICK, select)
    area:Subscribe(ui.Hook.ONHOLD, select)
    area:Subscribe(ui.Hook.ONRELEASE, select)
    local marker = controls.rectangle(0, 0, 7, 7, { 1, 1, 1, 1 })
    marker.fill = false
    marker.clickthrough = true
    local view = {}

    function view:setHSV(hue, saturation, value)
        local shade = value == 1 and saturation / 2 or 1 - value / 2
        marker:SetPos(x + hue * (width - 1) - 3, y + shade * (height - 1) - 3)
    end

    return view
end

return spectrum
