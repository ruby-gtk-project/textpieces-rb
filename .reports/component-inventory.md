# textpieces-rb component inventory

Upstream: `origin/main` (Vala, `src/` + `resources/ui/*.blp`). Port: `ruby`
branch, `lib/`. One unit per upstream template/class, in the order a user
meets them.

## Binding-gem defect found during this survey

**`lib/` hand-rolls GtkSourceView instead of using the `gtksourceview5` gem
that already exists on RubyGems**, and this is not a side detail — it is the
reason `lib/editor.rb`, `lib/search_bar.rb`, `lib/search_entry.rb`,
`lib/recoloring.rb`, `lib/style_scheme.rb` and part of `lib/preferences.rb`
exist as hand-written code at all:

- `lib/editor.rb`'s header comment states: *"Upstream's view is a
  GtkSource.View, which has no Ruby bindings; this one is a Gtk::TextView."*
  That claim is false — `gtksourceview5` (and `gtksourceview4`/`3`) are
  published gems built by the ruby-gnome project providing `GtkSource::View`,
  `GtkSource::Buffer`, `GtkSource::SearchContext`, `GtkSource::SearchSettings`,
  `GtkSource::StyleSchemeManager` and `GtkSource::StyleSchemeChooserWidget` —
  exactly the classes upstream's `Editor.vala`, `SearchBar.vala`,
  `SearchEntry.vala`, `Recoloring.vala` and `Preferences.vala` use.
- `lib/style_scheme.rb`'s header repeats the same claim ("GtkSourceView has no
  Ruby bindings") to justify shipping four hand-authored JSON files under
  `data/style-schemes/` in place of `GtkSource::StyleSchemeManager`, and
  `lib/recoloring.rb` reimplements `src/utils/Recoloring.vala`'s colour
  extraction against that JSON instead of against a real
  `GtkSource::StyleScheme`.
- The gemspec has no `gtksourceview*` dependency, and `flake.nix`'s
  `gtkStack` (the list that feeds both `buildInputs` and `typelibPath`) has no
  GtkSourceView/`libgtksourceview` entry either, so the typelib is not even
  wired up to try it.
- Net effect: the editor is a plain `Gtk::TextView` with no syntax
  highlighting, no `GtkSource.SearchContext` incremental search/replace, and
  the style-scheme picker in Preferences is not the real
  `GtkSourceStyleSchemeChooserWidget` upstream uses — all because a gem that
  exists was never tried.

This is not this step's job to fix (no app code is written here), but it must
be wired in — gemspec dependency, `nix/Gemfile`, regenerated lockfile,
`gtkStack`/`typelibPath` entry for the GtkSourceView typelib, proven with
`ruby -e 'require "gtksourceview5"; puts GtkSource.constants.size'` — before
`lib/editor.rb`, `lib/search_bar.rb`, `lib/search_entry.rb`,
`lib/recoloring.rb` and `lib/style_scheme.rb` are rewritten against it, per the
earlier instruction to delete hand-rolled code once a real gem is proven.

Also missing on the port side entirely: upstream's
`data/com.github.liferooter.textpieces.gschema.xml` has no equivalent GSettings
schema file in the port (`lib/settings.rb` stores the same keys in a JSON file
under `XDG_CONFIG_HOME` instead — that substitution is explained and may be
legitimate given GSettings needs a system schema install step, but it means
the port never proves it reads/writes the same keys the same way).

## Components

