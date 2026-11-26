# Design note: Keep Codex connected apps away from the reviewer

| Option | For | Against |
|---|---|---|
| A. Force `-c features.apps=false` and verify with `codex features list` under the same options | Mirrors the MCP re-list check; fails closed; verified live (`apps stable false` under the override) | Depends on the `features list` text format, so an unrecognised format refuses |
| B. Force the override without verifying | Simplest | A renamed or ignored key would fail open silently |
| C. Disable each app by name | Finer control | No reliable list of apps is exposed |

**Choice:** A.

**Sacrifices:** a future change to `codex features list` output stops reviews until the check is updated (fail closed).
