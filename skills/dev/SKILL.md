---
name: dev
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Orchestrates one change from approved job stories to a merged PR and archived change folder: detects existing state and enters at the right phase, then sequences scope brief, spec-writer, the tracker, test author and implementer subagents, an isolated evaluator, a cross-model review (Codex or Claude, whichever did not write it) and the archive move, then completes it (pull request, hosted review, CI and the merge gates) and stops at a merge-ready PR; after a merge it closes out the tracker and cleans up."
license: MIT (Scope Brief and head discipline adapted from fx/skills by Marian Rudzynski; see LICENSE.txt)
metadata:
  type: flexible
  upstream: "https://github.com/fx/skills/tree/4b1010d/skills/dev"
---

# Dev

## When to Use

**Invocation.** The user names this skill with a feat-name, in any wording. These three are equivalent, and all re-run entry detection from scratch:
- "use dev to start work on `<feat-name>`"
- "`/dev` what's next for `<feat-name>`"
- "dev: open a PR for `<feat-name>`"

Without the skill's name, none of them starts it (Invocation boundary).

All three behave identically: entry detection runs first and decides the phase, whatever the wording. "Open a PR for feat-X" does not skip to Phase 5; it may enter Phase 3 if `sprint-contract.md` is absent or has unchecked items.

## Invocation boundary

- **Start only on an explicit invocation**: the user names `dev` (`/dev`, "use dev for `<feat-name>`"), or `team` runs it for one change. Only the user or `team` starts it. Never load it because a request involves coding, implementation, GitHub, planning, review, or a phrase that resembles one of its phases.
- **Its authority ends at its handoff**: the Phase 5 report (merge-ready or blocked), the Phase 6 report after a merge, or a stop for the user. Later messages are standalone requests unless the user invokes `dev` again; they don't inherit its orchestration.
- **Incidental requests are not phases.** A status question, a branch sync, a PR metadata edit or an explicitly authorized merge is handled directly when it needs no substantive implementation judgment.
- **`dev` never merges.** After the handoff, "merge it" is a standalone request: re-check the live gates (a fresh `pr-status.sh` report on the head and every gate in step 6 of `references/completion.md`) and merge directly in the same session with `--match-head-commit`. Don't re-invoke `dev`, load other skills for it or spawn a merge subagent. `team` is the only workflow that merges by itself, after re-checking every gate.
- **The user may narrow, waive or stop a procedural pass** (skip a re-review, stop after Phase 3). Correctness, security, privacy and merge-gate requirements still hold, but `dev`'s orchestration never outranks a direct user instruction.
- **Work outside `dev`** is a spike or proof of concept the user drives by hand, with no completion workflow.
- **Under `team`**, the `dev` coordinator is a subagent of the `team` session and holds `dev`'s full authority for its change (commits, pushes, the PR, hosted-review fixes), and none to merge. Each later message from `team` is an explicit re-invocation carrying an invocation number; end every final message with the `TEAM:` line it asked for, ending `#<i>`.

## Roles

You are the **coordinator**. You own the Scope Brief, branches, commits, `sprint-contract.md`, the tracker mapping, the archive move and every handoff to the user. Completion (the PR, hosted review, CI, the merge gates and every tracker write after the PR exists) is Phase 5, in this same session, following `references/completion.md`. You delegate exactly three jobs, each to its own general-purpose subagent that reads a role file from this skill's `references/` directory:

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

**Budget.** Each spawn costs roughly 50–80k tokens, and the user's plan has a session limit that a long run can hit. Match the tier to the job: `small` for narrow or mechanical evaluations and doc fixes, `medium` for test authoring, implementation and judgment-heavy evaluation. Keep at most three agents in flight. Reviews go to the other model (Phase 4), not to more Claude agents; an unavailable required reviewer hands the merge to the user.

## Scope Brief

Read `references/scope-brief.md` before Phase 0. It defines the brief, its fields, and how it travels. Every subagent prompt and every review request in this lifecycle carries the brief verbatim; that is how "just", "only" and the implied neighbouring updates survive past the first handoff.

## Worktrees

