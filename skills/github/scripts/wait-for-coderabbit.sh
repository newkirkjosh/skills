#!/usr/bin/env bash
# Wait for CodeRabbit's review of a PR's current head, with a deadline.
# Run it in the background (Claude Code: run_in_background) and read the
# final STATUS= line when it exits. It waits only; reading and settling the
# review's threads is head-status.sh and the caller's job.
#
# usage: bash wait-for-coderabbit.sh <pr-number> [timeout-minutes] [owner/repo]
#   timeout-minutes  default 20; owner/repo defaults to the current repository
#   WAIT_APPEAR_MIN  minutes to wait for the CodeRabbit check to appear (default 5)
#   WAIT_INTERVAL    seconds between polls (default 30)
# Exit: 0 PASS, 1 FAIL, 3 TIMEOUT, 4 NOT_CONFIGURED (no CodeRabbit check:
# terminal, don't retry), 5 RATE_LIMITED (don't wait out the cooldown),
# 6 HEAD_MOVED (a push landed mid-wait: rerun for the new head), 2 usage
set -uo pipefail

pr=${1:-}
[[ $pr =~ ^[0-9]+$ ]] || { sed -n '2,14p' "$0" >&2; exit 2; }
timeout_min=${2:-20}
[[ $timeout_min =~ ^[0-9]+$ ]] || { echo "timeout must be whole minutes" >&2; exit 2; }
nwo=${3:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}
[[ $nwo =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { echo "bad owner/repo: $nwo" >&2; exit 2; }
interval=${WAIT_INTERVAL:-30} appear_min=${WAIT_APPEAR_MIN:-5}

head_of() { gh pr view "$pr" -R "$nwo" --json headRefOid -q .headRefOid; }
head=$(head_of) || { echo "cannot read PR $pr in $nwo" >&2; exit 2; }
deadline=$((SECONDS + timeout_min * 60)) appear_deadline=$((SECONDS + appear_min * 60))

while :; do
  now=$(head_of) || now=$head
  [ "$now" = "$head" ] || { echo "STATUS=HEAD_MOVED from=$head to=$now"; exit 6; }

  # `gh pr checks` exits 8 while anything is pending; read its JSON regardless.
  checks=$(gh pr checks "$pr" -R "$nwo" --json name,bucket 2> /dev/null) || true
  bucket=$(jq -r '[.[] | select(.name == "CodeRabbit") | .bucket][0] // empty' <<< "${checks:-[]}" 2> /dev/null)

  case $bucket in
    pass) echo "STATUS=PASS sha=$head"; exit 0 ;;
    fail|cancel) echo "STATUS=FAIL bucket=$bucket sha=$head"; exit 1 ;;
  esac

  # A rate-limited CodeRabbit says so in a PR comment and may never finish its check.
  if gh api "repos/$nwo/issues/$pr/comments" --paginate \
      --jq '.[] | select(.user.login == "coderabbitai[bot]") | .body' 2> /dev/null \
      | grep -qiE 'rate limit(ed| exceeded)'; then
    echo "STATUS=RATE_LIMITED sha=$head"; exit 5
  fi

  if [ -z "$bucket" ] && [ "$SECONDS" -ge "$appear_deadline" ]; then
    echo "STATUS=NOT_CONFIGURED sha=$head after ${appear_min}m"; exit 4
  fi
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "STATUS=TIMEOUT bucket=${bucket:-none} sha=$head after ${timeout_min}m"; exit 3
  fi
  sleep "$interval"
done
