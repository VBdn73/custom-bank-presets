local nameEditor = require("editor/view")
local layout = require("editor/layout")
local icons = require("editor/icon")
local slots = require("presets/slots")
local popup = {}
local window, refresh, bankIsOpen, updateInfo, infoButton, updateClose, closeButton
local positionKey = "presetEditor.position.v1"
local lastX, lastY
local savedPosition
local destroyEditor
local selectSlot
local entryCount

local function titleFor(slot)
    return slot == slots.bob and "Custom bank preset - BoB"
        or "Custom bank preset " .. slot
end

function popup.select(slot)
    if window and selectSlot and slots.valid(slot, entryCount) then
        selectSlot(slot)
        window.titleText.content = titleFor(slot)
    end
end

local function loadPosition()
    local ok, value = pcall(function() return PersistentDB:GetString(positionKey) end)
    if not ok or type(value) ~= "string" then return end
    local x, y = value:match("^(%d+),(%d+)$")
    x, y = tonumber(x), tonumber(y)
    if x and y and x < math.huge and y < math.huge then
        lastX, lastY, savedPosition = x, y, value
    end
end

local function rememberPosition()
    if not window then return end
    -- The bank may already have disposed the interface; retain the last tick's
    -- position if the component is no longer readable.
    pcall(function()
        local x, y = window.root.x, window.root.y
        if type(x) == "number" and type(y) == "number"
            and x >= 0 and y >= 0 and x < math.huge and y < math.huge then
            lastX, lastY = math.floor(x), math.floor(y)
        end
    end)
end

loadPosition()

function popup.close()
    selectSlot = nil
    if destroyEditor then pcall(destroyEditor); destroyEditor = nil end
    rememberPosition()
    if lastX and lastY then
        local value = lastX .. "," .. lastY
        if value ~= savedPosition then
            local ok, result = pcall(function() return PersistentDB:SetString(positionKey, value) end)
            if ok and result ~= false then savedPosition = value end
        end
    end
    local previous = window
    window, refresh, bankIsOpen, updateInfo = nil, nil, nil, nil
    infoButton, closeButton, updateClose = nil, nil, nil
    -- The bank may already have disposed the window's interface.
    if previous then pcall(function() previous:Destroy() end) end
end

function popup.open(slot, names, bindings, prettyui)
    local binding = bindings.labels[slot]
    if not binding then return end
    local source = ui.Interfaces:GetComponent(binding.interfaceID, binding.staticID,
        binding.categoryID, binding.dynamicID)
    if not source or source.isRestricted or not source.visibleGlobal then return end
    -- The bank itself is a constrained popover. Keep the window in the outer UI.
    local parent = source.parent
    while parent and parent.parent and not parent.parent.isRestricted do
        parent = parent.parent
    end
    if not parent or parent.isRestricted then return end
    assert(prettyui and prettyui.Window, "PrettyUI Window is required for the bank editor.")

    popup.close()
    bankIsOpen = function()
        local current = ui.Interfaces:GetComponent(binding.interfaceID, binding.staticID,
            binding.categoryID, binding.dynamicID)
        return current and not current.isRestricted and current.visibleGlobal
    end
    local bodyHeight = layout.compactBodyHeight + (bindings.colours and layout.colourHeight or 0)
        + (bindings.icons and layout.iconHeight or 0)
        + (bindings.iconText and layout.iconTextHeight or 0)
        - layout.popupEditorGapReduction - layout.popupHeadingRemoval
    -- PrettyUI chrome uses a 32px title and 8px bottom/side borders.
    local width, height = layout.width + 16, bodyHeight + 32 + 8
    local ok, message = pcall(function()
        window = prettyui.Window.new(parent, {
            title = titleFor(slot), width = width, height = height,
            x = math.max(0, math.min(lastX or math.floor((parent.width - width) / 2), parent.width - width)),
            y = math.max(0, math.min(lastY or math.floor((parent.height - height) / 2), parent.height - height)),
            scrollable = false, onClose = popup.close,
        })
        -- Keep PrettyUI's known-good tiled background and title font. The
        -- bank's background component can expose an empty sprite, and font
        -- IDs which are not present in the client do not render any text.
        window.titleText.rgba = 0xD6A65CFF
        -- Lift the tiled body slightly to match the native bank's warmer background.
        -- Create it before the form so controls remain above the tint.
        local backgroundTint = ui.Rectangle.new(window.content)
        backgroundTint:SetSize(window.content.width, window.content.height)
        backgroundTint.fill = true
        backgroundTint.colour = Vector4.new(1, 0.9, 0.8, 0.035)
        backgroundTint.clickthrough = true
        local toggleInfo
        refresh, toggleInfo, destroyEditor, selectSlot = nameEditor.build(window.content, names, bindings, slot, {
            hideTitle = true, readOnlyPreset = true, hidePresetHeading = true,
            externalInfoButton = true, infoParent = window.root,
            contentHost = window, formHeight = bodyHeight, prettyui = prettyui,
            bankButtons = true,
        })
        entryCount = bindings.entryCount or bindings.presetCount
        infoButton, updateInfo = icons.info(window.root, toggleInfo)
        closeButton, updateClose = icons.close(window.root, popup.close)
        infoButton:SetPos(-52, 7, 1, 0)
        infoButton:SetSize(20, 20)
        -- Cover the close frame built into PrettyUI's corner without replacing
        -- the corner itself, which also supplies the outer window border.
        closeButton:SetPos(-28, 7, 1, 0)
        closeButton:SetSize(20, 20)
        window.closeButton.hidden = true
        window.titleText:SetSize(-80, 28, 1, 0)
        window.titleDrag:SetSize(window.root.width - 70, 32)
        window:_SyncOverlays(false)
    end)
    if not ok then
        popup.close()
        print("[Custom bank presets] Bank editor error: " .. tostring(message))
    end
end

function popup.update()
    if not window then return end
    rememberPosition()
    local ok = pcall(function()
        if not bankIsOpen() then popup.close(); return end
        -- PrettyUI restores its default drag width after release. Leave its
        -- full-screen capture alone while dragging, then reserve the buttons.
        if not window.dragFeedback then window.titleDrag:SetSize(window.root.width - 70, 32) end
        window:_SyncOverlays(window.root.hidden == true)
        updateInfo()
        updateClose()
        refresh()
    end)
    if not ok then popup.close() end
end

return popup
