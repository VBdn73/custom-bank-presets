local test = require("tests.test_helper")
local catalogue = require("presets/icon_catalogue")

local function fixture()
    local f = { numbers = {}, selected = {}, sprites = {}, messages = {}, texts = {}, iconTexts = {} }
    local spriteIDs = {}
    for index, entry in ipairs(catalogue.categories[1].entries) do spriteIDs[entry.sprite] = 1000 + index end
    local bindings = dofile("bank/bindings.lua").numbers
    function f.number(slot)
        return { content = tostring(slot), type = 1, parent = {}, width = 24, height = 30,
            x = 4, y = (slot - 1) * 30, visibleGlobal = true, rgba = 0xFFCB75FF,
            font = 12, isShadowed = true }
    end
    for slot = 1, 18 do f.numbers[slot] = f.number(slot) end
    local environment = setmetatable({
        print = function(message) f.messages[#f.messages + 1] = message end,
        require = function(path)
            if path == "presets/icon_catalogue" then
                return { resolve = function(key) return catalogue.resolve(key, spriteIDs) end,
                    apply = function(sprite, assetID, entry)
                        if entry.objectID then sprite:SetAssociatedObject(assetID)
                        else catalogue.apply(sprite, assetID, entry) end
                    end }
            end
            return require(path)
        end,
        id = { Font = { MUSEO_SANS_11PT_REGULAR = 11 } },
        ui = { ComponentType = { LABEL = 1 }, AlignMode = { CENTRE = 1 }, ObjectQuantityDisplayMode = { NEVER = 0 },
            Interfaces = { GetComponent = function(_, interfaceID, staticID, categoryID, dynamicID)
                test.equal(interfaceID, 517)
                test.equal(staticID, 266)
                test.equal(categoryID, 0)
                test.equal(dynamicID % 3, 0)
                return f.numbers[dynamicID / 3 + 1]
            end },
            Text = { new = function(parent, categoryID, dynamicID)
                test.equal(categoryID, 3)
                local text = { parent = parent, dynamicID = dynamicID }
                function text:SetSize(w, h) self.width, self.height = w, h end
                function text:SetPos(x, y) self.x, self.y = x, y end
                function text:Destroy() self.destroyed = true end
                function text:MoveToFront() self.frontMoves = (self.frontMoves or 0) + 1 end
                f.texts[#f.texts + 1] = text
                return text
            end },
            Sprite = { new = function(parent, categoryID, dynamicID)
                if f.creationFails then return nil end
                assert(type(categoryID) == "number" and categoryID % 1 == 0
                    and categoryID >= 0 and categoryID <= 256, "Invalid sprite category ID")
                assert(type(dynamicID) == "number" and dynamicID % 1 == 0
                    and dynamicID >= 0 and dynamicID <= 256, "Invalid sprite dynamic ID")
                test.equal(categoryID, 1, "Plugin sprites must not inherit native category 0")
                test.equal(dynamicID >= 1 and dynamicID <= 18, true)
                local sprite = { parent = parent, categoryID = categoryID, dynamicID = dynamicID }
                function sprite:SetAssociatedObject(objectID) self.associatedObjectID = objectID end
                function sprite:SetSize(w, h)
                    if f.layoutFails then error("Injected layout failure") end
                    self.width, self.height = w, h
                end
                function sprite:SetPos(x, y) self.x, self.y = x, y end
                function sprite:Destroy() self.destroyed = true end
                function sprite:MoveToFront()
                    if f.frontFails then error("Injected render-order failure") end
                    self.frontMoves = (self.frontMoves or 0) + 1
                    self.occluded = false
                end
                setmetatable(sprite, { __index = function(self, key)
                    if key == "spriteID" then return f.assignmentFails and -1 or self.sprite end
                end })
                f.sprites[#f.sprites + 1] = sprite
                return sprite
            end },
        },
    }, { __index = _G })
    f.renderer = assert(loadfile("bank/icons.lua", "t", environment))()
    f.preview = assert(loadfile("bank/preview.lua", "t", environment))()
    f.store = { get = function(slot)
        if f.storeFails == slot then error("Injected storage error") end
        return f.selected[slot] or ""
    end }
    f.bindings = bindings
    function f.update() f.renderer.update(f.bindings, f.store, { get = function(slot) return f.iconTexts[slot] or "" end }) end
    function f.live()
        local count = 0
        for _, sprite in ipairs(f.sprites) do if not sprite.destroyed then count = count + 1 end end
        return count
    end
    f.spriteIDs = spriteIDs
    return f
end

test.case("Bank icon text replaces numbers, overlays icons and restores native labels", function()
    local f = fixture()
    f.iconTexts[1] = "WAS"
    f.update()
    local text = f.texts[1]
    test.equal(text.content, "WAS")
    test.equal(text.width, 40)
    test.equal(text.maxLines, 1)
    test.equal(text.y, f.numbers[1].y)
    test.equal(f.numbers[1].content, "")
    f.selected[1] = "skills:farming"
    f.update()
    test.equal(text.destroyed, true)
    text = f.texts[2]
    test.equal(text.y, f.numbers[1].y + 6)
    test.equal(text.frontMoves, 1)
    f.numbers[1].content = "1"
    f.update()
    test.equal(f.numbers[1].content, "")
    f.iconTexts[1], f.selected[1] = "", nil
    f.update()
    test.equal(text.destroyed, true)
    test.equal(f.numbers[1].content, "1")
end)

test.case("Number bindings cover only presets 1..18 with zero-based dynamic IDs", function()
    local numbers = dofile("bank/bindings.lua").numbers
    test.equal(#numbers, 18)
    for slot, binding in ipairs(numbers) do
        test.equal(binding.slot, slot)
        test.equal(binding.dynamicID, (slot - 1) * 3)
    end
    test.equal(numbers[19], nil)
end)

test.case("Bank icons render as untinted, non-interactive siblings and leave native styling intact", function()
    local f = fixture()
    f.selected[1] = "skills:farming"
    f.update()
    local number, sprite = f.numbers[1], f.sprites[1]
    test.equal(number.content, "")
    test.equal(sprite.parent, number.parent)
    test.equal(sprite.categoryID, 1)
    test.equal(sprite.dynamicID, 1)
    test.equal(sprite.frontMoves, 1)
    test.equal(sprite.width, 24)
    test.equal(sprite.height, 24)
    test.equal(sprite.x, 8, "Bank icon has a 4-unit inset from the native number area")
    test.equal(sprite.y, 3)
    test.equal(sprite.clickthrough, true)
    test.equal(sprite.enabled, false)
    test.equal(sprite.rgba, 0xFFFFFFFF)
    test.equal(number.rgba, 0xFFCB75FF)
    test.equal(number.font, 12)
    test.equal(number.isShadowed, true)
    test.equal(number.hidden, nil)
    test.equal(number.hooks, nil)
    local previewNumber = f.preview.number(1)
    test.equal(previewNumber, number, "Editor can still read native number styling while its text is overridden")
    test.equal(previewNumber.font, 12)
    test.equal(previewNumber.width, 24)
    test.equal(f.numbers[2].content, "2")
    f.update()
    test.equal(#f.sprites, 1, "Unchanged components reuse their sprite")
    test.equal(sprite.frontMoves, 2)
end)

test.case("Item icons use a larger centered canvas while staying within row height", function()
    local f = fixture()
    f.selected[1], f.selected[2] = "item:31725", "skills:farming"
    f.update()
    local item, skill = f.sprites[1], f.sprites[2]
    test.equal(item.width, 32)
    test.equal(item.height, 28)
    test.equal(item.x, 4)
    test.equal(item.y, 1)
    test.equal(skill.width, 24)
    test.equal(skill.height, 24)
    f.numbers[1].height = 20
    f.update()
    test.equal(item.height, 20)
    test.equal(item.width <= 32, true)
end)

test.case("All 18 bank rows render saved icons and reset independently", function()
    local f = fixture()
    for slot = 1, 18 do f.selected[slot] = "skills:necromancy" end
    f.update()
    test.equal(f.live(), 18)
    for slot = 1, 18 do test.equal(f.numbers[slot].content, "") end
    f.selected[18] = ""
    f.update()
    test.equal(f.numbers[18].content, "18")
    test.equal(f.live(), 17)
    f.renderer.restore()
    f.renderer.restore()
    test.equal(f.live(), 0)
    for slot = 1, 18 do test.equal(f.numbers[slot].content, tostring(slot)) end
end)

test.case("Management icons survive repeated native selection redraws without losing saved icons", function()
    local f = fixture()
    local parent = {}
    for slot = 1, 18 do
        f.numbers[slot].parent = parent
        f.selected[slot] = slot % 2 == 0 and "skills:necromancy" or "skills:farming"
    end
    f.update()
    local addresses = {}
    for slot, sprite in ipairs(f.sprites) do
        test.equal(sprite.parent, parent)
        test.equal(sprite.categoryID, 1)
        test.equal(sprite.dynamicID, slot)
        local address = sprite.categoryID .. ":" .. sprite.dynamicID
        test.equal(addresses[address], nil, "Each row gets a distinct plugin child address")
        addresses[address] = true
    end
    for _, selectedSlot in ipairs({ 1, 16, 2, 18, 16 }) do
        -- Model native selection scripts rewriting numbers and drawing sibling
        -- backgrounds over retained injected sprites, without rebuilding rows.
        f.numbers[selectedSlot].content = tostring(selectedSlot)
        for _, sprite in ipairs(f.sprites) do sprite.occluded = true end
        f.update()
        test.equal(#f.sprites, 18, "Selection redraws reuse existing sprites")
        for slot, sprite in ipairs(f.sprites) do
            test.equal(sprite.occluded, false)
            test.equal(sprite.destroyed, nil)
            test.equal(f.numbers[slot].content, "")
            test.equal(sprite.sprite, f.spriteIDs[catalogue.get(f.selected[slot]).sprite])
        end
    end
    f.renderer.restore()
    test.equal(f.live(), 0)
    for slot = 1, 18 do test.equal(f.numbers[slot].content, tostring(slot)) end
end)

test.case("Unknown selections and missing resources retain or restore the native number", function()
    local f = fixture()
    f.selected[1], f.selected[2] = "skills:removed", "skills:farming"
    f.update()
    test.equal(f.numbers[1].content, "1")
    f.spriteIDs[catalogue.get("skills:farming").sprite] = nil
    f.update()
    test.equal(f.numbers[2].content, "2")
    test.equal(f.live(), 0)
end)

for _, failure in ipairs({ "creationFails", "layoutFails", "assignmentFails", "frontFails" }) do
    test.case("Renderer keeps numbers and cleans up on " .. failure, function()
        local f = fixture()
        f.selected[1], f[failure] = "skills:farming", true
        f.update()
        test.equal(f.numbers[1].content, "1")
        test.equal(f.live(), 0)
        test.equal(#f.messages, 1)
        f.update()
        test.equal(#f.messages, 1, "Repeated failure is not logged every frame")
        f[failure] = false
        f.update()
        test.equal(f.numbers[1].content, "")
        test.equal(f.live(), 1)
    end)
end

test.case("A later rendering failure restores the original and does not affect other rows", function()
    local f = fixture()
    f.selected[1], f.selected[2] = "skills:farming", "skills:magic"
    f.update()
    f.numbers[1].width = 0
    f.update()
    test.equal(f.numbers[1].content, "1")
    test.equal(f.numbers[2].content, "")
    test.equal(f.live(), 1)
    f.storeFails = 2
    f.update()
    test.equal(f.numbers[2].content, "2")
    test.equal(f.live(), 0)
end)

test.case("Native text updates survive reset and shutdown without changing geometry", function()
    local f = fixture()
    f.selected[1] = "skills:farming"
    f.update()
    f.numbers[1].content = "Native update"
    f.update()
    test.equal(f.numbers[1].content, "")
    f.selected[1] = ""
    f.update()
    test.equal(f.numbers[1].content, "Native update")
    f.selected[1] = "skills:farming"
    f.update()
    f.numbers[1].content = "Newer update"
    f.renderer.restore()
    test.equal(f.numbers[1].content, "Newer update")
    test.equal(f.numbers[1].width, 24)
    test.equal(f.numbers[1].height, 30)
end)

test.case("Bank close and component or parent rebuilds dispose old sprites and reacquire rows", function()
    local f = fixture()
    f.selected[1] = "skills:farming"
    f.update()
    local old = f.numbers[1]
    f.numbers[1] = nil
    f.update()
    test.equal(f.live(), 0)
    test.equal(old.content, "1")
    f.numbers[1] = f.number(1)
    f.update()
    local oldSprite = f.sprites[#f.sprites]
    f.numbers[1] = f.number(1)
    f.update()
    test.equal(oldSprite.destroyed, true)
    test.equal(f.live(), 1)
    oldSprite = f.sprites[#f.sprites]
    f.numbers[1].parent = {}
    f.update()
    test.equal(oldSprite.destroyed, true)
    test.equal(f.live(), 1)
end)

test.case("Missing and restricted parents and labels never hide a number", function()
    local f = fixture()
    f.selected[1] = "skills:farming"
    f.numbers[1].isRestricted = true
    f.update()
    test.equal(f.numbers[1].content, "1")
    f.numbers[1].isRestricted = false
    f.numbers[1].parent.isRestricted = true
    f.update()
    test.equal(f.live(), 0)
    f.numbers[1].parent = nil
    f.update()
    test.equal(f.numbers[1].content, "1")
    f.numbers[1].parent = {}
    f.numbers[1].type = 2
    f.update()
    test.equal(f.numbers[1].content, "1")
end)

test.case("Native scrolling and visibility move or suppress the sprite with its row", function()
    local f = fixture()
    f.selected[1] = "skills:farming"
    f.update()
    local sprite = f.sprites[1]
    f.numbers[1].y, f.numbers[1].visibleGlobal = -30, false
    f.update()
    test.equal(sprite.y, -27)
    test.equal(sprite.hidden, true)
    f.numbers[1].y, f.numbers[1].visibleGlobal = 60, true
    f.update()
    test.equal(sprite.y, 63)
    test.equal(sprite.hidden, false)
end)

test.case("Removed bindings and changed selections release only plugin-owned sprites", function()
    local f = fixture()
    f.selected[1] = "skills:farming"
    f.update()
    local first = f.sprites[1]
    f.selected[1] = "skills:necromancy"
    f.update()
    test.equal(first.destroyed, true)
    test.equal(f.live(), 1)
    f.bindings = {}
    f.update()
    test.equal(f.numbers[1].content, "1")
    test.equal(f.live(), 0)
    f.renderer.update({ { slot = 19 } }, f.store)
    test.equal(f.live(), 0, "BoB bindings cannot trigger rendering")
end)
