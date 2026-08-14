# SEQ-016: Portfolio counts the escalations format header as an open escalation

**Status**: [ ]
**Priority**: P2
**Sequence**: todo/SEQUENCE.md
**Origin**: SEQ-007 / 6A-2 enablement baseline, 2026-08-14

Every enrolled unit reports one escalation awaiting on an empty `escalations.md`,
forever, and `/ops-status`'s verdict inherits the off-by-one.

## The defect

`escalations_awaiting()` in `scripts/ops-portfolio.py` (line ~173):

```python
def escalations_awaiting(unit_path):
    esc = os.path.join(todo_dir(unit_path), "escalations.md")
    if not os.path.isfile(esc):
        return None
    with open(esc, encoding="utf-8") as f:
        return sum(1 for line in f if line.startswith("- [ ]"))
```

`/ops-enroll` Step 5.5 writes this header into every unit's `escalations.md` at
enrolment, and the fourth line of it is a literal unchecked checkbox documenting
the pinned format:

```markdown
# Escalations

Bot-owned. Every line uses the pinned format:

- [ ] ESC-NNN (date, origin): summary. _Grounding: …_
```

So the count starts at 1 on a file with nothing in it, and never returns to 0.

**Reproduced on the pilot at the 6A-2 baseline.** `frameworkreboot/cropfolio-rep`'s
`escalations.md` holds the header and nothing else — the sweep cleared ESC-001 in
run 31687191102 the day before. The portfolio still rendered:

```
| per-cropfolio | code | 0/3 | 1 | 2 | — | 1 | — | 2026-08-14 | triage+sweep (scheduled) | 0d ago · streak 0 | — |
                                              ^ Escalations
```

The same sweep's dashboard render read `_No open escalations._` — the agent judges
the file correctly; only the script miscounts. That divergence is the tell: the
phone-visible surface and the portfolio disagree about the same file.

## Why it matters more than one wrong digit

`/ops-status`'s verdict line is the product's headline output ("7 units, 2 with ready
work, **3 escalations waiting**, …"). A permanent floor of one-per-unit means the
number is never trustworthy and never actionable — the operator cannot tell a unit
with one real escalation from a unit with none, which is exactly the discrimination
the column exists to make. It also scales with enrolment: ten units, ten phantoms.

## Fix

Tighten the match to the pinned format's numbered form. Add a module-level regex
alongside the existing ones (lines 42–45) and use it in the counter:

```python
ESCALATION_RE = re.compile(r"^- \[ \] ESC-\d+\b")
```

Real entries are numbered (`ESC-001`, `ESC-014`); the header's placeholder is the
literal string `ESC-NNN`, which `\d+` cannot match. That is the precise
discriminator, and it needs no change to any already-written file.

Keep counting only `- [ ]` and not `- [x]`: a ticked box is consumed by the next
sweep, so "awaiting" means unticked, which is correct as written.

## Considered and rejected

**Changing the header `/ops-enroll` writes** (fencing the example, or dropping the
checkbox). It does not fix the units already enrolled — their `escalations.md` is on
disk with the header in it — so the script fix is needed regardless, and doing both
would leave new units' headers diverging from existing ones for no gain. The example
line is deliberate documentation of the format the bot must follow; it stays.

## Files

- `scripts/ops-portfolio.py`
- `scripts/test-escalation-count.sh` (new)
- `README.md` (only if it states the escalation-counting rule)

## Instructions

- Add `ESCALATION_RE` to the module-level regex block (lines 42–45), matching the
  existing `ENTRY_RE` / `LINK_RE` naming and placement.
- Use it in `escalations_awaiting()` in place of the `startswith("- [ ]")` test.
  Leave the `None` return for a missing file alone — that is the `—` cell, and it is
  distinct from a present-but-empty file, which must now read `0`.
- Write `scripts/test-escalation-count.sh` following `scripts/test-skip-ci.sh`'s
  shape (`set -uo pipefail`, the `check` helper, numbered sections). Build fixture
  `escalations.md` files in a `mktemp -d` and assert the count for each:
  - header only → `0`
  - header + one real `- [ ] ESC-001 (…)` line → `1`
  - header + one real + one `- [x] ESC-002 (…)` → `1`
  - no file at all → `—` in the rendered cell (not `0`)
- Do not re-enrol any unit and do not touch `/ops-enroll`'s header text.

## Accept

A unit whose `escalations.md` contains only the format header renders `0` in the
Escalations column; one real open entry renders `1`; a ticked entry is not counted;
a unit with no escalations file still renders `—`. The pilot's live row drops from
`1` to `0` without its file changing.

## Test

```bash
bash scripts/test-escalation-count.sh
```

Plus the live regression on the pilot, which needs no fixture:

```bash
python3 scripts/ops-portfolio.py --no-fetch \
  && grep -q "| per-cropfolio | code |" ~/Desktop/repositories/ops-workspace/PORTFOLIO.md \
  && python3 -c "
import re,sys
row = [l for l in open('/mnt/c/Users/matsh/Desktop/repositories/ops-workspace/PORTFOLIO.md') if '| per-cropfolio |' in l][0]
esc = [c.strip() for c in row.split('|')][7]
assert esc == '0', f'expected 0 escalations, got {esc!r}'
print('PASS: pilot renders 0 escalations on a header-only file')"
```
