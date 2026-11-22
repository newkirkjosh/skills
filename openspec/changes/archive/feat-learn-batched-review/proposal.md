# Proposal: Batched learning review
**Change:** feat-learn-batched-review
**Story group:** none (user request to review learnings at a macro level instead of after every evaluation)
**Date:** 2026-11-22

## Scope
Add a capture mode and a batched review mode to `learn`, with a shared record format in `references/inbox.md`. Capture records a lesson in a private inbox without editing the catalog; review turns the open records into one evidence-backed, user-approved set of catalog edits and tracks each record until its fix ships. Update `learn`'s description and the README row.

## Rationale
`learn` today turns each correction into an edit at once, which fixes symptoms one at a time, can overfit to one run, and gives no view across runs of which skills are weakest.

## Out of scope
- The global-instruction lines naming the inbox location, the capture rule and the reminder threshold (dotfiles, a separate change).
- The `team` failure-injection trial (another repository).
- Any automatic review trigger; review stays user-invoked.
