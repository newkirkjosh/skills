# Cross-review: Dev state

Reviewed: 9a1b48873934382ad0138831de1c0b6f27bbb694
Merge base: 9571fcfa912c49a7174f5f36ef6a21e4aadda3b4
Coverage: Claude reviewing Codex, three direct read-only delegate passes. Not converged.

## Open blockers

- B1/R2: comparing legacy artifacts against the current default tip mistakes inherited archives for branch-owned state after default changes.
- C1/E3: after squash merge, matching default-tip artifacts causes retained legacy branches and their merged PRs to lose change association.
- B3: handoff is checked before selected-layer artifact reload, so a kept earlier branch can supply a stale handoff or hide the selected layer's handoff.

Evidence: Claude reproduced all three in temporary Git repositories at the reviewed head. The bundled suite passes 73 stubbed and 16 real-Git cases but does not cover these probes yet. Original cwd, sibling branch, shared-unit contract, reevaluation and explicit PR identity findings are fixed. Fork-list filtering is fixed.

Round 1 exhausted its three passes. No fourth pass is authorized. No merge readiness or convergence is claimed.
