# Sprint Contract: Reconcile every file of a multi-file learn remedy
**Change:** fix-learn-multi-file-remedy
**Date:** 2026-11-26
**Derived from:** specs/stories.md

## :catalog
Cross-review: unavailable for final delta after the provider rate limit; owner authorized continued Codex progress without it. Historical Codex findings through W-3 are fixed; no final converged cross-model review is claimed.
Evaluated at: f33a2dd5e3b642d225ad433e5ab559ad87fad200
Evaluator: fresh isolated Codex learn_final_eval replayed M0–M18 and R1–R3, all behavioral checks PASS. It used actual local Git fixtures and PR-state stubs, not executable product tests. Validators and script suites passed (cross-review 111/0, eval-export 12/0, verify-change 102/0). Its export lacked Git metadata for S4; fresh learn_privacy_eval independently completed S4 in a history-free scratch index: privacy check exit 0, all 144 snapshot files indexed, no missing/extra paths. Combined contract has no unchecked item. Coordinator also ran the real-worktree privacy check successfully.

- [x] M0: an Applied whose guard change contains "; " and ":" reads as exactly two entries, the guard whole (inbox.md:49).
- [x] M1: the template, the open→applied row and Record write every file with its own change (inbox.md:31-32, :55; SKILL.md:133).
- [x] M2: both changes on the default branch → shipped (inbox.md:51, :56; replay guard HOLDS, test HOLDS).
- [x] M3: PR merged without the test → open, naming the test (inbox.md:51, :57; SKILL.md:128).
- [x] M4: test reverted after merge → open; the check reads the current default tip (replay).
- [x] M5: open PR holding both, default holding neither → stays applied (inbox.md:58).
- [x] M5b: guard on default, open PR holding both → stays applied, test named (inbox.md:51, :58).
- [x] M5c: open PR lost the test → open, naming it (inbox.md:57).
- [x] M5d: guard on default, PR adds the test but deletes the guard → open, naming the guard (inbox.md:51; SKILL.md:128).
- [x] M6: a listed file without its change → unverifiable, checked first (inbox.md:59, :62).
- [x] M7: an edit plus a removal, each judged by its kind (inbox.md:49, :51; replay both ways).
- [x] M8: two entries in one file, the removal not landed → not shipped, removal named (inbox.md:32, :49; SKILL.md:133).
- [x] M9: Applied with metadata only → unverifiable before any default-branch check (inbox.md:59, :62).
- [x] M10: a legacy single-line Applied is read from its prose, one entry (inbox.md:49).
- [x] M11: reapplying a reopened partial landing keeps the still-required original entries unless superseded (SKILL.md:133).
- [x] M12: a legacy single line with code spans is read by its layout as one entry (inbox.md:49).
- [x] M13: reopening writes the reason after the existing entries and keeps them (inbox.md:57; SKILL.md:133).
- [x] M14: a reopened partial landing is not closed as already fixed unless every still-required entry holds (inbox.md:60).
- [x] M15: the Reopened: line is prose, never read as an entry (inbox.md:57; SKILL.md:133).
- [x] M16: partial remedy proposes missing changes instead of a no-op.
- [x] M17: pending changes elsewhere are identified; a partial pending remedy asks where to finish it rather than omitting required changes.
- [x] M18: default flow uses the selected worktree when provided; review mode always uses the default branch it will edit from.
- [x] R1: legacy one-file record → one-item list, shipped (inbox.md:49).
- [x] R2: legacy record, PR closed, change missing → open (inbox.md:57).
- [x] R3: both on default with an open PR → shipped (inbox.md:56; SKILL.md:128).
- [x] Also update: every remaining "recorded change" in skills/learn/ is per file (grep).
- [x] S1–S5: validators, descriptions (learn description unchanged), refs, check-private on a scratch git copy, bash -n per script and all six script tests pass.
- [x] S6: only skills/learn/SKILL.md, skills/learn/references/inbox.md and the change folder differ from base.
- [x] S7: singular-wording grep returns nothing.
- [x] S8: Step 5.1 and Summarize and ask unchanged.
- [x] S9: SKILL.md 157 lines; review-mode reconciliation/recording and Step 3.2 full-remedy presence/base selection changed; note mode and enforcement question unchanged.
- [x] S10: all writes in the evaluator's scratch directory; inbox untouched.

