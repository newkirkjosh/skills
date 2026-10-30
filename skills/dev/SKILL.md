---
name: dev
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Orchestrates one change from approved job stories to a merged PR and archived change folder: detects existing state and enters at the right phase, then sequences scope brief, spec-writer, the tracker, test author and implementer subagents, an isolated evaluator, a cross-model review (Codex or Claude, whichever did not write it), pr, review and archive."
license: MIT (Scope Brief adapted from fx/skills by Marian Rudzynski; see LICENSE.txt)
metadata:
  type: flexible
  upstream: "https://github.com/fx/skills/tree/4b1010d/skills/dev"
---

# Dev

## When to Use

**Invocation.** The user names this skill with a feat-name, in any wording. These three are equivalent, and all re-run entry detection from scratch:
- "start work on `<feat-name>`"
- "what's next for `<feat-name>`"
- "open a PR for `<feat-name>`"

All three behave identically: entry detection runs first and decides the phase, whatever the wording. "Open a PR for feat-X" does not skip to Phase 4; it may enter Phase 3 if `sprint-contract.md` is absent or has unchecked items.

**Explicit use only.** Never load this skill for a request that doesn't name it: a status question, a branch sync or a PR tweak on a change is handled directly.

**The workflow ends at its handoff.** Its rules apply to the invocation that started it and stop at the merge-ready report (or the merge, under a Merge policy), or when it stops for the user. A later request in the same session doesn't inherit its orchestration unless the user invokes it again.

## Roles

You are the **coordinator**. You own the Scope Brief, branches, commits, `sprint-contract.md`, the PR and every handoff to the user. You delegate exactly three jobs, each to its own general-purpose subagent that reads a role file from this skill's `references/` directory:

| Role | File | Writes | Tier |
|---|---|---|---|
| Test author | `references/test-author.md` | Failing tests and fakes only | `medium` |
| Implementer | `references/implementer.md` | Production code only | `medium` |
| Evaluator | `references/evaluator.md` | Nothing; reports the contract | `medium` |

Spawn each one like this. The syntax is Claude Code's and only illustrative; `<skill-dir>` is the base directory shown when this skill loaded, and `<tier model>` is the host's model for that tier (`small`, `medium` or `large`; on Claude Code currently `haiku`, `sonnet`, `opus`). Never hardcode a model name elsewhere: names change, tiers don't.

```
Agent tool:
  subagent_type: "general-purpose"
  model: "<tier model>"
  description: "<role>: <feat-name> <layer>"
  prompt: "Read <skill-dir>/references/<role>.md and act in that role.

           <the Scope Brief from scope-brief.md, verbatim>

           Change folder: <absolute path>
           Layer: <:layer>
           <role-specific input: the test author's report for the implementer,
            the failing items on a fix pass; for the evaluator only the
            environment it needs (see Phase 3)>"
```

**On any host other than Claude Code, and in a headless session on any host** (nothing can answer or wake you mid-run, as in `claude -p` or `codex exec`), read `references/host-adapters.md` before the first spawn. On Codex, ending your turn kills running subagents, and a spawn without `fork_turns: "none"` can't take a tier. In a headless session its foreground rules override every "run in the background" instruction in this skill.

Never hand a subagent the whole lifecycle, and never do a delegated job yourself: a coordinator that writes the code also grades it. One exception: a review or evaluation finding that only needs a few lines of non-code wording (docs, comments, a contract sentence) you apply directly and say so in the commit; anything touching code, config or tests goes to an implementer.

**Budget.** Each spawn costs roughly 50–80k tokens, and the user's plan has a session limit that a long run can hit. Match the tier to the job: `small` for narrow or mechanical evaluations and doc fixes, `medium` for test authoring, implementation and judgment-heavy evaluation. Keep at most three agents in flight. Scale the review set to the change (see `pr`).

## Scope Brief

