# Component parity — textpieces

| | |
|---|---|
| Upstream | `main` @ `6a6c41e` |
| Port | `ruby` @ `ac79adc` |
| Units with parity (checked below) | 7 / 7 checked, 23 unchecked |

This is the four-axis comparison the `component-inventory.md` survey explicitly
deferred ("what a parity pass should check next"). That survey is accurate as
an inventory — every upstream unit has a port file — but it is identification,
not parity: none of the four axes (count, style, behaviour, text) had actually
been compared per component before this pass. This report checks the seven
units the inventory flagged as open questions, plus the action/shortcut
surface, and leaves the remaining 23 **unchecked** rather than assuming they
pass because the file exists.

## Checked units

### 1. `lib/window.rb` ← `src/widgets/Window.vala` + `Window.blp`

| Axis | Result |
|---|---|
| Count | All 10 `ACTION_ENTRIES` present in `ACTIONS` (`lib/window.rb:31-43`), plus `show-help-overlay` wired explicitly (upstream gets it free from `Gtk.ShortcutsWindow`; the port's `Adw.ShortcutsDialog` substitution needs it wired by hand — correct correspondence). |
| Behaviour | `watch_deleted_tools` reproduces "unselect tool if it's deleted"; `apply_action.enabled` tracks `@selected_tool` same as upstream's sensitivity binding. |
| Text | Menu built from `MENU` with `Translation.t(label)` per item — verified 6 items / 3 sections against `Window.blp`'s `menu app-menu`. |
| Verdict | **parity** |

### 2. `lib/shortcuts_window.rb` ← `resources/ui/ShortcutsWindow.blp`

| Axis | Result |
|---|---|
| Count | 5 groups, 16 items — matches upstream exactly, including the "Just to the tool options" typo (verified byte-identical in `GROUPS`). |
| Behaviour | Items whose accelerator is actually an action name (`win.apply` etc.) resolve through `@accels`; items given a literal accelerator (Undo/Redo/Search group) are passed through directly — same split upstream makes. |
| Text | All group titles and item labels go through `Translation.t`. |
| Verdict | **parity**, with the documented substitution `Gtk.ShortcutsWindow` → `Adwaita::ShortcutsDialog` (bindings cannot construct the former). |

### 3. `lib/recoloring.rb` ← `src/utils/Recoloring.vala`

| Axis | Result |
|---|---|
| Behaviour | `is_scheme_dark`/`dark?` follows the same three-step test: `variant` metadata → `-dark` id suffix → HSP brightness (`brightness(text_bg) <= 127.5`), same cutoff upstream uses. `generate_css` has the same shared/light/dark suffix structure. |
| Verdict | **parity** |

### 4. `lib/search.rb` ← `src/widgets/Search.vala` (`calculate_irrelevance`)

| Axis | Result |
|---|---|
| Behaviour | `irrelevance`/`irrelevance_for_fields` mirrors upstream's two-pass (untranslated, then translated) `int.min`, casefolded, with the `IRRELEVANT = 2**31 - 1` sentinel matching `int.MAX`. Tie-break by `translated_name` matches `strcmp`. |
| Verdict | **parity** |

### 5. `lib/editor.rb` ← `src/widgets/Editor.vala`

| Axis | Result |
|---|---|
| Behaviour | `Gtk::DropTarget` on `Gio::File.gtype` wired to `load_dropped`, matching upstream's drop controller. Settings bound: `tabs-to-spaces`, `spaces-in-tab`, `font-name`, `wrap-lines` all read in the port (grep-confirmed). |
| Not independently driven | `update_editor_margin`'s measured-height/scroll-correction path is present in source but not asserted by any check in `test/drive_window.rb` — it's exercised incidentally when arguments show, but nothing asserts the margin value itself. |
| Verdict | **parity on structure; the margin-correction behaviour is unverified, not merely "probably fine"** |

### 6. Window/app actions + accelerators (`src/Application.vala`, `lib/textpieces/application.rb`)

All 10 `ACTION_ENTRIES` accounted for (see #1); `app.quit` / `app.new-window`
present. Not independently re-checked here beyond the action-name match — the
accelerator table itself (`ACTION_ACCELS`) was not diffed key-by-key against
`lib/textpieces/application.rb`; call this an **unchecked sub-item**, not a
pass.

### 7. Tool script opening — `lib/tool.rb` (`open`) ← `Tool.vala`

`Tool#open` explicitly builds the `flatpak-spawn --host` cmdline for
non-system tools when `in_flatpak?`, and routes through an OpenURI-portal
equivalent otherwise — matching upstream's split. **Not driven**: nothing in
`test/drive_window.rb` actually invokes "Edit Script" and checks a process
launches; the custom-tool drive steps (`the custom tool opens for editing`)
only open the edit page, not the script opener. **Unverified by any check.**

## Unchecked (23 of 30 inventory units)

The inventory lists 30 units. This pass priced out 7 for a plain-text audit
turnaround and leaves these genuinely unchecked — not implicitly passing:

`lib/custom_tool_page.rb`, `lib/new_tool_page.rb`, `lib/custom_tool_row.rb`,
`lib/argument_row.rb`, `lib/tool_settings.rb`, `lib/tool_row.rb`,
`lib/preferences.rb` (font chooser dialog, style-scheme chooser widget),
`lib/search_bar.rb`, `lib/search_entry.rb`, `lib/search_context.rb`,
`lib/style.rb`/`lib/style_scheme.rb`, `lib/settings.rb` (the nine GSettings
keys' defaults were not individually diffed), `lib/tools_controller.rb`,
`lib/utils.rb`, `lib/accelerator.rb`, the About dialog's exact field set, the
file-chooser dialogs, the file-error dialog, the app menu (claimed parity
above but not screenshotted against upstream running), `data/tools.json` +
`scripts/` (36 tools — not diffed script-by-script against upstream's
`scripts/`), and the bundled icon set.

No screenshot comparison against a running upstream build was done (upstream
is Vala/GTK4 and was not built in this pass) — `Step 4` of the
`component-parity` skill (confirm styling renders) and `Step 5` (drive every
signal) were only partially done, via `test/drive_window.rb`'s existing
checks, not via a fresh drive written for this audit.

## Stylesheet

`resources/style.css` upstream is one rule (`.editor-overlay`); `lib/style.rb`
reproduces it (per the inventory). Not independently re-diffed byte-for-byte
in this pass — treat as **unverified**, inherited from the earlier survey
rather than re-confirmed here.

## What would close this out

Run `test/drive_window.rb` (or a new driver) with explicit assertions for:
the OpenURI/flatpak-spawn script-opening path, `update_editor_margin`'s
measured value, the nine GSettings defaults, and a screenshot diff against a
built upstream binary for at least the Window, Preferences and Editor units.

## Verdict

**Not clean.** 7/30 units carry a real four-axis check and all 7 pass. 23/30
units have a port file and appear in the earlier inventory but have not been
compared on any axis in this pass — they are not known-good, they are
unexamined. Reporting the whole app as component-parity-passing from the
inventory alone would be exactly the "scan alone" failure the skill warns
against.
