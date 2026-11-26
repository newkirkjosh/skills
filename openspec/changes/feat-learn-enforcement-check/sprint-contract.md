# Sprint Contract: Enforce lessons before writing them
**Change:** feat-learn-enforcement-check
**Date:** 2026-11-25
**Derived from:** specs/stories.md

## :catalog
Evaluated at: 37bb54bea018b5a7f258fe50d7f7cd948c680eef
Cross-review: unavailable: cross-review.sh codex exited STATUS=ERROR (codex rejected the MCP overrides: invalid transport in mcp_servers.linear)

Behavioral items are instruction replay of `specs/manual-checks.md` against the finished `skills/learn/SKILL.md` (fresh evaluator, history-free export of the head above), not live runs.

- [x] The question is asked before any instruction text and names the catalog check script, bundled test and owning helper guard (B1)
- [x] When a check can decide the mistake, the correction is that check plus a test failing on it; instruction text only for the remaining judgment (B2, J3)
- [x] The check lives with the skill or script that owns the decision; no central rule table (B3, S7)
- [x] Review mode inherits the question through Apply's reuse of Steps 5 and 6, with no second copy (B4)
- [x] Step 6 shows a new check failing on the demonstrated mistake and passing on a nearby valid case, recording both (B5)
- [x] A judgment lesson states why no check applies and stays an instruction edit (J1); the question is limited to demonstrated mistakes and keeps the inline-work rule (J2)
- [x] README `learn` row untouched (it describes no edit types); `inbox.md`, `AGENTS.md`, `REVIEW.md` unchanged; no new check written (S6, S8)
- [x] `agentskills validate`, `check-descriptions.sh`, `check-refs.sh`, `bash -n` and all six script tests pass; SKILL.md 157 lines with other steps unchanged (S1-S3, S5, S9)
- [x] Private-term check (S4): coordinator-supplied, `scripts/check-private.sh` in the git worktree with `privacy.public=true` exits 0 at 37bb54b
