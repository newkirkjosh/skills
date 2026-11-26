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
# Ignore the user's global and system git config, so no fixture commit signs,
# runs a global hook or needs a configured identity: unattended runs never wait on a signing agent.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

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
# ignore the overrides; REAL_CODEX hands `mcp list` and `plugin list` to an
# installed codex. Plugins model codex 0.172: PLUGINS lists enabled plugin IDs
# and PLUGINS_OFF disabled ones (`|`-separated). Each enabled plugin adds a
# server named like the ID before the `@`, which `mcp list` shows unless
# `plugins.<id>.enabled=false` is given; an `mcp_servers.<name>` override for
# such a server is a config error, as in codex. PLUGIN_LIST_FAIL=1 makes
# `plugin list` exit non-zero, PLUGIN_LIST_GARBAGE=1 makes it print non-JSON.
# PLUGIN_LIST_RAW, when set (even empty), is printed verbatim by `plugin list`
# with exit 0. MCP_RAW does the same for `mcp list` before any server override
# is given (the first list) and MCP_RAW_FINAL for the re-list under overrides.
# `codex features list` models codex 0.172 rows (`<name> <stage words> <bool>`):
# `apps` reads true unless `-c features.apps=false` is given, with look-alike
# rows (`apps_early_resource_discovery`, `enable_mcp_apps`) always false.
# FEATURES_IGNORE=1 ignores the override, FEATURES_FAIL=1 exits non-zero,
# FEATURES_RAW (even empty) is printed verbatim with exit 0.
stubs="$work/bin"
mkdir -p "$stubs"
export STUB_WORK="$work"
for tool in codex claude; do
  sed "s/@TOOL@/$tool/g" > "$stubs/$tool" <<'EOF'
#!/usr/bin/env bash
if [ "$1 $2" = "plugin list" ]; then
  [ -n "${PLUGIN_LIST_FAIL:-}" ] && exit 1
  [ -n "${REAL_CODEX:-}" ] && exec "$REAL_CODEX" "$@"
  [ -n "${PLUGIN_LIST_GARBAGE:-}" ] && { echo "not json"; exit 0; }
  [ "${PLUGIN_LIST_RAW+x}" ] && { printf '%s' "$PLUGIN_LIST_RAW"; exit 0; }
  {
    IFS='|' read -r -a on <<<"${PLUGINS:-}"
    for id in "${on[@]}"; do [ -n "$id" ] && jq -cn --arg id "$id" '{pluginId: $id, name: ($id | split("@")[0]), enabled: true}'; done
    IFS='|' read -r -a no <<<"${PLUGINS_OFF:-}"
    for id in "${no[@]}"; do [ -n "$id" ] && jq -cn --arg id "$id" '{pluginId: $id, name: ($id | split("@")[0]), enabled: false}'; done
  } | jq -s '{installed: .}'
  exit 0
fi
if [ "$1 $2" = "features list" ]; then
  [ -n "${FEATURES_FAIL:-}" ] && exit 1
  [ -n "${REAL_CODEX:-}" ] && exec "$REAL_CODEX" "$@"
  [ "${FEATURES_RAW+x}" ] && { printf '%s' "$FEATURES_RAW"; exit 0; }
  apps=true
  for a in "$@"; do [ "$a" = "features.apps=false" ] && [ -z "${FEATURES_IGNORE:-}" ] && apps=false; done
  printf '%-40s %-18s %s\n' apps_early_resource_discovery "under development" false \
    apps stable "$apps" enable_mcp_apps "under development" false
  exit 0
