# Sprint Contract: Keep test fixture commits off the user's signing setup
**Change:** fix-test-fixture-signing
**Date:** 2026-11-26
**Derived from:** specs/stories.md

## :catalog
Evaluated at: 52f23e999ebf19ca145ee36a416ce998110fd8ce
Evaluator: fresh agent a404c5e69ce3432ee, history-free export, VERDICT: PASS. Every run used a scratch GIT_CONFIG_GLOBAL; the real signing program was never invoked.

- [x] `test-cross-review.sh` passes with global `commit.gpgsign=true` and a failing signing program: head 111 passed, 0 failed, rc=0 (base 72 passed, 37 failed, "gpg failed to sign the data").
- [x] `test-eval-export.sh` passes under the same config: head 12 passed, 0 failed, rc=0 (base 6 passed, 4 failed).
- [x] Neither suite invokes the signing program: a logging failing signer logged 0 calls on head for both suites (2 per suite on base).
- [x] Neither suite runs the user's global git hooks: a logging failing `core.hooksPath` pre-commit hook logged 0 calls on head (2 per suite on base, both suites failed).
- [x] Fixture commits need no configured identity: with no global config visible, commits land via the exported GIT_AUTHOR_*/GIT_COMMITTER_* variables (2 commits in eval-export, the stub's `moved` commit in cross-review).
- [x] `test-cross-review.sh` regression check catches a regression: with a scratch SSH key that really signs, removing the isolation export fails both fixture checks (109 passed, 2 failed, rc=1); making only the stub's commit read the signing config fails the unsigned check (110 passed, 1 failed, rc=1).
- [x] `test-eval-export.sh` regression check catches a regression: removing the export fails both fixture checks (10 passed, 2 failed, rc=1).
- [x] The stub's `STUB_COMMIT` commit runs isolated: "fixture: the stub's commit landed and no fixture commit is signed" passes on head; the stub-only mutation above is caught.
- [x] Header comments: both suites explain the isolation above the export; `test-eval-export.sh`'s usage line names itself.

Gaps recorded by the evaluator (not contract items):
- `scripts/test-install.sh` (out of scope, unchanged) still fails when a global `core.hooksPath` hook fails on throwaway repos; it passes with signing alone. Base fails the same way.
- The regression checks only bite on a machine that has global or system git config; a bare CI runner passes either way.
