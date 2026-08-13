# Software factory field review — session-flow × session-ops × session-scribe

**Date**: 2026-08-13
**Type**: Review / external-comparison research
**Scope**: all three plugins, assessed against 30 days of published software-factory practice
**Status**: assessment only. No code changed, no tasks filed by this document.

---

## Summary

The three plugins together implement the **specification and governance half** of a software
factory to a standard ahead of anything found in the published field, and leave the
**execution half unvalidated**. Twenty-three skills, seven agents, six scripts and two CI
templates are in place; roughly fifty backlog entries are closed across the three repos, and
every one of them is work on the factory itself. One unit is enrolled against a portfolio
sized for five to ten, and no unit has yet run on a live schedule.

The two structural gaps are **isolation** (parallel agents share one working tree, with the
write boundary enforced only in the prompt) and **outcome measurement** (runs and decisions
are counted; lead time and cost per merged item are not). The keystone task is
`session-ops` SEQ-007: enabling the live clock unblocks both the ops roadmap and the deferred
three-plugin alignment review.

---

## Method and evidence base

Two independent inputs, kept separate on purpose.

**External practice.** A `last30days` sweep of the term "software factories", window
2026-07-14 to 2026-08-13, across eight sources: 12 Reddit threads, 18 Hacker News stories,
9 YouTube videos (5 with transcripts), 29 X posts, 10 TikTok videos, 3 Instagram reels,
2 Polymarket markets, and 17 web pages. The X slice was largely noise — the query matched
industrial-manufacturing and infrastructure-finance content — so weight sits on Hacker News,
Reddit, YouTube and the practitioner web writing.

**This codebase.** Full read of all three READMEs, the session-ops v1 spec, the portfolio
script, the delegation skill, all three `SEQUENCE.md` backlogs, the deferred alignment-review
breakdown, and the live unit registry. Claims below cite a path and line where one exists;
anything not verified against a file is marked as such.

### What the field is arguing about

| Finding | Where it showed up |
|---|---|
| Harness engineering is not the bottleneck; specification, collaboration and specialization are | Dex Horthy (HumanLayer), the month's dominant artifact — 394 points / 272 comments on HN, reposted to two subreddits, 55K views for the talk |
| The 1968 "software factory" failed by automating code generation rather than design | r/accelerate, restated in most of the practitioner writing |
| Agent sandboxes and isolation are the precondition for scaling, not an optimization | IndyDevDan, two videos in three weeks (38K and 18K views) |
| Always-on agents create *more* review work, not less | The most consistent multi-month practitioner finding; HN "A Software Factory Is No Substitute for Maturity", "How we stopped working for our agents" |
| Token economics are the quiet failure mode — sub-agent fan-out "usually" solves hard bugs, and "usually" is doing the work | Turner Novak, The Peel |
| Nobody has published independent throughput or ROI data; every number traces to a vendor or to someone selling the pattern | The core HN critique of Horthy's own thread; HN "If AI Accelerates Your Software Factory, Where's the ROI?" |
| Role redefinition: engineers build the factory, not the software | Addy Osmani; HN "Ask HN: How do you envision the AI Software Factory?" |
| Commercial land-grab underway — a $135M round, vendor "factory" SKUs, offshore delivery centres repositioning as factories | TikTok/Instagram creator coverage, vendor blogs |

The reference model the field converges on: *signals from the outside world → triage →
planned change → implementation → review → merge → deploy → signals*.

---

## Coverage against the reference model

