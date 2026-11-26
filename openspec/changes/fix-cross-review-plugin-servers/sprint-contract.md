# Sprint Contract: Disable plugin-provided MCP servers for the Codex reviewer
**Change:** fix-cross-review-plugin-servers
**Date:** 2026-11-25
**Derived from:** specs/stories.md

## :catalog
Evaluated at: 6e09be40304dc7f6dc025459c1d4a20950db2c10
- [x] An enabled plugin whose server is in `codex mcp list` is disabled with `-c plugins.<pluginId>.enabled=false`, the re-list shows nothing enabled, and the review runs — plugin tests; live (read-only wrapper): 13 plugin overrides, re-list `[]`, header `plugins_disabled=13 mcp_disabled=0`, stopped at `codex review` by the wrapper
- [x] A plugin-provided server is never addressed by `mcp_servers.<name>` — "a plugin-provided server is not addressed by server name"
- [x] Regression reproduced with a stubbed `codex` and failing on base — head tests against base script: plugin tests fail; live base: `invalid transport in mcp_servers.linear`
- [x] Configured non-plugin servers are still disabled by name — "configured servers are still disabled by name"; real-codex test passes
- [x] The user's Codex config is never written — hash/file-count test; live sha256 of the config unchanged
- [x] Unreadable plugin list refuses (exit 3, `STATUS=ERROR`) — "refuses when the plugin list can't be read"
- [x] Unparsable, empty or wrong-shape plugin list refuses — parse, empty-output and shape/field-type tests
- [x] Plugin ID with `.` or `=` refuses; a disabled one doesn't block — two refusal tests, "a disabled plugin with an unaddressable ID doesn't block"
- [x] A server still enabled after the overrides refuses; empty or malformed MCP lists refuse — re-list and MCP shape tests
- [x] Header reports what was disabled, both modes — `plugins_disabled=` / `mcp_disabled=` tests
- [x] Also update: tests (75 passed, 0 failed), `references/codex.md`, header comment, unchanged Claude path — evaluator run
- [x] Privacy check — NOT RUN by the evaluator (export has no git); run by the coordinator in the worktree: `scripts/check-private.sh` exit 0
