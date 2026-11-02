# textpieces — upstream component inventory

Survey of `origin/main` (Vala + blueprint, Text Pieces by Gleb Smirnov) against
`lib/` on the `ruby` branch. Built with the `component-identification` skill:
every blueprint was read first (they *are* the widget tree), then the backing
`.vala` for the widgets, CSS classes, signals and actions the declarative files
cannot show.

Upstream is 11 Vala files, 10 blueprints, one GSettings schema, one GResource
manifest, two stylesheets, 36 bundled tool scripts and two gettext catalogues.
`lib/` on `ruby` currently holds **one** file of app code —
`lib/textpieces/application.rb`, a placeholder window with an
`Adw.StatusPage` saying the port is not written. **Every user-facing component
below is missing.**

## Scope note

`src/widgets/SearchBar.vala`, `src/widgets/SearchEntry.vala` and
`src/widgets/Editor.vala` all lean on **GtkSourceView 5** —
`GtkSource.View`, `GtkSource.Buffer`, `GtkSource.SearchContext`,
`GtkSource.SearchSettings`, `GtkSource.StyleScheme`,
`GtkSource.StyleSchemeManager` and `GtkSource.StyleSchemeChooserWidget`. There
is no GtkSourceView-free path to parity: the editor, the find/replace bar and
the whole Appearance preferences group are built on it. Confirm the typelib is
in the dev shell before the first unit.

---

## Component map

| # | Upstream | → port file | Kind | Exists |
|--:|---|---|---|---|
| 1 | `src/Application.vala` | `lib/textpieces/application.rb` | application | stub only |
| 2 | `src/widgets/Window.vala` + `resources/ui/Window.blp` | `lib/window.rb` | window | no |
| 3 | `resources/ui/Window.blp` (`menu app-menu`) | `lib/window.rb` | menu | no |
| 4 | `src/widgets/Window.vala` (`action_about`) | `lib/window.rb` | dialog | no |
| 5 | `src/widgets/Window.vala` (`action_save_as`, `action_load_file`) | `lib/window.rb` | dialog | no |
| 6 | `src/widgets/Window.vala` (`load_from`, `action_save_as` catch) | `lib/window.rb` | error state | no |
| 7 | `src/widgets/Editor.vala` + `resources/ui/Editor.blp` | `lib/editor.rb` | widget | no |
| 8 | `src/widgets/Search.vala` + `resources/ui/Search.blp` | `lib/search.rb` | page | no |
| 9 | `resources/ui/Search.blp` (placeholder stack page) | `lib/search.rb` | empty state | no |
| 10 | `src/tools/Tool.vala` (`build_list_row`) | `lib/tool_row.rb` | row | no |
| 11 | `src/widgets/SearchBar.vala` + `resources/ui/SearchBar.blp` | `lib/search_bar.rb` | widget | no |
| 12 | `src/widgets/SearchEntry.vala` + `resources/ui/SearchEntry.blp` | `lib/search_entry.rb` | widget | no |
| 13 | `src/widgets/preferences/Preferences.vala` + `resources/ui/Preferences.blp` | `lib/preferences.rb` | window | no |
| 14 | `resources/ui/Preferences.blp` (custom-tools empty page) | `lib/preferences.rb` | empty state | no |
| 15 | `src/widgets/preferences/Preferences.vala` (custom tools `bind_model`) | `lib/custom_tool_row.rb` | row | no |
| 16 | `src/widgets/preferences/Preferences.vala` (`action_select_font`) | `lib/preferences.rb` | dialog | no |
| 17 | `src/widgets/preferences/ToolSettings.vala` + `resources/ui/ToolSettings.blp` | `lib/tool_settings.rb` | widget | no |
| 18 | `src/widgets/preferences/ToolSettings.vala` (`argument_list` `bind_model`) | `lib/argument_row.rb` | row | no |
| 19 | `src/widgets/preferences/pages/CustomToolPage.vala` + `.blp` | `lib/custom_tool_page.rb` | page | no |
| 20 | `src/widgets/preferences/pages/NewToolPage.vala` + `.blp` | `lib/new_tool_page.rb` | page | no |
| 21 | `resources/ui/ShortcutsWindow.blp` | `lib/shortcuts_window.rb` | window | no |
| 22 | `src/Application.vala` (`ACTION_ACCELS`) | `lib/textpieces/application.rb` | shortcuts | no |
| 23 | `src/tools/Tool.vala` | `lib/tool.rb` | model | no |
| 24 | `src/tools/ToolsController.vala` | `lib/tools_controller.rb` | model | no |
| 25 | `src/utils/Recoloring.vala` | `lib/recoloring.rb` | style | no |
| 26 | `src/utils/Utils.vala` | `lib/utils.rb` | util | no |
| 27 | `data/com.github.liferooter.textpieces.gschema.xml` | `lib/settings.rb` | settings | no |
| 28 | `resources/style.css` | `lib/style.rb` | stylesheet | no |
| 29 | `data/tools.json` + `scripts/*` | `data/tools.json`, `scripts/` | data | no |
| 30 | `po/textpieces.pot`, `po/tools.pot`, `po/{es,nl,pt_BR}.po` | `po/` | translations | no |

