## Cross-model review

**Reviewed:** 4f9d40e (merge base b03fc62)
**Coverage:** Codex, change mode, 6 passes in 2 rounds: 655d05f, cdd3f86, 6d1aa4d, then after CodeRabbit's review 3e2b459, 167356a, 4f9d40e.
**Result:** not converged. One in-scope finding is open (Z-3). Both rounds hit the 3-pass limit.

| Finding | Disposition |
|---|---|
| X-1 a default-branch change counted as held in a PR or worktree that removes it | Fixed in 094baf4 |
| X-2 `; `-separated entries split a change containing `; ` | Fixed in 094baf4 |
| X-3 one change per file | Fixed in 81efe50 |
| X-4 an `Applied` without entries passes completeness | Fixed in 81efe50 |
| X-5 story said "one-file remedy" | Fixed in ff8ee60 (story wording) |
| CR-1..CR-3 (CodeRabbit) | Fixed in 47062a6 |
| Y-1 reopening could replace the entries | Fixed in 4f5758b |
| Y-2 legacy records keyed on "no code spans" | Fixed in 4f5758b |
| Y-3 stale coverage line in the contract | Fixed (this record) |
| Z-1 a reopened partial landing closed as "already fixed" | Fixed in f4d4028 |
| Z-2 reopen reason readable as an entry | Fixed in f4d4028 |
| **Z-3** Step 3's "already present, no-op" fires on a reopened partial landing, so review never proposes the missing test | **Open**: needs the owner's call |

Each behavioral fix was re-evaluated by a fresh blind evaluator (last PASS at f4d4028).
