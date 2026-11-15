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

# Run from a linked worktree, every installed link would point at that
# worktree's unmerged copy, and every running session would load it.
# Compare physical paths: a symlinked home makes the same directory read
# differently through each git query. Stop before touching any link if git
# can't find the checkout at all.
if ! git_rel="$(git -C "$src" rev-parse --git-dir 2>/dev/null)" ||
  ! common_rel="$(git -C "$src" rev-parse --git-common-dir 2>/dev/null)"; then
  echo "install.sh: $(dirname "$src") is not a git checkout" >&2
  exit 1
fi
git_dir="$(cd "$src" && cd "$git_rel" && pwd -P)"
common_dir="$(cd "$src" && cd "$common_rel" && pwd -P)"
if [ "$git_dir" != "$common_dir" ]; then
  echo "install.sh: run from the main checkout, not a worktree ($(dirname "$src"))" >&2
  exit 1
fi

src_phys="$(cd "$src" && pwd -P)"

targets=("$@")
[ ${#targets[@]} -gt 0 ] || targets=("$HOME/.claude/skills" "$HOME/.agents/skills")

# Refuse collisions before linking or pruning anything in any target.
resolve_link() {
  local resolved
  resolved="$(readlink -f "$1")" && [ -n "$resolved" ] || {
    echo "install.sh: cannot resolve $1" >&2
    return 1
  }
  printf '%s\n' "$resolved"
}

for target in "${targets[@]}"; do
  for link in "$target"/*; do
    [ -L "$link" ] || continue
    resolve_link "$link" >/dev/null || exit 1
  done
  for dir in "$src"/*/; do
    dest="$target/$(basename "$dir")"
    if [ -L "$dest" ]; then
      dest_phys="$(resolve_link "$dest")" || exit 1
      skill_phys="$(resolve_link "${dir%/}")" || exit 1
      if [ "$dest_phys" != "$skill_phys" ]; then
        echo "install.sh: foreign link collision: $dest" >&2
        exit 1
      fi
    elif [ -e "$dest" ]; then
      echo "install.sh: existing path collision: $dest" >&2
      exit 1
    fi
  done
done

for target in "${targets[@]}"; do
  mkdir -p "$target"

  for link in "$target"/*; do
    [ -L "$link" ] || continue
    link_phys="$(resolve_link "$link")" || exit 1
    case "$link_phys" in
      "$src_phys"/*) [ -e "$link" ] || { rm "$link"; echo "removed stale $(basename "$link")"; } ;;
    esac
  done

  for dir in "$src"/*/; do
    name="$(basename "$dir")"
    dest="$target/$name"
    ln -sfn "${dir%/}" "$dest"
  done

  echo "linked $(find "$target" -maxdepth 1 -type l -lname "$src/*" | wc -l) skills into $target"
done

# The catalog is public: the global hooks (~/.config/git/hooks, from the
# dotfiles) block commits that add private terms in opted-in repos.
git -C "$src/.." config privacy.public true
