# Codex as the reviewer

Read when running `scripts/cross-review.sh codex` (from a Claude Code session) or triaging its output.

## How the script runs it

- Change mode runs `codex review` on the worktree; document mode runs `codex exec` on a snapshot directory. Both use a read-only sandbox with approvals off, and every enabled plugin and configured MCP server disabled.
- The script reads the enabled plugins from `codex plugin list --json` and disables each with `-c plugins.<pluginId>.enabled=false`, lists the MCP servers under those overrides, disables each remaining one with `-c mcp_servers.<name>.enabled=false`, then lists them again and refuses to run if any is still enabled. It refuses too when either list can't be read, is empty, or isn't the expected shape (plugins: an `.installed` array of objects with a string `pluginId` and boolean `enabled`; servers: an array of objects with a string `name`). The header line counts them (`plugins_disabled=`, `mcp_disabled=`). The overrides last for the run; `~/.codex/config.toml` is never written.
- `CROSS_REVIEW_MODEL` and `CROSS_REVIEW_EFFORT` override the model and reasoning effort for one run, never the user's config. Leave them unset to use Codex's defaults; never lower them to save time.

## Gotchas

- **Codex reads `AGENTS.md` only**, not `CLAUDE.md` or `REVIEW.md`. In a repository with a `REVIEW.md`, the review applies its rules only when `AGENTS.md` has a `## Code Review Rules` section pointing at it. If Codex flags something `REVIEW.md` explicitly allows, check whether the pointer exists and whether the rule actually covers the finding; assume neither a missing pointer nor a false premise. Record the evidence and any warranted clarification with the convention procedure in `review-continuity.md`.
- **Never call `codex review --base`**: it refuses a prompt alongside `--base`, so it can't carry the scope and reviews work the change deliberately left out. The script passes the range inside the prompt instead.
- **`-c` keys split on every dot and keep quotes literally.** `mcp_servers."x".enabled` addresses a key named `"x"`, not server `x`, and a server name containing `.` can't be addressed at all. The script uses bare segments, refuses such names, and re-lists the servers under its overrides before running.
- **A plugin can provide an MCP server that only the plugin's own override removes.** `-c mcp_servers.<name>.enabled=false` on such a server fails with `invalid transport`, so the script disables plugins by `pluginId` first and names only the servers still listed. A plugin ID containing `.` or `=` can't be addressed with `-c`; the script refuses it. Disabling every enabled plugin also drops the skills and tools it adds, which a read-only reviewer doesn't need.
- **The verdict is printed twice.** The log repeats the final message after the `codex` marker line; read the text after the last `codex` line, not the reasoning above it.
