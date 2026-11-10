local test = require("tests.test_helper")
local catalogue = require("presets/icon_catalogue")

test.case("Skill catalogue has 29 unique keys in native skill-list order", function()
    local expected = {
        "attack", "constitution", "mining", "strength", "agility", "smithing",
        "defence", "herblore", "fishing", "ranged", "thieving", "cooking",
        "prayer", "crafting", "firemaking", "magic", "fletching", "woodcutting",
        "runecrafting", "slayer", "farming", "construction", "hunter", "summoning",
        "dungeoneering", "divination", "invention", "archaeology", "necromancy",
    }
    test.equal(#catalogue.categories, 3)
    local category = catalogue.categories[1]
    test.equal(category.key, "skills")
    test.equal(category.name, "Skills")
    test.equal(#category.entries, #expected)
    local seen = {}
    for index, key in ipairs(expected) do
        local entry = category.entries[index]
        test.equal(entry.key, "skills:" .. key)
        test.equal(seen[entry.key], nil)
        seen[entry.key] = true
        test.equal(entry.category, category.key)
        test.equal(type(entry.name), "string")
        test.equal(catalogue.get(entry.key), entry)
    end
end)

test.case("Bosses category is reserved for suitable icons", function()
    local category = catalogue.categories[3]
    test.equal(category.key, "bosses")
    test.equal(category.name, "Bosses")
    test.equal(#category.entries, 0)
    test.equal(catalogue.get("bosses:nex"), nil)
end)

test.case("Misc tab exposes coin variants, achievements and utility artwork", function()
    local category = catalogue.categories[2]
    test.equal(category.key, "misc")
    test.equal(category.name, "Misc")
    test.equal(#category.entries, 21)
    local seen = {}
    for _, entry in ipairs(category.entries) do
        test.equal(entry.category, "misc")
        test.equal(seen[entry.key], nil)
        seen[entry.key] = true
        test.equal(catalogue.get(entry.key), entry)
        if entry.objectID then
            test.equal(catalogue.resolve(entry.key, {}), entry.objectID)
        else
            test.equal(catalogue.resolve(entry.key, {}), nil)
            test.equal(catalogue.resolve(entry.key, { [entry.sprite] = 123 }), 123)
        end
    end
    for index, amount in ipairs({ 1, 2, 3, 4, 5, 25, 100, 250, 1000, 10000 }) do
        test.equal(catalogue.get("misc:coins-" .. amount).objectID, 994 + index)
    end
    for _, tier in ipairs({ "easy", "medium", "hard", "elite", "master" }) do
        test.equal(catalogue.get("misc:clue-scroll-" .. tier), nil)
        test.equal(catalogue.get("misc:casket-" .. tier), nil)
    end
    for _, key in ipairs({ "clue-scroll", "clue-bag", "max-cape", "completionist-cape",
        "trimmed-completionist-cape", "tetracompass" }) do
        test.equal(catalogue.get("misc:" .. key), nil)
    end
    test.equal(catalogue.get("misc:quests").sprite, "RS3_ICON_QUEST_LIST")
    test.equal(catalogue.get("misc:runescore").sprite, "ACHIEVEMENT_ICON_RUNESCORE")
    test.equal(catalogue.get("misc:skills").sprite, "RS3_ICON_TAB_SKILLS")
    local utilitySprites = {
        ["combat-level"] = "AIF_COMBAT_ICON",
        ["world-map"] = "NAVIGATION_ICON_WORLDMAP_ON",
        calendar = "BTN_MOBILE_CALENDAR",
        ["run-energy"] = "NAVIGATION_ICON_ENERGY_ON",
        rest = "NAVIGATION_ICON_ENERGY_REST",
        ["life-points"] = "RS3_HUD_COMBAT_BAR_ICON_HEALTH",
        bank = "RS3_ICON_WORLDMAP_KEY_BANK",
        ["grand-exchange"] = "RS3_ICON_PATH_GRAND_EXCHANGE",
    }
    for key, resource in pairs(utilitySprites) do
        test.equal(catalogue.get("misc:" .. key).sprite, resource)
    end
    test.equal(catalogue.get("misc:home-teleport"), nil)
    test.equal(catalogue.get("misc:lodestone"), nil)
end)

test.case("Native item assignment hides quantities and clears when returning to skills", function()
    local oldUI = ui
    ui = { ObjectQuantityDisplayMode = { NEVER = 0 } }
    local sprite = setmetatable({}, { __index = function(self, key)
        if key == "spriteID" then return self.sprite end
    end })
    function sprite:SetAssociatedObject(objectID, quantity)
        test.equal(quantity, nil, "Icon assignment must omit the optional native Uint64 quantity")
        self.associatedObjectID, self.associatedObjectQuantity = objectID, quantity
    end
    local asset, entry = catalogue.resolve("item:31725")
    catalogue.apply(sprite, asset, entry)
    test.equal(sprite.associatedObjectID, 31725)
    test.equal(sprite.associatedObjectQuantityMode, 0)
    catalogue.apply(sprite, 123, catalogue.get("skills:attack"))
    test.equal(sprite.associatedObjectID, -1)
    test.equal(sprite.spriteID, 123)
    ui = oldUI
end)

test.case("Catalogue preserves the visually confirmed Challenge mapping and chosen Necromancy", function()
    local suffixes = {
        attack = 0, strength = 1, defence = 2, ranged = 3, prayer = 4, mining = 5,
        constitution = 6, firemaking = 7, thieving = 8, hunter = 9, crafting = 10,
        fletching = 11, magic = 12, runecrafting = 13, woodcutting = 14, smithing = 15,
        construction = 16, herblore = 17, fishing = 18, cooking = 19, farming = 20,
        slayer = 21, dungeoneering = 22, summoning = 23, agility = 24, divination = 25,
        archaeology = 27, invention = 28,
    }
    for key, suffix in pairs(suffixes) do
        local entry = catalogue.get("skills:" .. key)
        test.equal(entry.sprite, "CHALLENGE_SKILL_ICONS_35PX_" .. suffix)
        test.equal(entry.width, 35)
        test.equal(entry.height, 35)
    end
    local necromancy = catalogue.get("skills:necromancy")
    test.equal(necromancy.sprite, "SKILL_ICON_NECROMANCY_52PX_0")
    test.equal(necromancy.width, 52)
    test.equal(necromancy.height, 52)
end)

test.case("Catalogue safely falls back for defaults, unknown keys and missing resources", function()
    for _, key in ipairs({ "", "skills:unknown", "items:farming", "skills:Farming", 1, false, {} }) do
        test.equal(catalogue.get(key), nil)
        test.equal(catalogue.resolve(key, {}), nil)
    end
    test.equal(catalogue.get(nil), nil)
    test.equal(catalogue.resolve(nil, {}), nil)
    test.equal(catalogue.resolve("skills:farming", {}), nil)
    local entry = catalogue.get("skills:farming")
    for _, value in ipairs({ -1, "123", false, 1.5, math.huge }) do
        test.equal(catalogue.resolve(entry.key, { [entry.sprite] = value }), nil)
    end
    local spriteID, resolved = catalogue.resolve(entry.key, { [entry.sprite] = 123 })
    test.equal(spriteID, 123)
    test.equal(resolved, entry)
    test.equal(catalogue.resolve(entry.key, { [entry.sprite] = 456 }), 456,
        "Resource IDs are resolved afresh rather than cached or persisted")
end)

test.case("Removed categories fall back to preset numbers", function()
    for _, key in ipairs({ "weapons90:noxious-scythe", "holidays:pumpkin" }) do
        test.equal(catalogue.get(key), nil)
        test.equal(catalogue.resolve(key), nil)
    end
end)
