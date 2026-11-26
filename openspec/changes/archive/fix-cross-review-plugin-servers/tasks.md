# Tasks: Disable plugin-provided MCP servers for the Codex reviewer
**Change:** fix-cross-review-plugin-servers
**Date:** 2026-11-25

## :catalog
- [ ] Regression tests in `skills/cross-review/scripts/test-cross-review.sh` with a stubbed `codex`: plugin-provided server (fails today), unreadable plugin list, plugin ID with `.`, non-plugin server still disabled by name.
- [ ] In `codex_opts()` of `skills/cross-review/scripts/cross-review.sh`, disable enabled plugins by ID before servers, refuse unaddressable IDs and unreadable lists, keep the re-list check, and report counts in the header.
- [ ] Update the header comment and `skills/cross-review/references/codex.md`.
