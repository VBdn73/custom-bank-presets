local test = require("tests.test_helper")
local createFixture = require("tests.fixtures.editor")

test.case("Popup editor omits its duplicate title and fits beneath window chrome", function()
    local f = createFixture()
    f.parent.width, f.parent.height = 352, 162
    local first = #f.controls + 1
    f:open(18, { hideTitle = true })
    for index = first, #f.controls do
        local c = f.controls[index]
        test.equal(c.content == "Custom bank presets", false)
        if c.content ~= "" then
            test.equal(c.y >= 0 and c.y + c.height <= 162, true, "Visible control fits popup content")
        end
    end
    test.equal(f.selector.y, 16)
    test.equal(f.input.content, "Last preset")
end)

test.case("Editor centres controls without resizing host layers and clamps small layouts", function()
    local f = createFixture()
    test.equal(f.parent.width, 580)
    test.equal(f.parent.height, 360)
    test.equal(f.host.width, 600)
    test.equal(f.host.height, 400)
    test.equal(f.title.x, 130)
    test.equal(f.title.y, 91)
    test.equal(f.title.parent, f.parent, "Controls attach directly to supplied layer")
    test.equal(f.title.parentX, nil)
    test.equal(f.title.selfX, nil)
    f.parent.width, f.parent.height = 640, 400
    f.parent.hooks[ui.Hook.ONRESIZE]()
    test.equal(f.title.x, 160)
    test.equal(f.title.y, 111)
    f.parent.width, f.parent.height = 300, 200
    f.parent.hooks[ui.Hook.ONRESIZE]()
    test.equal(f.title.x, 8)
    test.equal(f.title.y, 11)
    test.equal(f.input.x + f.input.width <= 300, true)
    test.equal(f.status.y + f.status.height <= 200, true)
end)

test.case("Plugin Hub settings info stays at the top-right after resizing", function()
    local f = createFixture()
    f:open(nil, { hideTitle = true })
    for _, size in ipairs({ { 580, 360 }, { 700, 400 }, { 300, 240 } }) do
        f.parent.width, f.parent.height = size[1], size[2]
        f.parent.hooks[ui.Hook.ONRESIZE]()
        test.equal(f.info.hidden, false)
        test.equal(f.info.x, size[1] - 8 - 22)
        test.equal(f.info.y, 8)
    end
end)

test.case("Resizable ribbon fits narrow panels and restores the wide layout without losing edits", function()
    local colours = { get = function() return "" end, save = function() return true end }
    local f = createFixture(colours)
    local first = #f.controls + 1
    f.parent.width, f.parent.height = 260, 260
    f:open(18)
    f.input.content = "Unsaved edit"
    for _, size in ipairs({ { 260, 260 }, { 300, 280 }, { 240, 246 }, { 580, 360 } }) do
        f.parent.width, f.parent.height = size[1], size[2]
        f.parent.hooks[ui.Hook.ONRESIZE]()
        for index = first, #f.controls do
            local c = f.controls[index]
            test.equal(c.x >= 0 and c.x + c.width <= size[1], true, "Control fits panel width")
            test.equal(c.y >= 0 and c.y + c.height <= size[2], true, "Control fits panel height")
        end
        test.equal(f.input.content, "Unsaved edit")
        test.equal(f.selector.selectedID, 17)
    end
    test.equal(f.input.width, 224)
    test.equal(f.title.content, "Custom bank presets")
    test.equal(f.saveCalls, 0)
end)

test.case("Ribbon reports an unavailable PrettyUI dependency before creating controls", function()
    local f = createFixture()
    local dependency = prettyui
    prettyui = nil
    local before = #f.controls
    local ok, message = pcall(function() f:open(nil, { scrollable = true }) end)
    prettyui = dependency
    test.equal(ok, false)
    test.equal(tostring(message):find("PrettyUI is required", 1, true) ~= nil, true)
    test.equal(#f.controls, before)
end)

test.case("Ribbon uses the dependency passed by main even without a module global", function()
    local f = createFixture()
    local dependency = prettyui
    prettyui = nil
    local ok, message = pcall(function()
        f:open(18, { scrollable = true, prettyui = dependency })
    end)
    prettyui = dependency
    test.equal(ok, true, tostring(message))
    test.equal(f.input.parent, f.scrollView.content)
    test.equal(f.selector.selectedID, 17)
    f.destroy()
end)

test.case("Small ribbon panels scroll to Save and reset their offset when enlarged", function()
    local f = createFixture({ get = function() return "" end, save = function() return true end })
    f.parent.width, f.parent.height = 200, 120
    f:open(18, { scrollable = true })
    f.input.content = "Keep this edit"
    test.equal(f.save.hidden, true)
    test.equal(f.scrollView.scrollbarVisible, true)
    test.equal(f.input.parent, f.scrollView.content)
    test.equal(f.input.width <= f.scrollView.contentWidth, true)
    test.equal(f.input.hooks[ui.Hook.ONSCROLLWHEEL](f.input, 100), false)
    f.refresh()
    test.equal(f.save.hidden, false)
    local visibleY = f.save.y - f.scrollView.scrollY
    test.equal(visibleY >= 0 and visibleY + f.save.height <= 120, true)
    f.parent.width, f.parent.height = 580, 360
    f.parent.hooks[ui.Hook.ONRESIZE]()
    test.equal(f.scrollView.scrollbarVisible, false)
    test.equal(f.scrollView.scrollY, 0)
    test.equal(f.save.hidden, false)
    test.equal(f.input.content, "Keep this edit")
    test.equal(f.selector.selectedID, 17)
    test.equal(f.saveCalls, 0)
    f.destroy()
    test.equal(f.scrollView.destroyed, true)
end)

test.case("Managed ribbon input submits once and uses PrettyUI clipping", function()
    local f = createFixture()
    f.parent.width, f.parent.height = 200, 88
    f:open(18, { scrollable = true })
    test.equal(f.input.contentClipped, true)
    test.equal(f.input.hidden, nil, "PrettyUI clips input visuals rather than hiding the field")
    f.input.content = "Managed input"
    f.input.hooks[ui.Hook.ONCONTENTCHANGED](f.input, 0)
    test.equal(f.saveCalls, 0)
    f.input.hooks[ui.Hook.ONCONTENTCHANGED](f.input, ui.InputFieldActionResult.SUBMIT)
    test.equal(f.saveCalls, 1)
    test.equal(f.stored[18], "Managed input")
    f.parent.height = 400
    f.parent.hooks[ui.Hook.ONRESIZE]()
    test.equal(f.input.contentClipped, false)
    f.destroy()
end)
