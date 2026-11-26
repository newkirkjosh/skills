## Cross-model review

**Reviewed:** 2b8cea2 (merge base 2c5e237)
**Coverage:** Codex, change mode, 7 passes in 3 rounds over the change's own commits against `main`. Round 1: b5ca796, b7eaf28 (converged). Round 2, a delta review after the CodeRabbit fix: 7c0f6b1, 163e778 (converged). Round 3, a review on the new merge base after syncing with `main` 2c5e237: fe5e0f5, 4a02cac, 2b8cea2 (converged).
**Dispositions:**
- X-1 (`review-continuity.md:26`), level `cited`. Fixed in 66973c4. Commit classification now asks for the patch-id compare, record and re-check for every amended or rebased classified commit.
- CR-1 (CodeRabbit, `review-continuity.md:15`), level `ran`. Fixed in 484ed90, refined in 1e81303. `git patch-id --stable` ignores all whitespace, so a match now counts only when `git patch-id --verbatim` matches too.
- X-2 (`sprint-contract.md:10`), level `ran`. Fixed in 1e81303. `--stable`, which Story 1 names, stays the compared and recorded ID; `--verbatim` is the extra whitespace check.
- X-3 (`review-continuity.md:15`), level `ran`. Fixed in e0fe50b, refined in 2ad941d. Both patch-id modes ignore line numbers, so a hunk moved to an identical block still matches; the rule now checks the hunk targets too.
- X-4 (`review-continuity.md:15`), level `traced`. Fixed in 2ad941d. The X-3 check asked every hunk to land on the finding's cited location, which a fix with a test hunk, or a commit with no finding, can't meet. It now compares each rewritten hunk with its counterpart in the original commit.
**Unresolved blockers:** none.
**Evidence:** the review ledger outside the tracked tree, and the logs of all seven passes.
