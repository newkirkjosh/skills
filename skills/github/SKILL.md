---
name: github
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. GitHub service mechanics through gh and the REST and GraphQL APIs: issues, pull requests, checks and review threads with complete pagination, head-scoped evidence, bounded waits and writes verified by reading them back, plus the tested PR evidence helpers ship uses before a guarded merge."
license: MIT (PR evidence helper concepts adapted from fx/skills by Marian Rudzynski; see LICENSE.txt)
metadata:
  type: reference
  upstream: "https://github.com/fx/skills/tree/4b1010d/skills/github"
---

# GitHub

How to carry out a GitHub operation correctly. What to do (scope, issue hierarchy, review policy, when to merge) belongs to the workflow in charge (`dev`, `ship`) or the user's request, and to the repository's `AGENTS.md`; this skill never decides it.

**Explicit use only.** It runs the operation it was asked for, reads the result back and stops. It never starts `dev` or `ship`, never scaffolds a change folder or spec, and grants no merge permission. A standalone request ("edit issue #12's title", "list the open threads on #34") produces that operation and its readback, nothing more.

## Rules

- **Docs, not memory.** Confirm commands, flags and fields from installed `gh <command> --help`, `gh api` and the GitHub REST and GraphQL docs before the first call. Fields and defaults change.
- **Outward writes need authority.** Creating or editing issues, PRs, labels and comments, replying to or resolving threads, and merging are visible to others. Do them when the user asked for exactly that action or the invoking workflow's authority covers it; otherwise confirm first. Before anything becomes public, check the repository's visibility (`gh repo view --json visibility`).
- **Bodies through files.** Pass every multiline body with `--body-file` (or `-F body=@file` to `gh api`), so Markdown and backticks survive quoting.
- **Read every write back.** After an edit, state change, label, reply or resolve, read the object again and check the field you changed; a zero exit is not proof. Replying and resolving are separate writes; verify each.
- **Paginate to exhaustion.** REST lists page until a short page (`--paginate`, or `per_page` plus `page`); GraphQL connections follow `pageInfo.hasNextPage` and `endCursor`, and nested connections (a thread's comments) need their own pagination. A count that disagrees with `totalCount` or `total_count` is an incomplete read.
- **Unknown is not empty.** A failed, rate-limited or truncated read is unknown, never "no threads", "no checks" or "no reviews". An absent check or reviewer report is unknown, never not configured; only repository or service authority establishes that, and it is recorded with its source.
- **Evidence belongs to one head.** Every check, status and review result is about exactly one commit. Read the PR's `headRefOid` with the evidence and again before using it; a result for another SHA says nothing about the head.
- **Identity.** A reply goes out as the authenticated account (`gh api user --jq .login`). Bot threads (`author.__typename == "Bot"`, or a `[bot]` login) may be replied to and resolved under authority; human threads are left for their authors to resolve.
- **Tokens stay off argv.** `gh` reads its own credentials; a token for a raw call goes in a header from stdin or a file, never on the command line or in a log.
- **Bounded waits, no polling loops.** Use host-native monitoring when it exists; otherwise the waiters below, inside the caller's overall budget.

## References and helpers

- `references/pr-evidence.md`: the PR evidence contract and the read-only helpers in `scripts/` (`pr-status.sh`, `wait-for-ci.sh`, `wait-for-coderabbit.sh`): arguments, exit codes, policy file and what each result does and does not prove. Read before collecting merge evidence or waiting on CI or CodeRabbit.
- `references/pull-requests.md`: opening and updating a PR, posting a review result, and fetching, replying to and resolving hosted feedback. Read before any of those.
- `references/openspec-issues.md`: turning a change folder into a parent issue plus one sub-issue per layer, and the `issues.md` anchor. Read when `dev` reaches issue creation on a GitHub-tracked project.

Callers resolve these paths from this skill's real directory: resolve the loaded skill's symlink, never the project's working directory.

## Merging

The merge command is `gh pr merge <n> --squash --delete-branch --match-head-commit <sha>`, run right after a fresh `pr-status.sh` exit-0 report for that same `<sha>`, with no push in between: the head guard makes the merge fail if a commit slipped in. Squash only.

An explicitly authorized standalone merge ("merge #34") runs the same collection `ship` uses: the policy file verified against repository authority, then `pr-status.sh` for the current head. It reports every repository gate it holds no evidence for as missing (a required converged cross-review, an evaluator result, an unresolved thread) and merges only when the repository's Merge policy grants it and nothing is missing. In a repository whose Merge policy requires review evidence that only a ledger records, a bare merge request with no ledger therefore stops and points to `ship`.

## Gotchas

- A check name alone doesn't identify a required check: a same-named check from another app can't stand in for the configured one. `pr-status.sh` reports each check with its app; compare both with the repository's required checks.
- A PR with zero review threads can still carry findings in review bodies and issue comments. Read those too.
- `--delete-branch` can't delete a local branch checked out in a worktree; leave cleanup to `wt remove`.
- `Closes #<n>` in the PR body closes the issue on merge only when the PR targets the default branch.
