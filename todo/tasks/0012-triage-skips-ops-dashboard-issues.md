# SEQ-012: `ops-triage` must skip issues labelled `ops-dashboard`

**Status**: [x]
**Priority**: P2
**Sequence**: todo/SEQUENCE.md
**Origin**: SEQ-005 / 4B-1 live test, 2026-08-13

## Context (read first)

`ops-triage.yml` fires on `issues: [opened, reopened]` and its job-level `if:` skips
exactly one thing:

```yaml
if: ${{ !contains(github.event.issue.labels.*.name, 'scribe:mirror') }}
```

The pinned ops dashboard issue is bot-owned and labelled `ops-dashboard`. It is not
skipped. Triaging it means gatekeeper triages the bot's own render — reading
"ops dashboard: <repo>" as if a human had filed it, spending a quota slot, and
plausibly writing a nonsense escalation about the escalation list.

During 4B-1 this was avoided by creating and pinning the dashboard issue **before**
pushing the workflows, so no trigger existed yet. That ordering is now baked into
`/ops-enroll`, which closes the enrolment path — but the hazard is still live:
**reopening** the dashboard issue fires `issues: [reopened]` and triages it. Closing
and reopening a pinned issue is an ordinary thing to do.

The reasoning mirrors the `scribe:mirror` skip in commit `c61b7ae`: filter on the
label rather than the author, because the bot commits under the same account a human
files issues from.

## Files

- `templates/ops-triage.yml`

## Instructions

- Extend the job-level `if:` to skip `ops-dashboard` as well as `scribe:mirror`.
  Keep it a single expression evaluated before any step, so a skipped run costs no
  quota slot and reports as skipped rather than failed.
- Extend the existing comment block to explain the second label in the same voice as
  the first: the dashboard issue is the sweep's own output, so triaging it feeds the
  bot its own render.
- Preserve the `workflow_dispatch` escape: `github.event.issue` is absent on a manual
  dispatch, so the expression stays false there and an operator can still deliberately
  triage any issue by number. Verify this holds for the combined condition.
- Bump `# ops-template-version:` (currently 6).

## Accept

An `issues:` event on an issue labelled `ops-dashboard` skips the job before the guard
runs; a `workflow_dispatch` against the same issue number still triages it.

## Test

`grep -q "ops-dashboard" templates/ops-triage.yml && grep -q "scribe:mirror" templates/ops-triage.yml`

`python3 -c "import yaml; d=yaml.safe_load(open('templates/ops-triage.yml')); print(d['jobs']['triage']['if'])"`
— the printed expression must reference both labels.

Live: reopen the pinned dashboard issue on an enrolled repo and confirm the triage run
is skipped, with `ops-guard` never invoked.
