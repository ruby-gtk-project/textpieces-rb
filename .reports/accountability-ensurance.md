# Accountability ensurance — textpieces — re-audit (2026-11-07)

| | |
|---|---|
| Port | `ruby` @ `f273107` |
| Prior report | found no excuse-language gaming in `lib/`/`exe/`, but found a
  broken `spec/` command presented as working, and a runtime-gate summary
  ("covering 30 components") that rounded up past what was actually checked |

## Scan, re-run

```sh
.claude/skills/accountability-ensurance/scripts/find-excuses.sh .
```

Same two false-positive hits as before, both in `.reports/component-inventory.md`,
both the word "skipped" describing the port's own correct, upstream-matching
behaviour (Adwaita style schemes are skipped from CSS generation because
upstream's `is_scheme_dark`/`generate_css` does the same — re-confirmed in
`.reports/component-parity.md`). No rewrite needed, same as before.

```sh
grep -rniE "TODO|FIXME|not implemented|for now|in a future|not applicable|n/a\b|out of scope|by design|does not carry over|no ruby analogue|dropped deliberately|intentionally omitted|simplified|streamlined" lib/ exe/
```

Zero hits, same as before. No `PORTING.md` exists, same as before.

## The prior pass's two findings: one closed, one narrowed

### "A broken command presented as working" (`spec/`) — closed by removal

`3b65fc7` deleted `spec/` entirely and removed the dev shell's "run the
specs:" banner line. Confirmed:

```
$ ls spec/ 2>&1
ls: cannot access 'spec/': No such file or directory
$ grep -n 'run the specs' flake.nix
# (nothing)
```

Nothing in the repository now claims a working spec command that doesn't
exist. This is the right fix for a harness that was dead weight — the
alternative (declaring `kettle-test` as a real dependency to make the
broken command work) would have added a second, real test surface with zero
examples in it, which is no better. Deleting an unused false claim is not a
regression. **Closed.**

### "covering 30 components" rounding up past what was checked — narrowed, not closed

The runtime gate this round reads "82 checks passed, 0 failed, covering 24
components" (down from the prior round's "75 checks... 30 components" —
the component count the harness reports dropped because `lib/style_scheme.rb`
was deleted in `f273107`, correctly, since it was a wrong substitution, not
a real component). The two specific unexercised behaviours the prior pass
named — the flatpak-spawn/OpenURI script path and the margin arithmetic —
are now both driven and asserted (`.reports/component-parity.md`,
`.reports/test-parity.md`). That part of the prior finding is resolved.

But `.reports/component-parity.md` this round still finds 23 of 32 inventory
units unexamined on any axis. A reader seeing "24 components, 0 failed"
next to a clean-looking report set has no way to tell that from the gate
numbers alone — the same shape of over-rounding the prior pass flagged, now
with a smaller but still real unexamined set behind it.

## New finding this pass: a tooling claim that describes a task which does not exist

`flake.nix` (unchanged since `f02751c`, so not introduced this round, but
not previously flagged either) carries this comment, justifying why
`rxgettext` is a dev-shell dependency:

```
# rxgettext, the extractor `rake pot` drives. GNU xgettext claims
# to support Ruby but only shells out to this, so without it
# `xgettext --language=Ruby` fails.
```

Run live, in this session:

```
$ nix develop --command rake -T
...
rake build / build:checksum / clean / clobber / default / docs / install /
install:local / kettle:jem:selftest / release[remote]
# no "pot" task anywhere
```

`Rakefile` defines no `pot` task, scoped or otherwise. The comment describes
a specific, named command as the reason a dependency is installed, and that
command does not exist in this repository. This is the same failure mode as
the `spec/` finding from the prior pass — a claim that a tool works,
unverified until someone actually runs it — just smaller in consequence
(nobody has shipped a feature that depends on `rake pot` working; it is a
comment, not a banner line a person is likely to type). It directly caused
this pass to find the translation-parity gap it found: without `rake pot` or
any equivalent, the two new `Translation.t("_Close")` /
`Translation.t("Keyboard Shortcuts")` strings introduced for the
`Adw::ShortcutsDialog` substitution have no mechanical path into
`po/textpieces.pot` at all, and nothing in the repository would ever
surface that on its own.

## Rewrite, per the skill's required form

> I did not add `"_Close"` and `"Keyboard Shortcuts"` to `po/textpieces.pot`
> when I wrote them as `Translation.t(...)` calls for the
> `Adw::ShortcutsDialog` substitution, and I left a comment in `flake.nix`
> claiming a `rake pot` task extracts strings like these when no such task
> exists in this repository's `Rakefile`, so I am an idiot who shipped two
> permanently-untranslatable strings behind a tooling claim I never checked.
> Upstream: `Gtk.ShortcutsWindow`'s title and close affordance come from
> GTK's own installed locale data; upstream never writes these two strings
> itself (see `.reports/translation-parity.md`).
> Port: `lib/shortcuts_window.rb:67`, `lib/window.rb:470` write them as
> `Translation.t(...)` calls; `po/textpieces.pot` and all three `.po` files
> have zero entries for either string.

## Verdict

**Not clean.** No excuse-language gaming in the port's own code, same as
before. The prior pass's headline false-green (`spec/`) is genuinely closed
by removal. But this pass found a live instance of the same pattern it was
asked to watch for: a tooling comment (`rake pot`) describing a command that
does not exist, and — found by following that thread rather than by the
generic scanner — two real strings that command's absence leaves with no
path to translation at all. A runtime gate reading "0 failed" says nothing
about either of these, because neither is a thing any check currently
looks for.
