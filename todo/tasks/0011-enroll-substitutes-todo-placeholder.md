# SEQ-011: `/ops-enroll` must substitute `{todo}` when installing

**Status**: [ ]
**Priority**: P1 (raised from P2 — this is a release blocker, see below)
**Sequence**: todo/SEQUENCE.md
**Origin**: SEQ-005 / 4B-1 live test, 2026-08-13

## Context (read first)

Both templates carry a literal `{todo}` placeholder inside the agent prompt:

```
templates/ops-sweep.yml:74    1) /session-gatekeeper sweep {todo}/inbox/ …
templates/ops-triage.yml:83   … ({todo}/escalations.md) and commit …
```

`/ops-enroll` Step 5 bakes `OPS_MAX_RUNS_PER_DAY`, `OPS_ENROLLED_REPOS`,
`OPS_DASHBOARD_ISSUE` and the cadence — and never mentions `{todo}`. So an install
produced by the shipped skill sends CI a prompt that literally reads
`sweep {todo}/inbox/`.

**This is why the task is a release blocker.** 4B-1 substituted the placeholder by
hand before installing, so every passing check in that test ran against a
hand-patched install. The path a real user takes has never been executed. The
plausible failure is not a clean error but the agent creating a directory literally
named `{todo}` and committing into it.

The rationale is identical to the env values: CI cannot read `~/.claude/ops.json`,
and while `.session-flow.json` *is* in the checkout, relying on the agent to resolve
the placeholder makes correctness depend on inference where a substitution is exact.

## Files

- `skills/ops-enroll/SKILL.md`

## Instructions

- Add `{todo}` substitution to Step 5's copy operation, next to the existing env
  baking, so the two live in one place: when copying each template, replace every
  `{todo}` with the unit's resolved todo path (from `.session-flow.json`
  `paths.todo`, defaulting to `_devdocs/todo`) — the same value Step 1 already
  resolves.
- State the reason in one line, matching the existing note on the env values: the
  placeholder must be resolved at install time so the prompt CI receives names a
  real path.
- Add a post-install verification line: no `{todo}` may remain anywhere under
  `.github/` after the copy. A leftover placeholder is a failed install, not a
  warning.
- Leave the templates themselves unchanged — `{todo}` is the correct thing for a
  template to carry; the defect is that nothing resolves it.

## Accept

A fresh `/ops-enroll` produces `.github/workflows/*.yml` containing the unit's real
todo path and no `{todo}` anywhere, without hand-editing.

## Test

`grep -q "{todo}" skills/ops-enroll/SKILL.md && grep -qi "substitut" skills/ops-enroll/SKILL.md`

End-to-end (the check that actually matters): install session-ops as a plugin, run
`/ops-enroll` against a private test repo, then
`! grep -rq "{todo}" <repo>/.github/`
