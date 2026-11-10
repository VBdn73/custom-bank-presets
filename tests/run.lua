-- Run from the repository root: lua tests/run.lua
-- Match the client sandbox, where the optional standard utf8 library is absent.
utf8 = nil
local test = require("tests.test_helper")

for _, suite in ipairs({
    "slots", "storage", "customisations", "preferences", "item_search", "icon_catalogue", "icons", "icon_text", "icon_picker",
    "preset_layout", "dropdown", "colours", "main", "reorder", "reorder_wrappers", "text_validation", "preset_names",
    "bank_bindings", "bank_labels", "bank_icons", "compact_icons", "bank_preview", "editor_style", "name_editor", "preset_menu", "editor_popup", "bob",
}) do
    print("\n" .. suite)
    dofile("tests/" .. suite .. ".lua")
end

print(string.format("\n%d passed, %d failed.", test.passed, test.failed))
if test.failed > 0 then os.exit(1) end
