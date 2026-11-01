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
  printf '# P\n\n## Layers\n:a\n\n## Tracker\nLinear\nLoad the `linear` skill before creating, changing or closing a tracker issue.\n\n## Pull requests\nlabels\n\n## Merge policy\nnone\n\n## Code Review Rules\n\nRead `REVIEW.md` and apply it.\n\n## Testing\nx\n' > "$work/r/AGENTS.md"
  echo "# PR Review" > "$work/r/REVIEW.md"
  printf 'knowledge_base:\n  code_guidelines:\n    enabled: true\n    filePatterns:\n      - "**/REVIEW.md"\n' > "$work/r/.coderabbit.yaml"
  mkdir -p "$work/r/.github/workflows"
  printf 'on:\n  push:\n  pull_request:\njobs:\n  secrets:\n    steps:\n      - uses: actions/checkout@v4\n        with:\n          fetch-depth: 0\n      - run: gitleaks git --log-opts="--all --full-history -m" --redact --no-banner .\n' > "$work/r/.github/workflows/ci.yml"
}

# Replace the fixture's Tracker body with $1, keeping the heading.
set_tracker() {
  awk -v body="$1" '/^## Tracker$/ { print; print body; skip = 1; next } skip && /^## / { skip = 0 } !skip { print }' \
    "$work/r/AGENTS.md" > "$work/agents.tmp" && mv "$work/agents.tmp" "$work/r/AGENTS.md"
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

# Named skills are scoped to the section that owns the task.
adopted; run
check "Tracker loads linear" 'has ok skill-lines'
check "no app needs no verification section" 'has n/a verify-section'

adopted; set_tracker $'GitHub issues on this repository.\nLoad the `github` skill before creating, changing or closing a GitHub issue.'; run
check "Tracker loads github" 'has ok skill-lines'

adopted; sed -i '/Load the/d' "$work/r/AGENTS.md"; run
check "Tracker without a load line is missing" 'has missing skill-lines && [ "$(rc)" = 1 ]'
printf '\n## Notes\nLoad the `linear` skill before creating a tracker issue.\n' >> "$work/r/AGENTS.md"; run
check "a load line outside Tracker does not count" 'has missing skill-lines'

adopted; sed -i 's/## Tracker/## Tracking/' "$work/r/AGENTS.md"; run
check "no Tracker section makes skill-lines n/a" 'has n/a skill-lines'

adopted
printf '\n## Verifying the app\nLoad the `verify-change` skill before verifying a change in the running app.\n' >> "$work/r/AGENTS.md"; run
check "instruction alone needs verification facts" 'has decide verify-section'

adopted; mkdir -p "$work/r/composeApp"; touch "$work/r/composeApp/build.gradle.kts"; run
check "Compose app needs verification facts" 'has decide verify-section && [ "$(rc)" = 0 ]'
printf '\n## Verifying the app\nUse the app.\n' >> "$work/r/AGENTS.md"; run
check "verification heading without skill still needs a decision" 'has decide verify-section'
sed -i 's/Use the app./Load the `verify-change` skill before verifying a change in the running app./' "$work/r/AGENTS.md"; run
printf 'Launch with the repository app script.\n' >> "$work/r/AGENTS.md"; run
check "app with verification skill and facts is ok" 'has ok verify-section'

adopted; mkdir -p "$work/r/androidApp"; touch "$work/r/androidApp/build.gradle"; run
check "Android Gradle module needs verification facts" 'has decide verify-section'

adopted; printf 'include(":composeApp")\n' > "$work/r/settings.gradle.kts"; run
check "declared Gradle app module needs verification facts" 'has decide verify-section'

adopted; printf "include ':androidApp'\n" > "$work/r/settings.gradle"; run
check "Groovy app module declaration needs verification facts" 'has decide verify-section'

adopted; mkdir -p "$work/r/client/src/main"; touch "$work/r/client/src/main/AndroidManifest.xml"; run
check "Android manifest needs verification facts" 'has decide verify-section'

for script in dev start; do
  adopted; mkdir -p "$work/r/client"
  printf '{"scripts":{"%s":"serve"}}\n' "$script" > "$work/r/client/package.json"; run
  check "package $script script needs verification facts" 'has decide verify-section'
done
adopted; printf '{"scripts":{"test":"test"}}\n' > "$work/r/package.json"; run
check "package without dev or start is not an app" 'has n/a verify-section'
adopted; printf 'invalid json\n' > "$work/r/package.json"; run
check "invalid package JSON does not imply an app" 'has n/a verify-section'
adopted; mkdir -p "$work/r/node_modules/dependency"
printf '{"scripts":{"dev":"serve"}}\n' > "$work/r/node_modules/dependency/package.json"; run
check "dependency app scripts do not imply a repository app" 'has n/a verify-section'

adopted; sed -i 's/^## Tracker$/## Tracker\n**You MUST load the `linear` skill before creating, changing or closing a tracker issue.**/' "$work/r/AGENTS.md"; run
check "fx-style 'You MUST load the' wording satisfies skill-lines" 'has ok skill-lines'

adopted; sed -i 's/^## Tracker$/## Project Conventions\n### Tracker\n**You MUST load the `linear` skill before creating, changing or closing a tracker issue.**\n### Other/' "$work/r/AGENTS.md"; run
check "skill-lines finds a ### Tracker nested under another section" 'has ok skill-lines'

adopted; set_tracker 'Linear. Load the `linear` skill for all tracker work.'; run
check "a topic-scoped tracker line is not accepted" 'has missing skill-lines'

adopted; set_tracker $'GitHub issues.\nLoad the `linear` skill before creating, changing or closing a tracker issue.'; run
check "a load line naming the wrong tracker is stale" 'has stale skill-lines'

adopted; printf '\n## Verifying the app\nDo not load `verify-change` here.\n' >> "$work/r/AGENTS.md"; run
check "a verification section that only mentions verify-change is not ok" '! has ok verify-section'

adopted; printf '\n## Verifying the app\n**You MUST load the `verify-change` skill before verifying a change in the running app.**\n' >> "$work/r/AGENTS.md"; run
check "bold instruction alone still needs facts" 'has decide verify-section'

adopted; printf '\n## Verifying the app\nLoad the `verify-change` skill before verifying a change in the running app. Launch with npm run dev.\n' >> "$work/r/AGENTS.md"; run
check "facts on the instruction's own line count" 'has ok verify-section'

adopted; set_tracker $'Linear issues.\n<!-- Load the `linear` skill before creating, changing or closing a tracker issue. -->'; run
check "a commented tracker load line is missing" 'has missing skill-lines'

adopted; set_tracker $'Linear issues.\n<!--\nLoad the `linear` skill before creating, changing or closing a tracker issue.\n-->'; run
check "a multiline commented tracker load line is missing" 'has missing skill-lines'

adopted; printf '\n## Verifying the app\n<!-- Load the `verify-change` skill before verifying a change in the running app. -->\n' >> "$work/r/AGENTS.md"; run
check "a commented verify-change line is not ok" '! has ok verify-section'

adopted; printf '\n## Verifying the app\nLoad the `verify-change` skill before verifying a change in the running app.\n<!-- Launch with npm run dev. -->\n' >> "$work/r/AGENTS.md"; run
check "a fact only inside a comment does not count" 'has decide verify-section'

adopted; mkdir -p "$work/r/desktopApp"; printf 'compose.desktop {\n  application { mainClass = "MainKt" }\n}\n' > "$work/r/desktopApp/build.gradle.kts"; run
check "a Compose Desktop build needs a verification section" 'has decide verify-section'

adopted; mkdir -p "$work/r/shared"; printf 'kotlin {\n  jvm("desktop")\n}\n' > "$work/r/shared/build.gradle.kts"; run
check "a library's jvm(\"desktop\") target alone is not an app" 'has n/a verify-section'

adopted; mkdir -p "$work/r/ui"; printf 'dependencies {\n  implementation(compose.desktop.currentOs)\n}\n// compose.desktop {\n' > "$work/r/ui/build.gradle.kts"; run
check "a compose.desktop dependency or comment is not an app" 'has n/a verify-section'

adopted; mkdir -p "$work/r/desktop"; printf 'compose.desktop.application {\n  mainClass = "MainKt"\n}\n' > "$work/r/desktop/build.gradle.kts"; run
check "a direct compose.desktop.application block is an app" 'has decide verify-section'

adopted; printf '\n## Verifying the app\nDo not load the `verify-change` skill before verifying a change in the running app.\n' >> "$work/r/AGENTS.md"; run
check "a negated full verify-change sentence is not ok" '! has ok verify-section'

adopted; set_tracker "Linear. Don't load the \`linear\` skill before creating, changing or closing a tracker issue."; run
check "a negated tracker load line is missing, not ok" 'has missing skill-lines'

# Regression coverage for case, tracker inference, affirmative wording and web apps.
adopted; sed -i 's/^## Tracker$/## tRaCkEr/' "$work/r/AGENTS.md"; run
check "mixed-case Tracker body is read" 'has ok skill-lines'

adopted; set_tracker $'`GitHub` issues.\nLoad the `linear` skill before creating, changing or closing a tracker issue.'; run
check "backticked tracker prose still exposes a mismatch" 'has stale skill-lines'

adopted; set_tracker '`GitHub` issues. **Load the `linear` skill before creating, changing or closing a tracker issue.**'; run
check "a mismatch on the prose's own line is stale" 'has stale skill-lines'

adopted; set_tracker 'GitHub issues on this repository. **Load the `github` skill before creating, changing or closing a GitHub issue.**'; run
check "a matching load line on the prose's own line is ok" 'has ok skill-lines'

adopted; set_tracker 'Load the `linear` skill before creating, changing or closing a tracker issue; this repository uses GitHub issues.'; run
check "tracker prose after the load clause still exposes a mismatch" 'has stale skill-lines'

for bullet in '*' '+'; do
  adopted; set_tracker "GitHub issues.
$bullet Load the \`github\` skill before creating, changing or closing a GitHub issue."; run
  check "a '$bullet' bullet load line is ok" 'has ok skill-lines'
done

for prefix in 'Do not ever load the' 'Never ever load the' 'Notes: Load the'; do
  adopted; set_tracker "Linear issues.
$prefix \`linear\` skill before creating, changing or closing a tracker issue."; run
  check "$prefix is not an affirmative tracker instruction" 'has missing skill-lines'
  printf '\n## Verifying the app\n%s `verify-change` skill before verifying a change in the running app.\nLaunch the app script.\n' "$prefix" >> "$work/r/AGENTS.md"; run
  check "$prefix is not an affirmative verification instruction" '! has ok verify-section'
done

adopted; set_tracker $'Linear issues.\n  - **lOaD tHe `linear` skill before creating, changing or closing a tracker issue.**'; run
check "indented bold list tracker instruction counts" 'has ok skill-lines'
printf '\n## vErIfYiNg ThE aPp\n  - **yOu MuSt LoAd ThE `verify-change` skill before verifying a change in the running app.**\nLaunch the app script.\n' >> "$work/r/AGENTS.md"; run
check "mixed-case verification heading and list instruction count with facts" 'has ok verify-section'

adopted
printf '\n## Verifying the app\nLoad the `verify-change` skill before verifying a change in the running app.\n\n### Commands\n\n## Other\nUnrelated facts.\n' >> "$work/r/AGENTS.md"; run
check "blank lines and headings are not verification facts" 'has decide verify-section'

for entry in index.html public/index.html web/index.html src/index.html; do
  adopted; mkdir -p "$work/r/$(dirname "$entry")"; touch "$work/r/$entry"; run
  check "static entrypoint $entry needs verification facts" 'has decide verify-section'
done

# Per-target facts must cover every detected target, even with a valid load line.
verification_facts() {
  printf '\n## Verifying the app\nLoad the `verify-change` skill before verifying a change in the running app.\n%s\n' "$1" >> "$work/r/AGENTS.md"
}
for declaration in 'compose.desktop {' 'compose.desktop.application {'; do
  for comment in line block multiline; do
    adopted
    case "$comment" in
      line) printf '// %s\n' "$declaration" ;;
      block) printf '/* %s } */\n' "$declaration" ;;
      multiline) printf '/* Disabled target\n%s\n}\n*/\n' "$declaration" ;;
    esac > "$work/r/build.gradle.kts"
    run
    check "$comment commented $declaration is not an app" 'has n/a verify-section'
  done
done
for target in android desktop web ios; do
  adopted
  case "$target" in
    android) printf 'kotlin { androidTarget() }\n' ;;
    desktop) printf 'compose.desktop.application { mainClass = "MainKt" }\n' ;;
    web) printf 'kotlin { wasmJs { browser() } }\n' ;;
    ios) printf 'kotlin { iosArm64() }\n' ;;
  esac > "$work/r/build.gradle.kts"
  verification_facts 'Launch with the repository script.'; run
  check "$target missing from facts needs a decision naming it" 'has decide verify-section && grep -q "detected targets: $target;" "$work/out"'
  printf -- '- **%s:** build and launch with the repository script; server URL from config.\n' "$target" >> "$work/r/AGENTS.md"
  run
  check "a $target bullet is ok" 'has ok verify-section'
done
for declaration in 'js() { browser() }' 'wasmJs() { browser() }'; do
  adopted; printf 'kotlin { %s }\n' "$declaration" > "$work/r/build.gradle.kts"; run
  check "a library's $declaration alone is not an app" 'has n/a verify-section'
  adopted; printf 'kotlin { %s\n binaries.executable() }\n' "$declaration" > "$work/r/build.gradle.kts"
  run
  check "Kotlin $declaration with an executable binary is an app" 'has decide verify-section'
  verification_facts '- **BROWSER:** build and launch with the repository script.'; run
  check "browser alias covers $declaration case-insensitively" 'has ok verify-section'
done
for declaration in 'iosX64()' 'iosArm64()' 'iosSimulatorArm64()'; do
  adopted; printf 'kotlin { %s }\n' "$declaration" > "$work/r/build.gradle.kts"; run
  check "$declaration alone is not an app" 'has n/a verify-section'
  verification_facts '- **iOS:** not verified here.'; run
  check "$declaration recorded as not verified here is ok" 'has ok verify-section'
done
adopted
printf '/*\nandroidTarget()\ncompose.desktop { }\nwasmJs() { browser() }\niosArm64()\n*/\n// iosX64()\n' > "$work/r/build.gradle.kts"
verification_facts 'Launch with the repository script.'; run
check "commented target declarations require no target facts" 'has ok verify-section'

adopted
printf 'kotlin {\n androidTarget()\n js() { browser() }\n iosArm64()\n}\ncompose.desktop { }\n' > "$work/r/build.gradle.kts"
verification_facts '- **Android:** build and launch with the repository script.'; run
check "all omitted targets are named together" 'has decide verify-section && grep -q "detected targets: desktop web ios;" "$work/out"'
printf -- '- **DESKTOP:** launch with the repository script.\n### Browser\nServe with the repository script.\n- iOS: not verified here.\n' >> "$work/r/AGENTS.md"; run
check "all detected targets mentioned is ok" 'has ok verify-section'

adopted; printf 'compose.desktop { }\n' > "$work/r/build.gradle.kts"
verification_facts 'It owns the emulator, desktop and web mechanics. Launch with the repository script.'; run
check "a passing mention of desktop is not a target bullet" 'has decide verify-section && grep -q "detected targets: desktop;" "$work/out"'

adopted; printf 'kotlin { wasmJs { browser(); binaries.executable() } }\n' > "$work/r/build.gradle.kts"; run
check "a trailing-lambda wasmJs executable is an app" 'has decide verify-section'

adopted; printf 'val banner = """\nMETA-INF/*\n"""\ncompose.desktop {\n}\n' > "$work/r/build.gradle.kts"; run
check "a multiline raw string does not hide a later desktop block" 'has decide verify-section'

adopted; printf 'val doc = """\n// not a comment\ncompose.desktop {\n"""\n' > "$work/r/build.gradle.kts"; run
check "a desktop block inside a raw string is not an app" 'has n/a verify-section'

adopted; printf 'compose {\n  desktop {\n    application { mainClass = "MainKt" }\n  }\n}\n' > "$work/r/build.gradle.kts"
verification_facts '- **Android:** launch with the repository script.'; run
check "a nested compose desktop application needs a Desktop bullet" 'has decide verify-section && grep -q "detected targets: desktop;" "$work/out"'

adopted; printf 'compose.desktop {\n}\nval note = "iosArm64()"\n' > "$work/r/build.gradle.kts"
verification_facts '- **Desktop:** launch with the repository script.'; run
check "a quoted iOS example is not a declared target" 'has ok verify-section'

adopted; printf '{"scripts":{"dev":"serve"}}\n' > "$work/r/package.json"
verification_facts $'Serve the client.\n- Web:'; run
check "a bare target label is not coverage" 'has decide verify-section && grep -q "detected targets: web;" "$work/out"'

adopted; printf '{"scripts":{"dev":"serve"}}\n' > "$work/r/package.json"
verification_facts $'### Web\n\n### Notes\nServe the client.'; run
check "an empty target subheading is not coverage" 'has decide verify-section && grep -q "detected targets: web;" "$work/out"'

adopted; printf '{"scripts":{"dev":"serve"}}\n' > "$work/r/package.json"
verification_facts $'### Web\n#### Build\nRun npm run dev.'; run
check "facts under a nested heading of a target subheading count" 'has ok verify-section'

adopted; printf '{"scripts":{"dev":"serve"}}\n' > "$work/r/package.json"; mkdir -p "$work/r/app"; touch "$work/r/app/AndroidManifest.xml"
verification_facts $'### Android\n- Web: run npm start'; run
check "another target's bullet is not this target's facts" 'has decide verify-section && grep -q "detected targets: android;" "$work/out"'

adopted; printf '{"scripts":{"dev":"serve"}}\n' > "$work/r/package.json"
verification_facts $'- **Web:**\n  Run npm run dev.'; run
check "an indented continuation line under a target bullet counts" 'has ok verify-section'

adopted; printf '{"scripts":{"dev":"serve"}}\n' > "$work/r/package.json"
verification_facts $'- **Web:**\nServe the client from the docs.'; run
check "an unindented line after an empty bullet is not its facts" 'has decide verify-section'

adopted; printf '{"scripts":{"dev":"serve"}}\n' > "$work/r/package.json"
verification_facts $'- **Web:**\n  - Android: run the emulator'; run
check "a nested other-target bullet is not continuation facts" 'has decide verify-section'

adopted; printf '{"scripts":{"dev":"serve"}}\n' > "$work/r/package.json"
verification_facts $'### Web\n#### Android\nRun the emulator.'; run
check "a nested other-target heading is not parent facts" 'has decide verify-section'

adopted; printf '{"scripts":{"dev":"serve"}}\n' > "$work/r/package.json"
verification_facts $'### Web\n- Android:\n  run the emulator'; run
check "lines under another target's bullet are not this target's facts" 'has decide verify-section'

adopted; printf '{"scripts":{"dev":"serve"}}\n' > "$work/r/package.json"
verification_facts $'### Web\n#### Android\nRun the emulator.\n#### Build\nRun npm run dev.'; run
check "a generic heading after another target's heading counts again" 'has ok verify-section'

for source in manifest module package static; do
  adopted
  case "$source" in
    manifest) mkdir -p "$work/r/client"; touch "$work/r/client/AndroidManifest.xml"; target=android ;;
    module) mkdir -p "$work/r/androidApp"; touch "$work/r/androidApp/build.gradle"; target=android ;;
    package) printf '{"scripts":{"dev":"serve"}}\n' > "$work/r/package.json"; target=web ;;
    static) touch "$work/r/index.html"; target=web ;;
  esac
  verification_facts 'Launch with the repository script.'; run
  check "$source target missing from facts is named" 'has decide verify-section && grep -q "detected targets: $target;" "$work/out"'
done

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
