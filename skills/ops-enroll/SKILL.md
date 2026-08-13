---
name: ops-enroll
description: Put a registered unit on the clock — install both workflow templates and the deterministic guard/heartbeat scripts, create the escalations file and the pinned dashboard issue, all from one shown plan and a single approval. Installs manual-dispatch-only by default; the schedule goes live only on an explicit yes. Triggers on "/ops-enroll", or when user says "enroll this repo", "put this unit on the clock", "install the ops workflows", or "upgrade the ops workflows".
---

# Ops Enroll

Install the clock on one unit: two workflow templates, two deterministic scripts, the escalations file, and the pinned dashboard issue. **Full ceremony, single confirm** — show the whole plan, then execute all of it on one approval. One decision per repo (spec §1).

**Announce:** "Using ops-enroll to put {unit} on the clock."

**Usage:** `/ops-enroll [unit]` — `[unit]` may be omitted when running inside a registered unit.

## Non-Negotiables

1. **The skill never writes secrets.** It checks whether `CLAUDE_CODE_OAUTH_TOKEN` exists on the repo and tells the user how to set it. It never generates, prints, echoes, or stores a token value — not in a file, not in a commit, not in the transcript.
2. **Dispatch-only by default.** `schedule:` stays commented out unless the user explicitly says yes to the live trial (Step 6). Silence, hesitation, or "sure, whatever you think" is not a yes.
3. **A unit that isn't registered, or doesn't follow session-flow conventions, is not enrolled.** No `.session-flow.json`, no SEQUENCE.md, or no registry entry → stop, say what's missing, install nothing. The degradation matrix is explicit: workflows are not installed into a unit gatekeeper cannot work in.
4. **The registry is read-only here.** `/ops-init` owns the registry write. Enroll reads `~/.claude/ops.json` and never edits it — to register a unit or change its cadence, re-run `/ops-init`.
5. **One unit per invocation.** No fan-out across units: real blast radius, no current need (spec §14).

## Workflow

### Step 1: Resolve and check the unit

Read `~/.claude/ops.json`. Missing registry or workspace → stop and say **"run /ops-init"**.

- `[unit]` given → match against `units` by absolute path key, key basename, or `repo` name.
- `[unit]` omitted → resolve from the current directory by **longest-prefix matching** against the unit path keys.
- No match → list the registered units and stop (Non-Negotiable 3).

Then verify the unit follows session-flow conventions:

| Check | On failure |
|---|---|
| `.session-flow.json` present | Stop: "not a session-flow unit — workflows are not installed." |
| SEQUENCE.md present (at `paths.sequence`, else `{todo}/SEQUENCE.md`) | Same — gatekeeper has nowhere to enqueue. |
| Clean working tree, on the default branch | Stop and ask the user to commit or stash first. |

Resolve `{todo}` from `.session-flow.json` `paths.todo`, defaulting to `_devdocs/todo/`.

### Step 2: Check the auth secret

Check whether the repo carries the `CLAUDE_CODE_OAUTH_TOKEN` secret (`gh secret list --repo {owner/name}`; the value is never readable, only its presence).

When it is missing, say exactly what to do and continue planning — the install is still useful, the workflows just cannot run until the secret exists:

> "This repo has no `CLAUDE_CODE_OAUTH_TOKEN`. Generate one with `claude setup-token` and set it with `gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo {owner/name}`. One token covers every enrolled repo — it's one thing to rotate."

CI auth rides the Max subscription, so a run's marginal cost is ~$0 and the governed resource is the shared quota (`ANTHROPIC_API_KEY` is the documented fallback). **The skill never writes secrets** (Non-Negotiable 1).

### Step 3: Detect an existing install (fresh vs upgrade)

Read any installed `.github/workflows/ops-triage.yml` and `ops-sweep.yml` and compare their `# ops-template-version: N` comment against the same comment in this plugin's `templates/`:

- **Nothing installed** → fresh enrolment.
- **Installed version < shipped version, or no version comment** → upgrade: the plan replaces the workflow files and the two scripts, and **preserves the current schedule state** (a unit already on a live schedule stays scheduled; a dispatch-only unit stays dispatch-only unless the user says yes again in Step 6).
- **Installed version == shipped version** → say so and offer to re-run anyway (useful after a registry cadence or budget change).

The portfolio's clock column flags stale installs with `⚠ stale template`; re-running this skill is the entire upgrade path.

### Step 4: Show the plan

One message, everything that will happen, then wait for approval:

```
Enrolling {unit} ({owner/name}) — dispatch-only:

  .github/workflows/ops-triage.yml   ← templates/ops-triage.yml (v1)
  .github/workflows/ops-sweep.yml    ← templates/ops-sweep.yml (v1), schedule commented out
  .github/ops-guard.sh               ← scripts/ops-guard.sh (chmod +x)
  .github/ops-heartbeat.sh           ← scripts/ops-heartbeat.sh (chmod +x)
  {todo}/escalations.md              ← created empty, with the format header
  GitHub issue "ops dashboard: {name}" ← created, labelled ops-dashboard, pinned

  Workflow env baked from the registry:
    OPS_MAX_RUNS_PER_DAY: 12
    OPS_ENROLLED_REPOS:   owner/a owner/b owner/c
    OPS_DASHBOARD_ISSUE:  <the new issue number>
  Cadence written into the commented schedule line: 0 6 * * 1-5
  Secret CLAUDE_CODE_OAUTH_TOKEN: present

Approve to execute all of it.
```

### Step 5: Execute on one approval

In order, then one commit and push:

