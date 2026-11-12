local test = require("tests.test_helper")

local function fixture()
    local context, db, reads, writes = "first", {}, 0, 0
    local mode
    local environment = setmetatable({
        PersistentDB = {
            GetString = function(_, key)
                reads = reads + 1
                return db[key]
            end,
            SetString = function(_, key, value)
                writes = writes + 1
                if mode == "throw" then error("Injected write failure") end
                if mode == "reject" then return false end
                if mode == "no-write" then return end
                db[key] = mode == "mismatch" and "skills:attack" or value
            end,
        },
    }, { __index = _G })
    local storage = assert(loadfile("storage.lua", "t", environment))()
    environment.require = function(path)
        if path == "presets/names" then return { getContext = function() return context end } end
        if path == "storage" then return storage end
        return require(path)
    end
    local function load() return assert(loadfile("presets/icons.lua", "t", environment))() end
    return load(), db, function(value) context = value end,
        function(value) mode = value end, function() return reads, writes end, load
end

test.case("Item icon persists across reloads", function()
    local icons, _, _, _, _, reload = fixture()
    test.equal(icons.save(1, "item:31725"), true)
    test.equal(reload().get(1), "item:31725")
    test.equal(icons.save(1, "item:0001"), false)
end)

test.case("Blank selection persists and can be reset", function()
    local icons, _, _, _, _, reload = fixture()
    test.equal(icons.save(1, "blank"), true)
    test.equal(reload().get(1), "blank")
    test.equal(icons.save(1, ""), true)
    test.equal(reload().get(1), "")
end)

test.case("Icons persist stable keys per numbered slot and character, including resets", function()
    local icons, db, character, _, _, reload = fixture()
    test.equal(icons.get(1), "")
    test.equal(icons.save(1, "skills:farming"), true)
    test.equal(icons.save(18, "skills:necromancy"), true)
    test.equal(db["presetIcon.v1.displayName.first.1"], "skills:farming")
    test.equal(reload().get(1), "skills:farming")
    test.equal(icons.get(18), "skills:necromancy")
    test.equal(icons.get(2), "")
    character("second")
    test.equal(icons.get(1), "")
    test.equal(icons.save(1, "skills:magic"), true)
    character("first")
    test.equal(icons.get(1), "skills:farming")
    test.equal(icons.save(1, ""), true)
    test.equal(reload().get(1), "")
    test.equal(icons.get(18), "skills:necromancy")
    character("second")
    test.equal(icons.get(1), "skills:magic")
end)

test.case("Icons reject unknown keys and BoB without reading or writing storage", function()
    local icons, _, _, _, counts = fixture()
    for _, value in ipairs({ "skills:unknown", "skills:Farming", " skills:farming", 123, false, {} }) do
        test.equal(icons.save(1, value), false)
        test.equal(icons.normalize(value), nil)
    end
    test.equal(icons.save(1, nil), false)
    for _, slot in ipairs({ 0, -1, 1.5, 19, 20, "1", false }) do
        test.equal(icons.get(slot), "")
        test.equal(icons.save(slot, "skills:farming"), false)
    end
    test.equal(icons.get(nil), "")
    test.equal(icons.save(nil, ""), false)
    local reads, writes = counts()
    test.equal(reads, 0)
    test.equal(writes, 0)
end)

test.case("Missing and unknown icons fall back without migrating existing settings", function()
    local icons, db, _, _, counts = fixture()
    db["presetName.v3.displayName.first.1"] = "My preset"
    db["presetColour.v1.displayName.first.1.text"] = "#123456"
    db["presetIcon.v1.displayName.first.1"] = "skills:removed"
    db["presetIcon.v1.displayName.first.2"] = false
    test.equal(icons.get(1), "")
    test.equal(icons.get(2), "")
    test.equal(icons.get(3), "")
    test.equal(icons.save(4, "skills:farming"), true, "No custom name or colours required")
    test.equal(db["presetIcon.v1.displayName.first.1"], "skills:removed")
    test.equal(db["presetName.v3.displayName.first.1"], "My preset")
    test.equal(db["presetColour.v1.displayName.first.1.text"], "#123456")
    local _, writes = counts()
    test.equal(writes, 1)
end)

test.case("Logout blocks icon writes and invalidates the previous character cache", function()
    local icons, db, character, _, counts = fixture()
    test.equal(icons.save(1, "skills:farming"), true)
    character(nil)
    test.equal(icons.get(1), "")
    test.equal(icons.save(1, "skills:magic"), false)
    db["presetIcon.v1.displayName.first.1"] = "skills:mining"
    character("first")
    test.equal(icons.get(1), "skills:mining")
    local _, writes = counts()
    test.equal(writes, 1)
end)

test.case("Icon cache handles defaults and known keys without client sprite APIs", function()
    local icons, _, _, _, counts = fixture()
    test.equal(icons.get(1), "")
    test.equal(icons.get(1), "")
    test.equal(counts(), 1)
    test.equal(icons.save(1, "skills:farming"), true)
    local before = counts()
    test.equal(icons.get(1), "skills:farming")
    test.equal(counts(), before)
end)

for _, failure in ipairs({ "reject", "no-write", "mismatch", "throw" }) do
    test.case("Failed icon save preserves the cache: " .. failure, function()
        local icons, _, _, mode = fixture()
        test.equal(icons.save(1, "skills:farming"), true)
        mode(failure)
        local ok, saved = pcall(icons.save, 1, "skills:magic")
        if failure == "throw" then
            test.equal(ok, false, "Host errors propagate to the grouped-save caller")
        else
            test.equal(ok, true)
            test.equal(saved, false)
        end
        test.equal(icons.get(1), "skills:farming")
    end)
end