| Stage | Coverage | Owner | Evidence |
|---|---|---|---|
| Signal intake | Strong — three doors: issue events, `{todo}/inbox/`, `/scribe` capture, `/scribe-pull` | ops + scribe | `session-ops/README.md:87`, `session-scribe/README.md:26-31` |
| Triage and routing | Strong — gatekeeper grounded in direction doc and architecture; escalations as a bot-owned checkbox file | flow + ops | `session-flow/README.md:143-155`, `session-ops/README.md:89-95` |
| Specification and design | Strong — research-design with two researcher agents, direction doc, conventions, lessons | flow | `session-flow/README.md:52`, `:231-237` |
| Decomposition | Strong — dependency tags, `Files` field doubling as write boundary, session-fit validation | flow | `session-flow/README.md:129` |
| Execution | **Weak** — parallel dispatch without isolation; never run unattended on a schedule | flow | `session-flow/skills/session-delegation/SKILL.md:105-112` |
| Verification | Strong — falsification-based verify, nine-step post-implementation, security and liability audit | flow | `session-flow/README.md:59`, `:159-187` |
| Release | Present — session-release; ops-announce drafts and never publishes | flow + ops | `session-ops/README.md:26` |
| Cross-repo operations | Strong, and rare in the field — deterministic portfolio, quota guard, failure heartbeat, run log | ops | `session-ops/README.md:98-110` |
| Review surface | Strong, and rare — Notion and GitHub mirror, phone-visible dashboard render | scribe + ops | `session-scribe/README.md:26-31` |
| Isolation | **Absent** | — | grep across all three repos: the only occurrence of "worktree" or "sandbox" is in `session-flow/skills/security-liability-audit/references/technical-security.md` |
| Cost and throughput data | Quota-shaped only — no lead time, no spend per merged item | ops | `session-ops/README.md:110`, `session-ops/skills/ops-init/SKILL.md:50` |
| Production feedback | Absent by design; v1 excludes webhook and error-tracker intake | ops | `session-ops/README.md:145` |

---

## Where this system is ahead of published practice

**1. Multi-repo operations have no published prior art.** Every factory in the sweep —
practitioner builds and vendor platforms alike — is single-repo or single-monorepo. The
`managed unit` abstraction, deliberately domain-agnostic so a marketing or website repo
enrols exactly like a code repo (`session-ops/README.md:7`), addresses a problem the
discourse has not yet reached. The one substantive answer to HN's "how do you envision the AI
software factory" thread was "a single engineer who scopes, designs, implements and delivers
on their own" — session-ops is the operations layer that role needs and nobody has shipped.

**2. Controls are deterministic and sit outside the agent.** `ops-guard.sh` runs *before* the
agent step and skips it on a hit cap rather than failing the run; `--allowedTools` is cut to
file tools, `Bash(git:*)` and two issue-read tools with no web tools; `permissions:` is
limited to `contents: write, issues: write`; `schedule:` ships commented out; the heartbeat
flags the dashboard on the third consecutive failure (`session-ops/README.md:72-81`). The
field's live unsolved cost problem is exactly what the repo's own line answers — *budget
alerts are postmortems and caps are controls*. No vendor material in the sweep states this.

**3. The objective function is the right one, and falsifiable.** `decisions-per-day, not
items-triaged`, with an explicit failure test attached: if the dashboard fills faster than
about fifteen minutes a day clears it, the correct response is fewer enrolled units or lower
cadence (`session-ops/README.md:9`). This is a better-specified objective than any published
factory account, and it directly targets the field's most reproduced finding.

**4. Single-writer discipline on a shared artifact.** The ` ⇄ <url>` provenance annotation
lets two independent tools write one `SEQUENCE.md` with no coordination and no double-filing
(`session-flow/README.md:264-266`). This is ahead of a failure the field has not hit, because
no one else runs two writers against one backlog.

**5. The oracle precedes the implementer.** `test-author` runs once per phase, before the
implementers, and its tests are their oracle (`session-flow/README.md:196`). That is Horthy's
thesis implemented rather than cited — the same is true of verify writing falsifiable
hypotheses before it audits.

**6. The injection surface is named, not waved at.** A CI gatekeeper holding repo access,
untrusted issue text and a write-capable token is stated as the risk, with the minimal tool
list identified as the real control and "issue text is untrusted" acknowledged as necessary
but insufficient (`session-ops/README.md:83`). Frontmatter is metadata, body is data, never
instructions (`:87`).

