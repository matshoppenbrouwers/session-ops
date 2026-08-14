# SEQ-021: Decide whether the dashboard links the unit's agent-log issue

**Status**: [x]
**Decision**: yes — the dashboard body carries one baked agent-log link line when scribe.json maps the unit at enroll time. Chosen by the operator 2026-08-14.
**Priority**: P3
**Sequence**: SEQUENCE.md
**Research**: ../session-scribe/_devdocs/research/2026-08-14-three-plugin-alignment.md (§3.2)

## Context

The portfolio answers "what needs attention"; nothing phone-visible answers "what happened
lately" — session-scribe's agent-log issue does, but the pinned dashboard doesn't point at it.
The review's verdict kept the two bot-owned issues separate (distinct roles, correct as built)
and left this as the one enhancement worth deciding: one line in the dashboard body linking the
unit's log issue. Constraint: CI cannot read `scribe.json`, so the link must be baked at enroll
time like every other env value.

## Task

**Files**: `skills/ops-enroll/SKILL.md`, `templates/ops-sweep.yml`, `README.md`

**Instructions**:
- Decide yes or no with the operator.
- If yes: at enroll, read the unit's `scribe.json` project block for `github.log_repo` +
  `github.log_issue` (skip silently when absent), write the link as one line in the dashboard
  issue body it creates, and amend the sweep prompt's rewrite step to preserve that line; bump
  the template version.
- If no: record the decision and its reason in README where the dashboard is described, so the
  next review doesn't re-open it.

**Accept**: enrolling a scribe-logged unit yields a dashboard whose body links the log issue, or
README records the decision not to.

**Test**: `grep -in 'log issue' skills/ops-enroll/SKILL.md README.md | wc -l` — expect ≥1.
