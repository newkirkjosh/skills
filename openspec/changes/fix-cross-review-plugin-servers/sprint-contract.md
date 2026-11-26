# Sprint Contract: Disable plugin-provided MCP servers for the Codex reviewer
**Change:** fix-cross-review-plugin-servers
**Date:** 2026-11-25
**Derived from:** specs/stories.md

## :catalog
Evaluated at: e4dd557d7aee88fb140c3c679a6de0eec93e36cb
- [x] An enabled plugin whose server is in `codex mcp list` gets `-c plugins.<pluginId>.enabled=false`, the re-list shows nothing enabled, and the review runs — `test-cross-review.sh` plugin tests; live: real codex accepted 13 plugin overrides, re-list empty, header `plugins_disabled=13 mcp_disabled=0` (review call stopped by a shim)
- [x] Plugin-provided servers are not addressed by server name — `plugin: a plugin-provided server is not addressed by server name`
- [x] Regression: the pre-change script fails this setup — head's tests against base's script: 14 failed; live base run: `invalid transport in mcp_servers.linear`, `STATUS=ERROR`
- [x] Configured servers are still disabled by name — `plugin: configured servers are still disabled by name`
- [x] The user's Codex config is never written — `plugin: the user's Codex config is never written` (sha256 unchanged)
- [x] Unreadable plugin list refuses to run (exit 3, `STATUS=ERROR`) — `plugin: refuses when the plugin list can't be read`
- [x] Unparsable plugin list refuses to run — `plugin: refuses when the plugin list can't be parsed`
- [x] Plugin ID with `.` or `=` refuses to run — dot and `=` refusal tests
- [x] A server still enabled after the overrides refuses to run — `plugin: refuses when a server stays enabled after the overrides`
- [x] The header reports what was disabled — `plugins_disabled=` / `mcp_disabled=` tests
- [x] Also update: tests (58 passed, 0 failed), `references/codex.md`, header comment, document mode and unchanged Claude path — evaluator run
