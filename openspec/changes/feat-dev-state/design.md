# Design

| Approach | Trade-off |
| --- | --- |
| Shell inspection helper | Reuses git/gh/wt; must keep ordered predicates aligned with lifecycle |
| Lifecycle runner | Adds write authority outside requested scope |

Choose a read-only shell entry point. Accept positional change/name/branch/PR plus documented team re-evaluation and sync options. Print stable `Playbook:` and `Step:` fields. Missing-folder recovery reports reconstruction rather than performing it. Unknown evidence fails closed. Tests establish the CLI before implementation. Read lifecycle.md and playbook-pickup.md as the routing authority.

CLI: `bash skills/dev/scripts/dev-state.sh <change|branch|PR-number|PR-URL> [--reevaluate-head <sha>] [--sync-pr <n> --expected-head <sha> --default-sha <sha>]`. Team options represent explicit team re-invocations. Stable fields: `Playbook: change|bug-fix|unresolved` and `Step: <entry label>`. Errors exit nonzero with diagnostics rather than inventing a step. Sync inspection reports the requested-sync entry only; it never performs the merge.
