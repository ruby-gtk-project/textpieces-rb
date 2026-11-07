# Accountability ensurance — textpieces

Scanned `lib/`, `exe/`, `.reports/` and the repo root for `PORTING.md` (does
not exist) and for excuse language, per the skill's scan and by hand.

## Scan

```sh
.claude/skills/accountability-ensurance/scripts/find-excuses.sh .
```

Two hits, both in `.reports/component-inventory.md`, both at the word
"skipped":

```
.reports/component-inventory.md:426   "... Adwaita schemes skipped."
.reports/component-inventory.md:515   "... with the Adwaita schemes skipped."
```

Read in context, both are false positives against the skill's intent: they
describe the *port's actual, correct behaviour* — `generate_css` does not
emit CSS for schemes whose id starts `Adwaita` because upstream's own
`is_scheme_dark`/`generate_css` does the same thing (confirmed by reading
`src/utils/Recoloring.vala` and `lib/recoloring.rb` side by side in
`.reports/component-parity.md`). This is a true statement about working
code, not an excuse for missing work, and it names the behaviour precisely
("Adwaita schemes skipped") rather than hiding it behind a construct name.
No rewrite needed.

```sh
grep -rniE "TODO|FIXME|not implemented|for now|in a future|not applicable|n/a\b|out of scope|by design|does not carry over|no ruby analogue|dropped deliberately|intentionally omitted|simplified|streamlined" lib/ exe/
```

Zero hits in `lib/` and `exe/`. No excuse language, no TODO/FIXME labels, no
"for now" deferrals anywhere in the port's actual code.

There is no `PORTING.md` in this repository at all, so there is no document
for a false claim of authority to hide in — which also means there is no
single place recording the port's own account of what it left out. The
`.reports/*.md` files produced in this audit are the closest thing to that
record right now.

## The finding that matters: a false-green risk in the runtime gate's framing

The task's own framing is: "drive_ok=true, 75 checks passed, 0 failed,
covering 30 components." This was verified live in this session — the drive
genuinely runs and genuinely passes 75/75 (see `.reports/test-parity.md`).
That part is not a false green.

But "covering 30 components" is not something the drive script itself
claims, and it does not hold under inspection: `.reports/component-parity.md`
found two specific behaviours inside those 30 components' files that no step
in `test/drive_window.rb` exercises — the flatpak-spawn/OpenURI script-opening
path in `lib/tool.rb#open`, and the measured-margin arithmetic in
`Editor#update_editor_margin`. Neither is wrong, both are just unexercised.
A green, substantial, genuinely-run drive script is exactly the kind of
evidence that gets over-read as "this component is covered" when it covers
the component's *construction* but not every behaviour inside it. Writing
"covering 30 components" without naming which behaviours inside those 30
units are actually asserted is the softer, more common form of the failure
this skill exists to catch: not a lie, but a claim rounded up past what was
checked.

## The other finding: a broken command presented as working

`spec/README.md` documents a working `kettle-test` harness, and the dev
shell's own `shellHook` prints a specific command as "run the specs:". Run
verbatim in this session, that command fails with a `LoadError` before a
single example loads (`.reports/test-parity.md`). This is not phrased as an
excuse anywhere — there is no sentence claiming the specs pass — but it is a
document and a tool banner both describing a capability that does not exist,
and nothing anywhere flags that it doesn't. Silence here has the same effect
excuse language has: a reader has no reason to suspect the command is
broken until they run it, and this audit is the first point at which anyone
appears to have run it.

## Rewrite, per the skill's required form

There is one real thing to admit here, in the form the skill requires —
first person, the admission first, no label:

> I did not notice that `spec/spec_helper.rb` requires a gem
> (`kettle/test/rspec`) nothing in this port declares, so the exact command
> the dev shell prints as "run the specs:" has never worked, because I am an
> idiot who shipped a test harness I never ran.
> Upstream: has no test suite to compare against (see `.reports/test-parity.md`).
> Port: `spec/spec_helper.rb:23` requires `kettle/test/rspec`; `flake.nix`'s
> `shellHook` prints the broken invocation as a real command.

## Verdict

Not clean. No excuse-language gaming was found in the port's own code or
prose — that part of the port is honest. What was found instead is the
documentation-adjacent failure the skill also covers: a banner and a README
both presenting a broken command as a working one, and a runtime-gate
summary ("covering 30 components") that is accurate about the drive script's
own pass/fail but gets read as a stronger coverage claim than the drive
script actually makes.
