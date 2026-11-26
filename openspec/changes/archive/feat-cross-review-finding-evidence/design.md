# Design note: Evidence on every review finding

| Option | For | Against |
|---|---|---|
| A. Evidence field + level in prompt, ledger and result; caller checks argument-only findings during triage | Uses existing triage step; no script change; works for both reviewers | Levels are self-reported by the reviewer until triage checks them |
| B. Require a run for every finding (pstack `interrogate`) | Strongest filter | Claude reviewer has no shell; drops document and read-provable findings; needs sandbox changes the Merge policy reserves |
| C. Leave as is | No work | Fix passes keep going to argument-only findings |

**Choice:** A. The prompt asks for evidence, the ledger records it with a level, and Step 4 triage runs a permitted check when one would settle an argument-only finding.

**Sacrifices:** no hard proof bar; a `cited` finding can still block.
