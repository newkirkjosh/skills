# Sprint Contract: Disable plugin-provided MCP servers for the Codex reviewer
**Change:** fix-cross-review-plugin-servers
**Date:** 2026-11-25
**Derived from:** specs/stories.md

## :catalog
Evaluated at: 31b15e5e67c3c6130ecd7f092321f47a3e0bfc3b
Cross-review: codex, 3 passes, converged at ce3ee7d (run through this branch\'s cross-review.sh; main\'s copy cannot start Codex, the bug under fix)
- [x] An enabled plugin whose server is in `codex mcp list` is disabled with `-c plugins.<pluginId>.enabled=false`, the re-list shows nothing enabled, and the review runs — plugin tests; live (read-only wrapper): 13 plugin overrides, re-list `[]`, header `plugins_disabled=13 mcp_disabled=0`, stopped at `codex review` by the wrapper
- [x] A plugin-provided server is never addressed by `mcp_servers.<name>` — "a plugin-provided server is not addressed by server name"
- [x] Regression reproduced with a stubbed `codex` and failing on base — head tests against base script: plugin tests fail; live base: `invalid transport in mcp_servers.linear`
- [x] Configured non-plugin servers are still disabled by name — "configured servers are still disabled by name"; real-codex test passes
- [x] The user's Codex config is never written — hash/file-count test; live sha256 of the config unchanged
- [x] Unreadable plugin list refuses (exit 3, `STATUS=ERROR`) — "refuses when the plugin list can't be read"
- [x] Unparsable, empty, wrong-shape or multi-value plugin list refuses — parse, empty-output, shape/field-type and multi-value tests
- [x] Plugin ID with `.` or `=` (now any ID outside `[A-Za-z0-9@_-]+`, empty included) refuses; a disabled one doesn't block — refusal and allowlist tests, "a disabled plugin with an unaddressable ID doesn't block"
- [x] A server still enabled after the overrides refuses; empty or malformed MCP lists refuse — re-list and MCP shape tests
- [x] Header reports what was disabled, both modes — `plugins_disabled=` / `mcp_disabled=` tests
- [x] Also update: tests (97 passed, 0 failed), `references/codex.md`, header comment, unchanged Claude path — evaluator run
- [x] Privacy check — NOT RUN by the evaluator (export has no git); run by the evaluator at 31b15e5 and by the coordinator in the worktree: `scripts/check-private.sh` exit 0
