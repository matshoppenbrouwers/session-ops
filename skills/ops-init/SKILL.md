---
name: ops-init
description: Create the session-ops registry (ops.json in the Claude config directory) and the private local workspace that every other ops skill depends on — units keyed by absolute path, budget ceiling, and an offered style-pack scaffold. Generated state never enters the public repo. Run once when adopting session-ops. Triggers on "/ops-init" or when user says "set up session-ops", "create the ops registry", or another ops skill reports the registry or workspace is missing.
---

# Ops Init

Create the two pieces of private state every other session-ops skill depends on: the **registry** — `ops.json` in the Claude config directory (`$CLAUDE_CONFIG_DIR` if set, else `~/.claude`; the same resolution rule session-scribe uses for `scribe.json`) — and the **workspace** (a plain local directory for everything generated).

**Announce:** "Using ops-init to create the ops registry and workspace."

## Non-Negotiables

1. **The workspace location is asked, never defaulted.** There is no imposed path. Ask the user where the workspace should live and use exactly what they answer.
2. **Offers are never forced.** `git init` on the workspace and the style-pack scaffold are both offered; a "no" is a complete answer and the skill proceeds without them. Both can be added later by re-running `/ops-init` against an existing workspace.
3. **Nothing under the workspace is ever committed to session-ops.** The public repo ships code, conventions, and `examples/ops.json`; every piece of real state (`PORTFOLIO.md`, `runs.jsonl`, `drafts/`, the style pack, the registry) lives on the user's machine.
4. **The registry schema matches `examples/ops.json` key-for-key.** Top-level keys are exactly `workspace`, `budget`, `units`; `budget` carries exactly `max_ci_runs_per_day` and `monthly_usd`; each unit carries exactly `repo`, `kind`, `cadence`. No extra keys, no renames — three other components parse this file.

## When to Use

- First time adopting session-ops on a machine.
- Re-run to register additional units, or to add `git init` / the style pack to an existing workspace (the skill detects what exists and only offers what's missing — it never overwrites a populated `voice.md` or an existing registry entry without asking).

## Workflow

### Step 1: Ask where the workspace lives

Ask the user for the workspace path (Non-Negotiable 1). If the registry already exists, read it, report what is already configured, and skip to whichever steps are incomplete.

### Step 2: Create the workspace

```
mkdir -p {workspace}/drafts
```

The workspace holds everything generated (`PORTFOLIO.md`, `runs.jsonl`, `drafts/`) plus the one thing the user authors there: the style pack (Step 5).

### Step 3: Write the registry

Write the registry (`ops.json` in the Claude config directory):

```json
{
  "workspace": "/the/path/from/step/1",
  "budget": { "max_ci_runs_per_day": 12, "monthly_usd": null },
  "units": {}
}
```

**Budget is quota-shaped, not dollar-shaped.** CI authenticates with the Max-subscription OAuth token, so the governed resource is the shared Max quota that CI draws from the same pool as the user's interactive sessions. `max_ci_runs_per_day` is the account-wide cap, default 12 (sized for 5–10 units: daily sweeps plus event-triage headroom). `monthly_usd` exists only for the API-key fallback mode and stays `null` on subscription auth.

### Step 4: Offer `git init`

Offer (never force) to `git init` the workspace. Pushing it to a **private** remote later is the opt-in that makes the portfolio phone-visible and unlocks scheduled auto-drafting — the user's call, later is fine. Never suggest a public remote: backlog titles and drafts are private state.

### Step 5: Offer the style-pack scaffold

Offer (never force) to scaffold the style pack — the single global voice source for every current and future ops-domain skill:

- `{workspace}/style/voice.md` — starts with a header explaining the format: one-line `rule — reason` entries covering tone, vocabulary, and structure preferences, plus an **Anti-AI-writing patterns** section for the tells the user does not want in their name. Both sections start empty apart from one commented example line each; a good first population pass is drafting rules from samples of the user's real writing and pruning hard.
- `{workspace}/style/templates/` — per-channel skeletons, seeded with one `announcement-post.md` skeleton (title line, one-paragraph summary slot, what-changed list, link line).

### Step 6: Point at next steps

Report what was created, then point forward: `/ops-enroll` to put a registered unit on the clock, `/ops-status` to render the portfolio.

## Unit Registration

**Init owns the registry write; `/ops-enroll` only reads it.** To register a unit (at first run or any re-run), add an entry under `units`:

```json
"units": {
  "/abs/path/to/repo": { "repo": "owner/name", "kind": "code", "cadence": "0 6 * * 1-5" }
}
```

- **Keys are absolute local paths**, resolved by **longest-prefix matching** (scribe's rule): a cwd anywhere inside a unit resolves to the deepest registered path that prefixes it.
- **`repo`** is the GitHub `owner/name`. Before asking for it, check `scribe.json` (same config directory) for a `projects` entry keyed by the same absolute path: when `projects.<path>.github.repo` exists, **prefill from it and confirm** rather than ask cold — scribe.json is the senior source for the path→`owner/name` fact, so a value that diverges from it is almost certainly a mistake. No scribe.json, or the path not registered there → ask as usual; nothing else changes.
- **`kind`** is a descriptive label (`code`, `content`, …) used only for portfolio grouping and announce's content-unit lookup.
- **`cadence`** is the cron line `/ops-enroll` writes into the unit's sweep workflow once that unit's live trial is confirmed — default `0 6 * * 1-5` (daily on weekdays; the scarce resource is the operator's attention, so cadence defaults slow).

## Degradation Contract (binding on all other ops skills)

When the registry or the workspace is missing, every other session-ops skill **stops and says "run /ops-init"** — the one interactive failure in the system. The absence of anything else (a unit's local clone, a content unit, the style pack, the dashboard issue) never errors; each has its own documented fallback in the spec's §2 degradation matrix. This skill is the only one that creates the registry or workspace; no other skill silently invents either.
