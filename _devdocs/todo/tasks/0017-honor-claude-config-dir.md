# SEQ-017: Honor CLAUDE_CONFIG_DIR when resolving the registry

**Status**: [x]
**Priority**: P2
**Sequence**: SEQUENCE.md
**Research**: ../session-scribe/_devdocs/research/2026-08-14-three-plugin-alignment.md (§3.1 conflict C3)

## Context

session-scribe resolves its config directory as `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`
(`scribe-hook.sh:19`, `scribe-install.py:122-123`); session-ops hardcodes `~/.claude/ops.json`
in the script default and all five skills. On a machine that sets `CLAUDE_CONFIG_DIR`, the two
registries live in different directories — the alignment review found exactly that live, with
two divergent `scribe.json` copies as fallout. Any future cross-read between the registries
(SEQ-018) resolves the wrong directory until this is fixed.

## Task

**Files**: `scripts/ops-portfolio.py`, `skills/ops-init/SKILL.md`, `skills/ops-enroll/SKILL.md`,
`skills/ops-capture/SKILL.md`, `skills/ops-announce/SKILL.md`, `skills/ops-status/SKILL.md`,
`README.md`

**Instructions**:
- Change `ops-portfolio.py`'s `--registry` default to `$CLAUDE_CONFIG_DIR/ops.json` when the
  variable is set, else `~/.claude/ops.json` (mirror `scribe-install.py:122-123`).
- Replace the hardcoded `~/.claude/ops.json` reference in each of the five skills with the same
  resolution rule, stated once per skill ("the registry, `ops.json` in the Claude config
  directory — `$CLAUDE_CONFIG_DIR` if set, else `~/.claude`").
- Add one line to README's coupling section noting the rule matches session-scribe's.

**Accept**: with `CLAUDE_CONFIG_DIR` set, `/ops-status` and every skill resolve the registry
inside it; with the variable unset, behavior is unchanged.

**Test**: `grep -l 'CLAUDE_CONFIG_DIR' scripts/ops-portfolio.py skills/ops-init/SKILL.md skills/ops-enroll/SKILL.md skills/ops-capture/SKILL.md skills/ops-announce/SKILL.md skills/ops-status/SKILL.md | wc -l` — expect `6`.
