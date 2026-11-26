# Sprint Contract: Keep Codex connected apps away from the reviewer
**Change:** fix-cross-review-codex-apps
**Date:** 2026-11-25
**Derived from:** specs/stories.md

## :catalog
Evaluated at: 96387d986e20d4af3b579e77ed1af1661bc0ac63
- [x] Change mode passes `-c features.apps=false` — "apps: change mode always passes features.apps=false"; live wrapper run shows it in the review args
- [x] Document mode passes `-c features.apps=false` — "apps: document mode always passes features.apps=false"
- [x] `codex features list` is checked under the reviewer's options before the review; it runs only when `apps` reads false — stubbed tests; live: real codex 0.172.0 `apps stable true` without the override, `false` with it
- [x] Header reports apps off — "apps: the header reports apps off"; live header ends `plugins_disabled=13 mcp_disabled=0 apps=off`
- [x] `apps` still true under the override refuses (exit 3, `STATUS=ERROR`, no review) — change and document refusal tests; live wrapper that dropped the override: rc=3
- [x] Failing `features list` refuses — "apps: refuses when features list fails"
- [x] No exact `apps` row refuses; look-alike rows never count — "prints nothing", "no exact apps row", look-alike tests
- [x] The user's Codex config is never written — config test; only read-only list commands ran live
- [x] Claude reviewer path unchanged — "apps: the claude reviewer path is unchanged"
- [x] Also update: tests (109 passed, 0 failed; base 97), `references/codex.md`, script comments; mutation checks: removing the override fails 30, removing the check fails 7
