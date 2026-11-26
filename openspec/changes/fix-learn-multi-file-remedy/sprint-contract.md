# Sprint Contract: Reconcile every file of a multi-file learn remedy
**Change:** fix-learn-multi-file-remedy
**Date:** 2026-11-26
**Derived from:** specs/stories.md

## :catalog
Evaluated at: 50e07e0a6a1ed207ea0f58dc86b037907b5c6dcc
Evaluators: a0f0aafd9fea18922 (history-free export; 24 of 25 PASS, S10 NOT RUN after its own stray /tmp write, since deleted), then fresh a2690744b45ab936f for S10 only (PASS). Replays ran against scratch repos with a gh stub under an isolated git config; the real inbox was never read or written.

- [x] M1: the template, the open→applied row and Record write every file with its own change (inbox.md:31, :52; SKILL.md:133).
- [x] M2: both changes on main → shipped (inbox.md:53; replay: shipped, all on the default branch).
- [x] M3: PR merged with only the guard → open, naming the missing test (inbox.md:48, :54; replay).
- [x] M4: test reverted on main after merge → open (replay).
- [x] M5: open PR holding both → stays applied (inbox.md:55; replay).
- [x] M5b: guard on main, PR open with both → stays applied, names the test (inbox.md:48; replay).
- [x] M5c: PR dropped the test → open, naming it (inbox.md:54; replay).
- [x] M6: a listed file without its change → unverifiable, checked before main (inbox.md:56, :59; replay).
- [x] M7: edit plus removal judged per change (inbox.md:48; replay both ways).
- [x] R1: legacy one-file record → one-item list, ships (inbox.md:48; replay).
- [x] R2: legacy record, PR closed unmerged → open (replay).
- [x] R3: default branch still wins over an open PR (inbox.md:53; SKILL.md:128; replay).
- [x] Story 2 c3: Reconcile in SKILL.md states the same rule as inbox.md (SKILL.md:128).
- [x] Also update: no singular Applied wording left in skills/learn/ (grep).
- [x] S1–S5: validators, descriptions, refs, check-private (scratch git copy, rc 0), bash -n and all 6 script tests pass.
- [x] S6: only skills/learn/SKILL.md, skills/learn/references/inbox.md and the change folder differ from base.
- [x] S7: singular-wording grep returns nothing.
- [x] S8: Step 5.1 and Summarize and ask unchanged against base.
- [x] S9: SKILL.md 157 lines; only Reconcile and Record lines differ.
- [x] S10: nothing in the diff writes or points outside the repository; inbox untouched (diff read; inbox dir mtime predates the export) — evaluator a2690744b45ab936f.
