#!/usr/bin/env bash
# Tests for install.sh: links from the main checkout, refuses from a worktree.
# Builds a throwaway catalog repo; needs git, no network.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0

repo="$tmp/catalog"
mkdir -p "$repo/scripts" "$repo/skills/alpha"
cp "$here/install.sh" "$repo/scripts/"
echo "# alpha" > "$repo/skills/alpha/SKILL.md"
git -C "$repo" init -q
git -C "$repo" -c user.name=t -c user.email=t@example.com add -A
git -C "$repo" -c user.name=t -c user.email=t@example.com -c commit.gpgsign=false commit -qm init
git -C "$repo" worktree add -q "$tmp/wt" -b wt

# From a worktree: refuses, links nothing.
if bash "$tmp/wt/scripts/install.sh" "$tmp/target-wt" 2>/dev/null; then
  echo "FAIL: install.sh succeeded from a worktree"; fail=1
fi
if [ -e "$tmp/target-wt/alpha" ]; then
  echo "FAIL: install.sh linked a skill from a worktree"; fail=1
fi

# From the main checkout: links into the main checkout.
bash "$repo/scripts/install.sh" "$tmp/target" >/dev/null
if [ "$(readlink "$tmp/target/alpha")" != "$(cd "$repo/skills/alpha" && pwd)" ]; then
  echo "FAIL: alpha not linked to the main checkout"; fail=1
fi

# From the main checkout reached through a symlink (a symlinked home):
# still allowed.
ln -s "$repo" "$tmp/catalog-link"
if ! bash "$tmp/catalog-link/scripts/install.sh" "$tmp/target-link" >/dev/null 2>&1; then
  echo "FAIL: install.sh refused the main checkout reached through a symlink"; fail=1
fi

[ "$fail" -eq 0 ] && echo "install: ok"
exit "$fail"
