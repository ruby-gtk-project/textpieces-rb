# Test parity — textpieces

| | |
|---|---|
| Upstream | `main` @ `6a6c41e` |
| Port | `ruby` @ `ac79adc` |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps | 0 |
| Test command (ledger) | none exists — see below |

## Upstream has no test suite

Verified by reading, not assumed: `.github/workflows/test.yml` runs only a
REUSE license-compliance check and a Flatpak build (`run-tests: true` there
means "run the Flatpak build's own smoke test", not a unit suite). There is
no `tests/` directory, no `meson test` target referencing test binaries, no
`Test.add_func`, no GLib test fixtures anywhere in `src/`. Parity is 0/0 and
is met trivially. **The port inherits no safety net from upstream** — every
check below was written for the port and pins nothing upstream considered
worth pinning down.

## What the port actually has, and the gap that matters

The port ships two test surfaces, and they are in very different states.

### `spec/` — present but **non-functional**

```
spec/README.md
spec/spec_helper.rb
```

No `*_spec.rb` files exist at all — the directory holds only a harness
README and a `spec_helper.rb`. Worse: the dev shell's own printed spec
command does not run:

```
$ nix develop --command ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'
Failure/Error: require "kettle/test/rspec"
LoadError:
  cannot load such file -- kettle/test/rspec
0 examples, 0 failures, 2 errors occurred outside of examples
```

`spec_helper.rb` requires `kettle/test/rspec`, a gem that is not declared
anywhere reachable from the dev shell. This was run, not assumed: the command
above is the exact one the flake's `shellHook` prints as "run the specs:".
**This command has never worked and cannot have ever been run successfully in
this environment.** Zero examples is not "nothing to test yet" — it is a
broken harness with a pointer at an empty directory behind it.

### `test/drive_window.rb` + `test/gtk_driver.rb` — real, and it runs

```
$ nix develop --command xvfb-run -a ruby test/drive_window.rb
...
75 of 75 checks passed
DRIVE OK
```

Run directly for this audit, not taken on the task's word — the command
above is this session's own output, timestamped 2026-11-07. It genuinely
drives a live headless app through 52 named steps covering: window open,
editor text entry, tool apply (with and without arguments), tool search and
filtering (including the empty-placeholder state), search-bar find/replace
(including replace-all and the match counter), file save/load (including the
file-error path), the shortcuts window, preferences (settings round-trip,
style-scheme picker), the full custom-tool lifecycle (create → edit → add
argument → delete, including the resulting empty state), the about dialog,
copy, `win.find`, `win.jump-to-args`, `win.tools-settings`, `app.new-window`,
and opening a file into a new window.

Two components not exercised by any step found in this file (checked by
reading, not inferred from the pass count): the OpenURI/`flatpak-spawn`
script-opening path in `lib/tool.rb#open` (the custom-tool steps open the
*edit page*, never click "Edit Script"), and the specific scroll/margin
arithmetic in `Editor#update_editor_margin`. The runtime gate's "30
components" claim is therefore optimistic by at least these two — the drive
is real and green, but it does not reach every component the inventory
lists.

## Why this still isn't test parity, by the skill's own terms

Test parity (`ported`/`gap` bijection) is 0/0 and holds trivially — there is
nothing upstream to map against, so there is no gap to open here.

But `drive_window.rb` is explicitly **not** a test-parity artifact; it is
`## Extra`, per the skill's own worked examples (gnome-tour, planify-rb): a
substantial, green, extra suite the port wrote for itself, listed outside the
count. Calling the runtime gate ("75 checks, 30 components, drive_ok=true")
a statement about *parity* would be the exact failure mode the skill
describes for planify-rb — "a bigger number is not parity."

The more serious finding is the one that doesn't show up in any pass/fail
count at all: **the project has a second, named test surface (`spec/`) that
has never once executed successfully**, and nothing in this repository says
so anywhere a reader would see it before this report. A green `DRIVE OK` next
to a silently broken `rspec` invocation is the "false green" this audit was
asked to look for.

## Extra

- `test/drive_window.rb` — 75 checks across 52 named steps, driving the live
  app headlessly. Passes, verified live in this session.
- `spec/` — 0 examples, 2 load errors. Not extra coverage; a non-functional
  harness. Listed here rather than silently omitted.

## Verdict

Not clean. Upstream owes the port nothing (0/0, met trivially), so there is
no bijection gap — but the repository currently presents two signals to a
reader (`DRIVE OK` and a documented `rspec` command) and only one of them is
real. The broken `spec/` harness should either be fixed (declare
`kettle-test`/`kettle-soup-cover` as real dependencies, or drop the
`kettle/test/rspec` require and the "run the specs" line from the dev shell
banner) or the banner and `spec/README.md` should stop presenting it as a
working command.
