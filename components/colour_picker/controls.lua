-- Native controls bound to one colour picker and its client environment.
local controls = {}

function controls.new(root, ui, id, Vector4)
    local factory = {}

    function factory.colour(rgba)
        return Vector4.new(rgba[1], rgba[2], rgba[3], rgba[4])
    end

    function factory.rectangle(x, y, width, height, tint, action)
        local box = ui.Rectangle.new(root)
        box:SetPos(x, y)
        box:SetSize(width, height)
        box.fill = true
        box.colour = factory.colour(tint)
        box.clickthrough = false
        if action then box:Subscribe(ui.Hook.ONCLICK, action) end
        return box
    end

    function factory.text(x, y, width, content)
        local label = ui.Text.new(root)
        label:SetPos(x, y)
        label:SetSize(width, 24)
        label.font = id.Font.MUSEO_SANS_11PT_REGULAR or id.Font.MUSEO_SANS_15PT_REGULAR
        label.content = content
        label.clickthrough = true
        return label
    end

    function factory.closeButton(x, y, close)
        local button = ui.Sprite.new(root)
        button:SetPos(x, y)
        button:SetSize(20, 20)
        button.clickthrough = false
        button.sprite = id.Sprite.RS3_BTN_MODAL_WINDOW_1_CLOSE_NML
        button:Subscribe(ui.Hook.ONMOUSEOVER, function()
            button.sprite = id.Sprite.RS3_BTN_MODAL_WINDOW_1_CLOSE_OVR
        end)
        button:Subscribe(ui.Hook.ONMOUSELEAVE, function()
            button.sprite = id.Sprite.RS3_BTN_MODAL_WINDOW_1_CLOSE_NML
        end)
        button:Subscribe(ui.Hook.ONCLICK, function() close(); return true end)
        return button
    end

    function factory.hexInput(x, y, width, height, selected)
        local input = ui.InputField.new(root)
        input:SetPos(x, y)
        input:SetSize(width, height)
        input.stylesheetID = id.StyleSheet.INPUT_DEFAULT
        input:Setup(ui.TextContentVisibilityMode.VISIBLE, ui.InputFieldFilterMode.NONE, 7)
        input.content = selected
        return input
    end

    return factory
end

return controls