**One change, one worktree, for its whole life,** managed with worktrunk (`wt`; current commands from `wt <command> --help` and https://worktrunk.dev/llms.txt). `wt switch --create <branch> --no-cd` creates it where the user's worktrunk config puts worktrees, before Phase 0 writes anything; find its path with `wt list --format=json | jq -r '.items[] | select(.branch=="<branch>") | .worktree.path'`. Every phase, subagent and command for that change runs from that path. The main checkout stays on the default branch and clean, so other changes can start beside it.

- **Layer branches.** The first layer (in `tasks.md` order) uses the branch Phase 0 creates: `<feat-name>` with its type prefix's hyphen as a slash (`feat-onboarding` → `feat/onboarding`). Each later layer uses that branch plus `-<layer>`, with `<layer>` as `issues.md` writes it (`feat/onboarding-<layer-2>`), in its own worktree. Layers that share one issue use the first one's branch. "The layer's branch" below always means this name, never whichever branch of the change happens to exist.
- **Parallel work** is one coordinator session per change, each started in its own worktree. A single session juggling several changes runs out of context.
- **Status** comes from `wt list --format=json` (per item: `branch`, `worktree.path`, `worktree.changes`, `default_branch.ahead/behind`, `head.committed_at`) plus the PR state from `gh pr view`. Check it at the start of every invocation and after every merge: a merged PR, run entry detection for that change (Phase 6 closes out the tracker and cleans up); an open PR behind the default branch, merge it in and push (under `team`, only when `team` asks: Requested sync, in Entry detection); no PR and no commit for two weeks, report it as stale and never delete it; uncommitted changes, leave it alone.
- **Shared resources** that only one run can use at a time (an emulator, a device, a fixed local port) are taken with `flock`, on a lock file in the repository's common git dir, which every worktree shares: `mkdir -p "$(git rev-parse --path-format=absolute --git-common-dir)/locks"`, then `flock "$(git rev-parse --path-format=absolute --git-common-dir)/locks/<resource>" <command>`. Hold it for the whole check that needs the resource, and pass the same rule to evaluators.
- **Builds** in separate worktrees have separate outputs and can run side by side; the lock is only for what they truly share.

## Entry detection

**Incomplete sync first.** Before anything else, including finding or recreating the worktree, and whatever the prompt asks: if the sync journal (`<common git dir>/team/changes/<feat-name>/sync-progress`, outside the worktree so it never dirties it) has a record without its `handed-off` line, or a merge is in progress in the change's worktree if it still exists (`git rev-parse -q --verify MERGE_HEAD`; never recreate a worktree to check), change nothing and end `TEAM: BLOCKED sync interrupted` (outside `team`, report it to the user and stop).

First find the change: its layer branches in `wt list --format=json`, then an open PR for it, then `openspec/changes/archive/<feat-name>/` on the default branch. Read the change folder from wherever it is found and continue there; if the worktree is gone but the branch exists, `wt switch <branch> --no-cd` recreates it (for a requested sync, only after the checks below pass). Only when it is found nowhere is it a new change.

**Requested re-evaluation.** When a `team` re-invocation asks to re-evaluate the layer at a named head, and that is the layer branch's head, go to Phase 3 with a fresh evaluator, whatever the contract and ledger say. The layer's open PR is reused for any PR-only evidence: never open another or change its draft state. A different head ends `TEAM: BLOCKED head mismatch`.

**Requested sync next.** When a `team` re-invocation says the default branch moved and names the PR, the expected head and the default SHA, handle it here, before the table below. Read the PR from GitHub: it must still be open and target this repository's default branch. Check the PR head and the local branch head (`git rev-parse refs/heads/<branch>`, which needs no worktree) both equal the expected head. Only then recreate a missing worktree, and check the worktree and index are clean (`git status --porcelain` empty). Any failure ends `TEAM: BLOCKED sync interrupted` or `TEAM: BLOCKED sync needs a clean worktree`, changing nothing. Record the three SHAs in the sync journal and merge exactly that default SHA; any conflict or other merge failure: `git merge --abort` if a merge is in progress, and end `TEAM: BLOCKED sync failed: <git's message>`. A clean merge is classified (Phase 4 step 5, with the review range in `references/completion.md`): `behavioral: yes` runs Phase 4's re-evaluation and a delta review, except that evidence only a pushed PR can produce ends `TEAM: BLOCKED sync needs PR evidence`. That stop holds for this whole invocation, Phase 5's fix loop included: never push a candidate just to get PR-only evaluation evidence during a requested sync. Then run Phase 5 as usual: its local checks, fresh review for the new merge base and single push publish the sync; Phase 5's later review and CI fix pushes are part of the same sync. Just before ending with `TEAM: MERGE-READY`, write `handed-off <head sha>` to the sync journal; `team` retires the journal after verifying that head.

If the change folder has a `handoff.md`, read it first: it records where a stopped run left off. Resume from it, and delete it in the commit that gets past the point it describes.

Then, checked in order, first match wins. Work proceeds one layer at a time, in `tasks.md` order; "the layer" below is the first layer whose sub-issue in `issues.md` is still open. When several layers map to the **same** issue (a small fix tracked by one issue), treat them as one unit: one branch, one test author/implementer/evaluator pass covering all of them, one PR.

| Existing state | Entry point |
|---|---|
| No change folder, active or archived (found nowhere above) | Phase 0: Scope Brief and OpenSpec setup |
| Worktree, branch or PR exists, but no change folder | Reconstruct the change folder there from its commits (brief, proposal, stories, design note, tasks), commit it, then re-run detection |
| Change folder exists, no `scope-brief.md` | Reconstruct the brief (see `references/scope-brief.md`), then re-run detection |
| Change folder exists, no `issues.md` | Phase 1: Issue creation |
| A branch of this change (in `wt list` until Phase 6 removes it) has a merged PR, whatever its issue's state (`Closes #<n>` closes a GitHub issue at merge) | Phase 6 for that branch's own layer, not "the layer" above: its close-out (step 0) touches only the issue that PR closes or links, so it never touches a layer still open, and reads each write back, so a repeat is harmless |
| All sub-issues in `issues.md` are closed | Phase 6: Cleanup |
| `issues.md` exists, and the layer's branch is missing or has no commit outside `openspec/changes/` (`git diff --stat origin/<default>...<branch> -- . ':!openspec/changes'` is empty: the change folder, contract and review record live there, so a spec edit elsewhere under `openspec/` still counts as implementation) | Phase 2: Implementation |
| No `sprint-contract.md` section for the layer, with or without a PR (draft or ready) | Phase 3: Evaluation (start) |
| No PR or a draft PR, the layer's contract has unchecked items | Phase 3: Evaluation (fix pass, or a fresh evaluator once what was `INCOMPLETE` is available) |
| The layer's contract is all checked, but its `Evaluated at:` SHA is missing or isn't an ancestor of the branch head | Phase 3: Evaluation (a fresh evaluator) |
| The layer's contract is all checked, no `Cross-review:` line, with or without a PR (draft or ready) | Phase 4: Cross-model review; Phase 5 marks a draft ready |
| No open PR, the layer's contract is all checked and has its `Cross-review:` line | Phase 4 steps 4–5 (archive move if not yet made, classify), then Phase 5 |
| Ready PR open, the layer's contract has unchecked items (a re-evaluation run that stopped, or a fail on a PR opened outside `dev`) | Phase 5: resume its re-evaluation loop under Phase 3 steps 5–7 (a fix pass, or a fresh evaluator once what was `INCOMPLETE` is available) |
| PR open (draft or ready), the layer's contract all checked with its `Cross-review:` line, and the change folder not yet under `openspec/changes/archive/`, or a commit in the review range (`references/completion.md`, Caller gate) without a `behavioral` record or recorded `behavioral: yes` | Phase 4 steps 4–5 (archive move, classify, re-evaluate), then Phase 5 |
| PR open for the layer (none of the above: contract checked and reviewed, folder archived, every later commit `behavioral: no`) | Phase 5: Completion |

## Phases

**Phase 0 — Scope Brief and OpenSpec setup**
0. Create the worktree on the first layer's branch (Layer branches, above): `wt switch --create <branch> --no-cd` (no issue number is needed; if `wt list` already shows the branch, from an interrupted run, use its worktree instead), and work from its path from here on.
1. Build the Scope Brief from the user's own words. Grep for every file the change will touch to fill **Also update**.
2. Classify the **Path** (`references/scope-brief.md`). A `spike` leaves the lifecycle here: answer it and stop. Otherwise invoke the `spec-writer` skill, passing the brief: a `bounded` change gets a short design note, an `architectural` one a full `arch-review`, and the user approves an architectural design before Phase 1.
3. Save the brief as `openspec/changes/<feat-name>/scope-brief.md`.
4. Show the user the **Path** with its reason, and the **Interpreted scope**, **Also update** and **Explicitly out of scope** fields, in a few lines, so a wrong reading is caught now.

**Phase 1 — Issue creation**
Invoke `linear` (default tracker) for its OpenSpec-to-issues workflow. Output: `issues.md` with the parent identifier and one sub-issue per layer. If the work already has an issue (the user named one, or it was filed earlier), don't create new ones: write `issues.md` mapping each layer to that issue, add it to the board, and comment there if the diagnosis changed.

*GitHub alternate:* for a GitHub-tracked project, invoke `github` and follow its `openspec-issues.md` reference instead, and place the issues on the board the repository's `AGENTS.md` names. They write `issues.md` with GitHub issue numbers; the rest of the pipeline is unchanged.

**Phase 2 — Implementation**
If the user says they will implement it themselves, surface the layer's `tasks.md` section, say "When the tasks are done, invoke `dev` again for `<feat-name>`", and stop.

Otherwise, for the layer:
1. For a later layer, the previous layer has merged: from the main checkout, `git fetch origin`, then `wt switch --create <the layer's branch> --base origin/<default> --no-cd`, and work from its path. If `wt list` already shows that branch (a run stopped right after creating it), use its worktree instead of creating it again. It starts from the default branch, which already holds the archived change folder. For the first layer, commit the change folder in its worktree first (`docs(openspec): …`). On a resumed run, skip any step whose commit is already on the branch.
2. Spawn the **test author**, unless checks that fail for this exact bug already exist (a broken build, an existing test that fails today). Then skip it, name those checks in the implementer's prompt and in `sprint-contract.md`, and say why.
   Otherwise spawn it. Check its report: every story has a test or a named manual check, and every test fails for the stated reason. Commit the tests (`test(<scope>): …`).
3. Spawn the **implementer** with the test author's report. Check its report: tests and build clean, every **Also update** item accounted for, nothing outside the brief. Commit (`feat(<scope>): …`). If it reports a wrong test, surface its evidence to the user and stop.
4. Continue to Phase 3 in the same run.

**Phase 3 — Evaluation**
1. If the change's evidence only exists on a PR (a CI workflow that triggers on `pull_request`) and the layer already has an open PR, keep it and its draft state. Outside a requested sync, push the evaluated head if the PR isn't on it, read the PR head back, wait for that head's run and give the evaluator the PR number; repeat this before each evaluator whose head changed. With no PR yet, push and open it as a **draft** first through the `github` skill's pull-request reference (title, labels, project and `Closes` reference from the repository's `AGENTS.md` and `issues.md`, as Phase 5 does), wait for its run, and give the evaluator the PR number as environment. Completion is not merge-ready while it is a draft; Phase 5 marks it ready after the converged review.
2. Export what it evaluates, without history: `bash scripts/eval-export.sh <worktree> HEAD "$(git merge-base origin/<default> HEAD)" <scratch>/eval-<feat-name>-<short-sha>`, to a scratch directory **outside** the repository. It writes `head/` (the change) and `base/` (the default branch it started from), with no `.git`, so commit messages and the diff can't leak.
   Spawn the **evaluator** with only the brief, the layer, the two export paths and the change folder's path inside `head/`. Never pass implementation context: no diff, no summary, no "should pass because". Delete the export after writing the contract.
   **Named verification skill.** If the repository is one the user owns and its default branch's `AGENTS.md` (`base/AGENTS.md`, never the change's own copy, which the change may have edited) names a single-task skill for verifying the app (`verify-change`), include its bare name and the instruction to read and follow it in the evaluator's prompt, together with the repository's verification facts. Never pass a workflow (`dev`, `team`) or a skill the catalog doesn't have. This is environment context, not implementation context.
   **GUI checks.** If the layer has any (a desktop window, a screenshot, simulated input) and the user's global instructions give an isolated display for GUI apps on this machine (an off-screen display, say), copy that recipe into the evaluator's prompt verbatim, and tell it to set `DISPLAY` explicitly on every launch, screenshot and input command, using only input tools scoped to that display (`xdotool`, never a device-level one like `ydotool`, which reaches the live desktop whatever `DISPLAY` says). Subagents don't reliably see those instructions, and an evaluator without the recipe returns `INCOMPLETE`. With no isolated display, GUI checks stay manual: the evaluator reports them `INCOMPLETE` rather than touching the live desktop.
   **Time budget.** Before spawning, estimate the run from what it must do (the last test run's duration, an emulator boot, a CI wait). If it will likely take more than about 10 minutes, tell the user the estimate and what dominates it, then run the evaluator in the background. The evaluator sends a progress line after each step; if 30 minutes pass with no new line, stop it and every process it started (an emulator, a daemon), delete its export, and write `handoff.md` inside the change folder wherever it is now (`openspec/changes/archive/<feat-name>/` once archived; never create the active path for it): the layer, the last progress line and its time, what was running, what is already known, and the next command to resume with. Commit it with the change folder, tell the user, and stop. Never restart the same evaluation in the same run.
3. Write the layer's section of `sprint-contract.md` from its report (template in the `spec-writer` skill), checking only PASS items, with an `Evaluated at: <full-sha>` line naming the commit the evaluator saw. Every fresh evaluator rewrites that line. When the section is all checked, that SHA is the **evaluator PASS SHA** everything below and Phase 5's caller gate measure from, so a resumed run reads it here rather than remembering it. Commit it with the change folder (`docs(openspec): …`).
4. On `VERDICT: PASS`, go to Phase 4.
5. On `VERDICT: FAIL`, run **one** fix pass: GAP items to a fresh test author, then FAIL items (and the new tests) to a fresh implementer, each given only those items. Commit, then spawn a **fresh** evaluator and rewrite the section from its report.
6. On `INCOMPLETE`, first check whether you can provide what's missing on this machine (boot an existing emulator AVD headless, start a local daemon or database), recording its PID so you can stop only the process you started. Evaluators can message you to change shared environment mid-run (e.g. "stop the backend now"); do it, then reply with what changed. Never hand an evaluator input control of the user's live desktop (`xdotool`, `ydotool`, or a real `DISPLAY`): they may be using it. GUI checks run the way the user's global instructions say, handed over as in step 2. If so, spawn a **fresh** evaluator and tell it only what's now available. Stop it afterwards.
7. If it still fails after the fix pass, or is still `INCOMPLETE`, surface the open items with the evaluator's evidence and stop. Don't loop further. For `INCOMPLETE`, name what's needed (a device, a running daemon) so the user can provide it and re-invoke.

**Phase 4 — Cross-model review and archive move**

Run the review with the `cross-review` skill in change mode, before the PR is opened or a Phase 3 draft is marked ready, keeping its review ledger for this branch through completion.
1. **Review.** Skip it only for a `narrow` docs-only change: record `Cross-review: skipped (narrow docs-only)` as in step 3, tell the user, and go on. Otherwise give `cross-review` the Scope Brief verbatim as the scope, the worktree and `origin/<default>`, and the ledger.
2. **Triage and fix.** In-scope blocking findings go to a fresh implementer as a fix list, all of them in one pass; out-of-scope ones are recorded with the exclusion that covers them. Commit each fix pass (`fix(<scope>): …`) before the next review, and record its `behavioral: yes|no` classification in the ledger. A behavior-changing fix re-runs Phase 3 with a fresh evaluator before the next pass, which makes a new evaluator PASS SHA. Converge as `cross-review` describes (at most three passes, then surface the remaining blockers and stop for the user). An unavailable reviewer is recorded as unavailable; continue only to the PR handoff, since an unavailable required review blocks autonomous merge.
3. **Record** it in the layer's `sprint-contract.md` section: `Cross-review: <reviewer>, <passes> pass(es), converged at <short-sha>` (or `Cross-review: unavailable: <reason>`, or the skip from step 1), and save the final pass's output as `cross-review.md` in the change folder, to post on the PR; commit both with the change folder.
4. **Archive move.** Once `sprint-contract.md` is final and review is done, make the archive move the candidate head's last commit: `git mv openspec/changes/<feat-name> openspec/changes/archive/<feat-name>`. Merging then closes the issue (`Closes #<n>`) and archives the change together, with no follow-up PR to `main`. If the folder is already under `openspec/changes/archive/<feat-name>/` (an earlier layer's PR archived it, or this layer already made the move), there is nothing to move: skip this step and keep using the archived path wherever this file names the change folder.
5. **Classify** every commit in the review range (`references/completion.md`, Caller gate) that has no record yet (the contract, `cross-review.md` and archive commits included) as `behavioral: yes|no` in the ledger, by its actual effect. If any commit in that range is `behavioral: yes`, Phase 5's caller gate would refuse it: run a **fresh** evaluator as in Phase 3 (its PASS makes a new evaluator SHA), update the contract in place, review the delta with `cross-review`, refresh the `Cross-review:` line and `cross-review.md` from that review, and classify again from the new SHA. Go to Phase 5 only when every commit in the range is `behavioral: no`.

**Phase 5 — Completion**

Read `references/completion.md` and follow it: local review coverage, publish and link the tracker, settle hosted review, CI last, then verify every gate on the head. It ends in one of:

- `merge-ready`: report the PR URL, head SHA, review coverage, ledger location, tracker state and who may merge, and stop. Under `team`, end with the `TEAM:` line it asked for, including the head SHA and ledger location.
- `blocked`: report the failed or missing gates and stop.
- **Re-evaluation**, when a hosted or CI fix changes behavior: send the fix list to a fresh implementer, commit, then run a **fresh** evaluator as in Phase 3 and update the contract in place at `openspec/changes/archive/<feat-name>/sprint-contract.md` (the folder never moves back). Review the delta with `cross-review`, refresh the `Cross-review:` line and `cross-review.md` from it, classify the new commits, and resume completion at its step 2, which pushes once. If that evaluator fails or is `INCOMPLETE`, Phase 3 steps 5–7 apply as written: one fix pass, then surface the open items and stop. When the fresh evaluation needs evidence only a PR produces, a requested sync ends `TEAM: BLOCKED sync needs PR evidence` without pushing. Otherwise push the candidate to get it (keeping a draft a draft) and report completion as not merge-ready; additional evidence-driven pushes stay within the same fix pass. Resume completion once evaluation and review cover the resulting head.

**Phase 6 — Cleanup**

Reached from entry detection, when a branch of this change has a merged PR or every sub-issue is closed:
0. **Close-out.** For each merged branch whose layer isn't closed out yet, confirm `MERGED` with `gh pr view <n> --json state,mergeCommit` and run Close-out in `references/completion.md` for that layer's own issue only.
1. Read `issues.md`, and check each identifier's state: Linear via the `linear` skill (`get_issue`, `statusType`), GitHub via `gh issue view <n> --json state`. Read only; step 0 wrote them.
2. Confirm the change folder is under `openspec/changes/archive/` on the default branch (Phase 4 moved it in the PR). If it isn't, report it and stop before any cleanup or re-detection: detection would not find the change and would treat it as new. There is no post-merge archive PR.
3. If any layer's issue (every `issues.md` line except the `parent:` or `epic:` one, which close-out never closes) is not closed (`completed`/`cancelled` on Linear, `CLOSED` on GitHub): if the merged layer's own issue is closed, clean up that one branch the way step 4 does (no other layer's branch: another merged layer whose issue is still open keeps its branch, so detection can still select it for close-out) and re-run entry detection, which moves on to the next layer. If that cleanup kept the branch, stop and report it instead: detection would select the same merged branch again. Otherwise surface the open identifiers and stop.
4. Clean up from the main checkout, for every layer branch of this change (named as in Layer branches) still in `wt list` whose PR is merged (one an earlier run kept is cleaned up here): `wt remove <branch>`, which removes the worktree and deletes the branch only when its changes are already in the default branch (squash merges included). If it keeps a branch, report why instead of forcing it. For each removed branch, delete the remote branch only at its PR's merged head: read that from `gh pr view <branch> --json state,headRefOid` (`state` must be `MERGED`), read the remote with `git ls-remote origin refs/heads/<branch>`, and run `git push origin --delete <branch>` only when the two SHAs are equal. Empty `ls-remote` output means the merge already deleted it: nothing to do. A different SHA means the remote holds a commit that wasn't merged: keep the branch and report it. (Not `--force-with-lease`: guard hooks commonly block every force-push form.) Then re-check status for anything now behind.

## Constraints

- Every invocation runs entry detection; never jump to a phase based on wording.
- Entry detection reads worktrees, branches, PRs and the change folder; never ask the user what phase they're in.
- One worktree per change. Never start Phase 0 for a change that already has a worktree, branch or PR, and never run a change's phases from the main checkout or another change's worktree.
- `<feat-name>` is the change folder name exactly: kebab-case with a type prefix (`feat-`, `fix-`, `chore-`; see `spec-writer`).
- Every subagent prompt starts with the Scope Brief verbatim. A subagent that reports a brief/job conflict gets an answer from the user, not from you.
- Test author, implementer and evaluator are separate spawns with no shared context. The evaluator never sees implementation narrative, and a fix pass always ends with a **fresh** evaluator.
- Role subagents (test author, implementer, evaluator) never commit, push or open PRs; the coordinator does, after checking each report. A coordinator `team` started is not a role subagent.
- Phase 4 is only reached when the layer's `sprint-contract.md` section exists and every item is checked.
- Completion always links the PR to its sub-issue (completion step 3: Linear comment, or `Closes #<n>` on GitHub); never skip it.
- Final cleanup of the change is blocked while any sub-issue is open. Cleaning up one merged layer whose own issue is closed, then moving on to the next layer (Phase 6 step 3), is not.
- **Real device state needs permission.** No subagent runs a step that changes real hardware or system state (writing to a device such as lighting, fans or a pump; a root-only command) unless the repository's `AGENTS.md` permits it for unattended runs. Otherwise ask the user before that step runs, and record the item in `sprint-contract.md` as a manual check, saying who ran it. Tell the evaluator in its prompt which such steps are permitted.

## Gotchas

- **The sprint contract cites runs, not memories.** Write it only from the evaluator's report, with the run or job ID behind each checked item. Evidence you supplied yourself (a rerun you triggered, a CI run ID) is labelled as yours. Timings from a different run are not evidence.
- **Outside `team`, after any merge to `main`, merge `main` into every in-flight branch and push** (under `team`, a worker syncs only its own PR, and only when asked), so each PR's CI tests what will actually merge. Land CI/workflow changes first; branches created before the workflow existed get no checks until then.
- **Squash merges break ancestry.** A branch built on top of another PR's branch hits add/add conflicts after that PR is squash-merged. Check that `main`'s copy equals the branch's base (`git show origin/main:<f>` vs `git show <base>:<f>`); if so, keep the branch's version.
- **Signing or push failures stop the run.** If a commit or push fails with a signing-agent or SSH-agent error, nothing after it may run: chain with `&&`, report, and ask the user to unlock. Never fall back to unsigned commits.
- **An implementer that didn't show red first** (tests failing before the fix) leaves you without red-to-green evidence. Ask the evaluator to prove it: run the new tests against the pre-fix code in a scratch worktree.

- **A commit in the review range without a `behavioral` record leaves the merge gate unmet.** Record the contract, review-record and archive commits too, not only fixes.

- A subagent's "tests pass" is a claim. Check its report names the command and shows the result; if it doesn't, the evaluator will find out the hard way.
- Evaluators that read `design.md` or code before writing the contract grade the code instead of the stories. The role file forbids it; if a report's contract items mirror implementation names rather than story language, rerun with a fresh evaluator.
- `INCOMPLETE` is a normal outcome, not a failure. Don't fake the missing condition (a seeded login, a stubbed device) to reach PASS; record what's NOT RUN in `sprint-contract.md`, file anything pre-existing that blocked it as its own issue, push the branch, and stop.
- Build tools cache test results. An evaluator that reports "0 tests run" or an instant pass did not run anything; the role file tells it to force execution.

## Example

User says: "start work on feat-onboarding, just the empty state for now"

Entry detection: no change folder → Phase 0. The brief quotes the request verbatim, size signal `narrow`, out of scope "populated list and add-habit flow: later story group". `spec-writer` creates the folder; the brief is saved and its scope shown to the user.

Phase 1: `linear` → parent APP-12, sub-issues APP-13 (`:<layer-1>`), APP-14 (`:<layer-2>`).

Phase 2 (`:<layer-1>`): branch `feat/onboarding`; test author writes two failing repository tests; implementer makes them pass and wires DI; both commits made.

Phase 3: a fresh evaluator derives four contract items from `specs/stories.md`, runs the tests, reports `VERDICT: PASS`. `sprint-contract.md` gets a `:<layer-1>` section, all checked.

Phase 4: `cross-review` converges in one pass; the contract records it, and the archive move is the last commit.

Phase 5: `dev` opens the PR, comments its URL on APP-13, settles hosted review, waits for CI, verifies the gates and reports `merge-ready`. After the user merges, the next invocation closes out APP-13, cleans up and picks up `:<layer-2>`.