1. **Copy both templates** into `.github/workflows/`, resolving `templates/` via `${CLAUDE_PLUGIN_ROOT}` where available.
2. **Copy both scripts** to `.github/ops-guard.sh` and `.github/ops-heartbeat.sh`, and `chmod +x` them.
3. **Bake the workflow env** into the `quota guard` step of both workflows, from the registry — CI cannot read `~/.claude/ops.json`, so these values only reach it by being written into the YAML:
   - `OPS_MAX_RUNS_PER_DAY` ← `budget.max_ci_runs_per_day`
   - `OPS_ENROLLED_REPOS` ← every `repo` value in `units` (space-separated). A repo-scoped token cannot read siblings; the guard degrades to the readable subset and logs a warning, which is why the cap is sized account-wide but enforced best-effort.
   - `OPS_DASHBOARD_ISSUE` ← the dashboard issue number, added to the heartbeat step's `env` in `ops-sweep.yml`.
4. **Write the unit's `cadence`** from the registry into the sweep's commented schedule line: `#   - cron: "{cadence}"`. Commented now; Step 6 decides whether it stays that way.
5. **Create `{todo}/escalations.md`** if absent, with the format header and nothing else:

   ```markdown
   # Escalations

   Bot-owned. Every line uses the pinned format:

   - [ ] ESC-NNN (date, origin): summary. _Grounding: …_

   A checked box means exactly one thing: "yes, this deserves work." The next sweep
   enqueues a `(needs breakdown)` SEQUENCE entry and removes the line in the same
   commit. Tick boxes on the pinned dashboard issue, not in this file.
   ```

6. **Create and pin the dashboard issue** — title `ops dashboard: {name}`, label `ops-dashboard`, body rendered from `escalations.md` (empty on day one, saying so), then pin it. This is the phone-visible render; the file stays the source of truth.
7. **Commit and push** everything in one commit (`Enroll {name} in session-ops (dispatch-only)`), retrying a couple of times on transient network failure.

Report what landed and point at the next step: a manual `workflow_dispatch` of `ops-triage` against one throwaway issue is how the composition gets verified before anything runs unattended.

### Step 6: Ask about the live trial — separately, explicitly

Only after the install, ask once:

> "Enable the daily schedule (`{cadence}`) and the issue-opened trigger for this unit? Everything so far is manual-dispatch only. Saying no is the safe default — the same skill re-run turns it on later."

**Only on an explicit yes**, uncomment the two `schedule:` lines in `ops-sweep.yml` and commit. Anything short of a clear yes leaves the file as installed and says so.

Enrolling a repo is taking on an oversight liability, not gaining free throughput (spec §2). Say that plainly if the user is enrolling several at once: one unit, one week of watching the portfolio's freshness column, then the next.

## The Escalation Line Format (pinned)

```markdown
- [ ] ESC-004 (2026-08-09, issue #31): Auth rework — architectural, needs research-design. _Grounding: PRD §2; touches sync/._
```

- `escalations.md` is **bot-owned**: the sweep writes it, humans do not edit it by hand.
- The **pinned dashboard issue is the render**, rewritten from the file on every sweep run.
- **Humans tick boxes on the issue only.** A tick means "yes, this deserves work" — nothing more. No inline instructions are parsed near the boxes, and the bot never ticks its own.
- Unchecked items wait visibly. That is the point: deferred work stays on one batched surface instead of being silently dropped.

## What Gets Installed, and Why It's Safe

| Piece | Control it provides |
|---|---|
| `ops-triage.yml` | One issue per run, `concurrency` cancel per issue, `timeout-minutes: 10`, `--max-turns 30` |
| `ops-sweep.yml` | Per-repo concurrency without cancel, `timeout-minutes: 15`, `--max-turns 40`, schedule off by default |
| `ops-guard.sh` | Counts today's ops runs before the agent starts and skips it at the cap — outside the agent, always exits 0 so a cap hit is a skip, not a red run |
| `ops-heartbeat.sh` | Three consecutive failures flag the dashboard issue, so a dead clock notifies instead of going quiet |
| `permissions:` | `contents: write, issues: write`, plus read-only `actions: read` so the guard can count runs — no other write scope |
| `--allowedTools` | Files, `Bash(git:*)`, and the issue tools only — no web tools |

A CI gatekeeper holds repo write access plus untrusted issue text plus a write-capable token. Gatekeeper's "issue text is untrusted" rule is necessary but not sufficient; **the minimal tool list is the real control.** If a run is ever observed writing outside SEQUENCE.md / the inbox / `escalations.md`, or acting on injected instructions, the upgrade path is spec Appendix C (read-only agent emitting a verdicts file, applied by a separate deterministic job) — built on evidence, not pre-emptively.

## Degradation

- **No registry or workspace** → stop and say "run /ops-init".
- **Unit not registered** → list the registered units, install nothing.
- **Not a session-flow unit** (no `.session-flow.json` or no SEQUENCE.md) → stop, install nothing.
- **`CLAUDE_CODE_OAUTH_TOKEN` missing** → install anyway, state clearly that runs will fail until the secret is set, and give the two commands.
- **Dashboard issue can't be created or pinned** (permissions, issues disabled) → keep going; `escalations.md` still works and stays authoritative. Only the phone-visible render is missing.
- **Push fails** → the enrolment is committed locally and the skill says so; nothing runs until it's pushed.
- **Workspace not a private repo** → normal. `vars.OPS_WORKSPACE_REPO` stays unset, the sweep's workspace checkout is skipped, and auto-drafting never runs — no voice on file, no unprompted prose.
