# Sprint Contract: Batched learning review
**Change:** feat-learn-batched-review
**Date:** 2026-11-22
**Derived from:** specs/stories.md

## :catalog
Evaluated at: 0f6798298868866c964fdfacaeb0db60291cf6b3

All behavioral items are instruction replay of `specs/manual-checks.md` and eight added edge cases against the finished skill (fresh evaluator, history-free export of the head above), not live runs.

- [x] Note writes exactly one record with every required field and status `open`, with no catalog edit, worktree, commit or PR (C1)
- [x] No inbox named: report and write nothing; an inbox whose nearest existing ancestor is in a catalog or public checkout, or whose visibility can't be determined, is refused (C2, C3)
- [x] An unsupported lesson is asked about, or recorded with Cause `unestablished` (C4); a repeat is written and cites the earlier record (C5)
- [x] Review reads open and applied records, skips shipped and closed, and groups by owning skill and decision (R1, R2)
- [x] Recurrence orders investigation but never proves; cause, owner and duplicates come from Steps 1-3 before any edit; a group with no cause stays open (R3, R4)
- [x] Project and preference lessons are routed outside the catalog (R5); closing needs evidence, never non-recurrence or elapsed time (R6)
- [x] A ranked summary and the user's approval come before any worktree, catalog edit or record write; no answer writes nothing (R7)
- [x] Approved edits run through Steps 4-7, one worktree per owning catalog; a record-only approval creates no worktree (R8, R10, R11)
- [ ] An applied record names its worktree or PR, file and recorded change: edited text, or a removal (R9)
- [ ] Shipped means the recorded change holds on the owning catalog's default branch, by PR or otherwise, written in the Record step after approval; closed PR, gone worktree or a change that no longer holds reopens; unverifiable applied records are reported and asked about (T1-T7)
- [ ] A removal ships when the removed text or file is absent on the default branch (T8); a PR closed unmerged reopens the record even when its worktree still holds the change (T9)
- [ ] The default-branch change is checked first and decides shipped; a worktree confirmed gone with no PR and no text reopens; an access failure is reported as unverifiable; a fix that landed outside the catalog is closed with evidence from that destination, never applied
- [ ] A fix pending in another change keeps the record open with the change in `Pending`; an exact fix already on the default branch closes it with evidence
- [x] The single-correction Steps 1-7 are unchanged and an ambiguous request takes that flow (E1, E2)
- [x] Description keeps the explicit-use opener, names both modes, 613 characters; `agentskills validate`, `check-descriptions.sh`, `check-refs.sh`, all script tests and `bash -n` pass (S1, S2, S5, S6); README row updated (S4)
- [x] Private-term check (S3): coordinator-supplied, `scripts/check-private.sh` in the git worktree with `privacy.public=true` exits 0