---

## 1. `src/Application.vala` — the application: actions, accels, style scheme

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Application` | 1 | — | `startup`, `activate`, `open`, `shutdown` | id `com.github.liferooter.textpieces`, flags `FLAGS_NONE | HANDLES_OPEN` |
| `Gtk.CssProvider` | 1 | — | — | not a widget; holds generated style-scheme CSS, added at `PRIORITY_USER` for the display |

App actions: `app.quit`, `app.new-window`.

Accelerators (`ACTION_ACCELS`), the full list:

| Action | Accel |
|---|---|
| `win.apply` | `<Ctrl>Return` |
| `win.copy` | `<Ctrl><Shift>c` |
| `win.open-preferences` | `<Ctrl>comma` |
| `win.load-file` | `<Ctrl>o` |
| `win.save-as` | `<Ctrl>s` |
| `win.toggle-search` | `<Alt>s` |
| `win.jump-to-args` | `<Ctrl>e` |
| `window.close` | `<Ctrl>w` |
| `app.quit` | `<Ctrl>q` |
| `app.new-window` | `<Ctrl>n` |

Behaviour: `activate` → one new window; `open` → one window per file, each
`load_from`'d; `shutdown` → saves the active window's geometry (following
`transient_for` if a dialog is focused). Holds the static `settings` and
`tools` singletons, and the `style-scheme` property whose setter forces
`Adw.ColorScheme.FORCE_DARK`/`FORCE_LIGHT`, reloads the recoloring CSS and
writes `style-scheme` back to GSettings.

Port note: the house style uses `Gtk::Application`, not `Adwaita::Application`
(the binding is broken) — `lib/textpieces/application.rb` already does this.

## 2. `src/widgets/Window.vala` + `resources/ui/Window.blp` — the main window

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | — | `close_request` → `save_window_size` | `focus-widget: editor`; geometry restored from settings |
| `Gtk.Box` | 2 | — / `linked` | — | vertical root; the linked Apply/Copy pair |
| `Adw.HeaderBar` | 1 | — | — | `headerbar` |
| `Gtk.Revealer` | 1 | — | — | crossfade; `reveal-child` bound to `search_bar.search-mode-enabled` **inverted** |
| `Gtk.Button` | 4 | 2× `suggested-action` | `win.apply`, `win.copy`, `win.save-as`, `win.load-file` | labels `_Apply`; icons `edit-copy-symbolic`, `document-save-symbolic`, `document-open-symbolic`; tooltips Apply Selected Tool / Copy / Save to File / Load from File |
| `Gtk.ToggleButton` | 1 | `flat`, `heading` | `toggled` → `on_search_toggled` | `tool_button`, the window title |
| `Adw.ButtonContent` | 1 | — | — | `tool_button_content`; label/icon follow the selected tool, else "Select tool" / `applications-utilities-symbolic` |
| `Gtk.MenuButton` | 1 | — | `menu-model: app-menu` | `open-menu-symbolic`, primary, tooltip Main Menu |
| `Gtk.SearchBar` | 1 | — | `search-mode-enabled` ↔ `tool_button.active` **bidirectional** | `search_bar` |
| `TextPieces.SearchEntry` | 1 | — | — | hosted in the search bar, handed to `Search` |
| `Gtk.Stack` | 1 | — | — | `content_stack`, crossfade, pages `editor` / `search` |
| `TextPieces.Editor` | 1 | — | — | `vexpand` |
| `TextPieces.Search` | 1 | — | `tool-selected` → `on_tool_selected` | `search-entry: search_entry` |

Window actions (`ACTION_ENTRIES`), all ten: `win.apply`,
`win.open-preferences`, `win.about`, `win.copy`, `win.tools-settings`,
`win.toggle-search`, `win.save-as`, `win.load-file`, `win.jump-to-args`,
`win.find`. Plus the GTK-provided `win.show-help-overlay` and `window.close`.

`selected_tool` is the window's state: persisted to the `selected-tool`
GSettings key by script name, restored at construct (and reset with a log
message if the script is gone), cleared when `ToolsController::delete_tool`
fires for it, and on every change it updates the button content, enables or
disables `win.apply`, pushes the tool's translated arguments into the editor
and re-runs `editor.update_editor_margin` on idle.

`action_apply` runs the tool over the editor's selection (or the whole buffer),
toasts stderr, replaces the selection with stdout.

Conditional: Apply/Copy are revealed only when the tool search is closed.

## 3. `resources/ui/Window.blp` — the primary menu (`menu app-menu`)

Three sections, six items:

| Section | Label | Action |
|---|---|---|
| 1 | `_New Window` | `app.new-window` |
| 2 | `_Find/Replace…` | `win.find` |
| 3 | `_Preferences` | `win.open-preferences` |
| 3 | `_Keyboard Shortcuts` | `win.show-help-overlay` |
| 3 | `_About Text Pieces` | `win.about` |

All `use-underline`. No `custom:` slots.

## 4. `src/widgets/Window.vala` (`action_about`) — the About dialog

`Adw.AboutWindow`, built in code: icon `com.github.liferooter.textpieces`,
name "Text Pieces", comments "Transform text without using random websites",
version from `Config.VERSION`, licence `GPL_3_0`, website
`https://github.com/liferooter/textpieces`, issue URL `.../issues/new`,
artists "Tobias Bernard https://tobiasbernard.com", developers
"Gleb Smirnov <glebsmirnov0708@gmail.com>", developer name "Gleb Smirnov",
`translator_credits` from the catalogue. Transient for the window.

