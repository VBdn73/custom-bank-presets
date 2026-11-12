-- Resolve and fit icons independently of tile interaction and scrolling.
local sprites = {}

function sprites.new(ui, id, options, report)
    local reportedErrors = {}

    return function(parent, entry, x, y)
        local sprite
        local ok, err = pcall(function()
            local spriteID
            if options.resolve then spriteID = options.resolve(entry.key)
            else spriteID = id.Sprite[entry.sprite] end
            assert(type(spriteID) == "number" and spriteID >= 0 and spriteID % 1 == 0)
            local width, height = entry.width or 24, entry.height or 24
            assert(width > 0 and height > 0)
            sprite = ui.Sprite.new(parent)
            if options.apply then options.apply(sprite, spriteID, entry)
            else
                sprite.sprite = spriteID
                assert(sprite.spriteID == spriteID)
            end
            local iconSize = entry.objectID and 36 or 24
            local scale = math.min(iconSize / width, iconSize / height, 1)
            width = math.max(1, math.floor(width * scale))
            height = math.max(1, math.floor(height * scale))
            sprite:SetSize(width, height)
            sprite:SetPos(x + math.floor((40 - width) / 2), y + math.floor((40 - height) / 2))
            sprite.rgba = 0xFFFFFFFF
            sprite.clickthrough, sprite.enabled = true, false
        end)
        if not ok then
            if sprite then pcall(function() sprite:Destroy() end) end
            local message = tostring(err)
            if not reportedErrors[message] then
                reportedErrors[message] = true
                report("[Icon picker] Could not render " .. entry.key .. ": " .. message)
            end
        end
        return ok
    end
end

return sprites
