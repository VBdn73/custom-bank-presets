local test = require("tests.test_helper")

local function fixture(options)
    local f = { controls = {}, selected = {}, closed = 0, detached = 0, messages = {} }
    local function new(kind, parent)
        local control = { kind = kind, parent = parent, hooks = {}, children = {} }
        if parent then parent.children[#parent.children + 1] = control end
        function control:SetPos(x, y) self.x, self.y = x, y end
        function control:SetSize(w, h) self.width, self.height = w, h end
        function control:Setup() end
        function control:Subscribe(hook, action) self.hooks[hook] = action end
        function control:Destroy()
            self.destroyed = true
            for _, child in ipairs(self.children) do child:Destroy() end
        end
        setmetatable(control, { __index = function(self, key)
            if key == "spriteID" then return self.sprite end
        end })
        f.controls[#f.controls + 1] = control
        return control
    end
    local hooks = { ONCLICK = "click", ONBUTTONPRESSED = "press", ONMOUSEOVER = "over",
        ONMOUSELEAVE = "leave", ONKEY = "key", ONCONTENTCHANGED = "change" }
    local environment = setmetatable({
        print = function(message) f.messages[#f.messages + 1] = message end,
        ui = { Hook = hooks, AlignMode = { CENTRE = "centre" },
            TextContentVisibilityMode = { VISIBLE = 1 }, InputFieldFilterMode = { NONE = 1 },
            InputFieldActionResult = { CONTENT_CHANGE = 1 } },
        id = { Font = { MUSEO_SANS_11PT_REGULAR = 1 }, StyleSheet = { BUTTON_DEFAULT = 1, INPUT_DEFAULT = 2 },
            Sprite = { FARM = 10, WIDE = 11, RS3_BTN_MODAL_WINDOW_1_CLOSE_NML = 20,
                RS3_BTN_MODAL_WINDOW_1_CLOSE_OVR = 21 } },
        Vector4 = { new = function(...) return { ... } end },
    }, { __index = _G })
    for _, kind in ipairs({ "Layer", "Rectangle", "Text", "Button", "Sprite", "InputField" }) do
        environment.ui[kind] = { new = function(parent) return new(kind, parent) end }
    end
    f.parent = new("host")
    f.parent:SetPos(20, 30)
    f.parent:SetSize(1000, 700)
    f.host = new("host", f.parent)
    f.host:SetPos(100, 100)
    f.host:SetSize(300, 400)
    f.anchor = new("anchor", f.host)
    f.anchor:SetPos(10, 20)
    f.anchor:SetSize(40, 30)
    f.options = {
        prettyui = { SpriteButton = { new = function(parent, spriteName, action, options)
            local control = new("Arrow", parent)
            control.spriteName = spriteName
            control:SetPos(options.x, options.y)
            control:SetSize(options.size, options.size)
            function control:SetDisabled(disabled) self.disabled = disabled end
            control.hooks.press = function() if not control.disabled then action() end end
            return control
        end } },
        categories = { { key = "skills", name = "Skills", entries = {
            { key = "skills:farming", name = "Farming", sprite = "FARM", width = 35, height = 35 },
            { key = "skills:wide", name = "Wide", sprite = "WIDE", width = 48, height = 24 },
            { key = "skills:missing", name = "Missing", sprite = "MISSING" },
        } } },
        initial = "skills:farming", anchor = f.anchor,
        onSelect = function(key)
            test.equal(f.closed, 1, "Close and overlay detach precede selection")
            test.equal(f.detached, 1)
            f.selected[#f.selected + 1] = key
        end,
        onClose = function() f.closed = f.closed + 1 end,
        attachOverlay = function(root, reposition)
            f.root, f.reposition = root, reposition
            return function() f.detached = f.detached + 1 end
        end,
    }
    for key, value in pairs(options or {}) do f.options[key] = value end
    f.picker = assert(loadfile("components/icon_picker/init.lua", "t", environment))()
    function f.open() f.close, f.update = f.picker.open(f.host, f.options) end
    function f.find(kind, predicate)
        local result = {}
        for _, control in ipairs(f.controls) do
            if not control.destroyed and control.kind == kind and (not predicate or predicate(control)) then
                result[#result + 1] = control
            end
        end
        return result
    end
    function f.tiles() return f.find("Button", function(c) return c.label == "" or c.label == "?" end) end
    return f
end

test.case("Search tab displays selectable item tiles and paginates results", function()
    local entries = {}
    for i = 1, 35 do entries[i] = { id = i, name = "Widget " .. i } end
    local index = { next = 70001, maxId = 70000,
        search = function(query) return query == "widget" and entries or {} end }
    local f = fixture({ searchIndex = index, resolve = function(key) return tonumber(key:match("%d+")) end,
        apply = function(sprite, assetID) sprite.sprite = assetID end })
    f.open()
    local field = f.find("InputField")[1]
    test.equal(field.hidden, true)
    f.find("Button", function(c) return c.label == "Search" end)[1].hooks.press()
    test.equal(field.hidden, false)
    field.content = "widget"
    field.hooks.change(field, 1)
    test.equal(#f.tiles(), 30)
    f.tiles()[1].hooks.over()
    test.equal(#f.find("Text", function(c) return c.content == "Widget 1" end), 1)
    f.find("Arrow", function(c) return c.spriteName == "ARROW_RIGHT" end)[1].hooks.press()
    test.equal(#f.tiles(), 5)
    f.tiles()[1].hooks.press()
    test.equal(f.selected[1], "item:31")
end)

test.case("Icon picker selects once, highlights selection and exposes hover/keyboard labels", function()
    local f = fixture()
    f.open()
    test.equal(#f.tiles(), 3)
    local frames = f.find("Rectangle", function(c) return c.fill == false and c.width == 40 end)
    test.equal(#frames, 1)
    test.equal(frames[1].clickthrough, true)
    local farming = f.find("Sprite", function(c) return c.sprite == 10 end)[1]
    test.equal(farming.width, 24)
    test.equal(farming.rgba, 0xFFFFFFFF)
    test.equal(farming.clickthrough, true)
    local wide = f.find("Sprite", function(c) return c.sprite == 11 end)[1]
    test.equal(wide.width, 24)
    test.equal(wide.height, 12)
    local tiles = f.tiles()
    local selectedName = f.find("Text", function(c) return c.content == "Farming" end)[1]
    tiles[2].hooks.over()
    local hoverName = f.find("Text", function(c) return c.content == "Wide" end)[1]
    test.equal(selectedName.content, "Farming")
    test.equal(hoverName.parent.hidden, false)
    test.equal(hoverName.parent.clickthrough, true)
    tiles[2].hooks.leave()
    test.equal(hoverName.parent.hidden, true)
    test.equal(selectedName.content, "Farming")
    tiles[2].hooks.key()
    test.equal(hoverName.parent.hidden, false)
    test.equal(selectedName.content, "Farming")
    tiles[2].hooks.press()
    test.equal(f.selected[1], "skills:wide")
    test.equal(f.root.destroyed, true)
    tiles[2].hooks.press()
    f.close()
    f.update()
    test.equal(#f.selected, 1)
    test.equal(f.closed, 1)
    test.equal(f.detached, 1)
end)

test.case("Icon tooltip centres text and grows for wrapped names", function()
    local f = fixture({ categories = { { key = "test", name = "Test", entries = {
        { key = "test:long", name = "Custom-fit trimmed masterwork melee platebody", sprite = "FARM" },
        { key = "test:short", name = "Short", sprite = "FARM" },
    } } } })
    f.open()
    f.tiles()[1].hooks.over()
    local label = f.find("Text", function(c) return c.content == "Custom-fit trimmed masterwork melee platebody" end)[1]
    test.equal(label.alignVertical, "centre")
    test.equal(label.maxLines > 1, true)
    test.equal(label.parent.height > 26, true)
    test.equal(label.parent.x + label.parent.width <= f.root.width, true)
    f.tiles()[2].hooks.over()
    test.equal(label.maxLines, 1)
    test.equal(label.parent.height, 26)
    f.close()
end)

test.case("Missing resources cannot be selected and cancel leaves staged selection alone", function()
    local f = fixture()
    f.open()
    local missing = f.tiles()[3]
    test.equal(missing.label, "?")
    missing.hooks.over()
    test.equal(#f.find("Text", function(c) return c.content == "Missing (unavailable)" end), 1)
    missing.hooks.press()
    test.equal(#f.selected, 0)
    test.equal(f.closed, 0)
    local closeButton = f.find("Sprite", function(c) return c.sprite == 20 end)[1]
    closeButton.hooks.over()
    test.equal(closeButton.sprite, 21)
    closeButton.hooks.leave()
    test.equal(closeButton.sprite, 20)
    closeButton.hooks.click()
    test.equal(#f.selected, 0)
    test.equal(f.closed, 1)
end)

test.case("Default-number action clears selection and unknown initial keys remain safe", function()
    local f = fixture({ initial = "unknown" })
    f.open()
    test.equal(#f.find("Rectangle", function(c) return c.fill == false and c.width == 40 end), 0)
    f.find("Button", function(c) return c.label == "Use preset number" end)[1].hooks.press()
    test.equal(f.selected[1], "")
end)

test.case("Picker overlay follows its anchor, flips, clamps and tolerates detach failure", function()
    local f = fixture()
    f.open()
    test.equal(f.root.parent, f.parent)
    test.equal(f.root.x, 158)
    test.equal(f.root.y, 120)
    f.anchor:SetPos(850, 650)
    f.update()
    test.equal(f.root.x, 654)
    test.equal(f.root.y + f.root.height <= f.parent.height, true)
    f.anchor:SetPos(-1000, -1000)
    f.reposition()
    test.equal(f.root.x, 0)
    test.equal(f.root.y, 0)
    f.close()
    local other = fixture({ attachOverlay = function()
        return function() error("Disposed overlay") end
    end })
    other.open()
    other.close()
    test.equal(other.closed, 1)
end)

test.case("Categories are data-driven and switching tabs does not apply or close", function()
    local f = fixture()
    f.options.categories[2] = { key = "future", name = "Future", entries = {
        { key = "future:test", name = "Future test", sprite = "FARM" },
    } }
    f.open()
    local oldTile = f.tiles()[1]
    f.find("Button", function(c) return c.label == "Future" end)[1].hooks.press()
    test.equal(oldTile.destroyed, true)
    test.equal(#f.tiles(), 1)
    test.equal(#f.selected, 0)
    test.equal(f.closed, 0)
    f.tiles()[1].hooks.press()
    test.equal(f.selected[1], "future:test")
end)

test.case("Category tabs wrap into readable rows without overlapping the grid", function()
    local f = fixture()
    f.options.categories = {}
    for _, name in ipairs({ "Skills", "Weapons", "Holidays", "Misc", "Bag" }) do
        f.options.categories[#f.options.categories + 1] = { key = name, name = name, entries = {
            { key = name .. ":item", name = name .. " item", sprite = "FARM" },
        } }
    end
    f.open()
    local weapons = f.find("Button", function(c) return c.label == "Weapons" end)[1]
    local holidays = f.find("Button", function(c) return c.label == "Holidays" end)[1]
    local bag = f.find("Button", function(c) return c.label == "Bag" end)[1]
    test.equal(weapons.width >= 78, true)
    test.equal(holidays.width >= 78, true)
    test.equal(bag.y > weapons.y, true)
    test.equal(f.tiles()[1].parent.y >= bag.y + bag.height, true)
    holidays.hooks.press()
    test.equal(#f.tiles(), 1)
    f.tiles()[1].hooks.press()
    test.equal(f.selected[1], "Holidays:item")
end)

test.case("Empty categories are hidden but the backpack can explain its purpose", function()
    local f = fixture()
    f.options.categories[2] = { key = "backpack", name = "Bag", entries = {}, showWhenEmpty = true,
        emptyMessage = "Add items to Bag to use as icons." }
    f.options.categories[3] = { key = "bosses", name = "Bosses", entries = {} }
    f.open()
    test.equal(#f.find("Button", function(c) return c.label == "Bosses" end), 0)
    test.equal(#f.tiles(), 3)
    f.find("Button", function(c) return c.label == "Bag" end)[1].hooks.press()
    test.equal(#f.tiles(), 0)
    test.equal(#f.find("Text", function(c)
        return c.content == "Add items to Bag to use as icons."
    end), 1)
    f.close()
end)

test.case("Picker allows resetting when all categories are empty", function()
    local f = fixture({ categories = { { key = "bosses", name = "Bosses", entries = {} } } })
    f.open()
    test.equal(#f.find("Button", function(c) return c.label == "Bosses" end), 0)
    test.equal(#f.find("Text", function(c) return c.content == "No icons available." end), 1)
    f.find("Button", function(c) return c.label == "Use preset number" end)[1].hooks.press()
    test.equal(f.selected[1], "")
end)

test.case("Backpack tiles show the item name and select its stable ID", function()
    local f = fixture({ categories = { { key = "backpack", name = "Bag", entries = {
        { key = "item:31725", name = "Noxious scythe", objectID = 31725, width = 36, height = 32 },
    } } }, resolve = function() return 31725 end,
        apply = function(sprite, assetID) sprite.sprite = assetID end })
    f.open()
    f.tiles()[1].hooks.over()
    test.equal(#f.find("Text", function(c) return c.content == "Noxious scythe" end), 1)
    f.tiles()[1].hooks.press()
    test.equal(f.selected[1], "item:31725")
end)

test.case("Larger categories paginate and start on the selected entry's page", function()
    local f = fixture({ initial = "test:32" })
    local entries = {}
    for index = 1, 35 do entries[index] = { key = "test:" .. index, name = "Test " .. index, sprite = "FARM" } end
    f.options.categories = { { key = "test", name = "Test", entries = entries } }
    f.open()
    test.equal(#f.tiles(), 5)
    test.equal(#f.find("Text", function(c) return c.content == "2 / 2" end), 1)
    local pageLabel = f.find("Text", function(c) return c.content == "2 / 2" end)[1]
    test.equal(pageLabel.alignHorizontal, "centre")
    test.equal(pageLabel.x + pageLabel.width / 2, f.root.width / 2)
    test.equal(f.find("Arrow")[2].disabled, true)
    f.find("Arrow", function(c) return c.spriteName == "ARROW_LEFT" end)[1].hooks.press()
    test.equal(#f.tiles(), 30)
    test.equal(f.find("Arrow")[1].disabled, true)
    f.find("Arrow", function(c) return c.spriteName == "ARROW_RIGHT" end)[1].hooks.press()
    f.tiles()[2].hooks.press()
    test.equal(f.selected[1], "test:32")
end)

test.case("Weapons tab paginates finished weapons and selects their stable keys", function()
    local catalogue = require("presets/icon_catalogue")
    local applied = {}
    local f = fixture({ categories = catalogue.categories,
        resolve = function() return 99 end,
        apply = function(sprite, assetID, entry)
            sprite.sprite = assetID
            applied[#applied + 1] = entry.key
        end })
    f.open()
    f.find("Button", function(c) return c.label == "Weapons" end)[1].hooks.press()
    test.equal(#f.tiles(), 30)
    test.equal(applied[#applied], catalogue.categories[2].entries[30].key)
    local weapon = f.find("Sprite", function(c) return c.sprite == 99 and c.width == 36 end)[1]
    test.equal(weapon.height, 32)
    test.equal(weapon.x >= 0 and weapon.x + weapon.width <= 40, true)
    test.equal(weapon.y >= 0 and weapon.y + weapon.height <= 40, true)
    f.find("Arrow", function(c) return c.spriteName == "ARROW_RIGHT" end)[1].hooks.press()
    f.tiles()[1].hooks.press()
    test.equal(f.selected[1], catalogue.categories[2].entries[31].key)
end)

test.case("The complete Skills category fits the standard grid and narrower UIs paginate", function()
    local categories = { require("presets/icon_catalogue").categories[1] }
    local f = fixture({ categories = categories, initial = "skills:necromancy", resolve = function() return 99 end })
    f.open()
    test.equal(#f.tiles(), 29)
    test.equal(#f.find("Arrow"), 0)
    f.close()
    local narrow = fixture({ categories = categories, initial = "skills:necromancy", resolve = function() return 99 end })
    narrow.parent:SetSize(220, 400)
    narrow.open()
    test.equal(narrow.root.width <= 220, true)
    test.equal(narrow.root.height <= 400, true)
    test.equal(#narrow.find("Text", function(c) return c.content == "2 / 2" end), 1)
    narrow.close()
end)

test.case("Picker supports injected catalogue resolution and cleans up failed construction", function()
    local f = fixture({ resolve = function(key)
        if key == "skills:farming" then return 99 end
        error("Unavailable resource")
    end })
    f.open()
    test.equal(#f.find("Sprite", function(c) return c.sprite == 99 end), 1)
    test.equal(f.tiles()[2].label, "?")
    test.equal(#f.messages, 1, "Repeated rendering errors are logged only once per picker")
    test.equal(f.messages[1]:find("Unavailable resource", 1, true) ~= nil, true)
    f.close()
    local broken = fixture({ attachOverlay = function() error("Attach failed") end })
    local ok = pcall(broken.open)
    test.equal(ok, false)
    test.equal(#broken.find("Layer"), 0, "Failed construction leaves no plugin popup")
    test.equal(broken.closed, 0, "An unopened picker does not emit a close event")
end)
