# Sprint Contract: Evidence on every review finding
**Change:** feat-cross-review-finding-evidence
**Date:** 2026-11-25
**Derived from:** specs/stories.md

## :catalog
Evaluated at: d0fed3d711260f8c47c9f68cd4f308aa42f91025
Cross-review: codex, 3 pass(es), converged at d0fed3d

- [x] The Step 2 prompt asks each blocking finding for its evidence (file:line, traced failure, or a command with its output). Observed: `skills/cross-review/SKILL.md` Step 2 prompt text.
- [x] Every finding, hosted triage included, records its evidence and exactly one level: `cited`, `traced` or `ran`. Observed: `SKILL.md` Step 4; `references/review-continuity.md` per-finding Evidence bullet.
- [x] Triage runs a permitted check on an argument-only finding before accepting it for a fix pass and records the result as its evidence (level `ran`). Observed: `SKILL.md` Step 4; `review-continuity.md` Evidence bullet.
- [x] A finding no permitted check can settle is triaged on its argument and never rejected for lacking a run; document-mode and read-provable findings stand at `cited` or `traced`. Observed: `SKILL.md` Step 4.
- [x] The Result's Dispositions show each finding's evidence level. Observed: `SKILL.md` Result, Dispositions field.
- [x] Also update: `review-continuity.md` per-finding Evidence record. Observed in the head export.
- [x] Also update: `claude.md` left unchanged because `SKILL.md` Step 4 states the Claude reviewer's strongest level is `traced`. Observed in the head export.
- [x] The levels are labels, not a gate: a `cited` finding can still block. Observed: `SKILL.md` Step 4 ("Never reject a finding for lacking a run").
- [x] `cross-review.sh` and its tests, `dev` and `team` unchanged. Observed: `diff -r` of the base and head exports lists only `SKILL.md` and `review-continuity.md`.
- [x] Repository checks pass. Evaluator run: `agentskills validate` on all 11 skills, `check-descriptions.sh`, `check-refs.sh`, `bash -n`, all six `test-*.sh` scripts, each rc=0.

Evidence: fresh evaluator run a0d20d36621ac1384 on the head export at the SHA above (re-evaluation after the cross-review fix X-1). `check-private.sh` cannot run on the history-free export; the coordinator ran it in the worktree on the same tree (rc=0, coordinator-supplied evidence).
