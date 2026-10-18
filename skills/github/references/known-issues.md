# Known issues

Commands that fail in non-obvious ways, each with the form that works. Add an entry whenever a `gh` call has to be corrected, using the template at the end.

## Body text

### Heredoc inside `--body` stays literal

**Wrong:** the inner substitution is never evaluated, so the PR body becomes the literal text `$(cat body.md)`.

```bash
gh pr edit <n> --body "$(cat <<'EOF'
$(cat body.md)
EOF
)"
```

**Right:**

```bash
gh pr edit <n> --body-file body.md
gh api repos/<owner>/<repo>/pulls/<n> -X PATCH -F body=@body.md
```

**Why:** a quoted heredoc delimiter disables expansion inside it.

## Pagination

### `--jq` with `--paginate` counts per page

**Wrong:** prints one number per page, not a total.

```bash
gh api --paginate repos/<owner>/<repo>/pulls/<n>/reviews --jq 'length'
```

**Right:**

```bash
gh api --paginate --slurp repos/<owner>/<repo>/pulls/<n>/reviews | jq '[.[][]] | length'
```

## CI

### The newest run is not the run for your push

**Wrong:** right after a push, `.[0]` is usually the previous commit's run.

```bash
gh run list --limit 1 --json databaseId -q '.[0].databaseId'
```

**Right:** filter on the commit, and wait for the run to appear: `bash scripts/wait-for-ci.sh "$(git rev-parse HEAD)"`.

### A new push cancels the previous commit's run

Workflows with `concurrency: cancel-in-progress` cancel the run on the superseded commit, so a waiter still watching that SHA reports a cancelled run as a failure. After pushing, stop the old waiter and wait on the new head; a `cancelled` conclusion on a superseded commit is not a CI failure.

### `gh pr checks` exits non-zero while checks are pending

It exits 8 for pending (`gh help exit-codes`), which is not "failed". Read the states (`gh pr checks <n> --json name,state,bucket`) or use `head-status.sh`.

## Review threads

### `gh pr review --comment` doesn't reply to a thread

It adds a new PR-level review. Reply or resolve through GraphQL (`addPullRequestReviewThreadReply`, `resolveReviewThread`); see `graphql.md`. Only touch threads the user asked you to settle.

## Repository settings

### Visibility change refused

`gh repo edit --visibility public` exits with an error until `--accept-visibility-change-consequences` is added. Treat the flag as the point to stop and confirm with the user.

## Template

````markdown
### <short description>

**Wrong:**
```bash
<failing command>
```

**Right:**
```bash
<working command>
```

**Why:** <root cause>
````
