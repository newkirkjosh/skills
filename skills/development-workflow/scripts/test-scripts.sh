#!/usr/bin/env bash
# Tests for worktree-status.sh and eval-export.sh, using real throwaway git
# repositories and worktrees, and a stub gh. No network.
# usage: bash test-scripts.sh   (needs bash, git, jq)
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass=0 fail=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else fail=$((fail + 1)); echo "FAIL $1"; fi; }
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
g() { git -C "$repo" "$@"; }
commit() { git -C "$1" commit -q --allow-empty -m "${2:-c}"; }

# --- fixture: repo with origin/main and five linked worktrees ---------------------
remote="$work/remote.git" repo="$work/repo"
git init -q --bare -b main "$remote"
git init -q -b main "$repo"
echo one > "$repo/a.txt"; g add a.txt; commit "$repo" init
g remote add origin "$remote"; g push -q -u origin main
g remote set-head origin main > /dev/null

for b in merged dirty behind stale active; do
  g worktree add -q "$repo/.worktrees/$b" -b "feat/$b"
  commit "$repo/.worktrees/$b" "work on $b"
done
GIT_COMMITTER_DATE="2020-01-01T00:00:00" commit "$repo/.worktrees/stale" "old work"
echo change >> "$repo/.worktrees/dirty/a.txt"
commit "$repo" "main moves on"; g push -q origin main

# gh stub: the PR for --head <branch> comes from $STUB/<branch-with-slashes-as-_>.json
mkdir -p "$work/bin" "$work/stub"
cat > "$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
[ -n "${STUB_GH_FAIL:-}" ] && exit 1
while [ $# -gt 0 ]; do [ "$1" = --head ] && { b=$2; break; }; shift; done
f="$STUB/${b//\//_}.json"
if [ -f "$f" ]; then cat "$f"; else echo '[]'; fi
EOF
chmod +x "$work/bin/gh"
export STUB="$work/stub"
pr() { echo "[{\"number\":$2,\"state\":\"$3\",\"headRefOid\":\"$4\"}]" > "$STUB/feat_$1.json"; }
tip() { git -C "$repo/.worktrees/$1" rev-parse HEAD; }
pr merged 10 MERGED "$(tip merged)"
pr behind 11 OPEN "$(tip behind)"
pr active 12 OPEN "$(tip active)"

status() { PATH="$work/bin:$PATH" bash "$here/worktree-status.sh" "$@" > "$work/out" 2> "$work/err"; echo $? > "$work/rc"; }
row() { awk -F'\t' -v b="feat/$1" '$3 == b' "$work/out"; }
state() { row "$1" | cut -f1; }

# --- worktree-status.sh ---------------------------------------------------------------
status "$repo"
check "status: succeeds" '[ "$(cat "$work/rc")" = 0 ]'
check "status: prints a header" 'head -1 "$work/out" | grep -q "^STATE	PATH	BRANCH"'
check "status: skips the main checkout" '! grep -q "	main	" "$work/out" && [ "$(($(wc -l < "$work/out") - 1))" = 5 ]'
check "status: merged PR at the tip is CLEANUP" '[ "$(state merged)" = CLEANUP ]'
check "status: uncommitted changes are DIRTY" '[ "$(state dirty)" = DIRTY ] && [ "$(row dirty | cut -f6)" = 1 ]'
check "status: open PR behind main is BEHIND" '[ "$(state behind)" = BEHIND ] && [ "$(row behind | cut -f5)" = "1/1" ]'
check "status: old PR-less work is STALE" '[ "$(state stale)" = STALE ] && [ "$(row stale | cut -f4)" = "-" ]'
check "status: PR number and state shown" '[ "$(row merged | cut -f4)" = "#10 MERGED" ]'

git -C "$repo/.worktrees/active" merge -q --no-edit origin/main
pr active 12 OPEN "$(tip active)"
status "$repo"
check "status: open PR up to date is ACTIVE" '[ "$(state active)" = ACTIVE ]'

commit "$repo/.worktrees/merged" "after merge"
status "$repo"
check "status: commits after the merge are not CLEANUP" '[ "$(state merged)" != CLEANUP ]'

echo change > "$repo/.worktrees/behind/new.txt"
status "$repo"
check "status: DIRTY wins over BEHIND" '[ "$(state behind)" = DIRTY ]'
rm "$repo/.worktrees/behind/new.txt"

STALE_DAYS=100000 status "$repo"
check "status: STALE_DAYS raises the bar" '[ "$(state stale)" = ACTIVE ]'

STUB_GH_FAIL=1 status "$repo"
check "status: offline shows ? and never CLEANUP" '[ "$(row stale | cut -f4)" = "?" ] && ! grep -q "^CLEANUP" "$work/out"'

status "$work/nope"
check "status: non-repo exits 2" '[ "$(cat "$work/rc")" = 2 ]'

# --- eval-export.sh -------------------------------------------------------------------
ex() { bash "$here/eval-export.sh" "$@" > "$work/out" 2> "$work/err"; echo $? > "$work/rc"; }
base=$(g rev-parse main~1) head=$(tip dirty)

ex "$repo" "$head" "$base" "$work/eval"
check "export: succeeds" '[ "$(cat "$work/rc")" = 0 ]'
check "export: head and base written" '[ -f "$work/eval/head/a.txt" ] && [ -f "$work/eval/base/a.txt" ]'
check "export: no git history anywhere" '[ -z "$(find "$work/eval" -name .git)" ]'
check "export: git sees no repository" '! git -C "$work/eval/head" rev-parse --git-dir > /dev/null 2>&1 || [ "$(git -C "$work/eval/head" rev-parse --show-toplevel 2>/dev/null)" != "$work/eval/head" ]'
check "export: committed state only, not the dirty file" '[ "$(cat "$work/eval/head/a.txt")" = one ]'
check "export: prints both paths" 'grep -q "^head: $work/eval/head$" "$work/out" && grep -q "^base: $work/eval/base$" "$work/out"'

ex "$repo" "$head" "$base" "$work/eval"
check "export: refuses a non-empty out dir" '[ "$(cat "$work/rc")" = 2 ]'
ex "$repo" deadbeef "$base" "$work/eval2"
check "export: unknown commit exits 2" '[ "$(cat "$work/rc")" = 2 ] && [ ! -e "$work/eval2" ]'
ex "$repo" "$head"
check "export: missing args exits 2" '[ "$(cat "$work/rc")" = 2 ]'

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
