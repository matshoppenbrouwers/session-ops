# SEQ-010: Remove the `OPS_DRAFT_PR` claim — it has no implementation

**Status**: [x]
**Priority**: P1
**Sequence**: todo/SEQUENCE.md
**Origin**: SEQ-005 / 4B-1 live test, 2026-08-13

## Context (read first)

Both templates carry this, and it reads as a supported escape hatch:

```yaml
#   # OPS_DRAFT_PR: "true"  # per-run draft PRs instead of direct commits
```

Spec §7 (line 133) presents it as the standing answer to commit collisions — *"the
fallback is per-run draft PRs (a config flag in the template), not a redesign"* —
and `ops-enroll`'s SKILL.md repeats it.

`grep -rn "OPS_DRAFT_PR" templates/ scripts/ skills/` returns **two comment lines and
nothing else**. There is no implementing logic anywhere. Uncommenting the flag has no
effect whatsoever.

This surfaced during 4B-1 while assessing per-cropfolio, a repo that auto-deploys to
Vercel on every push to `main`. Direct bot commits there trigger production
deployment attempts, and draft-PR mode is precisely the mitigation that situation
calls for — so the gap was found at the exact moment the feature was needed.

**This task is the documentation fix only.** Actually building draft-PR mode is
tracked separately (see SEQ-014) because it changes the single-writer model, needs
`pull-requests: write`, and warrants a research-design session.

## Files

- `templates/ops-triage.yml`
- `templates/ops-sweep.yml`
- `skills/ops-enroll/SKILL.md`
- `plans/2026-08-09-session-ops-v1-spec.md`

## Instructions

- Delete the `# OPS_DRAFT_PR: "true"` comment block from both templates, including
  the "Optional fallback (spec §7)" preamble above it that explains how to flip it on.
- In spec §7 (~line 133), replace the claim that the fallback *is* a config flag with
  an accurate statement: per-run draft PRs are the intended fallback if direct commits
  collide, and they are **not implemented** — tracked as SEQ-014.
- Remove or correct any matching claim in `skills/ops-enroll/SKILL.md`.
- Bump `# ops-template-version:` in both templates (currently triage 6, sweep 5) so
  `/ops-status` flags existing installs as stale.
- Do not add a stub implementation or a flag that logs "not supported" — the point is
  that the templates stop advertising something that does not exist.

## Accept

No file under `templates/`, `skills/` or `scripts/` mentions `OPS_DRAFT_PR` as an
available option; the spec names it as unimplemented future work pointing at SEQ-014.

## Test

`! grep -rq "OPS_DRAFT_PR" templates/ skills/ scripts/ && grep -q "SEQ-014" plans/2026-08-09-session-ops-v1-spec.md`
