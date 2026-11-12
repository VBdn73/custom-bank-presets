local test = require("tests.test_helper")

test.case("Entry point retains PrettyUI for later content events and disposes old views", function()
    local library = {}
    local built, destroyed = 0, 0
    local modules = {
        ["editor/views"] = require("editor/views"),
        ["bank/bindings"] = { labels = {} },
        ["bank/menu"] = { selectedSlot = function(entry)
            test.equal(entry.verbText, "Select")
            return 3
        end },
        ["editor/popup"] = { select = function(slot)
            test.equal(slot, 3, "Native selection is forwarded to the open popup")
        end },
        ["editor/view"] = { build = function()
            error("Preset editing must only be opened from the bank UI")
        end },
        ["editor/preferences"] = { build = function(_, _, prettyui)
            test.equal(prettyui, library)
            built = built + 1
            return function() end, nil, function() destroyed = destroyed + 1 end
        end },
    }
    local events = setmetatable({}, { __index = function(target, key)
        local event = { Subscribe = function(_, callback) target[key].callback = callback end }
        target[key] = event
        return event
    end })
    local environment = setmetatable({
        prettyui = library, Event = events,
        require = function(path)
            modules[path] = modules[path] or {}
            return modules[path]
        end,
    }, { __index = _G })
    assert(loadfile("main.lua", "t", environment))()
    -- Event execution must not depend on the global still containing the export.
    environment.prettyui = false
    events.ContentLayerReady.callback({ component = {} })
    events.ContentLayerReady.callback({ component = {} })
    test.equal(built, 2)
    test.equal(destroyed, 1)
    events.SettingsLayerReady.callback({ component = {} })
    test.equal(built, 3, "Main settings builds preferences, not the preset editor")
    events.SettingsLayerReady.callback({ component = {} })
    test.equal(built, 4)
    test.equal(destroyed, 2, "Reopening settings disposes its previous view")
    events.MiniMenuEntrySelected.callback({ entry = { verbText = "Select" } })
end)

test.case("Main renders saved icons at Draw and restores them on shutdown", function()
    local events, calls = {}, {}
    local bindings = { numbers = {}, compactButtons = {}, labels = {}, appearance = {} }
    local store = {}
    local showBackgrounds = true
    local modules = { ["bank/bindings"] = bindings, ["presets/icons"] = store }
    modules["editor/views"] = require("editor/views")
    modules["editor/popup"] = {
        close = function() calls[#calls + 1] = "popup.close" end,
    }
    modules["presets/item_search"] = {
        clear = function()
            test.equal(calls[#calls], "popup.close", "Close the picker before clearing its index")
            calls[#calls + 1] = "search.clear"
        end,
    }
    modules["presets/settings"] = {
        hidePredefinedDropdown = function() return false end,
        showCompactBackgrounds = function() return showBackgrounds end,
    }
    modules["bank/compact_icons"] = {
        update = function(buttons, icons, colours)
            test.equal(buttons, bindings.compactButtons)
            test.equal(icons, store)
            test.equal(colours, showBackgrounds and modules["presets/colours"] or nil)
            calls[#calls + 1] = "compact.update"
        end,
        restore = function() calls[#calls + 1] = "compact.restore" end,
    }
    modules["bank/icons"] = {
        update = function(numbers, icons)
            test.equal(numbers, bindings.numbers)
            test.equal(icons, store)
            calls[#calls + 1] = "icons.update"
        end,
        restore = function() calls[#calls + 1] = "icons.restore" end,
    }
    local environment = setmetatable({
        Event = setmetatable(events, { __index = function(target, key)
            local event = { Subscribe = function(_, callback) target[key].callback = callback end,
                Unsubscribe = function() end }
            target[key] = event
            return event
        end }),
        require = function(path)
            if not modules[path] then
                modules[path] = setmetatable({}, { __index = function(_, method)
                    return function() calls[#calls + 1] = path .. "." .. method end
                end })
            end
            return modules[path]
        end,
    }, { __index = _G })
    assert(loadfile("main.lua", "t", environment))()
    events.Draw.callback()
    test.equal(calls[#calls - 1], "icons.update")
    test.equal(calls[#calls], "compact.update", "Apply compact icons at the render boundary")
    showBackgrounds = false
    events.Draw.callback()
    local drawCalls = #calls
    environment.PluginShutdown()
    test.equal(calls[drawCalls + 1], "compact.restore")
    test.equal(calls[drawCalls + 2], "icons.restore", "Restore icons before native layout cleanup")
    local cleared = 0
    for _, call in ipairs(calls) do
        if call == "search.clear" then cleared = cleared + 1 end
    end
    test.equal(cleared, 1, "Shutdown clears the item-search cache")
end)
