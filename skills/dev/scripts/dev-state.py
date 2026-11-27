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


PR_FIELDS = "number,state,isDraft,headRefName,headRefOid,baseRefName,url,isCrossRepository,headRepository,headRepositoryOwner"


def inspect(args):
    root = Path(run("git", "rev-parse", "--show-toplevel").stdout.strip())

    def git(*args, optional=False):
        return run("git", *args, optional=optional, cwd=root)

    common = Path(git("rev-parse", "--path-format=absolute", "--git-common-dir").stdout.strip())
    repo = read_json("gh", "repo", "view", "--json", "nameWithOwner,defaultBranchRef")
    default = repo["defaultBranchRef"]["name"]
    base = "origin/" + default
    trees = read_json("wt", "list", "--format=json")
    trees = trees["items"] if isinstance(trees, dict) else trees
    branches = git("for-each-ref", "--format=%(refname:short)", "refs/heads/").stdout.splitlines()
    target = args.change
    explicit_pr = target.isdigit() or bool(re.fullmatch(r"https://github\.com/[^/]+/[^/]+/pull/\d+", target))

    def check_pr_repository(pr):
        match = re.fullmatch(r"https://github\.com/([^/]+/[^/]+)/pull/\d+", pr["url"])
        head_repo = pr.get("headRepository") or {}
        owner = pr.get("headRepositoryOwner") or {}
        identity = head_repo.get("nameWithOwner")
        if not identity and owner.get("login") and head_repo.get("name"):
            identity = owner["login"] + "/" + head_repo["name"]
        if (not match or match[1].lower() != repo["nameWithOwner"].lower()
                or pr.get("isCrossRepository")
                or (identity and identity.lower() != repo["nameWithOwner"].lower())):
            raise EvidenceError("PR repository does not match the inspected repository")

    if target.startswith("https://") and explicit_pr:
        if target.split("/pull/")[0].removeprefix("https://github.com/").lower() != repo["nameWithOwner"].lower():
            raise EvidenceError("PR URL repository does not match the inspected repository")
    target_pr = read_json("gh", "pr", "view", target, "--json", PR_FIELDS) if explicit_pr else None
    if target_pr:
        check_pr_repository(target_pr)
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

    # A folder is associated with a branch by an exact name, a declared layer,
    # or verified legacy artifacts on that branch itself. Prefixes alone are
    # insufficient: feat/example-extra may be an entirely separate change.
    files = ("scope-brief.md", "proposal.md", "tasks.md", "issues.md", "sprint-contract.md", "handoff.md")

    def load_folder(name, sources):
        for directory, ref in sources:
            for prefix in ("openspec/changes/", "openspec/changes/archive/"):
                candidate = prefix + name
                loaded = {}
                for filename in files:
                    if directory is not None:
                        path = directory / candidate / filename
                        loaded[filename] = path.read_text() if path.is_file() else None
                    else:
                        result = git("show", f"{ref}:{candidate}/{filename}", optional=True)
                        loaded[filename] = result.stdout if result.returncode == 0 else None
                if loaded["scope-brief.md"] is not None or (loaded["proposal.md"] is not None and loaded["tasks.md"] is not None):
                    return candidate, loaded
        return None, {}

    def branch_sources(branch):
        return ([(Path(t["worktree"]["path"]), None) for t in trees if t.get("branch") == branch]
                + [(None, branch)])

    names = set()
    directories = {root} | {Path(t["worktree"]["path"]) for t in trees}
    for directory in directories:
        path = directory / "openspec/changes"
        if path.is_dir():
            names.update(p.name for p in path.iterdir() if p.is_dir() and p.name != "archive")
            if (path / "archive").is_dir():
                names.update(p.name for p in (path / "archive").iterdir() if p.is_dir())
    # Discover archived folders on the existing default ref; never fetch.
    remote_paths = git("ls-tree", "-r", "--name-only", base, "--", "openspec/changes").stdout.splitlines()
    for path in remote_paths:
        match = re.match(r"openspec/changes/(?:archive/)?([^/]+)/", path)
        if match:
            names.add(match[1])
    # Include branch snapshots when the worktree and default archive are absent.
    if "/" in target:
        for path in git("ls-tree", "-r", "--name-only", stem_branch, "--", "openspec/changes", optional=True).stdout.splitlines():
            match = re.match(r"openspec/changes/(?:archive/)?([^/]+)/", path)
            if match:
                names.add(match[1])
    if "/" in target and not load_folder(change, branch_sources(stem_branch))[0]:
        matching = []
        for name in names:
            canonical_name = name.replace("-", "/", 1)
            verified, artifacts = load_folder(name, branch_sources(stem_branch))
            if not verified:
                continue
            declared = re.findall(r"^##\s+:([a-z0-9-]+)\s*$", artifacts["tasks.md"] or "", re.M)
            if (target in {canonical_name + "-" + layer for layer in declared}
                    or name.partition("-")[2] == target.partition("/")[2]):
                matching.append(name)
        if len(matching) > 1:
            raise EvidenceError("ambiguous change folder")
        if matching:
            change = matching[0]
    canonical = change.replace("-", "/", 1)
    # Folder input can resolve a legacy fix branch only when that branch really
    # contains this verified folder, rather than borrowing it from the caller.
    if "/" not in target and canonical not in branches:
        legacy = [b for b in branches if b.partition("/")[2] == change.partition("-")[2]
                  and load_folder(change, branch_sources(b))[0]]
        if len(legacy) > 1:
            raise EvidenceError("ambiguous change branch")
        if legacy:
            stem_branch = legacy[0]
    initial_sources = branch_sources(stem_branch)
    for branch in branches:
        if branch == stem_branch or not branch.startswith(canonical + "-"):
            continue
        verified, artifacts = load_folder(change, branch_sources(branch))
        declared = re.findall(r"^##\s+:([a-z0-9-]+)\s*$", artifacts.get("tasks.md") or "", re.M)
        if verified and branch in {canonical + "-" + layer for layer in declared}:
            initial_sources.extend(branch_sources(branch))
    initial_sources += [(root, None), (None, base)]
    folder, contents = load_folder(change, initial_sources)
    declared = re.findall(r"^##\s+:([a-z0-9-]+)\s*$", contents.get("tasks.md") or "", re.M)
    allowed = {canonical, stem_branch} | {canonical + "-" + layer for layer in declared}
    relevant = sorted(b for b in branches if b in allowed)
    relevant_trees = [t for t in trees if t.get("branch") in allowed]

    journal = common / "team/changes" / change / "sync-progress"
    if journal.is_file() and not re.search(r"^handed-off\s+\S+", journal.read_text(), re.M):
        raise EvidenceError("sync interrupted: unfinished journal")
    for tree in relevant_trees:
        if git("-C", tree["worktree"]["path"], "rev-parse", "-q", "--verify", "MERGE_HEAD", optional=True).returncode == 0:
            raise EvidenceError("sync interrupted: merge in progress")

    # Query per branch so pagination cannot silently hide a matching PR.
    prs = []
    for branch in relevant or [stem_branch]:
        found = read_json("gh", "pr", "list", "--head", branch, "--state", "all", "--limit", "100", "--json", PR_FIELDS)
        if len(found) >= 100:
            raise EvidenceError("unavailable complete PR evidence: result limit reached")
        for pr in found:
            check_pr_repository(pr)
        prs.extend(found)
    if target_pr and all(p["number"] != target_pr["number"] for p in prs):
        prs.append(target_pr)
    for branch in {p["headRefName"] for p in prs}:
        if sum(p["state"] == "OPEN" and p["headRefName"] == branch for p in prs) > 1:
            raise EvidenceError("ambiguous open PR evidence")

    # Prefer the requested branch, then the other verified layer branches;
    # invoking-checkout artifacts are only a fallback after branch snapshots.
    ordered = [stem_branch] + [b for b in relevant if b != stem_branch]
    sources = [source for branch in ordered for source in branch_sources(branch)]
    folder, contents = load_folder(change, sources + [(root, None), (None, base)])

    playbook = "unresolved"
    if folder:
        brief = contents["scope-brief.md"] or ""
        # Capture every present field before validating its whole value. Requiring
        # a valid-looking value here would silently turn malformed records into
        # legacy briefs and select a different playbook from the branch prefix.
        values = []
        for line in brief.splitlines():
            field = re.match(r"^[ \t]*(?:[-*+]\s+)?(?:\*\*)?Playbook(?:\*\*)?:(?:\*\*)?[ \t]*(.*)$", line)
            if field:
                values.append(field[1].strip())
        if values and (len(set(values)) != 1 or values[0] not in ("bug-fix", "change")):
            raise EvidenceError("unsupported or conflicting recorded playbook")
        playbook = values[0] if values else ("bug-fix" if stem_branch.startswith("fix/") else "change")

    def done(step):
        print("Playbook: " + playbook)
        print("Step: " + step)

    def layer_evidence():
        mappings = {}
        for line in contents["issues.md"].splitlines():
            # GitHub's producer writes layer: number; older fixtures and artifacts
            # also use :layer: #number. Both identify the same GitHub issue.
            match = re.match(r"^\s*:?([a-z0-9-]+):\s*#?(\d+)\s*$", line)
            if match:
                if match[1] in ("parent", "epic"):
                    continue
                if match[1] in mappings and mappings[match[1]] != match[2]:
                    raise EvidenceError("conflicting layer issue mapping")
                mappings[match[1]] = match[2]
            elif re.match(r"^\s*:?[a-z0-9-]+:\s*", line) and not re.match(r"^\s*(?:parent|epic):", line):
                raise EvidenceError("unavailable tracker evidence: only GitHub numeric issue mappings are supported")
        layers = re.findall(r"^##\s+:([a-z0-9-]+)\s*$", contents["tasks.md"] or "", re.M)
        if not layers or any(layer not in mappings for layer in layers):
            raise EvidenceError("unavailable layer issue mapping")
        states = {}
        for issue in set(mappings.values()):
            state = read_json("gh", "issue", "view", issue, "--json", "state")["state"]
            if state not in ("OPEN", "CLOSED"):
                raise EvidenceError("unavailable tracker state")
            states[issue] = state
        return mappings, layers, states

    if args.reevaluate_head:
        branch = stem_branch
        if "/" not in target and contents.get("issues.md") is not None:
            mappings, layers, states = layer_evidence()
            selected = next((layer for layer in layers if states[mappings[layer]] == "OPEN"), None)
            if selected is not None:
                first = next(i for i, layer in enumerate(layers) if mappings[layer] == mappings[selected])
                if first:
                    branch = canonical + "-" + layers[first]
        head = git("rev-parse", "refs/heads/" + branch, optional=True)
        if head.returncode or head.stdout.strip() != args.reevaluate_head:
            raise EvidenceError("head mismatch")
        return done("Phase 3: Evaluation (fresh evaluator)")
    if args.sync_pr:
        pr = read_json("gh", "pr", "view", args.sync_pr, "--json", PR_FIELDS)
        check_pr_repository(pr)
        branch = pr["headRefName"]
        head = git("rev-parse", "refs/heads/" + branch, optional=True)
        if (pr["state"] != "OPEN" or pr["baseRefName"] != default or pr["headRefOid"] != args.expected_head
                or head.returncode or head.stdout.strip() != args.expected_head or branch not in relevant):
            raise EvidenceError("sync interrupted: PR or local head changed")
        for tree in relevant_trees:
            if tree["branch"] == branch and git("-C", tree["worktree"]["path"], "status", "--porcelain").stdout.strip():
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

    mappings, layers, states = layer_evidence()
    if all(states[mappings[layer]] == "CLOSED" for layer in layers):
        return done("Phase 6: Cleanup")
    selected = next(layer for layer in layers if states[mappings[layer]] == "OPEN")
    unit = [layer for layer in layers if mappings[layer] == mappings[selected]]
    first = min(layers.index(layer) for layer in unit)
    branch = canonical if first == 0 else canonical + "-" + layers[first]
    if first == 0 and stem_branch in relevant and canonical not in relevant:
        branch = stem_branch
    if branch not in branches or not git("diff", "--stat", base + "..." + branch, "--", ".", ":!openspec/changes").stdout.strip():
        return done("Phase 2: Implementation")
    pr = next((p for p in prs if p["headRefName"] == branch and p["state"] == "OPEN"), None)
    # One shared issue is evaluated as a unit across every layer section.
    sections = [section(contents["sprint-contract.md"] or "", layer) for layer in unit]
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
        ancestry = git("merge-base", "--is-ancestor", match[1], branch, optional=True)
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
        later = git("rev-list", sha + ".." + branch, "--not", base).stdout.splitlines()
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
