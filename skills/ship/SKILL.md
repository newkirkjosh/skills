---
name: ship
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Takes finished work on a branch to a merged PR: one commit, one push, a bounded wait for CI on the head commit, one batched fix push per failure, a squash merge only when the repository's merge policy grants it, then the tracker update."
metadata:
  type: flexible
---

# Ship

The loop from "the work is done" to "merged and tracked", for a change that is not running under `dev` (which has its own Phase 4–6). **REQUIRED:** load the github skill for every `gh` step; this skill decides the order, github owns the mechanics.

**Explicit use only.** The workflow ends at its handoff: a merge, or a merge-ready report when the merge is the user's call. A later request on the same PR is handled directly.

## Steps

1. **Check the branch.** Never ship from the default branch; if the work is there, create a `<type>/<short-description>` branch first. Run the project's local checks (the completion criteria in its `AGENTS.md`). Red locally means fix first: a push that fails CI costs a full pipeline.
2. **Commit once.** `git status` and `git diff --stat`, then group the work into one commit (or one per logical change when they are truly separate). Conventional subject. Write the message to a file and `git commit -F <file>`: messages that mention commands can trip the user's command guard, and a file keeps the body intact.
3. **Push once and open the PR** if none exists, with the title and body conventions from `pr` and the repository's `AGENTS.md` (labels, project, `Closes` reference). Pushing and opening a PR are outward actions: confirm unless the user asked for exactly this.
4. **Wait for CI on the head commit** with the github skill's `wait-for-ci.sh <sha>` in the background. Not `gh pr checks --watch`: right after a push it can read the previous commit's checks or none, and it has no deadline. Don't push again while the run is going.
5. **On failure, batch the fix.** Read every failed job's log, fix all of them, rerun the local checks, then one follow-up commit and one push, and wait again (step 4). A failure that matches an already-filed flake may be rerun once (`gh run rerun --job`) instead; cite the issue. After the second red run on the same cause, stop and report it.
6. **Merge only under a Merge policy.** If the repository's `AGENTS.md` grants one, merge when every gate holds on the current head, re-checked right before merging with `head-status.sh`: CI green on that commit, zero unresolved review threads with `threads_truncated` false (a truncated count can hide an open thread), every review comment fixed or answered, and nothing the policy excludes. Then `gh pr merge <n> --squash --delete-branch --match-head-commit <sha>`. Without a policy, or with any gate failing, stop at a merge-ready report with the reason.
7. **Update the tracker.** Linear: comment the PR URL and move the issue to done after merge, or to the review state when stopping at the report (the `linear` skill). GitHub: `Closes #<n>` closes it; move the board item as `AGENTS.md` says (the github skill's projects reference). Read the issue back to confirm.
8. **Report** the PR URL, the merge commit or the reason it isn't merged, and the tracker state.

## Gotchas

- Each extra push to a branch with `cancel-in-progress` CI throws away the running pipeline. Pushing a "quick fix" while CI runs has cost whole slow runs; local checks first, then one push.
- A green run on an earlier commit says nothing about the head. Re-check right before merging; `--match-head-commit` makes the merge fail if a push slipped in.
- Merge commits and rebase merges are never used; squash only.
- When the branch lives in a worktree, `--delete-branch` can't delete the local branch. Clean up with `wt remove <branch>` from the main checkout, which deletes it only once its changes are in the default branch; never force-delete it.
