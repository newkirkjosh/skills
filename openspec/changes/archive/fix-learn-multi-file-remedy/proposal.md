# Proposal: Reconcile every file of a multi-file learn remedy
**Change:** fix-learn-multi-file-remedy
**Story group:** none (bug issue #48)
**Date:** 2026-11-26

## Scope
`learn`'s inbox records list every file and change of an approved remedy in `Applied`, and a record moves to `shipped` only when every listed change holds on the default branch. Review mode's Reconcile and Record steps follow the same rule.

## Rationale
Since Step 5.1 a remedy is often a guard plus its test. With `Applied` naming one file, a partial landing could mark the lesson `shipped`, and review would then skip it for good.

## Out of scope
- Records already in the private inbox.
- Scripts or new checks; other skills.
