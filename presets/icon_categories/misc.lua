-- Assets verified against dev_plugins/pan-files/pan-obj.txt and pan-sprite.txt.
local category = { key = "misc", name = "Misc", entries = {} }

local function item(key, name, objectID)
    category.entries[#category.entries + 1] = {
        key = "misc:" .. key, category = category.key, name = name,
        objectID = objectID, width = 36, height = 32,
    }
end

local function sprite(key, name, resource, width, height)
    category.entries[#category.entries + 1] = {
        key = "misc:" .. key, category = category.key, name = name,
        sprite = resource, width = width or 32, height = height or 32,
    }
end

-- Dedicated stack-variant objects give different piles without passing a native
-- Uint64 quantity or displaying a quantity label over the preset icon.
for index, amount in ipairs({ 1, 2, 3, 4, 5, 25, 100, 250, 1000, 10000 }) do
    item("coins-" .. amount, "Coins (" .. amount .. ")", 994 + index)
end

sprite("quests", "Quests", "RS3_ICON_QUEST_LIST")
sprite("runescore", "RuneScore", "ACHIEVEMENT_ICON_RUNESCORE")
sprite("skills", "Skills / levels", "RS3_ICON_TAB_SKILLS")
sprite("combat-level", "Combat level", "AIF_COMBAT_ICON")
sprite("world-map", "World map", "NAVIGATION_ICON_WORLDMAP_ON")
sprite("calendar", "Calendar", "BTN_MOBILE_CALENDAR")
sprite("run-energy", "Run energy", "NAVIGATION_ICON_ENERGY_ON")
sprite("rest", "Rest", "NAVIGATION_ICON_ENERGY_REST")
sprite("life-points", "Life points", "RS3_HUD_COMBAT_BAR_ICON_HEALTH")
sprite("bank", "Bank", "RS3_ICON_WORLDMAP_KEY_BANK")
sprite("grand-exchange", "Grand Exchange", "RS3_ICON_PATH_GRAND_EXCHANGE")

return category
