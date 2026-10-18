#!/usr/bin/env bash
# Call the official UniFi API (cloud connector or local console) with an API key.
# The key comes from UNIFI_API_KEY and reaches curl on stdin, never argv.
#
# usage: UNIFI_API_KEY=... bash unifi-api.sh <METHOD> <url> [body.json]
#   METHOD  GET for reads. Anything else changes state: get the user's approval first.
#   url     full URL; base URLs are in the API's openapi.json `servers`
#   body    JSON file for POST/PUT/PATCH
# Prints the response body, then "HTTP <code>" on its own line.
set -euo pipefail

[ $# -ge 2 ] || { sed -n '2,10p' "$0" >&2; exit 2; }
: "${UNIFI_API_KEY:?set UNIFI_API_KEY from your secret store}"
method=$1 url=$2 body=${3:-}

args=(-sS --max-time 30 -X "$method" -w '\nHTTP %{http_code}\n')
# Verify TLS everywhere except a private-network IP literal, where a console
# serves a self-signed certificate. The key is never sent unverified elsewhere.
host=${url#https://}; host=${host%%[/:]*}
case "$url" in https://*) ;; *) echo "refusing non-https URL" >&2; exit 2 ;; esac
if [[ $host =~ ^(10\.[0-9]+|192\.168|172\.(1[6-9]|2[0-9]|3[01]))\.[0-9]+\.[0-9]+$ ]]; then
  args+=(-k)
fi
if [ -n "$body" ]; then
  [ -f "$body" ] || { echo "no such body file: $body" >&2; exit 2; }
  args+=(-H 'Content-Type: application/json' --data "@$body")
fi

printf 'header = "X-API-Key: %s"\nheader = "Accept: application/json"\n' "$UNIFI_API_KEY" \
  | curl "${args[@]}" -K - "$url"
