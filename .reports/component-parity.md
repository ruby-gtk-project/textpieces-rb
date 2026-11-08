# Component parity — textpieces — re-audit (2026-11-07)

| | |
|---|---|
| Upstream | `main` @ `6a6c41e` |
| Port | `ruby` @ `f273107` |
| Prior pass | `ac79adc`, 7/30 checked, 23 unchecked |
| This pass | re-verifies the prior 7, checks the 2 items it left explicitly
  unverified, and finds 1 new defect introduced by work done since |

## Items the prior pass left explicitly unverified, now checked

### The flatpak-spawn/OpenURI script-opening path (`lib/tool.rb#open`)

Prior report: "nothing in `test/drive_window.rb` actually invokes 'Edit
Script' and checks a process launches... unverified by any check."

Now driven. `test/drive_window.rb:300` has a step `"Edit Script opens the
script through the OpenURI portal"` that exercises this exact path — read in
full, it clicks the real "Edit Script" row action and asserts the
flatpak-spawn/OpenURI cmdline construction in `lib/tool.rb:182` actually
runs. Re-ran the drive live:

```
$ nix develop --command xvfb-run -a ruby test/drive_window.rb
82 of 82 checks passed
DRIVE OK
```

**Closed.**

### `Editor#update_editor_margin`'s measured value

Prior report: "exercised incidentally when arguments show, but nothing
asserts the margin value itself."

Now asserted. `test/drive_window.rb:76-84` has a step whose checks are
`margin grew` and, critically, `margin matches the measured box height` —
comparing `view.top_margin` against the arguments box's own measured natural
height, not just "did it change". `test/drive_window.rb:106-108` also
asserts the margin falls back to the no-arguments default. **Closed.**

## Previously-checked units, re-confirmed unchanged

`lib/window.rb`, `lib/shortcuts_window.rb` (structure), `lib/recoloring.rb`,
`lib/search.rb` — re-read, no regressions from the commits since the last
pass; these files were not touched by `3b65fc7`/`449aeff`/`f273107`.

## New finding: `GtkSource` wiring is a real fix, but it surfaces a chrome-string gap

`f273107` replaced the hand-rolled `lib/style_scheme.rb` and the
reimplemented half of `lib/search_context.rb` with the real
`gtksourceview5` gem — confirmed loading live (see
`.reports/component-identification.md`) and confirmed as a genuine
dependency of the packaged build, not just the dev shell
(`textpieces-rb.gemspec:108`, `nix/Gemfile:15`, `nix/Gemfile.lock:59`). This
closes the "no Ruby bindings" false claim the earlier inventory flagged.

But reading `lib/shortcuts_window.rb` and `lib/window.rb` surfaced something
the gtksourceview change did not touch and nobody has flagged yet: the
**`Adw::ShortcutsDialog` substitution for upstream's native
`Gtk.ShortcutsWindow`** needs two chrome strings upstream never has to
supply at all:

```ruby
# lib/shortcuts_window.rb:67
window.title = Translation.t("Keyboard Shortcuts")
# lib/window.rb:470
dialog.add_response("close", Translation.t("_Close"))
```

Upstream's `Gtk.ShortcutsWindow` (`resources/ui/ShortcutsWindow.blp`) is a
native GTK widget that supplies its own window chrome — title and close
affordance — translated out of GTK's own installed locale data, not out of
`po/textpieces.pot`. Confirmed: grepping upstream's `resources/` and `src/`
for `"Keyboard Shortcuts"` or `"_Close"` finds nothing — those strings are
not upstream msgids at all, because upstream never had to write them. The
port's bindings cannot construct `Gtk.ShortcutsWindow` (documented
substitution, correctly disclosed elsewhere), so the port has to build this
chrome itself, in Ruby, as literal `Translation.t(...)` calls.

That is a reasonable substitution. The defect is what happens next: these
two strings were never added to `po/textpieces.pot` or any of the three
`.po` files. Confirmed:

```
$ grep -c '"_Close"\|"Keyboard Shortcuts"' po/textpieces.pot po/es.po po/nl.po po/pt_BR.po
# zero matches anywhere
```

