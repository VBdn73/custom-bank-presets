local test = require("tests.test_helper")

local function fixture()
    local f = { labels = {}, selected = {}, sprites = {}, backgrounds = {}, colours = {}, messages = {}, order = {}, texts = {}, iconTexts = {} }
    local bindings = dofile("bank/bindings.lua").compactButtons
    function f.label(index)
        return { type = 1, content = tostring(index), rgba = 0xFFCB75FF,
            parent = { visibleGlobal = true }, x = 7, y = 11, width = 30, height = 30, visibleGlobal = true }
    end
    for index = 1, 9 do f.labels[index] = f.label(index) end
    local environment = setmetatable({
        print = function(message) f.messages[#f.messages + 1] = message end,
        require = function(path)
            if path == "presets/icon_catalogue" then
                return { resolve = function(key)
                    if key == "skill" then return 101, { width = 32, height = 16 } end
                    if key == "large" then return 102, { width = 64, height = 64 } end
                    if key == "item" then return 31725, { objectID = 31725, width = 36, height = 32 } end
                end, apply = function(sprite, assetID, entry)
                    if entry.objectID then sprite:SetAssociatedObject(assetID)
                    else require("presets/icon_catalogue").apply(sprite, assetID, entry) end
                end }
            end
            return require(path)
        end,
        id = { Font = { MUSEO_SANS_11PT_REGULAR = 11 } },
        ui = { ComponentType = { LABEL = 1, SPRITE = 2 }, AlignMode = { CENTRE = 1 },
            ObjectQuantityDisplayMode = { NEVER = 0 }, Interfaces = {
            GetComponent = function(_, interfaceID, staticID, categoryID, dynamicID)
                test.equal(interfaceID, 517)
                test.equal(staticID, 117)
                test.equal(categoryID, 0)
                if dynamicID == 133 then return f.bob end
                if dynamicID == 134 then return f.bobIcon end
                return f.labels[(dynamicID - 9) / 11 + 1]
            end,
        }, Text = { new = function(parent, categoryID, dynamicID)
            test.equal(categoryID, 3)
            local text = { parent = parent, dynamicID = dynamicID }
            function text:SetSize(w, h) self.width, self.height = w, h end
            function text:SetPos(x, y) self.x, self.y = x, y end
            function text:Destroy() self.destroyed = true end
            function text:MoveToFront() f.order[#f.order + 1] = self end
            f.texts[#f.texts + 1] = text
            return text
        end }, Sprite = { new = function(parent, categoryID, dynamicID)
            if f.creationFails then return nil end
            assert(type(categoryID) == "number" and categoryID % 1 == 0
                and categoryID >= 0 and categoryID <= 256, "Invalid sprite category ID")
            assert(type(dynamicID) == "number" and dynamicID % 1 == 0
                and dynamicID >= 0 and dynamicID <= 256, "Invalid sprite dynamic ID")
            test.equal(categoryID, 1, "Plugin children must not inherit native category 0")
            test.equal(dynamicID >= 1 and dynamicID <= 10, true)
            local sprite = { parent = parent, visibleGlobal = f.initialSpriteVisibility,
                categoryID = categoryID, dynamicID = dynamicID }
            function sprite:SetAssociatedObject(objectID) self.associatedObjectID = objectID end
            function sprite:SetSize(w, h)
                if f.layoutFails then error("Injected layout failure") end
                self.width, self.height = w, h
            end
            function sprite:SetPos(x, y) self.x, self.y = x, y end
            function sprite:Destroy() self.destroyed = true end
             function sprite:MoveToFront()
                 f.order[#f.order + 1] = self
                self.frontMoves = (self.frontMoves or 0) + 1
                self.occluded = false
            end
            setmetatable(sprite, { __index = function(self, key)
                if key == "spriteID" then return f.assignmentFails and -1 or self.sprite end
            end })
            f.sprites[#f.sprites + 1] = sprite
            return sprite
        end }, Rectangle = { new = function(parent, categoryID, dynamicID)
            if f.backgroundFails then return nil end
            test.equal(categoryID, 2)
            local rectangle = { parent = parent, dynamicID = dynamicID }
            function rectangle:SetSize(w, h) self.width, self.height = w, h end
            function rectangle:SetPos(x, y) self.x, self.y = x, y end
            function rectangle:MoveToFront() f.order[#f.order + 1] = self end
            function rectangle:Destroy() self.destroyed = true end
            f.backgrounds[#f.backgrounds + 1] = rectangle
            return rectangle
        end } },
    }, { __index = _G })
    f.renderer = assert(loadfile("bank/compact_icons.lua", "t", environment))()
    f.store = { get = function(slot) return f.selected[slot] end }
    function f.update()
        f.renderer.update(bindings, f.store, not f.hideBackgrounds and { rgba = function(slot, kind)
            test.equal(kind, "background")
            return f.colours[slot]
        end }, { get = function(slot) return f.iconTexts[slot] or "" end })
    end
    function f.page(offset)
        for index = 1, 9 do f.labels[index].content = tostring(index + offset) end
    end
    function f.live()
        local count = 0
        for _, sprite in ipairs(f.sprites) do if not sprite.destroyed then count = count + 1 end end
        return count
    end
    return f
end

test.case("Blank hides compact numbers and follows page changes", function()
    local f = fixture()
    f.selected[1] = "blank"
    f.update()
    test.equal(f.labels[1].rgba & 0xFF, 0)
    test.equal(f.labels[1].content, "1")
    test.equal(f.live(), 0)
    f.page(9)
    f.update()
    test.equal(f.labels[1].rgba, 0xFFCB75FF)
    f.page(0)
    f.update()
    test.equal(f.labels[1].rgba & 0xFF, 0)
    f.selected[1] = nil
    f.update()
    test.equal(f.labels[1].rgba, 0xFFCB75FF)
end)

test.case("Compact item canvas expands within the button interior and follows resizing", function()
    local f = fixture()
    f.selected[1] = "item"
    f.update()
    local icon, label = f.sprites[1], f.labels[1]
    test.equal(icon.width, 26)
    test.equal(icon.height, 23)
    test.equal(icon.x >= label.x + 2 and icon.x + icon.width <= label.x + label.width - 2, true)
    test.equal(icon.y >= label.y + 2 and icon.y + icon.height <= label.y + label.height - 2, true)
    label.width, label.height = 20, 20
    f.update()
    test.equal(icon.width, 16)
    test.equal(icon.x >= label.x + 2 and icon.x + icon.width <= label.x + label.width - 2, true)
    test.equal(icon.y >= label.y + 2 and icon.y + icon.height <= label.y + label.height - 2, true)
end)

test.case("Compact icon text follows icons, page switches, visibility and resets", function()
    local f = fixture()
    f.iconTexts[1], f.iconTexts[10] = "WAS", "10A"
    f.update()
    local text = f.texts[1]
    assert(text, table.concat(f.messages, "; "))
    test.equal(text.content, "WAS")
    test.equal(text.width, 40)
    test.equal(text.maxLines, 1)
    test.equal(text.y, f.labels[1].y)
    test.equal(f.labels[1].content, "1")
    test.equal(f.labels[1].rgba, 0xFFCB7500)
    f.labels[1].rgba = 0x00000000
    f.update()
    test.equal(text.rgba, 0xFFCB75FF, "Native hover transparency must not hide custom text")
    f.labels[1].rgba = 0xFFCB75FF
    f.update()
    f.selected[1] = "skill"
    f.update()
    test.equal(text.destroyed, true)
    text = f.texts[2]
    test.equal(text.y, f.labels[1].y + 6)
    test.equal(f.order[#f.order], text)
    f.labels[1].hidden = true
    f.update()
    test.equal(text.hidden, true)
    f.labels[1].hidden = false
    f.page(9)
    f.update()
    test.equal(text.destroyed, true)
    test.equal(f.texts[3].content, "10A")
    f.iconTexts[10] = ""
    f.update()
    test.equal(f.texts[3].destroyed, true)
    test.equal(f.labels[1].rgba, 0xFFCB75FF)
end)

test.case("Compact BoB background follows the setting and saved colour without a custom icon", function()
    local f = fixture()
    f.bob = f.label(19)
    f.bobIcon = { type = 2, spriteID = 18787, width = 24, height = 24 }
    f.colours[19] = 0x123456FF
    f.update()
    test.equal(#f.messages, 0)
    test.equal(f.sprites[1].sprite, 18787)
    test.equal(f.backgrounds[1].width, 26)
    test.equal(f.backgrounds[1].height, 24)
    test.equal(f.backgrounds[1].rgba, 0x123456FF)
    test.equal(f.bob.rgba, 0xFFCB7500)
    f.page(9)
    f.colours[19] = 0xABCDEF80
    f.update()
    test.equal(f.backgrounds[1].rgba, 0xABCDEF80)
    f.hideBackgrounds = true
    f.update()
    test.equal(f.backgrounds[1].destroyed, true)
    test.equal(f.bob.rgba, 0xFFCB75FF)
    f.hideBackgrounds = false
    f.update()
    test.equal(f.sprites[2].sprite, 18787)
    local old = f.bob
    f.bob = nil
    f.update()
    test.equal(old.rgba, 0xFFCB75FF)
    test.equal(f.sprites[2].destroyed, true)
    f.bob = old
    f.update()
    f.renderer.restore()
    test.equal(f.bob.rgba, 0xFFCB75FF)
    test.equal(f.live(), 0)
end)

test.case("Compact backgrounds toggle live without changing icons or saved colours", function()
    local f = fixture()
    f.selected[1], f.colours[1] = "skill", 0x123456FF
    f.update()
    local sprite = f.sprites[1]
    f.hideBackgrounds = true
    f.update()
    for _, background in ipairs(f.backgrounds) do test.equal(background.destroyed, true) end
    test.equal(sprite.destroyed, nil)
    test.equal(#f.sprites, 1)
    test.equal(f.colours[1], 0x123456FF)
    f.hideBackgrounds = false
    f.update()
    test.equal(f.backgrounds[4].rgba, 0x123456FF)
    test.equal(#f.sprites, 1)
end)

test.case("Compact icons centre full-colour non-interactive siblings without clearing native text", function()
    local f = fixture()
    f.selected[1] = "skill"
    f.update()
    local sprite = f.sprites[1]
    test.equal(sprite.parent, f.labels[1].parent)
    test.equal(sprite.width, 24)
    test.equal(sprite.height, 12)
    test.equal(sprite.x, 10)
    test.equal(sprite.y, 20)
    test.equal(sprite.rgba, 0xFFFFFFFF)
    test.equal(sprite.clickthrough, true)
    test.equal(sprite.enabled, false)
    test.equal(sprite.categoryID, 1)
    test.equal(sprite.dynamicID, 1)
    test.equal(sprite.frontMoves, 1)
    test.equal(f.labels[1].content, "1")
    test.equal(f.labels[1].rgba, 0xFFCB7500)
    f.update()
    test.equal(#f.sprites, 1)
    test.equal(sprite.frontMoves, 2, "Reassert render order after native sibling redraws")
    f.selected[1] = nil
    f.update()
    test.equal(f.live(), 0)
    test.equal(f.labels[1].rgba, 0xFFCB75FF)
end)

test.case("Compact backgrounds follow saved colours, geometry, visibility and resets behind untinted icons", function()
    local f = fixture()
    f.selected[1], f.colours[1] = "skill", 0x123456FF
    f.update()
    local background, sprite = f.backgrounds[1], f.sprites[1]
    test.equal(background.parent, sprite.parent)
    test.equal(background.fill, true)
    test.equal(background.clickthrough, true)
    test.equal(background.enabled, false)
    test.equal(background.width, 26, "Background fills the interior without covering the bevel")
    test.equal(background.height, 24)
    test.equal(background.x, 9)
    test.equal(background.y, 14)
    test.equal(background.rgba, 0x123456FF)
    test.equal(f.order[#f.order - 3], background)
    test.equal(f.backgrounds[2].width, 24)
    test.equal(f.backgrounds[2].height, 1)
    test.equal(f.backgrounds[2].x, 10)
    test.equal(f.backgrounds[2].y, 13)
    test.equal(f.backgrounds[3].y, 38)
    test.equal(f.order[#f.order], sprite)
    test.equal(sprite.rgba, 0xFFFFFFFF)
    f.colours[1] = 0xABCDEF80
    f.labels[1].x, f.labels[1].hidden = 15, true
    f.update()
    test.equal(#f.backgrounds, 3)
    test.equal(background.rgba, 0xABCDEF80)
    test.equal(background.x, 17)
    test.equal(background.hidden, true)
    f.colours[1] = nil
    f.update()
    test.equal(background.destroyed, true)
    test.equal(sprite.destroyed, nil)
    test.equal(#f.sprites, 1)
end)

test.case("Compact backgrounds follow page identity and are removed on shutdown or icon reset", function()
    local f = fixture()
    f.selected[1], f.selected[10] = "skill", "skill"
    f.colours[1], f.colours[10] = 0x123456FF, 0xABCDEFff
    f.update()
    local first = f.backgrounds[1]
    f.page(9)
    f.update()
    test.equal(first.destroyed, true)
    test.equal(f.backgrounds[4].rgba, f.colours[10])
    f.selected[10] = nil
    f.update()
    test.equal(f.backgrounds[4].destroyed, true)
    f.selected[10] = "skill"
    f.update()
    f.renderer.restore()
    test.equal(f.backgrounds[7].destroyed, true)
    test.equal(f.live(), 0)
end)

test.case("Compact background setup failure retains native numbers and cleans up sprites", function()
    local f = fixture()
    f.selected[1], f.colours[1], f.backgroundFails = "skill", 0x123456FF, true
    f.update()
    test.equal(f.live(), 0)
    test.equal(f.labels[1].rgba, 0xFFCB75FF)
    test.equal(#f.messages, 1)
    f.backgroundFails = false
    f.update()
    test.equal(f.live(), 1)
    test.equal(f.backgrounds[1].rgba, 0x123456FF)
end)

test.case("All compact positions follow both pages on unchanged component objects", function()
    local f = fixture()
    for slot = 1, 18 do f.selected[slot] = slot <= 9 and "skill" or "large" end
    for _, offset in ipairs({ 0, 9, 0 }) do
        f.page(offset)
        f.update()
        test.equal(f.live(), 9)
        for index = 1, 9 do
            test.equal(f.labels[index].content, tostring(index + offset))
            test.equal(f.sprites[#f.sprites - 9 + index].sprite, offset == 0 and 101 or 102)
        end
    end
end)

test.case("Native sibling redraws cannot leave a retained compact icon behind a background", function()
    local f = fixture()
    f.selected[2] = "skill"
    f.update()
    local sprite = f.sprites[1]
    sprite.occluded = true
    f.update()
    test.equal(sprite.occluded, false)
    test.equal(#f.sprites, 1)
    test.equal(sprite.frontMoves, 2)
    test.equal(f.labels[2].content, "2")
end)

test.case("Transparent native labels do not hide their replacement icons on later Draws", function()
    local f = fixture()
    f.selected[1], f.selected[10] = "skill", "large"
    f.update()
    local number = f.labels[1]
    -- Model a client whose effective visibility includes label alpha.
    number.visibleGlobal = false
    for _ = 1, 3 do
        f.update()
        test.equal(f.sprites[#f.sprites].hidden, false)
    end
    f.page(9)
    f.update()
    test.equal(f.sprites[#f.sprites].hidden, false)
    test.equal(f.sprites[#f.sprites].sprite, 102)
    number.parent.visibleGlobal = false
    f.update()
    test.equal(f.sprites[#f.sprites].hidden, true)
    number.parent.visibleGlobal = true
    number.hidden = true
    f.update()
    test.equal(f.sprites[#f.sprites].hidden, true)
    number.hidden = false
    f.update()
    test.equal(f.sprites[#f.sprites].hidden, false)
end)

test.case("Tree visibility is diagnostic only and never recreates retained compact sprites", function()
    local f = fixture()
    f.selected[1] = "skill"
    f.update()
    local stale = f.sprites[1]
    -- The resource ID alone does not establish that the native child survived.
    stale.visibleGlobal = false
    f.update()
    test.equal(stale.destroyed, nil)
    test.equal(f.live(), 1)
    test.equal(f.labels[1].rgba, 0xFFCB7500)
    test.equal(f.labels[1].content, "1")
    test.equal(#f.messages, 0, "Do not diagnose transient tree visibility as asset loading")
    for _ = 1, 5 do f.update() end
    test.equal(#f.sprites, 1)
    test.equal(#f.messages, 1)
    test.equal(f.labels[1].rgba, 0xFFCB7500)
    stale.visibleGlobal = true
    f.update()
    test.equal(f.live(), 1)
    test.equal(f.labels[1].rgba, 0xFFCB7500)
    test.equal(f.sprites[1].sprite, 101)
end)

test.case("Initial tree visibility does not delay a newly assigned compact icon", function()
    local f = fixture()
    f.initialSpriteVisibility = false
    f.selected[1] = "skill"
    f.update()
    test.equal(f.labels[1].rgba, 0xFFCB7500)
    test.equal(f.labels[1].content, "1")
    f.update()
    test.equal(#f.sprites, 1)
    test.equal(#f.messages, 0)
    f.sprites[1].visibleGlobal = true
    f.update()
    test.equal(f.labels[1].rgba, 0xFFCB7500)
    f.renderer.restore()
    test.equal(f.labels[1].rgba, 0xFFCB75FF)
end)

test.case("Same-resource page switches track slot identity and mixed defaults", function()
    local f = fixture()
    f.selected[1], f.selected[10], f.selected[11] = "skill", "skill", "large"
    f.update()
    local first = f.sprites[1]
    f.page(9)
    f.update()
    test.equal(first.destroyed, true)
    test.equal(f.live(), 2)
    f.selected[10] = nil
    f.update()
    test.equal(f.live(), 1)
    test.equal(f.labels[1].rgba, 0xFFCB75FF)
    f.page(0)
    f.update()
    test.equal(f.live(), 1)
    test.equal(f.labels[2].rgba, 0xFFCB75FF)
end)

test.case("Unexpected text and wrong-position numbers never reuse a stale icon", function()
    for _, text in ipairs({ "", "unexpected", "2", "19", "1.0", "-1", " 1 " }) do
        local f = fixture()
        f.selected[1] = "skill"
        f.update()
        f.labels[1].content = text
        f.update()
        test.equal(f.live(), 0)
        test.equal(f.labels[1].content, text)
        test.equal(f.labels[1].rgba, 0xFFCB75FF)
    end
end)

test.case("Compact refresh follows saved changes, swaps and character store changes", function()
    local f = fixture()
    f.selected[1] = "skill"
    f.update()
    f.selected[1], f.selected[2] = f.selected[2], f.selected[1]
    f.update()
    test.equal(f.labels[1].rgba, 0xFFCB75FF)
    test.equal(f.labels[2].rgba, 0xFFCB7500)
    f.selected = { [1] = "large" }
    f.update()
    test.equal(f.live(), 1)
    test.equal(f.sprites[#f.sprites].sprite, 102)
    f.selected = {}
    f.update()
    test.equal(f.live(), 0)
end)

test.case("Missing assets and compact setup failures retain numbers and deduplicate errors", function()
    for _, failure in ipairs({ "creationFails", "layoutFails", "assignmentFails", "zeroBounds", "missingAsset" }) do
        local f = fixture()
        f.selected[1] = "skill"
        if failure == "zeroBounds" then f.labels[1].width = 0
        elseif failure == "missingAsset" then f.selected[1] = "unknown"
        else f[failure] = true end
        f.update()
        f.update()
        test.equal(f.live(), 0)
        test.equal(f.labels[1].content, "1")
        test.equal(f.labels[1].rgba, 0xFFCB75FF)
        test.equal(#f.messages, failure == "missingAsset" and 0 or 1)
    end
end)

test.case("Compact closure, rebuilds and restricted components release owned sprites safely", function()
    for _, change in ipairs({ "missing", "restricted", "parentRestricted", "parentMissing", "rebuilt" }) do
        local f = fixture()
        f.selected[1] = "skill"
        f.update()
        local old, sprite = f.labels[1], f.sprites[1]
        if change == "missing" then f.labels[1] = nil
        elseif change == "restricted" then old.isRestricted = true
        elseif change == "parentRestricted" then old.parent.isRestricted = true
        elseif change == "parentMissing" then old.parent = nil
        else f.labels[1] = f.label(1) end
        f.update()
        test.equal(sprite.destroyed, true)
        test.equal(old.rgba, change == "restricted" and 0xFFCB7500 or 0xFFCB75FF)
        test.equal(f.live(), change == "rebuilt" and 1 or 0)
    end
end)

test.case("Compact cleanup preserves newer native text and colours and is repeatable", function()
    local f = fixture()
    f.selected[1], f.selected[2] = "skill", "skill"
    f.update()
    f.labels[1].content = "10"
    f.labels[2].rgba = 0x123456FF
    f.renderer.restore()
    f.renderer.restore()
    test.equal(f.labels[1].content, "10")
    test.equal(f.labels[1].rgba, 0xFFCB75FF)
    test.equal(f.labels[2].rgba, 0x123456FF)
    test.equal(f.live(), 0)
end)
