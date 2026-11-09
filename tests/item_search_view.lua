local test = require("tests.test_helper")

test.case("Settings item search scrolls, previews and cleans up", function()
    local oldUI, oldID, oldConfig = ui, id, config
    local oldIndex = package.loaded["presets/item_search"]
    local entries = {}
    for i = 1, 100 do entries[i] = { id = i, name = string.format("Widget %03d", i) } end
    package.loaded["presets/item_search"] = { next = 70001, maxId = 70000,
        search = function(query) return query == "widget" and entries or {} end }
    local controls = {}
    local function control(kind, parent)
        local c = { kind = kind, parent = parent, hooks = {} }
        function c:SetPos(x, y) self.x, self.y = x, y end
        function c:SetSize(w, h) self.width, self.height = w, h end
        function c:Subscribe(hook, callback) self.hooks[hook] = callback end
        function c:Setup() end
        function c:SetAssociatedObject(itemId) self.itemId = itemId end
        function c:Destroy() self.destroyed = true end
        controls[#controls + 1] = c
        return c
    end
    ui = { Hook = { ONCONTENTCHANGED = "change", ONBUTTONPRESSED = "press", ONSCROLLWHEEL = "wheel" },
        InputFieldActionResult = { CONTENT_CHANGE = 1 }, TextContentVisibilityMode = { VISIBLE = 1 },
        InputFieldFilterMode = { NONE = 1 }, AlignMode = { CENTRE = 1 } }
    for _, kind in ipairs({ "Text", "InputField", "Sprite", "Layer", "Button" }) do
        ui[kind] = { new = function(parent) return control(kind, parent) end }
    end
    id = { Font = { MUSEO_SANS_11PT_REGULAR = 1 }, StyleSheet = { INPUT_DEFAULT = 1, BUTTON_DEFAULT = 2 } }
    config = nil
    local ok, err = pcall(function()
        local scroll
        local pretty = { SimpleView = { new = function(parent)
            scroll = { content = control("scrollContent", parent), scrollY = 0, contentWidth = 350 }
            function scroll:SetSize(w, h) self.width, self.height = w, h end
            function scroll:SetContentHeight(h) self.contentHeight, self.scrollbarVisible = h, h > (self.height or 1) end
            function scroll:SetScrollPosition(y) self.scrollY = y end
            function scroll:ScrollBy(y) self.scrollY = math.max(0, self.scrollY + y) end
            function scroll:Destroy() self.destroyed = true end
            return scroll
        end } }
        local parent = { width = 400, height = 600 }
        local resize, refresh, destroy = require("editor/item_search_view").new(parent, pretty)
        resize(120)
        local field
        for _, c in ipairs(controls) do if c.kind == "InputField" then field = c end end
        field.content = "widget"
        field.hooks.change(field, 1)
        refresh()
        test.equal(scroll.contentHeight, 3000)
        local button, label
        for _, c in ipairs(controls) do
            if c.parent == scroll.content and c.kind == "Button" and c.y == 0 then button = c end
            if c.parent == scroll.content and c.kind == "Text" and c.y == 0 then label = c end
        end
        test.equal(label.content, "Widget 001 (1)")
        button.hooks.press()
        local foundPreview = false
        for _, c in ipairs(controls) do
            if c.parent == parent and c.kind == "Text" and c.content == "Widget 001 (1)" then foundPreview = true end
        end
        test.equal(foundPreview, true)
        scroll:SetScrollPosition(600)
        refresh()
        test.equal(label.content, "Widget 021 (21)")
        test.equal(#controls < 100, true)
        field.content = "missing"
        field.hooks.change(field, 1)
        refresh()
        test.equal(scroll.scrollY, 0)
        test.equal(button.hidden, true)
        destroy()
        test.equal(scroll.destroyed, true)
        test.equal(field.destroyed, true)
    end)
    ui, id, config = oldUI, oldID, oldConfig
    package.loaded["presets/item_search"] = oldIndex
    package.loaded["editor/item_search_view"] = nil
    assert(ok, err)
end)
