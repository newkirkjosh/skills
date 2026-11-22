# Sprint Contract: Batched learning review
**Change:** feat-learn-batched-review
**Date:** 2026-11-22
**Derived from:** specs/stories.md

## :catalog
Evaluated at: 60161f071a4ad7da3af0b2df0e9ec5e75e6f0ae4

All behavioral items are instruction replay of `specs/manual-checks.md` against the finished skill (fresh evaluator, export of the head above), not live runs.

- [x] Note writes exactly one record with every required field and status `open`, with no catalog edit, worktree, commit or PR (C1)
- [x] No inbox named: report and write nothing (C2)
- [x] An inbox inside a catalog or public repository is refused; no inbox path in the skill (C3)
- [x] An unsupported lesson is asked about, or recorded with Cause `unestablished`, never guessed (C4)
- [x] A duplicate note is written and cites the earlier record (C5)
- [x] Review reads open and applied records and skips shipped and closed (R1), grouped by skill and decision (R2)
- [x] Recurrence orders investigation but never proves; a group with no demonstrated cause gets no edit and stays open (R3, R4)
- [x] Project and preference lessons are routed outside the catalog (R5); closing needs evidence, never non-recurrence or elapsed time (R6)
- [x] A ranked summary and the user's approval come before any worktree or edit (R7); approved edits run in one worktree through Steps 4-7 (R8)
- [x] An applied record names its worktree or PR, file and edited text (R9); review makes no publish decision (R10); an empty inbox stops (R11)
- [x] Applied records move to shipped only with a merged PR and the text on the default branch, back to open when the PR closed, the worktree is gone, or the recorded text is gone, and stay applied otherwise (T1-T7)
- [x] The single-correction Steps 1-7 are unchanged and an ambiguous request takes that flow (E1, E2)
- [x] Description keeps the explicit-use opener, names both modes, under 1024 characters; `agentskills validate`, `check-descriptions.sh`, `check-refs.sh`, script tests and `bash -n` pass (S1, S2, S5, S6)
- [x] README `learn` row updated (S4)
- [x] Private-term check (S3): coordinator-supplied, `scripts/check-private.sh` in the git worktree with `privacy.public=true` exited 0 at 60161f0; the commit hook ran the local term list on every commit
