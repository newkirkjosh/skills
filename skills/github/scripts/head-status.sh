#!/usr/bin/env bash
# Summarise a PR's state for its HEAD commit only: check rollup, reviews on the
# head versus older commits, and unresolved review threads.
#
# usage: bash head-status.sh <pr-number> [owner/repo]
#   owner/repo defaults to the current directory's repository.
# Prints one JSON object. Exits non-zero when the read fails.
set -euo pipefail

pr=${1:-}
[[ $pr =~ ^[0-9]+$ ]] || { sed -n '2,8p' "$0" >&2; exit 2; }
nwo=${2:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}
[[ $nwo =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { echo "bad owner/repo: $nwo" >&2; exit 2; }

gh api graphql -F pr="$pr" -f owner="${nwo%%/*}" -f repo="${nwo#*/}" -f query='
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      state
      headRefOid
      commits(last: 1) { nodes { commit { oid statusCheckRollup { state } } } }
      reviews(last: 100) { nodes { author { login } state commit { oid } } }
      reviewThreads(first: 100) { totalCount nodes { isResolved } }
    }
  }
}' | jq -e '
  .data.repository.pullRequest
  | .headRefOid as $head
  | {
      state,
      head: $head,
      checks: ((.commits.nodes[0].commit | select(.oid == $head) | .statusCheckRollup.state) // "NONE"),
      reviews_on_head: [.reviews.nodes[] | select(.commit.oid == $head) | {author: .author.login, state}],
      reviews_on_older_commits: ([.reviews.nodes[] | select(.commit.oid != $head)] | length),
      unresolved_threads: ([.reviewThreads.nodes[] | select(.isResolved | not)] | length),
      threads_truncated: (.reviewThreads.totalCount > (.reviewThreads.nodes | length))
    }'
