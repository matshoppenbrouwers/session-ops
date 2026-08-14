#!/usr/bin/env python3
"""ops-portfolio.py — deterministic portfolio aggregation (session-ops spec §8).

Walks the registry (ops.json in the Claude config directory), inspects each
unit's local clone,
and regenerates {workspace}/PORTFOLIO.md whole (write-only output — never
merged with existing content), then appends one §9-schema line to
{workspace}/runs.jsonl.

Python 3 stdlib only. Same input, same output, zero tokens.

Flags:
  --registry PATH   registry file (default: ops.json under $CLAUDE_CONFIG_DIR
                    when set, else ~/.claude/ops.json)
  --no-fetch        skip `git fetch` and every remote API call; all
                    remote-derived columns render "n/a"

Degradation (spec §2): a unit whose local clone is missing is marked
`unreachable` and the rest are reported; absence of any file yields an
empty "—" cell, never an error. A missing registry or workspace is the one
hard stop: exit with "run /ops-init".
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import date, datetime, timezone

NA = "n/a"
EMPTY = "—"

STATUS_ENUM = ("complete", "timeout", "stalled", "max-turns", "tool-failure", "escalated")

# Workflow files /ops-enroll installs; names double as the API-side workflow names.
OPS_WORKFLOWS = ("ops-triage.yml", "ops-sweep.yml")

TEMPLATE_VERSION_RE = re.compile(r"#\s*ops-template-version:\s*(\d+)")
ENTRY_RE = re.compile(r"^- \[([^\]]*)\] (.*)$")
LINK_RE = re.compile(r"→\s*(\S+)")
ESCALATION_RE = re.compile(r"^- \[ \] ESC-\d+\b")
VERSION_RE = re.compile(r"\b(\d+\.\d+(?:\.\d+)?)\b")


def run_git(unit_path, *args):
    """Run a git command in a unit; return stdout or None (never raises)."""
    try:
        out = subprocess.run(
            ["git", "-C", unit_path, *args],
            capture_output=True, text=True, timeout=60,
        )
        if out.returncode == 0:
            return out.stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        pass
    return None


# ---------------------------------------------------------------- registry

def default_registry():
    """ops.json in the Claude config directory — $CLAUDE_CONFIG_DIR when set,
    else ~/.claude. Mirrors session-scribe's resolution of scribe.json, so the
    two registries always share a directory."""
    config_dir = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
    return os.path.join(config_dir, "ops.json")


def load_registry(path):
    try:
        with open(path, encoding="utf-8") as f:
            reg = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        sys.exit(f"ops-portfolio: cannot read registry {path}: {e} — run /ops-init")
    for key in ("workspace", "budget", "units"):
        if key not in reg:
            sys.exit(f"ops-portfolio: registry missing '{key}' — run /ops-init")
    return reg


# --------------------------------------------------------------- unit paths

def todo_dir(unit_path):
    """Resolve the unit's {todo} directory.

    `.session-flow.json` paths.todo wins; otherwise the session-flow default
    `_devdocs/todo/`, falling back to a bare `todo/` when only that exists.
    """
    cfg = os.path.join(unit_path, ".session-flow.json")
    if os.path.isfile(cfg):
        try:
            with open(cfg, encoding="utf-8") as f:
                paths = json.load(f).get("paths", {})
            if paths.get("todo"):
                return os.path.join(unit_path, paths["todo"])
        except (OSError, json.JSONDecodeError):
            pass
    default = os.path.join(unit_path, "_devdocs", "todo")
    if os.path.isdir(default):
        return default
    bare = os.path.join(unit_path, "todo")
    if os.path.isdir(bare):
        return bare
    return default


def sequence_path(unit_path):
    """Resolve SEQUENCE.md: `.session-flow.json` paths.sequence, else {todo}/SEQUENCE.md."""
    cfg = os.path.join(unit_path, ".session-flow.json")
    if os.path.isfile(cfg):
        try:
            with open(cfg, encoding="utf-8") as f:
                paths = json.load(f).get("paths", {})
            if paths.get("sequence"):
                return os.path.join(unit_path, paths["sequence"])
        except (OSError, json.JSONDecodeError):
            pass
    return os.path.join(todo_dir(unit_path), "SEQUENCE.md")


# ------------------------------------------------------------ local columns

def backlog_counts(unit_path):
    """Count SEQUENCE.md entries per session-status Step 2b.

    total = every `- [token]` entry, whatever the token; done = `[x]`; ready =
    open (`[ ]`) with a `→` link to an existing file; needs-breakdown = open
    with trailing `(needs breakdown)` or a missing/dangling link.

    A token that is neither empty nor `x` (`[DEFERRED]`, `[?]`, …) is a
    non-standard state session-ops does not interpret: it counts in `total`
    and in `other`, and in none of done/ready/needs. It is never dropped —
    the regex captures the token instead of filtering on it, so no entry can
    go missing from every count.

    Returns (done, total, ready, needs_breakdown, other) or None when absent.
    """
    seq = sequence_path(unit_path)
    if not os.path.isfile(seq):
        return None
    done = total = ready = needs = other = 0
    with open(seq, encoding="utf-8") as f:
        for line in f:
            m = ENTRY_RE.match(line.rstrip())
            if not m:
                continue
            total += 1
            token = m.group(1).strip().lower()
            if token == "x":
                done += 1
                continue
            if token:
                other += 1
                continue
            body = m.group(2)
            link = LINK_RE.search(body)
            target_exists = False
            if link:
                target = link.group(1).split("#")[0]
                target_exists = (
                    os.path.isfile(os.path.join(unit_path, target))
                    or os.path.isfile(os.path.join(os.path.dirname(seq), target))
                )
            if "(needs breakdown)" in body or not target_exists:
                needs += 1
            else:
                ready += 1
    return done, total, ready, needs, other


def inbox_depth(unit_path):
    inbox = os.path.join(todo_dir(unit_path), "inbox")
    if not os.path.isdir(inbox):
        return None
    return len([n for n in os.listdir(inbox) if n.endswith(".md")])


def escalations_awaiting(unit_path):
    """Count unticked escalations, or None when the file is absent.

    Only the pinned format's *numbered* form counts: `/ops-enroll` writes a
    format example (`- [ ] ESC-NNN (date, origin): summary`) into the header of
    every unit's escalations.md, and matching bare `- [ ]` scored that example
    as a real escalation — an empty file read as 1 awaiting, forever. `\\d+`
    cannot match the literal `NNN`, which is the discriminator.

    A ticked box is consumed by the next sweep, so "awaiting" means unticked.
    """
    esc = os.path.join(todo_dir(unit_path), "escalations.md")
    if not os.path.isfile(esc):
        return None
    with open(esc, encoding="utf-8") as f:
        return sum(1 for line in f if ESCALATION_RE.match(line))


def last_release(unit_path):
    """Top CHANGELOG.md version, falling back to the latest git tag."""
    changelog = os.path.join(unit_path, "CHANGELOG.md")
    if os.path.isfile(changelog):
        with open(changelog, encoding="utf-8") as f:
            for line in f:
                if line.startswith("#"):
                    m = VERSION_RE.search(line)
                    if m:
                        return m.group(1)
    tag = run_git(unit_path, "describe", "--tags", "--abbrev=0")
    if tag:
        return tag
    tags = run_git(unit_path, "tag", "--sort=-creatordate")
    if tags:
        return tags.splitlines()[0]
    return None


def last_activity(unit_path):
    """Last commit date on the default branch (falls back to HEAD)."""
    head = run_git(unit_path, "symbolic-ref", "--quiet", "refs/remotes/origin/HEAD")
    ref = head if head else "HEAD"
    return run_git(unit_path, "log", "-1", "--format=%cs", ref) or run_git(
        unit_path, "log", "-1", "--format=%cs"
    )


# ---------------------------------------------------- clock-state columns

def installed_template_versions(unit_path):
    """{workflow-name: version-int-or-None} for installed ops workflows."""
    found = {}
    for name in OPS_WORKFLOWS:
        wf = os.path.join(unit_path, ".github", "workflows", name)
        if not os.path.isfile(wf):
            continue
        version = None
        with open(wf, encoding="utf-8") as f:
            m = TEMPLATE_VERSION_RE.search(f.read())
            if m:
                version = int(m.group(1))
        found[name] = version
    return found


def current_template_versions(templates_dir):
    """Versions shipped in this repo's templates/ (empty until Phase 4 lands)."""
    versions = {}
    if not os.path.isdir(templates_dir):
        return versions
    for name in OPS_WORKFLOWS:
        path = os.path.join(templates_dir, name)
        if os.path.isfile(path):
            with open(path, encoding="utf-8") as f:
                m = TEMPLATE_VERSION_RE.search(f.read())
                if m:
                    versions[name] = int(m.group(1))
    return versions


