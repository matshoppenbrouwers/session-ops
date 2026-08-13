# Draft-PR Mode Research Report

**Date:** 2026-08-13
**Status:** Research complete. **Superseded in part — see Decision below.**
**Tracked as:** SEQ-015 (shipped) and SEQ-014 (deferred, blocked on evidence)

---

## Decision (2026-08-13)

**None of options A, B+, or C were built.** The research below was scoped to a driver — "units
that auto-deploy on push to main" — that turns out not to need an architectural answer.

GitHub skips the workflow runs a commit would trigger when its message contains `[skip ci]`
(also `[ci skip]`, `[no ci]`, `[skip actions]`, `[actions skip]`, or a `skip-checks: true`
trailer), for the `push` and `pull_request` events. A deploy-on-push-to-main is `on: push:
branches: [main]`, so it is covered. **Shipped as SEQ-015:** both agent prompts now require
every bot commit message to end with `[skip ci]`. Cost: two lines of prompt text. No branch, no
PR, no `pull-requests: write`, no new ref, no drift, no review burden, single-writer model and
all three idempotency markers untouched.

Documented limits (README, "The clock, and its safety shape"): the token covers `push` and
`pull_request` only, so a deploy on `pull_request_target`/`workflow_run` is not caught; and
non-Actions deploy platforms have their own conventions, unverified here. Both cases, plus
"I want a push-triggered check to keep running on bot commits", are handled by `paths-ignore`
on the unit's own deploy workflow — the bot's write footprint is only `SEQUENCE.md` plus
`{paths.todo}/**`.

**What survives as SEQ-014:** a protected `main` that forbids direct pushes. `[skip ci]` cannot
help there; a PR is structurally required. Deferred and explicitly blocked on evidence — no
enrolled unit is known to have one — matching Appendix C's build-on-evidence posture. If it is
ever built, §4's recommendation below (split writes by ownership) is the design to start from,
and §2.5's beads finding is the reason not to reach for a long-lived branch.

**Why option A was rejected outright:** for deploy safety the PR must never auto-merge, since
merging fires the deploy anyway. So the branch never merges, so its divergence from `main` grows
without bound, permanently. beads built that exact shape and removed it (§2.5).

---
**Scope:** Add an opt-in per-unit write mode to session-ops' scheduled workflows so that bot
file writes never land on the default branch, targeting units where push-to-main triggers a
deploy. Direct-commit remains the default. The bot's existing routing/escalation idempotency
must survive the change.

---

## 1. Current State

### What Exists

Every git write in session-ops is a **direct commit + push to the default branch**, performed
by an agent inside a GitHub Actions job holding `contents: write`.

| Write | Where instructed | What lands |
|-------|-----------------|------------|
| Inbox routing + `git rm` of the item | `templates/ops-sweep.yml:69-70` | files on main |
| Checked-box processing (enqueue + escalation-line removal) | `templates/ops-sweep.yml:71-74` | files on main |
| Dashboard issue body rewrite | `templates/ops-sweep.yml:75-77` | **issue API**, lands instantly |
| Announcement draft into inbox | `templates/ops-sweep.yml:78-81` | files on main |
| Triage enqueue or escalation append | `templates/ops-triage.yml:87-91` | files on main |

Both prompts end with the same instruction — *"Push every commit to the default branch — a
commit left unpushed is discarded when the runner is torn down"* (`templates/ops-sweep.yml:82`,
`templates/ops-triage.yml:92`). Neither names a ref explicitly; both rely on unqualified
`actions/checkout@v4` (`ops-sweep.yml:39`, `ops-triage.yml:64`) having checked out the default
branch.

`permissions:` in both is `contents: write`, `issues: write`, `actions: read`, `id-token: write`
(`ops-sweep.yml:24-28`, `ops-triage.yml:29-33`). **`pull-requests:` is granted nowhere.**

### Architecture

**Bot writes are load-bearing for the bot's own next run.** The state machine is "my commit
landed on main, so my next run sees it and won't redo the work." Three distinct markers encode
this:

1. **Inbox item deletion is the processed-marker.** Gatekeeper routes the item, then `git rm`s
   the file *in the same commit* that records the routing (`spec:125`). Git history is the
   archive; there is no `processed/` directory.
2. **Escalation line absence is the handled-marker.** A ticked box means "this deserves work";
   the next sweep enqueues a SEQUENCE entry and **removes the escalation line in the same
   commit** (`spec:141`).
