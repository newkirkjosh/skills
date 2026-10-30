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
# Exit: 0 PASS, 1 FAIL, 3 TIMEOUT (also when GitHub couldn't be read), 4
# NOT_CONFIGURED (no CodeRabbit check on the head: terminal, don't retry), 5
# RATE_LIMITED (don't wait out the cooldown), 6 HEAD_MOVED (a push landed
# mid-wait: rerun for the new head), 2 usage
set -uo pipefail

pr=${1:-}
[[ $pr =~ ^[0-9]+$ ]] || { sed -n '2,15p' "$0" >&2; exit 2; }
timeout_min=${2:-20}
[[ $timeout_min =~ ^[0-9]+$ ]] || { echo "timeout must be whole minutes" >&2; exit 2; }
nwo=${3:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}
[[ $nwo =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { echo "bad owner/repo: $nwo" >&2; exit 2; }
interval=${WAIT_INTERVAL:-30} appear_min=${WAIT_APPEAR_MIN:-5}

head_of() { gh pr view "$pr" -R "$nwo" --json headRefOid -q .headRefOid; }
head=$(head_of) || { echo "cannot read PR $pr in $nwo" >&2; exit 2; }
[[ $head =~ ^[0-9a-f]{40}$ ]] || { echo "bad head SHA for PR $pr: $head" >&2; exit 2; }
# A rate-limit comment counts only if CodeRabbit wrote or updated it after this head
# became the PR's head: after the commit was made, and after the last force-push
# (which can make an older commit the head again).
since=$(gh api "repos/$nwo/commits/$head" --jq .commit.committer.date) || { echo "cannot read commit $head" >&2; exit 2; }
pushed=$(gh api "repos/$nwo/issues/$pr/timeline" --paginate \
  --jq '.[] | select(.event == "head_ref_force_pushed") | .created_at' | sort | tail -n 1) \
  || { echo "cannot read PR $pr timeline" >&2; exit 2; }
[[ -n $pushed && $pushed > $since ]] && since=$pushed
deadline=$((SECONDS + timeout_min * 60)) appear_deadline=$((SECONDS + appear_min * 60))
errors=0
err=$(mktemp) || exit 2
trap 'rm -f "$err"' EXIT

while :; do
  now=$(head_of) || now=$head
  [ "$now" = "$head" ] || { echo "STATUS=HEAD_MOVED from=$head to=$now"; exit 6; }

  # The check is read for this exact SHA, so a push mid-poll can't lend this head another commit's result.
  read_ok=0
  if run=$(gh api "repos/$nwo/commits/$head/check-runs?check_name=CodeRabbit" \
      --jq '[.check_runs[] | {status, conclusion}] | first // empty' 2> "$err"); then
    read_ok=1
    status=$(jq -r '.status // empty' <<< "${run:-null}") conclusion=$(jq -r '.conclusion // empty' <<< "${run:-null}")
    if [ "$status" = completed ]; then
      case $conclusion in
        success|neutral|skipped) echo "STATUS=PASS conclusion=$conclusion sha=$head"; exit 0 ;;
        *) echo "STATUS=FAIL conclusion=$conclusion sha=$head"; exit 1 ;;
      esac
    fi
  else
    errors=$((errors + 1)) status=""
    echo "gh api check-runs failed: $(cat "$err")" >&2
  fi

  # Read every page before matching: `grep -q` closing the pipe early would fail the
  # pipeline under pipefail and hide the match.
  bodies=$(gh api "repos/$nwo/issues/$pr/comments" --paginate \
    --jq ".[] | select(.user.login == \"coderabbitai[bot]\" and .updated_at >= \"$since\") | .body" 2> /dev/null) || bodies=""
  if grep -qiE 'rate limit(ed| exceeded)' <<< "$bodies"; then
    echo "STATUS=RATE_LIMITED sha=$head"; exit 5
  fi

  # Absent only counts once GitHub has actually been read; an outage is not "not configured".
  if [ -z "${run:-}" ] && [ "$read_ok" = 1 ] && [ "$SECONDS" -ge "$appear_deadline" ]; then
    echo "STATUS=NOT_CONFIGURED sha=$head after ${appear_min}m"; exit 4
  fi
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "STATUS=TIMEOUT check=${status:-none} query_errors=$errors sha=$head after ${timeout_min}m"; exit 3
  fi
  sleep "$interval"
done
