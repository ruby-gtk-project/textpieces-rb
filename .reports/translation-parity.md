# Translation parity — textpieces

| | |
|---|---|
| Upstream | `main` @ `6a6c41e` |
| Port | `ruby` @ `ac79adc` |
| Domain | `textpieces` (po files copied unchanged; `lib/translation.rb` reads `.po` directly, no `.mo`/gettext runtime dependency) |
| Upstream messages | 237 distinct `(ctxt, id)` keys (233 reach a `.po`; 1 is a dynamic/unresolved call; 3 live only in AppStream metainfo the port does not ship) |
| Ported (key present in the port's catalogue) | 233 |
| Gaps | 4 |
| Extra | 0 |
| Languages | 3 — `es`, `nl`, `pt_BR` — all 3 shipped by the port, `LINGUAS` identical |
| Plurals | 0 upstream (`ngettext`/`n_` do not appear anywhere in `src/`) — so the port's `translation.rb` silently discarding `msgid_plural` lines costs nothing *today*, see Finding below |

## Census

```
scripts/msgid-census.sh <upstream> | wc -l   -> 1130 rows (237 distinct keys)
scripts/msgid-census.sh <port>     | wc -l   -> 1009 rows (233 distinct keys)
comm -23 up.keys port.keys | wc -l            -> 4   (gaps)
comm -13 up.keys port.keys | wc -l            -> 0   (extra)
```

### The 4 gaps

Three are AppStream metainfo description text, all from
`data/com.github.liferooter.textpieces.appdata.xml.in`:

| msgid | Source |
|---|---|
| `Powerful scratchpad with ability to perform a lot of text transformations, such as:` | `data/com.github.liferooter.textpieces.appdata.xml.in` |
| `The application is extendable with your own script-based actions.` | same |
| `And so on.` | same |

The port ships **no `data/` metainfo or `.desktop` file at all** — confirmed
by `find . -iname '*appdata*' -o -iname '*metainfo*' -o -iname '*.desktop*'`
returning nothing. This is simultaneously a translation gap (3 strings) and a
component gap (no AppStream entry, no desktop launcher entry, so the app has
no discoverable name/comment/keywords in a shell that reads `.desktop`
files — which is also where `Name`, `GenericName`, `Comment`, `Keywords`
would contribute their own msgids were the file present).

The fourth is `!unresolved`: `src/widgets/preferences/ToolSettings.vala:60`
calls `_(name)` on a variable, not a literal — upstream translating a tool's
own name string generically. The port's actual handling of per-tool
name/description translation (`Translation.tools`, `dpgettext2`-equivalent
over the `"tools"` context) is correct and verified by reading
`lib/tool.rb:115-117`; this row is a census artifact of a dynamic call, not
a missed string, and is recorded here rather than silently dropped per the
skill's rule on `!unresolved` rows.

## Finding: the generic scanner cannot see the port's own marker convention

Re-run with the kind column broken out:

```
upstream kind=single/plural (source-derived) : 109
port     kind=single/plural (source-derived) : 0
```

**Zero.** The port's house convention is `Translation.t(msgid)` and
`Translation.tools(msgid)` (`lib/translation.rb`), neither of which is in the
marker set `msgid-census.sh` recognises (`_`, `N_`, `C_`, `NC_`, `ngettext`,
`n_`, `Nn_`, `p_`, `np_`, `s_`, `pgettext`, `gettext`, `dgettext`,
`dpgettext2`, …). The 233 "ported" keys above are reached *entirely* through
the `.po` files the port copied byte-for-byte from upstream — the scanner
never found a single call site in `lib/`. That means the key-set match is
real (the catalogue is a faithful copy) but it is **not independent proof**
that the Ruby source actually invokes the right key at every site; that
claim rests on this report's own manual check, not the generic tooling:

```sh
grep -noE '\.(title|label|text|subtitle|tooltip_text) *= *"[^"]+"' lib/*.rb | grep -v 'Translation\.'
# -> no output: every such literal assignment in lib/ is empty
grep -c 'Translation\.t(' lib/*.rb | grep -v ':0'
# -> 11 files call it, 61 call sites total
```

So the strings genuinely do route through the translation layer — this was
checked by reading, not inferred from the scanner's silence — but the
scanner limitation itself is real and should be reported upstream to the
skill (its marker list needs `Translation.t`/`Translation.tools` added, or
this port's whole catalogue match is coincidental rather than demonstrated).
Per the skill's own rule ("fix the scanner... or state the discrepancy"),
this is stated rather than worked around silently.

## Languages

```
diff <(ls po/*.po | xargs -n1 basename -s .po | sort) <(sort LINGUAS from upstream, comments stripped)
-> no difference: es, nl, pt_BR on both sides
```

Not independently re-verified: the per-language translated/untranslated/fuzzy
string *counts* (upstream vs. port) were not recomputed in this pass — the
files are byte-identical copies (confirmed `diff -q` on all three `.po`s
below), so the counts are necessarily equal, but this is inference from the
copy being unmodified, not a fresh count:

```sh
diff -q po/es.po     /tmp/parity/upstream/po/es.po
diff -q po/nl.po     /tmp/parity/upstream/po/nl.po
diff -q po/pt_BR.po  /tmp/parity/upstream/po/pt_BR.po
```
(all three: identical, confirmed in this session)

## Not run

- `msgfmt -c` validation of any catalogue (not installed in the checked
  environment; not attempted — named here as unrun rather than silently
  skipped).
- Running the app under `LANGUAGE=es` or `LANGUAGE=nl` and asserting a known
  translated string on screen. `lib/translation.rb`'s own catalogue-selection
  logic was read and looks correct (LC_ALL/LC_MESSAGES/LANG priority, region
  fallback), but it was not driven live in a non-English locale in this
  pass.

## Verdict

**Not clean.** 233/237 messages ported (98%), 3/3 languages shipped
byte-identical, 0 reworded strings found — this is a strong result and
clearly deliberate work, not an oversight. But: 4 open gaps (all tied to the
same missing metainfo/desktop file), the generic scanner cannot actually see
the port's marker convention (so the catalogue match, while correct on
manual inspection, is not demonstrated by the tooling the way the skill
expects), and the live non-English run was not performed. "Fully localised"
is not claimed here; the numbers above are.
