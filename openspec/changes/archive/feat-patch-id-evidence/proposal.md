# Proposal: patch-id as rebase evidence
**Change:** feat-patch-id-evidence
**Story group:** none (user-approved step 1 of the pstack comparison follow-ups)
**Date:** 2026-11-25

## Scope
When a fix or classified commit is carried across an amend or rebase, record `git patch-id --stable` for both commits as evidence that the diff is unchanged; classification still follows actual effect.

## Rationale
review-continuity already says to "verify the corresponding diff" after an amend or rebase but gives no mechanical way to do it; patch-id is that check.

## Out of scope
- patch-id deciding `behavioral: no` alone.
- `team`'s merge gate and any script.

Depends on: feat-cross-review-finding-evidence (same file, merges first).