## 5. `src/widgets/Window.vala` — the file chooser dialogs

Two `Gtk.FileChooserNative`s, modal and transient: `SAVE` titled "Save to File"
(`win.save-as`) and `OPEN` titled "Load from File" (`win.load-file`). Both
no-op on a null file.

## 6. `src/widgets/Window.vala` — the file error dialog

`Gtk.MessageDialog`, `MODAL | DESTROY_WITH_PARENT`, `WARNING`, `CLOSE`,
destroyed on response. Two messages: `Can't load from file: %s` and
`Can't save to file: %s`.

## 7. `src/widgets/Editor.vala` + `resources/ui/Editor.blp` — the editor

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Bin` | 1 | — | `grab_focus` override → the source view | the template root |
| `Adw.ToastOverlay` | 1 | — | — | `message_overlay`; `show_message` adds an `Adw.Toast`, priority HIGH, timeout 2 s |
| `Gtk.Overlay` | 1 | — | — | source view below, controls above |
| `Gtk.ScrolledWindow` | 1 | — | — | |
| `GtkSource.View` | 1 | `monospace` (via the property) | drop target | monospace, auto-indent, line numbers, smart backspace, smart home/end `before`, top margin 6 |
| `Gtk.Box` | 2 | — / `linked`, `editor-overlay` | — | overlay column (valign start, halign end); `arguments_box`, width 300, vertical, spacing 3 |
| `TextPieces.SearchBar` | 1 | — | — | `editor: "editor"` |
| `Gtk.Entry` | *n* | `monospace` | `activate` → `move_focus(TAB_FORWARD)` | **repeater**: one per argument of the selected tool, `placeholder-text` = translated argument name. `arguments_box.visible` only when *n* > 0 |
| `Gtk.DropTarget` | 1 | — | `on_drop` | controller on the source view; drops a `File` and loads its contents |
| `Gtk.CssProvider` | 1 | — | — | not a widget; `.monospace { font-family: … }` from the `font-name` setting |

Settings bound (GET): `tabs-to-spaces` → `insert-spaces-instead-of-tabs`,
`spaces-in-tab` → `tab-width`, `font-name` → `editor-font`, `wrap-lines` →
`wrap-lines` (`WORD_CHAR` / `NONE`). Buffer `style-scheme` is bound
`SYNC_CREATE` to the application's.

Public API the window calls: `get_selection`, `replace_selection`, `copy_text`
(clipboard + "Text is copied" toast), `set_arguments`, `get_arguments`,
`jump_to_args`, `save_as`, `load_from`, `show_message`,
`update_editor_margin` (top margin = the arguments box's measured height, else
6, with the scroll position corrected).

## 8. `src/widgets/Search.vala` + `resources/ui/Search.blp` — the tool search

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Bin` | 1 | — | emits `tool-selected` | template root |
| `Gtk.Stack` | 1 | — | — | `search_stack`, crossfade, pages `search` / `placeholder` |
| `Gtk.ScrolledWindow` | 1 | — | — | |
| `Gtk.Viewport` | 1 | — | — | `results_viewport`, `scroll-to-focus`; `reset` zeroes its vadjustment |
| `Adw.Clamp` | 1 | — | — | max 600 |
| `Gtk.ListBox` | 1 | `boxed-list` | `row-activated` → `on_row_activated` | `results_listbox`, selection mode `browse`, margins 24, `bind_model(results_model, build_list_row)` |
| `Gtk.EventControllerKey` | 1 | — | `key-pressed` → `on_search_entry_key` | on the search entry; Up/Down forwarded to the list box, focus handed back |

