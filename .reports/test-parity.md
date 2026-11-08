# Test parity — textpieces — re-audit (2026-11-07)

| | |
|---|---|
| Upstream | `main` @ `6a6c41e` |
| Port | `ruby` @ `f273107` |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps | 0 |
| Prior report | found the drive suite real and green (75/75) but also found a
  second, named test surface (`spec/`) that had never worked |

## Upstream still has no test suite

Unchanged from the prior pass: `.github/workflows/test.yml` runs only a
REUSE license check and a Flatpak build; no `tests/`, no `meson test`
target, no `Test.add_func`. Parity is 0/0, met trivially.

## The drive suite, re-run live for this audit

```
$ nix develop --command xvfb-run -a ruby test/drive_window.rb
...
82 of 82 checks passed
DRIVE OK
```

Run in this session, not taken on the task's word. 82 checks across 57
named steps now — up from 75/52 at the prior pass. The two new checks the
prior pass most wanted (see `.reports/component-parity.md`) are in this
count: the OpenURI/flatpak-spawn script-opening path and the measured
margin-arithmetic assertion are both now exercised by name, not just
incidentally.

## The prior pass's headline finding: closed, by removal

The prior pass's most serious finding was not a missing feature, it was a
**false-green risk**: `spec/spec_helper.rb` required a gem
(`kettle/test/rspec`) nothing in the port declared, so the exact command the
dev shell's own banner printed as "run the specs:" had never worked, while
nothing in the repository said so.

That surface no longer exists:

```
$ ls spec/ 2>&1
ls: cannot access 'spec/': No such file or directory
$ grep -n 'spec\|rspec' flake.nix
# (no "run the specs" line, no spec_helper reference)
```

The commit that did this (`3b65fc7`, "...and drop the non-functional spec
runner") removed the broken harness and the banner line that advertised it,
rather than fixing the `kettle/test/rspec` dependency or leaving the false
claim in place. That is the right fix for a harness nothing in this port
ever used: deleting an unused, broken, falsely-advertised command is not a
coverage regression (0 examples existed before, 0 exist now), and it removes
the exact false-green surface the prior audit flagged. Confirmed `rake -T`
no longer lists a `spec` task reachable from this repo's own Rakefile baseline
behaviour (the `rake spec`/`rake test` lines in the Rakefile's own banner
comment are the upstream `kettle-jem` template's stock text, unrelated to
the deleted `spec/` directory, and were already present before `3b65fc7`;
they are not claims this repo's own code backs, and are flagged separately
in `.reports/accountability-ensurance.md` as boilerplate worth pruning, not
as a live false-green here since nothing in this session's drive or build
path invokes them).

## A new thing worth naming, found while re-checking the `spec/` removal

`flake.nix` carries a comment (predating this round, unchanged since
`f02751c`) that describes a `rake pot` task as the thing that drives
`rxgettext`:

```
# rxgettext, the extractor `rake pot` drives. GNU xgettext claims
# to support Ruby but only shells out to this, so without it
# `xgettext --language=Ruby` fails.
```

`rake -T` in the dev shell lists no `pot` task at all — confirmed live,
full output captured in this session. This is not a test-parity gap on its
own (there is no upstream test to compare it against), but it is adjacent:
it is exactly the kind of tooling claim that, left unexamined, becomes the
same shape of false-green the `spec/` harness was. Written up in full in
`.reports/translation-parity.md` and `.reports/accountability-ensurance.md`.

## Extra

- `test/drive_window.rb` — 82 checks across 57 named steps, driving the live
  app headlessly. Passes, verified live in this session, 2026-11-07.

## Verdict

**Not clean, but improved and the headline issue closed.** Upstream owes
the port nothing (0/0). The drive suite grew (75→82 checks) and now covers
the two specific behaviours the prior pass flagged as unexercised. The
broken `spec/` harness that was presenting a false-working command is gone,
closing that finding by removal rather than by repair — an acceptable
resolution since the harness was dead weight, not a coverage loss. The
`rake pot` comment in `flake.nix` naming a nonexistent task is a new,
smaller instance of the same "command that looks real but isn't" pattern,
and should not be left standing uncorrected now that it has been found.

---

# Re-verification — 2026-11-08

| | |
|---|---|
| Upstream | `main` @ `6a6c41e` (unchanged, still 0 tests) |
| Port | `ruby` @ `535b47b` |

## Drive suite, re-run live for this pass

```
$ nix develop --command xvfb-run -a ruby test/drive_window.rb
...
82 of 82 checks passed
DRIVE OK
```

Run in this session, not taken on the harness's own word. Count unchanged
from the prior pass (82/82) — `535b47b` and `7aaa797` touched `flake.nix`,
`po/textpieces.pot` and a skill script, none of which the drive exercises
directly, and the live re-run confirms no regression.

## The `rake pot` tooling claim: closed, see translation-parity.md

The flake.nix comment this report flagged as a "command that looks real but
isn't" has been rewritten in `535b47b` to state plainly that no such task
exists and the catalogue is hand-maintained. Confirmed by reading the
current comment and by re-running `rake -T | grep pot` (still empty, now
matching what the comment says rather than contradicting it). **Closed.**

## Still open

- Parity remains 0/0 trivially (upstream ships no tests) — unchanged.
- The runtime gate for this round reports 82 checks "covering 21
  components" against a 32-unit inventory. A component the drive suite
  never names is unverified by this suite, whatever its unit-test status —
  this is restated from `component-parity.md`'s re-verification, because a
  green 82/82 does not by itself mean full-app coverage and should not be
  read as such.

## Verdict

**Not clean, but improved further.** The one issue this report carried
forward from the prior pass (the `rake pot` comment) is now closed. Nothing
new was found this pass. The structural ceiling — a drive suite that is
real, green, and run live, but does not reach roughly a third of the
inventoried units — is unchanged and is not this pass's to close.
