# Specs: Disable plugin-provided MCP servers for the Codex reviewer

## Story 1
When an enabled Codex plugin provides an MCP server, I want a Codex cross-review to still run with that server disabled, so the review isn't blocked by an app I installed.

### Acceptance criteria
- [ ] With an enabled plugin whose server appears in `codex mcp list`, the script disables the plugin with `-c plugins.<pluginId>.enabled=false`, the re-list shows no enabled server, and the review runs.
- [ ] Broken today: with the same setup, the current script exits with a setup error ("codex rejected the MCP overrides"); a regression test reproduces it with a stubbed `codex`.
- [ ] Configured (non-plugin) servers are still disabled by name, as today.
- [ ] The user's Codex config file is never written.

## Story 2
When the script can't be sure every plugin and server is off, I want it to refuse to run, so a reviewer never runs with tools that could write somewhere or hang.

### Acceptance criteria
- [ ] An unreadable or unparsable plugin list refuses to run (setup error, exit 3, `STATUS=ERROR`).
- [ ] A plugin ID containing `.` or `=` refuses to run.
- [ ] Any server still enabled after the overrides refuses to run, as today.
- [ ] The header line reports what was disabled.
