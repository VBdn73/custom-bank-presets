local bankLabels = require("bank/labels")
local bankAppearance = require("bank/appearance")
local colourValue = require("presets/colour_value")
local preview = {}

-- Keep the bank-style label centred while the native field owns editing,
-- selection and long-name scrolling. PrettyUI may temporarily clip the field.
function preview.new(input, managedInput, label, background, bindings)
    local alignmentContent, alignmentWidth, alignmentHeight, alignmentFont
    local view = { nativeTextVisible = false }

    function view.align(slot)
        if not background then return end
        local content, width, height = input.content or "", input.width, input.height
        local fontID = input.text.font
        local font = config.Font.FromID(fontID)
        local textWidth = content ~= "" and font:GetStringWidth(content, true) or 0
        view.nativeTextVisible = textWidth > math.max(1, width - 16)
        label.hidden = view.nativeTextVisible
        label.content = content ~= "" and content
            or bankLabels.original(bindings.labels, slot) or "Uses predefined name"
        local clipped = managedInput and managedInput._unclippedAppearance
        local rgba = view.nativeTextVisible and (label.rgba or 0) or 0
        if clipped then
            clipped.textRGBA = rgba
        else
            input.text.rgba = rgba
            if not view.nativeTextVisible then input.text.isShadowed = false end
        end
        if content == alignmentContent and width == alignmentWidth
            and height == alignmentHeight and fontID == alignmentFont then return end
        alignmentContent, alignmentWidth, alignmentHeight, alignmentFont = content, width, height, fontID
        -- Native fields honour text alignment only for their placeholder.
        local left = math.min(255, math.max(8, math.floor((width - textWidth - 2) / 2)))
        -- Centre the glyph bounds rather than the font's line spacing.
        local baseline = math.floor((height - font.maxAscent - font.maxDescent) / 2) + font.maxAscent
        local top = math.min(255, math.max(0, baseline - font.baseline))
        input.contentMargin = ui.Margin.new(left, top, 8, 0)
    end

    function view.update(slot, colours)
        if not background then return end
        local visual = bankLabels.visual(bindings.labels, slot)
        local clipped = managedInput and managedInput._unclippedAppearance
        if visual then
            if visual.font ~= nil then input.text.font = visual.font end
            if visual.shadowRGBA ~= nil then input.text.shadowRGBA = visual.shadowRGBA end
            if visual.isShadowed ~= nil then
                if clipped then clipped.isShadowed = visual.isShadowed
                else input.text.isShadowed = visual.isShadowed end
            end
        end
        label.font = input.text.font
        label.isShadowed = not visual or visual.isShadowed ~= false
        view.align(slot)
        background.rgba = colourValue.rgba(colours.background)
            or bankAppearance.original(bindings.appearance, slot, "background") or 0x292520FF
        local text = colourValue.rgba(colours.text)
            or bankAppearance.original(bindings.appearance, slot, "text") or 0xB8AD9DFF
        label.rgba = text
        -- Update PrettyUI's restore state instead of leaking clipped native text.
        if clipped then
            clipped.textRGBA = view.nativeTextVisible and text or 0
            clipped.emptyTextRGBA, clipped.caretRGBA = text, text
            clipped.isShadowed = view.nativeTextVisible and label.isShadowed or false
        else
            input.text.rgba = view.nativeTextVisible and text or 0
            input.text.isShadowed = view.nativeTextVisible and label.isShadowed or false
            input.emptyTextRGBA, input.caretRGBA = text, text
        end
    end

    return view
end

return preview
