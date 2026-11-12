# Changelog

## 0.9.0 - 2026-11-12

- Added item-artwork search, replacing the Bag, Weapons, and Holidays tabs.
- Indexed item names in batches and filtered duplicate, broken, damaged, uncharged, and augmented items.
- Added icon-name tooltips, a picker scrollbar, and a Blank icon option.
- Refined the editor layout and controls to match the native bank UI; shortened the Beast of Burden editor.
- Refactored colour and icon pickers and expanded regression tests.

## 0.8.0 - 2026-11-03

- Renamed the plugin to Custom bank presets.
- Added up to three letters or numbers of icon text to numbered presets, shown in previews, bank rows, and compact buttons.
- Added the Bag tab for selecting item artwork from the backpack; saved icons remain available after the item leaves it.
- Expanded the weapon catalogue and improved item icon sizing and alignment.
- Wrapped icon-picker tabs to fit and hid empty categories except Bag.
- Added an unsaved-changes indicator to the editor.
- Expanded regression tests for icon text, backpack icons, and picker rendering.

## 0.7.0 - 2026-10-29

- Added preset icons in four categories: Skills (all 29), Weapons, Holidays, and Misc.
- Show saved icons in the editor preview, preset-management rows, and both compact bank pages.
- Added compact preset background colours with an option to hide them (shown by default).
- Added custom names and colours for the Beast of Burden row; its native icon stays unchanged.
- Icons save per character, follow preset swaps, and reset alongside names and colours.
- Improved icon layering and cleanup, restoring native numbers when icons are unavailable or the plugin is disabled.
- Added reusable icon-picker components and expanded regression tests.

## 0.6.0 - 2026-10-27

- Preset names and colours are now edited only in the bank via **Customize preset**.
- Simplified settings and ribbon panels to dropdown visibility and editor guidance.
- Added a preset preview with staged names, colours, and bank icons.
- Replaced the colour picker with a smooth canvas and instant previews.
- Made the picker draggable and prevented clicks passing through it.
- Replaced picker buttons with reset icons beside each colour swatch.
- Added best-effort recovery for failed customisation saves and swaps.
- Refactored editor layout, shared controls, and bank IDs.

## 0.5.0 - 2026-10-26

- Replaced colour dropdowns with background/text swatches and a picker with hue, shade, hex input, preview, and Apply/Cancel/Default controls.
- Click a swatch again to close its picker. Crossed swatches indicate Default.
- Pickers follow the editor, stay within screen bounds, and remain above PrettyUI windows.
- Custom colours use the existing per-character Save/Reset workflow.
- Added a settings option to hide the bank's predefined-name dropdown and expand the preset list into its space.
- Selecting another bank preset now updates the open editor without closing it.
- Replaced the bank editor's preset dropdown with a read-only preset heading; the ribbon/settings selector remains available.
- Fixed layout and alignment in the side plugin menu.
- Extracted reusable colour-picker and help components, centralised slot/colour helpers, and expanded regression tests.

## 0.4.0 - 2026-10-25

- Custom names, background colours, and text colours now follow presets when swapping them by drag and drop in the bank.
- Prevented the previous slot's predefined name briefly appearing when moving a custom name to another slot.

## 0.3.0 - 2026-10-25

- Added independent preset background and text colours, with 13 colours plus Default.
- Bank editor now remembers its position between sessions.
- Improved editor layout and scrolling with PrettyUI controls.

## 0.2.0 - 2026-10-24

- Custom names are now saved separately for each character.
- Added a right-click option to edit names directly from the bank in a draggable popup.
- Marked renamed presets with an asterisk in the preset selector.
- Improved editor styling, save/error feedback, and collapsible information notes.

## 0.1.0 - 2026-10-24

- Initial release with local custom names for all 18 bank preset slots.
- Added a preset selector with Save and Reset controls and support for names up to 40 Unicode characters.
- Saved names locally and restored predefined names when reset or disabled.
