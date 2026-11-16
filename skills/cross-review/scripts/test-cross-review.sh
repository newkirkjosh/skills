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
# `codex mcp list` models how codex applies `-c` overrides: the key splits on
# every dot with quotes kept literally, a key into an unknown server is a
# config error, and a server is disabled only by `mcp_servers.<name>.enabled=false`.
# MCP_NAMES lists the configured servers, `|`-separated; MCP_IGNORE=1 makes it
# ignore the overrides; REAL_CODEX hands `mcp list` to an installed codex.
stubs="$work/bin"
mkdir -p "$stubs"
export STUB_WORK="$work"
for tool in codex claude; do
  sed "s/@TOOL@/$tool/g" > "$stubs/$tool" <<'EOF'
#!/usr/bin/env bash
if [ "$1 $2" = "mcp list" ]; then
  [ -n "${MCP_FAIL:-}" ] && exit 1
  [ -n "${REAL_CODEX:-}" ] && exec "$REAL_CODEX" "$@"
  IFS='|' read -r -a names <<<"${MCP_NAMES:-alpha|has space}"
  off=()
  shift 2
  while [ $# -gt 0 ]; do
    if [ "$1" = -c ] && [ -z "${MCP_IGNORE:-}" ]; then
      key=${2%%=*} val=${2#*=}
      IFS=. read -r -a part <<<"$key"
      if [ "${part[0]}" = mcp_servers ]; then
        known=""; for n in "${names[@]}"; do [ "$n" = "${part[1]}" ] && known=1; done
        [ -n "$known" ] || { echo "invalid transport in mcp_servers.${part[1]}" >&2; exit 1; }
        [ "${#part[@]}" -eq 3 ] && [ "${part[2]}" = enabled ] && [ "$val" = false ] && off+=("${part[1]}")
      fi
      shift 2
    else
      shift
    fi
  done
  for n in "${names[@]}"; do
    e=true; for o in "${off[@]}"; do [ "$o" = "$n" ] && e=false; done
    jq -cn --arg n "$n" --argjson e "$e" '{name: $n, enabled: $e}'
  done | jq -s .
  exit 0
fi
printf '%s\n' "$@" > "$STUB_WORK/@TOOL@.args"
pwd > "$STUB_WORK/@TOOL@.pwd"
cat > "$STUB_WORK/@TOOL@.stdin"
[ -n "${STUB_TOUCH:-}" ] && echo edited >> "$STUB_TOUCH"
[ -n "${STUB_COMMIT:-}" ] && git -C "$STUB_COMMIT" commit -q --allow-empty -m moved
echo "review text"
exit "${STUB_RC:-0}"
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
check "codex: disables every MCP server with a bare key codex resolves" 'grep -qx "mcp_servers.alpha.enabled=false" "$work/codex.args" && grep -qx "mcp_servers.has space.enabled=false" "$work/codex.args" && grep -q "mcp_disabled=2" "$work/out"'
MCP_NAMES='alpha|beta.svc' cr codex "$repo" "$base" "$work/brief.md"
check "codex: refuses a server name -c can't address" '[ "$(rc)" = 3 ] && grep -q "beta.svc" "$work/err" && [ "$(last)" = STATUS=ERROR ]'
rm -f "$work/codex.args"
MCP_IGNORE=1 cr codex "$repo" "$base" "$work/brief.md"
check "codex: refuses when a server stays enabled after the overrides" '[ "$(rc)" = 3 ] && grep -q "still enabled" "$work/err" && [ ! -e "$work/codex.args" ]'
real=$(PATH=$(sed "s#$stubs:##" <<<"$PATH") command -v codex || true)
if [ -n "$real" ]; then
  # The installed codex, in a throwaway CODEX_HOME: the user's config is never read.
  home="$work/codex-home"; mkdir -p "$home"
  printf '%s\n' '[mcp_servers.alpha]' 'command = "true"' '[mcp_servers."has space"]' 'command = "true"' > "$home/config.toml"
  rm -f "$work/codex.args"
  (cd "$work" && CODEX_HOME="$home" REAL_CODEX="$real" cr codex "$repo" "$base" "$work/brief.md")
  check "codex: the installed codex reports every server disabled under the overrides" '[ "$(rc)" = 0 ] && [ "$(last)" = STATUS=COMPLETED ] && grep -q "mcp_disabled=2" "$work/out"'
else
  echo "skip installed-codex MCP check (codex not on PATH)"
fi
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
STUB_TOUCH="$repo/a.txt" cr claude "$repo" "$base" "$work/brief.md"
check "a worktree edited during review is ERROR" '[ "$(last)" = STATUS=ERROR ] && grep -q "worktree changed during review" "$work/err"'
git -C "$repo" checkout -q -- a.txt
rm -f "$work/codex.args"
echo dirty >> "$repo/a.txt"
cr codex "$repo" "$base" "$work/brief.md"
check "an uncommitted edit is refused before review" '[ "$(rc)" = 3 ] && grep -q "uncommitted or untracked" "$work/err" && [ ! -e "$work/codex.args" ]'
git -C "$repo" checkout -q -- a.txt
echo new > "$repo/untracked.txt"
cr claude "$repo" "$base" "$work/brief.md"
check "an untracked file is refused before review" '[ "$(rc)" = 3 ] && grep -q "untracked.txt" "$work/err"'
rm -f "$repo/untracked.txt"

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
check "document codex: same read-only sandbox and MCP lockdown" 'grep -qx "sandbox_mode=\"read-only\"" "$work/codex.args" && grep -qx "approval_policy=\"never\"" "$work/codex.args" && grep -qx "mcp_servers.alpha.enabled=false" "$work/codex.args"'
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
