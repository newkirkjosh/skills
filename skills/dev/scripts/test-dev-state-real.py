#!/usr/bin/env python3
"""Routing regressions using offline real git refs, snapshots and worktrees."""
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import tempfile

HELPERS = runpy.run_path(str(Path(__file__).with_name("test-dev-state.py")))
SNAPSHOT = HELPERS["snapshot"]
CLASSIFY = "Phase 4 steps 4–5, then Phase 5"


class Fixture:
    def __init__(self, temp):
        self.temp = Path(temp)
        self.root = self.temp / "repo"
        self.bin = self.temp / "bin"
        self.bin.mkdir()
        self.real_git = shutil.which("git")
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull,
                        GIT_CONFIG_NOSYSTEM="1", GIT_AUTHOR_NAME="Fixture",
                        GIT_COMMITTER_NAME="Fixture", GIT_AUTHOR_EMAIL="fixture@example.com",
                        GIT_COMMITTER_EMAIL="fixture@example.com", GIT_OPTIONAL_LOCKS="0")
        self.git("init", "-q", "-b", "main", str(self.root), cwd=self.temp)
        self.write("README.md", "Fixture repository\n")
        self.commit("base")
        self.base = self.git("rev-parse", "HEAD")
        self.git("update-ref", "refs/remotes/origin/main", self.base)
        self.state = {"branch": "main", "prs": [], "issues": {"11": "OPEN"},
                      "worktrees": []}
        self.trees = []
        for tool in ("git", "gh", "wt"):
            launcher = self.bin / tool
            launcher.write_text("#!/usr/bin/env bash\nexec python3 -I '"
                                + str(Path(__file__).with_name("test-dev-state.py").resolve())
                                + "' --fake " + tool + ' "$@"\n')
            launcher.chmod(0o755)

    def git(self, *args, cwd=None):
        result = subprocess.run([self.real_git, *args], cwd=cwd or self.root,
                                env=self.env, text=True, capture_output=True)
        if result.returncode:
            raise AssertionError("fixture git failed: " + repr(args) + ": " + result.stderr)
        return result.stdout.strip()

    def write(self, name, body, root=None):
        path = (root or self.root) / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(body)

    def commit(self, message, root=None):
        self.git("add", ".", cwd=root)
        self.git("-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null",
                 "commit", "-q", "-m", message, cwd=root)
        return self.git("rev-parse", "HEAD", cwd=root)

    def branch(self, name):
        self.git("checkout", "-q", "-b", name)
        self.state["branch"] = name

    def tree(self, branch, root=None):
        root = root or self.root
        self.trees.append({"branch": branch, "worktree": {"path": str(root), "changes": False},
                           "head": {"sha": self.git("rev-parse", branch)},
                           "default_branch": {"ahead": 1, "behind": 0}})

    def contract(self, layer="catalog", checked=True):
        return ("\n## :" + layer + "\n- [" + ("x" if checked else " ") + "] Evidence\n"
                + "Evaluated at: " + self.base + "\nCross-review: fixture, 1 pass, converged\n")

    def folder(self, name="feat-example", prefix="openspec/changes/", playbook="change",
               layers=("catalog",), issues=None, contracts=None, root=None):
        directory = prefix + name + "/"
        brief = "# Legacy brief\n" if playbook is None else "Playbook: " + playbook + "\n"
        self.write(directory + "scope-brief.md", brief, root)
        self.write(directory + "proposal.md", "# Proposal\n", root)
        self.write(directory + "tasks.md", "# Tasks\n" + "".join(
            "\n## :" + layer + "\n- [ ] Implement\n" for layer in layers), root)
        self.write(directory + "issues.md", issues or "catalog: 11\n", root)
        self.write(directory + "sprint-contract.md", "# Contract\n" + (
            contracts if contracts is not None else self.contract()), root)

    def implementation(self, branch="feat/example", name="feat-example", **folder_args):
        self.branch(branch)
        self.folder(name, **folder_args)
        self.write("example.py", "fixture = True\n")
        self.head = self.commit("implementation")
        self.tree(branch)

    def pr(self, branch="feat/example", state="OPEN", number=23, **extra):
        value = {"number": number, "state": state, "isDraft": False,
                 "headRefName": branch, "headRefOid": self.git("rev-parse", branch),
                 "baseRefName": "main", "url": "https://github.com/owner/repo/pull/" + str(number),
                 "isCrossRepository": False, "headRepository": {"name": "repo", "nameWithOwner": "owner/repo"},
                 "headRepositoryOwner": {"login": "owner"}}
        value.update(extra)
        self.state["prs"].append(value)

    def inspect(self, script, args, step=None, playbook="change", error=None, cwd=None):
        fixture = self.temp / "fixture.json"
        self.state["worktrees"] = self.trees
        fixture.write_text(json.dumps(self.state))
        violations = self.temp / "violations"
        env = dict(self.env, PATH=str(self.bin) + os.pathsep + self.env["PATH"],
                   DEV_STATE_REAL_GIT=self.real_git, DEV_STATE_FIXTURE=str(fixture),
                   DEV_STATE_CALLS=str(self.temp / "calls"), DEV_STATE_VIOLATIONS=str(violations))
        # Include actual refs, the index and every worktree in the read-only check.
        before = SNAPSHOT(self.root), [SNAPSHOT(Path(t["worktree"]["path"])) for t in self.trees]
        result = subprocess.run(["bash", str(script), *args], cwd=cwd or self.root,
                                env=env, text=True, capture_output=True, timeout=30)
        after = SNAPSHOT(self.root), [SNAPSHOT(Path(t["worktree"]["path"])) for t in self.trees]
        assert before == after, "repository, refs, index or worktree changed"
        assert not violations.exists(), "unsupported/mutating command: " + violations.read_text()
        output = result.stdout + result.stderr
        if error:
            assert result.returncode != 0 and error in output.lower(), (
                "expected rejection containing " + repr(error) + "; got " + output.strip())
            assert "Step:" not in result.stdout, "fabricated step on rejected evidence"
        else:
            assert result.returncode == 0, "unexpected failure: " + output.strip()
            assert "Playbook: " + playbook in result.stdout.splitlines(), output.strip()
            assert "Step: " + step in result.stdout.splitlines(), output.strip()
        return result.stdout


