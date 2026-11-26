# Proposal: Evidence on every review finding
**Change:** feat-cross-review-finding-evidence
**Story group:** none (user-approved step 1 of the pstack comparison follow-ups)
**Date:** 2026-11-25

## Scope
`cross-review` asks reviewers for the evidence behind each blocking finding, records its level (`cited`, `traced`, `ran`) in the ledger for every finding, and has triage run a permitted check on argument-only findings before accepting them for a fix pass.

## Rationale
Fix passes are the most expensive part of a review round, and a finding that rests on argument alone can send one after a non-defect. Recording evidence makes triage faster and the ledger more useful to later passes.

## Out of scope
- `cross-review.sh` and its tests (read-only sandbox; merge-policy reserved).
- A universal "must be proven by a run" rule.
- `dev` and `team` changes.
- The patch-id evidence change (feat-patch-id-evidence; runs after this one because both edit review-continuity.md).
