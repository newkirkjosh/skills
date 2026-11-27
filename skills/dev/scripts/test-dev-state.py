#!/usr/bin/env python3
"""Public CLI fixtures. The same file acts as deny-write git/gh/wt fakes."""
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

HEAD = "a" * 40
BASE = "b" * 40
PASS = "c" * 40
LATER = "d" * 40
CHANGE = "feat-example"
BRANCH = "feat/example"


def fake():
    state = json.loads(Path(os.environ["DEV_STATE_FIXTURE"]).read_text())
    name, args = Path(sys.argv[0]).name, sys.argv[1:]
    with open(os.environ["DEV_STATE_CALLS"], "a") as log:
        log.write(json.dumps([name] + args) + "\n")

    def emit(value):
        if isinstance(value, (dict, list)):
            print(json.dumps(value))
        elif value:
            print(value)
        return 0

    def reject():
        with open(os.environ["DEV_STATE_VIOLATIONS"], "a") as log:
            log.write(json.dumps([name] + args) + "\n")
        print("fixture rejects unsupported or mutating command", file=sys.stderr)
        return 97

    if name == "wt":
        if args == ["list", "--format=json"]:
            return emit({"items": state["worktrees"]})
        return reject()
    if name == "gh":
        if args[:2] == ["repo", "view"]:
            value = {"nameWithOwner": "owner/repo", "defaultBranchRef": {"name": "main"},
                     "url": "https://github.com/owner/repo"}
        elif args[:2] == ["pr", "list"]:
            if state.get("gh_unavailable"):
                print("offline API unavailable", file=sys.stderr)
                return 1
            value = state["prs"]
            if "--head" in args:
                branch = args[args.index("--head") + 1]
                value = [p for p in value if p["headRefName"] == branch]
            if "--state" in args and args[args.index("--state") + 1] != "all":
                wanted = args[args.index("--state") + 1].upper()
                value = [p for p in value if p["state"] == wanted]
        elif args[:2] == ["pr", "view"]:
            if state.get("gh_unavailable"):
                return 1
            ident = args[2] if len(args) > 2 and not args[2].startswith("-") else state["branch"]
            matches = [p for p in state["prs"] if ident in
                       (str(p["number"]), p["url"], p["headRefName"])]
            if not matches:
                print("no pull requests found", file=sys.stderr)
                return 1
            value = matches[0]
        elif args[:2] == ["issue", "view"]:
            if state.get("issue_unavailable"):
                return 1
            number = args[2]
            if number not in state["issues"]:
                return 1
            value = {"number": int(number), "state": state["issues"][number]}
        else:
            return reject()
        if "--jq" in args or "-q" in args:
            flag = "--jq" if "--jq" in args else "-q"
            query = args[args.index(flag) + 1]
            # Common scalar reads; complex jq belongs to the real jq executable.
            if query == ".defaultBranchRef.name":
                return emit("main")
            if query in (".state", ".headRefName", ".headRefOid", ".baseRefName", ".number"):
                return emit(value[query[1:]])
            return reject()
        return emit(value)
    if name != "git":
        return reject()
    while args and args[0] in ("-C", "-c"):
        args = args[2:]
    if not args:
        return reject()
    command, rest = args[0], args[1:]
    if command == "rev-parse":
        if "--show-toplevel" in rest:
            return emit(state["root"])
        if "--git-common-dir" in rest or "--git-dir" in rest:
            return emit(state["common"])
        if "--is-inside-work-tree" in rest:
            return emit("true")
        if "MERGE_HEAD" in rest:
            return emit(HEAD) if state.get("merging") else 1
        if "--abbrev-ref" in rest and "HEAD" in rest:
            return emit(state["branch"])
        ref = rest[-1] if rest else "HEAD"
        if ref == "HEAD":
            return emit(state.get("local_head", HEAD))
        if ref in (state["branch"], "refs/heads/" + state["branch"]):
            return emit(state.get("local_head", HEAD)) if state["branch"] in state["branches"] else 1
        if ref.removeprefix("refs/heads/") in state["branches"]:
            return emit(HEAD)
        if ref in ("origin/main", "refs/remotes/origin/main", "main"):
            return emit(BASE)
        if ref == state.get("evaluated", PASS):
            return emit(ref)
        return 1
    if command == "symbolic-ref":
        return emit("origin/main" if any("origin/HEAD" in x for x in rest) else state["branch"])
    if command == "status" and any(x.startswith("--porcelain") for x in rest):
        return emit(" M example.txt" if state.get("dirty") else "")
    if command == "branch" and ("--list" in rest or "--format" in " ".join(rest)):
        return emit("\n".join(state["branches"]))
    if command == "for-each-ref":
        return emit("\n".join(state["branches"]))
    if command == "show-ref":
        return 0 if rest[-1].removeprefix("refs/heads/") in state["branches"] else 1
    if command == "diff" and "--stat" in rest:
        return emit(" example.txt | 1 +" if state.get("implementation", True) else "")
    if command == "diff" and "--quiet" in rest:
        return 1 if state.get("implementation", True) else 0
    if command == "merge-base":
        if "--is-ancestor" in rest:
            return 0 if state.get("ancestor", True) else 1
        return emit(BASE)
    if command == "rev-list":
        return emit("\n".join(state.get("later", [])))
    if command == "log":
        return emit("\n".join(state.get("later", [])))
    if command in ("show", "cat-file", "ls-tree"):
        if command == "ls-tree":
            if "--name-only" not in rest:
                return reject()
            return emit("\n".join(state.get("remote_files", {})))
        refpath = next((x for x in rest if ":" in x and not x.startswith("--")), "")
        path = refpath.split(":", 1)[1] if refpath else ""
        if path in state.get("remote_files", {}):
            if command == "cat-file" and "-e" in rest:
                return 0
            return emit(state["remote_files"][path])
        return 1
    if command == "config" and ("--get" in rest or rest == ["remote.origin.url"]):
        if any("url" in x for x in rest):
            return emit("https://github.com/owner/repo.git")
        return 1
    return reject()


