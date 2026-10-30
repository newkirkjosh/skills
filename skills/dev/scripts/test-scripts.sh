#!/usr/bin/env bash
# Tests for eval-export.sh and cross-review.sh, using a real throwaway git repository. No network.
# usage: bash test-scripts.sh   (needs bash and git)
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass=0 fail=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else fail=$((fail + 1)); echo "FAIL $1"; fi; }
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com

# Repository: base commit, then a change commit, then an uncommitted edit.
repo="$work/repo"
git init -q -b main "$repo"
echo one > "$repo/a.txt"; git -C "$repo" add a.txt; git -C "$repo" commit -q -m base
base=$(git -C "$repo" rev-parse HEAD)
echo two > "$repo/b.txt"; git -C "$repo" add b.txt; git -C "$repo" commit -q -m "change: secret approach"
head=$(git -C "$repo" rev-parse HEAD)
echo dirty >> "$repo/a.txt"

ex() { bash "$here/eval-export.sh" "$@" > "$work/out" 2> "$work/err"; echo $? > "$work/rc"; }
rc() { cat "$work/rc"; }

ex "$repo" "$head" "$base" "$work/eval"
check "export: succeeds" '[ "$(rc)" = 0 ]'
check "export: head has the change, base doesn't" '[ -f "$work/eval/head/b.txt" ] && [ ! -e "$work/eval/base/b.txt" ]'
check "export: no git history anywhere" '[ -z "$(find "$work/eval" -name .git)" ]'
check "export: commit messages don't leak" '! grep -rq "secret approach" "$work/eval"'
check "export: committed state only, not the dirty edit" '[ "$(cat "$work/eval/head/a.txt")" = one ]'
check "export: prints both paths" 'grep -q "^head: $work/eval/head$" "$work/out" && grep -q "^base: $work/eval/base$" "$work/out"'

ex "$repo" "$head" "$base" "$work/eval"
check "export: refuses a non-empty out dir" '[ "$(rc)" = 2 ]'
ex "$repo" deadbeef "$base" "$work/eval2"
check "export: unknown commit exits 2" '[ "$(rc)" = 2 ] && [ ! -e "$work/eval2" ]'
ex "$repo" "$head"
check "export: missing args exits 2" '[ "$(rc)" = 2 ]'
ex "$work/nope" "$head" "$base" "$work/eval3"
check "export: non-repo exits 2" '[ "$(rc)" = 2 ]'

# cross-review.sh, with codex and claude stubbed on PATH: each stub records its
# arguments and stdin, and exits with $STUB_RC.
stubs="$work/bin"
mkdir -p "$stubs"
for tool in codex claude; do
  cat > "$stubs/$tool" <<EOF
#!/usr/bin/env bash
if [ "\$1 \$2" = "mcp list" ]; then
  [ -n "\${MCP_FAIL:-}" ] && exit 1
  echo '[{"name":"alpha"},{"name":"beta.svc"}]'; exit 0
fi
printf '%s\n' "\$@" > "$work/$tool.args"
cat > "$work/$tool.stdin"
echo "review text"
exit "\${STUB_RC:-0}"
EOF
  chmod +x "$stubs/$tool"
done
git -C "$repo" checkout -q -- a.txt
echo "brief: only the empty state" > "$work/brief.md"
cr() { PATH="$stubs:$PATH" bash "$here/cross-review.sh" "$@" > "$work/out" 2> "$work/err"; echo $? > "$work/rc"; }
last() { tail -n 1 "$work/out"; }

cr codex "$repo" "$base" "$work/brief.md"
check "cross-review codex: completes" '[ "$(rc)" = 0 ] && [ "$(last)" = STATUS=COMPLETED ]'
check "cross-review codex: disables every MCP server by name" 'grep -qx "mcp_servers.\"alpha\".enabled=false" "$work/codex.args" && grep -qx "mcp_servers.\"beta.svc\".enabled=false" "$work/codex.args"'
check "cross-review codex: no --base (codex rejects it with a prompt)" '! grep -qx -- "--base" "$work/codex.args"'
check "cross-review codex: prompt carries the range and the brief" 'grep -q "git diff $base...HEAD" "$work/codex.stdin" && grep -q "only the empty state" "$work/codex.stdin"'
check "cross-review codex: no model override unless asked" '! grep -q "^model=" "$work/codex.args"'
CROSS_REVIEW_EFFORT=high cr codex "$repo" "$base" "$work/brief.md"
check "cross-review codex: effort override per run" 'grep -qx "model_reasoning_effort=\"high\"" "$work/codex.args"'
MCP_FAIL=1 cr codex "$repo" "$base" "$work/brief.md"
check "cross-review codex: refuses when MCP list fails" '[ "$(rc)" = 3 ] && [ "$(last)" = STATUS=ERROR ]'
STUB_RC=2 cr codex "$repo" "$base" "$work/brief.md"
check "cross-review: passes the reviewer exit through" '[ "$(rc)" = 2 ] && grep -qx REVIEWER_EXIT=2 "$work/out" && [ "$(last)" = STATUS=COMPLETED ]'

cr claude "$repo" "$base" "$work/brief.md"
check "cross-review claude: completes" '[ "$(rc)" = 0 ] && [ "$(last)" = STATUS=COMPLETED ]'
check "cross-review claude: print mode, no write tools" 'grep -qx -- "-p" "$work/claude.args" && grep -qx Edit "$work/claude.args" && ! grep -q "Bash(git push" "$work/claude.args"'

cr gemini "$repo" "$base" "$work/brief.md"
check "cross-review: unknown reviewer exits 3" '[ "$(rc)" = 3 ] && [ "$(last)" = STATUS=ERROR ]'
cr codex "$repo" nope "$work/brief.md"
check "cross-review: unknown base exits 3" '[ "$(rc)" = 3 ]'
cr codex "$repo" HEAD "$work/brief.md"
check "cross-review: empty range exits 3" '[ "$(rc)" = 3 ] && grep -q "nothing to review" "$work/err"'
: > "$work/empty.md"
cr codex "$repo" "$base" "$work/empty.md"
check "cross-review: empty prompt exits 3" '[ "$(rc)" = 3 ]'

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
