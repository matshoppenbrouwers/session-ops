# SEQ-020: The sweep's checked-box enqueue carries the [auto] marker

**Status**: [x]
**Priority**: P3
**Sequence**: SEQUENCE.md
**Research**: ../session-scribe/_devdocs/research/2026-08-14-three-plugin-alignment.md (§3.6 conflict C4)

## Context

`[auto]` marks an entry enqueued by a bot rather than the user; session-flow's `/session-next`
never lets a marked entry outrank a manual one at equal priority. The triage path gets the
marker for free — the gatekeeper is its shipped setter. The sweep's step 2 (checked dashboard
box → SEQUENCE entry) invokes add-task *directly*, and the prompt gives no auto-provenance
instruction — so a bot-enqueued entry arrives unmarked and defeats the ordering rule the marker
exists for. (The user ticked the box, but the enqueue itself is unattended; the ticked
escalation line and the rendered dashboard are where the user saw it.)

## Task

**Files**: `templates/ops-sweep.yml`

**Instructions**:
- In the sweep prompt's step 2, instruct that the add-task enqueue set the auto-provenance flag
  (`[auto]` after the priority), same visibility rule as the triage path.
- Bump the `# ops-template-version:` comment so `/ops-status` flags stale installs; re-running
  `/ops-enroll` is the documented upgrade path.

**Accept**: the sweep prompt names `[auto]` for the checked-box enqueue; the template version
comment is bumped.

**Test**: `grep -c 'auto' templates/ops-sweep.yml` — expect ≥1 — and `grep 'ops-template-version' templates/ops-sweep.yml` shows the bumped version.
