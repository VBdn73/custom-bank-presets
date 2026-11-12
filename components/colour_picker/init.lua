local colourValue = require("components/colour_picker/value")
local overlayPosition = require("components/overlay_position")
local picker = {}
local defaultTheme = {
    border = { 0.58, 0.48, 0.28, 1 },
    background = { 0.14, 0.13, 0.11, 1 },
}
local function colour(rgba)
    return Vector4.new(rgba[1], rgba[2], rgba[3], rgba[4])
end

-- A separate overlay avoids clipping by the ribbon's scrolling content.
-- Host integration is injected; this component knows nothing about the editor,
-- persistence or PrettyUI. attachOverlay may return a cleanup function.
function picker.open(host, options)
    options = options or {}
    local initial, onChange = options.initial, options.onChange
    local anchor, onClose = options.anchor, options.onClose
    local theme = options.theme or defaultTheme
    assert(type(onChange) == "function", "Colour picker requires an onChange callback.")
    local parent = host
    while parent.parent and not parent.parent.isRestricted do parent = parent.parent end
    local root = ui.Layer.new(parent)
    local closed = false
    local detachOverlay
    local function close()
        if closed then return end
        closed = true
        if detachOverlay then detachOverlay() end
        root:Destroy()
        if onClose then onClose() end
    end
    local function rect(x, y, w, h, colour, action)
        local box = ui.Rectangle.new(root)
        box:SetPos(x, y)
        box:SetSize(w, h)
        box.fill = true
        box.colour = Vector4.new(colour[1], colour[2], colour[3], colour[4])
        box.clickthrough = false
        if action then box:Subscribe(ui.Hook.ONCLICK, action) end
        return box
    end
    local function text(x, y, w, content)
        local label = ui.Text.new(root)
        label:SetPos(x, y)
        label:SetSize(w, 24)
        label.font = id.Font.MUSEO_SANS_11PT_REGULAR or id.Font.MUSEO_SANS_15PT_REGULAR
        label.content = content
        label.clickthrough = true
        return label
    end
    local width, height = 288, 266
    root:SetSize(width, height)
    root.clickthrough = false
    -- Empty popup space must consume clicks rather than forwarding them to
    -- the game world. Child controls retain their own pointer handlers.
    root:Subscribe(ui.Hook.ONCLICK, function() return true end)
    local function updatePosition()
        if closed then return end
        overlayPosition.beside(root, parent, anchor or host, width, height)
    end
    updatePosition()
    local function consumeClick() return true end
    rect(0, 0, width, height, theme.border, consumeClick)
    rect(1, 1, width - 2, height - 2, theme.background, consumeClick)
    text(12, 8, 232, options.title or "Choose colour")
    -- Match PrettyUI's window close control using the native modal sprites.
    local closeButton = ui.Sprite.new(root)
    closeButton:SetPos(256, 8)
    closeButton:SetSize(20, 20)
    closeButton.clickthrough = false
    closeButton.sprite = id.Sprite.RS3_BTN_MODAL_WINDOW_1_CLOSE_NML
    closeButton:Subscribe(ui.Hook.ONMOUSEOVER, function()
        closeButton.sprite = id.Sprite.RS3_BTN_MODAL_WINDOW_1_CLOSE_OVR
    end)
    closeButton:Subscribe(ui.Hook.ONMOUSELEAVE, function()
        closeButton.sprite = id.Sprite.RS3_BTN_MODAL_WINDOW_1_CLOSE_NML
    end)
    closeButton:Subscribe(ui.Hook.ONCLICK, function() close(); return true end)
    local selected = colourValue.normalize(initial) or "#FFFFFF"
    local h, s, v = colourValue.toHSV(selected)
    local preview = rect(232, 226, 44, 28, colourValue.vector(selected))
    local input = ui.InputField.new(root)
    input:SetPos(12, 226)
    input:SetSize(208, 28)
    input.stylesheetID = id.StyleSheet.INPUT_DEFAULT
    input:Setup(ui.TextContentVisibilityMode.VISIBLE, ui.InputFieldFilterMode.NONE, 7)
    input.content = selected
    local shadeMarker
    local function positionMarkers()
        local y = v == 1 and s / 2 or 1 - v / 2
        if shadeMarker then shadeMarker:SetPos(12 + h * 263 - 3, 36 + y * 181 - 3) end
    end
    local function refresh()
        preview.colour = colour(colourValue.vector(selected))
        input.content = selected
        positionMarkers()
    end
    local canvas = ui.Canvas.new(root)
    canvas:SetPos(12, 36)
    canvas:SetSize(264, 182)
    canvas.clickthrough = true
    -- Native gradients give a continuous spectrum without a grid of components.
    for sector = 0, 5 do
        canvas:AddGradientH(sector * 44, 0, 44, 182,
            colourValue.rgba(colourValue.fromHSV(sector / 6, 1, 1)),
            colourValue.rgba(colourValue.fromHSV((sector + 1) / 6, 1, 1)))
    end
    canvas:AddGradientV(0, 0, 264, 91, 0xFFFFFFFF, 0xFFFFFF00)
    canvas:AddGradientV(0, 91, 264, 91, 0x00000000, 0x000000FF)
    -- One hit target for the entire canvas. Pointer
    -- hook coordinates are component-local interface units (also at UI scale).
    local function dragArea(x, y, w, height, update)
        local area = ui.Layer.new(root)
        area:SetPos(x, y)
        area:SetSize(w, height)
        area.clickthrough = false
        local function select(_, mx, my)
            if closed or type(mx) ~= "number" or type(my) ~= "number" then return false end
            update(math.max(0, math.min(1, mx / (w - 1))),
                math.max(0, math.min(1, my / (height - 1))))
            selected = colourValue.fromHSV(h, s, v)
            refresh()
            onChange(selected)
            return true
        end
        area:Subscribe(ui.Hook.ONCLICK, select)
        area:Subscribe(ui.Hook.ONHOLD, select)
        area:Subscribe(ui.Hook.ONRELEASE, select)
        return area
    end
    dragArea(12, 36, 264, 182, function(x, y)
        h, s, v = x, math.min(1, y * 2), math.min(1, (1 - y) * 2)
    end)
    shadeMarker = rect(0, 0, 7, 7, { 1, 1, 1, 1 })
    shadeMarker.fill = false
    shadeMarker.clickthrough = true
    positionMarkers()
    input:Subscribe(ui.Hook.ONCONTENTCHANGED, function()
        local hex = colourValue.normalize(input.content)
        if not hex then return end
        selected = hex
        h, s, v = colourValue.toHSV(hex)
        preview.colour = colour(colourValue.vector(hex))
        positionMarkers()
        onChange(selected)
    end)
    if options.attachOverlay then detachOverlay = options.attachOverlay(root, updatePosition) end
    return close, updatePosition
end
return picker
