# Pull requests and hosted feedback

Read before opening or updating a PR, posting a review result, or fetching, replying to and resolving hosted feedback. This is mechanics; the caller (`dev`, or the user's request) decides what to post and when, and its authority covers only the PR in scope.

## Opening and updating

Use the repository's PR template, naming, labels and project conventions from its `AGENTS.md`. Otherwise use a conventional-commit title and a concise body explaining the problem, resulting behavior and actual validation. When a change folder exists, read issue identifiers from its `issues.md`; otherwise use the issue linked by the request or branch context. Include `Closes #<issue>` for GitHub issues. Pass the body with `--body-file`, then read the PR back (`gh pr view <n> --json title,body,labels,isDraft,headRefOid`) and check each field. Mark a draft ready with `gh pr ready <n>` and confirm `isDraft` is false.

Post a review result the caller supplies (for example a change folder's `cross-review.md`) with `gh pr comment <n> --body-file <file>`, and read the comment back.

## Fetching feedback

Read the PR head SHA first. Collect every review thread (GraphQL `reviewThreads`, with `isResolved`, `isOutdated`, path, line and the first comment's author and database ID), every review body with its `commit.oid`, every issue comment, and the checks, each paginated to exhaustion. `pr-status.sh` does this collection for one pinned head; prefer it to ad-hoc queries. A failed or incomplete read is unknown, never a clean verdict. Zero threads does not prove a completed review: body-only findings and comments count, and each configured reviewer must have reported on this head. Read the head again after collection; if it moved, the collection is stale.

Hand the findings, with their source URLs and the SHA they were made on, to the caller's triage (`cross-review`). Suggested patches are claims: the caller verifies each against current code before accepting it.

## Replying and resolving

Only after the caller has a disposition for a finding:

1. Reply on the thread with the disposition and its evidence: the fix commit SHA, or the reason for dismissal (`gh api` on the pull request review comment's replies endpoint, body from a file).
2. Resolve bot threads only (`resolveReviewThread` mutation with the thread ID). Leave human threads for their authors.
3. Re-read all threads, paginated, and confirm each reply exists and each intended resolution holds. A reply without resolution, or a resolution without a reply, is incomplete.

A body-only finding gets a PR comment with its disposition. Report the head, review coverage, unresolved feedback and pending checks at handoff.
