#!/usr/bin/env bash
# Tests for unifi-api.sh and unifi-local.sh. Runs them against stub curl and jq
# that record their argv and stdin, so nothing touches a network.
# usage: bash test-scripts.sh   (needs bash and jq)
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
real_jq="$(command -v jq)" || { echo "jq is required" >&2; exit 1; }
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass=0 fail=0

ok()  { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# --- stubs -------------------------------------------------------------------
mkdir -p "$work/bin"
cat > "$work/bin/curl" <<'EOF'
#!/usr/bin/env bash
# Record argv one per line and stdin; honour -D (headers) and -c (cookie jar).
log="$STUB_LOG"; n=$(( $(cat "$log/curl.count" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$log/curl.count"
printf '%s\n' "$@" > "$log/curl.$n.argv"
cat > "$log/curl.$n.stdin"
prev=
for a in "$@"; do
  [ "$prev" = -D ] && printf 'HTTP/2 200\r\n%s\r\n\r\n' "${STUB_HEADER-x-csrf-token: tok-123}" > "$a"
  [ "$prev" = -c ] && printf '10.0.0.2\tFALSE\t/\tTRUE\t0\tTOKEN\tsession\n' > "$a"
  prev=$a
done
echo '{"meta":{"rc":"ok"},"data":[]}'
EOF
cat > "$work/bin/jq" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" > "\$STUB_LOG/jq.argv"
exec "$real_jq" "\$@"
EOF
chmod +x "$work/bin/curl" "$work/bin/jq"

# Fresh log and runtime dir per case.
reset() {
  export STUB_LOG="$work/log" XDG_RUNTIME_DIR="$work/run"
  rm -rf "$STUB_LOG" "$XDG_RUNTIME_DIR"; mkdir -p "$STUB_LOG" "$XDG_RUNTIME_DIR"
  unset STUB_HEADER
}
run() { PATH="$work/bin:$PATH" bash "$@" < /dev/null > "$work/out" 2> "$work/err"; echo $? > "$work/rc"; }
rc()  { cat "$work/rc"; }
argv() { cat "$STUB_LOG/curl.${1:-1}.argv" 2>/dev/null; }
stdin() { cat "$STUB_LOG/curl.${1:-1}.stdin" 2>/dev/null; }
called() { [ -f "$STUB_LOG/curl.count" ]; }

api="$here/unifi-api.sh" local="$here/unifi-local.sh"
key='key-SECRET-abc' pw='pw-SECRET-xyz'

# --- unifi-api.sh ------------------------------------------------------------
reset; run "$api" GET
check "api: too few args exits 2" '[ "$(rc)" = 2 ] && ! called'

reset; env -u UNIFI_API_KEY PATH="$work/bin:$PATH" bash "$api" GET https://api.ui.com/v1/hosts > /dev/null 2>&1
check "api: missing UNIFI_API_KEY fails before curl" '[ $? -ne 0 ] && ! called'

reset; UNIFI_API_KEY=$key run "$api" GET https://api.ui.com/v1/hosts
check "api: GET succeeds" '[ "$(rc)" = 0 ]'
check "api: key not in curl argv" '! argv | grep -q SECRET'
check "api: key sent as header on stdin" 'stdin | grep -q "X-API-Key: $key"'
check "api: cloud URL keeps TLS verification" '! argv | grep -qx -- -k'
check "api: method passed through" 'argv | grep -qx GET'

reset; UNIFI_API_KEY=$key run "$api" GET https://10.0.0.2/proxy/network/integration/v1/sites
check "api: private console IP skips verification for self-signed cert" 'argv | grep -qx -- -k'
reset; UNIFI_API_KEY=$key run "$api" GET https://10.0.0.2@example.com/x
check "api: userinfo trick does not disable verification" '! argv | grep -qx -- -k'

for u in https://example.com/x https://203.0.113.5/x https://192.168.1.1.example.com/x; do
  reset; UNIFI_API_KEY=$key run "$api" GET "$u"
  check "api: verifies TLS for $u" '! argv | grep -qx -- -k'
done
for u in https://10.0.0.1/x https://172.16.5.4:8443/x; do
  reset; UNIFI_API_KEY=$key run "$api" GET "$u"
  check "api: skips verification for private IP $u" 'argv | grep -qx -- -k'
done
reset; UNIFI_API_KEY=$key run "$api" GET http://192.0.2.1/x
check "api: refuses non-https URL before curl" '[ "$(rc)" = 2 ] && ! called'

reset; echo '{"name":"x"}' > "$work/body.json"
UNIFI_API_KEY=$key run "$api" POST https://api.ui.com/x "$work/body.json"
check "api: body file sent with --data @file" 'argv | grep -qx -- "--data" && argv | grep -qx "@$work/body.json"'

reset; UNIFI_API_KEY=$key run "$api" POST https://api.ui.com/x "$work/missing.json"
check "api: missing body file exits 2 before curl" '[ "$(rc)" = 2 ] && ! called'

# --- unifi-local.sh ----------------------------------------------------------
export UNIFI_HOST=https://10.0.0.2

reset; env -u UNIFI_HOST PATH="$work/bin:$PATH" bash "$local" get /x > /dev/null 2>&1
check "local: missing UNIFI_HOST fails before curl" '[ $? -ne 0 ] && ! called'

reset; UNIFI_HOST=https://unifi.example.com UNIFI_USER=viewer UNIFI_PASS=$pw run "$local" login
check "local: hostname console keeps TLS verification" '! argv | grep -qx -- -k'
reset; UNIFI_USER=viewer UNIFI_PASS=$pw run "$local" login
check "local: private console IP skips verification" 'argv | grep -qx -- -k'
reset; UNIFI_HOST=http://10.0.0.2 run "$local" login
check "local: refuses non-https UNIFI_HOST" '[ "$(rc)" = 2 ] && ! called'

reset; run "$local" bogus
check "local: unknown mode exits 2" '[ "$(rc)" = 2 ] && ! called'

reset; env -u UNIFI_PASS UNIFI_USER=viewer PATH="$work/bin:$PATH" bash "$local" login > /dev/null 2>&1
check "local: login without UNIFI_PASS fails before curl" '[ $? -ne 0 ] && ! called'

reset; run "$local" get /x
check "local: get without a session exits 1 before curl" '[ "$(rc)" = 1 ] && ! called && grep -q "run .unifi-local.sh login" "$work/err"'

reset; run "$local" query /proxy/network/v2/api/site/default/system-log/all '{}'
check "local: query without a session exits 1 before curl" '[ "$(rc)" = 1 ] && ! called'

reset; UNIFI_USER=viewer UNIFI_PASS=$pw run "$local" login
sess="$XDG_RUNTIME_DIR/unifi-local-$(id -u)"
check "local: login succeeds" '[ "$(rc)" = 0 ]'
check "local: password not in curl argv" '! argv | grep -q SECRET'
check "local: password not in jq argv" '! grep -q SECRET "$STUB_LOG/jq.argv"'
check "local: credentials sent as JSON on stdin" '[ "$(stdin | "$real_jq" -r .password)" = "$pw" ] && [ "$(stdin | "$real_jq" -r .username)" = viewer ]'
check "local: login posts to /api/auth/login" 'argv | grep -qx "$UNIFI_HOST/api/auth/login"'
check "local: CSRF token stored as curl config" 'grep -qx "header = \"X-CSRF-Token: tok-123\"" "$sess/csrf.cfg"'
check "local: session dir is private" '[ "$(stat -c %a "$sess")" = 700 ]'
check "local: token file is private" '[ "$(stat -c %a "$sess/csrf.cfg")" = 600 ]'
check "local: raw response headers removed" '[ ! -e "$sess/headers" ]'

reset; STUB_HEADER='x-other: 1' UNIFI_USER=viewer UNIFI_PASS=$pw run "$local" login
check "local: login without CSRF token exits 1" '[ "$(rc)" = 1 ]'

reset; UNIFI_USER=viewer UNIFI_PASS=$pw run "$local" login
run "$local" get /proxy/network/api/s/default/stat/sta
check "local: get sends cookie jar to the full URL" 'argv 2 | grep -qx -- -b && argv 2 | grep -qx "$UNIFI_HOST/proxy/network/api/s/default/stat/sta"'
check "local: get never POSTs" '! argv 2 | grep -qx -- "--data"'

reset; UNIFI_USER=viewer UNIFI_PASS=$pw run "$local" login; rm "$STUB_LOG/curl.count"
run "$local" query /proxy/network/api/s/default/rest/wlanconf '{"x":1}'
check "local: query refuses non-read POST" '[ "$(rc)" = 2 ] && ! called'

reset; UNIFI_USER=viewer UNIFI_PASS=$pw run "$local" login
run "$local" query /proxy/network/v2/api/site/default/system-log/all '{"pageSize":1}'
check "local: query allows system-log" '[ "$(rc)" = 0 ]'
check "local: CSRF token not in argv" '! argv 2 | grep -q tok-123'
check "local: token passed via -K config file" 'argv 2 | grep -qx "$sess/csrf.cfg"'
check "local: query body sent on stdin" '[ "$(stdin 2)" = "{\"pageSize\":1}" ]'

run "$local" query /proxy/network/api/s/default/stat/report/5minutes.user '{}'
check "local: query allows stat/report" '[ "$(rc)" = 0 ]'

rm "$STUB_LOG/curl.count"
for p in '/proxy/network/v2/api/site/default/system-log/../../../rest/wlanconf' \
         '/proxy/network/api/s/default/rest/wlanconf?x=/system-log/' \
         '/proxy/network/api/s/default/rest/wlanconf#/stat/report/' \
         '/proxy/network/v2/api/site/default/system-log/%2e%2e/x' \
         '/proxy/network/api/s/default/stat/report/5minutes.user/../../../rest/x' \
         '/proxy/network/api/s/default/cmd/devmgr/stat/report/x.y'; do
  run "$local" query "$p" '{}'
  check "local: query refuses $p" '[ "$(rc)" = 2 ] && ! called'
done
run "$local" get '@example.com/x'
check "local: get refuses path not starting with /" '[ "$(rc)" = 2 ] && ! called'
run "$local" get '/proxy/../api/x'
check "local: get refuses .. in path" '[ "$(rc)" = 2 ] && ! called'

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
