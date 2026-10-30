#!/usr/bin/env bash
# Report how a repository measures against the setup standard in SKILL.md.
# Read-only: changes nothing.
#
# usage: bash check-repo.sh [repo-dir]   (default: current directory)
#   REPO_VISIBILITY=PUBLIC|PRIVATE  skip the gh lookup (tests, offline)
#
# One line per item: `<state> <id> <detail>`, where state is
#   ok       meets the standard
#   missing  absent; the skill adds it
#   stale    present in an old or wrong form; the skill migrates it
#   decide   needs the user's decision; never filled in by the agent
#   n/a      doesn't apply to this repository
# Exit: 0 nothing missing or stale, 1 something to fix, 2 usage
set -uo pipefail

dir=${1:-.}
top=$(git -C "$dir" rev-parse --show-toplevel 2> /dev/null) || { echo "not a git repository: $dir" >&2; exit 2; }
cd "$top" || exit 2

vis=${REPO_VISIBILITY:-$(gh repo view --json visibility -q .visibility 2> /dev/null || true)}
case $vis in PUBLIC|PRIVATE) ;; *) vis=UNKNOWN ;; esac

todo=0
say() { echo "$1 $2 $3"; case $1 in missing|stale) todo=1 ;; esac; }
heading() { [ -f AGENTS.md ] && grep -qiE "^#+ +$1" AGENTS.md; }

# Instruction files
if [ ! -e CLAUDE.md ]; then say missing claude-pointer "no CLAUDE.md; add one containing only @AGENTS.md"
elif [ -L CLAUDE.md ]; then say stale claude-pointer "CLAUDE.md is a symlink; make it a file containing only @AGENTS.md"
elif [ "$(tr -d '[:space:]' < CLAUDE.md)" = "@AGENTS.md" ]; then say ok claude-pointer "CLAUDE.md imports AGENTS.md"
else say stale claude-pointer "CLAUDE.md has its own content; move it into AGENTS.md (M1)"
fi
if [ -f AGENTS.md ]; then say ok agents "AGENTS.md present"; else say missing agents "no AGENTS.md"; fi
for f in AGENTS.md REVIEW.md; do
  [ -L "$f" ] && say stale symlink "$f is a symlink; a write would land in its target: replace it with a file"
done

# Review rules
if [ -f REVIEW.md ]; then say ok review "REVIEW.md present"; else say missing review "no REVIEW.md"; fi
if [ -f AGENTS.md ] && awk '/^## +Code Review Rules/{f=1; next} /^## /{f=0} f' AGENTS.md | grep -q 'REVIEW.md'; then
  say ok review-bridge "AGENTS.md points Codex at REVIEW.md"
else
  say missing review-bridge "no '## Code Review Rules' section in AGENTS.md pointing at REVIEW.md (Codex reads only AGENTS.md)"
fi
if [ -f .github/copilot-instructions.md ]; then
  say stale copilot-instructions ".github/copilot-instructions.md duplicates REVIEW.md; merge it in and delete it (M2)"
fi
if [ -f .coderabbit.yaml ]; then
  # Only the code_guidelines block counts: its pattern list, and not switched off.
  guidelines=$(awk '/^[[:space:]]*code_guidelines:/{f=1; d=match($0,/[^ ]/); next}
    f && /[^[:space:]]/ && !/^[[:space:]]*#/ { if (match($0,/[^ ]/) <= d) exit; print }' .coderabbit.yaml)
  if grep -qE '^[^#]*\*\*/REVIEW\.md' <<< "$guidelines" && ! grep -qE '^[[:space:]]*enabled:[[:space:]]*false' <<< "$guidelines"; then
    say ok coderabbit ".coderabbit.yaml reads **/REVIEW.md"
  else
    say stale coderabbit ".coderabbit.yaml doesn't read **/REVIEW.md (knowledge_base.code_guidelines: enabled, with the pattern)"
  fi
elif [ "$vis" = PUBLIC ]; then say missing coderabbit "public repository without .coderabbit.yaml"
else say n/a coderabbit "private repository: pr-review-toolkit reviews locally"
fi

# Secrets and privacy
# A workflow file counts when an uncommented step runs gitleaks and its checkout
# fetches the full history; a comment, or a shallow clone, scans nothing old.
scan=""
for wf in .github/workflows/*.yml .github/workflows/*.yaml; do
  [ -f "$wf" ] || continue
  grep -qE '^[^#]*(uses:[[:space:]]*gitleaks/gitleaks-action|gitleaks[[:space:]]+(git|detect))' "$wf" \
    && grep -qE '^[^#]*fetch-depth:[[:space:]]*0' "$wf" && scan=$wf && break
done
if [ -n "$scan" ]; then say ok secrets-ci "$scan scans the full history with gitleaks"
else say missing secrets-ci "no CI job scans the full history with gitleaks (uncommented step, fetch-depth: 0)"
fi
case $vis in
  PUBLIC)
    if [ "$(git config --bool privacy.public 2> /dev/null)" = true ]; then say ok privacy "privacy.public=true in this clone"
    else say missing privacy "public repository without privacy.public=true in this clone (local git config)"
    fi ;;
  PRIVATE) say n/a privacy "private repository" ;;
  *) say decide privacy "visibility unknown (gh unavailable); check it before deciding" ;;
esac

# What the workflow skills read from AGENTS.md: the user decides each, the agent never invents one.
if heading 'Layers'; then say ok layers "AGENTS.md declares layers"; else say decide layers "no Layers section; needed before dev or spec-writer runs here"; fi
if heading 'Tracker'; then say ok tracker "AGENTS.md names the tracker"; else say decide tracker "no Tracker section (Linear team and project, or GitHub issues and board)"; fi
if heading '(Pull request|PR)'; then say ok pr-conventions "AGENTS.md has PR conventions"; else say decide pr-conventions "no Pull Request section (labels, project or board)"; fi
if heading 'Merge policy'; then say ok merge-policy "AGENTS.md has a Merge policy"; else say decide merge-policy "no Merge policy: every PR stops at merge-ready, which is a valid choice"; fi

exit "$todo"
