#!/usr/bin/env bash
# Export a change's head and its base as plain directories with no git
# history, for an evaluator that must not learn how the change was built.
#
# usage: bash eval-export.sh <repo-dir> <head-ref> <base-ref> <out-dir>
#   base-ref is usually the merge base: $(git merge-base origin/main HEAD)
# Creates <out-dir>/head and <out-dir>/base (tracked files only, no .git) and
# prints their paths. Refuses an existing non-empty <out-dir>.
set -euo pipefail

[ $# -eq 4 ] || { sed -n '2,9p' "$0" >&2; exit 2; }
repo=$1 head_ref=$2 base_ref=$3 out=$4

git -C "$repo" rev-parse --git-dir > /dev/null 2>&1 || { echo "not a git repository: $repo" >&2; exit 2; }
for r in "$head_ref" "$base_ref"; do
  git -C "$repo" rev-parse --verify --quiet "$r^{commit}" > /dev/null || { echo "unknown commit: $r" >&2; exit 2; }
done
if [ -e "$out" ] && [ -n "$(ls -A "$out" 2>/dev/null)" ]; then
  echo "refusing to reuse non-empty $out" >&2; exit 2
fi

for side in head base; do
  ref=$head_ref; [ "$side" = base ] && ref=$base_ref
  mkdir -p "$out/$side"
  git -C "$repo" archive --format=tar "$ref" | tar -x -C "$out/$side"
done

if find "$out" -name .git -print -quit | grep -q .; then
  echo "export contains a .git entry; refusing" >&2; exit 1
fi
echo "head: $out/head"
echo "base: $out/base"
