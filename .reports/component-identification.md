# Component identification — verification pass

This repo already has `.reports/component-inventory.md`, produced by an
earlier `component-identification` run. It is a careful, well-sourced
document and most of it holds up — this report is a verification pass over
it, not a replacement, and it records one real omission the earlier document
missed, plus two things that were checked and do hold up.

## The gap the existing inventory missed

`.reports/component-inventory.md` states: "Every user-facing component below
exists" and presents a 30-row component map as complete. It is not complete.
Upstream ships two files the map never mentions at all:

- `data/com.github.liferooter.textpieces.desktop.in` — the desktop entry:
  `Name=Text Pieces`, an `Icon=`, `MimeType=text/plain;`, a `Keywords=` list
  (translatable), `Categories=`, and a second launchable action, `New
  Window` (`Actions=new-window;` + a `[Desktop Action new-window]` section).
- `data/com.github.liferooter.textpieces.appdata.xml.in` — the AppStream
  metainfo: `<name>`, `<summary>`, a `<description>` with an 11-item `<ul>`
  (the source of the 3 msgid gaps in `.reports/translation-parity.md`),
  `<launchable>`, `<developer>`, screenshot and release metadata.

The port has **no `data/` directory containing either**, confirmed by
`find . -iname '*.desktop*' -o -iname '*appdata*' -o -iname '*metainfo*'`
returning nothing. These are genuine components — a desktop entry is how a
GNOME user finds and launches the app at all, and it carries its own
translatable strings and its own secondary action (`new-window`) that the
`.desktop` spec, not GTK, is responsible for exposing to a shell. Dropping
both from the inventory is why the earlier document could call the survey
"complete": the units were never counted because the scan that produced it
(`component-scan.sh`) only reads `src/`, `resources/ui/` and the gschema by
design, and nobody separately walked `data/*.in`.

This is now two rows the component map should carry and currently does not:

| # | Upstream | → port file | Kind | Exists |
|--:|---|---|---|---|
| 31 | `data/com.github.liferooter.textpieces.desktop.in` | — | desktop entry | **no** |
| 32 | `data/com.github.liferooter.textpieces.appdata.xml.in` | — | metainfo | **no** |

## What was re-checked and holds up

- **The GtkSourceView scope note.** Confirmed: `GtkSource.View`,
  `.Buffer`, `.SearchContext`, `.SearchSettings`, `.StyleScheme`,
  `.StyleSchemeManager` and `.StyleSchemeChooserWidget` have no Ruby
  bindings, and the port's substitutes (`lib/search_context.rb`,
  `lib/style_scheme.rb`, the hand-built chooser in `lib/preferences.rb`) are
  real files that do real work, not stubs — spot-checked in
  `.reports/component-parity.md`.
- **The 30 listed units each have a port file.** Re-confirmed by `find lib
  -type f` against the map; all 30 paths exist.
- **The "port-only support units" table** (`lib/search_context.rb`,
  `lib/style_scheme.rb`, `lib/accelerator.rb`, `lib/translation.rb`,
  `lib/textpieces.rb`) is accurate — each stands in for something the Ruby
  bindings cannot import, and each says so in its header comment.

## What this report does not do

It does not re-run the four-axis comparison per component — that is
`.reports/component-parity.md`'s job, and it found 7/30 units actually
checked, 23 unchecked. This report's job was narrower: confirm the unit list
itself is complete. It is not; it was short two real components.

## Verdict

Not clean. The existing inventory's "every user-facing component exists"
claim is false for the desktop entry and the AppStream metainfo — both
absent, both counted nowhere, and the absence of the metainfo file is the
direct cause of 3 of the 4 gaps in `.reports/translation-parity.md`.
