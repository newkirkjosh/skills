#!/usr/bin/env bash
# Cross-model review: the model that did not write the work reviews it,
# read-only, with the caller's prompt (scope and ledger) as its instructions.
#
# usage: cross-review.sh <codex|claude> <worktree> <base-ref> <prompt-file>
#        cross-review.sh <codex|claude> --document <file> <prompt-file>
#
# Change mode reviews the committed changes between the merge base of
# <base-ref> and HEAD, from a worktree with nothing uncommitted or untracked
# (refused before, ERROR if it appears during review); the header line names
# the reviewed head SHA.
# Document mode reviews a snapshot of one draft file that need not be
# committed; the header line names the snapshot's sha256 content digest.
#
#   codex   from a Claude Code session: a read-only sandbox, no approvals,
#           every plugin and MCP server disabled (`codex review` for a change,
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
# forever on its first tool call. Servers come from two places. An enabled
# plugin provides some, and only `plugins.<pluginId>.enabled=false` removes
# them (an `mcp_servers.<name>` override for one is a config error), so read
# the enabled plugins from `codex plugin list --json` and disable each by ID
# first. Then list the servers under those overrides and disable each
# remaining one by name: `-c mcp_servers={}` merges rather than replaces.
# Refuse to run if either list can't be read or isn't the expected shape
# (plugins: object with an `.installed` array of objects with a string
# `pluginId` and boolean `enabled`; servers: array of objects with a string
# `name`): empty, malformed or multi-value output (more than one JSON value)
# must never read as "nothing enabled". Codex splits a `-c` key on every dot
# and keeps quote characters literally (`mcp_servers."x".enabled` names a key
# `"x"`), so only a bare segment reaches a server or plugin. Allowlist rather
# than blocklist: every enabled plugin ID and every server name must match
# `[A-Za-z0-9@_-]+` (checked in jq, whole string, so an embedded newline can't
# split one value into two), or the script refuses to run. Disabled plugins
# are ignored whatever their ID. Finally list the servers again with every
# override applied and refuse to run unless each reports disabled. Overrides
# apply to this run only; the config is never written.
codex_opts() {
  command -v jq >/dev/null || die "jq is not on PATH"
  local re='\A[A-Za-z0-9@_-]+\z' list_shape='type == "array" and all(.[]; type == "object" and (.name | type == "string"))' bad
  opts=(-c 'sandbox_mode="read-only"' -c 'approval_policy="never"')
  plugin_json=$(codex plugin list --json) || die "codex plugin list failed; refusing to run with unknown plugins"
  jq -s -e 'length == 1 and (.[0] | (type == "object") and (.installed | type == "array") and all(.installed[]; type == "object" and (.pluginId | type == "string") and (.enabled | type == "boolean")))' <<<"$plugin_json" >/dev/null 2>&1 || die "codex plugin list output is empty or not the expected shape; refusing to run with unknown plugins"
  bad=$(jq -r --arg re "$re" '[.installed[] | select(.enabled == true) | .pluginId | select(test($re) | not)] | first // empty | @json' <<<"$plugin_json") || die "could not parse codex plugin list output"
  [ -z "$bad" ] || die "plugin ID $bad can't be disabled with -c (allowed: letters, digits, @, _, -); refusing to run with it enabled"
  plugins=$(jq -r '.installed[] | select(.enabled == true) | .pluginId' <<<"$plugin_json") || die "could not parse codex plugin list output"
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    opts+=(-c "plugins.$id.enabled=false")
  done <<<"$plugins"
  plugins_disabled=$(grep -c . <<<"$plugins")
  [ -n "${CROSS_REVIEW_MODEL:-}" ] && opts+=(-c "model=\"$CROSS_REVIEW_MODEL\"")
  [ -n "${CROSS_REVIEW_EFFORT:-}" ] && opts+=(-c "model_reasoning_effort=\"$CROSS_REVIEW_EFFORT\"")
  servers=$(codex mcp list --json "${opts[@]}") || die "codex mcp list failed; refusing to run with unknown MCP servers"
  jq -s -e "length == 1 and (.[0] | $list_shape)" <<<"$servers" >/dev/null 2>&1 || die "codex mcp list output is empty or not the expected shape; refusing to run with unknown MCP servers"
  bad=$(jq -r --arg re "$re" '[.[].name | select(test($re) | not)] | first // empty | @json' <<<"$servers") || die "could not parse codex mcp list output"
  [ -z "$bad" ] || die "MCP server name $bad can't be disabled with -c (allowed: letters, digits, @, _, -); refusing to run with it enabled"
  names=$(jq -r '.[].name' <<<"$servers") || die "could not parse codex mcp list output"
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    opts+=(-c "mcp_servers.$name.enabled=false")
  done <<<"$names"
  after=$(codex mcp list --json "${opts[@]}") || die "codex rejected the MCP overrides; refusing to run"
  jq -s -e "length == 1 and (.[0] | $list_shape)" <<<"$after" >/dev/null 2>&1 || die "codex mcp list output is empty or not the expected shape; refusing to run with unknown MCP servers"
  bad=$(jq -r --arg re "$re" '[.[].name | select(test($re) | not)] | first // empty | @json' <<<"$after") || die "could not parse codex mcp list output"
  [ -z "$bad" ] || die "MCP server name $bad can't be disabled with -c (allowed: letters, digits, @, _, -); refusing to run with it enabled"
  enabled=$(jq -r '.[] | select(.enabled != false) | .name' <<<"$after") || die "could not parse codex mcp list output"
  [ -z "$enabled" ] || die "MCP servers still enabled after the overrides: $(tr '\n' ' ' <<<"$enabled")"
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
    echo "reviewer=codex mode=document digest=sha256:$digest plugins_disabled=$plugins_disabled mcp_disabled=$mcp_disabled"
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
  # The reviewer reads surrounding code from the worktree, so it must be
  # exactly HEAD: an uncommitted or untracked file would be reviewed as if it
  # were part of the head SHA the header names.
  dirty=$(git status --porcelain --untracked-files=all) || die "git status failed"
  [ -z "$dirty" ] || die "worktree has uncommitted or untracked changes; commit or remove them before review:
$dirty"
  if [ "$reviewer" = codex ]; then
    codex_opts
    # `codex review` rejects --base together with a prompt, so the range
    # travels in the prompt.
    prompt="Review only the committed changes on this branch: \`git diff $merge_base...HEAD\` (base $base, head $head). Read the surrounding code as needed. This is a read-only review: change no files.

$brief"
    echo "reviewer=codex mode=change base=$base merge_base=$merge_base head=$head plugins_disabled=$plugins_disabled mcp_disabled=$mcp_disabled"
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
  # So does a worktree edited while it ran: the reviewer may have read it.
  [ -z "$(git status --porcelain --untracked-files=all)" ] || { echo "cross-review: worktree changed during review" >&2; rc=1; }
fi

echo "REVIEWER_EXIT=$rc"
[ "$rc" -eq 0 ] && status=COMPLETED
exit "$rc"
