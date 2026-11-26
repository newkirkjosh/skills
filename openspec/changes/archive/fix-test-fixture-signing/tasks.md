# Tasks: Keep test fixture commits off the user's signing setup
**Change:** fix-test-fixture-signing
**Date:** 2026-11-26

## :catalog
- [ ] Regression check in each suite that fails when a fixture commit is signed or the suite reads the user's global git config.
- [ ] Isolate `skills/cross-review/scripts/test-cross-review.sh` and `skills/dev/scripts/test-eval-export.sh` from global and system git config, including the stub's `STUB_COMMIT` commit.
- [ ] Update each suite's header comment if it describes the environment.