`Translation.t` falls back silently to the English literal when a key is
missing from the catalogue (`lib/translation.rb:29`, by design, matching
gettext's own behaviour) — so this does not crash or show untranslated
brackets, it just **can never be translated**, in any locale, because
nothing ever extracts it into the catalogue for a translator to see. This
is a new, real gap: 2 English-only strings in a path upstream never needed
one for. Full detail, including why there is also no tooling that would
catch it, is in `.reports/translation-parity.md`.

## Still unchecked (carried over, not re-examined this pass)

Per the prior report's own accounting, 23 of 32 units have a port file and
appear in the inventory but have not been compared on any axis:
`lib/custom_tool_page.rb`, `lib/new_tool_page.rb`, `lib/custom_tool_row.rb`,
`lib/argument_row.rb`, `lib/tool_settings.rb`, `lib/tool_row.rb`,
`lib/preferences.rb` (font chooser, the rest of the page beyond the
scheme-chooser swap already checked), `lib/search_bar.rb`,
`lib/search_entry.rb`, `lib/settings.rb` (9 GSettings keys' defaults not
diffed), `lib/tools_controller.rb`, `lib/utils.rb`, `lib/accelerator.rb`, the
About dialog's exact field set, file-chooser dialogs, the file-error dialog,
`data/tools.json` + `scripts/` (36 tools, not diffed script-by-script), the
bundled icon set, and the two new `data/` files' installation wiring at
build time (confirmed present in source, not confirmed installed to the
right XDG path by a built package in this pass). No screenshot-diff against
a running upstream build was performed in this pass either (same limitation
as before — upstream is Vala/GTK4 and was not built).

## Verdict

**Not clean**, but materially improved. 9/32 units now carry a real,
re-verified check (the prior 7 plus the 2 closed this pass), and the two
items the prior pass most wanted closed — the OpenURI script-opening path
and the margin arithmetic — are closed with real assertions, not just a
green drive run. Against that improvement, this pass also found one real
new gap the `gtksourceview5` migration surfaced: two chrome strings for the
`Adw::ShortcutsDialog` substitution that are permanently untranslatable
because nothing extracts them into the catalogue. 23/32 units remain
genuinely unexamined and should not be read as passing.

---

# Re-verification — 2026-11-08

| | |
|---|---|
| Upstream | `main` @ `6a6c41e` (unchanged) |
| Port | `ruby` @ `535b47b` |
| This pass | confirms the one gap this report raised (the two untranslated
  `Adw::ShortcutsDialog`/`Adw::AlertDialog` chrome strings) is closed, and
  re-states what is still unexamined |

## The chrome-string gap: closed

`535b47b` adds both msgids to `po/textpieces.pot`, each with a translator
comment explaining why upstream has no equivalent:

```
$ grep -c '"_Close"\|"Keyboard Shortcuts"' po/textpieces.pot
2
```

Confirmed by reading the diff: both entries carry `#: lib/shortcuts_window.rb:67`
/ `#: lib/window.rb:470` references matching the call sites this report
named. **Closed** — the strings now have a mechanical path to a translator,
even though no translator has acted on them yet (see
`.reports/translation-parity.md`'s re-verification for why that remainder is
expected, not a new gap).

## Still unchecked — unchanged from the prior pass

The prior pass's own accounting stands: **23 of 32 inventory units** have a
port file and appear in the inventory but have not been compared on any of
the four axes (count/style/behaviour/text). Nothing in `535b47b` or
`7aaa797` touches any of those 23 files, and nothing in this pass re-examined
them. They are listed in full above and are **not** closed by this
verification pass.

Separately: the runtime gate this round reports 82 checks covering **21**
components. A component with no check exercising it is unverified, not
passing — the gap between 21 checked and 32 inventoried units is the same
gap this report has been carrying since the first pass, just visible now
from the gate's own numbers rather than only from the inventory.

## Verdict (unchanged)

**Not clean.** One real, re-verified fix landed cleanly. The structural gap —
roughly two-thirds of the component inventory never compared on any axis — is
untouched by this round's commits and remains open.
