---
name: ops-status
description: The multi-repo portfolio verdict — runs the deterministic ops-portfolio.py aggregation, regenerates PORTFOLIO.md, and gives a one-paragraph verdict covering units, ready work, escalations, unannounced releases, and budget. Triggers on "/ops-status" or when user asks "how are my repos doing", "portfolio status", or "what needs attention across units".
---

# Ops Status

Render the multi-repo portfolio and deliver the one-paragraph verdict. The aggregation is a **deterministic script, not model work** — same input, same output, zero tokens; the skill's only judgement is the verdict sentence.

**Announce:** "Using ops-status to render the portfolio and give the verdict."

## Non-Negotiables

1. **`PORTFOLIO.md` is write-only.** The script regenerates it whole on every run; the skill never edits it, patches it, or merges content into it — not even to fix an obvious glitch. If the output looks wrong, the script is wrong: report that instead.
2. **The script does the counting.** Never re-derive backlog, inbox, escalation, or budget numbers by reading unit files directly — the verdict quotes `PORTFOLIO.md`, nothing else.
3. **No registry or workspace → stop and say "run /ops-init".** The one interactive failure, per the degradation contract in `skills/ops-init/SKILL.md`.

## Workflow

### Step 1: Run the script

```
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/ops-portfolio.py"
```

Where `CLAUDE_PLUGIN_ROOT` is unavailable, resolve `scripts/ops-portfolio.py` relative to this plugin's install location. Pass `--no-fetch` only if the user asks for an offline/fast run; remote columns (freshness, budget run-count) then render `n/a`.

### Step 2: Handle failure

- Exit message names a missing registry or workspace → stop and tell the user to **run /ops-init** (Non-Negotiable 3).
- Any other non-zero exit → report the script's error output verbatim and stop. Never hand-edit or regenerate `PORTFOLIO.md` another way (Non-Negotiable 1).

### Step 3: Read the regenerated portfolio

Read `{workspace}/PORTFOLIO.md` (workspace path from the registry — `ops.json` in the Claude config directory, `$CLAUDE_CONFIG_DIR` if set, else `~/.claude`; the script resolves `--registry` the same way). A unit marked `unreachable` means its local clone is missing — mention it in the verdict; it is not an error.

### Step 4: Give the verdict

One paragraph, all five fields, drawn only from the table:

> "7 units, 2 with ready work, 3 escalations waiting, 1 unannounced release, budget 40%."

- **Units** — row count (note any `unreachable`).
- **Units with ready work** — rows with Ready > 0.
- **Escalations waiting** — sum of the Escalations column.
- **Unannounced releases** — rows with a `yes (…)` in Unannounced release.
- **Budget percentage** — today's run count over `max_ci_runs_per_day` from the Budget line ("n/a" offline).

Follow the paragraph with anything that demands attention — a failure streak, a stale template flag, a unit gone quiet — and stop. The portfolio reports; it never reorders anyone's backlog.
