# Sprint Contract: Enforce lessons before writing them
**Change:** feat-learn-enforcement-check
**Date:** 2026-11-25
**Derived from:** specs/stories.md

## :catalog
Evaluated at: 7e48c136f034f98d7606ee4405d42f6e29252b68
Cross-review: codex, 2 pass(es), converged at 7f7bbd4 (round 3, after syncing main at 905bc4e; round 2 converged at 617ed5d on base c358d0f; round 1 at d5087c5 was unavailable)

Behavioral items are instruction replay of `specs/manual-checks.md` against the finished `skills/learn/SKILL.md` (fresh evaluator after the round-3 review fix, history-free export of the head above, base 905bc4e), not live runs.

- [x] The question is asked before any instruction text and names the catalog check script, bundled test and owning helper guard (B1)
- [x] When a check can decide the mistake, the correction is that check plus a test failing on it; instruction text only for the remaining judgment (B2, J3)
- [x] The check lives with the skill or script that owns the decision; no central rule table (B3, S7)
- [x] Review mode inherits the question: Apply still routes edits through Steps 5 and 6, and Summarize and Apply cite Step 5.1 by number with no second copy of the rule (B4)
- [x] Step 6.2 runs a new check's test on the reproduced mistake against the unfixed behavior and shows it fail on its assertion, not on setup, then pass with the correction and on a nearby valid input, recording both (B5)
- [x] A judgment lesson states why no check applies and stays an instruction edit (J1); the question is limited to demonstrated mistakes and keeps the inline-work rule (J2)
- [x] README `learn` row untouched (it describes no edit types); `inbox.md`, `AGENTS.md`, `REVIEW.md` unchanged; no new check written (S6, S8)
- [x] `agentskills validate` (11 skills), `check-descriptions.sh`, `check-refs.sh`, `bash -n` and all six script tests pass; SKILL.md 157 lines, only Steps 5, 6 and review-mode items 5-6 changed (S1-S3, S5, S9)
- [x] Private-term check (S4): coordinator-supplied, `scripts/check-private.sh` in the git worktree with `privacy.public=true` exits 0 at 7e48c13
