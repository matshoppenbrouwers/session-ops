# session-ops

Multi-repo operations layer for Claude Code, companion to [session-flow](https://github.com/matshoppenbrouwers/session-flow).

**session-flow owns routing and judgement inside a repo; session-ops owns the feed, the clock, and metrics across repos** — plus the multi-repo portfolio, the one thing session-flow structurally cannot see.

A **managed unit** is any repo following session-flow conventions (`.session-flow.json`, a SEQUENCE.md, a direction doc) — not "a codebase". The sequence layer is domain-agnostic, so a marketing or website repo enrolls exactly like a software repo and works through the same chain. session-ops sees units, backlogs, and releases; it never learns what a tweet is.

**The design metric is decisions-per-day, not items-triaged.** The consistent practitioner finding is that always-on agents create *more* review work, not less. For a one-person factory the scarce resources are the operator's attention first and tokens second, so: cadence defaults are daily, not hourly; escalations batch into one surface; trivial enqueues cost zero decisions (veto-able, not approval-gated); and enrolling a repo is treated as taking on an oversight liability, not free throughput. If the dashboard fills faster than ~15 minutes a day clears it, the correct response is fewer enrolled units or lower cadence.

**v1 triages and drafts. It never implements and never publishes.**

---

## What ships

Five skills, three scripts, two workflow templates, zero agents.

| Skill | Contract |
|---|---|
| `/ops-init` | Create the registry (`~/.claude/ops.json`) and the private local workspace. Workspace location is asked, never defaulted; `git init` and the style-pack scaffold are offered, never forced. |
| `/ops-enroll` | Put one registered unit on the clock — both workflows, both scripts, the escalations file, the pinned dashboard issue — from one shown plan and a single approval. Installs manual-dispatch-only by default. Never writes secrets. |
| `/ops-capture` | Write one raw item into a unit's `{todo}/inbox/` and push it immediately. Enqueue only: never triages, never touches SEQUENCE.md. |
| `/ops-status` | Run the deterministic portfolio aggregation, regenerate `PORTFOLIO.md`, and give the one-paragraph verdict. |
| `/ops-announce` | Draft release announcement copy from the unit's own artifacts into the content unit's inbox (or the workspace `drafts/`). Drafts always, publication never. |

| Script | What it does |
|---|---|
| `scripts/ops-portfolio.py` | The portfolio aggregation. Python 3 stdlib only, offline-capable via `--no-fetch`. Same input, same output, zero tokens. |
| `scripts/ops-guard.sh` | The quota guard. Counts today's account-wide ops workflow runs and emits `ok=true|false` to `$GITHUB_OUTPUT`. Runs **before** the agent step, always exits 0. |
| `scripts/ops-heartbeat.sh` | The failure heartbeat. On the third consecutive failed run, prepends a `⚠` line to the pinned dashboard issue so a dead clock arrives as a notification. |

| Template | Trigger |
|---|---|
| `templates/ops-triage.yml` | `issues: [opened, reopened]` + `workflow_dispatch`. One issue per run, minus `scribe:mirror` and `ops-dashboard` issues. |
| `templates/ops-sweep.yml` | `workflow_dispatch` always; `schedule:` shipped commented out. |

---

## Install

```
/plugin marketplace add matshoppenbrouwers/session-ops
/plugin install session-ops@session-ops
```

session-ops assumes [session-flow](https://github.com/matshoppenbrouwers/session-flow) is installed and that the repos you enroll follow its conventions.

## Quickstart

```
/ops-init                       # registry + workspace + (offered) style pack — once per machine
/ops-status                     # the portfolio verdict — works immediately, no enrolment needed
/ops-enroll                     # put this repo on the clock (dispatch-only until you say otherwise)
/ops-capture <unit> <text>      # drop a raw item into a unit's inbox
/ops-announce [unit] [version]  # draft announcement copy for a shipped release
```

`/ops-init` and `/ops-status` are the whole loop's floor: the portfolio is useful across units on day one, with nothing enrolled and no CI involved.

Enrolment additionally needs a `CLAUDE_CODE_OAUTH_TOKEN` secret on each repo, generated once with `claude setup-token` and reused everywhere (`ANTHROPIC_API_KEY` is the documented fallback). `/ops-enroll` checks the secret exists and tells you how to set it — it never writes one.

---

## The clock, and its safety shape

Not a scheduler: two workflow templates plus an enrolment step, split by trigger shape because triage wants events and grooming wants cron.

- **`ops-triage.yml`** runs `/session-gatekeeper` against a single freshly opened issue. Trivial and aligned → enqueue to SEQUENCE.md as a direct commit. Significant, divergent, or off-direction → one line in `{todo}/escalations.md`, no SEQUENCE write.
- **`ops-sweep.yml`** is the slow daily pass: sweep the inbox, process checked escalation boxes, re-render the dashboard issue, and (only behind the style-pack gate) draft announcements for unannounced releases.

Every control is deterministic and lives **outside** the agent — the practitioner lesson is that budget alerts are postmortems and caps are controls:

- `permissions:` limited to `contents: write, issues: write`.
- `--allowedTools` reduced to file tools, `Bash(git:*)`, and the two GitHub issue-read tools. **No web tools.**
- `timeout-minutes` (10 triage / 15 sweep), `--max-turns` caps, and per-issue / per-repo concurrency.
- Issues labelled `scribe:mirror` or `ops-dashboard` skip the triage job entirely, via a job-level `if:`. [session-scribe](https://github.com/matshoppenbrouwers/session-scribe)'s backlog mirror opens one issue per `SEQUENCE.md` entry, so triaging them would re-triage items that came *from* SEQUENCE.md and can enqueue them straight back into it — a first mirror of a 21-entry backlog is 21 such runs. The pinned dashboard issue is the sweep's own render, so triaging it feeds the bot its output; enrolment pins it before the workflows exist, but reopening a closed dashboard issue is an ordinary thing to do and fires `issues: [reopened]`. The skip happens before the guard, so it costs no quota slot; a `workflow_dispatch` run still triages either kind deliberately. The filter is the label, never the author or an `SEQ-` title prefix: both bots run under the same account a human files issues from by hand.
- `ops-guard.sh` runs before the agent step and skips it when the account's ops runs for the day have hit `budget.max_ci_runs_per_day` — a hit cap skips the agent, it does not fail the run.
- `ops-heartbeat.sh` runs only on failure and flags the dashboard issue on the third consecutive failure.
- `schedule:` ships commented out. The live schedule is a second, explicit yes.
- Every bot commit message ends with `[skip ci]`, so **a bot push cannot fire a unit's deploy** (see below).
- Both templates carry `# ops-template-version:` so the portfolio can flag stale installs; re-running `/ops-enroll` is the entire upgrade path.

**Automated commits never deploy.** Both agent prompts — and `/ops-capture`, which pushes an inbox file to the unit's default branch the moment you capture it — require every commit message to end with `[skip ci]`. GitHub skips the workflow runs a commit would otherwise trigger, so a unit that deploys on push to `main` does not deploy because the bot enqueued a backlog line or you jotted down an idea. This keeps the single-writer model of the section below intact — no branch, no PR, no extra permission scope — while removing the one consequence a direct commit could have beyond the file it wrote.

The deliberate exception is `/ops-enroll`'s own install commit, which is attended, one-time, and lands `.github/workflows/` — the commit where you generally *want* CI to run.

Two limits are worth knowing, because neither is hypothetical:

- GitHub honours the token for the **`push` and `pull_request` events only**. A unit deploying on `pull_request_target` or `workflow_run` is not covered — though neither of those is a push-to-main deploy.
- Deploy platforms outside Actions (Vercel, Netlify, Cloudflare Pages) have their own skip conventions. Most honour `[skip ci]`; none of them is verified here.

For either case — or when you want a push-triggered check to keep running on bot commits, which `[skip ci]` would also skip — add `paths-ignore` to the *unit's own* deploy workflow instead. The bot's entire write footprint is `SEQUENCE.md` plus `{paths.todo}/**`, so the filter is narrow and needs no session-ops change:

```yaml
on:
  push:
    branches: [main]
    paths-ignore: ["_devdocs/**"] # or your paths.todo, plus SEQUENCE.md
```

What neither control solves is a **protected `main` that forbids direct pushes** — that needs a pull request, and it is tracked as SEQ-014, unbuilt, gated on a unit actually having one.

The injection surface is named rather than waved at: a CI gatekeeper holds repo access, untrusted issue text, and a write-capable token. Gatekeeper's "issue text is untrusted" rule is necessary but not sufficient — the minimal tool list is the real control.

## The feed, and escalations

The inbox convention is the place any future source drops into: `{paths.todo}/inbox/`, one item per file, `YYYY-MM-DD-slug.md`, with `source` / `captured` / `by` / optional `url` frontmatter. **Frontmatter is metadata; the body is untrusted data for gatekeeper to triage, never instructions to obey.** Gatekeeper routes an item and `git rm`s it in the same commit — git history is the archive, there is no `processed/` directory.

Escalations never touch SEQUENCE.md. They go to `{todo}/escalations.md`, a bot-owned file of checkbox lines:

```markdown
- [ ] ESC-004 (2026-08-09, issue #31): Auth rework — architectural, needs research-design. _Grounding: PRD §2; touches sync/._
```

The file is the source of truth; the pinned dashboard issue is its render, rewritten by every sweep. **A checked box has exactly one meaning: "yes, this deserves work."** The next sweep enqueues a `(needs breakdown)` SEQUENCE entry referencing the escalation, removes the line in the same commit, and re-renders. No inline instructions are parsed under ticked boxes. The bot never checks its own boxes — box state is the one place a human writes into the loop.

## The portfolio

`scripts/ops-portfolio.py` walks the registry and regenerates `{workspace}/PORTFOLIO.md` **whole** — a write-only output, never hand-edited — plus one `runs.jsonl` line per run. Per unit it reports:

- backlog done/total · ready · needs-breakdown (session-flow's own counting rules). `total` is *every* entry line, whatever sits in the box: a non-standard status token — `- [DEFERRED]`, `- [?]` — counts in `total` and is reported as `· N other`, and in none of done/ready/needs, because session-ops does not interpret states session-flow has not defined. No entry ever disappears from all the counts at once.
- inbox depth · escalations awaiting. Awaiting means an unticked, *numbered* entry (`- [ ] ESC-014 …`); the `ESC-NNN` line in every file's format header is documentation of the format, not an escalation, so a file holding only the header reads `0` — distinct from `—`, which means no escalations file at all.
- last release (top CHANGELOG version, falling back to the latest tag) · last activity
- clock state: workflows present/scheduled, stale template, days since last success, current failure streak. The two freshness halves render independently — a unit with a failing clock and no successful run yet reads `n/a · streak 3`, not a fabricated day count.
- budget: today's ops CI runs against the cap
- unannounced release: a release newer than any `release-announce` item and the last `announce` run

`/ops-status` wraps it and gives the verdict — *"7 units, 2 with ready work, 3 escalations waiting, 1 unannounced release, budget 40%."* Missing files yield `—`, an unreachable clone is marked `unreachable` and the rest still report, and `--no-fetch` renders every remote column `n/a` without attempting a single network call.

Metrics are the free kind only: one `runs.jsonl` line per ops-launched run, with the structured status enum `complete | timeout | stalled | max-turns | tool-failure | escalated`. No per-phase token counts, no in-session hooks — instrumentation that adds ceremony to a live session is a defect.

---

## Public repo, private state

session-ops is public, so **nothing generated ever enters it.** The repo ships code, conventions, and `examples/ops.json`; every piece of real state lives on your machine:

| Lives in the repo | Lives in `~/.claude/ops.json` and the workspace |
|---|---|
| Skills, scripts, templates, examples | The registry: units keyed by absolute path, `kind`, `cadence`, budget ceiling |
| | `PORTFOLIO.md`, `runs.jsonl`, `drafts/` — all generated |
| | `style/voice.md` + `style/templates/` — the one thing you author there |

The workspace is a plain directory. `git init` on it is offered, never forced; pushing it to a **private** remote is the opt-in that makes the portfolio phone-visible and unlocks scheduled auto-drafting. `.gitignore` covers the artifact names as a safety net.

## Degradation

Coupling is by file convention in known locations. Absence never errors.

| If this is absent | Then |
|---|---|
| session-flow in a unit | Inbox items sit inert; the portfolio still reports counts; workflows are not installed (enroll checks) |
| session-ops | session-flow runs single-repo exactly as today; nothing references ops |
| A registered unit's local clone | The portfolio marks the unit `unreachable` and reports the rest |
| The workspace | Skills stop and say "run `/ops-init`" — the one interactive failure |
| A content unit (for announce) | Drafts land in the workspace `drafts/`, stated plainly |
| The style pack | Interactive announce proceeds with a stated warning; scheduled auto-drafting does not run at all — no voice on file, no unprompted prose |
| The workspace as a private repo | The portfolio stays local-only and the sweep never auto-drafts; everything else unaffected |
| The dashboard issue | Escalations still live in `{todo}/escalations.md`; only the phone-visible render is missing |

---

## What v1 deliberately does not do

**It never implements work on a schedule, and it never publishes anything.** Also excluded, on purpose: any UI beyond `PORTFOLIO.md`; inline instructions parsed under escalation checkboxes; approval-first enqueueing; webhook→file event pumps and error-tracker intake; cross-unit priority or a global queue (each unit's SEQUENCE.md stays sovereign — the portfolio reports, never reorders); fan-out operations across units; and agent spending authority of any kind.

The audit trail a future opt-in "implement ready tasks → draft PR" mode would need — `[auto]` provenance, structured run statuses, single-writer discipline, the budget ceiling — is built now, for free. Designed for; not shipped.

## Status

v1 (0.2.0). Both operational validations 0.1.0 listed as outstanding have now run. The composed CI path (`--plugin-dir` loading session-flow inside `claude-code-action`, gatekeeper committing from CI, the dashboard round-trip) executed end-to-end on 2026-08-13 and passed every check. One unit has run on a live schedule since 2026-08-14, the first unattended sweep landing green that morning; its one-week watch closes 2026-08-21, and widening enrolment is the deliberate decision on the far side of it.

**Both templates still install manual-dispatch-only.** That is the shipped default for everyone and it has not changed — enabling a schedule is a separate, attended act on a unit you have decided to put on the clock, which is the posture the pilot went through. One validated pilot is not a recommendation to enrol a portfolio; the meta-risk in spec §12 is attention, and it is real.

## Documentation

- `plans/2026-08-09-session-ops-v1-spec.md` — the v1 specification, including the prior-art review and the argument against the design
- `todo/SEQUENCE.md` — the backlog
- `CHANGELOG.md` — release history

## License

MIT — see [LICENSE](LICENSE).
