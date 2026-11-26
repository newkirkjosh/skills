# Proposal: Disable plugin-provided MCP servers for the Codex reviewer
**Change:** fix-cross-review-plugin-servers
**Story group:** none (bug #37)
**Date:** 2026-11-25

## Scope
`cross-review.sh` disables every enabled Codex plugin at the plugin level (`-c plugins.<id>.enabled=false`, IDs from `codex plugin list --json`) before disabling servers by name, and keeps its re-list check, so a plugin-provided server no longer stops every Codex review.

## Rationale
With the Linear plugin enabled, the per-server override produces "invalid transport in mcp_servers.linear" and the script refuses to run, so no Codex review can run and every merge that needs one is blocked.

## Out of scope
- Codex connected apps / `features.apps` (#39, next change, same files).
- The Claude reviewer path.
- Editing the user's Codex config.
