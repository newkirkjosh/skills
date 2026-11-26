# Sprint Contract: Evidence on every review finding
**Change:** feat-cross-review-finding-evidence
**Date:** 2026-11-25
**Derived from:** specs/stories.md

## :catalog
Evaluated at: 3015b3ebc11a55f7efb845961b6d0750c6f85add

- [x] The prompt asks each blocking finding for its evidence (file:line, traced failure, or a command with its output). Observed: `skills/cross-review/SKILL.md` Step 2 prompt text.
- [x] The ledger records evidence and a level for every finding, hosted-triage findings included. Observed: `SKILL.md` Step 4 and `references/review-continuity.md` per-finding Evidence bullet.
- [x] The returned Dispositions show each finding's evidence level. Observed: `SKILL.md` Result, Dispositions field.
- [x] Triage runs a permitted check on an argument-only finding before accepting it for a fix pass and records the result as its evidence. Observed: `SKILL.md` Step 4; `review-continuity.md` Evidence bullet.
- [x] A finding no check can settle is triaged on its argument. Observed: `SKILL.md` Step 4.
- [x] Document-mode findings and defects provable by reading are not rejected for lacking a run. Observed: `SKILL.md` Step 4.
- [x] The reviewer sandbox and `cross-review.sh` are unchanged. Observed: `diff -r` of base and head exports lists only `SKILL.md` and `review-continuity.md`; `test-cross-review.sh` rc=0.
- [x] Also update: `SKILL.md` Step 2, Step 4 and Dispositions changed. Observed in the head export.
- [x] Also update: `review-continuity.md` per-finding Evidence record changed. Observed in the head export.
- [x] Also update: `claude.md` left unchanged because `SKILL.md` Step 4 states the Claude reviewer's strongest level is `traced`. Observed in the head export.
- [x] `dev`, `team` and the patch-id change untouched. Observed: `diff -r` of the exports.

Evidence: evaluator run a2d12f6559227dd5c on the head export at the SHA above: `agentskills validate` on all 11 skills, `check-descriptions.sh`, `check-refs.sh`, `bash -n`, and all six `test-*.sh` scripts, each rc=0. `check-private.sh` could not run on the history-free export; the coordinator ran it in the worktree at the same SHA (rc=0, coordinator-supplied evidence).