Read `references/scope-brief.md` before Phase 0. It defines the brief, its fields, and how it travels. Every subagent prompt and every review request in this lifecycle carries the brief verbatim; that is how "just", "only" and the implied neighbouring updates survive past the first handoff.

## Worktrees

**One change, one worktree, for its whole life,** managed with worktrunk (`wt`; current commands from `wt <command> --help` and https://worktrunk.dev/llms.txt). `wt switch --create <branch> --no-cd` creates it where the user's worktrunk config puts worktrees, before Phase 0 writes anything; find its path with `wt list --format=json | jq -r '.items[] | select(.branch=="<branch>") | .worktree.path'`. Every phase, subagent and command for that change runs from that path. The main checkout stays on the default branch and clean, so other changes can start beside it.

- **Parallel work** is one coordinator session per change, each started in its own worktree. A single session juggling several changes runs out of context.
- **Status** comes from `wt list --format=json` (per item: `branch`, `worktree.path`, `worktree.changes`, `default_branch.ahead/behind`, `head.committed_at`) plus the PR state from the github skill. Check it at the start of every invocation and after every merge: a merged PR, run the Phase 6 cleanup; an open PR behind the default branch, merge it in and push; no PR and no commit for two weeks, report it as stale and never delete it; uncommitted changes, leave it alone.
- **Shared resources** that only one run can use at a time (an emulator, a device, a fixed local port) are taken with `flock`, on a lock file in the repository's common git dir, which every worktree shares: `mkdir -p "$(git rev-parse --path-format=absolute --git-common-dir)/locks"`, then `flock "$(git rev-parse --path-format=absolute --git-common-dir)/locks/<resource>" <command>`. Hold it for the whole check that needs the resource, and pass the same rule to evaluators.
- **Builds** in separate worktrees have separate outputs and can run side by side; the lock is only for what they truly share.

## Entry detection

First find the change: its branch in `wt list --format=json`, then an open PR for it, then `openspec/changes/archive/<feat-name>/` on the default branch. Read the change folder from wherever it is found and continue there; if the worktree is gone but the branch exists, `wt switch <branch> --no-cd` recreates it. Only when it is found nowhere is it a new change.

If the change folder has a `handoff.md`, read it first: it records where a stopped run left off. Resume from it, and delete it in the commit that gets past the point it describes.

Then, checked in order, first match wins. Work proceeds one layer at a time, in `tasks.md` order; "the layer" below is the first layer whose sub-issue in `issues.md` is still open. When several layers map to the **same** issue (a small fix tracked by one issue), treat them as one unit: one branch, one test author/implementer/evaluator pass covering all of them, one PR.

| Existing state | Entry point |
|---|---|
| No `openspec/changes/<feat-name>/` folder | Phase 0: Scope Brief and OpenSpec setup |
| Worktree, branch or PR exists, but no change folder | Reconstruct the change folder there from its commits (brief, proposal, stories, design note, tasks), commit it, then re-run detection |
| Change folder exists, no `scope-brief.md` | Reconstruct the brief (see `references/scope-brief.md`), then re-run detection |
| Change folder exists, no `issues.md` | Phase 1: Issue creation |
| `issues.md` exists, no branch for the layer | Phase 2: Implementation |
| Branch exists, no open PR, no `sprint-contract.md` section for the layer | Phase 3: Evaluation (start) |
| Branch exists, no open PR, the layer's contract has unchecked items | Phase 3: Evaluation (fix pass) |
| Branch exists, no open PR, the layer's contract is all checked, no `Cross-review:` line | Phase 4: Cross-model review |
| Branch exists, no open PR, the layer's contract is all checked and has its `Cross-review:` line | Phase 4: PR creation |
| Draft PR open (from Phase 3 step 1), the layer's contract all checked, no `Cross-review:` line | Phase 4: Cross-model review, then mark the draft ready |
| PR open for the layer | Phase 5: Review |
| All sub-issues in `issues.md` are closed | Phase 6: Archive |

## Phases

**Phase 0 — Scope Brief and OpenSpec setup**
0. Create the worktree: `wt switch --create <type>/<short-description> --no-cd` (the `pr` branch name; no issue number is needed), and work from its path from here on.
1. Build the Scope Brief from the user's own words. Grep for every file the change will touch to fill **Also update**.
2. Classify the **Path** (`references/scope-brief.md`). A `spike` leaves the lifecycle here: answer it and stop. Otherwise invoke the `spec-writer` skill, passing the brief: a `bounded` change gets a short design note, an `architectural` one a full `arch-review`, and the user approves an architectural design before Phase 1.
3. Save the brief as `openspec/changes/<feat-name>/scope-brief.md`.
4. Show the user the **Path** with its reason, and the **Interpreted scope**, **Also update** and **Explicitly out of scope** fields, in a few lines, so a wrong reading is caught now.

**Phase 1 — Issue creation**
Invoke `linear` (default tracker) for its OpenSpec-to-issues workflow. Output: `issues.md` with the parent identifier and one sub-issue per layer. If the work already has an issue (the user named one, or it was filed earlier), don't create new ones: write `issues.md` mapping each layer to that issue, add it to the board, and comment there if the diagnosis changed.

*GitHub alternate:* for a GitHub-tracked project, invoke `gh-issues` instead, and place the issues on the board the repository's `AGENTS.md` names (the github skill's projects reference). They write `issues.md` with GitHub issue numbers; the rest of the pipeline is unchanged.

