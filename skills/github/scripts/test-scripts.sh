#!/usr/bin/env bash
# Tests for head-status.sh, wait-for-ci.sh and check-body-wrap.sh, against a
# stub gh that replays canned responses. No network.
# usage: bash test-scripts.sh   (needs bash and jq)
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v jq > /dev/null || { echo "jq is required" >&2; exit 1; }
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass=0 fail=0

ok()  { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# --- stub gh -----------------------------------------------------------------
# gh api graphql -> $STUB/graphql.json ; gh run list -> $STUB/runs.<n>.json
# (the last file repeats) ; gh repo view -> owner/repo. argv logged per call.
mkdir -p "$work/bin"
cat > "$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
n=$(( $(cat "$STUB/count" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$STUB/count"
printf '%s\n' "$@" > "$STUB/argv.$n"
case "$1 $2" in
  "api graphql") cat "$STUB/graphql.json" ;;
  "repo view")   echo "example/repo" ;;
  "run list")
    r=$(( $(cat "$STUB/runs.count" 2>/dev/null || echo 0) + 1 )); echo "$r" > "$STUB/runs.count"
    f="$STUB/runs.$r.json"; [ -f "$f" ] || f=$(ls "$STUB"/runs.[0-9]*.json | sort -t. -k2 -n | tail -1)
    [ -n "${STUB_RUN_FAIL:-}" ] && { echo "HTTP 502" >&2; exit 1; }
    cat "$f" ;;
  *) echo "unexpected gh call: $*" >&2; exit 99 ;;
esac
EOF
chmod +x "$work/bin/gh"

reset() { export STUB="$work/stub"; rm -rf "$STUB"; mkdir -p "$STUB"; unset STUB_RUN_FAIL; }
run() { PATH="$work/bin:$PATH" bash "$@" < /dev/null > "$work/out" 2> "$work/err"; echo $? > "$work/rc"; }
rc()  { cat "$work/rc"; }
out() { cat "$work/out"; }
field() { jq -r "$1" "$work/out"; }
calls() { cat "$STUB/count" 2>/dev/null || echo 0; }

hs="$here/head-status.sh" wfc="$here/wait-for-ci.sh" wrap="$here/check-body-wrap.sh"
HEAD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa OLD=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb

gql() {  # $1 rollup-commit-oid $2 rollup-state $3 threads-total
  cat > "$STUB/graphql.json" <<EOF
{"data":{"repository":{"pullRequest":{"state":"OPEN","headRefOid":"$HEAD",
 "commits":{"nodes":[{"commit":{"oid":"$1","statusCheckRollup":{"state":"$2"}}}]},
 "reviews":{"nodes":[
   {"author":{"login":"alice"},"state":"APPROVED","commit":{"oid":"$OLD"}},
   {"author":{"login":"bot"},"state":"COMMENTED","commit":{"oid":"$HEAD"}}]},
 "reviewThreads":{"totalCount":${3:-3},"nodes":[{"isResolved":true},{"isResolved":false},{"isResolved":false}]}}}}}
EOF
}

# --- head-status.sh ------------------------------------------------------------
reset; run "$hs"
check "head-status: no PR number exits 2 before gh" '[ "$(rc)" = 2 ] && [ "$(calls)" = 0 ]'
reset; run "$hs" '12; rm -rf /'
check "head-status: non-numeric PR exits 2" '[ "$(rc)" = 2 ] && [ "$(calls)" = 0 ]'
reset; run "$hs" 12 'not a repo'
check "head-status: bad owner/repo exits 2" '[ "$(rc)" = 2 ] && [ "$(calls)" = 0 ]'

reset; gql "$HEAD" SUCCESS; run "$hs" 12 example/repo
check "head-status: succeeds" '[ "$(rc)" = 0 ]'
check "head-status: reports head SHA" '[ "$(field .head)" = "$HEAD" ]'
check "head-status: rollup read for the head commit" '[ "$(field .checks)" = SUCCESS ]'
check "head-status: only head-commit reviews count" '[ "$(field ".reviews_on_head|length")" = 1 ] && [ "$(field ".reviews_on_head[0].author")" = bot ]'
check "head-status: older approval counted separately" '[ "$(field .reviews_on_older_commits)" = 1 ]'
check "head-status: unresolved threads counted" '[ "$(field .unresolved_threads)" = 2 ]'
check "head-status: PR number passed typed with -F" 'grep -qx -- -F "$STUB/argv.1" && grep -qx "pr=12" "$STUB/argv.1"'
check "head-status: owner and repo split" 'grep -qx "owner=example" "$STUB/argv.1" && grep -qx "repo=repo" "$STUB/argv.1"'

reset; gql "$OLD" SUCCESS; run "$hs" 12 example/repo
check "head-status: rollup from another commit is NONE" '[ "$(field .checks)" = NONE ]'

reset; gql "$HEAD" FAILURE 250; run "$hs" 12 example/repo
check "head-status: flags truncated thread list" '[ "$(field .threads_truncated)" = true ]'

reset; gql "$HEAD" SUCCESS; run "$hs" 12
check "head-status: defaults to current repo" 'grep -qx view "$STUB/argv.1" && grep -qx "owner=example" "$STUB/argv.2"'

reset; echo '{"errors":[{"message":"Could not resolve"}],"data":{"repository":{"pullRequest":null}}}' > "$STUB/graphql.json"
run "$hs" 999 example/repo
check "head-status: missing PR exits non-zero" '[ "$(rc)" != 0 ]'

