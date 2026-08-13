# SEQ-009: `/ops-enroll` must require SEQUENCE.md be tracked in git

**Status**: [ ]
**Priority**: P1
**Sequence**: todo/SEQUENCE.md
**Origin**: SEQ-005 / 4B-1 live test, 2026-08-13

## Context (read first — this task exists because of a real failure)

`/ops-enroll` Step 1 checks that SEQUENCE.md is **present**, using a filesystem
check. CI only ever sees files that are **tracked in git**.

During 4B-1, `session-scribe` passed enrolment cleanly: `.session-flow.json` present,
`_devdocs/todo/SEQUENCE.md` sitting right there on disk. But session-scribe's
`.gitignore` contains `_devdocs/` ("Internal dev docs — not published"), so zero
files under it are tracked and `GET /contents/_devdocs/todo/SEQUENCE.md` returns 404
on the remote. A CI checkout gets a tree with no `_devdocs/` at all — nothing to
enqueue into, no `escalations.md` to append to, no inbox to sweep.

The enrolment would have been certified as healthy and every run would have failed
to do anything. The whole test had to move to a different repository.

The same trap catches any repo that gitignores its docs root, which is a reasonable
thing to do on a public repo — so this is a common configuration, not an edge case.

## Files

- `skills/ops-enroll/SKILL.md`

## Instructions

- In Step 1's convention table, replace the "SEQUENCE.md present" row with a
  **tracked-in-git** check. `git ls-files --error-unmatch <sequence path>` is the
  precise test: it exits non-zero when the file is untracked *or* ignored, which is
  exactly the condition CI cannot recover from.
- Apply the same rule to the `{todo}` directory the sweep writes into: if `{todo}`
  is ignored, `escalations.md` cannot be committed either. Enrol must stop for the
  same reason.
- Write the failure message so it names the actual cause and the fix, e.g.
  "`_devdocs/todo/SEQUENCE.md` is present but not tracked by git (matched by
  `.gitignore:2 _devdocs/`). CI checks out only tracked files, so the workflows
  would have nothing to write to. Un-ignore the sequence layer, or enrol a
  different unit."
- Add the case to the Degradation section alongside the existing
  "not a session-flow unit" entry.
- Do **not** offer to edit the user's `.gitignore` — that is their call about what
  is published, and on a public repo it may be deliberate.

## Accept

Enrol stops before installing anything when the sequence file or the todo directory
is untracked or ignored, and the message names the file, the cause, and the two
ways out.

## Test

`grep -q "ls-files" skills/ops-enroll/SKILL.md && grep -qi "tracked" skills/ops-enroll/SKILL.md && grep -qi "ignored\|gitignore" skills/ops-enroll/SKILL.md`

Manual check against the original failure: the rule must reject
`session-scribe` (`_devdocs/` ignored, 0 tracked files) and accept
`per-cropfolio` (`_devdocs/` tracked, 30 files).
