local search = require("presets/item_search")
assert(search.next == 0 and search.maxId == 70000)
local names = { [0] = "Bronze sword", [1] = "Swordfish", [2] = "Bronze sword", [3] = "null",
    [4] = "Bronze sword (broken)", [5] = "Bronze sword (Damaged)",
    [6] = "Broken sword", [7] = "Sword (broken) ornament", [8] = "Sword (Uncharged)",
    [9] = "Augmented sword", [10] = "augmented Sword", [11] = "Sword augmented",
    [12] = "Bronze sword", [13] = "bronze sword" }
local function lookup(id)
    if id == 3 then error("invalid definition") end
    return names[id] and { name = names[id] }
end
assert(not search.step(12, lookup))
assert(not search.step(2, lookup))
local results = search.search(" SWORD ")
assert(#results == 4 and results[1].id == 11 and results[2].id == 1
    and results[3].id == 0 and results[4].id == 13)
assert(#search.search("(broken)") == 0 and #search.search("(damaged)") == 0
    and #search.search("(uncharged)") == 0)
assert(#search.search("  ") == 0 and #search.search("missing") == 0)
search.next = 70000
assert(search.step(500, function(id) assert(id == 70000); return nil end))
assert(search.next == 70001)
print("item search tests passed")
