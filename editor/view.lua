local constants = require("constants")
local layout = require("editor/layout")
local theme = require("editor/theme")
local icons = require("editor/icon")
local colourPicker = require("components/colour_picker/init")
local iconPicker = require("components/icon_picker/init")
local backpackIcons = require("presets/backpack_icons")
local iconCatalogue = require("presets/icon_catalogue")
local colourValue = require("presets/colour_value")
local slots = require("presets/slots")
local info = require("editor/info")
local bankAppearance = require("bank/appearance")
local bankLabels = require("bank/labels")
local bankPreview = require("bank/preview")
local customisations = require("presets/customisations")
local editor = {}

local function createText(parent, content, font)
    local label = ui.Text.new(parent)
    label:SetSize(layout.controlWidth, layout.textHeight)
    label.font = font or id.Font.MUSEO_SANS_15PT_REGULAR
    label.content = content
    return label
end

local function createButton(parent, label, callback)
    local control = ui.Button.new(parent)
    control:SetSize(layout.buttonWidth, layout.buttonHeight)
    control.stylesheetID = id.StyleSheet.BUTTON_DEFAULT
    control.label = label
    control:Subscribe(ui.Hook.ONBUTTONPRESSED, callback)
    return control
end

function editor.build(parent, names, bindings, initialSlot, options)
    options = options or {}
    local persistence = customisations.new(names, bindings.colours, bindings.icons, bindings.iconText)
    local host = parent
    local scrollView
    local contentHost = options.contentHost
    if options.scrollable then
        -- Receive dependency exports explicitly from the entry point.
        local prettyui = options.prettyui
        assert(prettyui,
            "PrettyUI is required for the ribbon editor.")
        assert(prettyui.SimpleView and prettyui.SimpleView.new,
            "The installed PrettyUI version does not provide SimpleView.")
        scrollView = prettyui.SimpleView.new(host, {
            width = math.max(1, host.width), height = math.max(1, host.height),
        })
        parent = scrollView.content
        contentHost = scrollView
    end
    -- Position controls directly on the supplied layer. An extra nested layer
    -- is positioned unexpectedly by the beta client's settings host.
    local contentWidth = layout.width
    local contentHeight = options.hideTitle and layout.compactBodyHeight or layout.compactHeight
    if bindings.colours then contentHeight = contentHeight + layout.colourHeight end
    if bindings.icons then contentHeight = contentHeight + layout.iconHeight end
    if bindings.iconText then contentHeight = contentHeight + layout.iconTextHeight end
    local headingGapReduction = options.readOnlyPreset and layout.popupEditorGapReduction or 0
    if options.hidePresetHeading then headingGapReduction = headingGapReduction + layout.popupHeadingRemoval end
    contentHeight = contentHeight - headingGapReduction
    local controlPositions = {}
    local function trackPosition(component, x, y)
        controlPositions[#controlPositions + 1] = {
            component = component, x = x, y = y - (options.hideTitle and layout.titleHeight or 0),
        }
        return component
    end

    -- Build the controls in display order, using offsets within the editor.
    local entryCount = bindings.entryCount or bindings.presetCount
    local selectedSlot = initialSlot or 1
    if not slots.valid(selectedSlot, entryCount) then
        selectedSlot = 1
    end
    if not options.hideTitle then
        trackPosition(createText(parent, constants.editorTitle), layout.padding, layout.rows.title)
    end
    local presetSelector, presetHeading
    if options.readOnlyPreset and not options.hidePresetHeading then
        presetHeading = createText(parent, "")
        presetHeading.clickthrough = true
        trackPosition(presetHeading, layout.padding, layout.rows.selector)
    elseif not options.readOnlyPreset then
        presetSelector = ui.List.new(parent)
        trackPosition(presetSelector, layout.padding, layout.rows.selector)
        presetSelector:SetSize(layout.controlWidth, layout.fieldHeight)
        presetSelector.stylesheetID = id.StyleSheet.DROPDOWN_DEFAULT
        presetSelector.dropdownMaxVisibleEntries = layout.dropdownVisibleEntries
        presetSelector.entryHeight = layout.textHeight
    end
    local presetLabels = {}
    local function refreshPresetLabels()
        if options.readOnlyPreset then
            if not presetHeading then return end
            local name = names.get(selectedSlot)
            presetHeading.content = slots.title(selectedSlot) .. (name and name ~= "" and " - " .. name or "")
            return
        end
        local labels, changed = {}, false
        for preset = 1, entryCount do
            local name = names.get(preset)
            local customized = name and name ~= ""
            if bindings.colours then
                customized = customized or bindings.colours.get(preset, "background") ~= ""
                    or bindings.colours.get(preset, "text") ~= ""
            end
            if bindings.icons then customized = customized or bindings.icons.get(preset) ~= "" end
            if bindings.iconText then customized = customized or bindings.iconText.get(preset) ~= "" end
            labels[preset] = slots.title(preset) .. (customized and " *" or "")
            changed = changed or labels[preset] ~= presetLabels[preset]
        end
        if not changed then return end
        presetSelector:Clear()
        for preset = 1, entryCount do
            -- Native list IDs are zero-based; storage slots are one-based.
            presetSelector:Add(labels[preset], preset - 1)
        end
        presetSelector:SetEntrySelected(selectedSlot - 1, true, false)
        presetLabels = labels
    end
    refreshPresetLabels()
    local smallFont = id.Font.MUSEO_SANS_11PT_REGULAR or id.Font.MUSEO_SANS_15PT_REGULAR

    local previewBorder, previewBackground
    if bindings.colours then
        previewBorder = ui.Rectangle.new(parent)
        previewBorder.fill = true
        previewBorder.colour = theme.colour(theme.border)
        previewBorder.clickthrough = true
        previewBorder:SetSize(layout.controlWidth, layout.fieldHeight)
        trackPosition(previewBorder, layout.padding, layout.rows.input)
        previewBackground = ui.Rectangle.new(parent)
        previewBackground.fill = true
        previewBackground.clickthrough = true
        previewBackground:SetSize(layout.controlWidth, layout.fieldHeight)
        trackPosition(previewBackground, layout.padding, layout.rows.input)
    end
    local managedInput = contentHost and contentHost:AddTextField({
        absolute = true, x = 0, y = 0, width = layout.controlWidth,
        height = layout.fieldHeight, maxLength = constants.maximumNameLength,
        placeholder = "Uses predefined name",
        -- SimpleView is itself the scroll controller; Window wraps one.
        _scrollController = contentHost._scroll or contentHost,
    })
    local nameInput = managedInput and managedInput.root or ui.InputField.new(parent)
    trackPosition(nameInput, layout.padding, layout.rows.input)
    nameInput:SetSize(layout.controlWidth, layout.fieldHeight)
    nameInput.stylesheetID = id.StyleSheet.INPUT_DEFAULT
    if not managedInput then
        nameInput:Setup(ui.TextContentVisibilityMode.VISIBLE, ui.InputFieldFilterMode.NONE,
            constants.maximumNameLength)
    end
    nameInput.emptyText = "Uses predefined name"
    if previewBackground then
        nameInput.containerSprite.alpha = 0
        nameInput.text.font = id.Font.MUSEO_SANS_15PT_REGULAR
        nameInput.text.alignHorizontal = ui.AlignMode.CENTRE
        nameInput.text.isShadowed = true
    end
    local defaultNamePreview
    if previewBackground then
        -- Render default and custom names through the same bank-style label.
        -- The native input still owns editing, caret and selection.
        defaultNamePreview = ui.Text.new(parent)
        defaultNamePreview:SetSize(layout.controlWidth, layout.fieldHeight)
        defaultNamePreview.alignHorizontal = ui.AlignMode.CENTRE
        defaultNamePreview.alignVertical = ui.AlignMode.CENTRE
        defaultNamePreview.clickthrough = true
        defaultNamePreview.maxLines = 1
        trackPosition(defaultNamePreview, layout.padding, layout.rows.input)
        nameInput.emptyText = ""
    end
    local pendingIcon = ""
    local iconTextInput, managedIconText, iconTextLabel
    local iconTextComponents = {}
    local previewSkillIcon
    local iconControl, iconControlSprite, iconControlNumber, iconLabel, iconReset
    local iconComponents = {}
    local iconHidden = {}
    local unsavedIcon, unsavedLabel
    if options.readOnlyPreset then
        unsavedIcon = ui.Sprite.new(parent)
        unsavedIcon.sprite = id.Sprite.RS3_ICON_EDIT_23PX_0
        unsavedIcon.clickthrough = true
        unsavedIcon:SetSize(18, 18)
        trackPosition(unsavedIcon, layout.padding,
            bindings.colours and layout.rows.colourStatus or layout.rows.status)
        unsavedLabel = createText(parent, "Unsaved", smallFont)
        unsavedLabel:SetSize(58, layout.noteHeight)
        unsavedLabel.alignVertical = ui.AlignMode.CENTRE
        unsavedLabel.clickthrough = true
        unsavedLabel.colour = theme.colour(theme.titleText)
        trackPosition(unsavedLabel, layout.padding,
            bindings.colours and layout.rows.colourStatus or layout.rows.status)
    end
    local previewNumber, previewIconText, previewIcons = nil, nil, {}
    if previewBackground then
        previewNumber = ui.Text.new(parent)
        previewNumber:SetSize(28, layout.fieldHeight)
        previewNumber.font = id.Font.MUSEO_SANS_15PT_REGULAR
        previewNumber.alignVertical = ui.AlignMode.CENTRE
        previewNumber.isShadowed = true
        previewNumber.clickthrough = true
        trackPosition(previewNumber, layout.padding, layout.rows.input)
        if bindings.icons then
            previewSkillIcon = ui.Sprite.new(parent)
            previewSkillIcon.clickthrough = true
            previewSkillIcon.enabled = false
            previewSkillIcon:SetSize(24, 24)
            trackPosition(previewSkillIcon, layout.padding, layout.rows.input)
        end
        if bindings.iconText then
            previewIconText = ui.Text.new(parent)
            previewIconText:SetSize(40, layout.fieldHeight)
            previewIconText.font = smallFont
            previewIconText.maxLines = 1
            previewIconText.alignHorizontal = ui.AlignMode.CENTRE
            previewIconText.alignVertical = ui.AlignMode.CENTRE
            previewIconText.isShadowed = true
            previewIconText.clickthrough = true
            trackPosition(previewIconText, layout.padding, layout.rows.input)
        end
        for index = 1, 3 do
            local sprite = ui.Sprite.new(parent)
            sprite:SetSize(20, 20)
            sprite.clickthrough = true
            trackPosition(sprite, layout.padding, layout.rows.input)
            previewIcons[index] = sprite
        end
    end
    local function applyIcon(sprite, maxWidth, maxHeight)
        if not sprite then return false end
        local spriteID, entry = iconCatalogue.resolve(pendingIcon)
        local ok = false
        if slots.valid(selectedSlot) and spriteID then
            ok = pcall(function()
                iconCatalogue.apply(sprite, spriteID, entry)
                sprite.rgba = 0xFFFFFFFF
                local scale = math.min(maxWidth / entry.width, maxHeight / entry.height, 1)
                sprite:SetSize(math.max(1, math.floor(entry.width * scale)),
                    math.max(1, math.floor(entry.height * scale)))
            end)
        end
        sprite.hidden = not ok
        iconHidden[sprite] = not ok
        return ok
    end
    local function refreshIcon()
        local _, entry = iconCatalogue.resolve(pendingIcon)
        local isItem = entry and entry.objectID
        local active = applyIcon(previewSkillIcon, isItem and 28 or 24, isItem and 30 or 24)
        if active and previewNumber.x and previewNumber.y then
            previewSkillIcon:SetPos(previewNumber.x - (isItem and 3 or 0)
                + math.floor(((isItem and 28 or 24) - previewSkillIcon.width) / 2),
                previewNumber.y + math.floor((layout.fieldHeight - previewSkillIcon.height) / 2))
        end
        local text = iconTextInput and iconTextInput.content or ""
        local hasText = slots.valid(selectedSlot) and text ~= ""
        if previewNumber then
            previewNumber.hidden = active or hasText
            iconHidden[previewNumber] = active or hasText
        end
        if previewIconText then
            previewIconText.content = text
            previewIconText.rgba = previewNumber.rgba
            previewIconText.hidden = not hasText
            iconHidden[previewIconText] = not hasText
            if previewNumber.x ~= nil and previewNumber.y ~= nil then
                previewIconText:SetPos(previewNumber.x - 8, previewNumber.y + (active and 6 or 0))
            end
        end
        if iconControl then
            local supported = slots.valid(selectedSlot)
            for component in pairs(iconComponents) do
                component.hidden = not supported
                iconHidden[component] = not supported
            end
            iconControl.enabled = supported
            local available = applyIcon(iconControlSprite, isItem and 30 or 24, 24)
            if available and iconControl.x and iconControl.y then
                iconControlSprite:SetPos(iconControl.x + 2 + math.floor(((isItem and 30 or 24)
                    - iconControlSprite.width) / 2),
                    iconControl.y + math.floor((iconControl.height - iconControlSprite.height) / 2))
            end
            iconControlNumber.content = tostring(selectedSlot)
            iconControlNumber.hidden = not supported or available
            iconHidden[iconControlNumber] = not supported or available
            if not supported then
                iconControlSprite.hidden = true
                iconHidden[iconControlSprite] = true
            end
        end
    end
    local function refreshDecorations()
        if not previewNumber then return end
        local number = bankPreview.number(selectedSlot)
        previewNumber.content = selectedSlot == slots.bob and "" or tostring(selectedSlot)
        previewNumber.rgba = number and number.rgba or 0xFFCB75FF
        if number then
            previewNumber.font = number.font
            previewNumber.isShadowed = number.isShadowed
        end
        refreshIcon()
        for index, sprite in ipairs(previewIcons) do
            local source = bankPreview.decoration(selectedSlot, index)
            local resource = source and source.sprite
            sprite.alpha = resource ~= nil and source.alpha or 0
            if resource ~= nil then
                sprite.sprite = resource
                sprite.rgba = source.rgba
            end
        end
    end
    local alignmentContent, alignmentWidth, alignmentHeight, alignmentFont
    local nativeTextVisible = false
    local function refreshInputAlignment()
        if not previewBackground then return end
        local content, width, height = nameInput.content or "", nameInput.width, nameInput.height
        local fontID = nameInput.text.font
        local font = config.Font.FromID(fontID)
        local textWidth = content ~= "" and font:GetStringWidth(content, true) or 0
        nativeTextVisible = textWidth > math.max(1, width - 16)
        defaultNamePreview.hidden = nativeTextVisible
        defaultNamePreview.content = content ~= "" and content
            or bankLabels.original(bindings.labels, selectedSlot) or "Uses predefined name"
        local clipped = managedInput and managedInput._unclippedAppearance
        local rgba = nativeTextVisible and (defaultNamePreview.rgba or 0) or 0
        if clipped then clipped.textRGBA = rgba
        else
            nameInput.text.rgba = rgba
            if not nativeTextVisible then nameInput.text.isShadowed = false end
        end
        if content == alignmentContent and width == alignmentWidth
            and height == alignmentHeight and fontID == alignmentFont then return end
        alignmentContent, alignmentWidth, alignmentHeight, alignmentFont = content, width, height, fontID
        -- Native fields honour text alignment only for their placeholder.
        -- Move the editable origin, retaining native caret and selection.
        local left = math.min(255, math.max(8, math.floor((width - textWidth - 2) / 2)))
        -- Centre the visible glyph bounds, not the font's line spacing.
        -- Native inputs place the baseline at top + font.baseline.
        local centredBaseline = math.floor((height - font.maxAscent - font.maxDescent) / 2)
            + font.maxAscent
        local top = math.min(255, math.max(0, centredBaseline - font.baseline))
        nameInput.contentMargin = ui.Margin.new(left, top, 8, 0)
    end

    local statusLabel = createText(parent, "", smallFont)
    if bindings.colours then
        statusLabel:SetSize(layout.controlWidth, layout.noteHeight)
    end
    trackPosition(statusLabel, layout.padding,
        bindings.colours and layout.rows.colourStatus or layout.rows.status)
    local function setStatus(message, succeeded)
        statusLabel.content = message
        statusLabel.colour = theme.colour(succeeded and theme.success or theme.error)
    end
    local colourControls = {}
    local colourSwatches = {}
    local updateColourResetIcons = {}
    local defaultMarks = {}
    local defaultMarkKinds = {}
    local colourLabels = {}
    local pendingColours = {}
    local refreshUnsavedChanges
    local closePicker
    local updatePicker
    local pickerKind
    local function dismissPicker()
        if closePicker then closePicker(); closePicker = nil end
        updatePicker = nil
        pickerKind = nil
    end
    local function refreshColours()
        if not bindings.colours then return end
        refreshDecorations()
        local visual = bankLabels.visual(bindings.labels, selectedSlot)
        local clipped = managedInput and managedInput._unclippedAppearance
        if visual then
            if visual.font ~= nil then nameInput.text.font = visual.font end
            if visual.shadowRGBA ~= nil then nameInput.text.shadowRGBA = visual.shadowRGBA end
            if visual.isShadowed ~= nil then
                if clipped then clipped.isShadowed = visual.isShadowed
                else nameInput.text.isShadowed = visual.isShadowed end
            end
        end
        defaultNamePreview.font = nameInput.text.font
        defaultNamePreview.isShadowed = not visual or visual.isShadowed ~= false
        refreshInputAlignment()
        local background = colourValue.rgba(pendingColours.background)
            or bankAppearance.original(bindings.appearance, selectedSlot, "background")
            or 0x292520FF
        local text = colourValue.rgba(pendingColours.text)
            or bankAppearance.original(bindings.appearance, selectedSlot, "text")
            or 0xB8AD9DFF
        previewBackground.rgba = background
        defaultNamePreview.rgba = text
        -- PrettyUI temporarily makes native text transparent when clipped.
        -- Update its restore state instead of leaking text outside the viewport.
        if clipped then
            clipped.textRGBA, clipped.emptyTextRGBA, clipped.caretRGBA = nativeTextVisible and text or 0, text, text
            clipped.isShadowed = nativeTextVisible and defaultNamePreview.isShadowed or false
        else
            nameInput.text.rgba = nativeTextVisible and text or 0
            nameInput.text.isShadowed = nativeTextVisible and defaultNamePreview.isShadowed or false
            nameInput.emptyTextRGBA = text
            nameInput.caretRGBA = text
        end
        for kind, control in pairs(colourControls) do
            local value = pendingColours[kind]
            local hex = colourValue.normalize(value)
            control.colour = theme.colour(hex and colourValue.vector(hex) or theme.background)
            for _, mark in ipairs(defaultMarks[kind]) do mark.hidden = hex ~= nil end
        end
    end
    if bindings.colours then
        for index, kind in ipairs({ "background", "text" }) do
            local y = layout.rows.colourLabel + (index - 1) * 32
            local label = createText(parent, kind == "background" and "Background colour:" or "Text colour:", smallFont)
            label:SetSize(layout.swatchX - layout.padding - 6, 20)
            label.clickthrough = true
            colourLabels[kind] = label
            trackPosition(label, layout.padding, y)
            local border = ui.Button.new(parent)
            border:SetSize(58, 26)
            border.stylesheetID = id.StyleSheet.BUTTON_DEFAULT
            border.label = ""
            border.clickthrough = true
            trackPosition(border, layout.swatchX, y - 3)
            colourSwatches[border] = true
            local control = ui.Rectangle.new(parent)
            control:SetSize(54, 20)
            control.fill = true
            control.clickthrough = false
            trackPosition(control, layout.swatchX + 2, y)
            colourControls[kind] = control
            colourSwatches[control] = true
            local resetColour, updateReset = icons.new(parent,
                id.Sprite.RS3_ICON_STOPWATCH_RESET_0,
                id.Sprite.RS3_ICON_STOPWATCH_RESET_1,
                id.Sprite.RS3_ICON_STOPWATCH_RESET_2, function()
                dismissPicker()
                pendingColours[kind] = ""
                statusLabel.content = ""
                refreshColours()
                refreshUnsavedChanges()
            end)
            resetColour:SetSize(22, 22)
            trackPosition(resetColour, layout.swatchX + 66, y - 1)
            updateColourResetIcons[#updateColourResetIcons + 1] = updateReset
            defaultMarks[kind] = {}
            -- Blend neighbouring pixels according to the fractional line position.
            -- Native rectangles do not need rotation and remain click-through.
            for column = 0, 49 do
                local offset = column * 15 / 49
                for _, position in ipairs({ offset, 15 - offset }) do
                    local row = math.floor(position)
                    local fraction = position - row
                    for _, pixel in ipairs({ { row, 1 - fraction }, { row + 1, fraction } }) do
                        if pixel[2] > 0 then
                            local mark = ui.Rectangle.new(parent)
                            mark:SetSize(1, 1)
                            mark.fill = true
                            mark.colour = theme.colour({ 1, 1, 1, pixel[2] })
                            mark.clickthrough = true
                            trackPosition(mark, layout.swatchX + 4 + column, y + 2 + pixel[1])
                            defaultMarks[kind][#defaultMarks[kind] + 1] = mark
                            defaultMarkKinds[mark] = kind
                        end
                    end
                end
            end
            control:Subscribe(ui.Hook.ONCLICK, function()
                local toggleClosed = pickerKind == kind
                dismissPicker()
                if toggleClosed then return end
                pickerKind = kind
                local slot, context = selectedSlot, names.getContext()
                closePicker, updatePicker = colourPicker.open(host, {
                    title = "Choose " .. kind .. " colour",
                    initial = colourValue.normalize(pendingColours[kind]),
                    anchor = control,
                    theme = theme,
                    attachOverlay = contentHost and contentHost._RegisterOverlay and function(root, updatePosition)
                        contentHost:_RegisterOverlay(root, nil, updatePosition)
                        contentHost:_SyncOverlays(false)
                        return function() contentHost:_UnregisterOverlay(root) end
                    end or nil,
                    onChange = function(value)
                    if selectedSlot ~= slot or names.getContext() ~= context then return end
                    pendingColours[kind] = value
                    statusLabel.content = ""
                    refreshColours()
                    refreshUnsavedChanges()
                    end,
                    onClose = function()
                    closePicker = nil
                    updatePicker = nil
                    pickerKind = nil
                    end,
                })
            end)
        end
    end
    if bindings.icons then
        local function trackIcon(component, x, y)
            iconComponents[component] = true
            return trackPosition(component, x, y)
        end
        iconLabel = createText(parent, "Icon:", smallFont)
        iconLabel:SetSize(layout.swatchX - layout.padding - 6, 20)
        iconLabel.clickthrough = true
        trackIcon(iconLabel, layout.padding, layout.rows.colourLabel)
        iconControl = ui.Button.new(parent)
        iconControl:SetSize(58, 26)
        iconControl.stylesheetID = id.StyleSheet.BUTTON_DEFAULT
        iconControl.label = ""
        trackIcon(iconControl, layout.swatchX, layout.rows.colourLabel - 3)
        iconControlNumber = createText(parent, "", smallFont)
        iconControlNumber:SetSize(24, 24)
        iconControlNumber.alignHorizontal = ui.AlignMode.CENTRE
        iconControlNumber.alignVertical = ui.AlignMode.CENTRE
        iconControlNumber.clickthrough = true
        trackIcon(iconControlNumber, layout.swatchX + 4, layout.rows.colourLabel - 2)
        -- The client font lacks the Unicode dropdown triangle. Draw a small
        -- click-through triangle instead, independent of font glyph coverage.
        for row = 0, 3 do
            local arrow = ui.Rectangle.new(parent)
            arrow:SetSize(7 - row * 2, 1)
            arrow.fill = true
            arrow.colour = theme.colour(theme.titleText)
            arrow.clickthrough = true
            trackIcon(arrow, layout.swatchX + 40 + row, layout.rows.colourLabel + 8 + row)
        end
        iconControlSprite = ui.Sprite.new(parent)
        iconControlSprite:SetSize(24, 24)
        iconControlSprite.clickthrough = true
        iconControlSprite.enabled = false
        trackIcon(iconControlSprite, layout.swatchX + 4, layout.rows.colourLabel - 2)
        local updateReset
        iconReset, updateReset = icons.new(parent,
            id.Sprite.RS3_ICON_STOPWATCH_RESET_0, id.Sprite.RS3_ICON_STOPWATCH_RESET_1,
            id.Sprite.RS3_ICON_STOPWATCH_RESET_2, function()
                dismissPicker()
                pendingIcon = ""
                statusLabel.content = ""
                refreshIcon()
                refreshUnsavedChanges()
            end)
        iconReset:SetSize(22, 22)
        trackIcon(iconReset, layout.swatchX + 66, layout.rows.colourLabel - 1)
        updateColourResetIcons[#updateColourResetIcons + 1] = updateReset
        iconControl:Subscribe(ui.Hook.ONBUTTONPRESSED, function()
            if not slots.valid(selectedSlot) then return end
            local toggleClosed = pickerKind == "icon"
            dismissPicker()
            if toggleClosed then return end
            pickerKind = "icon"
            local slot, context = selectedSlot, names.getContext()
            closePicker, updatePicker = iconPicker.open(host, {
                prettyui = options.prettyui,
                categories = backpackIcons.categories(), initial = pendingIcon,
                searchIndex = require("presets/item_search"),
                initialName = iconCatalogue.displayName(pendingIcon),
                resolve = iconCatalogue.resolve, apply = iconCatalogue.apply, anchor = iconControl, theme = theme,
                attachOverlay = contentHost and contentHost._RegisterOverlay and function(root, updatePosition)
                    contentHost:_RegisterOverlay(root, nil, updatePosition)
                    contentHost:_SyncOverlays(false)
                    return function() contentHost:_UnregisterOverlay(root) end
                end or nil,
                onSelect = function(value)
                    if selectedSlot ~= slot or names.getContext() ~= context then return end
                    pendingIcon = value
                    statusLabel.content = ""
                    refreshIcon()
                    refreshUnsavedChanges()
                end,
                onClose = function()
                    closePicker, updatePicker, pickerKind = nil, nil, nil
                end,
            })
        end)
    end
    if bindings.iconText then
        iconTextLabel = createText(parent, "Icon text:", smallFont)
        iconTextLabel:SetSize(layout.swatchX - layout.padding - 6, 20)
        iconTextLabel.clickthrough = true
        iconTextComponents[iconTextLabel] = true
        trackPosition(iconTextLabel, layout.padding, layout.rows.colourLabel)
        managedIconText = contentHost and contentHost:AddTextField({
            absolute = true, x = 0, y = 0, width = 58, height = 26, maxLength = 3,
            placeholder = "", _scrollController = contentHost._scroll or contentHost,
        })
        iconTextInput = managedIconText and managedIconText.root or ui.InputField.new(parent)
        iconTextInput:SetSize(58, 26)
        iconTextInput.stylesheetID = id.StyleSheet.INPUT_DEFAULT
        if not managedIconText then
            iconTextInput:Setup(ui.TextContentVisibilityMode.VISIBLE, ui.InputFieldFilterMode.NONE, 3)
        end
        iconTextComponents[iconTextInput] = true
        trackPosition(iconTextInput, layout.swatchX, layout.rows.colourLabel - 3)
        local resetText, updateReset = icons.new(parent,
            id.Sprite.RS3_ICON_STOPWATCH_RESET_0, id.Sprite.RS3_ICON_STOPWATCH_RESET_1,
            id.Sprite.RS3_ICON_STOPWATCH_RESET_2, function()
                iconTextInput.content = ""
                statusLabel.content = ""
                refreshIcon()
                refreshUnsavedChanges()
            end)
        resetText:SetSize(22, 22)
        iconTextComponents[resetText] = true
        trackPosition(resetText, layout.swatchX + 66, layout.rows.colourLabel - 1)
        updateColourResetIcons[#updateColourResetIcons + 1] = updateReset
    end
    local toggleInfo, positionInfo = info.new(options.infoParent or host, {
        header = options.infoParent ~= nil,
    })

    -- Popup chrome supplies its own button; native settings chrome is owned by
    -- the client, so keep the embedded button in our content's top-right corner.
    local infoButton, updateInfo
    if not options.externalInfoButton then
        infoButton, updateInfo = icons.info(host, toggleInfo)
    end

    local displayedCharacterContext = names.getContext()
    refreshUnsavedChanges = function()
        local dirty = (nameInput.content or "") ~= (names.get(selectedSlot) or "")
        if bindings.colours then
            for _, kind in ipairs({ "background", "text" }) do
                local pending = colourValue.normalize(pendingColours[kind]) or ""
                local saved = colourValue.normalize(bindings.colours.get(selectedSlot, kind)) or ""
                dirty = dirty or pending ~= saved
            end
        end
        if bindings.icons then dirty = dirty or pendingIcon ~= (bindings.icons.get(selectedSlot) or "") end
        if iconTextInput then dirty = dirty or (iconTextInput.content or "") ~= bindings.iconText.get(selectedSlot) end
        if unsavedIcon then
            unsavedIcon.hidden, unsavedLabel.hidden = not dirty, not dirty
            iconHidden[unsavedIcon], iconHidden[unsavedLabel] = not dirty, not dirty
        end
        refreshPresetLabels()
    end
    local function refreshSelectedName()
        dismissPicker()
        displayedCharacterContext = names.getContext()
        pendingIcon = bindings.icons and bindings.icons.get(selectedSlot) or ""
        if iconTextInput then
            iconTextInput.content = bindings.iconText.get(selectedSlot)
            iconTextInput.enabled = slots.valid(selectedSlot)
        end
        if bindings.colours then
            for kind in pairs(colourControls) do
                pendingColours[kind] = bindings.colours.get(selectedSlot, kind)
            end
        end
        refreshColours()
        refreshPresetLabels()
        refreshIcon()
        nameInput.content = names.get(selectedSlot) or ""
        refreshInputAlignment()
        refreshUnsavedChanges()
        statusLabel.content = displayedCharacterContext and "" or "Log in and wait for your character name."
    end

    local function saveValue(value)
        dismissPicker()
        -- Do not save an old character's unfinished edit under a new character.
        if names.getContext() ~= displayedCharacterContext then
            refreshSelectedName()
            setStatus("Character changed. Enter the name again.", false)
            return false
        end

        local saveSucceeded, message = persistence.save(selectedSlot, {
            name = value, background = pendingColours.background, text = pendingColours.text,
            icon = bindings.icons and pendingIcon or nil,
            iconText = iconTextInput and (iconTextInput.content or "") or nil,
        })
        setStatus(message, saveSucceeded)
        refreshUnsavedChanges()
        return saveSucceeded
    end

    local function saveInput()
        saveValue(nameInput.content)
    end

    local function actionButton(label, callback)
        if not contentHost then return createButton(parent, label, callback) end
        return contentHost:AddSimpleButton(label, callback, {
            absolute = true, x = 0, y = 0,
            width = layout.buttonWidth, height = layout.buttonHeight,
        }).root
    end

    local centreContent
    local function selectSlot(slot)
        if not slots.valid(slot, entryCount) or slot == selectedSlot then return end
        selectedSlot = slot
        if presetSelector then presetSelector:SetEntrySelected(slot - 1, true, false) end
        refreshSelectedName()
        if centreContent then centreContent() end
    end

    -- Wire user actions after the controls and their shared state exist.
    if presetSelector then presetSelector:Subscribe(ui.Hook.ONSELECTIONCHANGED, function(_, entryID, event)
        local selectedPreset = entryID + 1
        if event == ui.SelectionChangeEvent.SELECTED
            and selectedPreset >= 1 and selectedPreset <= entryCount
            and selectedPreset ~= selectedSlot then
            selectSlot(selectedPreset)
        end
    end) end
    local buttonsY = bindings.colours and layout.rows.colourButtons or layout.rows.buttons
    trackPosition(actionButton("Save", saveInput), layout.padding, buttonsY)
    trackPosition(actionButton("Reset", function()
        dismissPicker()
        if names.getContext() ~= displayedCharacterContext then
            refreshSelectedName()
            setStatus("Character changed. Enter the name again.", false)
            return
        end
        nameInput.content = ""
        pendingColours.background, pendingColours.text = "", ""
        pendingIcon = ""
        if iconTextInput then iconTextInput.content = "" end
        refreshColours()
        refreshIcon()
        refreshUnsavedChanges()
        setStatus("Defaults staged. Click Save to apply.", true)
    end), layout.resetX, buttonsY)
    if managedInput then
        managedInput.onSubmit = saveInput
        managedInput.onChange = function()
            refreshInputAlignment()
            refreshUnsavedChanges()
        end
    else
        nameInput:Subscribe(ui.Hook.ONCONTENTCHANGED, function(_, reason)
            refreshInputAlignment()
            refreshUnsavedChanges()
            if reason == ui.InputFieldActionResult.SUBMIT then
                saveInput()
            end
        end)
    end
    if iconTextInput then
        local function changed()
            statusLabel.content = ""
            refreshIcon()
            refreshUnsavedChanges()
        end
        if managedIconText then
            managedIconText.onChange = changed
            managedIconText.onSubmit = saveInput
        else
            iconTextInput:Subscribe(ui.Hook.ONCONTENTCHANGED, function(_, reason)
                changed()
                if reason == ui.InputFieldActionResult.SUBMIT then saveInput() end
            end)
        end
    end
    refreshSelectedName()

    for _, position in ipairs(controlPositions) do
        position.width, position.height = position.component.width, position.component.height
    end

    if scrollView then
        for _, position in ipairs(controlPositions) do
            -- Lists own their wheel events for navigating their entries.
            if position.component ~= presetSelector
                and not (managedInput and position.component == nameInput)
                and not (managedIconText and position.component == iconTextInput) then
                position.component:Subscribe(ui.Hook.ONSCROLLWHEEL, "customBankPresets.scroll", function(_, delta)
                    if not scrollView.scrollbarVisible then return true end
                    scrollView:ScrollBy(delta * layout.fieldHeight)
                    return false
                end)
            end
        end
    end

    local function updateClipping()
        if not scrollView then return end
        for _, position in ipairs(controlPositions) do
            local control = position.component
            local top = control.y - scrollView.scrollY
            -- Native input text can escape ancestor clipping; suppress controls
            -- crossing the viewport boundary, as in the previous ribbon editor.
            if not (managedInput and control == nameInput) and not (managedIconText and control == iconTextInput) then
                local kind = defaultMarkKinds[control]
                local customColour = kind and colourValue.normalize(pendingColours[kind]) ~= nil
                local nonemptyPreview = control == defaultNamePreview and nativeTextVisible
                control.hidden = not not (customColour or nonemptyPreview or iconHidden[control]
                    or top < 0 or top + control.height > host.height)
            end
        end
    end

    local function sizeContent()
        local hostHeight = options.formHeight or host.height
        local minimumHeight = (bindings.colours and layout.minimumColourHeight or layout.minimumHeight)
            + (bindings.icons and layout.iconHeight or 0)
            + (bindings.iconText and layout.iconTextHeight or 0)
            - (options.hideTitle and layout.titleHeight or 0)
            - headingGapReduction
        local overflowing = scrollView ~= nil and host.height < minimumHeight
        local compact = hostHeight < contentHeight
        local titleOffset = options.hideTitle and layout.titleHeight or 0
        local height = compact and minimumHeight or contentHeight
        if scrollView then
            scrollView:SetSize(host.width, host.height)
            scrollView:SetContentHeight(height)
        end
        local availableHostWidth = scrollView and scrollView.contentWidth or host.width
        local width = math.min(contentWidth, math.max(1, availableHostWidth))
        local controlWidth = math.max(1, width - layout.padding * 2)
        local buttonWidth = math.max(1, (controlWidth - layout.buttonGap) / 2)
        return {
            overflowing = overflowing,
            compact = compact,
            titleOffset = titleOffset,
            width = width,
            controlWidth = controlWidth,
            buttonWidth = buttonWidth,
            offsetX = math.max(0, math.floor((availableHostWidth - width) / 2)),
            offsetY = math.max(0, math.floor((hostHeight - height) / 2)),
        }
    end

    local function buildCompactRowMapping()
        -- Tight ribbon panels need smaller gaps, not smaller text or fields.
        -- Leave the established popup/settings spacing alone when it fits.
        local compactRows = {
            [layout.rows.title] = layout.compactRows.title,
            [layout.rows.selector] = layout.compactRows.selector,
            [layout.rows.input] = layout.compactRows.input,
            [layout.rows.colourLabel] = layout.compactRows.colourLabel,
            [layout.rows.colourInput] = layout.compactRows.colourInput,
            [layout.rows.colourButtons] = layout.compactRows.colourButtons,
            [layout.rows.colourStatus] = layout.compactRows.colourStatus,
        }
        if not bindings.colours then
            compactRows[layout.rows.buttons] = layout.compactRows.buttons
            compactRows[layout.rows.status] = layout.compactRows.status
        end
        return compactRows
    end

    local function positionControls(size, compactRows)
        local compact, titleOffset = size.compact, size.titleOffset
        local width, controlWidth, buttonWidth = size.width, size.controlWidth, size.buttonWidth
        local offsetX, offsetY = size.offsetX, size.offsetY
        for _, position in ipairs(controlPositions) do
            local control = position.component
            local x = position.x == layout.resetX
                and layout.padding + buttonWidth + layout.buttonGap or position.x
            local y = compact and (compactRows[position.y + titleOffset] or position.y + titleOffset)
                - titleOffset or position.y
            local isColumn = position.width == layout.buttonWidth
                or (bindings.colours and position.y + titleOffset == layout.rows.colourLabel)
            local availableWidth = isColumn and buttonWidth or controlWidth
            local isSwatch = position.x >= layout.swatchX - 1 and (position.width <= 34 or colourSwatches[control] or control == iconControl or control == iconTextInput)
            local isColourLabel = control == colourLabels.background or control == colourLabels.text or control == iconLabel or control == iconTextLabel
            local swatchX = math.max(layout.padding, math.min(layout.swatchX,
                width - layout.padding - 88))
            if isSwatch then
                availableWidth = position.width
                x = swatchX + position.x - layout.swatchX
            elseif isColourLabel then
                availableWidth = math.max(1, swatchX - layout.padding - 6)
            end
            if isSwatch or isColourLabel then
                local row = position.y + titleOffset >= layout.rows.colourInput and layout.rows.colourInput
                    or layout.rows.colourLabel
                y = (compact and compactRows[row] or row) - titleOffset
                    + position.y + titleOffset - row
            end
            if position.y + titleOffset >= layout.rows.input then
                y = y - headingGapReduction
            end
            if bindings.icons and slots.valid(selectedSlot) and not iconComponents[control]
                and position.y + titleOffset >= layout.rows.colourLabel - 3 then
                y = y + layout.iconHeight
            end
            if bindings.iconText and not iconComponents[control] and not iconTextComponents[control]
                and position.y + titleOffset >= layout.rows.colourLabel - 3 then
                y = y + layout.iconTextHeight
            end
            if control.content == constants.editorTitle or control.content == "Preset customisation" then
                control.content = width < layout.width and "Preset customisation" or constants.editorTitle
                availableWidth = math.max(1, controlWidth - layout.popupCloseSize - 4)
            end
            control:SetSize(availableWidth, compact and position.height == layout.textHeight
                and layout.noteHeight or position.height)
            control:SetPos(offsetX + x, offsetY + y)
            if control == statusLabel and unsavedIcon then
                control:SetSize(math.max(1, controlWidth - 82), position.height)
            elseif control == unsavedIcon then
                control:SetSize(18, 18)
                control:SetPos(offsetX + layout.padding + controlWidth - 80, offsetY + y)
            elseif control == unsavedLabel then
                control:SetSize(58, position.height)
                control:SetPos(offsetX + layout.padding + controlWidth - 58, offsetY + y)
            end
            if previewNumber and (control == nameInput or control == defaultNamePreview) then
                control:SetSize(math.max(1, controlWidth - 96), position.height)
                control:SetPos(offsetX + layout.padding + 28, offsetY + y)
            elseif control == previewNumber then
                control:SetSize(24, layout.fieldHeight)
                control:SetPos(offsetX + layout.padding + 5, offsetY + y)
            elseif control == previewSkillIcon then
                control:SetSize(24, 24)
                control:SetPos(offsetX + layout.padding + 5, offsetY + y + (layout.fieldHeight - 24) / 2)
            elseif control == previewIconText then
                control:SetSize(40, layout.fieldHeight)
                control:SetPos(offsetX + layout.padding - 3, offsetY + y)
            else
                for index, sprite in ipairs(previewIcons) do
                    if control == sprite then
                        sprite:SetSize(20, 20)
                        sprite:SetPos(offsetX + layout.padding + controlWidth - 64 + (index - 1) * 20,
                            offsetY + y + (layout.fieldHeight - 20) / 2)
                    end
                end
            end
            if control == previewBackground then
                control:SetSize(math.max(1, availableWidth - 2), math.max(1, position.height - 2))
                control:SetPos(offsetX + x + 1, offsetY + y + 1)
            end
        end
    end

    centreContent = function()
        dismissPicker()
        local size = sizeContent()
        positionControls(size, buildCompactRowMapping())
        if infoButton then
            infoButton.hidden = size.overflowing
            infoButton:SetPos(math.max(0, host.width - layout.padding - layout.popupCloseSize),
                layout.padding)
        end
        positionInfo()
        refreshInputAlignment()
        refreshIcon()
        updateClipping()
        if managedInput then
            -- Refresh after repositioning too, not only when the user scrolls.
            (contentHost._scroll or contentHost):SetScrollPosition(contentHost.scrollY or 0)
        end
    end
    centreContent()
    host:Subscribe(ui.Hook.ONRESIZE, "customBankPresets.centre", centreContent)

    -- Called by main.lua each logic tick, not only when the editor is opened.
    return function()
        if host.visibleGlobal == false then dismissPicker() end
        if updatePicker then updatePicker() end
        updateClipping()
        if updateInfo then updateInfo() end
        for _, updateReset in ipairs(updateColourResetIcons) do updateReset() end
        if names.getContext() ~= displayedCharacterContext then
            refreshSelectedName()
        end
        refreshUnsavedChanges()
        refreshColours()
        refreshIcon()
        updateClipping()
    end, toggleInfo, function()
        dismissPicker()
        if scrollView then scrollView:Destroy() end
    end, selectSlot
end

return editor
