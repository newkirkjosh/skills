#!/usr/bin/env bash
# Tests for cross-review.sh, using a real throwaway git repository with codex
# and claude stubbed on PATH. No network.
# usage: bash test-cross-review.sh   (needs bash, git, jq and sha256sum)
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass=0 fail=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else fail=$((fail + 1)); echo "FAIL $1"; fi; }
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com

# Repository: base commit, then a change commit.
repo="$work/repo"
git init -q -b main "$repo"
echo one > "$repo/a.txt"; git -C "$repo" add a.txt; git -C "$repo" commit -q -m base
base=$(git -C "$repo" rev-parse HEAD)
echo two > "$repo/b.txt"; git -C "$repo" add b.txt; git -C "$repo" commit -q -m change
head=$(git -C "$repo" rev-parse HEAD)

# Each stub records its arguments, stdin and working directory, and exits with
# $STUB_RC. STUB_TOUCH names a file the stub appends to while "reviewing".
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
pwd > "$work/$tool.pwd"
cat > "$work/$tool.stdin"
[ -n "\${STUB_TOUCH:-}" ] && echo edited >> "\$STUB_TOUCH"
[ -n "\${STUB_COMMIT:-}" ] && git -C "\$STUB_COMMIT" commit -q --allow-empty -m moved
echo "review text"
exit "\${STUB_RC:-0}"
EOF
  chmod +x "$stubs/$tool"
done
echo "brief: only the empty state" > "$work/brief.md"
cr() { PATH="$stubs:$PATH" bash "$here/cross-review.sh" "$@" > "$work/out" 2> "$work/err"; echo $? > "$work/rc"; }
rc() { cat "$work/rc"; }
last() { tail -n 1 "$work/out"; }

# Change mode.
cr codex "$repo" "$base" "$work/brief.md"
check "codex: completes" '[ "$(rc)" = 0 ] && [ "$(last)" = STATUS=COMPLETED ]'
check "codex: header names the reviewed head" 'grep -q "mode=change .*head=$head" "$work/out"'
check "codex: disables every MCP server by name" 'grep -qx "mcp_servers.\"alpha\".enabled=false" "$work/codex.args" && grep -qx "mcp_servers.\"beta.svc\".enabled=false" "$work/codex.args"'
check "codex: runs codex review" '[ "$(head -n 1 "$work/codex.args")" = review ]'
check "codex: no --base (codex rejects it with a prompt)" '! grep -qx -- "--base" "$work/codex.args"'
check "codex: prompt carries the range and the brief" 'grep -q "git diff $base...HEAD" "$work/codex.stdin" && grep -q "only the empty state" "$work/codex.stdin"'
check "codex: no model override unless asked" '! grep -q "^model=" "$work/codex.args"'
check "codex: forces a read-only sandbox" 'grep -qx "sandbox_mode=\"read-only\"" "$work/codex.args" && grep -qx "approval_policy=\"never\"" "$work/codex.args"'
CROSS_REVIEW_EFFORT=high cr codex "$repo" "$base" "$work/brief.md"
check "codex: effort override per run" 'grep -qx "model_reasoning_effort=\"high\"" "$work/codex.args"'
MCP_FAIL=1 cr codex "$repo" "$base" "$work/brief.md"
check "codex: refuses when MCP list fails" '[ "$(rc)" = 3 ] && [ "$(last)" = STATUS=ERROR ]'
STUB_RC=2 cr codex "$repo" "$base" "$work/brief.md"
check "a failed reviewer is ERROR, never COMPLETED" '[ "$(rc)" = 2 ] && grep -qx REVIEWER_EXIT=2 "$work/out" && [ "$(last)" = STATUS=ERROR ]'
(cd "$work" && PATH="$stubs:$PATH" bash "$here/cross-review.sh" codex "$repo" "$base" brief.md > "$work/out" 2> "$work/err"; echo $? > "$work/rc")
check "relative prompt path resolves from the caller" '[ "$(rc)" = 0 ] && grep -q "only the empty state" "$work/codex.stdin"'

cr claude "$repo" "$base" "$work/brief.md"
check "claude: completes" '[ "$(rc)" = 0 ] && [ "$(last)" = STATUS=COMPLETED ]'
check "claude: print mode, read-only tools, no shell, no MCP" 'grep -qx -- "-p" "$work/claude.args" && grep -qx -- "--tools" "$work/claude.args" && grep -qx Read "$work/claude.args" && ! grep -q "Bash" "$work/claude.args" && grep -qx -- "--strict-mcp-config" "$work/claude.args"'
check "claude: reviews a diff written beforehand" 'grep -q "change.diff" "$work/claude.stdin" && grep -q "only the empty state" "$work/claude.stdin"'

