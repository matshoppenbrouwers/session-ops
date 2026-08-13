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
- [ ] SEQ-007 P2: v1 Phase 6 — gatekeeper inbox PR + trigger enablement (blocked by session-flow SEQ-001) → todo/2026-08-09-v1-implementation.md#6A-1
- [x] SEQ-008 P1: v1 Phase 7 — README, CHANGELOG 0.1.0, version bump, tag → todo/2026-08-09-v1-implementation.md#7A-1
- [ ] SEQ-009 P1: /ops-enroll must require SEQUENCE.md be *tracked in git*, not merely present on disk — session-scribe passed enrolment while CI could not see the file (needs breakdown)
- [ ] SEQ-010 P1: Implement OPS_DRAFT_PR, or drop the claim — spec §7 documents a draft-PR fallback that exists only as a comment in both templates, with no implementing logic anywhere (needs breakdown)
- [ ] SEQ-011 P2: /ops-enroll must substitute {todo} when installing — both agent prompts ship the literal placeholder; 4B-1 substituted it by hand (needs breakdown)
- [ ] SEQ-012 P2: ops-triage should skip issues labelled ops-dashboard — only scribe:mirror is skipped, so reopening the pinned dashboard issue triages the bot's own render (needs breakdown)
- [ ] SEQ-013 P3: ops-portfolio.py freshness column renders "n/ad ago" (string concat bug) and counts 23 of 24 SEQUENCE entries (needs breakdown)