**Phase 2 — Implementation**
If the user says they will implement it themselves, surface the layer's `tasks.md` section, say "When the tasks are done, invoke `dev` again for `<feat-name>`", and stop.

Otherwise, for the layer:
1. In the change's worktree, commit the change folder first (`docs(openspec): …`). A later layer of the same change gets its own branch and worktree, created after the previous layer merges.
2. Spawn the **test author**, unless checks that fail for this exact bug already exist (a broken build, an existing test that fails today). Then skip it, name those checks in the implementer's prompt and in `sprint-contract.md`, and say why.
   Otherwise spawn it. Check its report: every story has a test or a named manual check, and every test fails for the stated reason. Commit the tests (`test(<scope>): …`).
3. Spawn the **implementer** with the test author's report. Check its report: tests and build clean, every **Also update** item accounted for, nothing outside the brief. Commit (`feat(<scope>): …`). If it reports a wrong test, surface its evidence to the user and stop.
4. Continue to Phase 3 in the same run.

**Phase 3 — Evaluation**
1. If the change's evidence only exists on a PR (a CI workflow that triggers on `pull_request`), push and open the PR as a **draft** first, wait for its run, and give the evaluator the PR number as environment. Phase 4 then marks it ready instead of creating it.
2. Export what it evaluates, without history: `bash scripts/eval-export.sh <worktree> HEAD "$(git merge-base origin/<default> HEAD)" <scratch>/eval-<feat-name>-<short-sha>`, to a scratch directory **outside** the repository. It writes `head/` (the change) and `base/` (the default branch it started from), with no `.git`, so commit messages and the diff can't leak.
   Spawn the **evaluator** with only the brief, the layer, the two export paths and the change folder's path inside `head/`. Never pass implementation context: no diff, no summary, no "should pass because". Delete the export after writing the contract.
   **GUI checks.** If the layer has any (a desktop window, a screenshot, simulated input) and the user's global instructions give an isolated display for GUI apps on this machine (an off-screen display, say), copy that recipe into the evaluator's prompt verbatim, and tell it to set `DISPLAY` explicitly on every launch, screenshot and input command, using only input tools scoped to that display (`xdotool`, never a device-level one like `ydotool`, which reaches the live desktop whatever `DISPLAY` says). Subagents don't reliably see those instructions, and an evaluator without the recipe returns `INCOMPLETE`. With no isolated display, GUI checks stay manual: the evaluator reports them `INCOMPLETE` rather than touching the live desktop.
   **Time budget.** Before spawning, estimate the run from what it must do (the last test run's duration, an emulator boot, a CI wait). If it will likely take more than about 10 minutes, tell the user the estimate and what dominates it, then run the evaluator in the background. The evaluator sends a progress line after each step; if 30 minutes pass with no new line, stop it and every process it started (an emulator, a daemon), delete its export, and write `openspec/changes/<feat-name>/handoff.md`: the layer, the last progress line and its time, what was running, what is already known, and the next command to resume with. Commit it with the change folder, tell the user, and stop. Never restart the same evaluation in the same run.
3. Write the layer's section of `sprint-contract.md` from its report (template in the `spec-writer` skill), checking only PASS items. Commit it with the change folder (`docs(openspec): …`).
4. On `VERDICT: PASS`, go to Phase 4.
5. On `VERDICT: FAIL`, run **one** fix pass: GAP items to a fresh test author, then FAIL items (and the new tests) to a fresh implementer, each given only those items. Commit, then spawn a **fresh** evaluator and rewrite the section from its report.
6. On `INCOMPLETE`, first check whether you can provide what's missing on this machine (boot an existing emulator AVD headless, start a local daemon or database), keeping its PID per the `shell` skill. Evaluators can message you to change shared environment mid-run (e.g. "stop the backend now"); do it, then reply with what changed. Never hand an evaluator input control of the user's live desktop (`xdotool`, `ydotool`, or a real `DISPLAY`): they may be using it. GUI checks run the way the user's global instructions say, handed over as in step 2. If so, spawn a **fresh** evaluator and tell it only what's now available. Stop it afterwards.
7. If it still fails after the fix pass, or is still `INCOMPLETE`, surface the open items with the evaluator's evidence and stop. Don't loop further. For `INCOMPLETE`, name what's needed (a device, a running daemon) so the user can provide it and re-invoke.

**Phase 4 — Cross-model review and PR creation**
1. **Cross-model review, before the PR is opened or a Phase 3 draft is marked ready.** The model that didn't write the change reviews it: Codex when you run on Claude Code, Claude when you run on Codex. Skip it only for a `narrow` docs-only change: record `Cross-review: skipped (narrow docs-only)` as in step 4, tell the user, and go on to the PR. Write a prompt file in scratch space: the Scope Brief verbatim as OUT OF SCOPE / IN SCOPE, then "Report only blocking findings: correctness, security, data loss, or a story in `specs/stories.md` the change doesn't meet. Rank them, give file and line, and say why each blocks. Report nothing else." Run it as a long command (backgrounded on Claude Code; a waiter child on Codex), logging to scratch space:
   `bash <skill-dir>/scripts/cross-review.sh <codex|claude> <worktree> origin/<default> <prompt-file> > <scratch>/cross-review-<n>.log 2>&1`
   Its last line is `STATUS=COMPLETED` or `STATUS=ERROR`; a log without one is still running. Never poll it, and never set a timeout on the review command (a waiter child's `wait_agent` timeout is fine): a real review takes many minutes and prints nothing until it finishes.
2. Triage each finding against the brief. In-scope blocking findings go to a fresh implementer as a fix list, all of them in one pass; out-of-scope ones are recorded with the exclusion that covers them. Commit each fix pass (`fix(<scope>): …`) before the next review: the script reviews committed changes only, so an uncommitted fix is never reviewed and the next pass would converge on the old code. A fix that changes behaviour re-runs Phase 3 with a fresh evaluator before the next pass.
3. **Converge**: re-run with the prompt prefixed "Pass <n>. Already fixed: <findings, with commit SHAs>. Report only blocking findings not listed here." Stop when a pass reports no blocking finding (other remarks don't count), or after three passes; then surface what is still open and stop for the user. On `STATUS=ERROR` or a reviewer that can't run, fix the setup error if it is one (the script names it); otherwise record the review as unavailable, tell the user, and continue without it.
4. Record it in the layer's `sprint-contract.md` section: `Cross-review: <reviewer>, <passes> pass(es), converged at <short-sha>` (or `Cross-review: unavailable: <reason>`, or the skip from step 1), and save the final pass's output as `cross-review.md` in the change folder, for `pr` to post; commit both with the change folder.

Once `sprint-contract.md` is final and review is done, make the archive move the PR's last commit: `git mv openspec/changes/<feat-name> openspec/changes/archive/<feat-name>`. Merging then closes the issue (`Closes #<n>`) and archives the change together, with no follow-up PR to `main`.
Invoke `pr`, passing the Scope Brief for the PR body and the reviewers. After the PR exists, link it to the layer's sub-issue from `issues.md`: on Linear, comment the PR URL on the sub-issue and move it to the team's review state (the `linear` skill); on GitHub, the PR body's `Closes #<n>` links it, and the board item moves as the repository's `AGENTS.md` says (the github skill's projects reference). Output: PR URL.

**Phase 5 — Review**
`pr` runs the review sequence; pass each review agent the brief as an OUT OF SCOPE / IN SCOPE block. Wait for the hosted checks with the github skill's `wait-for-ci.sh <head-sha>` and, where the repository uses CodeRabbit, `wait-for-coderabbit.sh <pr>`, both as long commands; never a hand-written polling loop. Triage findings against the brief, fix what is in scope, and surface the consolidated result before merge.

**Merging** is the user's call unless the project's `AGENTS.md` has a **Merge policy** that grants it. With that grant, merge yourself only when every gate holds on the PR's current head, re-checked right before merging (the github skill's `head-status.sh`):

1. CI green on the head commit.
2. The layer's `sprint-contract.md` section is all checked from an evaluator `VERDICT: PASS`, and its `Cross-review:` line says converged, skipped for a `narrow` docs-only change, or unavailable and reported to the user.
3. Every review finding is fixed or dismissed with a reason in the PR comment; none is open or blocking.
4. Zero unresolved review threads.
5. Nothing the policy excludes (it may exclude, for example, migrations, auth or release PRs).

Squash-merge with `--match-head-commit <sha>` so a later push can't slip in, then move the tracker issues to done and run Phase 6. Any gate failing hands the merge back to the user with the reason. Without a policy, stop at the merge-ready report.

**Phase 6 — Archive**
1. Read `issues.md`.
2. Check each identifier's state: Linear via the `linear` skill (`get_issue`, `statusType`), GitHub via `gh issue view <n> --json state`.
3. If any issue is not closed (`completed`/`cancelled` on Linear, `CLOSED` on GitHub), surface the open identifiers and stop. Don't archive.
4. If all are closed, confirm the change folder is under `openspec/changes/archive/` (Phase 4 moved it in the PR). Only a change merged before that rule needs a separate archive commit; batch those into one chore PR.
5. Clean up from the main checkout: `wt remove <branch>`, which removes the worktree and deletes the branch only when its changes are already in the default branch (squash merges included). If it keeps the branch, report why instead of forcing it. Then `git push origin --delete <branch>`, and re-check status for anything now behind.

## Constraints

- Every invocation runs entry detection; never jump to a phase based on wording.
- Entry detection reads worktrees, branches, PRs and the change folder; never ask the user what phase they're in.
- One worktree per change. Never start Phase 0 for a change that already has a worktree, branch or PR, and never run a change's phases from the main checkout or another change's worktree.
- `<feat-name>` is the change folder name exactly: kebab-case with a type prefix (`feat-`, `fix-`, `chore-`; see `spec-writer`).
- Every subagent prompt starts with the Scope Brief verbatim. A subagent that reports a brief/job conflict gets an answer from the user, not from you.
- Test author, implementer and evaluator are separate spawns with no shared context. The evaluator never sees implementation narrative, and a fix pass always ends with a **fresh** evaluator.
- Subagents never commit, push or open PRs; the coordinator does, after checking each report.
- Phase 4 is only reached when the layer's `sprint-contract.md` section exists and every item is checked.
- Phase 4 always links the PR to its sub-issue (Linear comment, or `Closes #<n>` on GitHub); never skip it.
- Phase 6 archive is blocked while any sub-issue is open; no partial archive.
- **Real device state needs permission.** No subagent runs a step that changes real hardware or system state (writing to a device such as lighting, fans or a pump; a root-only command) unless the repository's `AGENTS.md` permits it for unattended runs. Otherwise ask the user before that step runs, and record the item in `sprint-contract.md` as a manual check, saying who ran it. Tell the evaluator in its prompt which such steps are permitted.

## Gotchas

- **The sprint contract cites runs, not memories.** Write it only from the evaluator's report, with the run or job ID behind each checked item. Evidence you supplied yourself (a rerun you triggered, a CI run ID) is labelled as yours. Timings from a different run are not evidence.
- **After any merge to `main`, merge `main` into every in-flight branch and push**, so each PR's CI tests what will actually merge. Land CI/workflow changes first; branches created before the workflow existed get no checks until then.
- **Squash merges break ancestry.** A branch built on top of another PR's branch hits add/add conflicts after that PR is squash-merged. Check that `main`'s copy equals the branch's base (`git show origin/main:<f>` vs `git show <base>:<f>`); if so, keep the branch's version.
- **Signing or push failures stop the run.** If a commit or push fails with a signing-agent or SSH-agent error, nothing after it may run: chain with `&&`, report, and ask the user to unlock. Never fall back to unsigned commits.
- **An implementer that didn't show red first** (tests failing before the fix) leaves you without red-to-green evidence. Ask the evaluator to prove it: run the new tests against the pre-fix code in a scratch worktree.

- **Codex reads `AGENTS.md` only**, not `CLAUDE.md` or `REVIEW.md`. In a repo with a `REVIEW.md`, the cross-review applies its rules only when `AGENTS.md` has a `## Code Review Rules` section pointing at it. If Codex flags something `REVIEW.md` explicitly allows, the pointer is missing: report that rather than applying the finding.
- **Never call `codex review --base`** for the cross-review: it refuses a prompt alongside `--base`, so it can't carry the brief and reviews work the change deliberately left out. `cross-review.sh` passes the range inside the prompt instead.

- A subagent's "tests pass" is a claim. Check its report names the command and shows the result; if it doesn't, the evaluator will find out the hard way.
- Evaluators that read `design.md` or code before writing the contract grade the code instead of the stories. The role file forbids it; if a report's contract items mirror implementation names rather than story language, rerun with a fresh evaluator.
- `INCOMPLETE` is a normal outcome, not a failure. Don't fake the missing condition (a seeded login, a stubbed device) to reach PASS; record what's NOT RUN in `sprint-contract.md`, file anything pre-existing that blocked it as its own issue, push the branch, and stop.
- Build tools cache test results. An evaluator that reports "0 tests run" or an instant pass did not run anything; the role file tells it to force execution.

## Example

User says: "start work on feat-onboarding, just the empty state for now"

Entry detection: no change folder → Phase 0. The brief quotes the request verbatim, size signal `narrow`, out of scope "populated list and add-habit flow: later story group". `spec-writer` creates the folder; the brief is saved and its scope shown to the user.

Phase 1: `linear` → parent APP-12, sub-issues APP-13 (`:<layer-1>`), APP-14 (`:<layer-2>`).

Phase 2 (`:<layer-1>`): branch `feat/onboarding-empty-state`; test author writes two failing repository tests; implementer makes them pass and wires DI; both commits made.

Phase 3: a fresh evaluator derives four contract items from `specs/stories.md`, runs the tests, reports `VERDICT: PASS`. `sprint-contract.md` gets a `:<layer-1>` section, all checked.

Phase 4: `pr` opens the PR and the URL is commented on APP-13. The next invocation picks up `:<layer-2>`.
