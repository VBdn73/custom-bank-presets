local search = require("presets/item_search")
assert(search.next == 0 and search.maxId == 70000)
local names = { [0] = "Bronze sword", [1] = "Swordfish", [2] = "Bronze sword", [3] = "null" }
assert(not search.step(4, function(id)
    if id == 3 then error("invalid definition") end
    return names[id] and { name = names[id] }
end))
local results = search.search(" SWORD ")
assert(#results == 3 and results[1].id == 1 and results[2].id == 0 and results[3].id == 2)
assert(#search.search("  ") == 0 and #search.search("missing") == 0)
search.next = 70000
assert(search.step(500, function(id) assert(id == 70000); return nil end))
assert(search.next == 70001)
print("item search tests passed")
