# Proposal: Keep test fixture commits off the user's signing setup
**Change:** fix-test-fixture-signing
**Story group:** none (bug issue #47)
**Date:** 2026-11-26

## Scope
The throwaway repositories in `test-cross-review.sh` and `test-eval-export.sh` stop reading the user's global and system git config, so fixture commits never sign or run global hooks. Each suite checks that its fixture commits are unsigned.

## Rationale
With `commit.gpgsign=true` globally, every fixture commit went through the signing agent; a locked agent failed dozens of unrelated tests and made the suites slow, and unattended runs can't unlock it.

## Out of scope
- `cross-review.sh` and `eval-export.sh` (no commits).
- `scripts/test-install.sh` (already isolated).
- CI workflows, and signing of real commits.
