# GraphQL patterns

Use GraphQL when `gh` subcommands and REST don't expose the data in one call. Pass variables with `-F` (typed: numbers, booleans) or `-f` (strings) instead of splicing them into the query. Confirm field names by introspection when unsure:

```bash
gh api graphql -f query='{ __type(name:"PullRequestReviewThread") { fields { name } } }' --jq '.data.__type.fields[].name'
```

## PR status on the head commit

The query behind `scripts/head-status.sh`:

```graphql
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      headRefOid
      commits(last: 1) { nodes { commit { oid statusCheckRollup { state } } } }
      reviews(last: 100) { nodes { author { login } state commit { oid } } }
      reviewThreads(first: 100) { nodes { isResolved } }
    }
  }
}
```

A review counts for the head only when `commit.oid == headRefOid`.

## Review threads

List unresolved threads with their first comment:

```bash
gh api graphql -F pr=<n> -f owner=<owner> -f repo=<repo> -f query='
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100) {
        nodes { id isResolved path line comments(first: 1) { nodes { author { login } body } } }
      }
    }
  }
}' --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)'
```

Reply, then resolve, only with the user's go-ahead:

```bash
gh api graphql -f id=<thread-id> -f body="$(cat reply.md)" -f query='
mutation($id: ID!, $body: String!) {
  addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $id, body: $body}) { comment { id } }
}'
gh api graphql -f id=<thread-id> -f query='
mutation($id: ID!) { resolveReviewThread(input: {threadId: $id}) { thread { isResolved } } }'
```

## Pagination

Connections take `first`/`after` and return `pageInfo { hasNextPage endCursor }`. `gh api graphql --paginate` follows them when the query declares `$endCursor: String` and passes `after: $endCursor` on exactly one connection. Combine with `--slurp` before counting.

## Projects (v2)

Use `projects.md` and the `gh project` commands first; drop to GraphQL (`ProjectV2`, `updateProjectV2ItemFieldValue`) only for what they don't cover.
