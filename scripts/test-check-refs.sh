#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/skills/dev"
check() { CHECK_REFS_ROOT="$work" bash "$here/check-refs.sh" > "$work/out" 2>&1; }
printf '%s\n' '# Example' 'Use ordinary shell, GitHub links https://github.com/owner/repo and gh pr view.' > "$work/skills/dev/SKILL.md"
check
for text in 'Invoke `gh-issues`' 'invoke the `missing` skill' 'Call `missing`' 'Read `scripts/missing.sh`' 'description: sequences scope brief, pr, review and archive.'; do
 printf '%s\n' "$text" > "$work/skills/dev/SKILL.md"
 if check; then echo "accepted missing reference: $text"; exit 1; fi
done
printf '%s\n' 'description: sequences `code-review` and `dev`.' > "$work/skills/dev/SKILL.md"
check
echo 'reference checker offline tests passed'
