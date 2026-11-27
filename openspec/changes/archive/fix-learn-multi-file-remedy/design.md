# Design note: Reconcile every file of a multi-file learn remedy

| Option | For | Against |
|---|---|---|
| A. `Applied` lists each file with its recorded change; `shipped` needs all of them on the default branch; a partial landing is treated as "does not hold" for the existing PR/worktree rules, naming the missing part | Smallest change to the existing transition table; one rule for one or many files | The table rows read "the recorded change" and must say "every listed change" consistently |
| B. One record per file of the remedy | No new field shape | Splits one lesson into several records, which breaks grouping and duplicates evidence |
| C. Record only the PR and let a merged PR decide | Simple | Contradicts the existing rule that a merged PR alone never makes a record `shipped` |

**Choice:** A.

**Sacrifices:** none beyond longer `Applied` fields.
