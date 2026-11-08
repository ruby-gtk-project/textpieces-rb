# Translation parity — textpieces — re-audit (2026-11-07)

| | |
|---|---|
| Upstream | `main` @ `6a6c41e` |
| Port | `ruby` @ `f273107` |
| Domain | `textpieces` (po files copied unchanged; `lib/translation.rb` reads `.po` directly) |
| Upstream messages | 237 distinct `(ctxt, id)` keys |
| Ported (key present in the port's catalogue) | 236 |
| Gaps (upstream key missing from port) | 1 (the same `!unresolved` dynamic call as before — not a real gap, see below) |
| New gap this pass | 2 strings the port added that are **not in any catalogue at all**, upstream or port |
| Languages | 3 — `es`, `nl`, `pt_BR` — all 3 shipped, byte-identical to upstream's own `.po` files |

## Re-run census

```
$ .claude/skills/translation-parity/scripts/msgid-census.sh <upstream-main> | wc -l
1130   (237 distinct keys)
$ .claude/skills/translation-parity/scripts/msgid-census.sh .           | wc -l
1094   (249 distinct keys — see "extra" below for why this isn't 236)
$ comm -23 up.keys port.keys
!unresolved   _(name); } }  ...
$ comm -13 up.keys port.keys
-             _Close
-             Keyboard Shortcuts
!unresolved   <11 rows, all Translation.t(...)/Translation.tools(...) call sites the scanner can't parse as literals>
```

### The 3 old metainfo/desktop gaps: closed

The prior pass's 4 gaps included 3 strings from
`data/com.github.liferooter.textpieces.appdata.xml.in` ("Powerful
scratchpad...", "The application is extendable...", "And so on.") which the
port did not ship at all, because it shipped no `data/` directory. It now
does (`data/org.rubygtkproject.Textpieces.metainfo.xml`,
`data/org.rubygtkproject.Textpieces.desktop`, see
`.reports/component-identification.md`), and `po/textpieces.pot` now
contains all 3 strings:

```
$ grep -c "Powerful scratchpad\|script-based actions\|And so on" po/textpieces.pot
3
```

None of the 3 are translated in `es.po`/`nl.po`/`pt_BR.po` — but neither are
they in upstream's own `.po` files for the same 3 strings (confirmed: 0
matches on both sides). This matches upstream's own (untranslated) state
exactly, so it is not a port-introduced regression; it is upstream's own gap,
faithfully reproduced. **Closed, correctly.**

### The 1 remaining old gap: not a real gap (unchanged from before)

`!unresolved` on `_(name)` in `ToolSettings.vala:60` is a dynamic call the
census scanner cannot resolve to a literal upstream msgid. The port's actual
mechanism (`Translation.tools`, verified at `lib/tool.rb:115-117`) is
correct. Carried forward unchanged from the prior report.

## New finding: 2 strings exist in the port's source but in no catalogue at all

```ruby
# lib/shortcuts_window.rb:67
window.title = Translation.t("Keyboard Shortcuts")
# lib/window.rb:470
dialog.add_response("close", Translation.t("_Close"))
```

```
$ grep -c '"_Close"\|"Keyboard Shortcuts"' po/textpieces.pot po/es.po po/nl.po po/pt_BR.po
0  0  0  0
```

These are not upstream msgids at all — upstream's `Gtk.ShortcutsWindow` is a
native widget that gets its own window title and close button translated
from GTK's installed locale data, not from `po/textpieces.pot`. The port
substitutes `Adw::ShortcutsDialog` (bindings cannot construct the native
widget — a documented, reasonable substitution, see
`.reports/component-parity.md`), which does not supply that chrome for
free, so the port writes the two strings itself. Writing them was the right
call. Routing them through `Translation.t` looks right at a glance — it is
the house convention, and it means the strings are *not* hardcoded English
literals outside the translation layer.

But `Translation.t` falls back silently to the literal when the catalogue
has no entry (`lib/translation.rb:29`, correct gettext-matching behaviour,
and the reason nothing crashes or shows brackets). That silence is exactly
why this gap is invisible at runtime: the app looks fully translated in
every locale because the English fallback is indistinguishable from a real
translation when you're reading English. The two strings are **not
present in `po/textpieces.pot` and have no path to get there**:

```
$ rake -T 2>&1 | grep pot
# (nothing — no pot-extraction task exists)
```

`flake.nix` has a comment claiming `rxgettext` is installed because "the
extractor `rake pot` drives" it — no such task exists in `Rakefile`. So even
if someone wanted to regenerate the catalogue from the Ruby source today,
the tool the repo's own comment says to run isn't there. These two strings
are structurally stuck in English for every non-English user, permanently,
until someone either writes a `rake pot` task or hand-adds the two msgids.

This is the kind of gap the generic scanner cannot find on its own (it
doesn't know `Translation.t` is a translation call at all, a limitation
already noted in the prior pass) — it was found by reading the two files
the `Adw::ShortcutsDialog`/`gtksourceview5` substitutions touched and
checking each new literal against all four catalogues by hand.

## Scanner limitation, carried forward

Unchanged from the prior pass: `msgid-census.sh`'s marker list does not
include `Translation.t`/`Translation.tools`, so every one of the 249 "port"
rows above that looks like `!unresolved` is a call site the scanner can't
parse as a literal, not a missing string — confirmed by hand that the
genuinely-ported 236 keys route correctly through 11 files and 61+ call
sites of `Translation.t(`. This is stated per the skill's rule rather than
silently worked around, same as the prior pass.

## Languages

Unchanged: `es`, `nl`, `pt_BR`, byte-identical copies of upstream's own
`.po` files (`diff -q` on all three, confirmed again this pass — the files
were not touched by any commit since the last audit).

## Not run (same limitations as before)

- `msgfmt -c` validation (not installed in the checked environment).
- Driving the app live under `LANGUAGE=es`/`nl` and asserting a translated
  string on screen.

## Verdict

**Not clean.** The 3 old metainfo gaps are genuinely closed, correctly
matching upstream's own untranslated state rather than just suppressing the
diff. But this pass found a new, real gap introduced by the
`Adw::ShortcutsDialog` substitution: 2 strings with no path into any
catalogue, invisible at runtime because the fallback-to-English behaviour
that makes missing keys harmless also makes them undetectable without
reading the source against all four catalogues by hand — which is what this
pass did. The `rake pot` comment describing nonexistent tooling compounds
this: there is currently no mechanical way to even notice these two strings
are missing, let alone add them.

---

# Re-verification — 2026-11-08

| | |
|---|---|
| Upstream | `main` @ `6a6c41e` (unchanged) |
| Port | `ruby` @ `535b47b` |

## The "2 strings in no catalogue at all" gap: closed

`535b47b` adds both as new entries to `po/textpieces.pot`:

```
$ grep -A2 'msgid "Keyboard Shortcuts"\|msgid "_Close"' po/textpieces.pot
#. Translators: not an upstream string. Upstream's native Gtk.ShortcutsWindow
#. supplies its own translated window title from GTK's own locale data; ...
#: lib/shortcuts_window.rb:67
msgid "Keyboard Shortcuts"
msgstr ""

#. Translators: not an upstream string. The close button of the port's
#. file-error alert dialog (Adw.AlertDialog), which upstream's own dialog
#. does not need to supply as a separate msgid.
#: lib/window.rb:470
msgid "_Close"
msgstr ""
```

Each carries a translator comment stating plainly that it is not an
upstream string and why the port had to add it — the honest form this
skill asks for, not a silent catalogue edit. **Closed** as a translation-
parity gap: the strings now have a mechanical extraction path.

They remain, correctly, untranslated in `es.po`/`nl.po`/`pt_BR.po` (0 hits
in all three). This is not a new gap: the fork is not registered on
l10n.gnome.org, these are port-introduced ("Extra") strings by the skill's
own definition, and the skill is explicit that Extra strings are "not free"
— English-only until a translator acts — never that they must be
hand-translated by whoever adds them. They are listed here, in the `##
Extra` sense, rather than silently left unmentioned.

## The `rake pot` false-tooling-claim: closed

`535b47b` also rewrites the `flake.nix` comment that previously claimed a
`rake pot` task drives `rxgettext`. It now reads:

```
# rxgettext, the extractor GNU xgettext's `--language=Ruby` mode
# shells out to; without it that mode fails outright. No rake
# task in this repo drives it yet (`po/textpieces.pot` is
# maintained by hand), but the dev shell carries the tool so one
# can be added without a second round of Nix wiring.
```

Confirmed live: `nix develop --command rake -T 2>&1 | grep -i pot` still
returns nothing, and the comment no longer claims otherwise. This closes
the false-green risk this report and `accountability-ensurance.md` flagged
— the comment now accurately describes the catalogue as hand-maintained
with no extraction tooling, rather than naming a task that does not exist.

## Still open, unchanged

- No `rake pot`/equivalent extraction task exists. Any future string added
  as a literal still has to be hand-added to `po/textpieces.pot`, as
  `535b47b` itself was — there is nothing mechanical catching a *next*
  occurrence of this exact gap.
- `msgfmt -c` validation and a live `LANGUAGE=es`/`nl` on-screen check were
  not run this pass either (same unrun-check limitation as before).
- The 23 unexamined component-parity units (see that report's
  re-verification) may still hide further unmarked or interpolated strings
  that a file-by-file read has not yet reached.

## Verdict

**Not clean, but the two findings this report raised are both genuinely
closed.** The remaining open items are pre-existing tooling/coverage gaps,
not new regressions, and are carried forward rather than claimed fixed.