Models (not widgets): `CustomSorter` + `CustomFilter` over
`Application.tools.all_tools`, wrapped `FilterListModel` → `SortListModel`.
Ranking is the `calculate_irrelevance` term-matching algorithm over the tool's
name and description, translated and untranslated, ties broken by name;
infinite irrelevance filters the tool out. The search entry's `changed`
invalidates both and re-picks the stack page; `activate` activates the selected
row (or row 0).

## 9. `resources/ui/Search.blp` — the "No Tools Found" empty state

`Adw.StatusPage`, icon `applications-utilities-symbolic`, title "No Tools
Found", holding a `flat` `Gtk.Button` (halign center, action
`win.tools-settings`) whose `Adw.ButtonContent` is `list-add-symbolic` /
"_Add Custom Tool". Shown when the filtered model is empty.

## 10. `src/tools/Tool.vala` (`build_list_row`) — a tool row

`Adw.ActionRow`, activatable, `title` = translated name, `subtitle` =
translated description, `icon-name` = the tool's icon (default
`applications-utilities-symbolic`). **Repeater**, one per matching tool.

## 11. `src/widgets/SearchBar.vala` + `resources/ui/SearchBar.blp` — find/replace

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Bin` | 1 | — | — | template root; installs the `search` action group |
| `Gtk.Revealer` | 1 | — | `child-revealed` → `search_context.highlight` | `search_revealer`, slide-down |
| `Gtk.Grid` | 1 | `editor-overlay` | — | 3 rows, row/column spacing 6 |
| `TextPieces.SearchEntry` | 1 | — | `query` → `search_settings.search-text` | row 0 col 0 |
| `Gtk.Box` | 2 | `linked` / — | — | prev/next pair (homogeneous); the options row |
| `Gtk.Button` | 6 | 2× plain, `flat`+`circular`, 2× plain | `search.prev-match`, `search.next-match`, `search.hide`, `search.replace`, `search.replace-all` | `go-up-symbolic` "Move to previous match", `go-down-symbolic` "Move to next match", `window-close-symbolic` "Close search", `_Replace`, `Replace _All` |
| `Gtk.ToggleButton` | 2 | — | — | `search_replace` (`edit-find-replace-symbolic`, "Find and replace"), `search_options` (`preferences-symbolic`, "Toggle search options") |
| `Gtk.Entry` | 1 | `error` (added on a failed replace, removed by `changed` → `remove_error_style`) | `changed` | `replace_entry`, primary icon `edit-find-replace-symbolic` non-activatable, placeholder "Replace" |
| `Gtk.CheckButton` | 3 | — | `active` ↔ `use-regex` / `case-sensitive` / `whole-words`, bidirectional | "Re_gular expressions", "_Case sensitive", "Match whole _word only" |
| `Gtk.ShortcutController` | 2 | — | — | managed scope: `<Ctrl>f` → `search.show`, `<Ctrl>h` → `search.show-replace`; inside the revealer, `Escape` → `search.hide` |

`search` action group, seven actions: `hide`, `show`, `show-replace`,
`next-match`, `prev-match`, `replace`, `replace-all`. Backed by
`GtkSource.SearchSettings` (`wrap_around`) and `GtkSource.SearchContext`;
next/prev are async `forward_async`/`backward_async` against a `Cancellable`
that `hide` cancels and `show` resets, then `scroll_mark_onscreen`.
A failed replace adds `error` to the replace entry and rings `error_bell`.

Conditional: the replace entry and both replace buttons are visible only with
`search_replace.active`; the options box only with `search_options.active`.
`_Replace` is sensitive on `occurrence_position`, `Replace _All` on
`occurrences_count`.

## 12. `src/widgets/SearchEntry.vala` + `resources/ui/SearchEntry.blp` — search entry

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.Widget` subclass | 1 | css **name** `entry` | — | `BoxLayout` layout manager, accessible role `TEXT_BOX`, width-request 300, `grab_focus` forwards to the text |
| `Gtk.Image` | 1 | — | — | `edit-find-symbolic` |
| `Gtk.Text` | 1 | — | `text` → `query`; `changed` | placeholder "Find", hexpand/vexpand, 12 width-chars |
| `Gtk.Label` | 1 | opacity 0.3, xalign 1 | `label` bound to `occurrences_info` | `"%u of %d"`, blank when there are no occurrences |
| `Gtk.ShortcutController` | 1 | — | — | local scope on the text: `Return` → `search.next-match`, `<Shift>Return` → `search.prev-match` |