fi
if [ "$1 $2" = "mcp list" ]; then
  [ -n "${MCP_FAIL:-}" ] && exit 1
  [ -n "${REAL_CODEX:-}" ] && exec "$REAL_CODEX" "$@"
  has_ov=""; for a in "$@"; do case $a in mcp_servers.*) has_ov=1 ;; esac; done
  [ -z "$has_ov" ] && [ "${MCP_RAW+x}" ] && { printf '%s' "$MCP_RAW"; exit 0; }
  [ -n "$has_ov" ] && [ "${MCP_RAW_FINAL+x}" ] && { printf '%s' "$MCP_RAW_FINAL"; exit 0; }
  IFS='|' read -r -a names <<<"${MCP_NAMES:-alpha|beta-2}"
  IFS='|' read -r -a plugins <<<"${PLUGINS:-}"
  off=() offp=()
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
      [ "${part[0]}" = plugins ] && [ "${#part[@]}" -eq 3 ] && [ "${part[2]}" = enabled ] && [ "$val" = false ] && offp+=("${part[1]}")
      shift 2
    else
      shift
    fi
  done
  for n in "${names[@]}"; do
    e=true; for o in "${off[@]}"; do [ "$o" = "$n" ] && e=false; done
    jq -cn --arg n "$n" --argjson e "$e" '{name: $n, enabled: $e}'
  done > "$STUB_WORK/servers.jsonl"
  for id in "${plugins[@]}"; do
    [ -n "$id" ] || continue
    gone=""; for o in "${offp[@]}"; do [ "$o" = "$id" ] && gone=1; done
    [ -n "$gone" ] || jq -cn --arg n "${id%%@*}" '{name: $n, enabled: true}' >> "$STUB_WORK/servers.jsonl"
  done
  jq -s . "$STUB_WORK/servers.jsonl"
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
check "codex: disables every MCP server with a bare key codex resolves" 'grep -qx "mcp_servers.alpha.enabled=false" "$work/codex.args" && grep -qx "mcp_servers.beta-2.enabled=false" "$work/codex.args" && grep -q "mcp_disabled=2" "$work/out"'
MCP_NAMES='alpha|beta.svc' cr codex "$repo" "$base" "$work/brief.md"
check "codex: refuses a server name -c can't address" '[ "$(rc)" = 3 ] && grep -q "beta.svc" "$work/err" && [ "$(last)" = STATUS=ERROR ]'
rm -f "$work/codex.args"
MCP_IGNORE=1 cr codex "$repo" "$base" "$work/brief.md"
check "codex: refuses when a server stays enabled after the overrides" '[ "$(rc)" = 3 ] && grep -q "still enabled" "$work/err" && [ ! -e "$work/codex.args" ]'
real=$(PATH=$(sed "s#$stubs:##" <<<"$PATH") command -v codex || true)
if [ -n "$real" ]; then
  # The installed codex, in a throwaway CODEX_HOME: the user's config is never read.
  home="$work/codex-home"; mkdir -p "$home"
  printf '%s\n' '[mcp_servers.alpha]' 'command = "true"' '[mcp_servers."beta-2"]' 'command = "true"' > "$home/config.toml"
  # No plugins in the throwaway home, so only the configured servers are disabled.
  rm -f "$work/codex.args"
  (cd "$work" && CODEX_HOME="$home" REAL_CODEX="$real" cr codex "$repo" "$base" "$work/brief.md")
  check "codex: the installed codex reports every server disabled under the overrides" '[ "$(rc)" = 0 ] && [ "$(last)" = STATUS=COMPLETED ] && grep -q "mcp_disabled=2" "$work/out"'
else
  echo "skip installed-codex MCP check (codex not on PATH)"
fi
# Mandatory assertions must not depend on the optional installed CLI check.
cr codex "$repo" "$base" "$work/brief.md"
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

