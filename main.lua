-- Retain the dependency export for editor instances created by later events.
local prettyUILibrary = prettyui
local bankBindings = require("bank/bindings")
local presetNames = require("presets/names")
local bankLabels = require("bank/labels")
local presetMenu = require("bank/menu")
local editorPopup = require("editor/popup")
local bankAppearance = require("bank/appearance")
local bankIcons = require("bank/icons")
local compactIcons = require("bank/compact_icons")
local presetColours = require("presets/colours")
local bankReorder = require("bank/reorder")
local bankDropdown = require("bank/dropdown")
local settings = require("presets/settings")
local preferences = require("editor/preferences")
local itemSearch = require("presets/item_search")
bankBindings.colours = presetColours
bankBindings.icons = require("presets/icons")
bankBindings.iconText = require("presets/icon_text")

local editorViews = require("editor/views").new()

local function showSettingsError(parent, message)
    print("[Custom bank presets] Ribbon settings error: " .. tostring(message))
    for index, text in ipairs({ "Could not open settings.",
        "See the client console for the error." }) do
        local label = ui.Text.new(parent)
        label:SetPos(8, 8 + (index - 1) * 24)
        label:SetSize(math.max(1, parent.width - 16), 24)
        label.font = id.Font.MUSEO_SANS_11PT_REGULAR
        label.content = text
    end
end

Event.MiniMenuReady.Subscribe("customBankPresets.menu", function(event)
    presetMenu.add(event.miniMenu, bankBindings.labels, function(slot)
        editorPopup.open(slot, presetNames, bankBindings, prettyUILibrary)
    end)
end)

Event.MiniMenuEntrySelected.Subscribe("customBankPresets.selection", function(event)
    editorPopup.select(presetMenu.selectedSlot(event.entry, bankBindings.labels))
end)

Event.SettingsLayerReady.Subscribe("customBankPresets.settings", function(event)
    editorViews.remove("settings")
    local refresh, _, destroy = preferences.build(event.component, settings, prettyUILibrary, true)
    editorViews.set("settings", refresh, destroy)
end)

Event.ContentLayerReady.Subscribe("customBankPresets.content", function(event)
    editorViews.remove("content")
    local ok, refresh, _, destroy = pcall(preferences.build, event.component, settings, prettyUILibrary)
    if ok then
        editorViews.set("content", refresh, destroy)
    else
        showSettingsError(event.component, refresh)
    end
end)

-- Reacquire components each tick: bank interfaces can close or rebuild at any time.
Event.Logic.Subscribe("customBankPresets.labels", function()
    bankReorder.update(bankBindings)
    bankDropdown.update(settings.hidePredefinedDropdown())
    editorPopup.update()
    editorViews.update()
    bankLabels.update(bankBindings.labels, presetNames)
end)

-- Bank scripts can reset label text after Logic (for example on selection).
-- Apply again at the render boundary so the predefined text is not drawn for
-- one frame before the next logic tick restores the custom name.
Event.Draw.Subscribe("customBankPresets.labels", function()
    bankDropdown.update(settings.hidePredefinedDropdown())
    bankAppearance.update(bankBindings.appearance, presetColours)
    bankLabels.update(bankBindings.labels, presetNames)
    bankIcons.update(bankBindings.numbers, bankBindings.icons, bankBindings.iconText)
    compactIcons.update(bankBindings.compactButtons, bankBindings.icons,
        settings.showCompactBackgrounds() and presetColours or nil, bankBindings.iconText)
end)

function PluginShutdown()
    compactIcons.restore()
    bankIcons.restore()
    bankDropdown.restore()
    bankReorder.clear()
    editorViews.clear()
    bankAppearance.restore(bankBindings.appearance)
    Event.MiniMenuReady.Unsubscribe("customBankPresets.menu")
    Event.MiniMenuEntrySelected.Unsubscribe("customBankPresets.selection")
    editorPopup.close()
    itemSearch.clear()
    Event.Logic.Unsubscribe("customBankPresets.labels")
    Event.Draw.Unsubscribe("customBankPresets.labels")
    Event.SettingsLayerReady.Unsubscribe("customBankPresets.settings")
    Event.ContentLayerReady.Unsubscribe("customBankPresets.content")
    bankLabels.restore(bankBindings.labels)
end