def main(script):
    tests = []

    def test(name):
        def decorate(function):
            tests.append((name, function))
            return function
        return decorate

    @test("R1: repository root and subdirectory select identical implementation evidence")
    def cwd_independent(f):
        f.implementation()
        nested = f.root / "nested"
        nested.mkdir()
        at_root = f.inspect(script, ["feat-example"], CLASSIFY)
        beneath_root = f.inspect(script, ["feat-example"], CLASSIFY, cwd=nested)
        assert at_root == beneath_root, "cwd changed public routing result"

    @test("R2: hyphenated branch does not borrow archived prefix folder")
    def prefix_folder(f):
        f.folder("feat-dev", prefix="openspec/changes/archive/")
        f.commit("archived unrelated change")
        f.branch("feat/dev-state")
        f.write("example.py", "fixture = True\n")
        f.commit("new implementation without artifacts")
        f.tree("feat/dev-state")
        f.inspect(script, ["feat/dev-state"], "Reconstruct change folder", "unresolved")

    @test("R2: fix branch does not borrow unrelated same-slug folder from default checkout")
    def unrelated_legacy_slug(f):
        f.branch("fix/onboarding")
        f.write("example.py", "fixture = True\n")
        f.commit("implementation without artifacts")
        f.git("checkout", "-q", "main")
        f.state["branch"] = "main"
        f.folder("feat-onboarding")
        f.inspect(script, ["fix/onboarding"], "Reconstruct change folder", "unresolved")

    @test("R3: merged sibling prefix PR does not close out this change")
    def merged_sibling(f):
        f.implementation(branch="feat/dev", name="feat-dev")
        sibling = f.temp / "sibling"
        f.git("worktree", "add", "-q", "-b", "feat/dev-state", str(sibling), "main")
        f.tree("feat/dev-state", sibling)
        f.pr("feat/dev-state", "MERGED")
        f.inspect(script, ["feat-dev"], CLASSIFY)

    @test("R4: shared unit with unchecked later section re-evaluates ready PR")
    def shared_unchecked(f):
        f.implementation(layers=("core", "ui"), issues="core: 11\nui: 11\n",
                         contracts=f.contract("core") + f.contract("ui", checked=False))
        f.pr()
        f.inspect(script, ["feat-example"], "Phase 5: Re-evaluation")

    @test("R4: missing section in shared unit starts whole-unit evaluation")
    def shared_missing(f):
        f.implementation(layers=("core", "ui"), issues="core: 11\nui: 11\n",
                         contracts=f.contract("core"))
        f.inspect(script, ["feat-example"], "Phase 3: Evaluation (start)")

    @test("R5: existing branch snapshot precedes stale default checkout artifacts")
    def branch_snapshot(f):
        f.implementation(playbook="bug-fix")
        f.trees = []
        f.git("checkout", "-q", "main")
        f.state["branch"] = "main"
        f.folder(playbook="change")
        f.inspect(script, ["feat/example"], CLASSIFY, "bug-fix")

    @test("R6: change-name re-evaluation validates first open layer branch head")
    def reevaluate_open_layer(f):
        f.implementation(layers=("core", "ui"), issues="core: 11\nui: 12\n",
                         contracts=f.contract("core"))
        f.state["issues"] = {"11": "CLOSED", "12": "OPEN"}
        ui_tree = f.temp / "ui-worktree"
        f.git("worktree", "add", "-q", "-b", "feat/example-ui", str(ui_tree), "feat/example")
        f.write("ui.py", "fixture = True\n", root=ui_tree)
        ui_head = f.commit("next layer implementation", ui_tree)
        f.tree("feat/example-ui", ui_tree)
        f.inspect(script, ["feat-example", "--reevaluate-head", ui_head],
                  "Phase 3: Evaluation (fresh evaluator)")

    @test("R7: foreign repository PR URL is rejected before routing")
    def foreign_url(f):
        f.implementation()
        f.pr(url="https://github.com/other/repository/pull/23")
        f.inspect(script, ["https://github.com/other/repository/pull/23"], error="repository")

    @test("R7: same-repository PR URL with cross-repository head is rejected")
    def foreign_head(f):
        f.implementation()
        f.pr(isCrossRepository=True, headRepository={"name": "repo", "nameWithOwner": "other/repo"},
             headRepositoryOwner={"login": "other"})
        f.inspect(script, ["https://github.com/owner/repo/pull/23"], error="repository")

    @test("E3: verified legacy fix worktree gives same fallback for branch and folder input")
    def legacy_identity(f):
        worktree = f.temp / "fix-worktree"
        f.git("worktree", "add", "-q", "-b", "fix/example", str(worktree), "main")
        f.folder(playbook=None, root=worktree)
        f.write("example.py", "fixture = True\n", root=worktree)
        f.commit("legacy fix implementation", worktree)
        f.tree("fix/example", worktree)
        branch_result = f.inspect(script, ["fix/example"], CLASSIFY, "bug-fix")
        folder_result = f.inspect(script, ["feat-example"], CLASSIFY, "bug-fix")
        assert branch_result == folder_result, "input spelling changed verified branch identity"

    def inherited_archive(f, branches):
        f.folder("feat-onboarding", prefix="openspec/changes/archive/", playbook=None)
        archived = f.commit("archive completed change on default branch")
        f.git("update-ref", "refs/remotes/origin/main", archived)
        f.state["issues"] = {"11": "CLOSED"}
        for branch in branches:
            f.git("checkout", "-q", "main")
            f.branch(branch)
            f.write(branch.partition("/")[0] + ".py", "fixture = True\n")
            f.commit("unrelated implementation inheriting archived artifacts")
        f.tree(branches[-1])

    @test("B1: branch cannot own an archived legacy folder inherited from main")
    def inherited_branch(f):
        inherited_archive(f, ["fix/onboarding"])
        f.inspect(script, ["fix/onboarding"], "Reconstruct change folder", "unresolved")

    @test("B1: archived legacy folder does not adopt unrelated inherited fix branch")
    def inherited_folder(f):
        inherited_archive(f, ["fix/onboarding"])
        f.inspect(script, ["feat-onboarding"], "Phase 6: Cleanup", "change")

    @test("B1: unrelated branches inheriting the same archive do not make folder ambiguous")
    def inherited_ambiguity(f):
        inherited_archive(f, ["fix/onboarding", "chore/onboarding"])
        f.inspect(script, ["feat-onboarding"], "Phase 6: Cleanup", "change")

    @test("B2: same-name fork PR is ignored during discovery but rejected as explicit target")
    def fork_discovery(f):
        f.implementation()
        f.pr()
        f.pr(state="CLOSED", number=24, isCrossRepository=True,
             headRepository={"name": "repo", "nameWithOwner": "other/repo"},
             headRepositoryOwner={"login": "other"})
        f.inspect(script, ["24"], error="repository")
        f.inspect(script, ["https://github.com/owner/repo/pull/24"], error="repository")
        f.inspect(script, ["feat/example", "--sync-pr", "24", "--expected-head", f.head,
                           "--default-sha", f.base], error="repository")
        f.inspect(script, ["feat/example"], CLASSIFY)

    def later_layer(f):
        f.implementation(layers=("core", "ui"), issues="core: 11\nui: 12\n",
                         contracts=f.contract("core"))
        f.state["issues"] = {"11": "CLOSED", "12": "OPEN"}
        f.trees = []  # Keep the first-layer ref but remove its worktree evidence.
        f.branch("feat/example-ui")
        f.folder(layers=("core", "ui"), issues="core: 11\nui: 12\n",
                 contracts=f.contract("core") + f.contract("ui"))
        f.write("ui.py", "fixture = True\n")
        head = f.commit("evaluate and review next layer")
        f.tree("feat/example-ui")
        return head

    @test("B3: folder selects first-open-layer contract ahead of retained first-layer snapshot")
    def first_open_artifacts(f):
        head = later_layer(f)
        branch_result = f.inspect(script, ["feat/example-ui"], CLASSIFY)
        # Requested re-evaluation must keep validating the selected UI head.
        branch_reeval = f.inspect(script, ["feat/example-ui", "--reevaluate-head", head],
                                  "Phase 3: Evaluation (fresh evaluator)")
        folder_reeval = f.inspect(script, ["feat-example", "--reevaluate-head", head],
                                  "Phase 3: Evaluation (fresh evaluator)")
        assert folder_reeval == branch_reeval, "re-evaluation input changed selected layer"
        folder_result = f.inspect(script, ["feat-example"], CLASSIFY)
        assert folder_result == branch_result, "folder input selected stale first-layer artifacts"

    failed = 0
    for name, function in tests:
        try:
            with tempfile.TemporaryDirectory(prefix="dev-state-real-") as temp:
                function(Fixture(temp))
            print("ok   " + name)
        except (AssertionError, OSError, subprocess.TimeoutExpired) as exc:
            failed += 1
            print("FAIL " + name + ": " + str(exc).replace("\n", " | "))
    print("\n" + str(len(tests) - failed) + " passed, " + str(failed) + " failed (real git)")
    return bool(failed)


if __name__ == "__main__":
    sys.exit(main(Path(sys.argv[1]).resolve()))
