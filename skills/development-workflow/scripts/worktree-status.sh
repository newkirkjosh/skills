#!/usr/bin/env bash
# List every linked worktree of a repository with what it needs next.
#
# usage: bash worktree-status.sh [repo-dir]
#   STALE_DAYS  days without a commit before a PR-less worktree is stale (default 14)
#
# Prints one tab-separated row per linked worktree (the main checkout is
# skipped): STATE, path, branch, PR, behind/ahead of the default branch,
# uncommitted file count, days since the last commit. STATE is one of:
#   CLEANUP  PR merged at this tip, nothing uncommitted: remove it
#   DIRTY    uncommitted changes (checked first; never clean these up)
#   BEHIND   open PR, default branch has moved on: merge it in
#   STALE    no PR and no commit for STALE_DAYS
#   ACTIVE   anything else
# Reads GitHub through gh; offline, PR shows as "?" and nothing is CLEANUP.
set -uo pipefail

repo=${1:-.}
stale_days=${STALE_DAYS:-14}
git -C "$repo" rev-parse --git-dir > /dev/null 2>&1 || { echo "not a git repository: $repo" >&2; exit 2; }

default=$(git -C "$repo" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null) || default=origin/main
git -C "$repo" rev-parse --verify --quiet "$default" > /dev/null || default=main
now=$(date +%s)

printf 'STATE\tPATH\tBRANCH\tPR\tBEHIND/AHEAD\tDIRTY\tAGE_DAYS\n'
first=1 path='' branch=''
emit() {
  [ -n "$path" ] || return 0
  if [ "$first" = 1 ]; then first=0; return 0; fi   # the main checkout
  local tip dirty age counts behind ahead pr='-' pr_state='' pr_head='' state=ACTIVE json
  tip=$(git -C "$path" rev-parse HEAD 2>/dev/null) || tip=''
  dirty=$(git -C "$path" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  age=$(( (now - $(git -C "$path" log -1 --format=%ct 2>/dev/null || echo "$now")) / 86400 ))
  counts=$(git -C "$path" rev-list --left-right --count "$default...HEAD" 2>/dev/null || echo "? ?")
  behind=${counts%%[[:space:]]*} ahead=${counts##*[[:space:]]}
  if [ -n "$branch" ]; then
    if json=$(cd "$path" && gh pr list --head "$branch" --state all --limit 1 \
                --json number,state,headRefOid 2>/dev/null); then
      pr_state=$(jq -r '.[0].state // empty' <<< "$json")
      pr_head=$(jq -r '.[0].headRefOid // empty' <<< "$json")
      [ -n "$pr_state" ] && pr="#$(jq -r '.[0].number' <<< "$json") $pr_state"
    else
      pr='?'
    fi
  fi
  if [ "$dirty" -gt 0 ]; then state=DIRTY
  elif [ "$pr_state" = MERGED ] && [ "$pr_head" = "$tip" ]; then state=CLEANUP
  elif [ "$pr_state" = OPEN ] && [ "$behind" != "?" ] && [ "$behind" -gt 0 ]; then state=BEHIND
  elif [ "$pr" = '-' ] && [ "$age" -ge "$stale_days" ]; then state=STALE
  fi
  printf '%s\t%s\t%s\t%s\t%s/%s\t%s\t%s\n' "$state" "$path" "${branch:-(detached)}" "$pr" "$behind" "$ahead" "$dirty" "$age"
}

while IFS= read -r line; do
  case "$line" in
    "worktree "*) path=${line#worktree } branch='' ;;
    "branch "*)   branch=${line#branch refs/heads/} ;;
    "")           emit; path='' ;;
  esac
done < <(git -C "$repo" worktree list --porcelain; echo)