# Plugin-provided MCP servers: an enabled Codex plugin adds a server that
# `-c mcp_servers.<name>.enabled=false` can't reach; only the plugin's own
# `plugins.<pluginId>.enabled=false` removes it.
plug='linear@claude-plugins-official|gmail@openai-curated-remote'
rm -f "$work/codex.args"
PLUGINS="$plug" cr codex "$repo" "$base" "$work/brief.md"
check "plugin: a plugin-provided server no longer blocks the review" '[ "$(rc)" = 0 ] && [ "$(last)" = STATUS=COMPLETED ] && ! grep -q "codex rejected" "$work/err"'
check "plugin: each enabled plugin is disabled by its bare ID" 'grep -qx "plugins.linear@claude-plugins-official.enabled=false" "$work/codex.args" && grep -qx "plugins.gmail@openai-curated-remote.enabled=false" "$work/codex.args"'
check "plugin: a plugin-provided server is not addressed by server name" '! grep -q "mcp_servers.linear" "$work/codex.args" && ! grep -q "mcp_servers.gmail" "$work/codex.args"'
check "plugin: configured servers are still disabled by name" 'grep -qx "mcp_servers.alpha.enabled=false" "$work/codex.args" && grep -qx "mcp_servers.beta-2.enabled=false" "$work/codex.args"'
check "plugin: the header reports the plugins disabled" 'grep -q "plugins_disabled=2" "$work/out" && grep -q "mcp_disabled=2" "$work/out"'
cr codex "$repo" "$base" "$work/brief.md"
check "plugin: no plugins installed reports plugins_disabled=0" '[ "$(rc)" = 0 ] && grep -q "plugins_disabled=0" "$work/out" && ! grep -q "^plugins\." "$work/codex.args"'
rm -f "$work/codex.args"
PLUGINS='linear@claude-plugins-official' PLUGINS_OFF='old@market' cr codex "$repo" "$base" "$work/brief.md"
check "plugin: an already-disabled plugin gets no override" '[ "$(rc)" = 0 ] && ! grep -q "plugins.old@market" "$work/codex.args" && grep -q "plugins_disabled=1" "$work/out"'
rm -f "$work/codex.args"
PLUGINS="$plug" MCP_IGNORE=1 cr codex "$repo" "$base" "$work/brief.md"
check "plugin: refuses when a server stays enabled after the overrides" '[ "$(rc)" = 3 ] && grep -q "still enabled" "$work/err" && [ ! -e "$work/codex.args" ]'
PLUGIN_LIST_FAIL=1 cr codex "$repo" "$base" "$work/brief.md"
check "plugin: refuses when the plugin list can't be read" '[ "$(rc)" = 3 ] && [ "$(last)" = STATUS=ERROR ] && [ ! -e "$work/codex.args" ]'
PLUGIN_LIST_GARBAGE=1 cr codex "$repo" "$base" "$work/brief.md"
check "plugin: refuses when the plugin list can't be parsed" '[ "$(rc)" = 3 ] && [ "$(last)" = STATUS=ERROR ] && [ ! -e "$work/codex.args" ]'
PLUGINS='foo.bar@market' cr codex "$repo" "$base" "$work/brief.md"
check "plugin: refuses a plugin ID containing a dot" '[ "$(rc)" = 3 ] && grep -q "foo.bar@market" "$work/err" && [ "$(last)" = STATUS=ERROR ] && [ ! -e "$work/codex.args" ]'
PLUGINS='a=b@market' cr codex "$repo" "$base" "$work/brief.md"
check "plugin: refuses a plugin ID containing =" '[ "$(rc)" = 3 ] && grep -q "a=b@market" "$work/err" && [ ! -e "$work/codex.args" ]'
PLUGINS_OFF='foo.bar@market' cr codex "$repo" "$base" "$work/brief.md"
check "plugin: a disabled plugin with an unaddressable ID doesn't block" '[ "$(rc)" = 0 ] && grep -q "plugins_disabled=0" "$work/out"'
# An exit-0 list that is empty or the wrong shape can't prove every plugin and
# server is off, so it refuses too, on the plugin list and on both MCP lists.
refuses() { [ "$(rc)" = 3 ] && [ "$(last)" = STATUS=ERROR ] && [ ! -e "$work/codex.args" ]; }
rm -f "$work/codex.args"
rm -f "$work/codex.args"
PLUGIN_LIST_RAW='' cr codex "$repo" "$base" "$work/brief.md"
check "plugin list: empty output with exit 0 refuses" 'refuses'
while IFS='~' read -r label raw; do
  rm -f "$work/codex.args"
  PLUGIN_LIST_RAW="$raw" cr codex "$repo" "$base" "$work/brief.md"
  check "plugin list: $label refuses" 'refuses'
done <<'CASES'
installed is an object~{"installed":{}}
no installed key~{}
top level is an array~[]
entry without pluginId~{"installed":[{"enabled":true}]}
non-string pluginId~{"installed":[{"pluginId":5,"enabled":true}]}
non-boolean enabled~{"installed":[{"pluginId":"x@m","enabled":"true"}]}
CASES
rm -f "$work/codex.args"
MCP_RAW='' cr codex "$repo" "$base" "$work/brief.md"
check "mcp list: empty output with exit 0 refuses" 'refuses'
rm -f "$work/codex.args"
MCP_RAW_FINAL='' cr codex "$repo" "$base" "$work/brief.md"
check "mcp re-list: empty output with exit 0 refuses" 'refuses'
while IFS='~' read -r label raw; do
  rm -f "$work/codex.args"
  MCP_RAW="$raw" cr codex "$repo" "$base" "$work/brief.md"
  check "mcp list: $label refuses" 'refuses'
  rm -f "$work/codex.args"
  MCP_RAW_FINAL="$raw" cr codex "$repo" "$base" "$work/brief.md"
  check "mcp re-list: $label refuses" 'refuses'
