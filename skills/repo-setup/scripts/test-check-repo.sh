#!/usr/bin/env bash
# Tests for check-repo.sh against throwaway git repositories. No network:
# REPO_VISIBILITY replaces the gh lookup.
# usage: bash test-check-repo.sh   (needs bash and git)
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass=0 fail=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else fail=$((fail + 1)); echo "FAIL $1"; fi; }

new() { rm -rf "$work/r"; git init -q "$work/r"; }
run() { REPO_VISIBILITY=${VIS:-PRIVATE} bash "$here/check-repo.sh" "$work/r" > "$work/out" 2> "$work/err"; echo $? > "$work/rc"; }
rc() { cat "$work/rc"; }
has() { grep -q "^$1 $2 " "$work/out"; }

# A fully adopted private repository.
adopted() {
  new
  echo "@AGENTS.md" > "$work/r/CLAUDE.md"
  printf '# P\n\n## Layers\n:a\n\n## Tracker\nLinear\n\n## Pull requests\nlabels\n\n## Merge policy\nnone\n\n## Code Review Rules\n\nRead `REVIEW.md` and apply it.\n\n## Testing\nx\n' > "$work/r/AGENTS.md"
  echo "# PR Review" > "$work/r/REVIEW.md"
  printf 'knowledge_base:\n  code_guidelines:\n    enabled: true\n    filePatterns:\n      - "**/REVIEW.md"\n' > "$work/r/.coderabbit.yaml"
  mkdir -p "$work/r/.github/workflows"
  printf 'on:\n  push:\n  pull_request:\njobs:\n  secrets:\n    steps:\n      - uses: actions/checkout@v4\n        with:\n          fetch-depth: 0\n      - run: gitleaks git --log-opts="--all --full-history -m" --redact --no-banner .\n' > "$work/r/.github/workflows/ci.yml"
}

adopted; run
check "adopted private repo: exit 0" '[ "$(rc)" = 0 ]'
check "adopted private repo: every item ok or n/a" '! grep -qvE "^(ok|n/a) " "$work/out"'

new; run
check "empty repo: exit 1" '[ "$(rc)" = 1 ]'
check "empty repo: instruction files missing" 'has missing claude-pointer && has missing agents && has missing review'
check "empty repo: decisions left to the user" 'has decide layers && has decide merge-policy'

adopted; echo "Use tabs." >> "$work/r/CLAUDE.md"; run
check "CLAUDE.md with content is stale (M1)" 'has stale claude-pointer && [ "$(rc)" = 1 ]'

adopted; rm "$work/r/CLAUDE.md"; ln -s AGENTS.md "$work/r/CLAUDE.md"; run
check "symlinked CLAUDE.md is stale" 'has stale claude-pointer'

adopted; mv "$work/r/REVIEW.md" "$work/r/R.md"; ln -s R.md "$work/r/REVIEW.md"; run
check "symlinked REVIEW.md is flagged" 'has stale symlink'

adopted; sed -i 's/Read `REVIEW.md` and apply it./See the docs./' "$work/r/AGENTS.md"; run
check "bridge must name REVIEW.md inside its own section" 'has missing review-bridge'

adopted; printf '\n## Notes\nREVIEW.md exists.\n' >> "$work/r/AGENTS.md"; sed -i '/^## Code Review Rules/,/^## Testing/{/REVIEW.md/d}' "$work/r/AGENTS.md"; run
check "REVIEW.md named in another section doesn't count" 'has missing review-bridge'

adopted; mkdir -p "$work/r/.github"; echo x > "$work/r/.github/copilot-instructions.md"; run
check "copilot-instructions.md is stale (M2)" 'has stale copilot-instructions'

adopted; rm "$work/r/.github/workflows/ci.yml"; run
check "no gitleaks job is missing" 'has missing secrets-ci'

adopted; printf '# TODO: add gitleaks\non: push\n' > "$work/r/.github/workflows/ci.yml"; run
check "a gitleaks comment is not a scan" 'has missing secrets-ci'

adopted; sed -i '/fetch-depth/d' "$work/r/.github/workflows/ci.yml"; run
check "a shallow checkout is not a full-history scan" 'has missing secrets-ci'

adopted; printf 'on: [push]\njobs:\n  s:\n    steps:\n      - uses: actions/checkout@v4\n        with:\n          fetch-depth: 0\n      - run: gitleaks git --log-opts="--all --full-history -m" --redact .\n' > "$work/r/.github/workflows/ci.yml"; run
check "the gitleaks CLI on a full checkout counts" 'has ok secrets-ci'

adopted; printf 'on: push\njobs:\n  a:\n    steps:\n      - uses: actions/checkout@v4\n        with:\n          fetch-depth: 0\n  b:\n    steps:\n      - uses: actions/checkout@v4\n      - run: gitleaks git --log-opts="--all --full-history -m" --redact --no-banner .\n' > "$work/r/.github/workflows/ci.yml"; run
check "full checkout in one job and gitleaks in another is not a scan" 'has missing secrets-ci'

adopted; sed -i 's/^on:$/on:\n  workflow_dispatch:/; /^  push:$/d; /^  pull_request:$/d' "$work/r/.github/workflows/ci.yml"; run
check "a scan only started by hand doesn't count" 'has missing secrets-ci'

