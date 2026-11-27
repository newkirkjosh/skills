# Cross-review: Dev state

Status: unavailable. No convergence is claimed.

## History

- Round 1 (Claude reviewing Codex, three passes, last at 9a1b488): not converged. Blockers B1/R2, C1/E3 and B3 were fixed afterwards with regressions.
- Round 2 pass 1 (bf983dd): not converged. B3 (absent later branch) and F1 open; F2 non-blocking. Fixed at 34df2ba.
- Round 2 pass 2 (34df2ba): not converged. Open: B3 (later branch without a snapshot and no default folder), N1 (open PR head only on a remote-tracking ref), N2 (abbreviated ledger SHAs); N3 (branch-only `wt list` items) non-blocking.

## After round 2

Codex hit its usage limit, so Claude continued as author. N1, N2, N3 and the B3 variant were fixed with regressions first. A blind evaluator then found that a declared later-layer branch name did not resolve to its change (L1); that was fixed the same way. A fresh blind evaluator passed every contract item at 2a5de98 (75 mocked and 82 real-git cases).

These fixes after round 2 pass 2 have no review from the other model family. Round 2's final pass was not run.
