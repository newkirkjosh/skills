#!/usr/bin/env bash
# Cross-model review of a change: the model that did not write it reviews it,
# read-only, with the Scope Brief as its instructions.
#
# usage: cross-review.sh <codex|claude> <worktree> <base-ref> <prompt-file>
#
#   codex   from a Claude Code session: `codex review`, every MCP server disabled
#   claude  from a Codex session: `claude -p`, read-only tools only
#
# Env: CROSS_REVIEW_MODEL, CROSS_REVIEW_EFFORT override the reviewer's model and
# reasoning effort for this run only (never the user's config). Leave them unset
# to use the reviewer's own defaults; never lower them to save time.
#
# The last stdout line is always STATUS=COMPLETED or STATUS=ERROR. A log with no
# STATUS= line is a review still running, or one that died: never a finished one.
# Exit status: the reviewer's own on COMPLETED, 3 on a setup error.
set -uo pipefail

status=ERROR
trap 'echo "STATUS=$status"' EXIT
die() { echo "cross-review: $*" >&2; exit 3; }

[ $# -eq 4 ] || die "usage: cross-review.sh <codex|claude> <worktree> <base-ref> <prompt-file>"
reviewer=$1 worktree=$2 base=$3 prompt_file=$4

[ -d "$worktree" ] || die "no such worktree: $worktree"
[ -s "$prompt_file" ] || die "prompt file missing or empty: $prompt_file"
cd "$worktree" || die "cannot cd to $worktree"
git rev-parse --verify --quiet "$base^{commit}" >/dev/null || die "unknown base ref: $base"
merge_base=$(git merge-base "$base" HEAD) || die "no merge base between $base and HEAD"
[ -n "$(git diff --name-only "$merge_base" HEAD)" ] || die "nothing to review: HEAD has no changes against $base"

# `codex review` rejects --base together with a prompt, so the range travels in
# the prompt for both reviewers.
prompt="Review only the committed changes on this branch: \`git diff $merge_base...HEAD\` (base $base). Read the surrounding code as needed. This is a read-only review: change no files.

$(cat "$prompt_file")"

case $reviewer in
  codex)
    command -v codex >/dev/null || die "codex is not on PATH"
    command -v jq >/dev/null || die "jq is not on PATH"
    # A review that inherits MCP servers can hang forever on its first tool call.
    # `-c mcp_servers={}` merges rather than replaces, so disable each by name,
    # from the resolved list; refuse to run if the list can't be read.
    servers=$(codex mcp list --json) || die "codex mcp list failed; refusing to run with unknown MCP servers"
    names=$(jq -r '.[].name' <<<"$servers") || die "could not parse codex mcp list output"
    opts=()
    while IFS= read -r name; do
      [ -n "$name" ] && opts+=(-c "mcp_servers.\"$name\".enabled=false")
    done <<<"$names"
    [ -n "${CROSS_REVIEW_MODEL:-}" ] && opts+=(-c "model=\"$CROSS_REVIEW_MODEL\"")
    [ -n "${CROSS_REVIEW_EFFORT:-}" ] && opts+=(-c "model_reasoning_effort=\"$CROSS_REVIEW_EFFORT\"")
    echo "reviewer=codex base=$base merge_base=$merge_base mcp_disabled=$(grep -c . <<<"$names")"
    codex review "${opts[@]}" - <<<"$prompt"
    rc=$?
    ;;
  claude)
    command -v claude >/dev/null || die "claude is not on PATH"
    opts=(--allowedTools "Read" "Grep" "Glob" "Bash(git diff:*)" "Bash(git log:*)" "Bash(git show:*)"
          --disallowedTools "Edit" "Write" "NotebookEdit")
    [ -n "${CROSS_REVIEW_MODEL:-}" ] && opts+=(--model "$CROSS_REVIEW_MODEL")
    [ -n "${CROSS_REVIEW_EFFORT:-}" ] && opts+=(--effort "$CROSS_REVIEW_EFFORT")
    echo "reviewer=claude base=$base merge_base=$merge_base"
    claude -p "${opts[@]}" <<<"$prompt"
    rc=$?
    ;;
  *) die "reviewer must be codex or claude, got: $reviewer" ;;
esac

status=COMPLETED
echo "REVIEWER_EXIT=$rc"
exit "$rc"
