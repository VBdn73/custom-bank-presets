-- Reusable native-asset picker. PrettyUI supplies native pagination arrows.
local picker = {}
local defaultTheme = {
    border = { 0.58, 0.48, 0.28, 1 },
    background = { 0.14, 0.13, 0.11, 1 },
}

local function globalPosition(component)
    local position = component.xyGlobal
    if position then return position.x, position.y end
    local x, y = component.x or 0, component.y or 0
    if component.parent then
        local px, py = globalPosition(component.parent)
        x, y = x + px, y + py
    end
    return x, y
end

function picker.open(host, options)
    options = options or {}
    assert(type(options.onSelect) == "function", "Icon picker requires an onSelect callback.")
    -- Hide empty categories unless they explicitly provide an empty state.
    local categories = {}
    for _, category in ipairs(options.categories or {}) do
        if #(category.entries or {}) > 0 or category.showWhenEmpty then
            categories[#categories + 1] = category
        end
    end
    local searchCategory
    if options.searchIndex then
        searchCategory = { key = "search", name = "Search", entries = {},
            emptyMessage = "Search item names." }
        categories[#categories + 1] = searchCategory
    end
    local parent = host
    while parent.parent and not parent.parent.isRestricted do parent = parent.parent end
    local root = ui.Layer.new(parent)
    local closed, detachOverlay = false, nil
    local function close()
        if closed then return end
        closed = true
        -- Disposed hosts and faulty overlay hooks must not leave the popup alive.
        if detachOverlay then pcall(detachOverlay) end
        pcall(function() root:Destroy() end)
        if options.onClose then options.onClose() end
    end
    local width, height, updateSearchIndex
    local function updatePosition()
        if closed then return end
        local target = options.anchor or host
        local ax, ay = globalPosition(target)
        local px, py = globalPosition(parent)
        local x, y = ax - px + target.width + 8, ay - py
        if x + width > parent.width then x = ax - px - width - 8 end
        root:SetPos(math.max(0, math.min(x, parent.width - width)),
            math.max(0, math.min(y, parent.height - height)))
    end
    local function build()
        local theme = options.theme or defaultTheme
        local function rectangle(parent, x, y, w, h, filled, tint)
            local control = ui.Rectangle.new(parent)
            control:SetPos(x, y)
            control:SetSize(w, h)
            control.fill = filled
            control.colour = Vector4.new(tint[1], tint[2], tint[3], tint[4])
            control.clickthrough = not filled
            return control
        end
        local function text(parent, x, y, w, content)
            local control = ui.Text.new(parent)
            control:SetPos(x, y)
            control:SetSize(w, 24)
            control.font = id.Font.MUSEO_SANS_11PT_REGULAR or id.Font.MUSEO_SANS_15PT_REGULAR
            control.content = content
            control.clickthrough = true
            return control
        end
        local function button(parent, x, y, w, h, label, action)
            local control = ui.Button.new(parent)
            control:SetPos(x, y)
            control:SetSize(w, h)
            control.stylesheetID = id.StyleSheet.BUTTON_DEFAULT
            control.label = label
            control:Subscribe(ui.Hook.ONBUTTONPRESSED, function()
                if not closed then action() end
            end)
            return control
        end
        local function select(key)
            if closed then return end
            close()
            options.onSelect(key)
        end
        width = math.min(288, parent.width)
        local innerWidth = math.max(1, width - 24)
        local columns = math.max(1, math.floor(innerWidth / 44))
        local tabColumns = math.max(1, math.min(#categories, math.max(1, math.floor(innerWidth / 80))))
        local tabRows = math.max(1, math.ceil(#categories / tabColumns))
        local searchY = 76 + (tabRows - 1) * 32
        local gridY = searchY + (searchCategory and 32 or 0)
        local largest = searchCategory and 1000 or 0
        local categoryIndex = 1
        local initialName = options.initialName or "Use preset number"
        for index, category in ipairs(categories) do
            largest = math.max(largest, #(category.entries or {}))
            for _, entry in ipairs(category.entries or {}) do
                if entry.key == options.initial then
                    categoryIndex, initialName = index, entry.name
                end
            end
        end
        -- Pagination keeps larger future categories within the same popup layout.
        local rows = math.max(1, math.min(5, math.ceil(largest / columns),
            math.floor((parent.height - 176 - (tabRows - 1) * 32 - (searchCategory and 32 or 0)) / 44)))
        local capacity = rows * columns
        local paginated = largest > capacity
        local footerY = gridY + rows * 44
        height = footerY + (paginated and 100 or 68)
        root:SetSize(width, height)
        root.clickthrough = false
        root:Subscribe(ui.Hook.ONCLICK, function() return true end)
        rectangle(root, 0, 0, width, height, true, theme.border)
        rectangle(root, 1, 1, width - 2, height - 2, true, theme.background)
        text(root, 12, 8, math.max(1, width - 48), options.title or "Choose preset icon")
        local closeButton = ui.Sprite.new(root)
        closeButton:SetPos(width - 32, 8)
        closeButton:SetSize(20, 20)
        closeButton.clickthrough = false
        closeButton.sprite = id.Sprite.RS3_BTN_MODAL_WINDOW_1_CLOSE_NML
        closeButton:Subscribe(ui.Hook.ONMOUSEOVER, function()
            if not closed then closeButton.sprite = id.Sprite.RS3_BTN_MODAL_WINDOW_1_CLOSE_OVR end
        end)
        closeButton:Subscribe(ui.Hook.ONMOUSELEAVE, function()
            if not closed then closeButton.sprite = id.Sprite.RS3_BTN_MODAL_WINDOW_1_CLOSE_NML end
        end)
        closeButton:Subscribe(ui.Hook.ONCLICK, function() close(); return true end)
        text(root, 12, footerY + 4, innerWidth, initialName)
        local page = 1
        -- Start on the page containing the current selection.
        for index, entry in ipairs((categories[categoryIndex] or {}).entries or {}) do
            if entry.key == options.initial then page = math.ceil(index / capacity) end
        end
        local grid, tooltip, tooltipBackground, tooltipInner, tooltipLabel, tabFrames, refresh = nil, nil, nil, nil, nil, {}, nil
        local searchField
        local function updateSearch(resetPage)
            local entries = {}
            for _, item in ipairs(options.searchIndex.search(searchField.content)) do
                if item.id > 0 then
                    entries[#entries + 1] = { key = "item:" .. item.id, name = item.name,
                        objectID = item.id, width = 36, height = 32 }
                end
            end
            searchCategory.entries = entries
            searchCategory.emptyMessage = searchField.content:match("%S")
                and (options.searchIndex.next <= options.searchIndex.maxId and "Indexing items..." or "No items found.")
                or "Search item names."
            if resetPage then page = 1 end
            page = math.min(page, math.max(1, math.ceil(#entries / capacity)))
            refresh()
        end
        if searchCategory then
            searchField = ui.InputField.new(root)
            searchField.stylesheetID = id.StyleSheet.INPUT_DEFAULT
            searchField:Setup(ui.TextContentVisibilityMode.VISIBLE, ui.InputFieldFilterMode.NONE, 80)
            searchField.emptyText, searchField.content = "Search item names", ""
            searchField:SetPos(12, searchY); searchField:SetSize(innerWidth, 25)
            searchField:Subscribe(ui.Hook.ONCONTENTCHANGED, function(_, reason)
                if reason == ui.InputFieldActionResult.CONTENT_CHANGE then updateSearch(true) end
                return false
            end)
            updateSearchIndex = function()
                if categories[categoryIndex] ~= searchCategory or not searchField.content:match("%S")
                    or options.searchIndex.next > options.searchIndex.maxId
                    or not (config and config.Obj and config.Obj.FromID) then return end
                local done = options.searchIndex.step(500, config.Obj.FromID)
                if done or options.searchIndex.next % 5000 == 0 then updateSearch(false) end
            end
        end
        local reportedErrors = {}
        local pageLabel, previousButton, nextButton
        if paginated then
            local spriteButton = assert(options.prettyui and options.prettyui.SpriteButton,
                "PrettyUI SpriteButton is required for icon picker pagination.")
            previousButton = spriteButton.new(root, "ARROW_LEFT", function()
                if closed then return end
                page = math.max(1, page - 1)
                refresh()
            end, { x = 12, y = footerY + 30, size = 28 })
            pageLabel = text(root, 48, footerY + 32, math.max(1, innerWidth - 72), "")
            pageLabel.alignHorizontal = ui.AlignMode.CENTRE
            nextButton = spriteButton.new(root, "ARROW_RIGHT", function()
                if closed then return end
                page = math.min(math.max(1, math.ceil(#(categories[categoryIndex].entries or {}) / capacity)), page + 1)
                refresh()
            end, { x = width - 40, y = footerY + 30, size = 28 })
        end
        button(root, 12, height - 40, innerWidth, 28, "Use preset number", function() select("") end)
        for index, category in ipairs(categories) do
            local tabWidth = innerWidth / tabColumns
            local x = 12 + math.floor(((index - 1) % tabColumns) * tabWidth)
            local y = 40 + math.floor((index - 1) / tabColumns) * 32
            button(root, x, y, math.floor(tabWidth) - 2, 28, category.name, function()
                categoryIndex, page = index, 1
                refresh()
            end)
            tabFrames[index] = rectangle(root, x, y, math.floor(tabWidth) - 2, 28, false, theme.border)
        end
        refresh = function()
            if closed then return end
            if grid then grid:Destroy() end
            if tooltip then tooltip:Destroy() end
            grid = ui.Layer.new(root)
            grid:SetPos(12, gridY)
            grid:SetSize(innerWidth, rows * 44)
            grid.clickthrough = true
            for index, frame in ipairs(tabFrames) do frame.hidden = index ~= categoryIndex end
            local category = categories[categoryIndex] or {}
            if searchField then searchField.hidden = category ~= searchCategory end
            local entries = category.entries or {}
            if #categories == 0 then
                text(grid, 0, 0, innerWidth, "No icons available.")
            elseif #entries == 0 and category.emptyMessage then
                text(grid, 0, 0, innerWidth, category.emptyMessage)
            end
            if pageLabel then
                local pages = math.max(1, math.ceil(#entries / capacity))
                pageLabel.content = page .. " / " .. pages
                previousButton:SetDisabled(page <= 1)
                nextButton:SetDisabled(page >= pages)
            end
            for offset = 1, capacity do
                local entry = entries[(page - 1) * capacity + offset]
                if entry then
                    local x, y = ((offset - 1) % columns) * 44, math.floor((offset - 1) / columns) * 44
                    local available = false
                    local target = button(grid, x, y, 40, 40, "", function()
                        if available then select(entry.key) end
                    end)
                    local sprite
                    local ok, err = pcall(function()
                        local spriteID
                        if options.resolve then spriteID = options.resolve(entry.key)
                        else spriteID = id.Sprite[entry.sprite] end
                        assert(type(spriteID) == "number" and spriteID >= 0 and spriteID % 1 == 0)
                        local w, h = entry.width or 24, entry.height or 24
                        assert(w > 0 and h > 0)
                        sprite = ui.Sprite.new(grid)
                        if options.apply then options.apply(sprite, spriteID, entry)
                        else
                            sprite.sprite = spriteID
                            assert(sprite.spriteID == spriteID)
                        end
                        local iconSize = entry.objectID and 36 or 24
                        local scale = math.min(iconSize / w, iconSize / h, 1)
                        w, h = math.max(1, math.floor(w * scale)), math.max(1, math.floor(h * scale))
                        sprite:SetSize(w, h)
                        sprite:SetPos(x + math.floor((40 - w) / 2), y + math.floor((40 - h) / 2))
                        sprite.rgba = 0xFFFFFFFF
                        sprite.clickthrough, sprite.enabled = true, false
                    end)
                    available = ok
                    if not ok then
                        if sprite then pcall(function() sprite:Destroy() end) end
                        target.label = "?"
                        local message = tostring(err)
                        if not reportedErrors[message] then
                            reportedErrors[message] = true
                            print("[Icon picker] Could not render " .. entry.key .. ": " .. message)
                        end
                    end
                    local function showName()
                        if closed then return end
                        local label = entry.name .. (available and "" or " (unavailable)")
                        local font
                        if config and config.Font and config.Font.FromID then
                            local ok, result = pcall(config.Font.FromID, tooltipLabel.font)
                            if ok then font = result end
                        end
                        local function measure(value)
                            if font then
                                local ok, result = pcall(function() return font:GetStringWidth(value, true) end)
                                if ok and type(result) == "number" then return result end
                            end
                            return #value * 8
                        end
                        local tooltipWidth = math.min(width - 8, math.max(60, measure(label) + 16))
                        local textWidth = math.max(1, tooltipWidth - 12)
                        local lines, line = 1, ""
                        for word in label:gmatch("%S+") do
                            local nextLine = line == "" and word or line .. " " .. word
                            if line ~= "" and measure(nextLine) > textWidth then
                                lines, line = lines + 1, word
                            else
                                line = nextLine
                            end
                        end
                        local tooltipHeight = math.max(26, lines * 18 + 8)
                        local tooltipX = math.max(4, math.min(12 + x, width - tooltipWidth - 4))
                        local tooltipY = gridY + y - tooltipHeight - 2
                        if tooltipY < gridY then tooltipY = gridY + y + 40 end
                        tooltipY = math.max(0, math.min(tooltipY, height - tooltipHeight))
                        tooltip:SetPos(tooltipX, tooltipY)
                        tooltip:SetSize(tooltipWidth, tooltipHeight)
                        tooltipBackground:SetSize(tooltipWidth, tooltipHeight)
                        tooltipInner:SetSize(tooltipWidth - 2, tooltipHeight - 2)
                        tooltipLabel:SetSize(textWidth, tooltipHeight - 2)
                        tooltipLabel.maxLines = lines
                        tooltipLabel.content = label
                        tooltip.hidden = false
                    end
                    target:Subscribe(ui.Hook.ONMOUSEOVER, showName)
                    -- Native buttons handle activation; ONKEY also exposes the
                    -- label when keyboard interaction is delivered to a tile.
                    target:Subscribe(ui.Hook.ONKEY, showName)
                    target:Subscribe(ui.Hook.ONMOUSELEAVE, function()
                        if not closed then tooltip.hidden = true end
                    end)
                    if entry.key == options.initial then
                        rectangle(grid, x, y, 40, 40, false, theme.border)
                    end
                end
            end
            -- Created after the grid so it draws above every icon tile.
            tooltip = ui.Layer.new(root)
            tooltip.clickthrough = true
            tooltipBackground = rectangle(tooltip, 0, 0, 60, 26, true, theme.border)
            tooltipInner = rectangle(tooltip, 1, 1, 58, 24, true, theme.background)
            tooltipBackground.clickthrough, tooltipInner.clickthrough = true, true
            tooltipLabel = text(tooltip, 6, 1, 48, "")
            tooltipLabel.alignVertical = ui.AlignMode.CENTRE
            tooltip.hidden = true
        end
        refresh()
        updatePosition()
        if options.attachOverlay then detachOverlay = options.attachOverlay(root, updatePosition) end
    end
    local ok, err = pcall(build)
    if not ok then
        closed = true
        if detachOverlay then pcall(detachOverlay) end
        pcall(function() root:Destroy() end)
        error(err, 0)
    end
    return close, function()
        updatePosition()
        if not closed and updateSearchIndex then updateSearchIndex() end
    end
end

return picker
