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
        if options.prettyui == nil then options.prettyui = prettyui end
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
                     - (options.hideTitle and 162 or 194)) / 2))
                    + 194 - (options.hideTitle and 32 or 0) then self.note = control
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

return createFixture
