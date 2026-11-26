## Cross-model review

**Reviewed:** ce3ee7d (merge base 67c349c), run through this branch's `cross-review.sh`, because `main`'s copy can't start Codex while a plugin provides an MCP server (the bug this change fixes). Header: `plugins_disabled=13 mcp_disabled=0`.
**Coverage:** codex, change mode, 3 passes in round 1.
**Dispositions:**
- F1 [P1] plugin list accepted when empty or the wrong shape (failed open): fixed in 6e09be4, verified in pass 2. The same fix covers both MCP list parses.
- F2 [P2] output with several JSON values passed, because `jq -e` judges only the last value: fixed in 31b15e5 (`jq -s`, exactly one value), verified in pass 3.
- F3 [P2] an enabled plugin with an empty ID, or a server with an empty name, was skipped: fixed in 31b15e5 with an allowlist `[A-Za-z0-9@_-]+` (whole-string anchors), verified in pass 3.
**Unresolved blockers:** none.
**Evidence:** pass 3: "No blocking issues found. Read-only checks verified that the committed F2 and F3 fixes reject multiple JSON values and empty or newline-containing identifiers."
