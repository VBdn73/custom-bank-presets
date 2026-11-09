-- A small, reusable viewport keeps broad searches within the client UI ID limit.
local index = require("presets/item_search")
local searchView = {}

function searchView.new(parent, prettyui)
    local title = ui.Text.new(parent)
    title.font, title.content = id.Font.MUSEO_SANS_11PT_REGULAR, "Item search"
    local field = ui.InputField.new(parent)
    field.stylesheetID = id.StyleSheet.INPUT_DEFAULT
    field:Setup(ui.TextContentVisibilityMode.VISIBLE, ui.InputFieldFilterMode.NONE, 80)
    field.emptyText, field.content = "Search item names", ""
    local status = ui.Text.new(parent)
    status.font = id.Font.MUSEO_SANS_11PT_REGULAR
    local previewIcon = ui.Sprite.new(parent)
    previewIcon:SetAssociatedObject(0)
    previewIcon.hidden = true
    local preview = ui.Text.new(parent)
    preview.font = id.Font.MUSEO_SANS_11PT_REGULAR
    preview.content = "Select an item to preview it."

    local viewport = ui.Layer.new(parent)
    local scroll = prettyui.SimpleView.new(viewport, { width = 1, height = 1 })
    local rows, matches = {}, {}
    local width, height = 1, 1
    local rowHeight = 30

    local function updateResults(resetScroll)
        matches = index.search(field.content)
        scroll:SetContentHeight(#matches * rowHeight)
        if resetScroll then scroll:SetScrollPosition(0) end
        if field.content:match("%S") then
            status.content = string.format("%d matches%s", #matches,
                index.next <= index.maxId and " (indexing...)" or "")
        else
            status.content = "Enter a name to build the item index."
        end
    end

    field:Subscribe(ui.Hook.ONCONTENTCHANGED, function(_, reason)
        if reason == ui.InputFieldActionResult.CONTENT_CHANGE then updateResults(true) end
        return false
    end)

    local function addRow()
        local row = {}
        row.button = ui.Button.new(scroll.content)
        row.button.stylesheetID = id.StyleSheet.BUTTON_DEFAULT
        row.icon = ui.Sprite.new(scroll.content)
        row.icon.clickthrough = true
        row.label = ui.Text.new(scroll.content)
        row.label.font, row.label.clickthrough = id.Font.MUSEO_SANS_11PT_REGULAR, true
        row.label.alignVertical = ui.AlignMode.CENTRE
        row.button:Subscribe(ui.Hook.ONBUTTONPRESSED, function()
            if row.item then
                previewIcon:SetAssociatedObject(row.item.id)
                previewIcon.hidden = false
                preview.content = row.item.name .. " (" .. row.item.id .. ")"
            end
            return true
        end)
        row.button:Subscribe(ui.Hook.ONSCROLLWHEEL, function(_, delta)
            if not scroll.scrollbarVisible then return true end
            scroll:ScrollBy(delta * rowHeight)
            return false
        end)
        rows[#rows + 1] = row
    end

    local function resize(y, availableWidth, availableHeight)
        width = math.max(1, (availableWidth or parent.width) - 16)
        height = math.max(1, (availableHeight or parent.height) - y - 116)
        title:SetPos(8, y); title:SetSize(width, 22)
        field:SetPos(8, y + 24); field:SetSize(width, 25)
        status:SetPos(8, y + 52); status:SetSize(width, 22)
        viewport:SetPos(8, y + 76); viewport:SetSize(width, height)
        scroll:SetSize(width, height)
        previewIcon:SetPos(8, y + 80 + height); previewIcon:SetSize(36, 32)
        preview:SetPos(50, y + 80 + height); preview:SetSize(math.max(1, width - 42), 32)
    end

    local function refresh()
        if field.content:match("%S") and index.next <= index.maxId
            and config and config.Obj and config.Obj.FromID then
            local done = index.step(500, config.Obj.FromID)
            if done or index.next % 5000 == 0 then updateResults(false) end
        end
        local needed = math.min(#matches, math.ceil(height / rowHeight) + 2)
        while #rows < needed do addRow() end
        local first = math.floor((scroll.scrollY or 0) / rowHeight) + 1
        local contentWidth = math.max(1, scroll.contentWidth or width)
        for i, row in ipairs(rows) do
            local position = first + i - 1
            local item = matches[position]
            local y = (position - 1) * rowHeight
            local visible = item ~= nil and y >= (scroll.scrollY or 0)
                and y + 26 <= (scroll.scrollY or 0) + height
            local changedItem = row.item ~= item
            row.item = item
            row.button:SetPos(0, y); row.button:SetSize(contentWidth, 26)
            row.icon:SetPos(5, y); row.icon:SetSize(29, 26)
            row.label:SetPos(38, y); row.label:SetSize(math.max(1, contentWidth - 42), 26)
            row.button.hidden, row.icon.hidden, row.label.hidden = not visible, not visible, not visible
            row.label.content = item and (item.name .. " (" .. item.id .. ")") or ""
            if item and changedItem then row.icon:SetAssociatedObject(item.id) end
        end
    end
    updateResults(false)
    return resize, refresh, function()
        scroll:Destroy()
        viewport:Destroy()
        title:Destroy(); field:Destroy(); status:Destroy(); previewIcon:Destroy(); preview:Destroy()
    end
end

return searchView
