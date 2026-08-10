#!/usr/bin/env bash
#
# ops-heartbeat.sh — failure-streak notifier for the ops clock.
#
# Runs only from an `if: failure()` step. Silent staleness is the documented
# failure class this exists for: an agent that ran stale for months with no
# error (spec §3). Three consecutive failed runs of this workflow prepend one ⚠
# line to the pinned ops dashboard issue, so a dead clock arrives as an ordinary
# GitHub notification instead of waiting to be noticed in /ops-status (spec §8).
#
# Installed by /ops-enroll at .github/ops-heartbeat.sh.
#
# Environment:
#   GITHUB_TOKEN          repo-scoped token (workflow-run API + issues API)
#   GITHUB_REPOSITORY     set by Actions
#   GITHUB_WORKFLOW_REF   set by Actions; names the workflow file to check
#   GITHUB_RUN_ID         set by Actions; linked in the ⚠ line
#   GITHUB_SERVER_URL     set by Actions
#   GITHUB_API_URL        set by Actions
#   OPS_DASHBOARD_ISSUE   optional issue number, baked in by /ops-enroll; when
#                         absent the first open issue labelled `ops-dashboard`
#                         is used
#
# Deterministic — no agent involvement, no model calls. Exit code is always 0:
# the job has already failed, and a noisy heartbeat must not mask why.
#
# Requires: curl, jq (both preinstalled on GitHub-hosted runners).

set -euo pipefail

API="${GITHUB_API_URL:-https://api.github.com}"
SERVER="${GITHUB_SERVER_URL:-https://github.com}"
TOKEN="${GITHUB_TOKEN:-}"
REPO="${GITHUB_REPOSITORY:-}"
RUN_ID="${GITHUB_RUN_ID:-}"
STREAK_THRESHOLD=3

say() { printf 'ops-heartbeat: %s\n' "$1"; }

if [ -z "$TOKEN" ] || [ -z "$REPO" ]; then
  say "no token or repository in the environment — nothing to do."
  exit 0
fi

api_get() {
  curl -sS -m 30 -f \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$1" 2>/dev/null
}

# --------------------------------------------------------- the streak check

# GITHUB_WORKFLOW_REF looks like owner/repo/.github/workflows/ops-sweep.yml@refs/heads/main
WORKFLOW_FILE="${GITHUB_WORKFLOW_REF:-}"
WORKFLOW_FILE="${WORKFLOW_FILE%%@*}"
WORKFLOW_FILE="${WORKFLOW_FILE##*/}"
if [ -z "$WORKFLOW_FILE" ]; then
  say "cannot resolve this workflow's file name — skipping."
  exit 0
fi

runs_json="$(api_get "${API}/repos/${REPO}/actions/workflows/${WORKFLOW_FILE}/runs?per_page=10&status=completed" || true)"
if [ -z "$runs_json" ]; then
  say "workflow-run API unreadable — skipping the streak check."
  exit 0
fi

# Consecutive failures among the most recent *completed* runs. This run is still
# in progress and is not in that list, so it is added on top.
prior="$(printf '%s' "$runs_json" | jq '
  [ .workflow_runs[]? | (.conclusion == "failure") ]
  | index(false) as $i
  | if $i == null then length else $i end' 2>/dev/null || echo 0)"
case "$prior" in ''|*[!0-9]*) prior=0 ;; esac
streak=$((prior + 1))
say "consecutive failures including this run: ${streak}"

# Fire once per outage, on the third failure exactly — runs four and beyond add
# nothing the first line did not already say.
if [ "$streak" -ne "$STREAK_THRESHOLD" ]; then
  say "streak is ${streak}, threshold is ${STREAK_THRESHOLD} — no dashboard write."
  exit 0
fi

# ------------------------------------------------------ the dashboard write

issue="${OPS_DASHBOARD_ISSUE:-}"
if [ -z "$issue" ]; then
  issue="$(api_get "${API}/repos/${REPO}/issues?state=open&labels=ops-dashboard&per_page=1" \
    | jq -r '.[0].number // empty' 2>/dev/null || true)"
fi
if [ -z "$issue" ]; then
  say "no dashboard issue found (set OPS_DASHBOARD_ISSUE or label one ops-dashboard) — skipping."
  exit 0
fi

issue_json="$(api_get "${API}/repos/${REPO}/issues/${issue}" || true)"
if [ -z "$issue_json" ]; then
  say "dashboard issue #${issue} unreadable — skipping."
  exit 0
fi

today="$(date -u +%Y-%m-%d)"
line="⚠ ${WORKFLOW_FILE} has failed ${STREAK_THRESHOLD} times in a row (latest: ${SERVER}/${REPO}/actions/runs/${RUN_ID}, ${today}). The clock is down — this dashboard is stale until it is fixed."

body="$(printf '%s' "$issue_json" | jq -r '.body // ""')"
if printf '%s' "$body" | grep -qF "actions/runs/${RUN_ID}"; then
  say "this run is already flagged on #${issue} — nothing to do."
  exit 0
fi

new_body="$(printf '%s\n\n%s' "$line" "$body")"
payload="$(jq -n --arg body "$new_body" '{body: $body}')"

if curl -sS -m 30 -f -X PATCH \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -d "$payload" \
  "${API}/repos/${REPO}/issues/${issue}" >/dev/null 2>&1; then
  say "flagged the failure streak on dashboard issue #${issue}."
else
  say "could not update dashboard issue #${issue} — the run failure is still in the Actions log."
fi

exit 0
