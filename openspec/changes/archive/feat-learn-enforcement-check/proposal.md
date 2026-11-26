# Proposal: Enforce lessons before writing them
**Change:** feat-learn-enforcement-check
**Story group:** none (user-approved step 1 of the pstack comparison follow-ups)
**Date:** 2026-11-25

## Scope
`learn` asks, before writing instruction text, whether a check script, a bundled test or a helper-script guard can make the demonstrated mistake fail; when one can, the correction is that check with a test that fails on the mistake.

## Rationale
Instruction text is skipped silently; a check fails loudly. pstack's `correct` and ASDLC's "enforce elsewhere first" both put mechanical enforcement ahead of prose.

## Out of scope
- A central rule-to-enforcer table.
- Writing new checks in this change.
- The inbox record format.
