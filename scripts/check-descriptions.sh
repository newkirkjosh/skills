#!/usr/bin/env bash
# Every skill description opens with the explicit-use sentence and carries no
# auto-trigger phrasing (see AGENTS.md, Explicit invocation).
set -euo pipefail
cd "$(dirname "$0")/.."

prefix='Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. '
banned='Triggers?:|auto-?trigger|MUST BE (USED|LOADED)|automatically invoked|even when the user|Use (for any|whenever)'
status=0

for f in skills/*/SKILL.md; do
  desc=$(awk 'NR==1 && $0=="---" {fm=1; next} fm && $0=="---" {exit} fm && /^description:/ {sub(/^description:[ ]*/, ""); print; exit}' "$f")
  desc=${desc#\"}; desc=${desc%\"}
  if [[ $desc != "$prefix"* ]]; then
    echo "$f: description does not open with the explicit-use sentence" >&2
    status=1
  fi
  if grep -qiE "$banned" <<<"$desc"; then
    echo "$f: description has auto-trigger phrasing: $(grep -oiE "$banned" <<<"$desc" | head -1)" >&2
    status=1
  fi
done

[ $status -eq 0 ] && echo "descriptions: ok"
exit $status
