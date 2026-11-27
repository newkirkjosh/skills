# Sprint contract

## docs

Evaluated at: edbc478ce2448195f28d62aa0336aad271c02fab

- [x] Immediate rejection preserves denial and produces BLOCKED without timeout or retry — PASS, adapter permission-result walkthrough through team supervision.
- [x] Verified pending prompt informs user, is never answered, stops/holds after 30 minutes — PASS, conditional supervision/hold walkthrough.
- [x] Unknown host behavior remains unknown — PASS, adapter and idle-output walkthrough.
- [x] Preflight rejection fails with denial and cleanup; no permission policy change — PASS, preflight walkthrough.
- [x] Adjacent hold guidance remains consistent — PASS, termination/cleanup uncertainty retains hold.
- [x] All validators, description/reference checks, shell syntax and six offline regression suites — PASS.

Fresh evaluation: observed pending prompts verify waiting for that request, including on an otherwise unverified host — PASS. Validators, descriptions, references and scenario walkthroughs passed; prior unrelated offline regressions retained.

VERDICT: PASS. Independent evaluator used history-free exports and scenario walkthroughs; no new live failure injection. Coordinator separately passed tracked-file privacy checks. Existing issue #38 supplies host observation evidence.

Cross-review: Claude, 2 completed passes, converged at f029ce97daf77c9a937b0d636d9ca2cf5b62c932. Earlier usage-limited attempt returned no review. X-1 fixed by clarifying that an observed pending prompt verifies waiting for that request.
