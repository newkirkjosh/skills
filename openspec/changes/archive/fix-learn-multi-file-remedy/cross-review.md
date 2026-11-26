## Cross-model review

**Reviewed:** 6d1aa4d (merge base b03fc62)
**Coverage:** Codex, change mode, 3 passes over the whole change against `main`: 655d05f, cdd3f86, 6d1aa4d.

| Finding | Where | Disposition |
|---|---|---|
| X-1 a default-branch change counted as held in a PR or worktree that removes it | `inbox.md`, `SKILL.md` Reconcile | Fixed in 094baf4: each listed change is checked at the PR head or in the worktree's files |
| X-2 `; `-separated entries split a change containing `; ` | `inbox.md` template, `SKILL.md` Record | Fixed in 094baf4: one entry per line, change in a code span |
| X-3 one change per file can't record a guard plus a removal in the same file | `inbox.md`, `SKILL.md` Record | Fixed in 81efe50: one entry per change |
| X-4 an `Applied` with no entries passes completeness | `inbox.md`, `SKILL.md` Reconcile | Fixed in 81efe50: at least one entry, else unverifiable |
| X-5 Story 1 said "one-file remedy" is a one-item list, contradicting X-3 | change folder `specs/stories.md` | Fixed in ff8ee60 (story wording only); not re-reviewed, since pass 3 was the last allowed pass |

Pass 3 verified X-1 to X-4 in the runtime instructions. Each behavioral fix was re-evaluated by a fresh blind evaluator (last PASS at 81efe50).
