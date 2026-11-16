#!/usr/bin/env bash
# Cross-model review: the model that did not write the work reviews it,
# read-only, with the caller's prompt (scope and ledger) as its instructions.
#
# usage: cross-review.sh <codex|claude> <worktree> <base-ref> <prompt-file>
#        cross-review.sh <codex|claude> --document <file> <prompt-file>
#
# Change mode reviews the committed changes between the merge base of
# <base-ref> and HEAD; the header line names the reviewed head SHA.
# Document mode reviews a snapshot of one draft file that need not be
# committed; the header line names the snapshot's sha256 content digest.
#
#   codex   from a Claude Code session: a read-only sandbox, no approvals,
#           every MCP server disabled (`codex review` for a change,
#           `codex exec` on the snapshot directory for a document)
#   claude  from a Codex session: `claude -p` with only Read, Grep and Glob,
#           no MCP servers, reviewing a diff or snapshot written beforehand
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
usage="usage: cross-review.sh <codex|claude> <worktree> <base-ref> <prompt-file> | <codex|claude> --document <file> <prompt-file>"

reviewer=${1:-}
if [ "${2:-}" = --document ]; then
  [ $# -eq 4 ] || die "$usage"
  mode=document doc=$3 prompt_file=$4
else
  [ $# -eq 4 ] || die "$usage"
  mode=change worktree=$2 base=$3 prompt_file=$4
fi
case $reviewer in
  codex|claude) command -v "$reviewer" >/dev/null || die "$reviewer is not on PATH" ;;
  *) die "reviewer must be codex or claude, got: $reviewer" ;;
esac

# Read the prompt before changing directory, so a relative path can't go missing.
[ -s "$prompt_file" ] || die "prompt file missing or empty: $prompt_file"
brief=$(cat "$prompt_file") || die "cannot read prompt file: $prompt_file"

# Codex options shared by both modes. A sandbox from the user's config could
# let injected text in the reviewed work run commands; force read-only, with
# nobody to approve an escape. A review that inherits MCP servers can hang
# forever on its first tool call. `-c mcp_servers={}` merges rather than
# replaces, so disable each by name, from the resolved list; refuse to run if
# the list can't be read.
codex_opts() {
  command -v jq >/dev/null || die "jq is not on PATH"
  opts=(-c 'sandbox_mode="read-only"' -c 'approval_policy="never"')
  servers=$(codex mcp list --json) || die "codex mcp list failed; refusing to run with unknown MCP servers"
  names=$(jq -r '.[].name' <<<"$servers") || die "could not parse codex mcp list output"
  while IFS= read -r name; do
    [ -n "$name" ] && opts+=(-c "mcp_servers.\"$name\".enabled=false")
  done <<<"$names"
  [ -n "${CROSS_REVIEW_MODEL:-}" ] && opts+=(-c "model=\"$CROSS_REVIEW_MODEL\"")
  [ -n "${CROSS_REVIEW_EFFORT:-}" ] && opts+=(-c "model_reasoning_effort=\"$CROSS_REVIEW_EFFORT\"")
  mcp_disabled=$(grep -c . <<<"$names")
}
claude_opts() {
  # No shell for the reviewer: even `git diff` can write files (--output), so
  # the reviewed input is written here and the reviewer gets read-only tools.
  opts=(--tools Read Grep Glob --strict-mcp-config --add-dir "$tmp")
  [ -n "${CROSS_REVIEW_MODEL:-}" ] && opts+=(--model "$CROSS_REVIEW_MODEL")
  [ -n "${CROSS_REVIEW_EFFORT:-}" ] && opts+=(--effort "$CROSS_REVIEW_EFFORT")
}

if [ "$mode" = document ]; then
  [ -f "$doc" ] && [ -s "$doc" ] || die "document missing or empty: $doc"
  tmp=$(mktemp -d) || die "mktemp failed"
  snap=$(basename "$doc")
  # Review a snapshot, so edits made while the review runs can't change what
  # the digest names.
  cp -- "$doc" "$tmp/$snap" || die "cannot snapshot $doc"
  digest=$(sha256sum "$tmp/$snap" | cut -d' ' -f1) || die "sha256sum failed"
  prompt="Review only the document $tmp/$snap (sha256:$digest), a draft that is not part of any diff. Read nothing else unless the instructions below name it. This is a read-only review: change no files.

$brief"
  cd "$tmp" || die "cannot cd to $tmp"
  if [ "$reviewer" = codex ]; then
    codex_opts
    echo "reviewer=codex mode=document digest=sha256:$digest mcp_disabled=$mcp_disabled"
    codex exec "${opts[@]}" --skip-git-repo-check --ephemeral -C "$tmp" - <<<"$prompt"
  else
    claude_opts
    echo "reviewer=claude mode=document digest=sha256:$digest"
    claude -p "${opts[@]}" <<<"$prompt"
  fi
  rc=$?
  [ "$(sha256sum "$tmp/$snap" | cut -d' ' -f1)" = "$digest" ] || { echo "cross-review: snapshot changed during review" >&2; rc=1; }
else
  [ -d "$worktree" ] || die "no such worktree: $worktree"
  cd "$worktree" || die "cannot cd to $worktree"
  git rev-parse --verify --quiet "$base^{commit}" >/dev/null || die "unknown base ref: $base"
  merge_base=$(git merge-base "$base" HEAD) || die "no merge base between $base and HEAD"
  head=$(git rev-parse HEAD) || die "cannot read HEAD"
  [ -n "$(git diff --name-only "$merge_base" HEAD)" ] || die "nothing to review: HEAD has no changes against $base"
  if [ "$reviewer" = codex ]; then
    codex_opts
    # `codex review` rejects --base together with a prompt, so the range
    # travels in the prompt.
    prompt="Review only the committed changes on this branch: \`git diff $merge_base...HEAD\` (base $base, head $head). Read the surrounding code as needed. This is a read-only review: change no files.

$brief"
    echo "reviewer=codex mode=change base=$base merge_base=$merge_base head=$head mcp_disabled=$mcp_disabled"
    codex review "${opts[@]}" - <<<"$prompt"
  else
    tmp=$(mktemp -d) || die "mktemp failed"
    git diff "$merge_base...HEAD" > "$tmp/change.diff" || die "git diff failed"
    claude_opts
    prompt="Review only the committed changes on this branch, given as a diff in $tmp/change.diff (base $base, head $head). Read the surrounding code in $PWD as needed. This is a read-only review: change no files.

$brief"
    echo "reviewer=claude mode=change base=$base merge_base=$merge_base head=$head"
    claude -p "${opts[@]}" <<<"$prompt"
  fi
  rc=$?
  # A HEAD that moved while the review ran makes the header's SHA wrong.
  [ "$(git rev-parse HEAD)" = "$head" ] || { echo "cross-review: HEAD moved during review" >&2; rc=1; }
fi

echo "REVIEWER_EXIT=$rc"
[ "$rc" -eq 0 ] && status=COMPLETED
exit "$rc"
