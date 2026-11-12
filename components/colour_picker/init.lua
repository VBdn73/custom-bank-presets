local colourValue = require("components/colour_picker/value")
local controlFactory = require("components/colour_picker/controls")
local spectrum = require("components/colour_picker/spectrum")
local overlayPosition = require("components/overlay_position")
local picker = {}
local defaultTheme = {
    border = { 0.58, 0.48, 0.28, 1 },
    background = { 0.14, 0.13, 0.11, 1 },
}

-- A separate overlay avoids clipping by the ribbon's scrolling content.
-- Host integration is injected; this component knows nothing about the editor,
-- persistence or PrettyUI. attachOverlay may return a cleanup function.
function picker.open(host, options)
    options = options or {}
    local onChange, onClose = options.onChange, options.onClose
    local theme = options.theme or defaultTheme
    assert(type(onChange) == "function", "Colour picker requires an onChange callback.")
    local parent = host
    while parent.parent and not parent.parent.isRestricted do parent = parent.parent end
    local root = ui.Layer.new(parent)
    local closed, detachOverlay = false, nil
    local function close()
        if closed then return end
        closed = true
        if detachOverlay then detachOverlay() end
        root:Destroy()
        if onClose then onClose() end
    end

    local width, height = 288, 266
    root:SetSize(width, height)
    root.clickthrough = false
    -- Empty popup space consumes clicks instead of forwarding them to the world.
    local function consumeClick() return true end
    root:Subscribe(ui.Hook.ONCLICK, consumeClick)
    local function updatePosition()
        if closed then return end
        overlayPosition.beside(root, parent, options.anchor or host, width, height)
    end
    updatePosition()

    local controls = controlFactory.new(root, ui, id, Vector4)
    controls.rectangle(0, 0, width, height, theme.border, consumeClick)
    controls.rectangle(1, 1, width - 2, height - 2, theme.background, consumeClick)
    controls.text(12, 8, 232, options.title or "Choose colour")
    controls.closeButton(256, 8, close)

    local selected = colourValue.normalize(options.initial) or "#FFFFFF"
    local preview = controls.rectangle(232, 226, 44, 28, colourValue.vector(selected))
    local input = controls.hexInput(12, 226, 208, 28, selected)
    local shade
    shade = spectrum.new(root, ui, controls, function() return closed end, function(hex, h, s, v)
        selected = hex
        preview.colour = controls.colour(colourValue.vector(selected))
        input.content = selected
        shade:setHSV(h, s, v)
        onChange(selected)
    end)
    shade:setHSV(colourValue.toHSV(selected))

    input:Subscribe(ui.Hook.ONCONTENTCHANGED, function()
        local hex = colourValue.normalize(input.content)
        if not hex then return end
        selected = hex
        preview.colour = controls.colour(colourValue.vector(selected))
        shade:setHSV(colourValue.toHSV(selected))
        onChange(selected)
    end)
    if options.attachOverlay then detachOverlay = options.attachOverlay(root, updatePosition) end
    return close, updatePosition
end

return picker