Properties `query`, `occurrences_info`, `occurrences_count`,
`occurrence_position`; `set_context` binds the count from the
`GtkSource.SearchContext` and recomputes the position from the selection on
buffer change, cursor move, text change and context notify.

Port note: this is a `Gtk.Widget` subclass with a custom CSS name and layout
manager. Composing an `Adw.Bin`/`Gtk.Box` with the `entry` style class is the
pragmatic Ruby equivalent — check the `ruby-gtk` skill before subclassing.

## 13. `src/widgets/preferences/Preferences.vala` + `resources/ui/Preferences.blp`

`Adw.PreferencesWindow`, modal, `can-navigate-back`. Two pages.

**Page `general-settings`** — "_General", icon `preferences-symbolic`:

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesGroup` | 2 | — | — | "Editor", "Appearance" |
| `Adw.ActionRow` | 4 | — | row 1 activatable → `prefs.select-font` | "Editor _Font", "_Wrap Lines", "Tabs to _Spaces", "_Tab Width in Spaces" |
| `Gtk.Box` + `Gtk.Label` + `Gtk.Image` | 1 each | — | — | font row suffix: `font_label` (bound to `font-name`) and `go-next-symbolic` |
| `Gtk.Switch` | 2 | — | `settings.wrap-lines`, `settings.tabs-to-spaces` | valign center |
| `Gtk.SpinButton` | 1 | — | `value` ↔ `spaces-in-tab` | adjustment 1–21 step 1, climb rate 1 |
| `Adw.Clamp` | 1 | — | — | max 450 |
| `GtkSource.StyleSchemeChooserWidget` | 1 | — | `style-scheme` ↔ app's, `SYNC_CREATE | BIDIRECTIONAL` | `style_scheme_chooser` |

**Page `custom-tools`** — "T_ools", icon `applications-utilities-symbolic`:

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesGroup` | 1 | — | — | "Custom tools" |
| `Gtk.Button` (header-suffix) | 1 | `flat` | `clicked` → `add_new_tool` | `Adw.ButtonContent` `list-add-symbolic` / "_Add custom tool" |
| `Gtk.ListBox` | 1 | `boxed-list` | `row-activated` → `edit_tool` | `custom_tools_listbox`, selection none, `bind_model(custom_tools)`; hidden when there are none |

