# Proposal: Keep Codex connected apps away from the reviewer
**Change:** fix-cross-review-codex-apps
**Story group:** none (security issue #39)
**Date:** 2026-11-25

## Scope
`cross-review.sh` always passes `-c features.apps=false` to the Codex reviewer and refuses to run unless `codex features list` under the reviewer's options shows `apps` off.

## Rationale
Connected apps reach a Codex reviewer as `mcp__codex_apps__*` tools, including write actions, even with every MCP server disabled and a read-only sandbox, because the sandbox only limits local commands.

## Out of scope
- Plugin and MCP server handling (#45, merged).
- The Claude reviewer path.
- Editing the user's Codex config.
