local test = require("tests.test_helper")

local function fixture()
    -- Each case gets an independent index, including its private name cache.
    local search = dofile("presets/item_search.lua")
    local names = {
        [0] = "Bronze sword", [1] = "Swordfish", [2] = "Bronze sword", [3] = "null",
        [4] = "Bronze sword (broken)", [5] = "Bronze sword (Damaged)",
        [6] = "Broken sword", [7] = "Sword (broken) ornament", [8] = "Sword (Uncharged)",
        [9] = "Augmented sword", [10] = "augmented Sword", [11] = "Sword augmented",
        [12] = "Bronze sword", [13] = "bronze sword",
    }
    local function lookup(id)
        if id == 3 then error("invalid definition") end
        return names[id] and { name = names[id] }
    end
    return search, lookup
end

test.case("Clearing item search resets progress, results and duplicate tracking", function()
    local search, lookup = fixture()
    search.step(14, lookup)
    test.equal(#search.search("bronze sword"), 2)
    local maximumID = search.maxId
    search.clear()
    test.equal(search.next, 0)
    test.equal(#search.entries, 0)
    test.equal(#search.search("bronze sword"), 0)
    test.equal(search.maxId, maximumID, "Clearing preserves the indexing limit")
    search.clear()
    search.step(14, lookup)
    test.equal(#search.search("bronze sword"), 2, "Previously seen names can be indexed again")
end)

test.case("Item indexing resumes across batches and tolerates missing definitions", function()
    local search, lookup = fixture()
    test.equal(search.next, 0)
    test.equal(search.step(12, lookup), false)
    test.equal(search.next, 12)
    test.equal(search.step(2, lookup), false)
    test.equal(search.next, 14)
    local results = search.search(" SWORD ")
    test.equal(#results, 4)
    for index, expectedID in ipairs({ 11, 1, 0, 13 }) do
        test.equal(results[index].id, expectedID, "Prefix matches precede alphabetical substring matches")
    end
end)

test.case("Item search filters unusable variants and deduplicates exact names", function()
    local search, lookup = fixture()
    search.step(14, lookup)
    for _, query in ipairs({ "(broken)", "(damaged)", "(uncharged)", "augmented sword", "broken sword" }) do
        test.equal(#search.search(query), 0, query)
    end
    local results = search.search("bronze sword")
    test.equal(#results, 2, "Case-distinct definitions remain available")
    test.equal(results[1].id, 0, "The first exact duplicate is retained")
    test.equal(results[2].id, 13)
end)

test.case("Empty and unmatched item queries return no results", function()
    local search, lookup = fixture()
    search.step(14, lookup)
    test.equal(#search.search("  "), 0)
    test.equal(#search.search("missing"), 0)
end)

test.case("Item indexing includes its upper bound and stops calling the lookup", function()
    local search = fixture()
    search.next = search.maxId
    local calls = 0
    local function lookup(id)
        calls = calls + 1
        test.equal(id, search.maxId)
    end
    test.equal(search.step(500, lookup), true)
    test.equal(search.next, search.maxId + 1)
    test.equal(search.step(500, lookup), true)
    test.equal(calls, 1)
end)
