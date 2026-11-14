#!/usr/bin/env bash
# Fail on references a skill makes that don't resolve: bundled files
# (`references/x.md`, `scripts/x`, `assets/x`) that don't exist in the skill's
# folder, and "the `name` skill" / "Invoke `name`" mentions of a skill that
# isn't in this catalog. Namespaced plugin skills (`plugin:skill`) and the
# names in EXTERNAL are allowed because they come from elsewhere.
set -euo pipefail

root="${CHECK_REFS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
EXTERNAL=" artifact-design research skill-creator code-review simplify "
status=0

for dir in "$root"/skills/*/; do
  skill="$(basename "$dir")"
  files=("$dir"SKILL.md)
  [ -d "$dir/references" ] && files+=("$dir"references/*.md)

  while IFS= read -r ref; do
    [ -e "$dir$ref" ] || { echo "$skill: missing bundled file $ref"; status=1; }
  done < <(grep -hoE '`(references|scripts|assets)/[^` ]+`' "${files[@]}" | tr -d '`' | sort -u)

  while IFS= read -r name; do
    case "$name" in *:*) continue ;; esac
    case "$EXTERNAL" in *" $name "*) continue ;; esac
    [ -d "$root/skills/$name" ] || { echo "$skill: references unknown skill \`$name\`"; status=1; }
  done < <(grep -hoE '(the `[a-z0-9:-]+` skill|[Ii]nvoke (the )?`[a-z0-9:-]+`|[Cc]all (the )?`[a-z0-9:-]+`)' "${files[@]}" | grep -oE '`[a-z0-9:-]+`' | tr -d '`' | grep -v ':$' | sort -u)
  # A named pipeline stage in a description is an invocation, not ordinary prose.
  description=$(sed -n '/^description:/p' "$dir/SKILL.md")
  if [[ $description == *"sequences "* ]]; then
    stages=${description#*sequences }
    while IFS= read -r stage; do
      [ -z "$stage" ] && continue
      [ -d "$root/skills/$stage" ] || { echo "$skill: unknown description stage $stage"; status=1; }
    done < <(printf '%s\n' "$stages" | grep -oE '`[a-z0-9-]+`' | tr -d '`')
    # Bare retired skill names as comma-delimited stages (not words in prose).
    for stage in pr gh-issues github resolve-pr-feedback; do
      if printf '%s\n' "$stages" | grep -qE "(^|, )$stage(,| and |\.)"; then
        [ -d "$root/skills/$stage" ] || { echo "$skill: unknown description stage $stage"; status=1; }
      fi
    done
  fi
done

[ "$status" -eq 0 ] && echo "all skill references resolve"
exit "$status"
