local test = require("tests.test_helper")

-- Mock only the native API used by the editor. No actual client UI is created.
local function createFixture(colours, iconStore)
    local f = { controls = {}, stored = { [18] = "Last preset" }, context = "first",
        saveCalls = 0, saveMode = "success" }
    local function createControl(kind, parent)
        local control = { kind = kind, parent = parent, entries = {}, hooks = {},
            text = {}, containerSprite = {} }
        setmetatable(control, { __index = function(target, key)
            if key == "spriteID" then return target.sprite end
        end, __newindex = function(target, key, value)
            if kind == "text" and key == "shadowRGBA" then
                error("Native Text does not expose a writable shadowRGBA property")
            end
            if key == "hidden" then
                test.equal(type(value), "boolean", "Native visibility requires a boolean")
            end
            rawset(target, key, value)
        end })
        function control:SetPos(x, y, parentX, parentY, selfX, selfY)
            self.x, self.y = x, y
            self.parentX, self.selfX = parentX, selfX
        end
        function control:SetSize(width, height) self.width, self.height = width, height end
        function control:SetAssociatedObject(objectID) self.associatedObjectID = objectID end
        function control:Destroy() self.destroyed = true end
        function control:Setup(visibility, filter, limit)
            self.visibility, self.filter, self.limit = visibility, filter, limit
        end
        function control:Subscribe(hook, reference, callback) self.hooks[hook] = callback or reference end
        function control:Add(label, entryID) self.entries[entryID] = label end
        function control:Clear() self.entries = {} end
        function control:SetEntrySelected(entryID, selected, triggerEvents)
            test.equal(selected, true)
            test.equal(triggerEvents, false, "Initialization must not trigger selection events")
            self.selectedID = entryID
        end
        f.controls[#f.controls + 1] = control
        return control
    end
    ui = {
        Canvas = { new = function(parent)
            local control = createControl("canvas", parent)
            control.gradients = {}
            function control:AddGradientH(...)
                self.gradients[#self.gradients + 1] = { direction = "horizontal", ... }
            end
            function control:AddGradientV(...)
                self.gradients[#self.gradients + 1] = { direction = "vertical", ... }
            end
            return control
        end },
        Layer = { new = function(parent) return createControl("layer", parent) end },
        Rectangle = { new = function(parent) return createControl("rectangle", parent) end },
        Text = { new = function(parent) return createControl("text", parent) end },
        Button = { new = function(parent) return createControl("button", parent) end },
        Sprite = { new = function(parent) return createControl("sprite", parent) end },
        InputField = { new = function(parent) return createControl("input", parent) end },
        List = { new = function(parent) return createControl("list", parent) end },
        Hook = { ONBUTTONPRESSED = 1, ONCONTENTCHANGED = 2, ONSELECTIONCHANGED = 3, ONRESIZE = 4, ONCLICK = 5,
            ONSCROLLWHEEL = 6, ONHOLD = 7, ONRELEASE = 8,
            ONMOUSEOVER = 9, ONMOUSELEAVE = 10, ONKEY = 11 },
        SelectionChangeEvent = { SELECTED = 1, DESELECTED = 0 },
        ObjectQuantityDisplayMode = { NEVER = 0 },
        TextContentVisibilityMode = { VISIBLE = 0 }, InputFieldFilterMode = { NONE = 0 },
        AlignMode = { CENTRE = 1 },
        Margin = { new = function(left, top, right, bottom)
            return { left = left, top = top, right = right, bottom = bottom }
        end },
        InputFieldActionResult = { SUBMIT = 1 },
    }
    Vector4 = { new = function(...) return { ... } end }
    config = { Font = { FromID = function()
        return { baseline = 18, maxAscent = 14, maxDescent = 4, GetStringWidth = function(_, content)
            local _, count = content:gsub("[^\128-\191]", "")
            return count * 8
        end }
    end } }
    -- Mock the public PrettyUI interface, not its scrollbar implementation.
    prettyui = { SimpleView = { new = function(parent, options)
        local view = { content = createControl("layer", parent), scrollY = 0,
            width = options.width, height = options.height, contentHeight = 0 }
        function view:ScrollBy(delta)
            self.scrollY = math.max(0, math.min(math.max(0, self.contentHeight - self.height),
                self.scrollY + delta))
        end
        function view:SetScrollPosition(value)
            self:ScrollBy(value - self.scrollY)
            if self.input then
                local root = self.input.root
                root.contentClipped = root.y - self.scrollY < 0
                    or root.y - self.scrollY + root.height > self.height
            end
        end
        function view:AddTextField(options)
            test.equal(options._scrollController, self)
            local root = createControl("input", self.content)
            root:SetPos(options.x, options.y)
            root:SetSize(options.width, options.height)
            root.limit = options.maxLength
            local field = { root = root }
            root:Subscribe(ui.Hook.ONCONTENTCHANGED, function(_, reason)
                if field.onChange then field.onChange(field, reason, root.content) end
                if reason == ui.InputFieldActionResult.SUBMIT and field.onSubmit then field.onSubmit() end
            end)
            root:Subscribe(ui.Hook.ONSCROLLWHEEL, function(_, delta)
                self:SetScrollPosition(self.scrollY + delta * 32)
                return false
            end)
            self.input = field
            return field
        end
        function view:AddSimpleButton(label, callback, options)
            test.equal(options.absolute, true)
            local root = createControl("button", self.content)
            root.label = label
            root:SetPos(options.x, options.y)
            root:SetSize(options.width, options.height)
            root:Subscribe(ui.Hook.ONBUTTONPRESSED, callback)
            return { root = root }
        end
        function view:SetContentHeight(height)
            self.contentHeight = height
            self.scrollbarVisible = height > self.height
            self.contentWidth = self.width - (self.scrollbarVisible and 18 or 0)
            self.content:SetSize(self.contentWidth, math.max(self.height, height))
            self:ScrollBy(0)
        end
        function view:SetSize(width, height)
            self.width, self.height = width, height
            self:SetContentHeight(self.contentHeight)
        end
        function view:Destroy() self.destroyed = true end
        f.scrollView = view
        return view
    end } }
    id = {
        Font = { MUSEO_SANS_15PT_REGULAR = 1, MUSEO_SANS_11PT_REGULAR = 2 },
        StyleSheet = { DROPDOWN_DEFAULT = 1, INPUT_DEFAULT = 2, BUTTON_DEFAULT = 3 },
        Sprite = { RS3_BUTTON_INFO_PARENT_0 = 28787, RS3_BUTTON_INFO_PARENT_1 = 32135,
            RS3_BTN_MODAL_WINDOW_1_CLOSE_NML = 1001, RS3_BTN_MODAL_WINDOW_1_CLOSE_OVR = 1002,
            RS3_BUTTON_INFO_PARENT_2 = 32136,
            RS3_ICON_STOPWATCH_RESET_0 = 14805, RS3_ICON_STOPWATCH_RESET_1 = 14806,
            RS3_ICON_STOPWATCH_RESET_2 = 14807, RS3_ICON_EDIT_23PX_0 = 33406 },
    }
    if iconStore then
        for index, entry in ipairs(require("presets/icon_catalogue").categories[1].entries) do
            id.Sprite[entry.sprite] = 2000 + index
        end
    end
    f.names = {
        normalize = dofile("presets/names.lua").normalize,
        getContext = function() return f.context end,
        get = function(slot) return f.stored[slot] end,
        save = function(slot, value)
            f.saveCalls = f.saveCalls + 1
            if f.saveMode == "error" then error("Simulated storage exception") end
            if f.saveMode == "rejected" then return false, "Simulated validation failure" end
            f.stored[slot] = value
            return true, "Name saved."
        end,
    }
    f.host = createControl("host")
    f.host.width, f.host.height = 600, 400
    f.parent = createControl("parent", f.host)
    f.parent.width, f.parent.height = 580, 360
    function f:open(initialSlot, options)
        options = options or {}
        if options.prettyui == nil then
            options.prettyui = prettyui
        end
        if options.prettyui then
            options.prettyui.SpriteButton = { new = function(parent, spriteName, action, settings)
                local control = createControl("Sprite", parent)
                control:SetPos(settings.x, settings.y)
                control:SetSize(settings.size, settings.size)
                function control:SetDisabled(disabled) self.disabled = disabled end
                return control
            end }
        end
        local firstNewControl = #self.controls + 1
        self.refresh, self.toggleInfo, self.destroy, self.selectSlot = dofile("editor/view.lua").build(self.parent, self.names,
            self.bindings or { presetCount = 18, colours = colours, icons = iconStore }, initialSlot, options)
        for index = firstNewControl, #self.controls do
            local control = self.controls[index]
            if control.kind == "list" and control.entries[17] then self.selector = control
            elseif control.kind == "input" then self.input = control
            elseif control.label == "Save" then self.save = control
            elseif control.label == "Reset" then self.reset = control
            elseif control.kind == "sprite" and control.sprite == 28787 then self.info = control
            elseif control.content == "Custom bank presets" then self.title = control
            elseif control.kind == "text" and control.height == 18
                and control.y == math.max(0, math.floor((self.parent.height
                     - (options and options.hideTitle and 162 or 194)) / 2))
                    + 194 - (options and options.hideTitle and 32 or 0) then self.note = control
            elseif control.kind == "text" and control.content == "" then self.status = control end
        end
    end
    function f:select(entryID, event)
        self.selector.hooks[ui.Hook.ONSELECTIONCHANGED](self.selector, entryID,
            event or ui.SelectionChangeEvent.SELECTED)
    end
    function f:clickSave() self.save.hooks[ui.Hook.ONBUTTONPRESSED]() end
    function f:clickReset() self.reset.hooks[ui.Hook.ONBUTTONPRESSED]() end
    f:open()
    return f
end

test.case("Icon text previews, validates, saves and resets without changing bank icons", function()
    local f = createFixture()
    local saved = {}
    local textStore = {
        normalize = require("presets/icon_text").normalize,
        get = function(slot) return saved[slot] or "" end,
        save = function(slot, value) saved[slot] = value; return true end,
    }
    local colours = { get = function() return "" end, save = function() return true end }
    local icons = { get = function() return "" end, save = function() return true end,
        normalize = function(value) return value end }
    f.bindings = { presetCount = 18, colours = colours, icons = icons, iconText = textStore }
    local first = #f.controls + 1
    f:open(1)
    local input, preview, label
    for index = first, #f.controls do
        local control = f.controls[index]
        if control.kind == "input" and control.limit == 3 then input = control end
        if control.content == "Icon text:" then label = control end
    end
    test.equal(label ~= nil, true)
    input.content = "A1"
    input.hooks[ui.Hook.ONCONTENTCHANGED](input)
    for index = first, #f.controls do
        local control = f.controls[index]
        if control.kind == "text" and control.content == "A1" then preview = control end
    end
    test.equal(preview.hidden, false)
    test.equal(preview.maxLines, 1)
    test.equal(preview.width, 40)
    local standaloneY = preview.y
    test.equal(input.y > label.y - 5, true)
    local entry = require("presets/icon_catalogue").categories[1].entries[1]
    id.Sprite[entry.sprite] = 9001
    icons.get = function() return entry.key end
    f.selectSlot(2)
    f.selectSlot(1)
    input.content = "A1"
    input.hooks[ui.Hook.ONCONTENTCHANGED](input)
    local sprite
    for index = first, #f.controls do
        local control = f.controls[index]
        if control.kind == "sprite" and control.sprite == 9001 and control.x == preview.x + 8 then sprite = control end
    end
    test.equal(sprite ~= nil and not sprite.hidden, true, "Text overlays the selected icon")
    test.equal(preview.hidden, false)
    test.equal(preview.y, standaloneY + 6, "Overlay sits lower to reveal more of the icon")
    f:clickSave()
    test.equal(saved[1], "A1")
    input.content = "!"
    f:clickSave()
    test.equal(saved[1], "A1")
    f:clickReset()
    f:clickSave()
    test.equal(saved[1], "")
end)

test.case("Unsaved indicator follows staged edits, failed saves and selection", function()
    local f = createFixture()
    local first = #f.controls + 1
    f:open(18, { hideTitle = true, readOnlyPreset = true })
    local heading, indicator, indicatorLabel
    for index = first, #f.controls do
        if f.controls[index].content == "Preset 18 - Last preset" then heading = f.controls[index] end
        if f.controls[index].sprite == id.Sprite.RS3_ICON_EDIT_23PX_0 then indicator = f.controls[index] end
        if f.controls[index].content == "Unsaved" then indicatorLabel = f.controls[index] end
    end
    test.equal(indicator.hidden, true)
    test.equal(indicatorLabel.hidden, true)
    f.input.content = "Changed"
    f.input.hooks[ui.Hook.ONCONTENTCHANGED](f.input)
    test.equal(heading.content, "Preset 18 - Last preset")
    test.equal(indicator.hidden, false)
    test.equal(indicatorLabel.hidden, false)
    test.equal(indicator.y, f.status.y, "Indicator shares the feedback row")
    test.equal(indicatorLabel.y, f.status.y)
    test.equal(f.status.x + f.status.width <= indicator.x, true, "Feedback does not overlap the indicator")
    test.equal(indicator.y + indicator.height, indicatorLabel.y + indicatorLabel.height,
        "Native icon and label are vertically aligned")
    f.saveMode = "rejected"
    f:clickSave()
    test.equal(indicator.hidden, false)
    f.input.content = "Last preset"
    f.input.hooks[ui.Hook.ONCONTENTCHANGED](f.input)
    test.equal(heading.content, "Preset 18 - Last preset")
    test.equal(indicator.hidden, true)
    f:clickReset()
    test.equal(indicator.hidden, false)
    f.saveMode = "success"
    f:clickSave()
    test.equal(heading.content, "Preset 18")
    test.equal(indicator.hidden, true)
    f.input.content = "Another edit"
    f.selectSlot(1)
    test.equal(heading.content, "Preset 1")
end)

test.case("BoB appears by name and saves independently from preset 18", function()
    local f = createFixture()
    f.bindings = dofile("bank/bindings.lua")
    f:open(19)
    test.equal(f.selector.entries[18], "Beast of Burden")
    test.equal(f.selector.selectedID, 18)
    f.input.content = "Pack yak"
    f:clickSave()
    test.equal(f.stored[19], "Pack yak")
    test.equal(f.stored[18], "Last preset")
    test.equal(f.selector.entries[18], "Beast of Burden *")
    local first = #f.controls + 1
    f:open(19, { hideTitle = true, readOnlyPreset = true })
    local heading
    for index = first, #f.controls do
        if f.controls[index].content == "Beast of Burden - Pack yak" then heading = f.controls[index] end
    end
    test.equal(heading ~= nil, true)
    f:clickReset()
    f:clickSave()
    test.equal(heading.content, "Beast of Burden")
    test.equal(f.stored[18], "Last preset")
end)

test.case("Read-only preset heading follows bank selection, save and reset", function()
    local f = createFixture()
    local first = #f.controls + 1
    f:open(18, { hideTitle = true, readOnlyPreset = true })
    local heading
    for index = first, #f.controls do
        local control = f.controls[index]
        test.equal(control.kind == "list", false, "Bank editor has no preset dropdown")
        if control.content == "Preset 18 - Last preset" then heading = control end
    end
    test.equal(heading ~= nil, true)
    test.equal(heading.clickthrough, true)
    f.selectSlot(2)
    test.equal(heading.content, "Preset 2")
    f.input.content = "Bossing"
    f:clickSave()
    test.equal(heading.content, "Preset 2 - Bossing")
    f:clickReset()
    test.equal(heading.content, "Preset 2 - Bossing", "Reset only stages a draft")
    f:clickSave()
    test.equal(heading.content, "Preset 2")
    f.stored[2] = "Updated externally"
    f.refresh()
    test.equal(heading.content, "Preset 2 - Updated externally")
end)

test.case("Bank editor tightens the heading gap and fits its shortened body", function()
    local f = createFixture({ get = function() return "" end })
    local layout = require("editor/layout")
    local height = layout.compactBodyHeight + layout.colourHeight - layout.popupEditorGapReduction
    f.parent.height = height
    f:open(18, { hideTitle = true, readOnlyPreset = true, formHeight = height })
    local heading
    for _, control in ipairs(f.controls) do
        if control.content == "Preset 18 - Last preset" then heading = control end
    end
    test.equal(f.input.y - (heading.y + heading.height),
        layout.rows.input - layout.rows.selector - layout.textHeight - layout.popupEditorGapReduction)
    test.equal(f.save.y, layout.rows.colourButtons - layout.titleHeight - layout.popupEditorGapReduction)
    test.equal(f.status.y + f.status.height <= height, true, "Retain space for save and validation messages")
end)

test.case("Bank selection refreshes the existing editor and saves to the new slot", function()
    local f = createFixture()
    f.input.content = "Unfinished first preset"
    f.selectSlot(18)
    test.equal(f.selector.selectedID, 17)
    test.equal(f.input.content, "Last preset")
    f.input.content = "Edited last preset"
    f.selectSlot(18)
    f.refresh()
    test.equal(f.input.content, "Edited last preset", "Repeated clicks retain the current draft")
    f:clickSave()
    test.equal(f.stored[18], "Edited last preset")
    test.equal(f.stored[1], nil, "Switching does not save the previous draft")
    f.selectSlot(0)
    test.equal(f.selector.selectedID, 17, "Ignore invalid slots")
end)

test.case("Bottom buttons save and reset names and staged colours for the selected slot", function()
    local values, calls = {}, 0
    local colours = {
        get = function(slot, kind) return values[slot .. kind] or "" end,
        save = function(slot, kind, value)
            calls = calls + 1
            values[slot .. kind] = value
            return true, "Colour saved."
        end,
    }
    local f = createFixture(colours)
    local controls = {}
    for _, control in ipairs(f.controls) do
        if control.kind == "rectangle" and control.width == 54 then controls[#controls + 1] = control end
    end
    local function choose(index, hex)
        controls[index].hooks[ui.Hook.ONCLICK]()
        local input
        for _, control in ipairs(f.controls) do
            if not control.destroyed and control.kind == "input" and control.limit == 7 then input = control end
        end
        input.content = hex
        input.hooks[ui.Hook.ONCONTENTCHANGED]()
        controls[index].hooks[ui.Hook.ONCLICK]()
    end
    test.equal(#controls, 2)
    test.equal(f.save.y > controls[1].y + controls[1].height, true)
    test.equal(controls[2].y - controls[1].y, 32, "Colour rows are stacked")
    test.equal(f.reset.y, f.save.y)
    test.equal(f.status.y >= f.save.y + f.save.height, true,
        "Save and failure messages sit below the buttons")
    test.equal(calls, 0)
    f:select(17)
    choose(1, "#008000")
    choose(2, "#FF0000")
    local colourResets = {}
    for _, control in ipairs(f.controls) do
        if control.kind == "sprite" and control.sprite == id.Sprite.RS3_ICON_STOPWATCH_RESET_0 then
            colourResets[#colourResets + 1] = control
        end
    end
    test.equal(#colourResets, 2)
    colourResets[1].hooks[ui.Hook.ONCLICK]()
    test.equal(controls[1].colour[2], require("editor/theme").background[2],
        "Colour reset immediately previews Default")
    test.equal(controls[2].colour[1], 1, "Reset leaves the other colour unchanged")
    test.equal(calls, 0, "Colour reset stays staged until Save")
    choose(1, "#008000")
    f.refresh()
    test.equal(f.input.containerSprite.alpha, 0)
    test.equal(f.input.text.alignHorizontal, ui.AlignMode.CENTRE,
        "Editable preview centres the name like the bank preset")
    test.equal(f.input.text.rgba, 0, "Native glyphs stay hidden behind the unified preview")
    local background, preview
    for _, control in ipairs(f.controls) do
        if control.kind == "rectangle" and control.rgba == 0x008000FF then background = control end
        if control.kind == "text" and control.content == "Last preset" then preview = control end
    end
    test.equal(background ~= nil, true, "Background previews the staged colour")
    test.equal(background.width, f.input.width + 96 - 2)
    test.equal(preview.rgba, 0xFF0000FF)
    test.equal(controls[1].colour[2], 128 / 255, "Ticks preserve unsaved colours")
    test.equal(calls, 0)
    test.equal(f.saveCalls, 0)
    f.input.content = "Coloured preset"
    f:clickSave()
    test.equal(values["18background"], "#008000")
    test.equal(values["18text"], "#FF0000")
    test.equal(f.stored[18], "Coloured preset")
    f:clickReset()
    test.equal(values["18background"], "#008000", "Reset does not write saved colours")
    test.equal(f.stored[18], "Coloured preset", "Reset does not write the saved name")
    test.equal(f.input.content, "")
    test.equal(f.input.text.rgba, 0)
    test.equal(preview.rgba, 0xB8AD9DFF)
    test.equal(background.rgba, 0x292520FF)
    f:clickSave()
    test.equal(values["18background"], "")
    test.equal(values["18text"], "")
    test.equal(f.stored[18], "")
    test.equal(controls[1].colour[1], require("editor/theme").background[1])
    test.equal(f.selector.entries[17], "Preset 18")
    choose(1, "#FF0000")
    f:clickSave()
    test.equal(f.selector.entries[17], "Preset 18 *", "Background alone marks the preset")
    f:clickReset()
    f:clickSave()
    test.equal(values["18background"], "")
    f.context = "second"
    choose(2, "#0080FF")
    f:clickSave()
    test.equal(calls, 8, "Character change blocks all stale writes")
    f.refresh()
    choose(2, "#0080FF")
    f:select(0)
    f:select(17)
    test.equal(controls[2].colour[1], require("editor/theme").background[1], "Switching slots discards unsaved colours")
    choose(2, "#0080FF")
    f:clickSave()
    test.equal(calls, 10)
    test.equal(f.selector.entries[17], "Preset 18 *", "Text colour alone marks the preset")
end)

test.case("Preview matches the bank label font and shadow without changing its colour", function()
    local colours = { get = function(_, kind) return kind == "text" and "#FF8000" or "" end }
    local f = createFixture(colours)
    local label = { type = 1, content = "Preset", font = 42,
        shadowRGBA = 0x202020FF, isShadowed = false, rgba = 0xFF8000FF }
    ui.ComponentType = { LABEL = 1 }
    ui.Interfaces = { GetComponent = function() return label end }
    f.bindings = { presetCount = 18, colours = colours,
        labels = { { slot = 18, interfaceID = 517, staticID = 266 } } }
    f:open(18, { scrollable = true })
    test.equal(f.input.text.font, label.font)
    test.equal(f.input.text.shadowRGBA, label.shadowRGBA)
    test.equal(f.input.text.isShadowed, false)
    test.equal(f.input.text.rgba, 0)
    test.equal(f.input.emptyTextRGBA, label.rgba)
    local fallback
    for _, control in ipairs(f.controls) do
        if control.kind == "text" and control.content == "Last preset" then fallback = control end
    end
    test.equal(fallback ~= nil, true)
    test.equal(fallback.rgba, label.rgba, "Default name uses a normal label, not dimmed native placeholder text")
    test.equal(fallback.font, label.font)
    test.equal(fallback.clickthrough, true)
    test.equal(f.input.emptyText, "")
    f.input.content = ""
    f.refresh()
    test.equal(fallback.hidden, false)
    f.input.content = "Custom name"
    f.input.hooks[ui.Hook.ONCONTENTCHANGED](f.input, 0)
    test.equal(fallback.hidden, false, "Custom names use the same preview renderer")
    test.equal(fallback.content, "Custom name")
    test.equal(fallback.alignVertical, ui.AlignMode.CENTRE)
    test.equal(fallback.y, f.input.y)
    test.equal(fallback.height, f.input.height)
    f.input.content = ""
    f.refresh()
    f.scrollView.input._unclippedAppearance = {}
    f.input.text.isShadowed = false
    label.isShadowed = true
    f.refresh()
    test.equal(f.input.text.isShadowed, false, "Clipped shadow remains hidden")
    test.equal(f.scrollView.input._unclippedAppearance.isShadowed, false)
    test.equal(fallback.isShadowed, true)
    f.parent.height = 50
    f.parent.hooks[ui.Hook.ONRESIZE]()
    f.refresh()
    test.equal(fallback.hidden, true, "Default preview stays clipped in small ribbon panels")
end)

test.case("Switching to a preset with missing icon sprites hides stale preview icons", function()
    local f = createFixture({ get = function() return "" end })
    local resource = 777
    ui.Interfaces = { GetComponent = function(_, _, staticID)
        if staticID >= 268 and staticID <= 270 then
            return { sprite = resource, alpha = 1, rgba = 0xFFFFFFFF }
        end
    end }
    f:open(18)
    local icons = {}
    for _, control in ipairs(f.controls) do
        if control.sprite == 777 then icons[#icons + 1] = control end
    end
    test.equal(#icons, 3)
    resource = nil
    f:select(0)
    f.refresh()
    for _, icon in ipairs(icons) do
        test.equal(icon.alpha, 0)
        test.equal(icon.sprite, 777, "Missing native resources are never assigned to the sprite")
    end
    resource = 778
    f.refresh()
    for _, icon in ipairs(icons) do
        test.equal(icon.alpha, 1)
        test.equal(icon.sprite, 778)
    end
end)

test.case("Entered preview names centre using measured margins and retain long-name scrolling", function()
    local f = createFixture({ get = function() return "" end })
    for _, managed in ipairs({ false, true }) do
        if managed then f:open(18, { scrollable = true }) end
        f.input.content = "Ranger Randy"
        f.input.hooks[ui.Hook.ONCONTENTCHANGED](f.input, 0)
        test.equal(f.input.contentMargin.left, math.floor((f.input.width - 12 * 8 - 2) / 2))
        test.equal(f.input.contentMargin.right, 8)
        test.equal(f.input.contentMargin.top, math.floor((f.input.height - 14 - 4) / 2) + 14 - 18,
            "Entered names centre visible glyph bounds rather than line spacing")
        test.equal(f.saveCalls, 0)
        f.input.content = "é"
        f.refresh()
        test.equal(f.input.contentMargin.left, math.floor((f.input.width - 8 - 2) / 2))
        f.parent.width = 180
        f.parent.hooks[ui.Hook.ONRESIZE]()
        test.equal(f.input.contentMargin.left, math.floor((f.input.width - 8 - 2) / 2))
        f.input.content = string.rep("W", 40)
        f.refresh()
        test.equal(f.input.contentMargin.left, 8, "Long names retain the normal input area")
        f:clickReset()
        f.refresh()
        test.equal(f.input.contentMargin.left, math.floor((f.input.width - 2) / 2),
            "Empty input places the caret at the centred typing origin")
        f.parent.width = 580
        f.parent.hooks[ui.Hook.ONRESIZE]()
        test.equal(f.input.contentMargin.left, math.floor((f.input.width - 2) / 2),
            "Empty caret remains centred after resizing")
    end
end)

test.case("Managed preview updates clipped restore colours without making text visible", function()
    local f = createFixture({ get = function(_, kind)
        return kind == "text" and "#FF8000" or "#008000"
    end })
    f:open(18, { scrollable = true })
    local managed = f.scrollView.input
    managed._unclippedAppearance = { textRGBA = f.input.text.rgba }
    f.input.text.rgba, f.input.emptyTextRGBA, f.input.caretRGBA = 0, 0, 0
    f.refresh()
    test.equal(f.input.text.rgba, 0)
    test.equal(f.input.emptyTextRGBA, 0)
    test.equal(f.input.caretRGBA, 0)
    test.equal(managed._unclippedAppearance.textRGBA, 0)
    f:clickReset()
    test.equal(f.input.text.rgba, 0)
    test.equal(managed._unclippedAppearance.textRGBA, 0)
    f.destroy()
    test.equal(f.saveCalls, 0, "Closing discards the draft reset")
end)

test.case("Colour picker updates colours immediately and validates hex without action buttons", function()
    local f = createFixture()
    local applied = "unchanged"
    local picker = require("components/colour_picker/init")
    local function open(title)
        local first = #f.controls + 1
        local close = picker.open(f.parent, {
            title = title, initial = "#38A4FF", onChange = function(value) applied = value end,
        })
        local found = { close = close, root = f.controls[first] }
        for i = first, #f.controls do
            local control = f.controls[i]
            if control.kind == "text" and control.y == 8 and control.x == 12 then found.title = control end
            if control.kind == "sprite" and control.x == 256 and control.y == 8 then
                found.closeButton = control
            end
            if control.kind == "text" and control.y == 258 then found.hint = control end
            if control.kind == "input" then found.input = control end
            if control.kind == "canvas" then found.canvas = control end
            if control.label then found[control.label] = control end
            if control.kind == "rectangle" and control.width == 44 then found.preview = control end
            if control.kind == "layer" and control.x == 12 and control.y == 200 then found.hue = control end
            if control.kind == "layer" and control.x == 12 and control.y == 36 then found.shade = control end
        end
        return found
    end
    local p = open()
    test.equal(p.Apply, nil)
    test.equal(p.Cancel, nil)
    test.equal(p.Default, nil)
    test.equal(applied, "unchanged", "Opening does not change the colour")
    test.equal(p.title.content, "Choose colour")
    test.equal(p.hint, nil, "No redundant hex hint below the input")
    test.equal(p.root.height, 266, "Popup removes the unused hint row")
    test.equal(p.closeButton.sprite, id.Sprite.RS3_BTN_MODAL_WINDOW_1_CLOSE_NML)
    p.closeButton.hooks[ui.Hook.ONMOUSEOVER]()
    test.equal(p.closeButton.sprite, id.Sprite.RS3_BTN_MODAL_WINDOW_1_CLOSE_OVR)
    p.closeButton.hooks[ui.Hook.ONMOUSELEAVE]()
    test.equal(p.closeButton.sprite, id.Sprite.RS3_BTN_MODAL_WINDOW_1_CLOSE_NML)
    test.equal(p.root.clickthrough, false, "Picker blocks clicks into the game")
    test.equal(p.root.hooks[ui.Hook.ONCLICK](), true, "Empty popup space consumes clicks")
    for _, control in ipairs(f.controls) do
        if control.parent == p.root and control.kind == "rectangle" and control.x <= 1 then
            test.equal(control.hooks[ui.Hook.ONCLICK](), true, "Popup background consumes clicks")
        end
    end
    test.equal(p.hue, nil, "No separate hue strip")
    test.equal(#p.canvas.gradients, 8, "Six smooth hue gradients plus white and black overlays")
    p.shade.hooks[ui.Hook.ONCLICK](p.shade, 0, 90.5)
    test.equal(p.input.content, "#FF0000", "Canvas centre selects saturated colour")
    test.equal(applied, "#FF0000", "Selection immediately updates the host")
    p.shade.hooks[ui.Hook.ONHOLD](p.shade, 0, 45.25)
    test.equal(p.input.content, "#FF8080", "Canvas top half blends towards white")
    test.equal(applied, "#FF8080", "Dragging immediately updates the host")
    p.shade.hooks[ui.Hook.ONHOLD](p.shade, 0, 135.75)
    test.equal(applied, "#800000", "Canvas bottom half blends towards black")
    p.shade.hooks[ui.Hook.ONHOLD](p.shade, 0, 250)
    test.equal(applied, "#000000", "Canvas bottom edge selects black")
    p.shade.hooks[ui.Hook.ONHOLD](p.shade, -20, -20)
    test.equal(p.input.content, "#FFFFFF", "Dragging clamps to the field edges")
    p.shade.hooks[ui.Hook.ONRELEASE](p.shade, 131.5, 90.5)
    test.equal(p.input.content, "#00FFFF", "Horizontal dragging selects hue")
    p.input.content = "#INVALID"
    p.input.hooks[ui.Hook.ONCONTENTCHANGED]()
    test.equal(applied, "#00FFFF", "Invalid input preserves the last valid colour")
    test.equal(p.root.destroyed, nil)
    p.input.content = "#12ab34"
    p.input.hooks[ui.Hook.ONCONTENTCHANGED]()
    test.equal(p.preview.colour[2], 171 / 255)
    test.equal(applied, "#12AB34")
    test.equal(p.root.destroyed, nil, "Valid input keeps the picker open")
    test.equal(p.closeButton.hooks[ui.Hook.ONCLICK](), true, "Close button consumes its click")
    test.equal(p.root.destroyed, true)
    test.equal(applied, "#12AB34", "Closing retains the selected colour")
    p = open("Choose background colour")
    test.equal(p.title.content, "Choose background colour")
    p.close()
    test.equal(applied, "#12AB34")
    test.equal(p.root.destroyed, true)
    p.close() -- Idempotent cleanup after an action.
end)

test.case("Colour swatches toggle their picker and switch between colours", function()
    local f = createFixture({ get = function() return "" end })
    local swatches = {}
    for _, control in ipairs(f.controls) do
        if control.kind == "rectangle" and control.width == 54 then
            swatches[#swatches + 1] = control
        end
    end
    local function click(index)
        local first = #f.controls + 1
        swatches[index].hooks[ui.Hook.ONCLICK]()
        if f.controls[first] then
            test.equal(f.controls[first + 3].content,
                index == 1 and "Choose background colour" or "Choose text colour")
        end
        return f.controls[first]
    end
    for index = 1, 2 do
        local root = click(index)
        test.equal(click(index), nil, "Reclick closes without opening another picker")
        test.equal(root.destroyed, true)
        root = click(index)
        local other = click(3 - index)
        test.equal(root.destroyed, true)
        test.equal(other.destroyed, nil, "Other swatch opens its own picker")
        click(3 - index)
        root = click(index)
        click(index)
        test.equal(root.destroyed, true)
        root = click(index)
        test.equal(root.kind, "layer", "Click after closing opens immediately")
        click(index)
    end
    test.equal(f.saveCalls, 0)
end)

test.case("Open colour pickers close on slot changes, character changes, hide and disposal", function()
    local f = createFixture({ get = function() return "" end })
    local swatch
    for _, control in ipairs(f.controls) do
        if control.kind == "rectangle" and control.width == 54 then swatch = control; break end
    end
    local function open()
        local first = #f.controls + 1
        swatch.hooks[ui.Hook.ONCLICK]()
        return f.controls[first]
    end
    local root = open()
    f:select(17)
    test.equal(root.destroyed, true)
    root = open()
    f.context = "other"
    f.refresh()
    test.equal(root.destroyed, true)
    root = open()
    f.parent.visibleGlobal = false
    f.refresh()
    test.equal(root.destroyed, true)
    f.parent.visibleGlobal = true
    root = open()
    f.destroy()
    test.equal(root.destroyed, true)
end)

test.case("Default colour swatches show antialiased clickthrough diagonal crosses", function()
    local f = createFixture({ get = function(_, kind)
        return kind == "text" and "#123456" or ""
    end })
    local marks = {}
    for _, control in ipairs(f.controls) do
        if control.kind == "rectangle" and control.width == 1 and control.height == 1 then
            marks[#marks + 1] = control
            test.equal(control.clickthrough, true)
            test.equal(control.colour[1], 1)
            test.equal(control.colour[2], 1)
            test.equal(control.colour[3], 1)
        end
    end
    test.equal(#marks, 392)
    local translucent = false
    for _, mark in ipairs(marks) do
        test.equal(mark.colour[4] > 0 and mark.colour[4] <= 1, true)
        if mark.colour[4] < 1 then translucent = true end
    end
    test.equal(translucent, true, "Diagonal edges use partial opacity")
    f.refresh()
    for index, mark in ipairs(marks) do
        test.equal(mark.hidden, index > 196, "Only default colours show the cross")
    end
end)

test.case("Colour labels and swatches share aligned rows and separate columns", function()
    local f = createFixture({ get = function() return "" end })
    local labels, swatches, frames = {}, {}, {}
    for _, control in ipairs(f.controls) do
        test.equal(control.content == "-", false, "Default swatches have no dash")
        if control.content == "Background colour:" or control.content == "Text colour:" then
            labels[#labels + 1] = control
        elseif control.kind == "rectangle" and control.width == 54 then
            swatches[#swatches + 1] = control
        elseif control.kind == "button" and control.width == 58 and control.height == 26 and control.clickthrough then
            frames[#frames + 1] = control
        end
    end
    for _, size in ipairs({ { 580, 360 }, { 352, 258 }, { 200, 246 } }) do
        f.parent.width, f.parent.height = size[1], size[2]
        f.parent.hooks[ui.Hook.ONRESIZE]()
        for index = 1, 2 do
            test.equal(labels[index].y, swatches[index].y)
            test.equal(labels[index].height, swatches[index].height)
            test.equal(labels[index].x + labels[index].width + 6, frames[index].x)
            test.equal(frames[index].stylesheetID, id.StyleSheet.BUTTON_DEFAULT)
            test.equal(swatches[index].x, frames[index].x + 2)
            test.equal(swatches[index].y, frames[index].y + 3)
        end
        test.equal(swatches[1].x, swatches[2].x)
    end
end)

test.case("Colour swatches retain their size and fit narrow scrolled panels", function()
    local f = createFixture({ get = function() return "#000000" end })
    f.parent.width, f.parent.height = 200, 180
    f:open(nil, { scrollable = true })
    local swatches = 0
    for _, control in ipairs(f.controls) do
        if control.parent == f.scrollView.content and control.kind == "rectangle" and control.width == 54 then
            swatches = swatches + 1
            test.equal(control.x + control.width <= f.scrollView.contentWidth, true)
            test.equal(control.height, 20)
        end
    end
    test.equal(swatches, 2)
    f.destroy()
end)

test.case("Colour picker anchors beside its swatch, follows movement and clamps to the screen", function()
    local f = createFixture()
    f.host.xyGlobal = { x = 100, y = 200 }
    local anchor = { xyGlobal = { x = 300, y = 250 }, width = 32 }
    local first = #f.controls + 1
    local close, update = require("components/colour_picker/init").open(f.parent, {
        initial = "#FFFFFF", onChange = function() end, anchor = anchor,
    })
    local root = f.controls[first]
    test.equal(root.x, 240, "Picker opens just right of the swatch in the overlay's coordinates")
    test.equal(root.y, 50)
    anchor.xyGlobal = { x = 600, y = 390 }
    update()
    test.equal(root.x, 204, "Picker flips left when the right side does not fit")
    test.equal(root.y, 400 - root.height, "Picker stays above the bottom screen edge")
    anchor.xyGlobal = { x = 80, y = 180 }
    update()
    test.equal(root.x >= 0, true)
    test.equal(root.y, 0)
    close()
    update() -- A disposed picker must not be repositioned.
end)

test.case("Colour picker joins the PrettyUI window overlay stack and unregisters on close", function()
    local f = createFixture()
    local owner = { overlays = {}, syncs = 0 }
    function owner:_RegisterOverlay(root, _, position)
        self.overlays[root] = position
    end
    function owner:_UnregisterOverlay(root)
        test.equal(root.destroyed, nil, "Unregister before disposing the native layer")
        self.overlays[root] = nil
    end
    function owner:_SyncOverlays(hidden)
        test.equal(hidden, false)
        self.syncs = self.syncs + 1
        for _, position in pairs(self.overlays) do position() end
    end
    local anchor = { xyGlobal = { x = 50, y = 50 }, width = 32 }
    local first = #f.controls + 1
    local close = require("components/colour_picker/init").open(f.parent, {
        initial = "#FFFFFF", onChange = function() end, anchor = anchor,
        attachOverlay = function(root, position)
            owner:_RegisterOverlay(root, nil, position)
            owner:_SyncOverlays(false)
            return function() owner:_UnregisterOverlay(root) end
        end,
    })
    local root = f.controls[first]
    test.equal(type(owner.overlays[root]), "function")
    test.equal(owner.syncs, 1, "Synchronize the newly opened overlay immediately")
    anchor.xyGlobal.x = 100
    owner:_SyncOverlays(false) -- Same synchronization used when PrettyUI moves/focuses its window.
    test.equal(root.x, 140)
    close()
    test.equal(owner.overlays[root], nil)
    test.equal(root.destroyed, true)
    close()
end)

test.case("Settings info uses the same native icon states as the popup", function()
    local f = createFixture()
    test.equal(f.info.sprite, 28787)
    test.equal(f.info.label, nil)
    test.equal(f.info.clickthrough, false)
    f.info.isMouseOver = true
    f.refresh()
    test.equal(f.info.sprite, 32135)
    f.info.isClicked = true
    f.refresh()
    test.equal(f.info.sprite, 32136)
    f.info.isMouseOver, f.info.isClicked = false, false
    f.refresh()
    test.equal(f.info.sprite, 28787)
end)

test.case("Editor starts at preset 1 with all 18 zero-based dropdown entries", function()
    local f = createFixture()
    for slot = 1, 18 do
        test.equal(f.selector.entries[slot - 1], "Preset " .. slot .. (slot == 18 and " *" or ""))
    end
    test.equal(f.selector.entries[18], nil)
    test.equal(f.selector.selectedID, 0)
    test.equal(f.input.content, "")
    test.equal(f.input.limit, 40)
    test.equal(f.saveCalls, 0, "Opening must not save")
end)

test.case("Preset markers follow saved names, blank saves, resets and external edits", function()
    local f = createFixture()
    f.input.content = "Custom"
    f.refresh()
    test.equal(f.selector.entries[0], "Preset 1")
    f:clickSave()
    test.equal(f.selector.entries[0], "Preset 1 *")
    f:clickReset()
    f:clickSave()
    test.equal(f.selector.entries[0], "Preset 1")
    f:select(17)
    f.input.content = ""
    f:clickSave()
    test.equal(f.selector.entries[17], "Preset 18")
    test.equal(f.selector.selectedID, 17)
    f.stored[2] = "Another editor"
    f.input.content = "Keep unsaved edit"
    f.refresh()
    test.equal(f.selector.entries[1], "Preset 2 *")
    test.equal(f.input.content, "Keep unsaved edit")
    f.context, f.stored = "second", {}
    f.refresh()
    test.equal(f.selector.entries[1], "Preset 2")
end)

test.case("Custom name label is omitted and save status uses the smaller font", function()
    local f = createFixture()
    for _, control in ipairs(f.controls) do
        test.equal(control.content == "Custom name (blank = predefined):", false)
    end
    f:clickSave()
    test.equal(f.status.content, "Name saved.")
    test.equal(f.status.colour[2] > f.status.colour[1], true, "Success is green")
    test.equal(f.status.font, id.Font.MUSEO_SANS_11PT_REGULAR)
    test.equal(f.title.font, id.Font.MUSEO_SANS_15PT_REGULAR)
end)

test.case("Status colours switch between success and failure without icons", function()
    local f = createFixture()
    for _, control in ipairs(f.controls) do
        test.equal(control.kind == "line", false)
    end
    f:clickSave()
    test.equal(f.status.content, "Name saved.")
    test.equal(f.status.colour[2] > f.status.colour[1], true)
    f.saveMode = "rejected"
    f:clickSave()
    test.equal(f.status.content, "Save failed; recovery incomplete. Check customisations and the client console.")
    test.equal(f.status.colour[1] > f.status.colour[2], true)
    f:select(17)
    test.equal(f.status.content, "")
end)

test.case("Direct editing starts at the clicked preset and saves only that slot", function()
    local f = createFixture()
    f:open(18)
    test.equal(f.selector.selectedID, 17)
    test.equal(f.input.content, "Last preset")
    test.equal(f.saveCalls, 0)
    f.input.content = "Direct edit"
    f:clickSave()
    test.equal(f.stored[18], "Direct edit")
    test.equal(f.stored[1], nil)
end)

test.case("Invalid direct-edit slots fall back to preset 1", function()
    local f = createFixture()
    for _, slot in ipairs({ 0, 19, 1.5, "18" }) do
        f:open(slot)
        test.equal(f.selector.selectedID, 0)
    end
end)

test.case("Popup editor omits its duplicate title and fits beneath window chrome", function()
    local f = createFixture()
    f.parent.width, f.parent.height = 352, 162
    local first = #f.controls + 1
    f:open(18, { hideTitle = true })
    for index = first, #f.controls do
        local c = f.controls[index]
        test.equal(c.content == "Custom bank presets", false)
        if c.content ~= "" then
            test.equal(c.y >= 0 and c.y + c.height <= 162, true, "Visible control fits popup content")
        end
    end
    test.equal(f.selector.y, 16)
    test.equal(f.input.content, "Last preset")
end)

test.case("Editor centres controls without resizing host layers and clamps small layouts", function()
    local f = createFixture()
    test.equal(f.parent.width, 580)
    test.equal(f.parent.height, 360)
    test.equal(f.host.width, 600)
    test.equal(f.host.height, 400)
    test.equal(f.title.x, 130)
    test.equal(f.title.y, 91)
    test.equal(f.title.parent, f.parent, "Controls attach directly to supplied layer")
    test.equal(f.title.parentX, nil)
    test.equal(f.title.selfX, nil)
    f.parent.width, f.parent.height = 640, 400
    f.parent.hooks[ui.Hook.ONRESIZE]()
    test.equal(f.title.x, 160)
    test.equal(f.title.y, 111)
    f.parent.width, f.parent.height = 300, 200
    f.parent.hooks[ui.Hook.ONRESIZE]()
    test.equal(f.title.x, 8)
    test.equal(f.title.y, 11)
    test.equal(f.input.x + f.input.width <= 300, true)
    test.equal(f.status.y + f.status.height <= 200, true)
end)

test.case("Plugin Hub settings info stays at the top-right after resizing", function()
    local f = createFixture()
    f:open(nil, { hideTitle = true })
    for _, size in ipairs({ { 580, 360 }, { 700, 400 }, { 300, 240 } }) do
        f.parent.width, f.parent.height = size[1], size[2]
        f.parent.hooks[ui.Hook.ONRESIZE]()
        test.equal(f.info.hidden, false)
        test.equal(f.info.x, size[1] - 8 - 22)
        test.equal(f.info.y, 8)
    end
end)

test.case("Resizable ribbon fits narrow panels and restores the wide layout without losing edits", function()
    local colours = {
        get = function() return "" end,
        save = function() return true end,
    }
    local f = createFixture(colours)
    local first = #f.controls + 1
    f.parent.width, f.parent.height = 260, 260
    f:open(18)
    f.input.content = "Unsaved edit"
    for _, size in ipairs({ { 260, 260 }, { 300, 280 }, { 240, 246 }, { 580, 360 } }) do
        f.parent.width, f.parent.height = size[1], size[2]
        f.parent.hooks[ui.Hook.ONRESIZE]()
        for index = first, #f.controls do
            local c = f.controls[index]
            test.equal(c.x >= 0 and c.x + c.width <= size[1], true, "Control fits panel width")
            test.equal(c.y >= 0 and c.y + c.height <= size[2], true, "Control fits panel height")
        end
        test.equal(f.input.content, "Unsaved edit")
        test.equal(f.selector.selectedID, 17)
    end
    test.equal(f.input.width, 224)
    test.equal(f.title.content, "Custom bank presets")
    test.equal(f.saveCalls, 0)
end)

test.case("Ribbon reports an unavailable PrettyUI dependency before creating controls", function()
    local f = createFixture()
    local dependency = prettyui
    prettyui = nil
    local before = #f.controls
    local ok, message = pcall(function() f:open(nil, { scrollable = true }) end)
    prettyui = dependency
    test.equal(ok, false)
    test.equal(tostring(message):find("PrettyUI is required", 1, true) ~= nil, true)
    test.equal(#f.controls, before)
end)

test.case("Ribbon uses the dependency passed by main even without a module global", function()
    local f = createFixture()
    local dependency = prettyui
    prettyui = nil
    local ok, message = pcall(function()
        f:open(18, { scrollable = true, prettyui = dependency })
    end)
    prettyui = dependency
    test.equal(ok, true, tostring(message))
    test.equal(f.input.parent, f.scrollView.content)
    test.equal(f.selector.selectedID, 17)
    f.destroy()
end)

test.case("Small ribbon panels scroll to Save and reset their offset when enlarged", function()
    local f = createFixture({
        get = function() return "" end, save = function() return true end,
    })
    f.parent.width, f.parent.height = 200, 120
    f:open(18, { scrollable = true })
    f.input.content = "Keep this edit"
    test.equal(f.save.hidden, true)
    test.equal(f.scrollView.scrollbarVisible, true)
    test.equal(f.input.parent, f.scrollView.content)
    test.equal(f.input.width <= f.scrollView.contentWidth, true)
    test.equal(f.input.hooks[ui.Hook.ONSCROLLWHEEL](f.input, 100), false)
    f.refresh()
    test.equal(f.save.hidden, false)
    local visibleY = f.save.y - f.scrollView.scrollY
    test.equal(visibleY >= 0 and visibleY + f.save.height <= 120, true)
    f.parent.width, f.parent.height = 580, 360
    f.parent.hooks[ui.Hook.ONRESIZE]()
    test.equal(f.scrollView.scrollbarVisible, false)
    test.equal(f.scrollView.scrollY, 0)
    test.equal(f.save.hidden, false)
    test.equal(f.input.content, "Keep this edit")
    test.equal(f.selector.selectedID, 17)
    test.equal(f.saveCalls, 0)
    f.destroy()
    test.equal(f.scrollView.destroyed, true)
end)

test.case("Managed ribbon input submits once and uses PrettyUI clipping", function()
    local f = createFixture()
    f.parent.width, f.parent.height = 200, 88
    f:open(18, { scrollable = true })
    test.equal(f.input.contentClipped, true)
    test.equal(f.input.hidden, nil, "PrettyUI clips input visuals rather than hiding the field")
    f.input.content = "Managed input"
    f.input.hooks[ui.Hook.ONCONTENTCHANGED](f.input, 0)
    test.equal(f.saveCalls, 0)
    f.input.hooks[ui.Hook.ONCONTENTCHANGED](f.input, ui.InputFieldActionResult.SUBMIT)
    test.equal(f.saveCalls, 1)
    test.equal(f.stored[18], "Managed input")
    f.parent.height = 400
    f.parent.hooks[ui.Hook.ONRESIZE]()
    test.equal(f.input.contentClipped, false)
    f.destroy()
end)

test.case("Editor info button reveals and hides scope notes without saving or changing edits", function()
    local f = createFixture()
    local originalY = f.input.y
    f.input.content = "Unsaved edit"
    f.info.hooks[ui.Hook.ONCLICK]()
    local text = {}
    for _, control in ipairs(f.controls) do
        if control.kind == "text" then text[control.content] = true end
    end
    test.equal(text["Local appearance changes only."], true)
    test.equal(text["Does not load presets or unlock slots."], true)
    test.equal(text["Stored on this device, per character name."], true)
    test.equal(f.input.y, originalY, "Help must not move the form")
    local note = f.controls[#f.controls]
    f.info.hooks[ui.Hook.ONCLICK]()
    test.equal(note.destroyed, true)
    test.equal(f.input.content, "Unsaved edit")
    test.equal(f.saveCalls, 0)
end)

test.case("Editor popover stays within its host without resizing or losing the selected preset", function()
    local f = createFixture()
    local heights = {}
    f:open(18, { hideTitle = true, externalInfoButton = true,
        onHeightChanged = function(height) heights[#heights + 1] = height end })
    f.toggleInfo()
    f.toggleInfo()
    local layout = require("editor/layout")
    test.equal(#heights, 0, "Popover never requests a layout resize")
    test.equal(f.parent.height, 360)
    test.equal(f.selector.selectedID, 17)
    test.equal(f.saveCalls, 0)
end)

test.case("Selecting the last entry saves and resets slot 18, not slot 17", function()
    local f = createFixture()
    f:select(17)
    test.equal(f.input.content, "Last preset")
    f.input.content = "Edited last preset"
    f:select(0, ui.SelectionChangeEvent.DESELECTED)
    test.equal(f.input.content, "Edited last preset")
    f:clickSave()
    test.equal(f.stored[18], "Edited last preset")
    test.equal(f.stored[17], nil)
    test.equal(f.stored[1], nil)
    f:clickReset()
    test.equal(f.stored[18], "Edited last preset")
    f:clickSave()
    test.equal(f.stored[18], "")
    test.equal(f.input.content, "")
end)

test.case("Invalid selections and reselecting the current slot preserve unsaved edits", function()
    local f = createFixture()
    f.input.content = "Unsaved"
    for _, entryID in ipairs({ -1, 18, 999, 0 }) do
        f:select(entryID)
        test.equal(f.input.content, "Unsaved", "Ignored entry " .. entryID)
    end
    f:clickSave()
    test.equal(f.stored[1], "Unsaved")
end)

test.case("Switching slots discards unsaved edits without writing them", function()
    local f = createFixture()
    f.input.content = "Discard this"
    f:select(17)
    test.equal(f.input.content, "Last preset")
    test.equal(f.saveCalls, 0)
end)

test.case("Enter submits input but ordinary content-change events do not save", function()
    local f = createFixture()
    f.input.content = "Enter saved"
    f.input.hooks[ui.Hook.ONCONTENTCHANGED](f.input, 0)
    test.equal(f.saveCalls, 0)
    f.input.hooks[ui.Hook.ONCONTENTCHANGED](f.input, ui.InputFieldActionResult.SUBMIT)
    test.equal(f.stored[1], "Enter saved")
    test.equal(f.status.content, "Name saved.")
end)

test.case("Rejected saves preserve edits; reset stages defaults without storage", function()
    local f = createFixture()
    f.saveMode = "rejected"
    f.input.content = "Keep this edit"
    f:clickSave()
    test.equal(f.status.content, "Save failed; recovery incomplete. Check customisations and the client console.")
    test.equal(f.status.colour[1] > f.status.colour[2], true, "Failure is red")
    f:clickReset()
    test.equal(f.input.content, "")
    test.equal(f.saveCalls, 2)
    test.equal(f.status.content, "Defaults staged. Click Save to apply.")
    test.equal(f.stored[1], nil)
end)

test.case("Storage exceptions are caught, logged, and displayed without clearing edits", function()
    local f = createFixture()
    f.saveMode = "error"
    f.input.content = "Keep this edit"
    local originalPrint, logged = print, nil
    print = function(message) logged = message end
    local succeeded, message = pcall(function() f:clickSave() end)
    print = originalPrint -- Restore even if the editor unexpectedly throws.
    test.equal(succeeded, true, message)
    test.equal(logged:find("Simulated storage exception", 1, true) ~= nil, true)
    test.equal(f.status.content, "Save failed; recovery incomplete. Check customisations and the client console.")
    test.equal(f.input.content, "Keep this edit")
end)

for _, action in ipairs({ "save", "reset" }) do
    test.case("Character changes block a stale " .. action, function()
        local f = createFixture()
        f.input.content = "Previous character edit"
        f.context, f.stored = "second", { [1] = "Other character" }
        if action == "save" then f:clickSave() else f:clickReset() end
        test.equal(f.saveCalls, 0)
        test.equal(f.input.content, "Other character")
        test.equal(f.status.content, "Character changed. Enter the name again.")
    end)
end

test.case("Tick refresh follows character changes and logout but preserves same-character edits", function()
    local f = createFixture()
    f.input.content = "Unsaved edit"
    f.refresh()
    test.equal(f.input.content, "Unsaved edit")
    f.context, f.stored = "second", { [1] = "Second character" }
    f.refresh()
    test.equal(f.input.content, "Second character")
    f.context, f.stored = nil, {}
    f.refresh()
    test.equal(f.input.content, "")
    test.equal(f.status.content, "Log in and wait for your character name.")
end)

test.case("Reopening starts at preset 1 without overwriting saved settings", function()
    local f = createFixture()
    f.stored[1] = "First preset"
    f:select(17)
    f:open()
    test.equal(f.selector.selectedID, 0)
    test.equal(f.input.content, "First preset")
    test.equal(f.stored[18], "Last preset")
    test.equal(f.saveCalls, 0)
end)

local function iconFixture(mockPicker)
    local data, writes, opened = { [1] = "skills:farming" }, 0, {}
    local store = {
        normalize = dofile("presets/icons.lua").normalize,
        get = function(slot) return data[slot] or "" end,
        save = function(slot, value)
            test.equal(slot == 19, false)
            data[slot], writes = value, writes + 1
            return true
        end,
    }
    local old = package.loaded["components/icon_picker/init"]
    if mockPicker ~= false then
        package.loaded["components/icon_picker/init"] = { open = function(host, options)
            local popup = { options = options, host = host, moves = 0 }
            opened[#opened + 1] = popup
            return function()
                if popup.closed then return end
                popup.closed = true
                options.onClose()
            end, function() popup.moves = popup.moves + 1 end
        end }
    end
    local colours = { get = function() return "" end, save = function() return true end }
    local f = createFixture(colours, store)
    package.loaded["components/icon_picker/init"] = old
    f.iconData, f.iconPopups = data, opened
    function f:iconWrites() return writes end
    function f:iconButton()
        for index = #self.controls, 1, -1 do
            local c = self.controls[index]
            if c.kind == "button" and c.width == 58 then return c end
        end
    end
    function f:openIcons() self:iconButton().hooks[ui.Hook.ONBUTTONPRESSED]() end
    function f:iconNumber()
        for index = #self.controls, 1, -1 do
            local c = self.controls[index]
            if c.kind == "text" and c.width == 24 and c.height == 24 then return c end
        end
    end
    function f:stageIcon(key)
        self:openIcons()
        local popup = opened[#opened]
        popup.closed = true
        popup.options.onClose()
        popup.options.onSelect(key)
    end
    function f:skillPreviews()
        local resource = require("presets/icon_catalogue").resolve("skills:necromancy")
        local found = {}
        if resource == nil then return found end
        for _, c in ipairs(self.controls) do
            if c.kind == "sprite" and c.sprite == resource and not c.hidden then found[#found + 1] = c end
        end
        return found
    end
    return f
end

test.case("Editor icon choices are staged, previewed, saved and restored on reopen", function()
    local f = iconFixture()
    f:stageIcon("skills:necromancy")
    test.equal(f:iconWrites(), 0)
    test.equal(f.iconData[1], "skills:farming")
    test.equal(#f:skillPreviews(), 2, "Control and preset preview share the catalogue")
    f.refresh()
    test.equal(#f:skillPreviews(), 2)
    f.input.content = ""
    f:clickSave()
    test.equal(f.iconData[1], "skills:necromancy")
    test.equal(f:iconWrites(), 1)
    test.equal(f.selector.entries[0], "Preset 1 *")
    f:open()
    test.equal(f:iconNumber().hidden, true)
end)

test.case("Popup removes the preset heading and its space while retaining unsaved feedback", function()
    local f = createFixture({ get = function() return "" end })
    local layout = require("editor/layout")
    local height = layout.compactBodyHeight + layout.colourHeight
        - layout.popupEditorGapReduction - layout.popupHeadingRemoval
    f.parent.height = height
    f:open(18, { hideTitle = true, readOnlyPreset = true, hidePresetHeading = true, formHeight = height })
    local indicator
    for _, control in ipairs(f.controls) do
        test.equal(control.content == "Preset 18 - Last preset", false)
        if control.content == "Unsaved" then indicator = control end
    end
    test.equal(f.input.y, layout.padding)
    test.equal(f.status.y + f.status.height <= height, true)
    f.input.content = "Changed"
    f.input.hooks[ui.Hook.ONCONTENTCHANGED](f.input)
    test.equal(indicator.hidden, false)
end)

test.case("Editor item previews use the available space without overlapping the control arrow", function()
    local f = iconFixture()
    f:stageIcon("item:31725")
    local previews = {}
    for _, control in ipairs(f.controls) do
        if control.kind == "sprite" and control.associatedObjectID == 31725 and not control.hidden then
            previews[#previews + 1] = control
        end
    end
    test.equal(#previews, 2)
    local preview, buttonIcon = previews[1], previews[2]
    local button = f:iconButton()
    test.equal(preview.width, 28)
    test.equal(preview.height <= 30, true)
    test.equal(buttonIcon.x >= button.x and buttonIcon.x + buttonIcon.width <= button.x + 32, true)
    test.equal(buttonIcon.y >= button.y and buttonIcon.y + buttonIcon.height <= button.y + button.height, true)
end)

test.case("Editor icon reset and full Reset stage defaults until Save", function()
    local f = iconFixture()
    f:stageIcon("skills:necromancy")
    local button = f:iconButton()
    local reset
    for _, c in ipairs(f.controls) do
        if c.kind == "sprite" and c.sprite == id.Sprite.RS3_ICON_STOPWATCH_RESET_0
            and c.y == button.y + 2 then reset = c end
    end
    test.equal(reset ~= nil, true)
    reset.hooks[ui.Hook.ONCLICK]()
    test.equal(f:iconNumber().content, "1")
    test.equal(f:iconNumber().hidden, false)
    test.equal(f:iconWrites(), 0)
    f:stageIcon("skills:necromancy")
    f:clickReset()
    test.equal(f:iconNumber().hidden, false)
    test.equal(f.iconData[1], "skills:farming")
    f:clickSave()
    test.equal(f.iconData[1], "")
end)

test.case("Preset changes and disposal discard staged icon edits and close their picker", function()
    local f = iconFixture()
    f:stageIcon("skills:necromancy")
    f:openIcons()
    local old = f.iconPopups[#f.iconPopups]
    f.selectSlot(2)
    test.equal(old.closed, true)
    old.options.onSelect("skills:magic")
    test.equal(f:iconNumber().content, "2")
    test.equal(f:iconNumber().hidden, false)
    f.selectSlot(1)
    f:openIcons()
    test.equal(f.iconPopups[#f.iconPopups].options.initial, "skills:farming")
    f.destroy()
    test.equal(f.iconPopups[#f.iconPopups].closed, true)
    test.equal(f:iconWrites(), 0)
end)

test.case("Icon and colour pickers are mutually exclusive and same-button clicks toggle", function()
    local f = iconFixture()
    f:openIcons()
    local first = f.iconPopups[1]
    f:openIcons()
    test.equal(first.closed, true)
    test.equal(#f.iconPopups, 1)
    f:openIcons()
    local swatch
    for _, c in ipairs(f.controls) do
        if c.kind == "rectangle" and c.width == 54 and c.height == 20 then swatch = swatch or c end
    end
    swatch.hooks[ui.Hook.ONCLICK]()
    test.equal(f.iconPopups[2].closed, true)
    local colourRoot
    for _, c in ipairs(f.controls) do
        if c.kind == "layer" and c.width == 288 then colourRoot = c end
    end
    f:openIcons()
    test.equal(colourRoot.destroyed, true)
end)

test.case("Character changes reject stale icon callbacks and failed saves preserve the draft", function()
    local f = iconFixture()
    f:stageIcon("skills:necromancy")
    f.saveMode = "rejected"
    f:clickSave()
    test.equal(f.iconData[1], "skills:farming")
    test.equal(#f:skillPreviews(), 2)
    f.saveMode = "success"
    f:openIcons()
    local old = f.iconPopups[#f.iconPopups]
    f.context = "second"
    old.options.onSelect("skills:magic")
    f.refresh()
    test.equal(old.closed, true)
    test.equal(f:iconWrites(), 0)
end)

test.case("BoB hides icon controls and unavailable sprites retain the preview number", function()
    local f = iconFixture()
    f:stageIcon("skills:necromancy")
    local entry = require("presets/icon_catalogue").get("skills:necromancy")
    local oldResource = id.Sprite[entry.sprite]
    id.Sprite[entry.sprite] = nil
    f.refresh()
    test.equal(f:iconNumber().content, "1")
    test.equal(f:iconNumber().hidden, false)
    test.equal(#f:skillPreviews(), 0)
    for _, c in ipairs(f.controls) do
        if c.kind == "sprite" and c.sprite == oldResource then test.equal(c.hidden, true) end
        if c.kind == "text" and c.content == "1" then test.equal(c.hidden, false) end
    end
    f.bindings = dofile("bank/bindings.lua")
    f.bindings.colours = { get = function() return "" end, save = function() return true end }
    f.bindings.icons = { get = function() return "" end, normalize = dofile("presets/icons.lua").normalize,
        save = function() error("BoB must not write icons") end }
    ui.Interfaces = { GetComponent = function() return nil end }
    f:open(19)
    test.equal(f:iconButton().hidden, true)
    f.refresh()
    test.equal(f:iconButton().hidden, true)
    f:clickReset()
    f:clickSave()
end)

test.case("BoB removes the unused icon row when switching presets", function()
    local f = createFixture()
    f.bindings = dofile("bank/bindings.lua")
    ui.Interfaces = { GetComponent = function() return nil end }
    f.bindings.colours = { get = function() return "" end, save = function() return true end }
    f.bindings.icons = { get = function() return "" end, save = function() return true end,
        normalize = function(value) return value end }
    f.bindings.iconText = { get = function() return "" end, save = function() return true end,
        normalize = function(value) return value end }
    local first = #f.controls + 1
    f:open(1, { hideTitle = true, readOnlyPreset = true, hidePresetHeading = true })
    local iconText, colour
    for index = first, #f.controls do
        local control = f.controls[index]
        if control.content == "Icon text:" then iconText = control end
        if control.content == "Background colour:" then colour = control end
    end
    local textY, colourY, saveY = iconText.y, colour.y, f.save.y
    f.selectSlot(19)
    local row = require("editor/layout").iconHeight
    test.equal(iconText.y, textY - row)
    test.equal(colour.y, colourY - row)
    test.equal(f.save.y, saveY - row)
    f.selectSlot(1)
    test.equal(iconText.y, textY)
    test.equal(colour.y, colourY)
    test.equal(f.save.y, saveY)
end)

test.case("The real icon picker stages an available catalogue entry in the editor", function()
    local f = iconFixture(false)
    f:openIcons()
    local tile
    for _, c in ipairs(f.controls) do
        if c.kind == "button" and c.width == 40 and c.height == 40 then tile = tile or c end
    end
    test.equal(tile ~= nil, true)
    tile.hooks[ui.Hook.ONBUTTONPRESSED]()
    test.equal(f:iconWrites(), 0)
    f:clickSave()
    test.equal(f.iconData[1], "skills:runecrafting")
end)

test.case("Icon row aligns above colours and fits narrow clipped layouts", function()
    local f = iconFixture(false)
    local iconLabel, colourLabel
    for _, c in ipairs(f.controls) do
        if c.content == "Icon:" then iconLabel = c end
        if c.content == "Background colour:" then colourLabel = c end
    end
    test.equal(colourLabel.y - iconLabel.y, require("editor/layout").iconHeight)
    test.equal(iconLabel.x, colourLabel.x)
    f.parent.width, f.parent.height = 200, 100
    f:open(nil, { scrollable = true })
    local button = f:iconButton()
    test.equal(button.x + button.width <= f.scrollView.contentWidth, true)
    test.equal(button.hidden, true, "Below-viewport icon row stays clipped")
    f.scrollView:SetScrollPosition(80)
    f.refresh()
    test.equal(button.hidden, false)
    f.destroy()
end)

test.case("Icon control draws a click-through dropdown arrow without font glyphs", function()
    local f = iconFixture(false)
    local button = f:iconButton()
    test.equal(button.label, "")
    local rows = 0
    for _, c in ipairs(f.controls) do
        if c.kind == "rectangle" and c.height == 1 and c.x >= button.x + 40
            and c.x <= button.x + 43 and c.y >= button.y + 11 and c.y <= button.y + 14 then
            rows = rows + 1
            test.equal(c.clickthrough, true)
            test.equal(c.fill, true)
            test.equal(c.x + c.width <= button.x + button.width, true)
        end
    end
    test.equal(rows, 4)
end)

test.case("Editor icon overlay registers, follows movement, and closes when hidden", function()
    local f = iconFixture(false)
    local owner = prettyui.SimpleView.new(f.parent, { width = 580, height = 360 })
    owner.overlays = {}
    function owner:_RegisterOverlay(root, _, position) self.overlays[root] = position end
    function owner:_UnregisterOverlay(root) self.overlays[root] = nil end
    function owner:_SyncOverlays()
        for _, position in pairs(self.overlays) do position() end
    end
    f:open(nil, { contentHost = owner })
    f:iconButton().xyGlobal = { x = 50, y = 50 }
    f:openIcons()
    local root = next(owner.overlays)
    test.equal(root ~= nil, true)
    local x = root.x
    f:iconButton().xyGlobal.x = 100
    f.refresh()
    test.equal(root.x, x + 50)
    f.parent.visibleGlobal = false
    f.refresh()
    test.equal(root.destroyed, true)
    test.equal(next(owner.overlays), nil)
end)
