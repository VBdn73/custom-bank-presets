local test = require("tests.test_helper")
local preferences = require("editor/preferences")

test.case("Preferences show both display options and bank-only editing guidance", function()
    local previousUI, previousID = ui, id
    local note = { SetPos = function(self, x, y) self.x, self.y = x, y end,
        SetSize = function() end }
    ui = { Hook = { ONRESIZE = "resize" }, AlignMode = { TOPLEFT = "topLeft" },
        Text = { new = function() return note end } }
    id = { Font = { MUSEO_SANS_11PT_REGULAR = 11 } }
    local ok, message = pcall(function()
        local hidden, backgrounds, canSave = false, true, true
        local controls = {}
        local parent = { width = 270, Subscribe = function(self, _, _, callback)
            self.resize = callback
        end }
        local root = { height = 28, SetPos = function(self, x, y) self.x, self.y = x, y end,
            SetSize = function(self, width, height) self.width, self.height = width, height end }
        local change, selected, count
        local refresh = preferences.build(parent, {
            hidePredefinedDropdown = function() return hidden end,
            setHidePredefinedDropdown = function(value)
                if not canSave then return false end
                hidden = value
                return true
            end,
            showCompactBackgrounds = function() return backgrounds end,
            setShowCompactBackgrounds = function(value)
                if not canSave then return false end
                backgrounds = value
                return true
            end,
        }, { CheckboxButton = { new = function(_, entries, options)
            if entries[1].value == "compactBackgrounds" then
                test.equal(entries[1].selected, true)
                local control = { root = { SetPos = function() end, SetSize = function() end },
                    items = { { label = { SetSize = function() end },
                        box = { SetPos = function() end }, row = { SetSize = function() end } } },
                    SetSelected = function(self, key, value, notify)
                        test.equal(key, "compactBackgrounds")
                        test.equal(notify, false)
                        self.selected = value
                    end, change = options.onChange }
                controls.backgrounds = control
                return control
            end
            count = #entries
            test.equal(entries[1].selected, false)
            change = options.onChange
            return { root = root, items = { { label = {
                SetSize = function() end,
            }, box = { SetPos = function() end },
                row = { SetSize = function() end } } }, SetSelected = function(_, key, value, notify)
                test.equal(key, "hideDropdown")
                test.equal(notify, false)
                selected = value
            end }
        end } })
        test.equal(count, 1)
        test.equal(note.content, "Presets can only be customised in the bank UI: right-click a preset and choose Customize preset.")
        test.equal(note.font, 11)
        test.equal(root.width, 254)
        test.equal(root.height, 36)
        test.equal(note.y, 96, "Wrapped checkboxes have a small gap before guidance")
        change(nil, nil, nil, true)
        test.equal(hidden, true)
        refresh()
        test.equal(selected, true)
        hidden = false
        refresh()
        test.equal(selected, false, "Changes from main settings are reflected")
        parent.width = 200
        parent.resize()
        test.equal(root.width, 184)
        test.equal(root.height, 54)
        parent.width = 700
        parent.resize()
        test.equal(root.height, 20)
        test.equal(note.y, 64, "Wide settings do not reserve unused checkbox lines")
        controls.backgrounds.change(nil, nil, nil, false)
        test.equal(backgrounds, false)
        refresh()
        test.equal(controls.backgrounds.selected, false)
        backgrounds = true
        refresh()
        test.equal(controls.backgrounds.selected, true, "Other panels reflect background changes")
        canSave = false
        controls.backgrounds.change(nil, nil, nil, false)
        test.equal(controls.backgrounds.selected, true, "Failed saves restore background preference")
        change(nil, nil, nil, true)
        test.equal(selected, false, "Failed saves restore the stored preference")
    end)
    ui = previousUI
    id = previousID
    assert(ok, message)
end)

test.case("Settings scrolls its preferences and adapts to resizing", function()
    local oldUI, oldID = ui, id
    local ok, message = pcall(function()
        local function component()
            return { SetPos = function() end, SetSize = function() end }
        end
        ui = { Hook = { ONRESIZE = "resize" }, AlignMode = { TOPLEFT = 1 },
            Text = { new = function() return component() end } }
        id = { Font = { MUSEO_SANS_11PT_REGULAR = 1 } }
        local host = { width = 400, height = 300, Subscribe = function(self, _, _, fn) self.resize = fn end }
        local scroll = { content = { width = 400 }, contentWidth = 400 }
        function scroll:SetSize(w, h) self.width, self.height = w, h end
        function scroll:SetContentHeight(h) self.contentHeight = h end
        function scroll:Destroy() self.destroyed = true end
        local pretty = { SimpleView = { new = function() return scroll end },
            CheckboxButton = { new = function() return { root = component(),
                items = { { label = component(), box = component(), row = component() } },
                SetSelected = function() end } end } }
        local settings = { hidePredefinedDropdown = function() return false end,
            setHidePredefinedDropdown = function() return true end,
            showCompactBackgrounds = function() return true end,
            setShowCompactBackgrounds = function() return true end }
        local _, _, destroy = preferences.build(host, settings, pretty, true)
        test.equal(scroll.contentHeight, 108)
        host.height = 800
        host.resize()
        test.equal(scroll.contentHeight, 108)
        test.equal(scroll.height, 800)
        destroy()
        test.equal(scroll.destroyed, true)
    end)
    ui, id = oldUI, oldID
    assert(ok, message)
end)
