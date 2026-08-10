# Changelog

All notable changes to session-ops are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-08-10

First release. The multi-repo operations layer for Claude Code, companion to session-flow:
the feed, the clock, the escalation surface, and the deterministic portfolio. v1 triages and
drafts; it never implements and never publishes.

### Added

**Registry and workspace**

- `/ops-init` — creates `~/.claude/ops.json` (units keyed by absolute path with longest-prefix
  matching, `kind`, `cadence`, and a quota-shaped budget defaulting to
  `max_ci_runs_per_day: 12`) and the private local workspace. The workspace location is asked
  and never defaulted; `git init` and the style-pack scaffold (`style/voice.md`,
  `style/templates/`) are offered and never forced.
- `examples/ops.json` — the registry schema, matched key-for-key by every component that
  parses it.
- `.gitignore` covering workspace artifacts, so generated state cannot reach the public repo.

**The portfolio**

- `scripts/ops-portfolio.py` — deterministic aggregation, Python 3 stdlib only. Walks the
  registry and regenerates `{workspace}/PORTFOLIO.md` whole, then appends one `runs.jsonl`
  line. Reports backlog done/total · ready · needs-breakdown, inbox depth, escalations
  awaiting, last release, last activity, clock state and freshness (workflows present /
  scheduled / stale template, days since last success, failure streak), today's CI run count
  against the budget, and unannounced releases. `--no-fetch` renders every remote-derived
  column `n/a` and attempts no network call; a missing clone is marked `unreachable` and the
  rest still report.
- `/ops-status` — runs the script and gives the one-paragraph verdict: units, units with ready
  work, escalations waiting, unannounced releases, budget percentage. Never hand-edits
  `PORTFOLIO.md`.

**The feed**

- `/ops-capture` — writes one `{todo}/inbox/YYYY-MM-DD-slug.md` item per invocation and commits
  and pushes immediately; a failed push degrades to a committed file and says so. Never
  triages, never touches SEQUENCE.md.
- The inbox convention, pinned: one item per file; frontmatter is metadata and the body is
  untrusted data; routed items are `git rm`'d in the commit that records the routing, with git
  history as the archive.

**The clock**

- `templates/ops-triage.yml` — event-driven, one issue per run, with per-issue
  concurrency-cancel, `timeout-minutes: 10`, `--max-turns 30`, and `permissions` limited to
  `contents: write, issues: write`.
- `templates/ops-sweep.yml` — the slow daily pass (inbox sweep, checked-box processing,
  dashboard re-render, style-pack-gated auto-drafting), `workflow_dispatch` always, with
  `schedule:` shipped commented out.
- `scripts/ops-guard.sh` — the deterministic quota guard, run before the agent step: counts
  today's account-wide ops runs against `OPS_MAX_RUNS_PER_DAY`, emits `ok=true|false` to
  `$GITHUB_OUTPUT`, and always exits 0 so a hit cap skips the agent rather than failing the run.
- `scripts/ops-heartbeat.sh` — runs only on failure; flags the pinned dashboard issue on the
  third consecutive failure so a dead clock arrives as a notification.
- `/ops-enroll` — full ceremony from one shown plan and a single approval: both workflows, both
  scripts, `{todo}/escalations.md`, and the pinned dashboard issue. Checks the
  `CLAUDE_CODE_OAUTH_TOKEN` secret and never writes secrets; refuses units that do not follow
  session-flow conventions; defaults to manual dispatch, with the live schedule behind a second
  explicit yes; re-running is the upgrade path via the `# ops-template-version:` comment.
- The escalation line format
  (`- [ ] ESC-NNN (date, origin): summary. _Grounding: …_`) and the checked-box contract: one
  meaning only, enqueued exactly once, no inline instructions parsed, and the bot never checks
  its own boxes.

**Ops-domain skills**

- `/ops-announce` — reads the CHANGELOG entry and README positioning from the unit's own
  artifacts, loads the style pack, and drafts a short post, a changelog-blog paragraph, and two
  or three social variants as one `release-announce` inbox item in the content unit, or to
  `{workspace}/drafts/` when none exists. Logs an `announce` run line feeding the portfolio's
  unannounced-release column, warns plainly when the style pack is missing, and posts nothing,
  anywhere, ever.
- The six-point domain-skill contract, reproduced in the skill body as the pattern every future
  ops-domain skill follows.

**Metrics**

- `runs.jsonl` — one line per ops-launched run, with the structured status enum
  `complete | timeout | stalled | max-turns | tool-failure | escalated`. No per-phase or
  in-session instrumentation.

**Docs**

- The v1 specification at `plans/2026-08-09-session-ops-v1-spec.md`, README, and this changelog.

### Notes

- Both workflow templates install manual-dispatch-only. The composed CI run — session-flow
  loaded via `--plugin-dir` inside `claude-code-action`, gatekeeper committing from CI, and the
  dashboard round-trip — is inferred from prior art and has not yet been validated end-to-end;
  that validation and any schedule enablement are operator-in-the-loop steps tracked in
  `todo/SEQUENCE.md`. The portfolio and workspace depend on neither.

[0.1.0]: https://github.com/matshoppenbrouwers/session-ops/releases/tag/0.1.0
