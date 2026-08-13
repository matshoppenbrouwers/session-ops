# SEQ-013: Portfolio renders `n/ad ago`, and drops entries with other status tokens

**Status**: [ ]
**Priority**: P3
**Sequence**: todo/SEQUENCE.md
**Origin**: SEQ-005 / 4B-1 live test, 2026-08-13

Two independent bugs in `scripts/ops-portfolio.py`, both reproduced. The second is
not what the original one-line entry claimed — groom corrected it.

## Bug A — `n/ad ago` in the freshness column

Observed in a real render:

```
| session-scribe | code | 23/23 | … | n/ad ago · streak 0 | yes (0.2.0) |
```

`freshness()` (line ~306) returns `days = NA` when no successful run is found, but
`streak` is always a real integer (initialised `0` at line 322). The render guard at
line ~436 is:

```python
f"{days}d ago · streak {streak}" if days != NA or streak != NA else NA,
```

With `days = "n/a"` and `streak = 0`, the first disjunct is false but the second is
true, so the f-string renders and concatenates the `d ago` suffix onto the literal
`n/a`. Reproduced exactly:

```
python3 -c "NA='n/a'; days,streak=NA,0; print(f'{days}d ago · streak {streak}' if days!=NA or streak!=NA else NA)"
→ n/ad ago · streak 0
```

The guard is all-or-nothing across two fields that fail independently.

## Bug B — entries with a non-`[ ]`/`[x]` status vanish from every count

`ENTRY_RE = re.compile(r"^- \[( |x)\] (.*)$")` (line 43) accepts only a space or `x`.
A real line in session-scribe's backlog:

```
- [DEFERRED] SEQ-024 P3: Three-plugin alignment review — …
```

matches none of it, so the entry is counted in **neither** total, ready, nor
needs-breakdown. It is silently invisible in the portfolio. Verified: 32 lines begin
`- [`, 31 match `ENTRY_RE`.

(The original entry described this as "counts 23 of 24". That number came from a
looser grep and is not the real behaviour — the defect is dropped status tokens, not
an off-by-one.)

## Files

- `scripts/ops-portfolio.py`

## Instructions

- **Bug A**: render the two fields independently — emit `NA` for the days half when
  days is `NA`, without the `d ago` suffix, while still showing a known streak. A
  cell like `n/a · streak 0` is honest; `n/ad ago` is not. Check the other columns
  for the same all-or-nothing guard pattern and fix any that share it.
- **Bug B**: decide and document how a non-standard status token is treated. Counting
  it in `total` but neither `ready` nor `needs` is the option consistent with
  session-status Step 2b, which defines total as "entries" rather than "open plus
  done". Whatever is chosen, an entry must never disappear from all three counts —
  silent omission from the portfolio is the failure mode being fixed.
- Widen `ENTRY_RE` to capture the token (e.g. `^- \[([^\]]*)\] (.*)$`) and branch on
  its value, so the regex stops being the thing that silently filters.
- Keep the module stdlib-only, per 2A-1.

## Accept

A sequence containing `- [ ]`, `- [x]` and `- [DEFERRED]` entries counts all three,
with the deferred one visible somewhere in the row; a unit with no successful run
renders a freshness cell containing no `n/ad`.

## Test

`python3 -c "
import re
src = open('scripts/ops-portfolio.py', encoding='utf-8').read()
assert 'n/ad' not in src
m = re.search(r'ENTRY_RE\s*=\s*re\.compile\((.*)\)', src)
assert '( |x)' not in m.group(1), 'ENTRY_RE still only accepts space or x'
print('PASS')
"`

Then render against a fixture sequence containing all three token types and confirm
the counts add up and no cell reads `n/ad ago`.
