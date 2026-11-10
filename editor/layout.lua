-- Keep the embedded editor and its popup host sized together.
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

return layout