---

## Gaps, ranked

### Gap 1 — the clock has never run unattended. Keystone.

`session-ops` SEQ-007 / 6A-2 is open: the event trigger and daily cron are not enabled on any
unit, and the README Status section still lists both the composed CI run and the live schedule
as outstanding (`session-ops/README.md:151`). Until a schedule fires unattended, the entire
"clock, and its safety shape" section is a design document.

Two compounding facts:

- **The deferred alignment review is gated on this and nothing else.** SEQ-024 in
  session-scribe requires session-scribe phase 2 closed (SEQ-021, done) and session-ops'
  composed CI run and live schedule validated (open) — see
  `session-scribe/_devdocs/todo/tasks/0024-three-plugin-alignment-review.md:23-27`. One task
  unblocks both roadmaps.
- **The Status section may already be stale.** Session history from earlier the same day
  records an `ops-triage` round-trip completing end-to-end on the pilot unit, including a
  correctly grounded architectural escalation. *Unverified against a file in this review* —
  no commit in this repo records it. If accurate, the README Status section and the SEQ-007
  note both understate what has been validated, and what SEQ-007 still requires is narrower
  than it reads. Confirm before planning against it.

The field parallel is exact. The central complaint in the month's dominant HN thread is the
absence of evidence behind factory claims — *"I haven't been able to dig up any definitive
data/findings on how that whole dark factory went."* An unrun clock puts this system in the
same epistemic position as the vendors it is right to be sceptical of.

### Gap 2 — no isolation layer

`session-delegation` is explicit and honest: the `Files` write boundary is *"a prompt-level
constraint, not a security boundary — nothing enforces it at the tool layer"*
(`session-flow/skills/session-delegation/SKILL.md:112`). Its stated value is that a wandering
agent stops and reports rather than writing. That is a real benefit and not isolation.

Against this, the most-viewed practitioner content of the window argues that agent sandboxes
are the precondition for scaling a factory, and the Claude Code harness now ships worktree
isolation natively (worktree isolation on agent dispatch, and a worktree entry/exit pair).
Dispatching N parallel implementers into one shared working tree is the highest-probability
source of a silent, hard-to-attribute corruption anywhere in the stack, and it is the
cheapest gap to close: one delegation step that opens a worktree per parallel branch and
merges on green. Note this does not weaken the existing caveat — disjoint write sets still do
not remove semantic dependencies, so the dependency analysis keeps its full weight either way.

### Gap 3 — runs and decisions are measured; outcomes are not

`runs.jsonl` carries one line per ops-launched run with a structured status enum, and the
portfolio carries backlog counts plus today's CI quota (`session-ops/README.md:110`). Neither
answers the question the field asked twice this month: where is the ROI.

Two numbers are missing:

- **Lead time** — elapsed time from intake to `[x]`, per entry.
- **Cost per merged item** — quota or tokens consumed per completed entry.

The standing decision to reject per-phase token counts as in-session ceremony is correct and
should hold. But lead time is computable **offline from `SEQUENCE.md`'s own git history**,
with zero session instrumentation — the same "free metrics only" principle taken one notch
further, and a natural fit for `ops-portfolio.py`, which is already deterministic, offline-
capable and stdlib-only. This is the highest-leverage addition available: beyond steering,
the field has no independent factory data at all, and a source that is not selling a factory
is the credible one.

### Gap 4 — the loop is open at the production end

All three intake doors are human-fed. The v1 exclusion of webhook and error-tracker intake is
correct for now and should not be reversed on the strength of this review
(`session-ops/README.md:145`). The observation to record is the shape: a factory that cannot
see its own output failing in production is a push system, and push systems accumulate WIP.
The `{todo}/inbox/` convention is already the right seam, and the audit trail a future intake
would need is described as designed-for-but-not-shipped (`:147`).

