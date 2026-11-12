local theme = require("editor/theme")
local marks = {}

-- Antialiased diagonal crosses indicate a default colour. Each pixel remains
-- click-through so the swatch underneath still owns pointer interaction.
function marks.new(parent, x, y, trackPosition)
    local controls = {}
    for column = 0, 49 do
        local offset = column * 15 / 49
        for _, position in ipairs({ offset, 15 - offset }) do
            local row = math.floor(position)
            local fraction = position - row
            for _, pixel in ipairs({ { row, 1 - fraction }, { row + 1, fraction } }) do
                if pixel[2] > 0 then
                    local mark = ui.Rectangle.new(parent)
                    mark:SetSize(1, 1)
                    mark.fill = true
                    mark.colour = theme.colour({ 1, 1, 1, pixel[2] })
                    mark.clickthrough = true
                    trackPosition(mark, x + column, y + pixel[1])
                    controls[#controls + 1] = mark
                end
            end
        end
    end
    return controls
end

return marks
