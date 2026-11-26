#!/usr/bin/env bash
# Tests for eval-export.sh, using a real throwaway git repository. No network.
# usage: bash test-eval-export.sh   (needs bash and git)
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass=0 fail=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else fail=$((fail + 1)); echo "FAIL $1"; fi; }
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
# Seed a hostile scratch global config so the isolation checks also catch a
# removed export on clean CI runners. Never read or change the real user's config.
export HOME="$work/config-home" XDG_CONFIG_HOME="$work/config-home/xdg"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$work/hooks"
unset GIT_CONFIG_GLOBAL GIT_CONFIG_NOSYSTEM
printf '#!/usr/bin/env bash\nexit 1\n' > "$work/hooks/pre-commit"
chmod +x "$work/hooks/pre-commit"
git config --file "$HOME/.gitconfig" commit.gpgsign true
git config --file "$HOME/.gitconfig" gpg.format openpgp
git config --file "$HOME/.gitconfig" gpg.program /bin/false
git config --file "$HOME/.gitconfig" user.signingkey fixture
git config --file "$HOME/.gitconfig" core.hooksPath "$work/hooks"

# Ignore the user's global and system git config, so no fixture commit signs,
# runs a global hook or needs a configured identity: unattended runs never wait on a signing agent.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

# Repository: base commit, then a change commit, then an uncommitted edit.
repo="$work/repo"
git init -q -b main "$repo"
echo one > "$repo/a.txt"; git -C "$repo" add a.txt; git -C "$repo" commit -q -m base
base=$(git -C "$repo" rev-parse HEAD)
echo two > "$repo/b.txt"; git -C "$repo" add b.txt; git -C "$repo" commit -q -m "change: secret approach"
head=$(git -C "$repo" rev-parse HEAD)
echo dirty >> "$repo/a.txt"

# Fixture commits never sign and never read the user's global or system git
# config (signing, hooks, identity), so an unattended run can't reach a signing agent.
unsigned() { local c n=0; for c in $(git -C "$1" rev-list --all); do n=$((n + 1)); git -C "$1" cat-file commit "$c" | grep -q '^gpgsig' && return 1; done; [ "$n" -gt 0 ]; }
no_user_config() { ! git -C "$1" config --show-scope --list | grep -Eq '^(global|system)[[:space:]]'; }
check "fixture: both commits landed and neither is signed" '[ "$(git -C "$repo" rev-list --count HEAD)" = 2 ] && unsigned "$repo"'
check "fixture: git reads no global or system config" 'no_user_config "$repo"'

ex() { bash "$here/eval-export.sh" "$@" > "$work/out" 2> "$work/err"; echo $? > "$work/rc"; }
rc() { cat "$work/rc"; }

ex "$repo" "$head" "$base" "$work/eval"
check "export: succeeds" '[ "$(rc)" = 0 ]'
check "export: head has the change, base doesn't" '[ -f "$work/eval/head/b.txt" ] && [ ! -e "$work/eval/base/b.txt" ]'
check "export: no git history anywhere" '[ -z "$(find "$work/eval" -name .git)" ]'
check "export: commit messages don't leak" '! grep -rq "secret approach" "$work/eval"'
check "export: committed state only, not the dirty edit" '[ "$(cat "$work/eval/head/a.txt")" = one ]'
check "export: prints both paths" 'grep -q "^head: $work/eval/head$" "$work/out" && grep -q "^base: $work/eval/base$" "$work/out"'

ex "$repo" "$head" "$base" "$work/eval"
check "export: refuses a non-empty out dir" '[ "$(rc)" = 2 ]'
ex "$repo" deadbeef "$base" "$work/eval2"
check "export: unknown commit exits 2" '[ "$(rc)" = 2 ] && [ ! -e "$work/eval2" ]'
ex "$repo" "$head"
check "export: missing args exits 2" '[ "$(rc)" = 2 ]'
ex "$work/nope" "$head" "$base" "$work/eval3"
check "export: non-repo exits 2" '[ "$(rc)" = 2 ]'

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