def sweep_scheduled(unit_path):
    """True when ops-sweep.yml carries an active (uncommented) schedule trigger."""
    wf = os.path.join(unit_path, ".github", "workflows", "ops-sweep.yml")
    if not os.path.isfile(wf):
        return False
    with open(wf, encoding="utf-8") as f:
        for line in f:
            if re.match(r"^\s*schedule:", line):
                return True
    return False


def clock_state(unit_path, shipped_versions):
    """Render 'triage+sweep (scheduled)', staleness-flagged, or —."""
    installed = installed_template_versions(unit_path)
    if not installed:
        return EMPTY
    parts = [n.replace("ops-", "").replace(".yml", "") for n in installed]
    mode = "scheduled" if sweep_scheduled(unit_path) else "dispatch-only"
    stale = any(
        shipped_versions.get(name) is not None
        and (ver is None or ver < shipped_versions[name])
        for name, ver in installed.items()
    )
    label = f"{'+'.join(parts)} ({mode})"
    if stale:
        label += " ⚠ stale template"
    return label


# ----------------------------------------------------------- remote columns

def github_api(path, token=None):
    """GET a GitHub API path via `gh api` or a token from the environment.

    Returns parsed JSON or None — never raises, never crashes offline.
    """
    if shutil.which("gh"):
        try:
            out = subprocess.run(
                ["gh", "api", path], capture_output=True, text=True, timeout=30
            )
            if out.returncode == 0:
                return json.loads(out.stdout)
        except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError):
            pass
    token = token or os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if not token:
        return None
    req = urllib.request.Request(
        f"https://api.github.com/{path.lstrip('/')}",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.load(resp)
    except (urllib.error.URLError, OSError, json.JSONDecodeError, ValueError):
        return None


def ops_runs(repo):
    """Recent ops workflow runs for owner/name, newest first, or None."""
    data = github_api(f"repos/{repo}/actions/runs?per_page=100")
    if not data or "workflow_runs" not in data:
        return None
    return [
        r for r in data["workflow_runs"]
        if r.get("name") in ("ops-triage", "ops-sweep")
        or (r.get("path") or "").endswith(OPS_WORKFLOWS)
    ]


def freshness(runs):
    """(days since last successful run, current failure streak) from API runs."""
    if runs is None:
        return NA, NA
    days = NA
    for r in runs:
        if r.get("conclusion") == "success":
            created = r.get("created_at", "")
            try:
                dt = datetime.strptime(created, "%Y-%m-%dT%H:%M:%SZ").replace(
                    tzinfo=timezone.utc
                )
                days = (datetime.now(timezone.utc) - dt).days
            except ValueError:
                pass
            break
    streak = 0
    for r in runs:
        if r.get("conclusion") is None:  # in-progress runs don't break a streak
            continue
        if r.get("conclusion") == "failure":
            streak += 1
        else:
            break
    return days, streak


def freshness_cell(days, streak):
    """Render the freshness column, each half independently.

    days and streak fail independently — a unit with no successful run still
    has a known streak — so each half renders its own value or `n/a`. Only a
    cell with nothing known at all collapses to a bare `n/a`.
    """
    if days == NA and streak == NA:
        return NA
    days_s = NA if days == NA else f"{days}d ago"
    streak_s = NA if streak == NA else f"streak {streak}"
    return f"{days_s} · {streak_s}"


def runs_today(runs):
    """Count of ops runs created today (UTC) in an API run list."""
    today = date.today().isoformat()
    return sum(1 for r in runs if (r.get("created_at") or "").startswith(today))


# ----------------------------------------------- unannounced-release column

def parse_version(text):
    m = VERSION_RE.search(text or "")
    if not m:
        return None
    return tuple(int(p) for p in m.group(1).split("."))


def announced_versions(unit_path, workspace):
    """Versions already announced: release-announce inbox items for the unit
    plus the last kind:"announce" line's detail in runs.jsonl."""
    versions = set()
    inbox = os.path.join(todo_dir(unit_path), "inbox")
    if os.path.isdir(inbox):
        for name in os.listdir(inbox):
            if not name.endswith(".md"):
                continue
            try:
                with open(os.path.join(inbox, name), encoding="utf-8") as f:
                    head = f.read(2048)
            except OSError:
                continue
            if re.search(r"^source:\s*release-announce", head, re.M):
                m = re.search(r"^version:\s*(\S+)", head, re.M)
                if m:
                    v = parse_version(m.group(1))
                    if v:
                        versions.add(v)
    runs_file = os.path.join(workspace, "runs.jsonl")
    if os.path.isfile(runs_file):
        last = None
        with open(runs_file, encoding="utf-8") as f:
            for line in f:
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if rec.get("kind") == "announce" and rec.get("unit") == unit_path:
                    last = rec
        if last:
            v = parse_version(str(last.get("detail")))
            if v:
                versions.add(v)
    return versions


def unannounced_release(unit_path, workspace, release):
    """'vX.Y.Z' when the last release is newer than everything announced, else —."""
    rel = parse_version(release or "")
    if not rel:
        return EMPTY
    announced = announced_versions(unit_path, workspace)
    if all(rel > v for v in announced):  # vacuously true when nothing announced
        return f"yes ({release})"
    return EMPTY


# ------------------------------------------------------------------ output

def build_row(unit_path, meta, no_fetch, shipped_versions, workspace):
    name = os.path.basename(unit_path.rstrip("/"))
    if not os.path.isdir(unit_path):
        return [name, meta.get("kind", EMPTY), "unreachable"] + [EMPTY] * 8

    if not no_fetch:
        run_git(unit_path, "fetch", "--quiet")

    counts = backlog_counts(unit_path)
    if counts:
        done, total, ready, needs, other = counts
        backlog = f"{done}/{total}"
        if other:
            backlog += f" · {other} other"
        ready_s, needs_s = str(ready), str(needs)
    else:
        backlog = ready_s = needs_s = EMPTY

    inbox = inbox_depth(unit_path)
    esc = escalations_awaiting(unit_path)
    release = last_release(unit_path)
    activity = last_activity(unit_path)

    if no_fetch:
        days = streak = NA
    else:
        days, streak = freshness(ops_runs(meta.get("repo", "")))

    return [
        name,
        meta.get("kind", EMPTY),
        backlog,
        ready_s,
        needs_s,
        str(inbox) if inbox is not None else EMPTY,
        str(esc) if esc is not None else EMPTY,
        release or EMPTY,
        activity or EMPTY,
        clock_state(unit_path, shipped_versions),
        freshness_cell(days, streak),
        unannounced_release(unit_path, workspace, release),
    ]


HEADERS = [
    "Unit", "Kind", "Backlog", "Ready", "Needs breakdown", "Inbox",
    "Escalations", "Last release", "Last activity", "Clock",
    "Freshness", "Unannounced release",
]


def budget_line(registry, no_fetch, workspace):
    budget = registry.get("budget", {})
    cap = budget.get("max_ci_runs_per_day")
    if no_fetch:
        count = NA
    else:
        seen_repos, total = set(), 0
        counted = False
        for meta in registry.get("units", {}).values():
            repo = meta.get("repo")
            if not repo or repo in seen_repos:
                continue
            seen_repos.add(repo)
            runs = ops_runs(repo)
            if runs is not None:
                total += runs_today(runs)
                counted = True
        count = total if counted else NA
    line = f"**Budget:** today's ops CI runs {count} / {cap}"
    monthly = budget.get("monthly_usd")
    if monthly is not None:
        month = date.today().strftime("%Y-%m")
        spent = 0.0
        runs_file = os.path.join(workspace, "runs.jsonl")
        if os.path.isfile(runs_file):
            with open(runs_file, encoding="utf-8") as f:
                for raw in f:
                    try:
                        rec = json.loads(raw)
                    except json.JSONDecodeError:
                        continue
                    if (rec.get("ts") or "").startswith(month) and rec.get("cost_usd"):
                        spent += float(rec["cost_usd"])
        line += f" · month-to-date ${spent:.2f} / ${monthly}"
    return line


def render(rows, registry, no_fetch, workspace):
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    lines = [
        "# Portfolio",
        "",
        f"_Generated {now} by ops-portfolio.py — write-only output, regenerated whole, never hand-edited._",
        "",
        "| " + " | ".join(HEADERS) + " |",
        "|" + "|".join("---" for _ in HEADERS) + "|",
    ]
    for row in rows:
        row = row + [EMPTY] * (len(HEADERS) - len(row))
        lines.append("| " + " | ".join(row) + " |")
    lines += ["", budget_line(registry, no_fetch, workspace), ""]
    return "\n".join(lines)


def append_run(workspace, status, duration_s):
    rec = {
        "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "unit": None,
        "kind": "portfolio",
        "status": status if status in STATUS_ENUM else "tool-failure",
        "duration_s": duration_s,
        "cost_usd": None,
        "detail": None,
    }
    with open(os.path.join(workspace, "runs.jsonl"), "a", encoding="utf-8") as f:
        f.write(json.dumps(rec) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", default=default_registry())
    parser.add_argument("--no-fetch", action="store_true")
    args = parser.parse_args()

    start = time.monotonic()
    registry = load_registry(args.registry)
    workspace = registry["workspace"]
    if not os.path.isdir(workspace):
        sys.exit(f"ops-portfolio: workspace {workspace} missing — run /ops-init")

    templates_dir = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "templates"
    )
    shipped = current_template_versions(templates_dir)

    rows = [
        build_row(path, meta or {}, args.no_fetch, shipped, workspace)
        for path, meta in sorted(registry.get("units", {}).items())
    ]

    output = render(rows, registry, args.no_fetch, workspace)
    with open(os.path.join(workspace, "PORTFOLIO.md"), "w", encoding="utf-8") as f:
        f.write(output)

    append_run(workspace, "complete", round(time.monotonic() - start, 1))
    print(f"portfolio: {len(rows)} unit(s) → {os.path.join(workspace, 'PORTFOLIO.md')}")


if __name__ == "__main__":
    main()
