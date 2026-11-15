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

# Retired links reached through an alias are still owned by the catalog.
ln -s "$tmp/catalog-link/skills/retired" "$tmp/target/retired"
ln -s "$tmp/other-missing" "$tmp/target/unrelated"
bash "$repo/scripts/install.sh" "$tmp/target" >/dev/null
if [ -L "$tmp/target/retired" ]; then
  echo "FAIL: alias-spelled retired link survived"; fail=1
fi
[ -L "$tmp/target/unrelated" ] || { echo "FAIL: unrelated link pruned"; fail=1; }

# Outside any git checkout: refuses, links nothing.
mkdir -p "$tmp/plain/scripts" "$tmp/plain/skills/alpha"
cp "$here/install.sh" "$tmp/plain/scripts/"
if GIT_CEILING_DIRECTORIES="$tmp" bash "$tmp/plain/scripts/install.sh" "$tmp/target-plain" 2>/dev/null; then
  echo "FAIL: install.sh succeeded outside a git checkout"; fail=1
fi
if [ -e "$tmp/target-plain/alpha" ]; then
  echo "FAIL: install.sh linked a skill outside a git checkout"; fail=1
fi

# Foreign links (including broken links) and real directories survive refusal.
for kind in foreign broken directory; do
  target="$tmp/collision-$kind"
  mkdir -p "$target" "$tmp/other"
  case "$kind" in
    foreign) ln -s "$tmp/other" "$target/alpha" ;;
    broken) ln -s "$tmp/missing" "$target/alpha" ;;
    directory) mkdir "$target/alpha" ;;
  esac
  ln -s "$repo/skills/retired" "$target/retired"
  if bash "$repo/scripts/install.sh" "$target" >/dev/null 2>&1; then
    echo "FAIL: accepted $kind collision"; fail=1
  fi
  [ -L "$target/retired" ] || { echo "FAIL: pruned before preflight"; fail=1; }
  if [ "$kind" = directory ]; then
    [ -d "$target/alpha" ] && [ ! -L "$target/alpha" ] || { echo "FAIL: collision path changed ($kind)"; fail=1; }
  else
    [ "$(readlink "$target/alpha")" != "$repo/skills/alpha" ] || { echo "FAIL: collision path changed ($kind)"; fail=1; }
  fi
done

[ "$fail" -eq 0 ] && echo "install: ok"
exit "$fail"
