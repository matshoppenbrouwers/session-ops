# SEQ-018: Decide the registry cross-read with scribe.json

**Status**: [x]
**Decision**: (a) — `/ops-init` prefills `repo` from scribe.json; scribe.json is the senior source for path→owner/name. Chosen by the operator 2026-08-14.
**Priority**: P3
**Sequence**: SEQUENCE.md
**Research**: ../session-scribe/_devdocs/research/2026-08-14-three-plugin-alignment.md (§3.1)

## Context

`~/.claude/ops.json` units and `~/.claude/scribe.json` projects both map an absolute repo path
to `owner/name` with identical longest-prefix keying (ops credits it as "scribe's rule",
`skills/ops-init/SKILL.md:77`). Same fact, two files, no cross-read — a renamed repo or moved
checkout is fixed twice. The review verdict is *duplicated*, currently unfelt (the live
registries share zero repos). Depends on SEQ-017: a cross-read built before the config-dir
asymmetry is fixed reads the wrong directory on `CLAUDE_CONFIG_DIR` machines.

## Task

**Files**: `skills/ops-init/SKILL.md`, `examples/ops.json`, `README.md`

**Instructions**:
- Decide between: (a) `/ops-init` prefills a unit's `repo` from `scribe.json`'s
  `projects.<path>.github.repo` when the path is already registered there, and the docs name
  scribe.json the senior source for the path→owner/name fact; or (b) the duplication is
  accepted, and README's coupling section says so and names the two-file fix for a moved
  checkout.
- Implement the chosen option; either way, record the decision and its reason in README's
  coupling section so the next review doesn't re-derive it.

**Accept**: README states the relationship between the two registries explicitly (cross-read or
accepted duplication), and `/ops-init`'s behavior matches the statement.

**Test**: `grep -c 'scribe.json' README.md` — expect ≥1.