3. **The dashboard issue is a pure render** of `escalations.md`, rewritten every sweep run
   (`spec:141`, `ops-sweep.yml:75-77`).

### The Idempotency Coupling — why this isn't a one-line change

Hold writes back from main and all three markers break:

- An unmerged inbox `git rm` → next sweep reads main, sees the item again, **routes it twice**.
- An unmerged escalation-line removal → next sweep sees the still-ticked box, **re-enqueues**.
- The dashboard render is an *issue API* write. It lands immediately and **cannot be held on a
  branch**, so the render would advertise state that does not exist on main.

That third one is the sharpest: it is not fixable by choosing a branch strategy, because the
write isn't a git write at all.

### Where a mode flag can live

The registry schema is **explicitly closed** — `skills/ops-init/SKILL.md:17`, Non-Negotiable 4:

> Top-level keys are exactly `workspace`, `budget`, `units`; `budget` carries exactly
> `max_ci_runs_per_day` and `monthly_usd`; each unit carries exactly `repo`, `kind`, `cadence`.
> No extra keys, no renames — three other components parse this file.

So a per-unit `"writes": "pr"` key in `ops.json` would violate a sibling skill's non-negotiable.

**There is a precedent that avoids the schema entirely.** The schedule on/off toggle is already
*file state*, not registry state: `/ops-enroll` Step 6 turns the clock on by uncommenting the
`schedule:` line in the installed YAML (`skills/ops-enroll/SKILL.md:135-143`), and
`ops-portfolio.py` reads it back off disk (`sweep_scheduled`, `:242-251`) exactly as it reads
`# ops-template-version` (`:211-224`). `clock_state()` (`:254-269`) already renders a per-unit
mode label — `"triage+sweep (scheduled)"` vs `"(dispatch-only)"` — derived purely from
workflow-file content.

Install-time substitution is the established mechanism: `/ops-enroll` already resolves `{todo}`,
`OPS_MAX_RUNS_PER_DAY`, `OPS_ENROLLED_REPOS`, `OPS_DASHBOARD_ISSUE` and `{cadence}` at install
time (`skills/ops-enroll/SKILL.md:106-114`), with a hard-stop verification that no placeholder
survived (`:130`).

### Gaps

| Gap | Impact |
|-----|--------|
| No branch/PR machinery anywhere — no `git checkout -b`, `gh pr`, or `pull-requests:` scope | Built from scratch |
| `pull-requests: write` not granted | Permissions block must change (PR options only) |
| Dashboard render is an issue write, unholdable on a branch | Render/branch consistency needs an explicit answer |
| No per-unit write-mode surface | Needs the file-state route, not the registry |
| `runs.jsonl` exists but is workspace-local | Written by `ops-portfolio.py:529-540` and the announce/capture skills; **not** written by CI, so it is not currently a CI-visible state ledger |

---

## 2. Reference Implementations

### 2.1 gh-aw (GitHub Agentic Workflows)
**Source:** <https://github.github.com/gh-aw/reference/safe-outputs-pull-requests/>
**Architecture:** Read-only agent job (`contents: read`) emits a git bundle + structured JSON;
a separate permission-scoped job applies and pushes it. Branch names get a **random hex suffix
by default** (`feature/update-docs-a7f2k9`) — per-run, disposable, non-accumulating. Long-lived
branches are opt-in via `preserve-branch-name: true`, paired with `recreate-ref: true`, which
**force-deletes and recreates** rather than reconciling. A separate `push-to-pull-request-branch`
output exists for adding commits to an already-open PR.
**Relevance:** The strongest precedent for session-ops' own Appendix C split. Its default choice
is the finding that matters: per-run branches exist *specifically* so drift is never a problem.