| # | Upstream file(s) | → `lib/*.rb` | Kind | Exists? |
|---|---|---|---|---|
| 1 | `src/Application.vala` | `lib/textpieces/application.rb` | application class (actions, accelerators, About, new-window) | Yes (176 lines) |
| 2 | `src/widgets/Window.vala` + `resources/ui/Window.blp` | `lib/window.rb` | main window (`Adw.ApplicationWindow`): headerbar, tool-select toggle, apply/copy buttons, save/load buttons, app-menu, content `Stack` (editor/search pages) | Yes (479 lines) |
| 3 | `resources/ui/Window.blp`'s `menu app-menu { }` | `lib/window.rb` (menu model inline) | primary menu — 5 items (`new-window`, `find`, `open-preferences`, `show-help-overlay`, `about`) across 3 sections | Yes — verify item-for-item during component-parity |
| 4 | `src/widgets/Editor.vala` + `resources/ui/Editor.blp` | `lib/editor.rb` | editor pane: `Adw.ToastOverlay` → `Overlay` → `ScrolledWindow`+`GtkSource.View` main child, overlay child = search bar + `arguments_box` (linked/editor-overlay) | Yes (332 lines) — **built on `Gtk::TextView`, not GtkSource.View; see defect above** |
| 5 | `src/widgets/SearchBar.vala` + `resources/ui/SearchBar.blp` | `lib/search_bar.rb` | in-editor find/replace bar: revealer, grid of entry/buttons, regex/case/whole-word checkbuttons, two `ShortcutController`s (`Escape`, `<Ctrl>f`, `<Ctrl>h`) | Yes (364 lines) — depends on `GtkSource.SearchContext`, see `lib/search_context.rb` |
| 6 | `src/widgets/SearchEntry.vala` + `resources/ui/SearchEntry.blp` | `lib/search_entry.rb` | the find entry itself: icon, `Text`, occurrence-count label, two local shortcuts (`Return`, `<Shift>Return`) | Yes (148 lines) |
| 7 | (no upstream file — `GtkSource.SearchContext`) | `lib/search_context.rb` | search/replace engine the gem would provide | Yes (219 lines) — hand-rolled; should be `GtkSource::SearchContext` once wired |
| 8 | `src/widgets/Search.vala` + `resources/ui/Search.blp` | `lib/search.rb` | tool picker page: `Stack` of results `ListBox` (`boxed-list`, `row-activated`) vs. `Adw.StatusPage` "No Tools Found" placeholder with "Add Custom Tool" button | Yes (311 lines) |
| 9 | `src/tools/Tool.vala` | `lib/tool.rb` | one tool's model: `ScriptResult` struct + `Tool` object (script execution) | Yes (215 lines) |
| 10 | `src/tools/ToolsController.vala` | `lib/tools_controller.rb` | loads `data/tools.json` + user custom tools, exposes the active list | Yes (204 lines) |
| 11 | (`Search.vala`'s row widget, implicit) | `lib/tool_row.rb` | one row in the tool-picker `ListBox` | Yes (21 lines) |
| 12 | `src/widgets/preferences/Preferences.vala` + `resources/ui/Preferences.blp` | `lib/preferences.rb` | `Adw.PreferencesWindow`, 2 pages: General (font row, wrap-lines/tabs-to-spaces/tab-width rows, `GtkSourceStyleSchemeChooserWidget` in a Clamp) and Tools (custom-tools `ListBox` + add button + "No Custom Tools" `Adw.StatusPage`) | Yes (381 lines) — style-scheme chooser is hand-rolled (see defect) |
| 13 | `src/widgets/preferences/ToolSettings.vala` + `resources/ui/ToolSettings.blp` | `lib/tool_settings.rb` | shared form for new/edit tool: name/description/arguments-count `Adw.ActionRow`s, "Edit Script" row, dynamic `argument_list` | Yes (245 lines) |
| 14 | `ToolSettings.vala`'s nested `private class Argument` | `lib/argument_row.rb` | one argument's row in `argument_list` (index + name) | Yes (36 lines) |
| 15 | `src/widgets/preferences/pages/CustomToolPage.vala` + `resources/ui/CustomToolPage.blp` | `lib/custom_tool_page.rb` | edit-existing-tool page: headerbar (back, title, Delete), embeds `ToolSettings` with `can-edit-script: true` | Yes (105 lines) |
| 16 | `src/widgets/preferences/pages/NewToolPage.vala` + `resources/ui/NewToolPage.blp` | `lib/new_tool_page.rb` | new-tool page: headerbar (back, title, Create revealed when valid), embeds `ToolSettings` | Yes (123 lines) |
| 17 | (`Preferences.vala`'s custom-tools `ListBox` row, implicit) | `lib/custom_tool_row.rb` | one row in the custom-tools list | Yes (22 lines) |
| 18 | `resources/ui/ShortcutsWindow.blp` (no backing `.vala`) | `lib/shortcuts_window.rb` | `Gtk.ShortcutsWindow`: 5 groups (General, Tools, Undo/Redo, Files, Search&Replace), ~15 shortcut rows | Yes (102 lines) |
| 19 | `src/utils/Recoloring.vala` | `lib/recoloring.rb` | derives UI accent colours from the active `GtkSource.StyleScheme` | Yes (272 lines) — reimplemented against hand-rolled JSON schemes, see defect |
| 20 | (no upstream file — `GtkSource.StyleScheme`) | `lib/style_scheme.rb` | style-scheme model the gem would provide | Yes (85 lines) — hand-rolled; should be `GtkSource::StyleScheme`/`StyleSchemeManager` once wired |
| 21 | `src/utils/Utils.vala` | `lib/utils.rb` | small free functions | Yes (31 lines) |
| 22 | `data/com.github.liferooter.textpieces.gschema.xml` | `lib/settings.rb` | app settings (9 keys: style-scheme, font-name, wrap-lines, tabs-to-spaces, spaces-in-tab, window-width/height, is-maximized, selected-tool) | Yes (111 lines) — JSON-file substitute, no port-side `.gschema.xml` exists |
| 23 | `src/Application.vala`'s `ActionAccel` struct + accelerator setup | `lib/accelerator.rb` | accelerator-string helper | Yes (37 lines) |
| 24 | `po/*.po`, `po/textpieces.pot`, `po/tools.pot` | `lib/translation.rb` + `po/*.po` | i18n: message catalogue (es, nl, pt_BR) plus the separate `tools.pot` for `data/tools.json`'s bundled tool names | Present on both sides — run `translation-parity` to confirm msgid-for-msgid |
| 25 | `data/tools.json` | `data/tools.json` | bundled built-in tools (base64, hashes, JSON/YAML/XML formatting, regex filters, RSS-from-OPML, etc.) | Present — diff against upstream's `data/tools.json` for tool-for-tool parity (not done in this survey) |
| 26 | `data/com.github.liferooter.textpieces.appdata.xml.in`, `.desktop.in` | `data/org.rubygtkproject.Textpieces.metainfo.xml`, `.desktop` | app metadata (About dialog content, desktop launcher) | Present, renamed to the port's own app ID — compare content fields (description, screenshots, categories) for parity, not done in this survey |
| 27 | `resources/style.css`, `resources/style-dark.css` | *(not located under `lib/` or `data/` in this survey — needs a dedicated pass)* | editor-overlay/linked CSS classes used throughout `Editor.blp`/`SearchBar.blp` | **Unclear — needs follow-up**: grep for where the port defines `.editor-overlay`/`.linked` styling |

## Not yet surveyed (next passes)

- **`data/tools.json` tool-for-tool diff** — upstream vs. port, to confirm every
  built-in script/formatter/filter tool is present with the same command and
  the same translatable name.
- **CSS stylesheet parity** (`resources/style.css`, `resources/style-dark.css`)
  — where does the port define the equivalent classes, and does it have a
  dark-mode variant.
- **`translation-parity`** — msgid-by-msgid census of `po/textpieces.pot` and
  `po/tools.pot` against the port's marked strings, confirming `es`, `nl`,
  `pt_BR` are all still carried.
- **`component-parity`** — widget-by-widget, CSS-class-by-CSS-class,
  signal-by-signal comparison per file listed above, once the GtkSourceView
  gem defect is resolved (several rows above will change shape — e.g.
  `Gtk::TextView` → `GtkSource::View` changes what signals/properties
  `lib/editor.rb` has to carry).
- **`test-parity`** — upstream has no `tests/` directory in `git ls-tree`, so
  there may be nothing to port here; confirm by checking for a Vala test
  harness this listing missed.