done <<'CASES'
a non-array~{}
an entry without name~[{"enabled":false}]
a non-string name~[{"name":5,"enabled":false}]
a non-object entry~["alpha"]
CASES
# A list that holds more than one JSON value can't be trusted (jq -e judges only
# the last), so it refuses on the plugin list and on both MCP lists.
nl=$'\n'
rm -f "$work/codex.args"
PLUGIN_LIST_RAW='{"installed":{}}'"$nl"'{"installed":[]}' cr codex "$repo" "$base" "$work/brief.md"
check "plugin list: two JSON values refuse" 'refuses'
rm -f "$work/codex.args"
PLUGIN_LIST_RAW='{"installed":[]}'"$nl"'{"installed":[]}' cr codex "$repo" "$base" "$work/brief.md"
check "plugin list: two valid JSON values refuse" 'refuses'
rm -f "$work/codex.args"
MCP_RAW='{}'"$nl"'[]' cr codex "$repo" "$base" "$work/brief.md"
check "mcp list: two JSON values refuse" 'refuses'
rm -f "$work/codex.args"
MCP_RAW_FINAL='{}'"$nl"'[]' cr codex "$repo" "$base" "$work/brief.md"
check "mcp re-list: two JSON values refuse" 'refuses'
# An enabled plugin or server with an empty ID or name is never skipped.
rm -f "$work/codex.args"
PLUGIN_LIST_RAW='{"installed":[{"pluginId":"","enabled":true}]}' cr codex "$repo" "$base" "$work/brief.md"
check "plugin list: an enabled plugin with an empty pluginId refuses" 'refuses'
rm -f "$work/codex.args"
MCP_RAW='[{"name":"","enabled":true}]' MCP_RAW_FINAL='[]' cr codex "$repo" "$base" "$work/brief.md"
check "mcp list: a server with an empty name refuses" 'refuses'
rm -f "$work/codex.args"
MCP_RAW_FINAL='[{"name":"","enabled":false}]' cr codex "$repo" "$base" "$work/brief.md"
check "mcp re-list: a server with an empty name refuses" 'refuses'
# Every enabled plugin ID and every server name must match [A-Za-z0-9@_-]+.
for bad in 'has space' $'line\nbreak' 'a/b' 'a"b' "a'b"; do
  rm -f "$work/codex.args"
  PLUGIN_LIST_RAW=$(jq -cn --arg id "$bad@market" '{installed: [{pluginId: $id, enabled: true}]}') cr codex "$repo" "$base" "$work/brief.md"
  check "plugin list: an enabled ID with ${bad//$'\n'/<newline>} refuses" 'refuses'
  rm -f "$work/codex.args"
  MCP_RAW=$(jq -cn --arg n "$bad" '[{name: $n, enabled: true}]') MCP_RAW_FINAL='[]' cr codex "$repo" "$base" "$work/brief.md"
  check "mcp list: a server name with ${bad//$'\n'/<newline>} refuses" 'refuses'
  rm -f "$work/codex.args"
  MCP_RAW_FINAL=$(jq -cn --arg n "$bad" '[{name: $n, enabled: false}]') cr codex "$repo" "$base" "$work/brief.md"
  check "mcp re-list: a server name with ${bad//$'\n'/<newline>} refuses" 'refuses'
done
mkdir -p "$work/home/.codex"
echo 'model = "x"' > "$work/home/.codex/config.toml"
cfg=$(sha256sum "$work/home/.codex/config.toml")
HOME="$work/home" CODEX_HOME="$work/home/.codex" PLUGINS="$plug" cr codex "$repo" "$base" "$work/brief.md"
check "plugin: the user's Codex config is never written" '[ "$(rc)" = 0 ] && [ "$(sha256sum "$work/home/.codex/config.toml")" = "$cfg" ] && [ "$(find "$work/home" -type f | wc -l)" = 1 ]'
PLUGINS="$plug" cr claude "$repo" "$base" "$work/brief.md"
check "plugin: the claude reviewer path is unchanged" '[ "$(rc)" = 0 ] && ! grep -q "plugins\." "$work/claude.args" && ! grep -q plugins_disabled "$work/out"'

cr claude "$repo" "$base" "$work/brief.md"
check "claude: completes" '[ "$(rc)" = 0 ] && [ "$(last)" = STATUS=COMPLETED ]'
check "claude: print mode, read-only tools, no shell, no MCP" 'grep -qx -- "-p" "$work/claude.args" && grep -qx -- "--tools" "$work/claude.args" && grep -qx Read "$work/claude.args" && ! grep -q "Bash" "$work/claude.args" && grep -qx -- "--strict-mcp-config" "$work/claude.args"'
check "claude: reviews a diff written beforehand" 'grep -q "change.diff" "$work/claude.stdin" && grep -q "only the empty state" "$work/claude.stdin"'

