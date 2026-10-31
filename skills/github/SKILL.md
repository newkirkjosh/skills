---
name: github
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Reference guidance for driving GitHub through the gh CLI and the REST and GraphQL APIs without the mistakes agents make: finding current commands and fields from the docs instead of memory, scoping CI and reviews to the PR's head commit, bounded CI waits, correct pagination, keeping tokens off the command line, project boards, and checking visibility before anything goes public."
license: MIT (adapted from fx/skills by Marian Rudzynski; see LICENSE.txt)
metadata:
  upstream: "https://github.com/fx/skills/tree/4b1010d/skills/github"
---

# GitHub

The mechanics of operating GitHub. Conventions for titles, bodies, branches, labels and merge strategy belong to the workflow skill in charge (`pr`, `gh-issues`) and the repository's `AGENTS.md`, which also says how its project board is organized; this skill says how to carry them out correctly.

## Docs first, never a pinned version

`gh` and the APIs change between releases. Look things up for the installed version instead of recalling flags or fields:

| Question | Source |
|---|---|
| Does a command or flag exist, what does it do | `gh <command> --help` |
| Which `--json` fields a command offers | `gh <command> --json` with no value lists them |
| Formatting output, `--jq`, templates | `gh help formatting` |
| Environment variables, auth | `gh help environment`, `gh auth status` |
| REST endpoints and payloads | https://docs.github.com/rest |
| GraphQL types and fields | https://docs.github.com/graphql, or introspect: `gh api graphql -f query='{ __type(name:"PullRequest") { fields { name } } }'` |

Don't write a `gh` or API version into notes, scripts or answers. When a flag is missing, check `--help`, then suggest upgrading `gh` rather than working around an old version.

## Rules

- **Scope CI and reviews to the head commit.** A green run or an approval on an older commit says nothing about the code being merged. Get `headRefOid` first, then filter checks, runs and reviews by it. `bash scripts/head-status.sh <pr>` does this in one call.
- **Wait boundedly, on the commit.** A run list read right after a push often doesn't show the new run yet. Use `bash scripts/wait-for-ci.sh <sha>` (with the host's background mechanism), which waits for runs on that SHA to appear and finish, with a deadline. Never `sleep` in a loop by hand.
- **One push per CI cycle.** Run the project's local checks before pushing, then push once and wait for the result. Never push to a branch whose run is still in progress: a workflow with `cancel-in-progress` cancels it, and a slow pipeline restarts from zero. The one exception is a push fixing blocking findings from a hosted review of that same head: the review already condemned it, so its CI result can't be merged on anyway (`ship`'s head-discipline reference). Batch every finding into that one push. When CI fails, fix every failure it reported, recheck locally, and send the fixes as one follow-up push.
- **Paginate all of it.** With `--paginate`, `--jq` runs once per page, so counts and `length` come out per page. Use `--paginate --slurp` and do the math in `jq` afterwards.
- **Bodies come from files.** `--body-file` or `-F body=@file`. Inline `--body "$(…)"` with heredocs mangles text and substitutions.
- **Tokens never touch argv.** `gh` reads `GH_TOKEN` from the environment; fill it from the secret store (`GH_TOKEN="$(<secret read>)" gh api user`). To test a raw token, send the header through `curl -K -` on stdin. A `401` means the token is dead.
- **Visibility before publishing.** `gh repo view --json visibility` before a push or commit to an unfamiliar repo. On a public repo, everything committed is published.
- **Outward actions need approval.** Pushing, opening or merging PRs, commenting, editing settings, changing visibility, deleting branches or releases: confirm first unless the user already asked for that exact action.
- **Verify every write.** Read the object back (`gh pr view <n> --json title,body,labels`) after creating or editing it.

## Scripts

- `bash scripts/head-status.sh <pr> [owner/repo]`: head SHA, check rollup for that commit, reviews on it versus older commits, unresolved thread count, as JSON.
- `bash scripts/wait-for-ci.sh <sha> [timeout-min] [owner/repo]`: waits for every workflow run on that commit. Exits 0 all passed, 1 any failed, 3 timed out, 4 no run appeared.
- `bash scripts/wait-for-coderabbit.sh <pr> [timeout-min] [owner/repo]`: waits for CodeRabbit's check on the PR's current head. Exits 0 passed, 1 failed, 3 timed out, 4 `NOT_CONFIGURED` (no CodeRabbit check appeared; terminal, record it and don't retry), 5 `RATE_LIMITED` (settle what it already posted and go on; never wait out the cooldown), 6 `HEAD_MOVED` (a push landed; rerun for the new head).
- `bash scripts/test-scripts.sh`: offline tests for all three. Run after changing any of them.

## References

- `references/known-issues.md`: commands that fail in non-obvious ways, with the working form. Read before an unfamiliar operation, and add to it whenever a `gh` call needs correcting.
- `references/graphql.md`: review threads, PR status, pagination. Read when REST or `gh` subcommands don't cover the data.
- `references/projects.md`: adding items to a project board and moving them between columns. Read when a repository's `AGENTS.md` names a project, or the user asks about a board.

## Gotchas

- `gh repo edit --visibility` refuses without `--accept-visibility-change-consequences`. Making a repo public is effectively irreversible for anything already cloned or cached; check history for secrets and private terms first.
- `gh pr create --project` and `gh project` need the `project` token scope: `gh auth refresh -s project`.
- `gh run list` right after `git push` returns the previous run. Filter by `headSha` (or `--commit`), never take `.[0]`.
- `gh run watch --exit-status` only works on a run that exists; it can't wait for one to appear.
- PR and issue bodies are rendered markdown: write one line per paragraph. Commit bodies are plain text: wrap at about 72 columns.
- `#<n>` in a commit subject or squash-merge title auto-links issue or PR `n` forever. Use it only for a real reference.
