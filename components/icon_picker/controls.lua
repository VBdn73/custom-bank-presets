-- Bind native controls to this picker's environment and lifetime.
local controls = {}

function controls.new(ui, id, Vector4, isClosed)
    local factory = {}

    function factory.rectangle(parent, x, y, width, height, filled, tint)
        local control = ui.Rectangle.new(parent)
        control:SetPos(x, y)
        control:SetSize(width, height)
        control.fill = filled
        control.colour = Vector4.new(tint[1], tint[2], tint[3], tint[4])
        control.clickthrough = not filled
        return control
    end

    function factory.text(parent, x, y, width, content)
        local control = ui.Text.new(parent)
        control:SetPos(x, y)
        control:SetSize(width, 24)
        control.font = id.Font.MUSEO_SANS_11PT_REGULAR or id.Font.MUSEO_SANS_15PT_REGULAR
        control.content = content
        control.clickthrough = true
        return control
    end

    function factory.button(parent, x, y, width, height, label, action)
        local control = ui.Button.new(parent)
        control:SetPos(x, y)
        control:SetSize(width, height)
        control.stylesheetID = id.StyleSheet.BUTTON_DEFAULT
        control.label = label
        control:Subscribe(ui.Hook.ONBUTTONPRESSED, function()
            if not isClosed() then action() end
        end)
        return control
    end

    return factory
end

return controls