Action groups: `prefs` (`select-font`) and `settings`, built from
`Settings.create_action` for `wrap-lines` and `tabs-to-spaces`.
`add_new_tool` → `present_subpage(NewToolPage)`; `edit_tool` →
`present_subpage(CustomToolPage(tool))`. The window is opened by
`win.open-preferences`, and by `win.tools-settings` with
`visible_page_name = "custom-tools"`.

## 14. `resources/ui/Preferences.blp` — the "No Custom Tools" empty state

`Adw.StatusPage`, icon `applications-utilities-symbolic`, title "No Custom
Tools", description "You can create one", vexpand, valign center, visible when
`custom_tools_listbox.visible` is **inverted**.

## 15. `src/widgets/preferences/Preferences.vala` — a custom tool row

`Adw.ActionRow`, activatable, title/subtitle from the tool's translated name
and description, suffix `Gtk.Image` `go-next-symbolic`. **Repeater** over
`custom_tools`.

## 16. `src/widgets/preferences/Preferences.vala` (`action_select_font`) — font chooser

`Gtk.FontChooserDialog` titled "Select font", modal, transient, level `FAMILY`,
seeded from `font-name`; on `OK` writes the family back to `font-name`.

## 17. `src/widgets/preferences/ToolSettings.vala` + `resources/ui/ToolSettings.blp`

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Bin` | 1 | — | — | template root; `is_valid`, `can_edit_script` properties |
| `Gtk.ScrolledWindow` + `Gtk.Viewport` | 1 each | — | — | `scroll-to-focus` |
| `Adw.Clamp` | 1 | — | — | max 400 |
| `Gtk.Box` | 1 | — | — | vertical, margins 20, spacing 20 |
| `Gtk.ListBox` | 3 | `boxed-list` | `edit_script_list` visible only with `can_edit_script`; `argument_list` visible only when there are arguments | fields list, edit-script list, `argument_list` |
| `Adw.ActionRow` | 4 | `error` on `name_entry` when the name is blank | row 4 `activated` → `edit_script` | "_Name", "_Description", "_Arguments", "Edit _Script" (activatable, suffix `document-edit-symbolic`) |
| `Gtk.Entry` | 2 | — | `name_entry` `activate` → focus the description entry | `name_entry` ↔ `tool.name` (bidirectional, rejects blank), `description_entry` ↔ `tool.description` |
| `Gtk.SpinButton` | 1 | — | `value_changed` grows/shrinks the argument model | `arguments_number`, adjustment 0–100 step 1 |
| `Gtk.Image` | 1 | — | — | `document-edit-symbolic` |

`is_valid` is "name is not empty", bound `SYNC_CREATE` from the name entry —
it is what reveals NewToolPage's Create button. `edit_script` opens the script
through `Xdp.Portal.open_uri` (`ASK | WRITABLE`).

## 18. `src/widgets/preferences/ToolSettings.vala` — an argument row

`Adw.ActionRow` titled `Argument %d` (1-based), `activatable_widget` = a
valign-center `Gtk.Entry` added as its suffix, entry text ↔ the argument's
name bidirectionally. **Repeater** over the private `Argument` list store;
`items_changed` rewrites `tool.arguments` and re-indexes.

## 19. `src/widgets/preferences/pages/CustomToolPage.vala` + `.blp` — edit a tool

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.Box` | 1 | — | `unmap` → commit the tools index, toast on failure | template root, vertical |
| `Adw.HeaderBar` | 1 | — | — | no start/end title buttons |
| `Gtk.Button` | 2 | — / `destructive-action` | `clicked` → `go_back`; `clicked` → `delete_tool` **then** `go_back` | `go-previous-symbolic`; "D_elete" |
| `Gtk.Label` | 1 | `heading` | — | "Edit Tool" |
| `TextPieces.ToolSettings` | 1 | — | — | `can-edit-script: true` |

