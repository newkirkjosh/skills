# Sprint Contract: Dev state
**Change:** feat-dev-state
**Date:** 2026-11-27
**Derived from:** specs/stories.md

## :catalog
- [x] Feat-name, branch, PR number and PR URL inputs resolve the change, including an archived folder on the default ref.
- [x] A folder counts only with `scope-brief.md`, or `proposal.md` plus `tasks.md`; an unrelated directory counts as missing and is preserved.
- [x] Another change's branch never claims this change: shared-prefix siblings, undeclared suffixes, inherited archives and fork PRs.
- [x] A recorded `Playbook:` wins over the branch prefix in both directions.
- [x] The prefix fallback applies only to a verified folder without a recorded field; without a verified folder the playbook stays unresolved.
- [x] An unsupported, blank, multiword or conflicting playbook stops nonzero with no step.
- [x] Entry rows 1–15 select the right entry, first match wins.
- [x] "The layer" is the first with an open sub-issue; layers sharing one issue act as one unit.
- [x] A merged PR on any branch of the change selects Phase 6 close-out for that branch's own layer.
- [x] An interrupted sync preempts everything, including a re-evaluation request.
- [x] A re-evaluation request at the matching head selects a fresh Phase 3 ahead of sync and handoff; a wrong head reports head mismatch.
- [x] A sync request precedes handoff and the table and rejects a changed PR or local head, a merged or retargeted PR and a dirty worktree, never recreating a worktree.
- [x] `handoff.md` preempts the table; an earlier layer's stale handoff does not.
- [x] Unavailable or ambiguous gh, PR or tracker evidence exits nonzero with no fabricated step.
- [x] Bad options are rejected.
- [x] The helper issues no lifecycle writes: repository files, refs, index and worktrees are unchanged.
- [x] Offline fixtures stub git, gh and wt and reject writes.
- [x] Dev usage documentation covers the CLI.
- [x] CI runs the offline shell tests.

Not a contract item: the evaluator's stricter "nothing under `.git` changes" reading. `wt list` writes worktrunk's own cache and default-branch setting; the Scope Brief excludes lifecycle writes only, and `dev`'s own status read makes the same call. Documented in `references/dev-state.md`.

Evaluated at: 2a5de98f119b7caff94641c6bd9e2f366e213589
Cross-review: unavailable: Codex usage limit reached after Claude reviewed Codex's work for two rounds (not converged at 34df2ba); later fixes are by Claude and have no other-family review
