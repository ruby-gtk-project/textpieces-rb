# Component identification — re-verification pass (2026-11-07)

| | |
|---|---|
| Upstream | `main` @ `6a6c41e` |
| Port | `ruby` @ `f273107` |
| Prior report | `.reports/component-inventory.md` (30-unit survey) + an earlier verification
pass of this file that found 2 missing units (desktop entry, AppStream metainfo) |

This re-run checks whether the previously-found gap was actually closed, and
whether anything new appeared in the commits since (`3b65fc7`, `449aeff`,
`f273107`).

## The previously-found gap: closed

The earlier pass found upstream ships `data/com.github.liferooter.textpieces.desktop.in`
and `data/com.github.liferooter.textpieces.appdata.xml.in`, neither of which
existed in the port at the time. Both now exist:

```
data/org.rubygtkproject.Textpieces.desktop
data/org.rubygtkproject.Textpieces.metainfo.xml
```

Confirmed by reading both files side by side with upstream's:

- `Name`, `MimeType`, `Categories`, `Keywords`, `Terminal`, `StartupNotify`,
  `Actions=new-window;` and the `[Desktop Action new-window]` block are
  byte-identical to upstream. `Exec` and `Icon` are correctly re-pointed at
  the port's own launcher/app-id (`org.rubygtkproject.Textpieces`), which is
  the right adaptation, not a drift — a file header comment names the
  substitution and why.
- The metainfo's `<summary>`, `<description>` (all 11 `<li>` items plus the
  trailing `<p>`), `<content_rating>`, `<supports>`/`<recommends>`/`<requires>`
  are upstream's, unchanged. `<id>`, `<launchable>`, `<provides>/<binary>`
  and the `<url>` pair are correctly re-pointed at the port. The per-release
  `<releases>` history is dropped, with a header comment giving the reason
  (it describes the Vala binary's own release history, not this port's) —
  this is a deliberate, named omission of upstream metadata that does not
  correspond to user-facing behaviour, not a silently dropped component.

This closes 2 of the units the component map was previously missing. The
unit count is now 32 (30 + these 2), all 32 present on the port side.

## Checked again for anything new

- `find lib -type f` still returns exactly the units the inventory names,
  minus `lib/style_scheme.rb` (deleted in `f273107`) — see the note below.
  `lib/search_context.rb` is retained but its role changed (see
  `component-parity.md`).
- No new upstream files appeared between `6a6c41e` (still current `origin/main`)
  and this run — the upstream ref did not move, only the port did.
- `rake -T` (the dev shell's own task list) advertises no `pot`-extraction
  task despite a comment in `flake.nix` describing one (`rake pot`) — this is
  a tooling-identification gap in its own right, written up in
  `.reports/translation-parity.md` and `.reports/accountability-ensurance.md`
  rather than here, since it is not a missing *user-facing* component.

## `lib/style_scheme.rb` removal

The earlier inventory's own defect report said this file should not exist
once `gtksourceview5` is wired in ("`lib/style_scheme.rb` is not a reasonable
substitution... per the defect"). It has since been deleted (`f273107`) and
`lib/preferences.rb`/`lib/recoloring.rb` now call `GtkSource::StyleSchemeManager`
and `GtkSource::StyleSchemeChooserWidget` directly — verified by reading
both files and by loading the gem live:

```
$ nix develop --command xvfb-run -a ruby -e "require 'gtksourceview5'; puts GtkSource.constants.grep(/View|Buffer|SearchContext|StyleScheme/).sort"
Buffer
SearchContext
StyleScheme
StyleSchemeChooser
StyleSchemeChooserButton
StyleSchemeChooserWidget
StyleSchemeManager
StyleSchemePreview
View
ViewGutterPosition
```

This is not a removed component, it is removing a wrong substitution for the
real upstream component (`GtkSource.StyleScheme`/`StyleSchemeManager`), which
is a correctness fix, not a regression. `lib/search_context.rb` survives as a
thin adapter over the real `GtkSource::SearchContext`/`SearchSettings`
(confirmed: `require "gtksourceview5"`, `GtkSource::SearchSettings.new`,
`GtkSource::SearchContext.new` at `lib/search_context.rb:3,22-23`) — this is
the correct shape now, not a reimplementation.

## Verdict

**Clean for this pass's scope.** The one real omission the prior
identification pass found (desktop entry + AppStream metainfo) is closed,
verified by reading both new files against upstream's. No new missing
top-level component was found. This report does not re-run the full 30→32
unit four-axis comparison — that remains `.reports/component-parity.md`'s
job — and that report still finds open items, including one new one from
this round's own code reading (see its ShortcutsDialog chrome-string
finding).
