-- Run from the repository root: lua tests/run.lua
-- Match the client sandbox, where the optional standard utf8 library is absent.
utf8 = nil
local test = require("tests.test_helper")

local suites = {
    -- Persistence, validation and catalogues.
    "slots", "storage", "customisations", "preferences", "item_search",
    "icon_catalogue", "icons", "icon_text", "icon_picker",
    -- Native bank integration and lifecycle.
    "preset_layout", "dropdown", "colours", "main", "reorder", "reorder_wrappers",
    "text_validation", "preset_names", "bank_bindings", "bank_labels",
    "bank_icons", "compact_icons", "bank_preview",
    -- Editor interactions.
    "editor_style", "name_editor", "editor_layout", "preset_menu", "editor_popup", "bob", "editor_views",
}

if arg and #arg > 0 then suites = arg end
for _, suite in ipairs(suites) do
    print("\n" .. suite)
    local ok, message = xpcall(function() dofile("tests/" .. suite .. ".lua") end, debug.traceback)
    if not ok then
        test.failed = test.failed + 1
        print("  FAIL Could not finish suite " .. suite .. "\n" .. message)
    end
end

print(string.format("\n%d passed, %d failed.", test.passed, test.failed))
if test.failed > 0 then os.exit(1) end
