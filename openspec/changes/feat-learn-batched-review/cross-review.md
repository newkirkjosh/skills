# Cross-review: feat-learn-batched-review

Reviewer: Codex (read-only), 5 passes against `origin/main`.

| Pass | Head | Material findings |
|---|---|---|
| 1 | 14d4225 | 5: inbox guard for a not-yet-created directory, record writes before approval, shipped tied to a merged PR, review skipping catalog resolution, no closure for a fix already shipped |
| 2 | a5923dc | 2: a deleted versus unreadable worktree was ambiguous, outside-catalog fixes never reconciled |
| 3 | d5f42cd | 2: removal-only fixes could not prove shipped, a closed PR with a live worktree matched two rules |
| 4 | d2afe4a | 2: an open PR versus a stale worktree matched two rules, a worktree-only record lost a later PR |
| 5 | 793fb5c | none |

All findings were fixed on this branch and verified by the next pass and a fresh evaluator.

Final pass output:

> No material blockers. Both documents make the PR decisive when one exists and require repository and branch information so a later review can find a PR opened after the Applied record was written.
