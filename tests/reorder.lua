local test = require("tests.test_helper")

test.case("Native drops swap all customisations and ignore invalid destinations", function()
    local oldNames, oldColours = package.loaded["presets/names"], package.loaded["presets/colours"]
    local oldSwap = package.loaded["presets/swap"]
    local oldIcons = package.loaded["presets/icons"]
    local oldIconText = package.loaded["presets/icon_text"]
    local data = { [1] = { name = "First", background = "#008000", text = "", icon = "skills:farming", iconText = "A1" },
        [5] = { name = "Fifth", background = "", text = "#38A4FF", icon = "", iconText = "" } }
    local context = "character"
    local names = { getContext = function() return context end,
        normalize = dofile("presets/names.lua").normalize,
        get = function(slot) return data[slot].name end,
        save = function(slot, value) data[slot].name = value return true end }
    package.loaded["presets/names"] = names
    package.loaded["presets/colours"] = {
        get = function(slot, kind) return data[slot][kind] end,
        save = function(slot, kind, value) data[slot][kind] = value return true end,
    }
    package.loaded["presets/icons"] = {
        normalize = dofile("presets/icons.lua").normalize,
        get = function(slot) return data[slot].icon end,
        save = function(slot, value) data[slot].icon = value return true end,
    }
    package.loaded["presets/icon_text"] = {
        normalize = dofile("presets/icon_text.lua").normalize,
        get = function(slot) return data[slot].iconText end,
        save = function(slot, value) data[slot].iconText = value return true end,
    }
    package.loaded["presets/swap"] = dofile("presets/swap.lua")
    local rows = {}
    for _, slot in ipairs({ 1, 5 }) do
        rows[slot] = { interfaceID = 517, staticID = 267, categoryID = 0,
            dynamicID = slot, visibleGlobal = true, xyGlobal = { y = slot * 30 }, height = 20,
            Subscribe = function(self, _, _, callback) self.callback = callback end,
            Unsubscribe = function(self) self.callback = nil end }
    end
    ui = { Hook = { ONDRAGCOMPLETE = 1 }, Interfaces = {
        GetComponent = function(_, _, staticID, _, dynamicID)
            if staticID == 267 then return rows[dynamicID] end
            if staticID == 266 then
                local slot = math.floor(dynamicID / 3) + 1
                if rows[slot] then
                    return { interfaceID = 517, staticID = 266, categoryID = 0,
                        dynamicID = dynamicID, visibleGlobal = true,
                        xyGlobal = { y = slot * 30 }, height = 20,
                        Subscribe = function() end, Unsubscribe = function() end }
                end
            end
        end } }
    local reorder = dofile("bank/reorder.lua")
    reorder.update({ presetCount = 18, labels = {} })
    -- Deliberately mismatch native hit-target IDs and preset numbers.
    rows[1].dynamicID, rows[5].dynamicID = 0, 4
    test.equal(rows[1].callback(rows[1], rows[5]), true)
    test.equal(data[5].name, "First")
    test.equal(data[5].background, "#008000")
    test.equal(data[1].name, "Fifth")
    test.equal(data[1].text, "#38A4FF")
    test.equal(data[1].background, "")
    test.equal(data[5].icon, "skills:farming")
    test.equal(data[1].icon, "")
    test.equal(data[5].iconText, "A1")
    test.equal(data[1].iconText, "")
    rows[1].callback(rows[1], nil)
    rows[1].callback(rows[1], rows[1])
    test.equal(data[1].name, "Fifth")
    context = "other"
    rows[1].callback(rows[1], rows[5])
    test.equal(data[1].name, "Fifth")
    reorder.clear()
    test.equal(rows[1].callback, nil)
    package.loaded["presets/names"], package.loaded["presets/colours"] = oldNames, oldColours
    package.loaded["presets/swap"] = oldSwap
    package.loaded["presets/icons"] = oldIcons
    package.loaded["presets/icon_text"] = oldIconText
end)
