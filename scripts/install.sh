#!/usr/bin/env bash
# Link every skill in this catalog into an agent's skills directory.
# Symlinks, not copies, so an edit in the checkout takes effect on the next
# skill load. Re-run after adding, renaming or deleting a skill: it links new
# skills and removes links that point into this catalog but no longer resolve.
# Also opts this checkout into the global private-term commit check.
#
# usage: scripts/install.sh [target-dir ...]
#   default: ~/.claude/skills (Claude Code) and ~/.agents/skills (Codex)
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills" && pwd)"
targets=("$@")
[ ${#targets[@]} -gt 0 ] || targets=("$HOME/.claude/skills" "$HOME/.agents/skills")

for target in "${targets[@]}"; do
  mkdir -p "$target"

  for link in "$target"/*; do
    [ -L "$link" ] || continue
    case "$(readlink "$link")" in
      "$src"/*) [ -e "$link" ] || { rm "$link"; echo "removed stale $(basename "$link")"; } ;;
    esac
  done

  for dir in "$src"/*/; do
    name="$(basename "$dir")"
    dest="$target/$name"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
      echo "skip $name: $dest exists and is not a link" >&2
      continue
    fi
    ln -sfn "${dir%/}" "$dest"
  done

  echo "linked $(find "$target" -maxdepth 1 -type l -lname "$src/*" | wc -l) skills into $target"
done

# The catalog is public: the global hooks (~/.config/git/hooks, from the
# dotfiles) block commits that add private terms in opted-in repos.
git -C "$src/.." config privacy.public true
