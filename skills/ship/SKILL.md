---
name: ship
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Owns completion for finished work on a branch, standalone or called by dev: detects what is already done, gets the local cross-model review when needed, publishes or updates the PR, settles hosted feedback, waits for CI on the head commit, squash-merges only when fresh evidence holds and the repository's merge policy grants it, and does every tracker write after the PR exists."
license: MIT (head discipline adapted from fx/skills by Marian Rudzynski; see LICENSE.txt)
metadata:
  type: flexible
  upstream: "https://github.com/fx/skills/tree/4b1010d/skills/dev/references/head-discipline.md"
---

# Ship

The one completion procedure, from "the work is done" to "merged and tracked". The user runs it standalone on a finished branch; `dev` runs it for every change it coordinates (see Called by dev). The push and wait order (candidate head, SHA-scoped evidence, one fix pass per push, review before CI) is `references/head-discipline.md`; read it before step 3.

**Explicit use only.** The workflow ends at its handoff. Standalone, that is a merge or a merge-ready report when the merge is the user's call; a later request on the same PR is handled directly. Under `dev`, it is the return to `dev`.

**Sibling skills.** Resolve this skill's real directory (follow the loaded skill's symlink), and take its siblings from there: `../github` for PR, thread and evidence mechanics and the helpers in its `scripts/`, `../cross-review` for review and triage, `../dev/references/host-adapters.md` for waiting on hosts other than Claude Code and in headless runs. Never resolve them from the project's working directory or an installed link: a new skill may not be linked yet.

## Called by dev

`dev` calls ship in its own coordinator session, not as a second lifecycle owner, passing: the Scope Brief, the change and layer, the evaluator PASS SHA, the local cross-review result, the review ledger location and the `issues.md` mapping.