adopted; sed -i 's|- run: gitleaks git --log-opts="--all --full-history -m" --redact --no-banner .|- uses: gitleaks/gitleaks-action@v3|' "$work/r/.github/workflows/ci.yml"; run
check "gitleaks-action is stale: it scans only each event's commits (M4)" 'has stale secrets-ci'

adopted; sed -i 's|gitleaks git --log-opts="--all --full-history -m" --redact|gitleaks git --log-opts=HEAD~1..HEAD --redact|' "$work/r/.github/workflows/ci.yml"; run
check "a --log-opts range is not a full-history scan" 'has missing secrets-ci'

adopted; sed -i 's|^    steps:|    if: false\n    steps:|' "$work/r/.github/workflows/ci.yml"; run
check "a job with if: false is not a scan" 'has missing secrets-ci'

adopted; sed -i 's|- run: gitleaks git|- run: "$RUNNER_TEMP/gitleaks" git|' "$work/r/.github/workflows/ci.yml"; run
check "the template's quoted CLI path counts" 'has ok secrets-ci'

adopted; sed -i 's/- run: gitleaks git/- name: gitleaks git/' "$work/r/.github/workflows/ci.yml"; run
check "a step name is not an executed scan" 'has missing secrets-ci'

adopted; sed -i 's/--all --full-history -m/HEAD~1..HEAD/' "$work/r/.github/workflows/ci.yml"; run
check "restricted history is rejected" 'has missing secrets-ci'

adopted; sed -i 's/--all --full-history -m/--all/' "$work/r/.github/workflows/ci.yml"; run
check "merge diffs are required" 'has missing secrets-ci'

adopted
{ printf 'on: [push, pull_request]\njobs:\n'; cat "$here/../assets/secrets-job.yml"; } > "$work/r/.github/workflows/ci.yml"
run
check "the actual secrets job template counts" 'has ok secrets-ci'

adopted; sed -i 's/- run: /- run: |\n          /' "$work/r/.github/workflows/ci.yml"; run
check "a block run command counts" 'has ok secrets-ci'

adopted; sed -i 's/^## Pull requests$/## Project skills/' "$work/r/AGENTS.md"; run
check "a heading starting with Pr (Project) is not PR conventions" 'has decide pr-conventions'

adopted; sed -i 's/^## Pull requests$/### PR labels/' "$work/r/AGENTS.md"; run
check "a PR heading at any level counts" 'has ok pr-conventions'

adopted; sed -i "s#- run: gitleaks git#- run: |\n          'gitleaks git#; s#--no-banner .\$#--no-banner .'#" "$work/r/.github/workflows/ci.yml"; run
check "a block line still wrapped in quotes is one bogus command, not a scan" 'has missing secrets-ci'

adopted; sed -i 's|gitleaks git --log-opts|gitleaks git --staged --log-opts|' "$work/r/.github/workflows/ci.yml"; run
check "--staged ignores --log-opts, so it is not a full-history scan" 'has missing secrets-ci'

adopted; sed -i 's|gitleaks git --log-opts|gitleaks git --pre-commit --log-opts|' "$work/r/.github/workflows/ci.yml"; run
check "--pre-commit is not a full-history scan" 'has missing secrets-ci'



adopted; printf 'knowledge_base:\n  code_guidelines:\n    enabled: false\n    filePatterns:\n      - "**/REVIEW.md"\n' > "$work/r/.coderabbit.yaml"; git -C "$work/r" config privacy.public true; VIS=PUBLIC run
check "disabled code_guidelines is stale even with the pattern" 'has stale coderabbit'

adopted; printf 'reviews:\n  path_filters:\n    - "**/REVIEW.md"\nknowledge_base:\n  code_guidelines:\n    enabled: true\n' > "$work/r/.coderabbit.yaml"; VIS=PUBLIC run
check "the pattern outside code_guidelines doesn't count" 'has stale coderabbit'

adopted; printf 'knowledge_base:\n  code_guidelines:\n    enabled: true\n    filePatterns:\n      - "**/REVIEW.md"\n' > "$work/r/.coderabbit.yaml"; VIS=PUBLIC run
check "a correct code_guidelines block is ok" 'has ok coderabbit'

adopted; rm "$work/r/.coderabbit.yaml"; run
check "private without .coderabbit.yaml is missing too" 'has missing coderabbit'

adopted; rm "$work/r/.coderabbit.yaml"; VIS=PUBLIC run
check "public without .coderabbit.yaml is missing" 'has missing coderabbit'
check "public without privacy.public is missing" 'has missing privacy'

adopted; printf 'reviews:\n  profile: chill\n# "**/REVIEW.md" in a comment does not count\n' > "$work/r/.coderabbit.yaml"; git -C "$work/r" config privacy.public true; VIS=PUBLIC run
check "coderabbit without the REVIEW.md pattern is stale (M3)" 'has stale coderabbit'
check "privacy.public=true is ok" 'has ok privacy'

adopted; VIS=UNKNOWN run
check "unknown visibility asks rather than guessing" 'has decide privacy'

REPO_VISIBILITY=PRIVATE bash "$here/check-repo.sh" "$work/nope" > /dev/null 2>&1; r=$?
check "not a repository exits 2" '[ "$r" = 2 ]'

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
