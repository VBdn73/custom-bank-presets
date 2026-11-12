# Custom bank presets

Give your RuneScape bank presets custom names, colours, icons, and icon text. Version **0.8.1**
changes their appearance locally, not their server-side names or behaviour.

## Features

- Custom names (up to 40 Unicode characters) and background/text colours for all
  18 numbered presets and the Beast of Burden row.
- Icons for numbered presets from **Skills** and **Misc**,
  using native client assets. All 29 skills are included.
- Up to three letters or numbers of icon text for numbered presets, with or without an icon.
- Saved icons appear in preset-management rows and both compact bank pages.
- Optional compact-button background colours, enabled by default.
- Draggable editor with live previews, colour/hex controls, resets, and an unsaved indicator.
- Per-character settings; customisations follow drag-and-drop preset swaps.
- Option to hide the bank's predefined-name dropdown.

No preset loading, automation, hidden information, or slot unlocking. Bank actions
are unchanged. Disabling restores native labels, colours, and numbers where available.
Beast of Burden's native icon is unchanged, and its customisation is excluded from swaps.

See [changelog.md](changelog.md) for release changes.

## Requirements

This is a development version for the RuneScape plugin beta. Distribution requires
Jagex moderation approval; this repository does not imply approval.

**PrettyUI** (mod.io ID `6398181`) must be installed. Development enable commands
do not download dependencies automatically.

## How to use

1. In the bank, right-click a preset name and choose **Customize preset**.
2. Enter a name and click the background/text swatches to choose colours. Use the
   colour canvas or enter `#RRGGBB`; changes preview immediately.
3. For numbered presets, click **Icon**, choose a category, and select an icon.
   Hover an icon to see its name. **Blank** hides the icon and number; **Use preset number** restores the default.
   Empty categories are hidden. The **Search** tab also offers item artwork. Item names
   are indexed in batches while the icon picker is open, so search results can be
   incomplete until indexing finishes. Progress is retained for the plugin session.
4. Optionally enter up to three letters or numbers in **Icon text**. Click **Save**,
   or press Enter in the name field, to apply your changes.

### Editor controls

- **Reset** previews all defaults; click **Save** to apply them. The **↺** controls
  reset individual colours or the icon. A crossed swatch means Default.
- A blank name uses the predefined name while keeping your colours and icon.
  Names cannot contain `<`, `>`, or control characters.
- Only one picker opens at a time. Closing it keeps staged changes; closing the
  editor or switching presets discards unsaved changes.
- Drag the title bar to move the editor; its position is remembered. Click **i**
  for help. **×** or closing the bank closes the editor.
- Saving requires your logged-in character's display name. Unknown or unavailable
  icons fall back to the preset number.

### Display settings

Plugin Hub settings and the ribbon panel offer:

- **Hide predefined-name dropdown** — hides the game's dropdown and expands the
  preset list without changing predefined names. Off by default.
- **Show background colours in small bank UI** — toggles compact-button backgrounds
  without changing saved colours, icons, or management rows. On by default.

Customisations can only be edited inside the bank. Display preferences persist across reloads.
Failed saves or customisation swaps attempt best-effort recovery and report failures;
native bank preset swaps are not undone.

## Permissions and privacy

**Data protection — Case 1 (local only).** No additional permissions, chat access,
network requests, screenshots, or gameplay-history collection.

This plugin requests no additional permissions.

Settings use the client's `PersistentDB` API. Your display name, preset names,
colours, icons, and icon text are stored locally per character. Display-name keys ignore case
and surrounding spaces. Editor position and display preferences are shared across
characters on this device. Nothing is sent to the developer or external services.

- Settings do not sync between devices; beta and live storage are separate.
- Saves under the previous plugin name are not automatically imported after the rename.
- After a character rename, re-enter or manually migrate settings. Reusing a display
  name on the same device can inherit its previous settings.
- Older device-wide and tracking-ID-based settings are not imported automatically.
- Settings have no automatic expiry. Reset clears a slot's customisation, not the
  character name in its storage keys.
- Disabling does not erase settings. There is no full-data deletion control for
  current or legacy keys; do not assume uninstalling clears the client database.
  The developer cannot access or delete these settings remotely.

## Local development

Follow Jagex's [getting-started guide](https://developer.runescape.com/rs/getting-started.html).
Place this repository, including subdirectories, in
`RuneScape-BETA/dev_plugins/custom-bank-presets/` and install PrettyUI.
Open the client console with **Alt + `**, then run:

```text
prf
pon custom-bank-presets
```

After Lua changes, run `prl custom-bank-presets`. After `plugin.json` changes,
run `prf` before reloading.

### Tests

Run the mocked regression suite with Lua 5.4:

```sh
lua tests/run.lua
```

Run specific suites by supplying their names, for example:

```sh
lua tests/run.lua name_editor editor_layout item_search
```

Editor fixtures live in `tests/fixtures/`; layout/scrolling checks are separate
from editing behaviour. Every suite can run independently. Keep boundary,
character-isolation, partial-write recovery, and native-UI restoration coverage
when changing implementation details.

Also test in-client: save/reset, all 18 presets and Beast of Burden, character
isolation, persistence, swaps, picker positioning, scrolling/resizing, and restoration
on disable. Check all icon categories on both compact pages, background visibility,
and unchanged preset loading, menus, hover text, and keyboard behaviour.
Mocked tests do not replace visual and interaction checks.

### Code overview

- `main.lua`: lifecycle and editor entry points.
- `bank/`: UI bindings, labels, colours, icons, and context menus.
- `editor/`: editor layout, preview, help, and PrettyUI integration.
- `editor/name_preview.lua`: native input alignment and clipped preview styling.
- `editor/views.lua`: settings/ribbon refresh and cleanup ownership.
- `presets/`: validation, per-character storage, and icon catalogue.
- `components/`: reusable colour and icon pickers.
- `tests/`: mocked regression suites; `plugin.json`: manifest and dependency.

Use slash-separated imports without `.lua`. PrettyUI is supplied through the
`prettyui` dependency global, not `require("prettyui")`. Slots are one-based;
native dropdown entry IDs are zero-based.

To add an icon category, add a module under `presets/icon_categories/` and register
it in `presets/icon_catalogue.lua`. Keep saved icon keys stable. The catalogue
supports native sprites and item artwork; the picker creates tabs and pagination.

Before submission, review and test the code and follow Jagex's
[plugin guidelines](https://developer.runescape.com/rs/submission/guidelines.html)
and [submission process](https://developer.runescape.com/rs/submission/process.html).

## Feedback and collaboration

Report issues or propose contributions through this repository's issue tracker,
or contact [vincent.rs.plugins@gmail.com](mailto:vincent.rs.plugins@gmail.com).
For bugs, include reproduction steps and your client version. Do not post personal
information in public reports.

## EULA

This Plugin uses software licensed by Jagex to the developer under the terms of the Jagex End User Licence Agreement (EULA) found at https://legal.jagex.com/docs/terms/eula (and all terms incorporated into it by reference). The development and any use of the Plugin is at all times subject to the Jagex EULA.