## 20. `src/widgets/preferences/pages/NewToolPage.vala` + `.blp` — create a tool

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.Box` | 1 | — | — | template root, vertical |
| `Adw.HeaderBar` | 1 | — | — | no start/end title buttons |
| `Gtk.Button` | 2 | — / `suggested-action` | `clicked` → `go_back`; `clicked` → `create` **then** `go_back` | `go-previous-symbolic`; "_Create" |
| `Gtk.Label` | 1 | `heading` | — | "New Tool" |
| `Gtk.Revealer` | 1 | — | `reveal-child` bound to `tool_settings.is_valid` | crossfade; hides Create until the name is non-empty |
| `TextPieces.ToolSettings` | 1 | — | — | `can-edit-script` left false |

`create` ensures `~/.local/share/textpieces/scripts`, generates
`name-<8 hex>` via a SHA256 salt, copies `scripts/template` in, chmods 0750,
appends the tool, commits, and opens the script in the user's editor. Commit
failures land as an `Adw.Toast` on the preferences window.

## 21. `resources/ui/ShortcutsWindow.blp` — the shortcuts window

`Gtk.ShortcutsWindow` (`gtk/help-overlay.ui`), one section, max height 12, five
groups and 16 items:

| Group | Items |
|---|---|
| General | New window, Keyboard shortcuts, Preferences, Close window, Quit |
| Tools | Apply, Select tool, "Just to the tool options" (sic — upstream typo) |
| Undo and Redo | Undo `<ctrl>z`, Redo `<ctrl><shift>z` |
| Files | Load from file, Save to file |
| Search and Replace | Search `<ctrl>f`, Replace `<ctrl>h`, Move to previous match `<Shift>Return`, Move to next match `Return` |

Most items name an action and take the accel from the application's
`ACTION_ACCELS`; the Undo/Redo and Search groups give accelerators literally.
`Gtk.ShortcutsWindow` is deprecated in GTK 4.18 — the port should use
`Adw.ShortcutsDialog` (see the pilot's `lib/shortcuts_dialog.rb`) and keep the
same groups and items.

## 22–28. Non-widget units parity needs

- **`lib/settings.rb`** — the nine GSettings keys with upstream's defaults:
  `style-scheme` `'Adwaita-dark'`, `font-name` `'Monospace'`, `wrap-lines`
  `true`, `tabs-to-spaces` `false`, `spaces-in-tab` `4`, `window-width` `800`,
  `window-height` `500`, `is-maximized` `false`, `selected-tool` `''`.
  The pilot backs these with a JSON file under `XDG_CONFIG_HOME` rather than an
  installed schema; do the same here.
- **`lib/tool.rb`** — the tool model: name/description/arguments translated
  through the `tools` gettext context, icon, script, `is_system`; `apply`
  (spawn the script, pipe the text through stdin, capture stdout/stderr,
  `flatpak-spawn --host` for custom tools in Flatpak), `open` via the file
  portal, `generate_filename`.
- **`lib/tools_controller.rb`** — `system_tools` / `custom_tools` /
  `all_tools` list stores, JSON load and save of `tools.json`
  (`~/.config/textpieces/tools.json` for custom), `commit` (save, refresh,
  delete removed scripts), `add_tool` / `delete_tool` signals.
- **`lib/recoloring.rb`** — turns a GtkSourceView style scheme into
  app-wide `@define-color` CSS: `is_scheme_dark` (metadata `variant`, the
  `-dark` suffix, then the HSP brightness test), `generate_css` with the
  shared/light/dark suffixes, Adwaita schemes skipped.
- **`lib/utils.rb`** — `ensure_directory_exists`.
- **`lib/style.rb`** — `resources/style.css` is one rule, `.editor-overlay`
  (padding 6, `lighter(@window_bg_color)`, radius 9, three-layer box shadow).
  `style-dark.css` is a licence header only — no rules. The `monospace` class
  is GTK's own; `linked`, `boxed-list`, `flat`, `circular`, `heading`,
  `suggested-action`, `destructive-action` and `error` are Adwaita's.
- **`data/tools.json` + `scripts/`** — 36 system tools, 8 of them taking
  arguments (Filter/Reverse-Filter Lines by Regex and by Substring, Remove
  Regex/Substring, Replace Substring/Regex), plus `scripts/template` for new
  tools. Icons used: `fingerprint-symbolic`, `lock-symbolic`,
  `unlock-symbolic`, `edit-cut-symbolic`, `rss-symbolic`, `funnel-symbolic`,
  `applications-utilities-symbolic`, `preferences-symbolic` — the last seven of
  which upstream **bundles** in `resources/icons/scalable/status/`, because
  they are not in the system icon theme. The port needs those SVGs on its icon
  search path.
- **`po/`** — two catalogues: `po/textpieces.pot` for the UI and
  `po/tools.pot` for the tool names, descriptions and argument names (looked up
  with `dpgettext2(null, "tools", …)`). Three languages: `es`, `nl`, `pt_BR`.
  `po/POTFILES` lists 6 Vala files and all 10 blueprints.

---

## Suggested port order

1. `lib/settings.rb`, `lib/utils.rb`, `lib/tool.rb`, `lib/tools_controller.rb`
   plus `data/tools.json` and `scripts/` — nothing on screen works without the
   tool model.
2. `lib/editor.rb` and `lib/style.rb` — the editor is the app.
3. `lib/window.rb` with its menu, the About dialog, the file choosers and the
   error dialog, and the accelerators in `lib/textpieces/application.rb`.
4. `lib/tool_row.rb` + `lib/search.rb` — tool selection, with the irrelevance
   ranking and the empty state.
5. `lib/search_entry.rb` + `lib/search_bar.rb` — find/replace.
6. `lib/settings.rb`-driven `lib/preferences.rb`, `lib/custom_tool_row.rb`,
   `lib/tool_settings.rb`, `lib/argument_row.rb`, `lib/custom_tool_page.rb`,
   `lib/new_tool_page.rb`.
7. `lib/shortcuts_window.rb`, `lib/recoloring.rb`, `po/`.
