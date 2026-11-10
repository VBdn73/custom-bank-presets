local test = require("tests.test_helper")

test.case("PrettyUI popup retains bank ownership, selected slot and safe cleanup", function()
    local previousDB = PersistentDB
    local stored = {}
    PersistentDB = {
        GetString = function(_, key) return stored[key] end,
        SetString = function(_, key, value) stored[key] = value; return true end,
    }
    local previousEditor = package.loaded["editor/view"]
    local built, windows, infoClicks, sprites = {}, {}, 0, {}
    local selected = {}
    local root = { width = 900, height = 890 }
    local bank = { parent = root }
    local source = { parent = bank, visibleGlobal = true }
    local function control(parent)
        local c = { parent = parent }
        function c:SetPos(x, y, xa, ya) self.x, self.y, self.xAnchor, self.yAnchor = x, y, xa, ya end
        function c:SetSize(w, h) self.width, self.height = w, h end
        function c:Subscribe(_, callback) self.callback = callback end
        function c:Destroy() self.destroyed = true end
        return c
    end
    local previousVector4 = Vector4
    Vector4 = { new = function(...) return { ... } end }
    local rectangles = {}
    ui = { Interfaces = { GetComponent = function() return source end },
        Rectangle = { new = function(parent)
            local c = control(parent)
            rectangles[#rectangles + 1] = c
            return c
        end },
        Sprite = { new = function(parent)
            local c = control(parent)
            sprites[#sprites + 1] = c
            return c
        end }, Hook = { ONCLICK = 1 } }
    id = { Font = { CINZEL_13PT_REGULAR = 10, CINZEL_13PT_BOLD = 11 }, Sprite = { RS3_BUTTON_INFO_PARENT_0 = 1,
        RS3_BUTTON_INFO_PARENT_1 = 2, RS3_BUTTON_INFO_PARENT_2 = 3,
        RS3_BUTTON_CLOSE_PARENT_0 = 4, RS3_BUTTON_CLOSE_PARENT_1 = 5,
        RS3_BUTTON_CLOSE_PARENT_2 = 6, RS3_MODAL_WINDOW_1_TOP_TILE = 7,
        RS3_PARENT_FRAME_TOP_CORNER = 8 } }
    local library = { Window = { new = function(parent, options)
        local w = { root = control(parent), options = options, titleText = control(parent), overlays = {},
            background = control(parent), closeButton = control(parent),
            titleRight = control(parent), titleDrag = control(parent) }
        function w:_RegisterOverlay(c, _, position) self.overlays[c] = position end
        function w:_UnregisterOverlay(c) self.overlays[c] = nil end
        function w:_SyncOverlays(hidden)
            for c, position in pairs(self.overlays) do position(); c.hidden = hidden end
        end
        w.root:SetPos(options.x, options.y)
        w.root:SetSize(options.width, options.height)
        w.content = control(w.root)
        w.content:SetSize(options.width - 16, options.height - 40)
        function w:Destroy() self.destroyed = true end
        windows[#windows + 1] = w
        return w
    end } }
    package.loaded["editor/view"] = { build = function(parent, names, bindings, slot, options)
        built[#built + 1] = { parent = parent, slot = slot, options = options }
        return function() if parent.disposed then error("Disposed") end end,
            function() infoClicks = infoClicks + 1 end, nil,
            function(slot) selected[#selected + 1] = slot end
    end }
    local popup = dofile("editor/popup.lua")
    package.loaded["editor/view"] = previousEditor
    local bindings = require("bank/bindings")
    popup.open(18, {}, bindings, library)
    local first = windows[1]
    test.equal(first.root.parent, root, "Host is outside the bank popover")
    test.equal(first.root.x, 274)
    test.equal(first.root.y, math.floor((890 - first.root.height) / 2))
    test.equal(first.options.scrollable, false)
    test.equal(first.options.title, "Custom bank preset 18")
    test.equal(built[1].slot, 18)
    test.equal(built[1].options.contentHost, first)
    test.equal(built[1].options.prettyui, library, "Bank editor forwards PrettyUI to the icon picker")
    test.equal(built[1].options.hideTitle, true)
    test.equal(built[1].options.readOnlyPreset, true)
    test.equal(built[1].options.hidePresetHeading, true)
    test.equal(built[1].options.externalInfoButton, true)
    test.equal(built[1].options.bankButtons, true)
    test.equal(first.background.sprite, nil, "Keep the window's existing background")
    test.equal(rectangles[1].parent, first.content)
    test.equal(rectangles[1].width, first.content.width)
    test.equal(rectangles[1].height, first.content.height)
    test.equal(rectangles[1].fill, true)
    test.equal(rectangles[1].clickthrough, true)
    test.equal(rectangles[1].colour[4], 0.035)
    test.equal(first.titleText.font, nil, "Keep the window's existing title font")
    test.equal(first.titleText.rgba, 0xD6A65CFF)
    test.equal(first.closeButton.hidden, true, "Use the native close sprite instead of PrettyUI's modal icon")
    test.equal(built[1].options.infoParent, first.root)
    local info, close = sprites[1], sprites[2]
    test.equal(first.titleRight.spriteID, nil, "Keep the original complete title corner")
    test.equal(info.parent, first.root, "Header buttons move with the window")
    test.equal(close.parent, first.root)
    test.equal(first.titleDrag.width, first.root.width - 70)
    test.equal(info.width, 20)
    test.equal(info.sprite, 1)
    test.equal(close.width, 20)
    test.equal(close.sprite, 4)
    test.equal(close.x, -28)
    test.equal(close.y, 7)
    test.equal(info.y, 7)
    test.equal(info.x, -52, "Help sits beside close")
    test.equal(info.xAnchor, 1)
    first.root:SetPos(100, 120)
    popup.update()
    test.equal(info.x, -52, "Buttons retain their window-relative position")
    test.equal(info.y, 7)
    test.equal(close.x, -28)
    first.dragFeedback = {}
    first.titleDrag:SetSize(900, 890)
    popup.update()
    test.equal(first.titleDrag.width, 900, "Do not disturb active drag capture")
    first.dragFeedback = nil
    popup.update()
    test.equal(first.titleDrag.width, first.root.width - 70)
    first.root.hidden = true
    popup.update()
    test.equal(first.root.hidden, true, "Child buttons inherit window visibility")
    first.root.hidden = false
    info.callback()
    test.equal(infoClicks, 1)
    test.equal(first.destroyed, nil, "Help must not close the window")
    source = { parent = bank, visibleGlobal = true }
    popup.update()
    test.equal(first.destroyed, nil, "Fresh native wrappers must not close the popup")
    popup.select(3)
    test.equal(selected[#selected], 3, "Native selection selects the preset to edit")
    test.equal(first.titleText.content, "Custom bank preset 3")
    popup.select(0)
    test.equal(first.titleText.content, "Custom bank preset 3", "Invalid selections leave the title unchanged")
    popup.select(19)
    test.equal(first.titleText.content, "Custom bank preset - BoB")
    test.equal(#windows, 1, "Switch presets without rebuilding the window")
    info.isMouseOver = true
    popup.update()
    test.equal(info.sprite, 2)
    close.isMouseOver = true
    popup.update()
    test.equal(close.sprite, 5)
    popup.open(2, {}, bindings, library)
    test.equal(first.destroyed, true)
    test.equal(next(first.overlays), nil)
    test.equal(built[2].slot, 2)
    test.equal(windows[2].root.x, 100, "Reopening retains dragged x")
    test.equal(windows[2].root.y, 120, "Reopening retains dragged y")
    sprites[4].callback()
    test.equal(windows[2].destroyed, true)
    test.equal(stored["presetEditor.position.v1"], "100,120")
    popup.close()
    local selections = #selected
    popup.select(4)
    test.equal(#selected, selections, "Selections after closing do not touch disposed controls")
    popup.open(3, {}, bindings, library)
    built[3].parent.disposed = true
    popup.update()
    test.equal(windows[3].destroyed, true)
    for _, unavailable in ipairs({ "hidden", "restricted", "missing" }) do
        source = { parent = bank, visibleGlobal = true }
        popup.open(1, {}, bindings, library)
        local opened = windows[#windows]
        if unavailable == "hidden" then source.visibleGlobal = false
        elseif unavailable == "restricted" then source.isRestricted = true
        elseif unavailable == "replaced" then source = { parent = bank, visibleGlobal = true }
        else source = nil end
        popup.update()
        test.equal(opened.destroyed, true, "Close when bank source becomes " .. unavailable)
    end
    source = { parent = bank, visibleGlobal = true }
    popup.open(1, {}, { labels = bindings.labels, colours = {} }, library)
    local layout = require("editor/layout")
    test.equal(built[#built].options.formHeight,
        layout.compactBodyHeight + layout.colourHeight - layout.popupEditorGapReduction - layout.popupHeadingRemoval)
    test.equal(windows[#windows].content.height, built[#built].options.formHeight)
    popup.open(1, {}, { labels = bindings.labels, colours = {}, icons = {} }, library)
    test.equal(built[#built].options.formHeight,
        layout.compactBodyHeight + layout.colourHeight + layout.iconHeight - layout.popupEditorGapReduction - layout.popupHeadingRemoval)
    test.equal(windows[#windows].content.height, built[#built].options.formHeight)
    popup.close()
    local count = #windows
    source.visibleGlobal = false
    popup.open(1, {}, bindings, library)
    source = nil
    popup.open(1, {}, bindings, library)
    test.equal(#windows, count)
    source = { parent = bank, visibleGlobal = true }
    package.loaded["editor/view"] = { build = function() return function() end, function() end end }
    local reloaded = dofile("editor/popup.lua")
    package.loaded["editor/view"] = previousEditor
    reloaded.open(1, {}, bindings, library)
    test.equal(windows[#windows].root.x, 100, "Position survives module reload")
    test.equal(windows[#windows].root.y, 120)
    reloaded.close()
    root.width, root.height = 400, 350
    reloaded.open(1, {}, bindings, library)
    local bounded = windows[#windows]
    test.equal(bounded.root.x, math.max(0, root.width - bounded.root.width))
    test.equal(bounded.root.y, math.min(120, math.max(0, root.height - bounded.root.height)))
    reloaded.close()
    PersistentDB = previousDB
    Vector4 = previousVector4
end)
