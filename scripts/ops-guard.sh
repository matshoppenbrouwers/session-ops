#!/usr/bin/env bash
#
# ops-guard.sh — deterministic quota guard, run before any agent step.
#
# CI shares the operator's Max subscription quota, so a runaway workflow starves
# the operator rather than the credit card (spec §4). This guard is the control:
# it counts today's ops workflow runs across the enrolled repos and tells the
# workflow whether the agent step may start. It is plain shell — no model, no
# agent-visible config, nothing the agent can talk its way past (spec §5).
#
# Installed by /ops-enroll at .github/ops-guard.sh.
#
# Environment (both baked into the workflow env by /ops-enroll from the
# registry — CI cannot read ops.json):
#   OPS_MAX_RUNS_PER_DAY  account-wide cap, from budget.max_ci_runs_per_day
#                         (default 12; 0 disables the agent entirely — the
#                         documented way to test the guard)
#   OPS_ENROLLED_REPOS    space- or comma-separated owner/name list; defaults
#                         to the current repo alone
#   GITHUB_TOKEN          repo-scoped token used for the workflow-run API
#   GITHUB_REPOSITORY     set by Actions
#   GITHUB_API_URL        set by Actions
#   GITHUB_OUTPUT         set by Actions
#
# Outputs (to $GITHUB_OUTPUT):
#   ok=true|false   the agent step gates on this
#   count=<n>       ops runs counted today
#   cap=<n>         the cap in force
#   reason=<slug>   under-cap | cap-reached | cap-zero | unreadable
#
# Exit code is always 0: a hit cap must skip the agent step, not fail the run —
# a red run would trip the heartbeat and read as broken plumbing. When the
# current repo itself cannot be counted the guard fails closed (ok=false) and
# annotates the run with ::error::, so an outage shows up loudly instead of
# quietly removing the only runaway control.
#
# Requires: curl, jq (both preinstalled on GitHub-hosted runners).

set -euo pipefail

CAP="${OPS_MAX_RUNS_PER_DAY:-12}"
API="${GITHUB_API_URL:-https://api.github.com}"
TOKEN="${GITHUB_TOKEN:-}"
SELF_REPO="${GITHUB_REPOSITORY:-}"
TODAY="$(date -u +%Y-%m-%d)"

emit() {
  # emit <ok> <count> <reason>
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
      printf 'ok=%s\n' "$1"
      printf 'count=%s\n' "$2"
      printf 'cap=%s\n' "$CAP"
      printf 'reason=%s\n' "$3"
    } >>"$GITHUB_OUTPUT"
  fi
  printf 'ops-guard: ok=%s count=%s cap=%s reason=%s\n' "$1" "$2" "$CAP" "$3"
  exit 0
}

# Count today's ops runs in one repo. Prints the count, or returns 1 when the
# repo is unreadable with this token.
count_repo() {
  local repo="$1" body
  body="$(curl -sS -m 30 -f \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "${API}/repos/${repo}/actions/runs?per_page=100&created=%3E%3D${TODAY}" \
    2>/dev/null)" || return 1
  printf '%s' "$body" | jq --arg today "$TODAY" '
    [ .workflow_runs[]?
      | select((.created_at // "") | startswith($today))
      | select(.name == "ops-triage" or .name == "ops-sweep"
               or ((.path // "") | test("ops-(triage|sweep)\\.yml$")))
    ] | length' 2>/dev/null || return 1
}

# Resolve the repo list: commas and whitespace both separate.
repos="${OPS_ENROLLED_REPOS:-$SELF_REPO}"
repos="${repos//,/ }"
# shellcheck disable=SC2206
repo_list=(${repos})
[ "${#repo_list[@]}" -gt 0 ] || repo_list=("$SELF_REPO")

# A non-numeric cap is a mis-baked workflow env, not a licence to run unbounded.
case "$CAP" in
  ''|*[!0-9]*)
    echo "::error::ops-guard: OPS_MAX_RUNS_PER_DAY='${CAP}' is not a number — skipping the agent step."
    CAP=0
    emit false 0 unreadable
    ;;
esac

# A cap of 0 skips the agent unconditionally — the documented way to test the
# guard (4B-1). Short-circuited so the test needs no working API.
if [ "$CAP" -le 0 ]; then
  echo "::notice::ops-guard: cap is ${CAP} — agent step skipped by design."
  emit false 0 cap-zero
fi

if [ -z "$TOKEN" ]; then
  echo "::error::ops-guard: no GITHUB_TOKEN — cannot count today's runs, skipping the agent step."
  emit false 0 unreadable
fi

total=0
self_counted=false
degraded=false

for repo in "${repo_list[@]}"; do
  [ -n "$repo" ] || continue
  if n="$(count_repo "$repo")" && [ -n "$n" ]; then
    total=$((total + n))
    if [ "$repo" = "$SELF_REPO" ]; then
      self_counted=true
    fi
  elif [ "$repo" = "$SELF_REPO" ]; then
    echo "::error::ops-guard: cannot read workflow runs for ${repo} — skipping the agent step."
    emit false 0 unreadable
  else
    # A repo-scoped token cannot see sibling repos; fall back to what it can
    # see rather than blocking the run (spec §5).
    echo "::warning::ops-guard: ${repo} unreadable with this token — excluded from today's count."
    degraded=true
  fi
done

if [ "$self_counted" = false ] && [ -n "$SELF_REPO" ]; then
  if n="$(count_repo "$SELF_REPO")" && [ -n "$n" ]; then
    total=$((total + n))
  else
    echo "::error::ops-guard: cannot read workflow runs for ${SELF_REPO} — skipping the agent step."
    emit false 0 unreadable
  fi
fi

if [ "$degraded" = true ]; then
  echo "ops-guard: count is this repo's readable subset only, not account-wide."
fi

# The current run is itself an ops run and is included in the count, so the cap
# is the number of ops runs allowed to start today, this one included.
if [ "$total" -ge "$CAP" ]; then
  echo "::notice::ops-guard: ${total} ops runs today at cap ${CAP} — agent step skipped."
  emit false "$total" cap-reached
fi

emit true "$total" under-cap
