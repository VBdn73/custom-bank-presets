local layout = require("editor/layout")
local icon = {}

-- Native states are separate sprites, not ui.Button's stacked spritesheet.
function icon.new(parent, idle, hover, pressed, action)
    local control = ui.Sprite.new(parent)
    control:SetSize(layout.popupCloseSize, layout.popupCloseSize)
    control.clickthrough = false
    control.sprite = idle
    control:Subscribe(ui.Hook.ONCLICK, action)
    return control, function()
        control.sprite = control.isMouseOver
            and (control.isClicked and pressed or hover) or idle
    end
end

function icon.info(parent, action)
    return icon.new(parent, id.Sprite.RS3_BUTTON_INFO_PARENT_0,
        id.Sprite.RS3_BUTTON_INFO_PARENT_1, id.Sprite.RS3_BUTTON_INFO_PARENT_2, action)
end

function icon.close(parent, action)
    return icon.new(parent, id.Sprite.RS3_BUTTON_CLOSE_PARENT_0,
        id.Sprite.RS3_BUTTON_CLOSE_PARENT_1, id.Sprite.RS3_BUTTON_CLOSE_PARENT_2, action)
end

return icon
