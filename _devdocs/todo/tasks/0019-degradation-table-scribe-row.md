# SEQ-019: Add the session-scribe row to the degradation table, plus the combined-notification note

**Status**: [x]
**Priority**: P3
**Sequence**: SEQUENCE.md
**Research**: ../session-scribe/_devdocs/research/2026-08-14-three-plugin-alignment.md (§3.3, §4)

## Context

README's degradation table (`README.md:149-160`) covers session-flow absence, unreachable
clones, and workspace states, but has no session-scribe row — the scribe-absence claim lives
only in the spec (`plans/2026-08-09-session-ops-v1-spec.md:44`), and the `scribe:mirror` triage
skip is the one place ops actively handles scribe's presence. Separately, no doc anywhere states
the *combined* notification picture for a repo running all three plugins.

## Task

**Files**: `README.md`

**Instructions**:
- Add a `session-scribe absent` row to the degradation table: the triage skip's label check
  simply never matches; nothing else references scribe.
- Add one short paragraph near the notification/quota discussion naming the combined picture for
  a repo that is enrolled, mirrored, and session-logged: scribe's per-session log comments
  dominate; ops' recurring writes are `[skip ci]` commits and dashboard *body edits*, neither of
  which notifies watchers; the notification-bearing ops events are enroll's issue creation and
  the heartbeat's one line per outage. Link session-scribe's README known-limitation for the
  log-repo side.

**Accept**: the degradation table has a session-scribe row and the combined-volume paragraph
exists with the cross-link.

**Test**: `grep -c 'session-scribe' README.md` — expect ≥2 (table row + paragraph).
