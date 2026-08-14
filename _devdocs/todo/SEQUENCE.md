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
- [ ] SEQ-007 P2: v1 Phase 6 — enable the event trigger and daily cron on the pilot unit. ENABLED 2026-08-14 on cropfolio-rep (`52bf1b1`, after the v9/v7 upgrade `78e1299` and a green dispatch-verify); stays open for the one-week watch, due 2026-08-21 — `/ops-status` daily, then decide on widening enrolment → todo/2026-08-09-v1-implementation.md#6A-2
- [x] SEQ-008 P1: v1 Phase 7 — README, CHANGELOG 0.1.0, version bump, tag → todo/2026-08-09-v1-implementation.md#7A-1
- [x] SEQ-009 P1: /ops-enroll must require SEQUENCE.md be *tracked in git*, not merely present on disk — session-scribe passed enrolment while CI could not see the file → todo/tasks/0009-enroll-requires-tracked-sequence.md
- [x] SEQ-010 P1: Remove the OPS_DRAFT_PR claim — spec §7 documents a draft-PR fallback that exists only as a comment, with no implementing logic anywhere → todo/tasks/0010-remove-unimplemented-draft-pr-claim.md
- [x] SEQ-011 P1: /ops-enroll must substitute {todo} when installing — both agent prompts ship the literal placeholder; 4B-1 substituted it by hand, so the shipped enrol path is untested (release blocker) → todo/tasks/0011-enroll-substitutes-todo-placeholder.md
- [x] SEQ-012 P2: ops-triage should skip issues labelled ops-dashboard — only scribe:mirror is skipped, so reopening the pinned dashboard issue triages the bot's own render → todo/tasks/0012-triage-skips-ops-dashboard-issues.md
- [x] SEQ-013 P3: ops-portfolio.py renders "n/ad ago" (all-or-nothing render guard) and silently drops entries whose status token is not [ ] or [x] → todo/tasks/0013-portfolio-freshness-and-status-tokens.md
- [x] SEQ-015 P2: Bot commits end with `[skip ci]` so a direct push cannot fire a unit's deploy — resolves SEQ-014's original driver deterministically, without a branch, a PR, or `pull-requests: write` → research/2026-08-13-ops-draft-pr-mode.md
- [x] SEQ-016 P2: `ops-portfolio.py` counts the escalations format-header example as an open escalation — `escalations_awaiting()` sums every `- [ ]` line, and `/ops-enroll` writes `- [ ] ESC-NNN (date, origin): summary` into the header of every unit's `escalations.md`, so an empty file reads as 1 awaiting on every unit forever and `/ops-status`'s verdict is permanently off by one → todo/tasks/0016-portfolio-phantom-escalation-count.md
- [x] SEQ-014 P4: Draft-PR mode for the one case `[skip ci]` cannot reach — a protected `main` that forbids direct pushes. BLOCKED ON EVIDENCE: do not implement until an enrolled unit actually has one (Appendix C's posture). Design is done, not the build → research/2026-08-13-ops-draft-pr-mode.md
- [x] SEQ-017 P2: Honor CLAUDE_CONFIG_DIR when resolving the registry → todo/tasks/0017-honor-claude-config-dir.md
- [x] SEQ-018 P3: Decide the registry cross-read with scribe.json → todo/tasks/0018-registry-cross-read-decision.md
- [ ] SEQ-019 P3: Add the session-scribe degradation row and the combined-notification note → todo/tasks/0019-degradation-table-scribe-row.md
- [ ] SEQ-020 P3: Sweep checked-box enqueue carries the auto-provenance marker → todo/tasks/0020-sweep-enqueue-carries-auto.md
- [ ] SEQ-021 P3: Decide whether the dashboard links the unit's agent-log issue → todo/tasks/0021-dashboard-links-log-issue.md