# --- wait-for-ci.sh ------------------------------------------------------------
export WAIT_INTERVAL=0
runs() { echo "$2" > "$STUB/runs.$1.json"; }
done_ok='[{"databaseId":1,"name":"CI","status":"completed","conclusion":"success"},{"databaseId":2,"name":"Lint","status":"completed","conclusion":"skipped"}]'

reset; run "$wfc"
check "wait: no SHA exits 2" '[ "$(rc)" = 2 ] && [ "$(calls)" = 0 ]'
reset; run "$wfc" 'main; echo hi'
check "wait: non-hex SHA exits 2" '[ "$(rc)" = 2 ] && [ "$(calls)" = 0 ]'
reset; run "$wfc" "$HEAD" soon
check "wait: non-numeric timeout exits 2" '[ "$(rc)" = 2 ]'

reset; runs 1 "$done_ok"; run "$wfc" "$HEAD" 1
check "wait: all passed exits 0" '[ "$(rc)" = 0 ] && out | grep -q "^STATUS=PASS runs=2"'
check "wait: filters runs by the commit" 'grep -qx -- --commit "$STUB/argv.1" && grep -qx "$HEAD" "$STUB/argv.1"'

reset; runs 1 '[]'; runs 2 '[{"databaseId":3,"name":"CI","status":"in_progress","conclusion":""}]'; runs 3 "$done_ok"
run "$wfc" "$HEAD" 1
check "wait: waits for runs to appear and finish" '[ "$(rc)" = 0 ] && [ "$(cat "$STUB/runs.count")" = 3 ]'

reset; runs 1 '[{"databaseId":1,"name":"CI","status":"completed","conclusion":"success"},{"databaseId":2,"name":"Test","status":"in_progress","conclusion":""}]'
runs 2 '[{"databaseId":1,"name":"CI","status":"completed","conclusion":"success"},{"databaseId":2,"name":"Test","status":"completed","conclusion":"failure"}]'
run "$wfc" "$HEAD" 1
check "wait: does not pass while one run is open" '[ "$(cat "$STUB/runs.count")" = 2 ]'
check "wait: a failed run exits 1" '[ "$(rc)" = 1 ] && out | grep -q "^STATUS=FAIL"'
check "wait: names the failed run" 'out | grep -q "^failure	Test	2"'

reset; runs 1 '[{"databaseId":1,"name":"CI","status":"completed","conclusion":"cancelled"}]'; run "$wfc" "$HEAD" 1
check "wait: cancelled counts as failure" '[ "$(rc)" = 1 ]'

reset; runs 1 '[]'; WAIT_APPEAR_MIN=0 run "$wfc" "$HEAD" 1
check "wait: no run appearing exits 4" '[ "$(rc)" = 4 ] && out | grep -q "^STATUS=NO_RUNS"'

reset; runs 1 '[{"databaseId":1,"name":"CI","status":"queued","conclusion":""}]'; run "$wfc" "$HEAD" 0
check "wait: deadline exits 3 and lists open runs" '[ "$(rc)" = 3 ] && out | grep -q "^STATUS=TIMEOUT open=1" && out | grep -q "^queued	CI"'

reset; runs 1 '[]'; STUB_RUN_FAIL=1 WAIT_APPEAR_MIN=0 run "$wfc" "$HEAD" 1
check "wait: gh errors are reported, not treated as pass" '[ "$(rc)" = 4 ] && grep -q "gh run list failed" "$work/err"'

reset; runs 1 "$done_ok"; run "$wfc" "$HEAD" 1 other/repo
check "wait: passes -R for an explicit repo" 'grep -qx -- -R "$STUB/argv.1" && grep -qx other/repo "$STUB/argv.1"'

# --- check-body-wrap.sh ----------------------------------------------------------
w() { printf '%b' "$1" | bash "$wrap" > "$work/out" 2>&1; echo $? > "$work/rc"; }
long=$(printf 'word %.0s' {1..40})
wrapped='This paragraph was wrapped by hand at about seventy-two columns so\nthat it looks tidy in a terminal but renders ragged once GitHub has\nreflowed it for a narrow window, which is the failure being caught.\n'

w "## Summary\n\n$long\n\n$long\n";            check "wrap: one line per paragraph passes" '[ "$(rc)" = 0 ]'
w "$wrapped";                                   check "wrap: hard-wrapped prose fails" '[ "$(rc)" = 1 ] && grep -q HARD-WRAPPED "$work/out"'
w "\`\`\`\n${wrapped}\`\`\`\n$long\n";          check "wrap: fenced code is skipped" '[ "$(rc)" = 0 ]'
w "\`\`\`\`\n\`\`\`\n${wrapped}\`\`\`\`\n$long\n"; check "wrap: shorter fence inside a longer one stays code" '[ "$(rc)" = 0 ]'
w "- item one that is long enough to land inside the sixty column band\n  and its continuation line, also long enough to land in the band ok\n$long\n"
check "wrap: list items and continuations are skipped" '[ "$(rc)" = 0 ]'
w "| a column that is long enough to land in the sixty column band | b |\n| another row that is long enough to land in the sixty col band | c |\n$long\n"
check "wrap: table rows are skipped" '[ "$(rc)" = 0 ]'
w "";                                           check "wrap: empty body passes" '[ "$(rc)" = 0 ] && grep -q "no prose" "$work/out"'

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