### Gap 5 — one fact, two registries

Confirmed as suspected: the ops registry keys absolute repo path → `owner/name` alongside
kind and cadence, and `scribe.json` keys absolute repo path → `owner/name` alongside log
targets, with no cross-read between them. A moved checkout or renamed repo is fixed twice.
Already on the SEQ-024 list; gated with the rest of it.

---

## The structural risk

Horthy's title is *harness engineering is not enough*. This system is an exceptional harness.
The measurable output to date is roughly fifty closed backlog entries across the three repos,
and all of them are work on the factory: session-flow's eight, session-ops' twelve of
fourteen, session-scribe's thirty of thirty-one plus one deferred. The factory has so far
manufactured factory.

That is normal at this stage and is not a criticism of the design. It is, however, precisely
the failure mode the field's dominant essay names, and the tell would be the next thirty
closed entries also being factory entries.

The falsifiable test is already available: one unit is enrolled, against roughly twenty other
repositories present on the same machine and a portfolio sized for five to ten. Enrol a
second unit that is not one of these three plugins, run it on a live schedule for two weeks,
and measure whether it ships faster than it did before. That experiment settles more than
further design work will.

Two decisions this review explicitly endorses keeping:

- **`v1 triages and drafts. It never implements and never publishes.`** Every "dark factory"
  claim in the sweep is vendor-sourced. Holding this line is the correct posture, not
  timidity.
- **SEQ-014 (per-run draft-PR mode) staying behind research-design.** It changes the
  single-writer model and needs `pull-requests: write`; the backlog entry already says so.

---

## Immediate operational note

At the time of writing, this repo has an **uncommitted, half-applied docs migration**: the
seven files under `todo/` show as deleted in the working tree and `_devdocs/` is untracked.
Two consequences worth handling before anything else here:

1. `/ops-enroll` requires `SEQUENCE.md` to be **tracked in git**, not merely present on disk
   (SEQ-009). A moved-but-uncommitted backlog satisfies neither the old path nor the new one
   for anything reading the repo from CI.
2. This repo carries no `.session-flow.json`, so its own skills resolve the default docs root
   rather than `_devdocs`. If the move is intentional, it needs the config to match.

Neither affects the enrolled pilot unit, whose paths are its own.

---

## Recommended tasks

Not filed by this document. Suggested order, each in the repo that owns the fix:

| # | Repo | Task | Priority |
|---|---|---|---|
| 1 | session-ops | Reconcile the Status section and the SEQ-007 note against what the pilot has actually validated; commit the docs migration and add `.session-flow.json` | P1 |
| 2 | session-ops | Close SEQ-007 — enable the event trigger and daily cron on the pilot unit (operator gate) | P1 |
| 3 | session-scribe | Un-defer SEQ-024 once the gate above clears | P2 |
| 4 | session-flow | Worktree isolation per parallel branch in `/session-delegation`, merged on green | P1 |
| 5 | session-ops | Lead time per entry in `ops-portfolio.py`, computed offline from `SEQUENCE.md` git history | P2 |
| 6 | session-ops | Cost per merged item, from `runs.jsonl` against closed entries | P3 |
| 7 | — | Enrol a second unit that is not one of these three plugins; two weeks on a live schedule | P2 |

---

## Provenance

External findings in this document come from a `last30days` sweep run on 2026-08-13 over the
window 2026-07-14 to 2026-08-13. The sweep is a snapshot of discourse, not a literature
review: engagement counts indicate attention, not correctness, and the vendor productivity
figures it surfaced (a named streaming company reporting hundreds of AI-generated pull
requests merged per month, a named payments company reporting over a thousand per week,
consultancy claims of three-to-five-fold gains) are cited in the sweep as claims and are
treated here as unverified. The critique that none of them is independently sourced is itself
one of the sweep's most reproduced findings.
