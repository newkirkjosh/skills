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
        before = SNAPSHOT(self.root), [SNAPSHOT(Path(t["worktree"]["path"])) for t in self.trees if "worktree" in t]
        result = subprocess.run(["bash", str(script), *args], cwd=cwd or self.root,
                                env=env, text=True, capture_output=True, timeout=30)
        after = SNAPSHOT(self.root), [SNAPSHOT(Path(t["worktree"]["path"])) for t in self.trees if "worktree" in t]
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

    def inherited_archive_with_default_drift(f, branches):
        inherited_archive(f, branches)
        default_tree = f.temp / "default-worktree"
        f.git("worktree", "add", "-q", str(default_tree), "main")
        f.write("openspec/changes/archive/feat-onboarding/sprint-contract.md",
                "# Contract\n" + f.contract() + "\nDefault-only correction\n", root=default_tree)
        updated = f.commit("correct archived contract on default branch", default_tree)
        f.git("update-ref", "refs/remotes/origin/main", updated)

    @test("B1: default archive edits do not confer ownership on an unrelated fix branch")
    def inherited_branch_after_default_drift(f):
        inherited_archive_with_default_drift(f, ["fix/onboarding"])
        f.inspect(script, ["fix/onboarding"], "Reconstruct change folder", "unresolved")

    @test("B1: legacy folder keeps change fallback after default archive edits")
    def inherited_folder_after_default_drift(f):
        inherited_archive_with_default_drift(f, ["fix/onboarding"])
        f.inspect(script, ["feat-onboarding"], "Phase 6: Cleanup", "change")

    @test("B1: default archive edits do not make inherited fix and chore branches ambiguous")
    def inherited_ambiguity_after_default_drift(f):
        inherited_archive_with_default_drift(f, ["fix/onboarding", "chore/onboarding"])
        f.inspect(script, ["feat-onboarding"], "Phase 6: Cleanup", "change")

    def squash_merged_legacy_fix(f, archived, issue_state):
        prefix = "openspec/changes/archive/" if archived else "openspec/changes/"
        f.implementation(branch="fix/example", playbook=None, prefix=prefix)
        default_tree = f.temp / "default-worktree"
        f.git("worktree", "add", "-q", str(default_tree), "main")
        f.git("merge", "--squash", "fix/example", cwd=default_tree)
        merged = f.commit("squash completed legacy fix", default_tree)
        f.git("update-ref", "refs/remotes/origin/main", merged)
        # The retained fix branch owns these artifacts even though squash made
        # their contents equal to the current default branch.
        f.state["issues"] = {"11": issue_state}
        f.pr("fix/example", "MERGED")

    for archived in (False, True):
        for issue_state in ("OPEN", "CLOSED"):
            for target in ("fix/example", "23", "feat-example"):
                @test("C1: squash-merged legacy fix retains close-out for "
                      + ("archived" if archived else "active") + " artifacts, "
                      + issue_state.lower() + " issue and " + target + " input")
                def merged_legacy_owner(f, archived=archived, issue_state=issue_state,
                                        target=target):
                    squash_merged_legacy_fix(f, archived, issue_state)
                    f.inspect(script, [target], "Phase 6: Close-out", "bug-fix")

    def assert_selected_overrides(f, head):
        f.pr("feat/example-ui")
        for target in ("feat-example", "feat/example-ui"):
            f.inspect(script, [target, "--reevaluate-head", head],
                      "Phase 3: Evaluation (fresh evaluator)")
            f.inspect(script, [target, "--sync-pr", "23", "--expected-head", head,
                               "--default-sha", f.base], "Requested sync")

    for target in ("feat-example", "feat/example"):
        @test("B3: selected UI handoff preempts table for " + target + " input")
        def selected_handoff(f, target=target):
            later_layer(f)
            f.write("openspec/changes/feat-example/handoff.md", "Resume UI check\n")
            head = f.commit("record next layer handoff")
            assert_selected_overrides(f, head)
            selected = f.inspect(script, ["feat/example-ui"], "Handoff: Resume UI check")
            routed = f.inspect(script, [target], "Handoff: Resume UI check")
            assert routed == selected, "input changed selected layer handoff"

    @test("B3: stale first-layer handoff does not preempt selected UI normal route")
    def stale_first_handoff(f):
        head = later_layer(f)
        first_tree = f.temp / "first-worktree"
        f.git("worktree", "add", "-q", str(first_tree), "feat/example")
        f.write("openspec/changes/feat-example/handoff.md", "Stale core check\n", root=first_tree)
        f.commit("record retained first layer handoff", first_tree)
        f.tree("feat/example", first_tree)
        assert_selected_overrides(f, head)
        selected = f.inspect(script, ["feat/example-ui"], CLASSIFY)
        routed = f.inspect(script, ["feat-example"], CLASSIFY)
        assert routed == selected, "stale first-layer handoff displaced selected UI route"

    @test("D1: missing brief reconstructs before unavailable tracker evidence")
    def missing_brief_before_tracker(f):
        f.implementation()
        (f.root / "openspec/changes/feat-example/scope-brief.md").unlink()
        f.state["issue_unavailable"] = True
        f.inspect(script, ["feat-example"], "Reconstruct Scope Brief")

    @test("D1: missing issue map enters issue creation with unavailable tracker")
    def missing_issues_before_tracker(f):
        f.implementation()
        (f.root / "openspec/changes/feat-example/issues.md").unlink()
        f.state["issue_unavailable"] = True
        f.inspect(script, ["feat-example"], "Phase 1: Issue creation")

    @test("D1: merged branch closes out before unavailable tracker evidence")
    def merged_before_tracker(f):
        f.implementation()
        f.pr(state="MERGED")
        f.state["issue_unavailable"] = True
        f.inspect(script, ["feat-example"], "Phase 6: Close-out")

    @test("D1: unambiguous unit handoff precedes unavailable tracker evidence")
    def single_unit_handoff_before_tracker(f):
        f.implementation()
        f.write("openspec/changes/feat-example/handoff.md", "Resume requested check\n")
        f.state["issue_unavailable"] = True
        f.inspect(script, ["feat-example"], "Handoff: Resume requested check")

    @test("D1: unavailable tracker cannot select among distinct layer handoffs")
    def ambiguous_unit_handoff_needs_tracker(f):
        later_layer(f)
        f.write("openspec/changes/feat-example/handoff.md", "Resume UI check\n")
        f.state["issue_unavailable"] = True
        f.inspect(script, ["feat-example"], error="gh issue")

    def merged_first_without_next_branch(f, handoff, keep_tree):
        f.implementation(layers=("core", "ui"), issues="core: 11\nui: 12\n",
                         contracts=f.contract("core"))
        if handoff == "committed":
            f.write("openspec/changes/feat-example/handoff.md", "Stale core check\n")
            f.commit("record first layer handoff")
        f.trees = []
        f.git("checkout", "-q", "--detach")
        default_tree = f.temp / "default-worktree"
        f.git("worktree", "add", "-q", str(default_tree), "main")
        f.git("merge", "--squash", "feat/example", cwd=default_tree)
        default_handoff = default_tree / "openspec/changes/feat-example/handoff.md"
        if default_handoff.exists():
            f.git("rm", "-q", "-f", "openspec/changes/feat-example/handoff.md", cwd=default_tree)
        (default_tree / "openspec/changes/archive").mkdir(parents=True)
        f.git("mv", "openspec/changes/feat-example", "openspec/changes/archive/feat-example",
              cwd=default_tree)
        merged = f.commit("squash first layer and archive", default_tree)
        f.git("update-ref", "refs/remotes/origin/main", merged)
        if keep_tree:
            first_tree = f.temp / "first-worktree"
            f.git("worktree", "add", "-q", str(first_tree), "feat/example")
            f.tree("feat/example", first_tree)
            if handoff == "uncommitted":
                f.write("openspec/changes/feat-example/handoff.md", "Stale core check\n",
                        root=first_tree)
        f.state["issues"] = {"11": "CLOSED", "12": "OPEN"}
        f.pr("feat/example", "MERGED")

    for handoff, keep_tree in ((None, False), (None, True),
                               ("committed", False), ("committed", True),
                               ("uncommitted", True)):
        @test("B3: uncreated next layer with " + str(handoff) + " first-layer handoff and "
              + ("retained" if keep_tree else "no") + " first-layer worktree")
        def uncreated_next_layer(f, handoff=handoff, keep_tree=keep_tree):
            merged_first_without_next_branch(f, handoff, keep_tree)
            f.inspect(script, ["feat-example"],
                      "Phase 6: Close-out" if keep_tree else "Phase 2: Implementation")

    for variant in ("linear", "no layer headings", "incomplete map"):
        @test("F1: unambiguous handoff precedes " + variant + " parsing")
        def unambiguous_handoff_before_map(f, variant=variant):
            f.implementation()
            if variant == "linear":
                f.write("openspec/changes/feat-example/issues.md", "catalog: ABC-12\n")
            elif variant == "no layer headings":
                f.write("openspec/changes/feat-example/tasks.md", "# Tasks\n- [ ] Implement\n")
            else:
                f.write("openspec/changes/feat-example/issues.md", "# Issue map pending\n")
            f.write("openspec/changes/feat-example/handoff.md", "Resume requested check\n")
            f.inspect(script, ["feat-example"], "Handoff: Resume requested check")

    @test("F2: selected later snapshot missing issue map enters issue creation")
    def selected_later_missing_issues(f):
        later_layer(f)
        (f.root / "openspec/changes/feat-example/issues.md").unlink()
        f.commit("remove next layer issue map")
        f.inspect(script, ["feat-example"], "Phase 1: Issue creation")

    def retained_first_without_next_branch(f, handoff):
        # The next layer has no branch yet and the default ref has no folder,
        # so only the retained first-layer worktree carries the change folder.
        first_tree = f.temp / "first-worktree"
        f.git("worktree", "add", "-q", "-b", "feat/example", str(first_tree), "main")
        f.folder(layers=("core", "ui"), issues="core: 11\nui: 12\n",
                 contracts=f.contract("core"), root=first_tree)
        f.write("example.py", "fixture = True\n", root=first_tree)
        if handoff == "committed":
            f.write("openspec/changes/feat-example/handoff.md", "Stale core check\n",
                    root=first_tree)
        f.commit("first layer implementation", first_tree)
        if handoff == "uncommitted":
            f.write("openspec/changes/feat-example/handoff.md", "Stale core check\n",
                    root=first_tree)
        f.tree("feat/example", first_tree)
        f.state["issues"] = {"11": "CLOSED", "12": "OPEN"}
        return first_tree

    for handoff in ("committed", "uncommitted"):
        for invoked in ("retained first-layer worktree", "main checkout"):
            @test("B3: selected next layer without snapshot ignores " + handoff
                  + " first-layer handoff from " + invoked)
            def no_default_snapshot(f, handoff=handoff, invoked=invoked):
                first_tree = retained_first_without_next_branch(f, handoff)
                cwd = first_tree if invoked.startswith("retained") else None
                output = f.inspect(script, ["feat-example"], "Phase 2: Implementation", cwd=cwd)
                assert "Stale core check" not in output, "stale first-layer handoff surfaced"

    @test("B3: selected next layer without snapshot keeps discovered folder from main checkout")
    def no_default_snapshot_main(f):
        retained_first_without_next_branch(f, None)
        f.inspect(script, ["feat-example"], "Phase 2: Implementation")

    def remote_only_head(f, remote):
        # The PR head exists only as refs/remotes/origin/<head>: no local
        # branch, no worktree, and no folder on the default ref.
        f.git("update-ref", "-d", "refs/heads/feat/example")
        if remote == "missing":
            f.git("update-ref", "-d", "refs/remotes/origin/feat/example")

    def remote_head_fixture(f, remote="match"):
        f.implementation()
        f.trees = []
        f.git("checkout", "-q", "main")
        f.state["branch"] = "main"
        tracked = f.head
        if remote == "stale":
            f.git("checkout", "-q", "feat/example")
            f.write("example.py", "fixture = 2\n")
            f.commit("newer PR head not yet fetched")
            f.git("checkout", "-q", "main")
        f.pr()
        f.git("update-ref", "refs/remotes/origin/feat/example", tracked)

    for target in ("23", "feat/example", "feat-example"):
        @test("N1: remote-tracking PR head routes like the local branch for " + target + " input")
        def remote_tracking_head(f, target=target):
            remote_head_fixture(f)
            local = f.inspect(script, [target], CLASSIFY)
            remote_only_head(f, "match")
            remote = f.inspect(script, [target], CLASSIFY)
            assert remote == local, "remote-tracking PR head changed the route"

        for remote in ("missing", "stale"):
            @test("N1: " + remote + " remote-tracking PR head is unavailable for " + target + " input")
            def remote_tracking_unavailable(f, target=target, remote=remote):
                remote_head_fixture(f, remote)
                remote_only_head(f, remote)
                f.inspect(script, [target], error="unavailable")

    def ledger_fixture(f, record):
        f.implementation(prefix="openspec/changes/archive/")
        for n in (1, 2):
            f.write("later" + str(n) + ".py", "fixture = True\n")
            f.commit("later commit " + str(n))
        later = f.git("rev-list", f.base + "..feat/example").split()
        assert len(later) == 3, "fixture expected three later commits"
        for sha in later:
            matches = [o for o in f.git("rev-list", "--all", "--objects").split()
                       if o.startswith(sha[:6])]
            assert len(matches) == 1, "fixture prefix is not unique"
        f.pr()
        ledger = f.temp / "review-ledger.md"
        ledger.write_text("# Review ledger\n\n" + "".join(
            record(sha, i == len(later) - 1) for i, sha in enumerate(later)))
        return ["feat-example", "--ledger", str(ledger)]

    def inline(ref, value="no"):
        return ref + " behavioral: " + value + " — Review record only\n"

    def block(ref, value="no"):
        return "## " + ref + "\nbehavioral: " + value + "\n\n"

    for form, render in (("inline", inline), ("section", block)):
        for length in (7, 12):
            @test("N2: " + str(length) + "-char " + form + " ledger prefixes classify later commits")
            def abbreviated_ledger(f, render=render, length=length):
                args = ledger_fixture(f, lambda sha, last: render(sha[:length]))
                f.inspect(script, args, "Phase 5: Completion")

        @test("N2: 6-char " + form + " ledger prefix does not classify a later commit")
        def short_ledger(f, render=render):
            args = ledger_fixture(f, lambda sha, last: render(sha[:6] if last else sha))
            f.inspect(script, args, CLASSIFY)

        @test("N2: abbreviated " + form + " yes record outweighs full-SHA no record")
        def abbreviated_yes(f, render=render):
            args = ledger_fixture(f, lambda sha, last: render(sha)
                                  + (render(sha[:7], "yes") if last else ""))
            f.inspect(script, args, CLASSIFY)

    for owner in ("other", "same"):
        @test("N3: branch-only wt item for " + owner + " branch is not a worktree")
        def branch_only_item(f, owner=owner):
            f.implementation()
            if owner == "same":
                f.trees = []
            branch = "feat/other" if owner == "other" else "feat/example"
            f.trees.append({"branch": branch, "display": branch + " (branch only)",
                            "head": {"sha": f.head}})
            f.inspect(script, ["feat-example"], CLASSIFY)

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
