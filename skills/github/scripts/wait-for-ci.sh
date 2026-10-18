#!/usr/bin/env bash
# Wait for every GitHub Actions run on one commit to finish, with a deadline.
# Run it in the background (Claude Code: run_in_background) and read the
# final STATUS= line when it exits.
#
# usage: bash wait-for-ci.sh <sha> [timeout-minutes] [owner/repo]
#   timeout-minutes  default 30; owner/repo defaults to the current repository
#   WAIT_APPEAR_MIN  minutes to wait for a first run to appear (default 3)
#   WAIT_INTERVAL    seconds between polls (default 15)
# Exit: 0 all passed, 1 a run failed, 3 timed out, 4 no run appeared, 2 usage
set -uo pipefail

sha=${1:-}
[[ $sha =~ ^[0-9a-f]{7,40}$ ]] || { sed -n '2,12p' "$0" >&2; exit 2; }
timeout_min=${2:-30}
[[ $timeout_min =~ ^[0-9]+$ ]] || { echo "timeout must be whole minutes" >&2; exit 2; }
repo_args=()
[ -n "${3:-}" ] && repo_args=(-R "$3")
interval=${WAIT_INTERVAL:-15} appear_min=${WAIT_APPEAR_MIN:-3}

start=$SECONDS
deadline=$((start + timeout_min * 60)) appear_deadline=$((start + appear_min * 60))

while :; do
  if ! runs=$(gh run list "${repo_args[@]}" --commit "$sha" --limit 100 \
      --json databaseId,name,status,conclusion 2>&1); then
    echo "gh run list failed: $runs" >&2
    runs='[]'
  fi
  total=$(jq 'length' <<< "$runs")
  open=$(jq '[.[] | select(.status != "completed")] | length' <<< "$runs")

  if [ "$total" -gt 0 ] && [ "$open" -eq 0 ]; then
    jq -r '.[] | "\(.conclusion)\t\(.name)\t\(.databaseId)"' <<< "$runs"
    if jq -e 'all(.[]; .conclusion | IN("success", "skipped", "neutral"))' <<< "$runs" > /dev/null; then
      echo "STATUS=PASS runs=$total sha=$sha"; exit 0
    fi
    echo "STATUS=FAIL runs=$total sha=$sha"; exit 1
  fi
  if [ "$total" -eq 0 ] && [ "$SECONDS" -ge "$appear_deadline" ]; then
    echo "STATUS=NO_RUNS sha=$sha after ${appear_min}m"; exit 4
  fi
  if [ "$SECONDS" -ge "$deadline" ]; then
    jq -r '.[] | "\(.status)\t\(.name)\t\(.databaseId)"' <<< "$runs"
    echo "STATUS=TIMEOUT open=$open runs=$total sha=$sha after ${timeout_min}m"; exit 3
  fi
  sleep "$interval"
done
