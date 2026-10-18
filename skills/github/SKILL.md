---
name: github
description: "How to drive GitHub through the gh CLI and the REST and GraphQL APIs without the mistakes agents make: finding current commands and fields from the docs instead of memory, scoping CI and reviews to the PR's head commit, bounded CI waits, paginating correctly, keeping tokens off the command line, and checking visibility before anything goes public. Use for any GitHub operation — PRs, checks, workflow runs, reviews and threads, issues, projects, labels, releases, repo settings, tokens — and before another skill's GitHub step, even when the user only says \"is CI green\", \"open a PR\" or \"make the repo public\"."
license: MIT (adapted from fx/skills by Marian Rudzynski; see LICENSE.txt)
metadata:
  upstream: "https://github.com/fx/skills/tree/4b1010d/skills/github"
---

# GitHub

The mechanics of operating GitHub. Conventions for titles, bodies, branches, labels and merge strategy belong to the workflow skill in charge (pr-workflow, github-issue, github-project) and the project's `AGENTS.md`; this skill says how to carry them out correctly.

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
- **Paginate all of it.** With `--paginate`, `--jq` runs once per page, so counts and `length` come out per page. Use `--paginate --slurp` and do the math in `jq` afterwards.
- **Bodies come from files.** `--body-file` or `-F body=@file`. Inline `--body "$(…)"` with heredocs mangles text and substitutions.
- **Tokens never touch argv.** `gh` reads `GH_TOKEN` from the environment; fill it from the secret store (`GH_TOKEN="$(<secret read>)" gh api user`). To test a raw token, send the header through `curl -K -` on stdin. A `401` means the token is dead.
- **Visibility before publishing.** `gh repo view --json visibility` before a push or commit to an unfamiliar repo. On a public repo, everything committed is published.
- **Outward actions need approval.** Pushing, opening or merging PRs, commenting, editing settings, changing visibility, deleting branches or releases: confirm first unless the user already asked for that exact action.
- **Verify every write.** Read the object back (`gh pr view <n> --json title,body,labels`) after creating or editing it.

## Scripts

- `bash scripts/head-status.sh <pr> [owner/repo]`: head SHA, check rollup for that commit, reviews on it versus older commits, unresolved thread count, as JSON.
- `bash scripts/wait-for-ci.sh <sha> [timeout-min] [owner/repo]`: waits for every workflow run on that commit. Exits 0 all passed, 1 any failed, 3 timed out, 4 no run appeared.
- `bash scripts/check-body-wrap.sh < body.md`: exits 1 when a PR or issue body's prose is hard-wrapped.
- `bash scripts/test-scripts.sh`: offline tests for all three. Run after changing any of them.

## References

- `references/known-issues.md`: commands that fail in non-obvious ways, with the working form. Read before an unfamiliar operation, and add to it whenever a `gh` call needs correcting.
- `references/graphql.md`: review threads, PR status, projects, pagination. Read when REST or `gh` subcommands don't cover the data.

## Gotchas

- `gh repo edit --visibility` refuses without `--accept-visibility-change-consequences`. Making a repo public is effectively irreversible for anything already cloned or cached; check history for secrets and private terms first.
- `gh pr create --project` and `gh project` need the `project` token scope: `gh auth refresh -s project`.
- `gh run list` right after `git push` returns the previous run. Filter by `headSha` (or `--commit`), never take `.[0]`.
- `gh run watch --exit-status` only works on a run that exists; it can't wait for one to appear.
- PR and issue bodies are rendered markdown: write one line per paragraph. Commit bodies are plain text: wrap at about 72 columns.
- `#<n>` in a commit subject or squash-merge title auto-links issue or PR `n` forever. Use it only for a real reference.