def snapshot(root):
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in root.rglob("*") if p.is_file()}


def run_tests(script):
    total = failed = 0
    folder = "openspec/changes/" + CHANGE
    brief = "# Scope Brief\n\n- **Playbook:** change\n"
    files = {
        folder + "/scope-brief.md": brief,
        folder + "/proposal.md": "# Proposal\n",
        folder + "/tasks.md": "# Tasks\n\n## :catalog\n- [ ] Implement example\n",
        folder + "/issues.md": "parent: #10\n:catalog: #11\n",
        folder + "/sprint-contract.md": "# Sprint contract\n\n## :catalog\n- [x] Example passes\n"
        + "Evaluated at: " + PASS + "\nCross-review: reviewer, 1 pass, converged at " + PASS[:8] + "\n",
    }
    defaults = {
        "branch": BRANCH, "branches": [BRANCH], "prs": [],
        "issues": {"10": "OPEN", "11": "OPEN"}, "files": files,
        "worktree": True, "implementation": True, "ancestor": True,
    }

    def case(name, step=None, playbook="change", mutate=None, args=None, error=None):
        nonlocal total, failed
        total += 1
        state = copy.deepcopy(defaults)
        if mutate:
            mutate(state)
        with tempfile.TemporaryDirectory(prefix="dev-state-test-") as temp:
            temp = Path(temp)
            root, common, bin_dir = temp / "repo", temp / "common", temp / "bin"
            root.mkdir()
            common.mkdir()
            bin_dir.mkdir()
            for file, body in state.pop("files").items():
                target = root / file
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(body)
            if state.pop("journal", None):
                journal = common / "team/changes" / CHANGE / "sync-progress"
                journal.parent.mkdir(parents=True)
                journal.write_text(state.pop("journal_text", "expected " + HEAD + "\n"))
            state.update(root=str(root), common=str(common))
            state["worktrees"] = [{"branch": state["branch"],
                                   "worktree": {"path": str(root), "changes": state.get("dirty", False)},
                                   "default_branch": {"ahead": 1, "behind": 0},
                                   "head": {"sha": HEAD, "committed_at": "2026-01-01T00:00:00Z"}}]
            if not state.pop("worktree"):
                state["worktrees"] = []
            fixture, calls, violations = temp / "fixture.json", temp / "calls", temp / "violations"
            fixture.write_text(json.dumps(state))
            for tool in ("git", "gh", "wt"):
                launcher = bin_dir / tool
                launcher.write_text("#!/usr/bin/env bash\nexec python3 -I "
                                    + "'" + str(Path(__file__).resolve()) + "' --fake " + tool + ' "$@"\n')
                launcher.chmod(0o755)
            env = dict(os.environ, PATH=str(bin_dir) + os.pathsep + os.environ["PATH"],
                       DEV_STATE_FIXTURE=str(fixture), DEV_STATE_CALLS=str(calls),
                       DEV_STATE_VIOLATIONS=str(violations))
            before = (snapshot(root), snapshot(common))
            result = subprocess.run(["bash", str(script)] + (args or [CHANGE]), cwd=root,
                                    env=env, text=True, capture_output=True, timeout=20)
            problems = []
            if violations.exists():
                problems.append("write/unsupported call: " + violations.read_text().strip())
            if before != (snapshot(root), snapshot(common)):
                problems.append("repository or common git state changed")
            if error:
                if result.returncode == 0 or error.lower() not in (result.stdout + result.stderr).lower():
                    problems.append("expected nonzero with diagnostic " + repr(error))
                if re.search(r"^Step: Phase [0-6]", result.stdout, re.M):
                    problems.append("fabricated lifecycle phase on error")
            else:
                if result.returncode != 0:
                    problems.append("exit " + str(result.returncode))
                if "Playbook: " + playbook not in result.stdout.splitlines():
                    problems.append("missing Playbook: " + playbook)
                if "Step: " + step not in result.stdout.splitlines():
                    problems.append("missing Step: " + step)
            if problems:
                failed += 1
                print("FAIL " + name + ": " + "; ".join(problems))
                print("  " + (result.stdout + result.stderr).strip().replace("\n", " | ")[:450])
            else:
                print("ok   " + name)

    def update(**values):
        return lambda s: s.update(values)

    def remove(*names):
        return lambda s: [s["files"].pop(folder + "/" + name, None) for name in names]

    def change_file(name, text):
        return lambda s: s["files"].__setitem__(folder + "/" + name, text)

    def combine(*actions):
        return lambda s: [action(s) for action in actions]

    def pr(state="OPEN", draft=False, branch=BRANCH, number=23):
        return {"number": number, "state": state, "isDraft": draft, "headRefName": branch,
                "headRefOid": HEAD, "baseRefName": "main", "mergeCommit": {"oid": BASE} if state == "MERGED" else None,
                "url": "https://github.com/owner/repo/pull/" + str(number)}

    def contract(s, checked=True, evaluated=PASS, reviewed=True, layer="catalog"):
        s["files"][folder + "/sprint-contract.md"] = (
            "# Sprint contract\n\n## :" + layer + "\n- [" + ("x" if checked else " ") + "] Example\n"
            + ("Evaluated at: " + evaluated + "\n" if evaluated else "")
            + ("Cross-review: reviewer, 1 pass, converged at cccccccc\n" if reviewed else ""))

    def archive(s):
        s["files"] = {p.replace("openspec/changes/", "openspec/changes/archive/", 1): v
                      for p, v in s["files"].items()}

    # Every lifecycle table row, in precedence order.
    case("row 1: nowhere is new work", "Phase 0: Scope Brief and OpenSpec setup", "unresolved",
         update(files={}, branches=[], worktree=False))
    case("row 2: branch without verified folder reconstructs", "Reconstruct change folder", "unresolved",
         update(files={}, worktree=False))
    case("row 2: unrelated directory is preserved", "Reconstruct change folder", "unresolved",
         update(files={folder + "/notes.md": "Keep me\n"}))
    case("row 3: verified legacy folder missing brief", "Reconstruct Scope Brief",
         mutate=remove("scope-brief.md"))
    case("row 4: missing issue map", "Phase 1: Issue creation", mutate=remove("issues.md"))
    case("row 5: merged PR preempts open issue", "Phase 6: Close-out", mutate=update(prs=[pr("MERGED")]))
    case("row 6: all child issues closed; open parent ignored", "Phase 6: Cleanup",
         mutate=update(issues={"10": "OPEN", "11": "CLOSED"}))
    case("row 7: missing layer branch", "Phase 2: Implementation", mutate=update(branches=[], worktree=False))
    case("row 7: only change-folder commits", "Phase 2: Implementation", mutate=update(implementation=False))
    case("row 8: absent contract", "Phase 3: Evaluation (start)", mutate=remove("sprint-contract.md"))
    case("row 8: another layer's contract is not this layer", "Phase 3: Evaluation (start)",
         mutate=lambda s: contract(s, layer="other"))
    case("row 9: unchecked with no PR", "Phase 3: Evaluation (fix pass)",
         mutate=lambda s: contract(s, checked=False))
    case("row 9: unchecked with draft PR", "Phase 3: Evaluation (fix pass)",
         mutate=combine(update(prs=[pr(draft=True)]), lambda s: contract(s, checked=False)))
    case("row 10: missing evaluated SHA", "Phase 3: Evaluation (fresh evaluator)",
         mutate=lambda s: contract(s, evaluated=None))
    case("row 10: evaluated SHA outside ancestry", "Phase 3: Evaluation (fresh evaluator)",
         mutate=update(ancestor=False))
    case("row 11: absent cross-review", "Phase 4: Cross-model review",
         mutate=lambda s: contract(s, reviewed=False))
    case("row 11: absent cross-review with ready PR", "Phase 4: Cross-model review",
         mutate=combine(update(prs=[pr()]), lambda s: contract(s, reviewed=False)))
    case("row 12: reviewed with no open PR", "Phase 4 steps 4–5, then Phase 5")
    case("row 13: unchecked with ready PR", "Phase 5: Re-evaluation",
         mutate=combine(update(prs=[pr()]), lambda s: contract(s, checked=False)))
    case("row 14: PR with unarchived folder", "Phase 4 steps 4–5, then Phase 5", mutate=update(prs=[pr()]))
    case("row 14: draft PR with unarchived folder", "Phase 4 steps 4–5, then Phase 5",
         mutate=update(prs=[pr(draft=True)]))
    case("row 14: archived but unclassified later commit", "Phase 4 steps 4–5, then Phase 5",
         mutate=combine(update(prs=[pr()], later=[LATER]), archive))
    ledger = "# Review ledger\n\n## " + LATER + "\nbehavioral: yes\n"
    case("row 14: behavioral yes later commit", "Phase 4 steps 4–5, then Phase 5",
         mutate=combine(update(prs=[pr()], later=[LATER]), change_file("review-ledger.md", ledger), archive))
    case("row 15: archived reviewed ready PR", "Phase 5: Completion",
         mutate=combine(update(prs=[pr()]), archive))
    case("row 15: archived reviewed draft PR", "Phase 5: Completion",
         mutate=combine(update(prs=[pr(draft=True)]), archive))
    case("row 15: every later commit behavioral no", "Phase 5: Completion",
         mutate=combine(update(prs=[pr()], later=[LATER]),
                        change_file("review-ledger.md", ledger.replace("yes", "no")), archive))

    def two_layers(s):
        s["files"][folder + "/tasks.md"] = "# Tasks\n\n## :catalog\n- [x] First\n\n## :docs\n- [ ] Second\n"
        s["files"][folder + "/issues.md"] = "parent: #10\n:catalog: #11\n:docs: #12\n"
        s["issues"] = {"10": "OPEN", "11": "CLOSED", "12": "OPEN"}
        s["branches"].append(BRANCH + "-docs")

    case("closed first layer does not select its checked contract", "Phase 3: Evaluation (start)",
         mutate=two_layers)
    case("merged earlier branch preempts later open layer", "Phase 6: Close-out",
         mutate=combine(two_layers, update(prs=[pr("MERGED")])) )
    case("unchecked later layer does not taint selected layer", "Phase 4 steps 4–5, then Phase 5",
         mutate=change_file("sprint-contract.md", files[folder + "/sprint-contract.md"]
                            + "\n## :other\n- [ ] Another layer is incomplete\n"))
    case("duplicate issue mappings share the first branch", "Phase 4 steps 4–5, then Phase 5",
         mutate=combine(two_layers, update(issues={"10": "OPEN", "11": "OPEN", "12": "OPEN"}),
                        change_file("issues.md", "parent: #10\n:catalog: #11\n:docs: #11\n")))

    # Playbook and discovery are independent of lifecycle routing.
    case("branch input", "Phase 4 steps 4–5, then Phase 5", args=[BRANCH])
    case("PR number input", "Phase 4 steps 4–5, then Phase 5", args=["23"], mutate=update(prs=[pr()]))
    case("PR URL input", "Phase 4 steps 4–5, then Phase 5",
         args=["https://github.com/owner/repo/pull/23"], mutate=update(prs=[pr()]))
    case("recorded bug-fix wins over feat prefix", "Phase 4 steps 4–5, then Phase 5", "bug-fix",
         change_file("scope-brief.md", "Playbook: bug-fix\n"))
    case("recorded change wins over fix prefix", "Phase 4 steps 4–5, then Phase 5",
         mutate=update(branch="fix/example", branches=["fix/example"]), args=["fix/example"])
    case("legacy verified fix branch falls back to bug-fix", "Phase 4 steps 4–5, then Phase 5", "bug-fix",
         combine(change_file("scope-brief.md", "# Legacy brief\n"),
                 update(branch="fix/example", branches=["fix/example"])), args=["fix/example"])
    case("legacy verified feature falls back to change", "Phase 4 steps 4–5, then Phase 5",
         mutate=change_file("scope-brief.md", "# Legacy brief\n"))
    case("unsupported recorded playbook stops", mutate=change_file("scope-brief.md", "Playbook: prototype\n"),
         error="playbook")
    case("conflicting recorded playbooks stop", error="playbook",
         mutate=change_file("scope-brief.md", "Playbook: change\nPlaybook: bug-fix\n"))
    case("missing worktree never recreated", "Phase 4 steps 4–5, then Phase 5", mutate=update(worktree=False))
    case("default-branch archive is discoverable", "Phase 5: Completion",
         mutate=combine(update(prs=[pr()], worktree=False),
                        lambda s: s.update(remote_files={p.replace("openspec/changes/", "openspec/changes/archive/", 1): v
                                                         for p, v in s["files"].items()}, files={})))

    # Routing preempts the table, and requested re-evaluation preempts requested sync.
    case("unfinished sync journal preempts every row", mutate=update(journal=True), error="sync interrupted")
    case("merge in progress preempts table", mutate=update(merging=True), error="sync interrupted")
    case("handed-off journal does not block", "Phase 4 steps 4–5, then Phase 5",
         mutate=update(journal=True, journal_text="expected " + HEAD + "\nhanded-off " + HEAD + "\n"))
    case("handoff preempts table", "Handoff: Resume requested check", mutate=change_file("handoff.md", "Resume requested check\n"))
    case("requested evaluation preempts handoff and table", "Phase 3: Evaluation (fresh evaluator)",
         args=[CHANGE, "--reevaluate-head", HEAD], mutate=change_file("handoff.md", "Resume requested check\n"))
    case("requested evaluation rejects wrong head", args=[CHANGE, "--reevaluate-head", BASE], error="head mismatch")
    sync = [CHANGE, "--sync-pr", "23", "--expected-head", HEAD, "--default-sha", BASE]
    case("requested sync preempts handoff and table", "Requested sync", args=sync,
         mutate=combine(update(prs=[pr()]), change_file("handoff.md", "Resume requested check\n")))
    case("requested evaluation preempts sync", "Phase 3: Evaluation (fresh evaluator)",
         args=sync + ["--reevaluate-head", HEAD], mutate=update(prs=[pr()], dirty=True))
    case("sync rejects changed local head", args=sync, error="sync interrupted",
         mutate=update(prs=[pr()], local_head=BASE))
    bad_pr = pr()
    bad_pr["headRefOid"] = BASE
    case("sync rejects changed PR head", args=sync, error="sync interrupted", mutate=update(prs=[bad_pr]))
    case("sync rejects merged PR", args=sync, error="sync interrupted", mutate=update(prs=[pr("MERGED")]))
    bad_pr = pr()
    bad_pr["baseRefName"] = "other"
    case("sync rejects retargeted PR", args=sync, error="sync interrupted", mutate=update(prs=[bad_pr]))
    case("sync rejects dirty worktree", args=sync, error="sync needs a clean worktree",
         mutate=update(prs=[pr()], dirty=True))
    case("sync inspects missing worktree without recreating", "Requested sync", args=sync,
         mutate=update(prs=[pr()], worktree=False))
    case("interrupted sync preempts requested evaluation", args=[CHANGE, "--reevaluate-head", HEAD],
         error="sync interrupted", mutate=update(journal=True))
    case("unavailable PR evidence fails closed", error="unavailable", mutate=update(gh_unavailable=True))
    case("unavailable tracker evidence fails closed", error="unavailable", mutate=update(issue_unavailable=True))
    case("ambiguous open PR evidence fails closed", error="ambiguous", mutate=update(prs=[pr(), pr(number=24)]))
    case("partial sync options rejected", args=[CHANGE, "--sync-pr", "23"], error="usage")
    case("unknown option rejected", args=[CHANGE, "--write"], error="usage")
    print("\n" + str(total - failed) + " passed, " + str(failed) + " failed")
    return 1 if failed else 0


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "--fake":
        sys.argv = [sys.argv[2]] + sys.argv[3:]
        sys.exit(fake())
    sys.exit(run_tests(Path(sys.argv[1]).resolve()))
