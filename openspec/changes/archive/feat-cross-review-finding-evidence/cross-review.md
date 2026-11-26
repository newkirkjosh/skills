## Cross-model review

**Reviewed:** attempted at 508157a and at b246dfb (merge base 67c349c)
**Coverage:** unavailable: Codex refused to start. `cross-review.sh` disables each MCP server with `-c mcp_servers.<name>.enabled=false`; this host's `linear` server comes from a Codex plugin, and the override produced `invalid transport in mcp_servers.linear`, so the script refused to run (`STATUS=ERROR`).
**Dispositions:** none (no pass ran).
**Unresolved blockers:** the required cross-model review is unmet, so autonomous merge is blocked until it runs.
**Evidence:** the review ledger outside the tracked tree; the script's own refusal message above.
