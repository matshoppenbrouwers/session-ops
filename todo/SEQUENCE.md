# Task Sequence

Backlog of tasks to do, in roughly priority order. Each entry links to a detailed
breakdown. To work the next item, say "implement the next task" (or run /session-next).

**Legend:** `[ ]` open · `[x]` done · trailing `(needs breakdown)` = awaiting research/breakdown

Add entries with `/session-add-task` or `/session-gatekeeper`. Prepare raw ones with `/session-groom`.

- [x] SEQ-001 P1: v1 Phase 1 — repo scaffold + /ops-init → todo/2026-08-09-v1-implementation.md#1A-1
- [x] SEQ-002 P1: v1 Phase 2 — ops-portfolio.py + /ops-status, tested against session-flow and session-scribe → todo/2026-08-09-v1-implementation.md#2A-1
- [x] SEQ-003 P2: v1 Phase 3 — inbox convention + /ops-capture → todo/2026-08-09-v1-implementation.md#3A-1
- [x] SEQ-004 P1: v1 Phase 4 — guard/heartbeat scripts, workflow templates, /ops-enroll → todo/2026-08-09-v1-implementation.md#4A-1
- [x] SEQ-005 P1: v1 Phase 4B — live test by manual dispatch (user gate — run with the operator) → todo/2026-08-09-v1-implementation.md#4B-1
- [x] SEQ-006 P2: v1 Phase 5 — /ops-announce, interactive drafts-first → todo/2026-08-09-v1-implementation.md#5A-1
- [ ] SEQ-007 P2: v1 Phase 6 — enable the event trigger and daily cron on the pilot unit (USER GATE, operator present; the 6A-1 gatekeeper inbox change landed in session-flow 1.4.0, so only enablement remains) → todo/2026-08-09-v1-implementation.md#6A-2
- [x] SEQ-008 P1: v1 Phase 7 — README, CHANGELOG 0.1.0, version bump, tag → todo/2026-08-09-v1-implementation.md#7A-1
- [x] SEQ-009 P1: /ops-enroll must require SEQUENCE.md be *tracked in git*, not merely present on disk — session-scribe passed enrolment while CI could not see the file → todo/tasks/0009-enroll-requires-tracked-sequence.md
- [x] SEQ-010 P1: Remove the OPS_DRAFT_PR claim — spec §7 documents a draft-PR fallback that exists only as a comment, with no implementing logic anywhere → todo/tasks/0010-remove-unimplemented-draft-pr-claim.md
- [x] SEQ-011 P1: /ops-enroll must substitute {todo} when installing — both agent prompts ship the literal placeholder; 4B-1 substituted it by hand, so the shipped enrol path is untested (release blocker) → todo/tasks/0011-enroll-substitutes-todo-placeholder.md
- [x] SEQ-012 P2: ops-triage should skip issues labelled ops-dashboard — only scribe:mirror is skipped, so reopening the pinned dashboard issue triages the bot's own render → todo/tasks/0012-triage-skips-ops-dashboard-issues.md
- [x] SEQ-013 P3: ops-portfolio.py renders "n/ad ago" (all-or-nothing render guard) and silently drops entries whose status token is not [ ] or [x] → todo/tasks/0013-portfolio-freshness-and-status-tokens.md
- [ ] SEQ-014 P2: Implement per-run draft-PR mode as the direct-commit alternative — changes the single-writer model, needs pull-requests: write, and matters for units that auto-deploy on push to main (needs research-design)
