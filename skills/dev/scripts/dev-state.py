"""Inspect existing dev state without executing any lifecycle action."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys


class EvidenceError(Exception):
    pass


def run(*args, optional=False, cwd=None):
    env = dict(os.environ, GIT_OPTIONAL_LOCKS="0", GH_PROMPT_DISABLED="1")
    result = subprocess.run(args, cwd=cwd, env=env, text=True, capture_output=True)
    if result.returncode and not optional:
        raise EvidenceError(f"unavailable evidence ({' '.join(args[:2])}): {result.stderr.strip()}")
    return result


def read_json(*args):
    try:
        return json.loads(run(*args).stdout)
    except (ValueError, TypeError) as exc:
        raise EvidenceError(f"unavailable JSON evidence: {args[0]}") from exc


def section(text, layer):
    headings = list(re.finditer(r"^##\s+:([^\s]+).*?$", text, re.M))
    for i, match in enumerate(headings):
        if match[1] == layer:
            return text[match.end():headings[i + 1].start() if i + 1 < len(headings) else len(text)]
    return None


PR_FIELDS = "number,state,isDraft,headRefName,headRefOid,baseRefName,url"


def inspect(args):
    root = Path(run("git", "rev-parse", "--show-toplevel").stdout.strip())
    common = Path(run("git", "rev-parse", "--path-format=absolute", "--git-common-dir").stdout.strip())
    repo = read_json("gh", "repo", "view", "--json", "nameWithOwner,defaultBranchRef")
    default = repo["defaultBranchRef"]["name"]
    base = "origin/" + default
    trees = read_json("wt", "list", "--format=json")
    trees = trees["items"] if isinstance(trees, dict) else trees
    branches = run("git", "for-each-ref", "--format=%(refname:short)", "refs/heads/").stdout.splitlines()
    target = args.change
    explicit_pr = target.isdigit() or bool(re.fullmatch(r"https://github\.com/[^/]+/[^/]+/pull/\d+", target))
    target_pr = read_json("gh", "pr", "view", target, "--json", PR_FIELDS) if explicit_pr else None
    if target_pr:
        target = target_pr["headRefName"]
    if "/" in target:
        if not re.fullmatch(r"[a-z0-9-]+/[a-z0-9-]+", target):
            raise EvidenceError("unsupported branch name")
        stem_branch = target
        change = target.replace("/", "-", 1)
    else:
        if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)+", target):
            raise EvidenceError("invalid change name")
        change = target
        stem_branch = target.replace("-", "/", 1)

    # A layer branch may name a folder whose first layer uses the unsuffixed branch.
    names = set()
    directories = {root} | {Path(t["worktree"]["path"]) for t in trees}
    for directory in directories:
        path = directory / "openspec/changes"
        if path.is_dir():
            names.update(p.name for p in path.iterdir() if p.is_dir() and p.name != "archive")
            if (path / "archive").is_dir():
                names.update(p.name for p in (path / "archive").iterdir() if p.is_dir())
    # Discover archived folders on the existing default ref; never fetch.
    remote_paths = run("git", "ls-tree", "-r", "--name-only", base, "--", "openspec/changes").stdout.splitlines()
    for path in remote_paths:
        match = re.match(r"openspec/changes/(?:archive/)?([^/]+)/", path)
        if match:
            names.add(match[1])
    matching = [name for name in names if target == name or target == name.replace("-", "/", 1)
                or target.startswith(name.replace("-", "/", 1) + "-")]
    # A legacy folder may retain its type prefix after the branch type changed.
    if len(matching) == 1:
        change = matching[0]
    elif len(matching) > 1:
        change = max(matching, key=len)
    elif "/" in target:
        legacy = [name for name in names if name.partition("-")[2] == target.partition("/")[2]]
        if len(legacy) > 1:
            raise EvidenceError("ambiguous change folder")
        if legacy:
            change = legacy[0]
    canonical = change.replace("-", "/", 1)
    relevant = sorted({b for b in branches if b == canonical or b.startswith(canonical + "-") or b == stem_branch})
    relevant_trees = [t for t in trees if t.get("branch") in relevant or t.get("branch") == stem_branch]

    journal = common / "team/changes" / change / "sync-progress"
    if journal.is_file() and not re.search(r"^handed-off\s+\S+", journal.read_text(), re.M):
        raise EvidenceError("sync interrupted: unfinished journal")
    for tree in relevant_trees:
        if run("git", "-C", tree["worktree"]["path"], "rev-parse", "-q", "--verify", "MERGE_HEAD", optional=True).returncode == 0:
            raise EvidenceError("sync interrupted: merge in progress")

    # Query per branch so pagination cannot silently hide a matching PR.
    prs = []
    for branch in relevant or [stem_branch]:
        found = read_json("gh", "pr", "list", "--head", branch, "--state", "all", "--limit", "100", "--json", PR_FIELDS)
        if len(found) >= 100:
            raise EvidenceError("unavailable complete PR evidence: result limit reached")
        prs.extend(found)
    if target_pr and all(p["number"] != target_pr["number"] for p in prs):
        prs.append(target_pr)
    for branch in {p["headRefName"] for p in prs}:
        if sum(p["state"] == "OPEN" and p["headRefName"] == branch for p in prs) > 1:
            raise EvidenceError("ambiguous open PR evidence")

    # Read from worktrees, then branch snapshots, then the default branch archive.
    sources = [(Path(t["worktree"]["path"]), None) for t in relevant_trees]
    sources.append((root, None))
    sources.extend((None, branch) for branch in relevant)
    sources.append((None, base))
    folder = None
    contents = {}
    for directory, ref in sources:
        for prefix in ("openspec/changes/", "openspec/changes/archive/"):
            candidate = prefix + change

            def read(name):
                if directory is not None:
                    path = directory / candidate / name
                    return path.read_text() if path.is_file() else None
                result = run("git", "show", f"{ref}:{candidate}/{name}", optional=True)
                return result.stdout if result.returncode == 0 else None

            loaded = {name: read(name) for name in ("scope-brief.md", "proposal.md", "tasks.md", "issues.md", "sprint-contract.md", "handoff.md")}
            if loaded["scope-brief.md"] is not None or (loaded["proposal.md"] is not None and loaded["tasks.md"] is not None):
                folder, contents = candidate, loaded
                break
        if folder:
            break

    playbook = "unresolved"
    if folder:
        brief = contents["scope-brief.md"] or ""
        values = re.findall(r"^\s*(?:-\s*)?(?:\*\*)?Playbook:(?:\*\*)?\s*([^\s]+)\s*$", brief, re.M)
        if values and (len(set(values)) != 1 or values[0] not in ("bug-fix", "change")):
            raise EvidenceError("unsupported or conflicting recorded playbook")
        playbook = values[0] if values else ("bug-fix" if stem_branch.startswith("fix/") else "change")

    def done(step):
        print("Playbook: " + playbook)
        print("Step: " + step)

    if args.reevaluate_head:
        head = run("git", "rev-parse", "refs/heads/" + stem_branch, optional=True)
        if head.returncode or head.stdout.strip() != args.reevaluate_head:
            raise EvidenceError("head mismatch")
        return done("Phase 3: Evaluation (fresh evaluator)")
    if args.sync_pr:
        pr = read_json("gh", "pr", "view", args.sync_pr, "--json", PR_FIELDS)
        branch = pr["headRefName"]
        head = run("git", "rev-parse", "refs/heads/" + branch, optional=True)
        if (pr["state"] != "OPEN" or pr["baseRefName"] != default or pr["headRefOid"] != args.expected_head
                or head.returncode or head.stdout.strip() != args.expected_head or branch not in relevant):
            raise EvidenceError("sync interrupted: PR or local head changed")
        for tree in relevant_trees:
            if tree["branch"] == branch and run("git", "-C", tree["worktree"]["path"], "status", "--porcelain").stdout.strip():
                raise EvidenceError("sync needs a clean worktree")
        return done("Requested sync")
    if contents.get("handoff.md"):
        return done("Handoff: " + contents["handoff.md"].strip().replace("\n", " "))
    if not folder:
        return done("Reconstruct change folder" if relevant or prs or relevant_trees else "Phase 0: Scope Brief and OpenSpec setup")
    if contents["scope-brief.md"] is None:
        return done("Reconstruct Scope Brief")
    if contents["issues.md"] is None:
        return done("Phase 1: Issue creation")
    if any(p["state"] == "MERGED" and p["headRefName"] in {t["branch"] for t in relevant_trees} for p in prs):
        return done("Phase 6: Close-out")

    mappings = {}
    for line in contents["issues.md"].splitlines():
        match = re.match(r"^\s*:([a-z0-9-]+):\s*#(\d+)\s*$", line)
        if match:
            mappings[match[1]] = match[2]
        elif re.match(r"^\s*:?[a-z0-9-]+:\s*", line) and not re.match(r"^\s*(?:parent|epic):", line):
            raise EvidenceError("unavailable tracker evidence: only GitHub #number mappings are supported")
    layers = re.findall(r"^##\s+:([a-z0-9-]+)\s*$", contents["tasks.md"] or "", re.M)
    if not layers or any(layer not in mappings for layer in layers):
        raise EvidenceError("unavailable layer issue mapping")
    states = {}
    for issue in set(mappings.values()):
        state = read_json("gh", "issue", "view", issue, "--json", "state")["state"]
        if state not in ("OPEN", "CLOSED"):
            raise EvidenceError("unavailable tracker state")
        states[issue] = state
    if all(states[mappings[layer]] == "CLOSED" for layer in layers):
        return done("Phase 6: Cleanup")
    selected = next(layer for layer in layers if states[mappings[layer]] == "OPEN")
    unit = [layer for layer in layers if mappings[layer] == mappings[selected]]
    first = min(layers.index(layer) for layer in unit)
    branch = canonical if first == 0 else canonical + "-" + layers[first]
    if first == 0 and stem_branch in relevant and canonical not in relevant:
        branch = stem_branch
    if branch not in branches or not run("git", "diff", "--stat", base + "..." + branch, "--", ".", ":!openspec/changes").stdout.strip():
        return done("Phase 2: Implementation")
    pr = next((p for p in prs if p["headRefName"] == branch and p["state"] == "OPEN"), None)
    # Shared issues have one branch and one evaluation pass, recorded under the
    # first layer of the unit, just as branch selection uses that first layer.
    sections = [section(contents["sprint-contract.md"] or "", layers[first])]
    if any(s is None for s in sections):
        return done("Phase 3: Evaluation (start)")
    checked = all(re.search(r"^- \[[xX]\]", s, re.M) and not re.search(r"^- \[ \]", s, re.M) for s in sections)
    if not checked:
        return done("Phase 3: Evaluation (fix pass)" if not pr or pr["isDraft"] else "Phase 5: Re-evaluation")
    evaluated = []
    for s in sections:
        match = re.search(r"^Evaluated at:\s*([0-9a-f]{40})\s*$", s, re.M)
        if not match:
            return done("Phase 3: Evaluation (fresh evaluator)")
        ancestry = run("git", "merge-base", "--is-ancestor", match[1], branch, optional=True)
        if ancestry.returncode == 1:
            return done("Phase 3: Evaluation (fresh evaluator)")
        if ancestry.returncode:
            raise EvidenceError("unavailable evaluation ancestry")
        evaluated.append(match[1])
    if any(not re.search(r"^Cross-review:\s*\S", s, re.M) for s in sections):
        return done("Phase 4: Cross-model review")
    classify = "Phase 4 steps 4–5, then Phase 5"
    if not pr or "/archive/" not in folder:
        return done(classify)
    ledger = Path(args.ledger).read_text() if args.ledger else ""
    for sha in evaluated:
        later = run("git", "rev-list", sha + ".." + branch, "--not", base).stdout.splitlines()
        for commit in later:
            # Accept the continuity reference's inline record and section records.
            records = re.findall(r"^.*?" + re.escape(commit) + r"[^\n]*\bbehavioral:\s*(yes|no)\b", ledger, re.M)
            block = re.search(r"^##\s+" + re.escape(commit) + r"\s*\n(.*?)(?=^## |\Z)", ledger, re.M | re.S)
            if block:
                records.extend(re.findall(r"^behavioral:\s*(yes|no)\b", block[1], re.M))
            if not records or any(record != "no" for record in records):
                return done(classify)
    return done("Phase 5: Completion")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("change", help="change name, branch, PR number or GitHub PR URL")
    parser.add_argument("--reevaluate-head")
    parser.add_argument("--sync-pr")
    parser.add_argument("--expected-head")
    parser.add_argument("--default-sha")
    parser.add_argument("--ledger", help="existing durable review ledger (read only)")
    args = parser.parse_args()
    if any((args.sync_pr, args.expected_head, args.default_sha)) and not all((args.sync_pr, args.expected_head, args.default_sha)):
        parser.error("sync requires --sync-pr, --expected-head and --default-sha")
    for sha in (args.reevaluate_head, args.expected_head, args.default_sha):
        if sha and not re.fullmatch(r"[0-9a-f]{40}", sha):
            parser.error("heads must be full lowercase commit SHAs")
    try:
        inspect(args)
    except (EvidenceError, OSError, KeyError, TypeError) as exc:
        print("dev-state: " + str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
