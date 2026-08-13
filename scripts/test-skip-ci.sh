#!/usr/bin/env bash
# SEQ-014 acceptance: bot commits carry [skip ci], and the claim is documented.
set -uo pipefail
cd /mnt/c/Users/matsh/Desktop/repositories/session-ops

fail=0
check() { # check <description> <expected 0|1> <cmd...>
  local desc="$1" want="$2"; shift 2
  "$@" >/dev/null 2>&1; local got=$?
  [ "$want" -eq 0 ] && [ "$got" -eq 0 ] && { echo "  PASS  $desc"; return; }
  [ "$want" -ne 0 ] && [ "$got" -ne 0 ] && { echo "  PASS  $desc"; return; }
  echo "  FAIL  $desc"; fail=1
}

echo "1. Both templates instruct [skip ci]"
for f in templates/ops-sweep.yml templates/ops-triage.yml; do
  check "$f prompt requires [skip ci]" 0 grep -q 'containing exactly "\[skip ci\]"' "$f"
done

echo "2. The instruction sits inside the agent prompt, not only in a comment"
# Strip all comment lines; the requirement must survive.
for f in templates/ops-sweep.yml templates/ops-triage.yml; do
  check "$f has it in non-comment YAML" 0 \
    bash -c "grep -v '^\s*#' '$f' | grep -q 'skip ci'"
done

echo "3. Template versions bumped (portfolio flags stale installs)"
check "ops-sweep.yml at version 7"  0 grep -qx '# ops-template-version: 7' templates/ops-sweep.yml
check "ops-triage.yml at version 9" 0 grep -qx '# ops-template-version: 9' templates/ops-triage.yml

echo "4. No new permission scope was introduced"
check "pull-requests: not granted in sweep"  1 grep -q 'pull-requests:' templates/ops-sweep.yml
check "pull-requests: not granted in triage" 1 grep -q 'pull-requests:' templates/ops-triage.yml

echo "5. Limits and the escape hatch are documented, not just the happy path"
check "README documents paths-ignore"        0 grep -q 'paths-ignore' README.md
check "README names the push/PR-only limit"  0 grep -q 'pull_request_target' README.md
check "README keeps SEQ-014 as protected-main" 0 grep -q 'protected `main`' README.md
check "spec records the resolution"          0 grep -q 'skip ci' plans/2026-08-09-session-ops-v1-spec.md

echo "6. /ops-enroll's placeholder guard still passes (no new placeholders)"
check "no {placeholder} left unresolved in templates other than {todo}/{cadence}" 1 \
  bash -c "grep -oh '{[a-z_]*}' templates/*.yml | sort -u | grep -qv -e '{todo}' -e '{cadence}'"

echo "7. /ops-capture also pushes to a unit's default branch, so it skips CI too"
check "capture Step 4 requires [skip ci]" 0 \
  grep -q 'containing exactly `\[skip ci\]`' skills/ops-capture/SKILL.md
check "capture non-negotiable 5 mentions it" 0 \
  bash -c "sed -n '20p' skills/ops-capture/SKILL.md | grep -q 'skip ci'"
check "README states the /ops-enroll exception" 0 \
  grep -q 'install commit, which is attended' README.md
check "README credits capture, not just the prompts" 0 \
  grep -q 'ops-capture`, which pushes an inbox file' README.md

echo
[ "$fail" -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit "$fail"
