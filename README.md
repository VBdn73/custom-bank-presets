# Custom bank presets

Give your RuneScape bank presets custom names, colours, icons, and icon text.
Version **0.8.1** changes appearance locally, not server-side names or bank actions.

This is a development version for the RuneScape plugin beta. Distribution requires
Jagex moderation approval; this repository does not imply approval.

## Features

- Names up to 40 Unicode characters and background/text colours for all 18 numbered
  presets and the Beast of Burden row.
- Icons from **Skills** (all 29), **Misc**, or item artwork through **Search**.
  Numbered presets also support up to three letters or numbers of icon text.
- Icons on preset-management rows and both compact bank pages, with optional
  compact-button background colours (on by default).
- A draggable editor with live previews, colour/hex controls, and resets.
- Per-character customisations that follow drag-and-drop preset swaps.
- An option to hide the bank's predefined-name dropdown (off by default).

No preset loading, automation, hidden information, or slot unlocking. Beast of
Burden keeps its native icon and is excluded from swaps. Disabling restores native
labels, colours, and numbers where available.

See [changelog.md](changelog.md) for release history.

## Requirements

Install **PrettyUI** (mod.io ID `6398181`). Development enable commands do not
download dependencies automatically.

## How to use

1. In the bank, right-click a preset name and choose **Customize preset**.
2. Enter a name and use the background/text swatches to choose colours, including
   hex values such as `#RRGGBB`.
3. For numbered presets, click **Icon** and select an icon or search for item artwork.
   **Blank** hides the icon and number; **Use preset number** restores the default.
   Optionally add up to three letters or numbers in **Icon text**.
4. Click **Save**, or press Enter in the name field, to apply changes.

### Controls and limitations

- **Reset** previews defaults; **Save** applies them. The **↺** controls reset
  individual colours or the icon. A crossed swatch means Default.
- A blank name uses the predefined name. Names cannot contain `<`, `>`, or control characters.
- Closing a picker keeps staged changes. Closing the editor or switching presets
  discards unsaved changes. Closing the bank also closes the editor.
- Drag the title bar to move the editor; its position is remembered. Click **i** for help.
- Item names are indexed in batches while the icon picker is open. Search results
  may be incomplete until indexing finishes; progress lasts for the plugin session.
- Saving requires your logged-in character's display name. Unknown or unavailable
  icons fall back to the preset number.
- Failed saves or customisation swaps attempt recovery and report failures.
  Native bank preset swaps are not undone.

Plugin Hub settings and the ribbon panel let you hide the predefined-name dropdown
or toggle compact-button background colours without changing saved customisations.
Customisations can only be edited inside the bank.

## Permissions

This plugin requests no additional permissions.

## Data protection

**Case 1 — local only.** The plugin uses your character's display name to keep
customisations separate. Your display name, preset names, colours, icons, and icon
text are stored locally through the client's `PersistentDB` API. Editor position
and display preferences are shared across characters on this device.

No chat access, network requests, screenshots, or gameplay-history collection.
Nothing is sent to the developer or external services.

- Settings do not sync between devices; beta and live storage are separate.
- Character keys ignore case and surrounding spaces. After a character rename,
  re-enter or manually migrate settings. Reusing a display name on the same device
  can inherit its previous settings.
- Settings from the previous plugin name, older device-wide storage, and
  tracking-ID-based storage are not imported automatically.
- Settings have no automatic expiry. Reset clears a slot's customisation, not the
  character name in its storage keys. Disabling does not erase settings.
- There is no full-data deletion control for current or legacy keys. Do not assume
  uninstalling clears the client database. The developer cannot access or delete
  these settings remotely.

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

### Testing

Run the mocked regression suite with Lua 5.4:

```sh
lua tests/run.lua
```

To run selected suites:

```sh
lua tests/run.lua name_editor editor_layout item_search
```

Also test in-client: save/reset, all presets and Beast of Burden, character
isolation, persistence, swaps, picker layout, both compact pages, display settings,
and restoration on disable. Confirm preset loading, menus, hover text, and keyboard
behaviour remain unchanged. Mocked tests do not replace in-client checks.

Before submission, personally review the code and follow Jagex's
[plugin guidelines](https://developer.runescape.com/rs/submission/guidelines.html)
and [submission process](https://developer.runescape.com/rs/submission/process.html).
The mod.io description must also include the contact email, feedback and
collaboration policy, permissions, data protection details, and EULA statement.

## Feedback and collaboration

Report bugs or propose contributions through this repository's issue tracker, or
email [vincent.rs.plugins@gmail.com](mailto:vincent.rs.plugins@gmail.com).
Include reproduction steps and your client version for bugs. Do not post personal
information in public reports.

## EULA

This Plugin uses software licensed by Jagex to the developer under the terms of the Jagex End User Licence Agreement (EULA) found at https://legal.jagex.com/docs/terms/eula (and all terms incorporated into it by reference). The development and any use of the Plugin is at all times subject to the Jagex EULA.
