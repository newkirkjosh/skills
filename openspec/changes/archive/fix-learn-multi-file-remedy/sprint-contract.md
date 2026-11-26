# Sprint Contract: Reconcile every file of a multi-file learn remedy
**Change:** fix-learn-multi-file-remedy
**Date:** 2026-11-26
**Derived from:** specs/stories.md

## :catalog
Cross-review: unavailable: not converged. Codex round 1 (3 passes) and round 2 after hosted review (3 passes) both hit the pass limit; round 2 pass 3 (4f9d40e) left Z-3 open (Step 3 no-op on a reopened partial landing), awaiting the owner.
Evaluated at: f4d40283e039c24cedeb1f4c986d876e708d02cc
Evaluator: fresh a34b2543532446b18 after the Codex round 2 fixes (Y-1, Y-2, Z-1, Z-2), history-free export, VERDICT: PASS. Replays ran real `git show` against scratch bare remotes with a gh stub under an isolated git config; all writes stayed in its scratch directory; the real inbox was never read or written. (Earlier PASSes: 4f5758b a31790a17cbc631a0; 47062a6 a960b20c79eada475; 81efe50 a4a8b00e24ff05e53; 094baf4 ad98dca8140ed7095; 50e07e0 a0f0aafd9fea18922 plus a2690744b45ab936f.)

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
- [x] R1: legacy one-file record → one-item list, shipped (inbox.md:49).
- [x] R2: legacy record, PR closed, change missing → open (inbox.md:57).
- [x] R3: both on default with an open PR → shipped (inbox.md:56; SKILL.md:128).
- [x] Also update: every remaining "recorded change" in skills/learn/ is per file (grep).
- [x] S1–S5: validators, descriptions (learn description unchanged), refs, check-private on a scratch git copy, bash -n per script and all six script tests pass.
- [x] S6: only skills/learn/SKILL.md, skills/learn/references/inbox.md and the change folder differ from base.
- [x] S7: singular-wording grep returns nothing.
- [x] S8: Step 5.1 and Summarize and ask unchanged.
- [x] S9: SKILL.md 157 lines; only review-mode steps 2 and 7 changed.
- [x] S10: all writes in the evaluator's scratch directory; inbox untouched.

