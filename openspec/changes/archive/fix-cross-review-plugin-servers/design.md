# Design note: Disable plugin-provided MCP servers for the Codex reviewer

| Option | For | Against |
|---|---|---|
| A. Disable enabled plugins by ID from `codex plugin list --json`, then servers by name, then re-list | Uses Codex's own resolved list; no TOML parsing; plugin-level override is verified to work (`plugins.linear@claude-plugins-official.enabled=false` empties `codex mcp list`) | One more Codex call; disables plugin skills too |
| B. Parse `[plugins."<id>"]` from `~/.codex/config.toml` (as #37 suggested) | No extra call | Needs a TOML parser (Python) and misses plugins enabled elsewhere (profiles, project config) |
| C. Map each plugin-provided server name back to its plugin | Disables only what's needed | No reliable mapping exposed |

**Choice:** A. Quoted keys are not an option: Codex keeps quotes literally, so only bare segments work, and IDs with `.` or `=` are refused.

**Sacrifices:** every enabled plugin is off for the review, not only the ones that add servers.
