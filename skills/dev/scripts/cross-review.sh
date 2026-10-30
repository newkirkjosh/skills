#!/usr/bin/env bash
# Cross-model review of a change: the model that did not write it reviews it,
# read-only, with the Scope Brief as its instructions.
#
# usage: cross-review.sh <codex|claude> <worktree> <base-ref> <prompt-file>
#
#   codex   from a Claude Code session: `codex review` in a read-only sandbox,
#           every MCP server disabled
#   claude  from a Codex session: `claude -p` with only Read, Grep and Glob, no
#           MCP servers, reviewing a diff file written beforehand
#
# Env: CROSS_REVIEW_MODEL, CROSS_REVIEW_EFFORT override the reviewer's model and
# reasoning effort for this run only (never the user's config). Leave them unset
# to use the reviewer's own defaults; never lower them to save time.
#
# The last stdout line is always STATUS=COMPLETED or STATUS=ERROR. COMPLETED
# means the reviewer exited 0 and its findings are above; anything else is
# ERROR, never a clean review. A log with no STATUS= line is still running, or
# died. Exit status: 0 on COMPLETED, the reviewer's own on its failure, 3 on a
# setup error.
set -uo pipefail

status=ERROR
tmp=""
trap '[ -n "$tmp" ] && rm -rf "$tmp"; echo "STATUS=$status"' EXIT
die() { echo "cross-review: $*" >&2; exit 3; }

[ $# -eq 4 ] || die "usage: cross-review.sh <codex|claude> <worktree> <base-ref> <prompt-file>"
reviewer=$1 worktree=$2 base=$3 prompt_file=$4

# Read the brief before changing directory, so a relative path can't go missing.
[ -s "$prompt_file" ] || die "prompt file missing or empty: $prompt_file"
brief=$(cat "$prompt_file") || die "cannot read prompt file: $prompt_file"
[ -d "$worktree" ] || die "no such worktree: $worktree"
cd "$worktree" || die "cannot cd to $worktree"
git rev-parse --verify --quiet "$base^{commit}" >/dev/null || die "unknown base ref: $base"
merge_base=$(git merge-base "$base" HEAD) || die "no merge base between $base and HEAD"
[ -n "$(git diff --name-only "$merge_base" HEAD)" ] || die "nothing to review: HEAD has no changes against $base"

case $reviewer in
  codex)
    command -v codex >/dev/null || die "codex is not on PATH"
    command -v jq >/dev/null || die "jq is not on PATH"
    # `codex review` rejects --base together with a prompt, so the range
    # travels in the prompt.
    prompt="Review only the committed changes on this branch: \`git diff $merge_base...HEAD\` (base $base). Read the surrounding code as needed. This is a read-only review: change no files.

$brief"
    # A sandbox from the user's config could let injected text in the reviewed
    # code run commands; force read-only, with nobody to approve an escape.
    opts=(-c 'sandbox_mode="read-only"' -c 'approval_policy="never"')
    # A review that inherits MCP servers can hang forever on its first tool call.
    # `-c mcp_servers={}` merges rather than replaces, so disable each by name,
    # from the resolved list; refuse to run if the list can't be read.
    servers=$(codex mcp list --json) || die "codex mcp list failed; refusing to run with unknown MCP servers"
    names=$(jq -r '.[].name' <<<"$servers") || die "could not parse codex mcp list output"
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
    # No shell for the reviewer: even `git diff` can write files (--output), so
    # the diff is written here and the reviewer gets only read-only tools.
    tmp=$(mktemp -d) || die "mktemp failed"
    git diff "$merge_base...HEAD" > "$tmp/change.diff" || die "git diff failed"
    prompt="Review only the committed changes on this branch, given as a diff in $tmp/change.diff (base $base). Read the surrounding code in $PWD as needed. This is a read-only review: change no files.

$brief"
    opts=(--tools Read Grep Glob --strict-mcp-config --add-dir "$tmp")
    [ -n "${CROSS_REVIEW_MODEL:-}" ] && opts+=(--model "$CROSS_REVIEW_MODEL")
    [ -n "${CROSS_REVIEW_EFFORT:-}" ] && opts+=(--effort "$CROSS_REVIEW_EFFORT")
    echo "reviewer=claude base=$base merge_base=$merge_base"
    claude -p "${opts[@]}" <<<"$prompt"
    rc=$?
    ;;
  *) die "reviewer must be codex or claude, got: $reviewer" ;;
esac

echo "REVIEWER_EXIT=$rc"
[ "$rc" -eq 0 ] && status=COMPLETED
exit "$rc"
