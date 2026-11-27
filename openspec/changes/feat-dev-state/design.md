# Design

| Approach | Trade-off |
| --- | --- |
| Shell inspection helper | Reuses git/gh/wt; must keep ordered predicates aligned with lifecycle |
| Lifecycle runner | Adds write authority outside requested scope |

Choose a read-only shell entry point. Accept positional change/name/branch/PR plus documented team re-evaluation and sync options. Print stable `Playbook:` and `Step:` fields. Missing-folder recovery reports reconstruction rather than performing it. Unknown evidence fails closed. Tests establish the CLI before implementation. Read lifecycle.md and playbook-pickup.md as the routing authority.
