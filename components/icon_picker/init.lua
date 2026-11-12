-- Reusable native-asset picker with a virtualized scrolling grid.
local picker = {}
local constants = require("constants")
local overlayPosition = require("components/overlay_position")
local controlFactory = require("components/icon_picker/controls")
local sprites = require("components/icon_picker/sprites")
local tooltips = require("components/icon_picker/tooltip")
local defaultTheme = {
    border = { 0.58, 0.48, 0.28, 1 },
    background = { 0.14, 0.13, 0.11, 1 },
}

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
        searchCategory = { key = "search", name = "Search", entries = {} }
        table.insert(categories, 1, searchCategory)
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
    local width, height, updateSearchIndex, updateScroll
    local function updatePosition()
        if closed then return end
        overlayPosition.beside(root, parent, options.anchor or host, width, height)
    end
    local function build()
        local theme = options.theme or defaultTheme
        local controls = controlFactory.new(ui, id, Vector4, function() return closed end)
        local rectangle, text, button = controls.rectangle, controls.text, controls.button
        local renderSprite = sprites.new(ui, id, options, print)
        local function select(key)
            if closed then return end
            close()
            options.onSelect(key)
        end
        width = math.min(300, parent.width)
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
        -- Keep the viewport bounded even for large categories.
        local rows = math.max(1, math.min(5, math.ceil(largest / columns),
            math.floor((parent.height - 176 - (tabRows - 1) * 32 - (searchCategory and 32 or 0)) / 44)))
        local footerY = gridY + rows * 44
        height = footerY + 68
        root:SetSize(width, height)
        root.clickthrough = false
        root:Subscribe(ui.Hook.ONCLICK, function() return true end)
        local backgroundBorder = rectangle(root, 0, 0, width, height, true, theme.border)
        local background = rectangle(root, 1, 1, width - 2, height - 2, true, theme.background)
        text(root, 12, 8, math.max(1, width - 48), options.title or "Choose preset icon")
        local closeButton = ui.Sprite.new(root)
        closeButton:SetPos(width - 26, 6)
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
        local selectedName = text(root, 12, footerY + 4, innerWidth, initialName)
        local grid, scroll, tooltip, tabFrames, refresh
        tabFrames = {}
        local renderedRow, scrollNeeded
        local searchField
        local function updateSearch(resetScroll)
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
                or nil
            refresh(resetScroll)
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
                if options.searchIndex.next > options.searchIndex.maxId
                    or not (config and config.Obj and config.Obj.FromID) then return end
                local done = options.searchIndex.step(constants.itemSearchBatchSize, config.Obj.FromID)
                if categories[categoryIndex] == searchCategory and searchField.content:match("%S")
                    and (done or options.searchIndex.next % constants.itemSearchRefreshInterval == 0) then updateSearch(false) end
            end
        end
        local resetWidth = math.floor((innerWidth - 4) / 2)
        local resetButton = button(root, 12, height - 40, resetWidth, 28, "Use preset number", function() select("") end)
        local blankButton = button(root, 16 + resetWidth, height - 40, innerWidth - resetWidth - 4, 28,
            "Blank", function() select("blank") end)
        for index, category in ipairs(categories) do
            local tabWidth = innerWidth / tabColumns
            local x = 12 + math.floor(((index - 1) % tabColumns) * tabWidth)
            local y = 40 + math.floor((index - 1) / tabColumns) * 32
            button(root, x, y, math.floor(tabWidth) - 2, 28, category.name, function()
                categoryIndex = index
                if category == searchCategory then updateSearch(true) else refresh(true) end
            end)
            tabFrames[index] = rectangle(root, x, y, math.floor(tabWidth) - 2, 28, false, theme.border)
        end
        local renderGrid
        refresh = function(resetScroll)
            if closed then return end
            local oldScroll = scroll and scroll.scrollY or 0
            if scroll then scroll:Destroy(); scroll = nil; grid = nil end
            if tooltip then tooltip:Destroy() end
            local category = categories[categoryIndex] or {}
            selectedName.content = category == searchCategory and searchField.content:match("%S")
                and options.searchIndex.next <= options.searchIndex.maxId
                and "Indexing... Results may be incomplete" or initialName
            gridY = searchY + (category == searchCategory and 32 or 0)
            footerY = gridY + rows * 44
            height = footerY + 68
            root:SetSize(width, height)
            backgroundBorder:SetSize(width, height)
            background:SetSize(width - 2, height - 2)
            selectedName:SetPos(12, footerY + 4)
            resetButton:SetPos(12, height - 40)
            blankButton:SetPos(16 + resetWidth, height - 40)
            updatePosition()
            assert(options.prettyui and options.prettyui.SimpleView, "PrettyUI SimpleView is required for the icon picker.")
            scroll = options.prettyui.SimpleView.new(root, {
                x = 12, y = gridY, width = math.max(1, width - 18), height = rows * 44, scrollStep = 44,
            })
            local entries = category.entries or {}
            columns = math.max(1, math.floor(innerWidth / 44))
            -- SimpleView hides its scrollbar when content fits. Reserve its width
            -- even for short lists by giving it one extra pixel of content.
            scroll:SetContentHeight(math.max(rows * 44 + 1, math.ceil(#entries / columns) * 44))
            columns = math.max(1, math.floor((scroll.contentWidth or innerWidth) / 44))
            local contentHeight = math.ceil(#entries / columns) * 44
            scrollNeeded = contentHeight > rows * 44
            scroll:SetContentHeight(math.max(rows * 44 + 1, contentHeight))
            if not scrollNeeded then
                for _, key in ipairs({ "upArrow", "downArrow", "track", "trackTop", "trackCentre", "trackBottom", "thumbDrag" }) do
                    if scroll[key] then scroll[key].enabled = false end
                end
            end
            local position = resetScroll and 0 or oldScroll
            if resetScroll == nil then
                for index, entry in ipairs(entries) do
                    if entry.key == options.initial then
                        position = math.floor((index - 1) / columns) * 44
                        break
                    end
                end
            end
            scroll:SetScrollPosition(scrollNeeded and position or 0)
            for index, frame in ipairs(tabFrames) do frame.hidden = index ~= categoryIndex end
            if searchField then searchField.hidden = category ~= searchCategory end
            renderGrid()
        end
        renderGrid = function()
            if closed or not scroll then return end
            if grid then grid:Destroy() end
            if tooltip then tooltip:Destroy() end
            local category = categories[categoryIndex] or {}
            local entries = category.entries or {}
            local firstRow = math.floor((scroll.scrollY or 0) / 44)
            renderedRow = firstRow
            grid = ui.Layer.new(scroll.content)
            grid:SetPos(0, 0)
            grid:SetSize(scroll.contentWidth or innerWidth, math.max(rows * 44, math.ceil(#entries / columns) * 44))
            grid.clickthrough = true
            if #categories == 0 then
                text(grid, 0, 0, innerWidth, "No icons available.")
            elseif #entries == 0 and category.emptyMessage then
                text(grid, 0, 0, innerWidth, category.emptyMessage)
            end
            local first = firstRow * columns + 1
            local last = math.min(#entries, (firstRow + rows + 1) * columns)
            for index = first, last do
                local entry = entries[index]
                if entry then
                    local x, y = ((index - 1) % columns) * 44, math.floor((index - 1) / columns) * 44
                    local available = false
                    local target = button(grid, x, y, 40, 40, "", function()
                        if available then select(entry.key) end
                    end)
                    target:Subscribe(ui.Hook.ONSCROLLWHEEL, "iconPicker.scroll", function(_, delta)
                        if scrollNeeded then
                            scroll:ScrollBy(delta * 44)
                            renderGrid()
                        end
                        return true
                    end)
                    available = renderSprite(grid, entry, x, y)
                    if not available then target.label = "?" end
                    local function showName()
                        if closed then return end
                        local label = entry.name .. (available and "" or " (unavailable)")
                        tooltip:show(label, x, y, gridY, scroll.scrollY or 0)
                    end
                    target:Subscribe(ui.Hook.ONMOUSEOVER, showName)
                    -- Native buttons handle activation; ONKEY also exposes the
                    -- label when keyboard interaction is delivered to a tile.
                    target:Subscribe(ui.Hook.ONKEY, showName)
                    target:Subscribe(ui.Hook.ONMOUSELEAVE, function()
                        if not closed then tooltip:hide() end
                    end)
                    if entry.key == options.initial then
                        rectangle(grid, x, y, 40, 40, false, theme.border)
                    end
                end
            end
            -- Created after the grid so it draws above every icon tile.
            tooltip = tooltips.new(root, ui, controls, theme, config)
        end
        updateScroll = function()
            if scroll and not scrollNeeded and (scroll.scrollY or 0) ~= 0 then scroll:SetScrollPosition(0) end
            if scroll and math.floor((scroll.scrollY or 0) / 44) ~= renderedRow then renderGrid() end
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
        if not closed and updateScroll then updateScroll() end
    end
end

return picker