- **Authority.** Ship acts under `dev`'s invocation: pushing and opening or updating the PR need no further confirmation (under `team` too, which runs `dev`). Merging still needs the repository's Merge policy. Reading another skill never widens what the user asked for.
- **Caller gate.** The evaluator passed at SHA S, and every commit after S has a ledger record `behavioral: no` (review-continuity reference in `cross-review`). `dev` records its own contract, review-record and archive commits before handing over; ship records the fixes it commits. A missing record is unmet.
- **Fixes.** Ship classifies each in-scope completion fix `behavioral: yes|no` before committing it. A non-behavioral fix goes to a fresh implementer spawned from `../dev/references/implementer.md` with the Scope Brief and the fix list (the coordinator never patches code inline; `dev`'s few-lines-of-wording exception still applies), then local checks, a commit and its classification, a review of the committed delta, then one push. A behavior-changing fix is not pushed: return `re-evaluation-needed` with the fix list. `dev` re-implements, re-evaluates, updates the contract and reviews the delta, then calls ship again, which pushes once.
- **Archive.** The archive move is already in the candidate head as `dev`'s last commit. Re-evaluation edits `openspec/changes/archive/<feat-name>/sprint-contract.md` in place; the folder never moves back.
- **PR-only evidence.** If `dev` published a candidate (a draft, or an update to an open PR) to get evidence only a PR produces, completion is not merge-ready until evaluation and review cover the resulting head. `dev` owns that publication; ship resumes when `dev` returns with both. An already-ready PR is reported as not merge-ready, not converted to a draft.
- **Return** one of: `merged <merge-commit>`, `merge-ready <reason the merge is the user's>`, `re-evaluation-needed <fix list>`, `blocked <reason>`, with the head SHA, review coverage, ledger location and tracker state.

Standalone ship has no evaluator: it records each fix's classification but never reroutes on it, and its caller gate is the project's required checks plus any evidence the user supplied. It never invents a sprint contract.

## Steps

0. **Detect what is done.** Read the branch, its commits against the default branch, the PR (none, draft, open, merged) and its head, the ledger, and the review result and its SHA. Skip a step only when its recorded evidence is valid for this change and this head; unknown evidence is unmet. A PR already merged (a user hand-merge included) goes straight to step 8 once `gh pr view <n> --json state,mergeCommit` shows `MERGED`.
1. **Check the branch.** Never ship from the default branch; standalone, if the work is there, create a `<type>/<short-description>` branch first. Run the project's local checks (the completion criteria in its `AGENTS.md`). Red locally means fix first: a push that fails CI costs a full pipeline.
2. **Commit once** (standalone; under `dev` the candidate head is already committed). `git status` and `git diff --stat`, then group the work into one commit (or one per logical change when they are truly separate). Conventional subject. Write the message to a file and `git commit -F <file>`: messages that mention commands can trip the user's command guard, and a file keeps the body intact.
3. **Local review before pushing.** Use `cross-review` in change mode and keep its ledger through local and hosted review. Reuse a supplied result only when it converged at the candidate head, or every commit after its SHA is the caller's review-record or archive commit with a `behavioral: no` record; anything else after it gets a review of the committed delta. Reuse also needs the same base: the merge base the review covered (the script's `merge_base=`, recorded in the ledger) must equal the merge base of the head and the PR's current base (before a PR exists, the base step 4 will open it against; after opening, check the actual base again), so a retargeted PR (a stacked PR after its parent merges) gets a fresh review. A `Cross-review: skipped (narrow docs-only)` from `dev` counts as covered unless the repository requires a review. This reuse never overrides a repository requirement for review on the exact current head; when that requirement exists, review the candidate head including the record and archive commits. Standalone, run it with a brief of what the change is for and converge (at most three passes); commit fixes before reviewing them again, then push only the converged candidate. When the reviewer is unavailable, record it as unavailable: a Merge policy that requires a converged review can't be met, and the merge goes to the user.
4. **Publish.** Push once, then open the PR if none exists, or update it, using the `github` pull-request reference and the repository's `AGENTS.md` (labels, project, `Closes` reference). Standalone, pushing and opening a PR are outward actions: confirm before the first push unless the user asked for exactly this. Mark a draft ready only after the converged review. Post the review result (`cross-review.md` when the change folder has one). Then link the tracker: on GitHub the body's `Closes #<n>` links it and the board item moves as `AGENTS.md` says; on Linear, comment the PR URL on the mapped issue and move it to the team's review state (the `linear` skill). Read each write back.
5. **Settle hosted review first.** Fetch every thread, review body and comment for the head with `github`, triage them with `cross-review` in hosted triage mode, and classify each in-scope fix. Batch the fixes, rerun local checks, commit and classify them, review the committed delta, then push once (under `dev`, by the fix rule above). Reply with each disposition and its evidence, and resolve bot threads, through `github`. A fix push starts this step again. The order and why are in `references/head-discipline.md`.
6. **Wait for CI last**, on the head that survived review (the `github` evidence reference for the waiter). On failure, read every failed job's log, fix all of them as one classified batch, rerun local checks, commit and classify the batch, review the committed delta, then push once, and go back to step 5. A failure that matches an already-filed flake may be rerun once (`gh run rerun --job`) instead; cite the issue. After the second red run on the same cause, stop and report it.
7. **Merge only when every gate holds.** Re-check right before merging, with no push in between, on the current head:
   - the repository's `AGENTS.md` has a Merge policy that grants it, and the change touches nothing it excludes;
   - a fresh `pr-status.sh` exit-0 report for that SHA, with the policy file verified against repository authority, every required check matched and successful, and each configured reviewer completed on that SHA (a skipped, absent or rate-limited required reviewer is unmet, even beside a green check);
   - the local cross-review covers the candidate under step 3’s reuse rule, including any stricter repository requirement for exact-head coverage;
   - every finding fixed or dismissed with evidence, none open or blocking, and zero unresolved review threads after pagination to exhaustion;
   - the caller gate (above).

   Then `gh pr merge <n> --squash --delete-branch --match-head-commit <sha>`. If any technical gate fails or is unknown, return `blocked` with the failures or missing evidence. Return `merge-ready` only when every technical gate holds and the sole remaining condition is merge authority (no granting policy, an excluded path, or a user-reserved merge).
8. **Close out the tracker** after a verified merge: GitHub's `Closes #<n>` closes the issue, so read it back as `CLOSED` and move the board item as `AGENTS.md` says; on Linear, read the mapped issue's state and move it to the team's `completed` state only if it isn't there yet, so a re-entry never moves it twice. Stopping at the report leaves the issue in review from step 4.
9. **Report** (standalone) or **return** (under `dev`): the PR URL, the merge commit or the reason it isn't merged, the head SHA, review coverage, the ledger location and the tracker state.

## Gotchas

- **Headless runs wait in the foreground.** When nothing can wake you mid-run (`claude -p`, `codex exec`, a scheduled job), a backgrounded waiter's result never arrives: follow the headless rules in `dev`'s host adapters reference when waiting for checks, and never end the turn while one is outstanding.
- Each extra push to a branch with `cancel-in-progress` CI throws away the running pipeline. Pushing a "quick fix" while CI runs has cost whole slow runs; local checks first, then one push.
- A green run on an earlier commit says nothing about the head. Re-check right before merging; `--match-head-commit` makes the merge fail if a push slipped in.
- Merge commits and rebase merges are never used; squash only.
- When the branch lives in a worktree, `--delete-branch` can't delete the local branch. Clean up with `wt remove <branch>` from the main checkout, which deletes it only once its changes are in the default branch; never force-delete it.
