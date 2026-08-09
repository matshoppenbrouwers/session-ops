# session-ops

Multi-repo operations layer for Claude Code, companion to [session-flow](https://github.com/matshoppenbrouwers/session-flow).

session-flow owns routing and judgement inside a repo; session-ops owns the feed, the clock, and metrics across repos — plus the multi-repo portfolio, the one thing session-flow structurally cannot see. A managed unit is any repo following session-flow conventions (`.session-flow.json`, a SEQUENCE.md, a direction doc) — not "a codebase", so a marketing or website repo enrolls exactly like a software repo. The design metric is decisions-per-day, not items-triaged: cadence defaults are daily, escalations batch into one surface, trivial enqueues cost zero decisions, and enrolling a repo is treated as taking on an oversight liability, not free throughput. v1 triages and drafts; it never implements or publishes.

> 🚧 **Under construction.** v1 is being built — see `plans/2026-08-09-session-ops-v1-spec.md` for the specification and `todo/SEQUENCE.md` for progress.
