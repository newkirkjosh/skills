# Design note: Enforce lessons before writing them

| Option | For | Against |
|---|---|---|
| A. One question at Step 5, with Step 6 proving the check | Smallest change; review mode inherits it | Relies on the agent asking honestly |
| B. Central rule-to-enforcer table in AGENTS.md (pstack `correct`) | Visible audit | Duplicates policy across owners |
| C. A new skill | Separate concern | Splits one decision across two owners |

**Choice:** A.

**Sacrifices:** no catalog-wide view of which rules are enforced.
