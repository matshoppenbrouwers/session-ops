#!/usr/bin/env bash
# SEQ-016 acceptance: escalations_awaiting() counts real ESC-NNN entries only —
# the format-header example /ops-enroll writes is documentation, not an escalation.
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

check_eq() { # check_eq <description> <expected> <actual>
  local desc="$1" want="$2" got="$3"
  [ "$want" = "$got" ] && { echo "  PASS  $desc"; return; }
  echo "  FAIL  $desc (expected ${want}, got ${got})"; fail=1
}

# Load the script as a module (its filename is not importable) and print one value.
py() { # py <expression using m and the unit path in `unit`>
  python3 - "$1" "$2" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("ops_portfolio", "scripts/ops-portfolio.py")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
unit = sys.argv[1]
print(eval(sys.argv[2]))
PY
}

count()  { py "$1" "m.escalations_awaiting(unit)"; }
# Index 6 of a row is the Escalations cell; --no-fetch semantics, empty workspace.
cell()   { py "$1" "m.build_row(unit, {}, True, {}, unit)[6]"; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkunit() { # mkunit <name> — returns nothing; creates $tmp/<name>/_devdocs/todo
  mkdir -p "$tmp/$1/_devdocs/todo"
}

header() { # header <name> — the exact block /ops-enroll Step 5.5 writes
  cat > "$tmp/$1/_devdocs/todo/escalations.md" <<'MD'
# Escalations

Bot-owned. Every line uses the pinned format:

- [ ] ESC-NNN (date, origin): summary. _Grounding: …_
MD
}

echo "1. A file holding only the format header has nothing awaiting"
mkunit header-only; header header-only
check_eq "header-only counts 0" "0" "$(count "$tmp/header-only")"
check_eq "header-only renders 0" "0" "$(cell "$tmp/header-only")"

echo "2. A real open entry counts"
mkunit one-open; header one-open
cat >> "$tmp/one-open/_devdocs/todo/escalations.md" <<'MD'
- [ ] ESC-001 (2026-08-13, issue #4): Auth rework — architectural. _Grounding: PRD §2._
MD
check_eq "header + one open entry counts 1" "1" "$(count "$tmp/one-open")"
check_eq "header + one open entry renders 1" "1" "$(cell "$tmp/one-open")"

echo "3. A ticked entry is consumed, not awaiting"
mkunit ticked; header ticked
cat >> "$tmp/ticked/_devdocs/todo/escalations.md" <<'MD'
- [ ] ESC-001 (2026-08-13, issue #4): Auth rework — architectural. _Grounding: PRD §2._
- [x] ESC-002 (2026-08-13, issue #5): Sync retry policy. _Grounding: PRD §6._
MD
check_eq "one open + one ticked counts 1" "1" "$(count "$tmp/ticked")"

echo "4. Several real entries all count"
mkunit many; header many
cat >> "$tmp/many/_devdocs/todo/escalations.md" <<'MD'
- [ ] ESC-001 (2026-08-13, issue #4): One. _Grounding: PRD §2._
- [ ] ESC-014 (2026-08-13, issue #9): Two. _Grounding: PRD §3._
- [ ] ESC-107 (2026-08-14, inbox): Three. _Grounding: PRD §4._
MD
check_eq "three open entries count 3" "3" "$(count "$tmp/many")"

echo "5. No escalations file at all stays distinct from an empty one"
mkunit no-file
check_eq "missing file returns None" "None" "$(count "$tmp/no-file")"
check_eq "missing file renders —" "—" "$(cell "$tmp/no-file")"

echo "6. The counter is anchored — a mention of the format elsewhere is not an entry"
mkunit prose; header prose
cat >> "$tmp/prose/_devdocs/todo/escalations.md" <<'MD'
Note: entries look like `- [ ] ESC-001 (…)` — see the header.
- [ ] ESC-020 (2026-08-14, issue #7): Real one. _Grounding: PRD §1._
MD
check_eq "indented/quoted mention not counted" "1" "$(count "$tmp/prose")"

echo
[ "$fail" -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit "$fail"
