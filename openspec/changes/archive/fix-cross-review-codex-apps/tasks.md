# Tasks: Keep Codex connected apps away from the reviewer
**Change:** fix-cross-review-codex-apps
**Date:** 2026-11-25

## :catalog
- [ ] Regression tests in `skills/cross-review/scripts/test-cross-review.sh` with a stubbed `codex features list`: override always passed (both modes), apps still on refuses, failing or apps-less output refuses, header reports apps off, Claude path unchanged.
- [ ] Add the forced override and the `features list` check to `codex_opts()` in `skills/cross-review/scripts/cross-review.sh`, plus the header field.
- [ ] Update the script's comments and `skills/cross-review/references/codex.md`.
