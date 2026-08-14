# Changelog

All notable changes to session-ops are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] — 2026-08-14

The three-plugin alignment release: every remaining finding from the 2026-08-14
session-flow / session-scribe / session-ops review, landed. Both templates moved
(triage v10, sweep v9) — re-run `/ops-enroll` on enrolled units to pick them up;
the portfolio flags a stale install.

### Fixed

- `ops-triage` skips issues labelled `scribe:log` (`ops-triage.yml` template version 10).
  session-scribe's `SessionEnd` hook comments on one agent-log issue per repo; if that log repo is
  itself an enrolled unit, opening or reopening the issue fired a triage run that read a work log —
  "what was asked, what was done, what is still open" — as a human's intake request. Companion to
  session-scribe's SEQ-035, which labels the issue at creation.
- The registry resolves as `ops.json` in the Claude config directory — `$CLAUDE_CONFIG_DIR` if
  set, else `~/.claude` — in `ops-portfolio.py`'s `--registry` default and all five skills,
  mirroring session-scribe's rule for `scribe.json` so the two registries always share a
  directory. Previously hardcoded to `~/.claude/ops.json`, which put them in different
  directories on any machine that sets the variable (SEQ-017).
- The sweep's checked-box enqueue carries the `[auto]` provenance marker (`ops-sweep.yml`
  template version 8). Step 2 invokes add-task directly, bypassing gatekeeper's shipped
  `[auto]` setter, so a bot-enqueued entry arrived unmarked and could outrank a manual entry
  at equal priority in `/session-next` — defeating the ordering rule the marker exists for
  (SEQ-020).

### Added

- `/ops-init` prefills a new unit's `repo` from `scribe.json`'s `projects.<path>.github.repo`
  when the path is registered there. scribe.json is the senior source for the path→`owner/name`
  fact; the duplication stays deliberate — a registration-time prefill, never a runtime
  dependency (SEQ-018).
- The pinned dashboard issue links the unit's session-scribe agent-log issue (`ops-sweep.yml`
  template version 9): baked at enroll from `scribe.json`'s `github.log_repo` + `github.log_issue`,
  skipped silently when unmapped, preserved verbatim by every sweep rewrite — "what happened
  lately" one tap from "what needs attention" (SEQ-021).
- README documents the session-scribe degradation row and the combined notification picture
  for a repo running all three plugins: scribe's per-session comments dominate; ops' recurring
  writes are `[skip ci]` commits and dashboard body edits, which notify no one (SEQ-019).

## [0.2.0] — 2026-08-14

The release where the clock actually ran. 0.1.0 shipped a CI path inferred from prior art
and said so; everything below is what it took to make that path execute end-to-end, plus the
defects the first real runs exposed. One unit has been on a live schedule since 2026-08-14.
Templates still install manual-dispatch-only for everyone — that default has not moved.

### Fixed

**The CI path — none of this was reachable by inspection**

- `actions: read` granted in both workflows. Without it `ops-guard.sh` could not list runs and
  failed closed on *every* run, so the agent step never executed.
- `id-token: write` granted — `claude-code-action` needs OIDC.
- The agent prompts named GitHub MCP tools that do not exist; replaced with the real names.
- The prompts committed but never pushed, silently discarding the work of a whole run.
- Line endings pinned to LF, so a CRLF checkout cannot break the shell scripts.

**Defects the live runs and the enablement baseline exposed**

- `/ops-enroll` now requires the sequence layer to be **tracked in git**, not merely present on
  disk — a unit could pass enrolment while CI could not see the file (SEQ-009).
- `/ops-enroll` substitutes `{todo}` when installing. Both agent prompts shipped the literal
  placeholder, so the shipped enrol path had never been exercised as written (SEQ-011).
- `ops-triage` skips issues labelled `ops-dashboard`. Only `scribe:mirror` was skipped, so
  reopening the pinned dashboard issue fed the bot its own render (SEQ-012).
- The portfolio's freshness cell renders each half independently — a unit with no successful
  run reads `n/a · streak 3`, not the fabricated `n/ad ago` — and no longer drops SEQUENCE
  entries whose status token is neither `[ ]` nor `[x]`; they count in `total` and report as
  `· N other` (SEQ-013).
- Escalations are counted by their **numbered** form (`- [ ] ESC-014`). The format example
  `/ops-enroll` writes into every unit's `escalations.md` header was being scored as a real
  escalation, so an empty file read as one awaiting, on every unit, permanently — and
  `/ops-status`'s verdict inherited the off-by-one (SEQ-016).

### Changed

- **Bot commits end with `[skip ci]`**, so an ops push cannot fire a unit's deploy workflow.
  This resolves the driver behind draft-PR mode deterministically, with no branch, no PR, and
  no `pull-requests: write` scope. `/ops-capture` carries the same rule, since it also pushes
  to a unit's default branch. The `/ops-enroll` install commit is the documented exception:
  it is attended. Platform-side git integrations (Vercel and similar) are not governed by
  `[skip ci]` in any case (SEQ-015).
- `ops-triage.yml` at template version 9, `ops-sweep.yml` at 7. Re-run `/ops-enroll` on an
  enrolled unit to upgrade; the portfolio flags a stale install until you do.
- The unimplemented `OPS_DRAFT_PR` fallback is gone from spec §7 — it existed only as a
  comment, with no implementing logic anywhere (SEQ-010).
- Triage skips session-scribe's mirrored issues, so the two plugins do not triage each other's
  bookkeeping.

### Added

- `scripts/test-skip-ci.sh` and `scripts/test-escalation-count.sh` — acceptance suites for the
  two behaviours most likely to regress silently.
- The 4B-1 live-test verdict and the 6A-2 enablement record, both with run ids and evidence,
  in `todo/2026-08-09-v1-implementation.md`.

### Notes

- **The composed CI run is now validated**, which is the claim 0.1.0 explicitly declined to
  make: session-flow loaded via `--plugin-dir` inside `claude-code-action`, gatekeeper
  committing from CI, and the dashboard round-trip all passed on 2026-08-13.
- One pilot unit runs `ops-sweep` on `0 6 * * 1-5`; its one-week watch closes 2026-08-21.
  Widening enrolment is a decision to be made after it, not a consequence of this release.
  Attention, not tokens, is the binding constraint (spec §12).
- The `0.1.0` git tag was never cut — the shipping session got `HTTP 403` on `refs/tags/*`.
  `0.2.0` is therefore this repository's first tag; 0.1.0 remains identifiable by its commits.

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

[0.2.0]: https://github.com/matshoppenbrouwers/session-ops/releases/tag/v0.2.0
[0.1.0]: https://github.com/matshoppenbrouwers/session-ops/releases/tag/0.1.0
