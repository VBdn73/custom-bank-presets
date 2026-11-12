-- Keep the embedded editor and its popup host sized together.
local slots = require("presets/slots")
local layout = {
    width = 336,
    height = 262,
    compactHeight = 194,
    minimumHeight = 184,
    minimumColourHeight = 234,
    titleHeight = 32,
    padding = 8,
    textHeight = 28,
    noteHeight = 18,
    fieldHeight = 32,
    buttonHeight = 30,
    buttonGap = 20,
    swatchX = 144,
    dropdownVisibleEntries = 8,
    rows = {
        title = 8,
        selector = 48,
        input = 90,
        colourLabel = 134,
        colourInput = 166,
        colourStatus = 238,
        colourButtons = 206,
        buttons = 134,
        status = 166,
        scopeNotes = 214,
    },
    compactRows = {
        title = 8,
        selector = 36,
        input = 72,
        colourLabel = 108,
        colourInput = 140,
        colourButtons = 176,
        colourStatus = 208,
        buttons = 122,
        status = 154,
    },
    noteSpacing = 20,
    popupPadding = 8,
    popupHeaderHeight = 36,
    popupBottomPadding = 12,
    popupBorderInset = 1,
    popupTitleBarInset = 4,
    popupTitleBarHeight = 30,
    popupTitleX = 12,
    popupTitleY = 7,
    popupTitleHeight = 26,
    popupCloseSize = 22,
    popupEditorGapReduction = 12,
    popupHeadingRemoval = 38,
    popupFeedbackHeight = 28,
    popupErrorExtraHeight = 24,
}

layout.controlWidth = layout.width - layout.padding * 2
layout.buttonWidth = (layout.controlWidth - layout.buttonGap) / 2
layout.resetX = layout.padding + layout.buttonWidth + layout.buttonGap
layout.bodyHeight = layout.height - layout.titleHeight
layout.compactBodyHeight = layout.compactHeight - layout.titleHeight
layout.popupWidth = layout.width + layout.popupPadding * 2
layout.popupHeight = layout.popupHeaderHeight + layout.bodyHeight + layout.popupBottomPadding
layout.compactPopupHeight = layout.popupHeaderHeight + layout.compactBodyHeight + layout.popupBottomPadding
layout.colourHeight = 64
layout.iconHeight = 32
layout.iconTextHeight = 32

function layout.customisationHeight(bindings, slot)
    if not slots.valid(slot) then return 0 end
    return (bindings.icons and layout.iconHeight or 0)
        + (bindings.iconText and layout.iconTextHeight or 0)
end

function layout.feedbackHeight(showError)
    return showError and layout.popupErrorExtraHeight or -layout.popupFeedbackHeight
end

function layout.popupBodyHeight(bindings, slot, showError)
    return layout.compactBodyHeight + (bindings.colours and layout.colourHeight or 0)
        + layout.customisationHeight(bindings, slot)
        - layout.popupEditorGapReduction - layout.popupHeadingRemoval
        + layout.feedbackHeight(showError)
end

return layout
