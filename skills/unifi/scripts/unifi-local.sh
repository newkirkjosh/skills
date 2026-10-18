#!/usr/bin/env bash
# Read from a UniFi console's web-UI API with a local (ideally View Only) account.
# Credentials come from the environment and reach curl on stdin, never argv.
#
# usage: bash unifi-local.sh login                 needs UNIFI_USER, UNIFI_PASS
#        bash unifi-local.sh get <path>            e.g. /proxy/network/api/s/default/stat/sta
#        bash unifi-local.sh query <path> <json>   POST, only for log and report queries
# All modes need UNIFI_HOST, e.g. https://<console-ip>.
# get and query print the response body, then "HTTP <code>" on its own line.
set -euo pipefail

: "${UNIFI_HOST:?set UNIFI_HOST, e.g. https://<console-ip>}"
dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/unifi-local-$(id -u)"
mkdir -p "$dir" && chmod 700 "$dir"
jar=$dir/cookies token=$dir/csrf.cfg
# Consoles use a self-signed certificate on the LAN.
curl_base=(curl -sS -k --max-time 30)

case "${1:-}" in
login)
  : "${UNIFI_USER:?set UNIFI_USER}" "${UNIFI_PASS:?set UNIFI_PASS from your secret store}"
  umask 077
  # jq reads both from the environment; --arg would put the password in argv.
  jq -nc '{username: env.UNIFI_USER, password: env.UNIFI_PASS, rememberMe: false}' \
    | "${curl_base[@]}" -c "$jar" -H 'Content-Type: application/json' --data @- \
        -D "$dir/headers" -o /dev/null -w 'HTTP %{http_code}\n' "$UNIFI_HOST/api/auth/login"
  # Stored as a curl config file so the token never appears in argv.
  tr -d '\r' < "$dir/headers" \
    | awk -F': ' 'tolower($1)=="x-csrf-token"{printf "header = \"X-CSRF-Token: %s\"\n", $2}' > "$token"
  rm -f "$dir/headers"
  [ -s "$token" ] || { echo "login failed: no CSRF token returned" >&2; exit 1; } ;;
get|query)
  [ -s "$jar" ] && [ -s "$token" ] || { echo "no session: run 'unifi-local.sh login' first" >&2; exit 1; } ;;&
get)
  [ $# -eq 2 ] || { echo "usage: unifi-local.sh get <path>" >&2; exit 2; }
  "${curl_base[@]}" -b "$jar" -w '\nHTTP %{http_code}\n' "$UNIFI_HOST$2" ;;
query)
  [ $# -eq 3 ] || { echo "usage: unifi-local.sh query <path> <json>" >&2; exit 2; }
  case "$2" in
    */system-log/*|*/stat/report/*) ;;
    *) echo "refusing POST to $2: query mode is for log and report reads only" >&2; exit 2 ;;
  esac
  printf '%s' "$3" | "${curl_base[@]}" -b "$jar" -K "$token" \
    -H 'Content-Type: application/json' --data @- -w '\nHTTP %{http_code}\n' "$UNIFI_HOST$2" ;;
*)
  sed -n '2,10p' "$0" >&2; exit 2 ;;
esac