STUB_COMMIT="$repo" cr codex "$repo" "$base" "$work/brief.md"
check "a HEAD that moves during review is ERROR" '[ "$(last)" = STATUS=ERROR ] && grep -q "HEAD moved" "$work/err"'

cr gemini "$repo" "$base" "$work/brief.md"
check "unknown reviewer exits 3" '[ "$(rc)" = 3 ] && [ "$(last)" = STATUS=ERROR ]'
cr codex "$repo" nope "$work/brief.md"
check "unknown base exits 3" '[ "$(rc)" = 3 ]'
cr codex "$repo" HEAD "$work/brief.md"
check "empty range exits 3" '[ "$(rc)" = 3 ] && grep -q "nothing to review" "$work/err"'
: > "$work/empty.md"
cr codex "$repo" "$base" "$work/empty.md"
check "empty prompt exits 3" '[ "$(rc)" = 3 ]'
cr codex "$repo" "$base"
check "missing argument exits 3" '[ "$(rc)" = 3 ] && grep -q usage "$work/err"'

# Document mode: an uncommitted draft outside any repository.
doc="$work/drafts/viability.md"
mkdir -p "$work/drafts"
printf '%s\n' '# Viability: Example' '**Verdict:** Go' > "$doc"
digest=$(sha256sum "$doc" | cut -d' ' -f1)

cr codex --document "$doc" "$work/brief.md"
check "document codex: completes" '[ "$(rc)" = 0 ] && [ "$(last)" = STATUS=COMPLETED ]'
check "document codex: header names the content digest" 'grep -q "mode=document digest=sha256:$digest" "$work/out"'
check "document codex: codex exec, not codex review" '[ "$(head -n 1 "$work/codex.args")" = exec ] && ! grep -qx review "$work/codex.args"'
check "document codex: same read-only sandbox and MCP lockdown" 'grep -qx "sandbox_mode=\"read-only\"" "$work/codex.args" && grep -qx "approval_policy=\"never\"" "$work/codex.args" && grep -qx "mcp_servers.\"alpha\".enabled=false" "$work/codex.args"'
check "document codex: runs in the snapshot directory, not the draft folder" 'grep -qx -- "--skip-git-repo-check" "$work/codex.args" && [ "$(grep -A1 -x -- -C "$work/codex.args" | tail -n 1)" = "$(cat "$work/codex.pwd")" ] && [ "$(cat "$work/codex.pwd")" != "$work/drafts" ]'
check "document codex: prompt names the digest and carries the brief" 'grep -q "sha256:$digest" "$work/codex.stdin" && grep -q "only the empty state" "$work/codex.stdin"'
check "document: snapshot is removed afterwards" 'snap=$(cat "$work/codex.pwd"); [ ! -e "$snap" ]'

cr claude --document "$doc" "$work/brief.md"
check "document claude: completes with read-only tools and no MCP" '[ "$(rc)" = 0 ] && grep -qx -- "--tools" "$work/claude.args" && ! grep -q Bash "$work/claude.args" && grep -qx -- "--strict-mcp-config" "$work/claude.args"'
check "document claude: header names the content digest" 'grep -q "mode=document digest=sha256:$digest" "$work/out"'

STUB_TOUCH="$doc" cr claude --document "$doc" "$work/brief.md"
check "document: an edit to the draft mid-review doesn't change the reviewed digest" '[ "$(rc)" = 0 ] && grep -q "digest=sha256:$digest" "$work/out" && [ "$(sha256sum "$doc" | cut -d" " -f1)" != "$digest" ]'
STUB_RC=2 cr codex --document "$doc" "$work/brief.md"
check "document: a failed reviewer is ERROR" '[ "$(rc)" = 2 ] && [ "$(last)" = STATUS=ERROR ]'
cr codex --document "$work/nope.md" "$work/brief.md"
check "document: missing file exits 3" '[ "$(rc)" = 3 ] && [ "$(last)" = STATUS=ERROR ]'
cr codex --document "$work/empty.md" "$work/brief.md"
check "document: empty file exits 3" '[ "$(rc)" = 3 ]'
cr codex --document "$doc"
check "document: missing prompt argument exits 3" '[ "$(rc)" = 3 ]'

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
