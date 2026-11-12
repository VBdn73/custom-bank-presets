local test = require("tests.test_helper")
local views = require("editor/views")

test.case("Replacing an editor view disposes only its previous instance", function()
    local manager = views.new()
    local destroyed, refreshed = 0, 0
    manager.set("settings", function() error("Old view must not refresh") end,
        function() destroyed = destroyed + 1 end)
    manager.set("settings", function() refreshed = refreshed + 1 end,
        function() destroyed = destroyed + 1 end)
    test.equal(destroyed, 1)
    manager.update()
    test.equal(refreshed, 1)
    manager.clear()
    manager.clear()
    manager.update()
    test.equal(destroyed, 2)
    test.equal(refreshed, 1)
end)

test.case("Failed editor refresh removes its view even when cleanup fails", function()
    local manager = views.new()
    local failures, destroyed, refreshed = 0, 0, 0
    manager.set("content", function()
        failures = failures + 1
        error("Host closed")
    end, function()
        destroyed = destroyed + 1
        error("Host already disposed")
    end)
    manager.set("settings", function() refreshed = refreshed + 1 end)
    manager.update()
    manager.update()
    test.equal(failures, 1)
    test.equal(destroyed, 1)
    test.equal(refreshed, 2)
    manager.clear()
end)