### 2.2 Renovate
**Source:** <https://docs.renovatebot.com/updating-rebasing/>, <https://docs.renovatebot.com/key-concepts/dashboard/>
**Architecture:** Long-lived branch per update task. Does **not** `git rebase` — it "reapplies
all updates into a new commit based off the head of the base branch" and force-pushes. Any human
commit to the branch **permanently stops** all further automation on it.
Its Dependency Dashboard issue is the closest analog to session-ops' pinned issue: before
overwriting the body each run, Renovate **parses checkbox state out of the existing body**
(`getCheckedBranches`/`parseDashboardIssue`) to pick up user intent.
**Relevance:** Two borrowables. (1) Force-recompute-against-base beats reconciliation. (2) Its
documented failure mode is a direct warning — issue
[#19563](https://github.com/renovatebot/renovate/issues/19563): clearing the issue body *crashes
the parser*, because the render is also an input. Any read-then-overwrite of the dashboard must
be defensive against human edits.

### 2.3 Dependabot
**Source:** <https://docs.github.com/en/code-security/dependabot/working-with-dependabot/managing-pull-requests-for-dependency-updates>
**Architecture:** Auto-rebases by default; stops once a human adds a commit (override:
`[dependabot skip]`); pauses rebasing after 30 days of PR inactivity.
**Relevance:** Confirms the "one human commit opts the branch out forever" heuristic as an
industry norm. Note what this implies: neither Renovate nor Dependabot ever attempts to
reconcile a branch a human partially applied to main. They stop and wait.

### 2.4 GitHub Copilot coding agent
**Source:** <https://docs.github.com/copilot/concepts/agents/coding-agent/about-coding-agent>
**Architecture:** One task = one branch = exactly one PR for the task's life; follow-up work
pushes more commits to the same branch. Structurally cannot approve or merge its own PR, and the
assigning user's approval doesn't count toward required approvals.
**Relevance:** Precedent for enforced no-self-merge. **No documentation exists** on its behaviour
when that branch drifts from main.

### 2.5 beads — the negative precedent
**Source:** <https://beads.gascity.com/reference/protected-branches.md>, <https://beads.gascity.com/reference/git-integration.md>
**Architecture:** beads is cited in session-ops' own spec (`spec:62`) as the project that
abandoned JSONL-in-git over merge conflicts. The full arc is more pointed than the spec records:
beads *then* added a long-lived `beads-sync` branch plus hidden worktrees, specifically to work
around branch-protection rules on main — **and has since removed that too**. Issue state now
lives in Dolt under `refs/dolt/data`, a **separate git ref namespace that is not a normal
branch**, so `bd create/update/close` never commit to any code branch and branch protection
simply doesn't apply to state changes.
**Relevance:** This is the closest documented attempt at what "bot reads its own long-lived
branch" proposes, and it was removed. The stated conclusion: state that machines mutate
frequently should be decoupled from the branch humans review.

### 2.6 The finding across all five

**No reference system commits a file-based state machine to a branch it deliberately never
merges.** They either make the branch disposable (gh-aw, per-run), force-recompute it from base
every run (Renovate, Dependabot), or move state off branches entirely (beads).

---

## 3. Comparative Analysis

**A — Long-lived ops branch, bot reads its own branch** (the shape chosen at scoping)
**B — Separate state ref, no PR at all** (the beads shape)
**C — Per-run branch, structured verdicts applied by a second job** (the gh-aw / Appendix C shape)

| Dimension | A: long-lived branch | B: separate state ref | C: per-run branch + apply job |
|-----------|---------------------|----------------------|------------------------------|
| Stops push-to-main deploy | Yes | **Yes** — a push to `refs/ops/state` does not match `on: push: branches: [main]` | Yes, until merged |
| Idempotency of the 3 markers | Holds — bot always sees its own writes | **Holds perfectly** — the ref *is* the bot's world, no drift concept | Breaks between runs unless a ledger is added |
| Divergence from main | **Unbounded and permanent** — the branch never merges by design | **Not applicable** — never intended to match main | None — branch is disposable |
| Dashboard render consistency | Render shows unmerged state | **Consistent** — render's source lives on the ref, always current | Render shows unmerged state |
| Needs `pull-requests: write` | Yes | **No** | Yes |
| Attention cost (§2) | One accumulating PR that must never merge → grows forever | **Zero new review surface** | One PR per run — the cost §7 explicitly rejects |
| SEQUENCE.md reaches humans on main | Only if the PR merges (it must not) | **No** — needs a separate answer | On merge |
| Prior art | **None. beads removed this exact shape** | beads (`refs/dolt/data`) | gh-aw default; session-ops Appendix C |
| Build cost | Medium | Medium — `git push origin HEAD:refs/ops/state`, no PR API | High — verdicts schema + apply script |

### The problem A cannot solve

For auto-deploy safety the PR must never auto-merge (merging to main fires the deploy — a draft
PR only helps while it stays unmerged). So the branch never merges. So divergence grows without
bound, forever, and every marker file on it drifts further from main's copy. The property that
makes A safe is the property that makes it unmaintainable. No reference system does this, and
the one that tried removed it.

### The problem B cannot solve, and the split it implies

B is excellent for **bot-owned** files. It is wrong for **`SEQUENCE.md`**, which is human-owned,
human-read, lives on main, and is parsed by session-flow (`spec:368` — "owned by session-flow").
Hiding it on a ref no human reads defeats the purpose of enqueuing.

That asymmetry is the actual design insight: **the bot's writes are not one category.**

| File | Owner | Read by | Belongs |
|------|-------|---------|---------|
| `escalations.md` | bot (`spec:141` — "bot-owned") | bot + dashboard render | state ref |
| `{todo}/inbox/` | bot after routing | bot | state ref |
| `SEQUENCE.md` | session-flow | **humans, locally, on main** | main — needs a PR, or direct commit |

Under that split, `escalations.md` and inbox churn — the high-frequency writes, and the two that
carry the fragile markers — leave main entirely, with no PR and no review burden. Only
SEQUENCE.md enqueues need gating, and those are low-volume, batchable, and already described by
§7 as "a proposal by nature."

---

## 4. Recommendation

**Recommended: B+ — split the writes by ownership.**

1. **Bot-owned state (`escalations.md`, inbox routing) → a separate ref** (`refs/ops/state`),
   pushed directly. No PR, no deploy trigger, no drift, all three idempotency markers intact,
   and the dashboard render stays truthful because its source is always current. Needs no new
   permission scope.
2. **`SEQUENCE.md` enqueues → one accumulating draft PR** off a branch rebuilt from main's head
   each run (Renovate's force-recompute, *not* a reconciled long-lived branch). This is the only
   place `pull-requests: write` is needed, and the only new review surface. Because the branch is
   recomputed from main every run, it never drifts.
3. **Mode selection is file state, not registry state** — following the `schedule:` precedent
   (`skills/ops-enroll/SKILL.md:135-143`), substituted at install time, surfaced by
   `ops-portfolio.py`'s `clock_state()`.

This keeps direct-commit as the default, holds §2's attention rule (the high-frequency writes add
zero review burden), and is the only option with positive prior art on both halves.

**Honest cost:** it is two mechanisms rather than one, and it introduces a ref that ordinary
`git fetch` won't show — an operator debugging `escalations.md` must know to fetch
`refs/ops/state`. That discoverability cost is real and should be documented in the README, not
hidden.

### Key design decisions to resolve

- Is the two-mechanism split acceptable, or is one uniform mechanism worth a worse fit?
- Does SEQUENCE.md's PR accumulate across runs, or open one per run?
- Should the dashboard issue body carry a "unmerged enqueues pending" line so the render never
  silently lies about main's state?
- Defensive parsing of the dashboard body before overwrite (Renovate #19563) — in scope, or a
  separate hardening task?
- Does the guard's run-counting need to change if a run can now no-op on a PR conflict?

---

## 5. Open Questions

- **Do any real units actually auto-deploy on push to main?** The whole driver rests on this. If
  none do today, this may be a documented-posture task rather than a build task.
- **Is a separate ref acceptable at all**, given `spec:145`'s offline-readable framing for
  `escalations.md`? A ref is still git-versioned and offline-readable, but not on the working
  branch.
- **Should this supersede Appendix C** (`spec:370`) or compose with it? Appendix C is the
  read-only-agent + verdicts-apply-job upgrade, gated on observed misuse. Option C above is
  essentially Appendix C plus a PR — worth knowing whether these merge into one future task.
- **Does `runs.jsonl` become CI-written?** It exists (`ops-portfolio.py:529-540`) but no CI path
  writes it. If PR mode needs a cross-run ledger, this is the natural home — but that makes CI a
  writer of a workspace-local file, which it currently is not.

---

## References

- Codebase map: this repo, cited inline above
- gh-aw safe outputs: <https://github.github.com/gh-aw/reference/safe-outputs/>
- Renovate rebasing: <https://docs.renovatebot.com/updating-rebasing/>
- Renovate dashboard parser crash: <https://github.com/renovatebot/renovate/issues/19563>
- Dependabot PR management: <https://docs.github.com/en/code-security/dependabot/working-with-dependabot/managing-pull-requests-for-dependency-updates>
- Copilot coding agent: <https://docs.github.com/copilot/concepts/agents/coding-agent/about-coding-agent>
- beads protected branches: <https://beads.gascity.com/reference/protected-branches.md>
- beads git integration (sync branch removed): <https://beads.gascity.com/reference/git-integration.md>
- session-ops spec §5, §7, Appendix B, Appendix C: `plans/2026-08-09-session-ops-v1-spec.md`