STUB_COMMIT="$repo" cr codex "$repo" "$base" "$work/brief.md"
check "a HEAD that moves during review is ERROR" '[ "$(last)" = STATUS=ERROR ] && grep -q "HEAD moved" "$work/err"'
# Fixture commits, the stub's included, never sign and never read the user's
# global or system git config (signing, hooks, identity), so an unattended run
# can't reach a signing agent.
unsigned() { local c n=0; for c in $(git -C "$1" rev-list --all); do n=$((n + 1)); git -C "$1" cat-file commit "$c" | grep -q '^gpgsig' && return 1; done; [ "$n" -gt 0 ]; }
no_user_config() { ! git -C "$1" config --show-scope --list | grep -Eq '^(global|system)[[:space:]]'; }
check "fixture: the stub's commit landed and no fixture commit is signed" '[ "$(git -C "$repo" log -1 --format=%s)" = moved ] && unsigned "$repo"'
check "fixture: git reads no global or system config" 'no_user_config "$repo"'
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

PLUGINS="$plug" cr codex --document "$doc" "$work/brief.md"
check "document codex: plugin-provided servers are disabled by plugin ID" '[ "$(rc)" = 0 ] && grep -qx "plugins.linear@claude-plugins-official.enabled=false" "$work/codex.args" && grep -q "plugins_disabled=2" "$work/out"'
PLUGIN_LIST_FAIL=1 cr codex --document "$doc" "$work/brief.md"
check "document codex: refuses when the plugin list can't be read" '[ "$(rc)" = 3 ] && [ "$(last)" = STATUS=ERROR ]'
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

# Codex connected apps: invisible to `mcp list` and not stopped by the sandbox,
# so `-c features.apps=false` is forced and checked with `features list`.
rm -f "$work/codex.args"
cr codex "$repo" "$base" "$work/brief.md"
check "apps: change mode always passes features.apps=false" '[ "$(rc)" = 0 ] && grep -qx "features.apps=false" "$work/codex.args"'
check "apps: the header reports apps off" 'grep -q "apps=off" "$work/out"'
rm -f "$work/codex.args"
cr codex --document "$doc" "$work/brief.md"
check "apps: document mode always passes features.apps=false" '[ "$(rc)" = 0 ] && grep -qx "features.apps=false" "$work/codex.args" && grep -q "apps=off" "$work/out"'
rm -f "$work/codex.args"
FEATURES_IGNORE=1 cr codex "$repo" "$base" "$work/brief.md"
check "apps: change mode refuses when apps stays on after the override" 'refuses && grep -q "apps" "$work/err"'
FEATURES_IGNORE=1 cr codex --document "$doc" "$work/brief.md"
check "apps: document mode refuses when apps stays on after the override" 'refuses'
FEATURES_FAIL=1 cr codex "$repo" "$base" "$work/brief.md"
check "apps: refuses when features list fails" 'refuses'
FEATURES_RAW='' cr codex "$repo" "$base" "$work/brief.md"
check "apps: refuses when features list prints nothing" 'refuses'
FEATURES_RAW=$'enable_mcp_apps   under development   false\napps_early_resource_discovery   under development   false\n' cr codex "$repo" "$base" "$work/brief.md"
check "apps: refuses when there is no exact apps row (prefix rows don't count)" 'refuses'
FEATURES_RAW=$'apps   stable   true\nenable_mcp_apps   under development   false\n' cr codex "$repo" "$base" "$work/brief.md"
check "apps: refuses an apps row that reads true even beside false look-alikes" 'refuses'
FEATURES_RAW=$'apps   stable   maybe\n' cr codex "$repo" "$base" "$work/brief.md"
check "apps: refuses an apps row whose value isn't false" 'refuses'
rm -f "$work/codex.args"
FEATURES_RAW=$'apps_early_resource_discovery   under development   true\napps   stable   false\n' cr codex "$repo" "$base" "$work/brief.md"
check "apps: a true look-alike row doesn't block when apps itself is false" '[ "$(rc)" = 0 ] && [ "$(last)" = STATUS=COMPLETED ]'
FEATURES_FAIL=1 cr claude "$repo" "$base" "$work/brief.md"
check "apps: the claude reviewer path is unchanged" '[ "$(rc)" = 0 ] && ! grep -q "features" "$work/claude.args" && ! grep -q "apps=" "$work/out"'

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
